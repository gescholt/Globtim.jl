"""
StandardExperiment Module - Unified Experiment Template

Critical point refinement lives in globtimpostprocessing; this module exports
ONLY raw critical points from HomotopyContinuation.

Provides standardized experiment execution that:
- Eliminates code duplication across experiment templates
- Exports raw critical points to CSV (no refinement in globtim)
- Integrates with existing infrastructure (hooks, CLI, DrWatson)
- Supports 1-arg and 2-arg objective functions (auto-detection)
- Captures rich error context for post-processing analysis

Key Features:
- **Raw critical points only**: No local optimization/refinement
- **CSV filename**: `critical_points_raw_deg_X.csv` (note `_raw` suffix)
- **CSV columns**: `index`, `p1`, `p2`, ..., `pN`, `objective`
- **Simplified schema**: v2.0.0 (no refinement/validation fields)
- **Post-processing**: Use globtimpostprocessing for refinement

Enhanced Error Handling:
When experiments fail, comprehensive error context is captured including:
- Error message and type
- Stack trace for debugging
- Experiment parameters (degree, dimension, GN, basis)
- Timing information
- Timestamp

This enables sophisticated error analysis in globtimpostprocessing without
coupling categorization logic to the core execution engine.

Usage:
```julia
using Globtim

# Define objective function (1-arg closure)
objective = p -> sum(p.^2)

# Run experiment (exports raw critical points only)
result = run_standard_experiment(
    objective_function = objective,
    bounds = [(-5.0, 5.0), (-5.0, 5.0)],
    experiment_config = config,
    output_dir = output_dir,
    metadata = Dict("experiment_type" => "sphere_minimization")
)

# CSV exported: critical_points_raw_deg_X.csv
# Columns: index, p1, p2, objective

# For refinement, use globtimpostprocessing:
using GlobtimPostProcessing
result_refined = refine_experiment_results(
    result[:output_dir],
    objective,
    ode_refinement_config()
)
```
"""
module StandardExperiment

using Globtim
using DynamicPolynomials
using Printf, Dates, Statistics
using CSV, DataFrames
using JSON3
using DrWatson
using JLD2
using LinearAlgebra

export run_standard_experiment, DegreeResult, solve_and_transform

using ..PathManager

"""
    _experiment_config_hash(experiment_config, bounds, objective_name, solver, msolve_threads) -> UInt

Stable fingerprint of the inputs that determine per-degree results. Used to decide
whether a `checkpoint.jld2` left behind by a previous run is compatible with the
current invocation.

Only fields that change which polynomial/CP would be produced are included:
- `GN`, `basis`, `domain_size`, `truncation_threshold`, `truncation_mode`
- `bounds`, `objective_name`, `solver`, `msolve_threads`

`degree_range` is intentionally excluded so a user can widen the range on resume.
Optimization tolerances (`optim_*`, `max_time`, `max_iterations`, feature toggles)
are excluded because they do not affect the raw critical points exported here.
"""
function _experiment_config_hash(
    experiment_config,
    bounds::Vector{Tuple{Float64,Float64}},
    objective_name::String,
    solver::Symbol,
    msolve_threads::Int,
)
    h = hash((
        experiment_config.GN,
        Symbol(experiment_config.basis),
        experiment_config.domain_size,
        experiment_config.truncation_threshold,
        Symbol(experiment_config.truncation_mode),
        bounds,
        objective_name,
        solver,
        msolve_threads,
    ))
    return h
end

"""
    _load_resumable_checkpoint(output_dir, config_hash) -> Vector{DegreeResult}

Return the `degree_results` from a compatible `checkpoint.jld2` in `output_dir`,
or an empty vector if no checkpoint exists / it is incompatible / it is corrupt.

A checkpoint is considered compatible only when the stored `config_hash` matches
the current one. Mismatches are logged and the checkpoint is ignored (not deleted)
so the user can inspect it.
"""
function _load_resumable_checkpoint(output_dir::String, config_hash::UInt)
    checkpoint_path = joinpath(output_dir, "checkpoint.jld2")
    isfile(checkpoint_path) || return []

    try
        data = JLD2.load(checkpoint_path)
        stored_hash = get(data, "config_hash", nothing)
        if stored_hash === nothing
            @warn "Checkpoint has no config_hash; ignoring (pre-resume-support file)" path =
                checkpoint_path
            return []
        end
        if stored_hash != config_hash
            @warn "Checkpoint config_hash mismatch; ignoring and starting fresh" path =
                checkpoint_path stored = stored_hash current = config_hash
            return []
        end
        results = get(data, "degree_results", nothing)
        if !(results isa Vector)
            @warn "Checkpoint missing degree_results or wrong type; ignoring" path =
                checkpoint_path
            return []
        end
        return results
    catch e
        @warn "Failed to load checkpoint; starting fresh" path = checkpoint_path exception =
            (e, catch_backtrace())
        return []
    end
end

"""
    _save_checkpoint(output_dir, degree_results, config_hash)

Persist in-progress results so a later invocation can resume. Stores both
`degree_results` and the `config_hash` used to validate compatibility.
"""
function _save_checkpoint(output_dir::String, degree_results::Vector, config_hash::UInt)
    checkpoint_path = joinpath(output_dir, "checkpoint.jld2")
    jldsave(
        checkpoint_path;
        degree_results = degree_results,
        config_hash = config_hash,
        warn = false,
    )
    return nothing
end

"""
Result structure for a single degree's computation.

Simplified structure for Phase 2: Refinement moved to globtimpostprocessing.
This struct now only tracks raw critical points from HomotopyContinuation.
"""
struct DegreeResult
    degree::Int
    status::String  # "success" or "failed"

    # Critical points (raw from HomotopyContinuation only)
    n_critical_points::Int  # Total raw critical points found
    critical_points::Vector{Vector{Float64}}  # Raw critical point coordinates
    objective_values::Vector{Float64}  # Objective values at raw critical points

    # Best estimate (always present, may be outside domain)
    best_estimate::Union{Vector{Float64},Nothing}
    best_objective::Union{Float64,Nothing}
    recovery_error::Union{Float64,Nothing}  # Optional: if true params known

    # Quality metrics
    l2_approx_error::Float64
    relative_l2_error::Float64  # l2_approx_error / ||f||_L2 (dimensionless)
    condition_number::Float64

    # Coefficient counts
    n_total_coeffs::Int   # Total coefficients = binomial(n+d, d) for total degree d in n dims
    support_size::Int     # Nonzero coefficients: count(!iszero, pol.coeffs)

    # Truncation/sparsity metrics (nothing when no truncation applied)
    truncation_original_nnz::Union{Int,Nothing}   # Nonzero coefficients before truncation
    truncation_new_nnz::Union{Int,Nothing}         # Nonzero coefficients after truncation
    truncation_l2_ratio::Union{Float64,Nothing}    # ||p_truncated||_L2 / ||p_original||_L2

    # Timing breakdown
    polynomial_construction_time::Float64
    critical_point_solving_time::Float64
    critical_point_processing_time::Float64
    file_io_time::Float64
    total_computation_time::Float64

    # Output location
    output_dir::String

    # Error information (if failed): Dict{String,Any} with rich context, or Nothing (success)
    error::Union{Dict{String,Any},Nothing}
end

"""
    solve_and_transform(pol::ApproxPoly, bounds; solver=:hc) -> (critical_points, solve_time)

Solve a polynomial system and transform solutions from normalized [-1,1]^n
coordinates to the original domain.

This is the shared kernel used by both `run_standard_experiment` (full polynomials)
and `run_sparsification_experiment` (sparsified polynomial variants).

# Arguments
- `pol::ApproxPoly`: Polynomial approximation (full or sparsified)
- `bounds::Vector{Tuple{Float64, Float64}}`: Domain bounds [(lb₁,ub₁), ...]

# Keyword Arguments
- `solver::Symbol=:hc`: Solver backend (`:hc` or `:msolve`)
- `msolve_threads::Int=1`: Number of threads for msolve (`:msolve` only)
- `search_bounds`: Optional sub-box in ORIGINAL domain coordinates to restrict
  solutions to. For msolve, uses certified interval-box overlap; for HC, uses
  midpoint filtering. Bounds are converted to normalized [-1,1]^n internally.

# Returns
- `critical_points::Vector{Vector{Float64}}`: Critical points in original domain coordinates
- `solve_time::Float64`: Wall-clock time for solve (seconds)
"""
function solve_and_transform(
    pol,  # ApproxPoly — not typed to avoid import dependency
    bounds::Vector{Tuple{Float64,Float64}};
    sparsify_threshold::Float64 = 0.0,
    start_system::Symbol = :auto,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing,
    msolve_coeff_tol::Float64 = 0.0,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
    transform::Union{Nothing,Matrix{Float64}} = nothing,
    path_stats_ref::Union{Nothing,Base.RefValue{Any}} = nothing,
    representation::Symbol = :monomial,
    surrogate_residual_tol::Real = 1e-4,
)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]

    # Stage 2b: a rotated leaf (transform = Q) maps normalized ẑ → physical via
    # z = center + Q·(ẑ .* sample_range). The HC system is solved in ẑ and CPs are
    # lifted back through Q below. search_bounds assume an axis-aligned physical box,
    # which is not axis-aligned in the rotated ẑ frame — raise rather than filter wrongly.
    if transform !== nothing && search_bounds !== nothing
        error(
            "solve_and_transform: search_bounds with a non-identity transform is not supported (the physical search box is not axis-aligned in the rotated frame)",
        )
    end

    # Convert search_bounds from original domain to normalized [-1,1]^n
    normalized_search_bounds = if search_bounds !== nothing
        [
            ((sb[1] - center[i]) / sample_range[i], (sb[2] - center[i]) / sample_range[i]) for (i, sb) in enumerate(search_bounds)
        ]
    else
        nothing
    end

    # Solve polynomial system (HC or msolve, selected by solver kwarg)
    @polyvar x[1:dimension]
    solve_time = @elapsed begin
        raw_critical_points = Globtim.solve_polynomial_system_from_approx(
            x,
            pol;
            sparsify_threshold = sparsify_threshold,
            start_system = start_system,
            solver = solver,
            msolve_threads = msolve_threads,
            msolve_timeout_seconds = msolve_timeout_seconds,
            msolve_coeff_tol = msolve_coeff_tol,
            search_bounds = normalized_search_bounds,
            path_stats_ref = path_stats_ref,
            representation = representation,
            surrogate_residual_tol = surrogate_residual_tol,
        )
    end

    # Transform from normalized [-1,1]^n to original domain coordinates. Axis-aligned
    # (transform === nothing) is the original byte-identical map; a rotated leaf lifts
    # back through Q: z = center + Q·(ẑ .* sample_range) (Stage 2b).
    critical_points = if transform === nothing
        [sample_range .* [pt[i] for i in 1:dimension] .+ center for pt in raw_critical_points]
    else
        [
            center .+ transform * (sample_range .* [pt[i] for i in 1:dimension]) for
            pt in raw_critical_points
        ]
    end

    return critical_points, solve_time
end

"""
    run_standard_experiment(;
        objective_function::Function,
        objective_name::String,
        bounds::Vector{Tuple{Float64, Float64}},
        experiment_config,
        output_dir::String,
        metadata::Dict{String, Any} = Dict(),
        true_params::Union{Vector{Float64}, Nothing} = nothing
    ) -> Dict{String, Any}

Execute standardized experiment with RAW critical point export only.

Refinement lives in the globtimpostprocessing package; this function exports
only raw critical points from HomotopyContinuation.

# Arguments
- `objective_function`: Callable with signature f(point::Vector{Float64}) -> Float64.
  Accepts plain functions, closures, or callable structs (e.g., TolerantObjective).
- `objective_name`: Identifier for the objective function (e.g., "lv4d", "deuflhard_4d_q4").
  Stored in `results_summary.json` under `experiment_definition.objective_name` to make
  experiment outputs self-describing for parameter sweep analysis.
- `bounds`: Vector of (min, max) tuples for each dimension
- `experiment_config`: ExperimentParams from ExperimentCLI (GN, degree_range, max_time, domain_size)
- `output_dir`: Output directory path (from DrWatson, --output-dir, or hierarchical path)
- `metadata`: Additional metadata for results_summary.json (system_type, params, etc.)
- `true_params`: Optional true parameters for recovery error calculation

# Degree policy (relative L2)
- `degree_policy::Symbol = :sweep`: `:sweep` solves every degree of
  `experiment_config.degree_range` (legacy). `:rel_l2_ladder` (rel_l2_ladder.jl) fits
  every degree but solves only those with relative L2 ≤ `rel_l2_solve_below`; it stops on
  a reliable fit (rel-L2 < `rel_l2_thresholds.reliable`) whose recovered minimizer has
  plateaued (relative move < `gradient_residual_tol` over the last two reliable solves),
  after `rel_l2_max_reliable_solves` reliable solves, or when rel-L2 stagnates
  (`stagnation_threshold`). Unsolved degrees appear with status `"skipped_rel_l2"` and do
  not count against `success_rate`. The verdict and the rel-L2 history are written to
  `metadata["rel_l2_ladder"]`; `:stagnated_unsolvable` means more degree will not help —
  subdivide, change chart, or try a rational surrogate. Incompatible with
  `stagnation_stop` / `gradient_residual_gate`, which it already contains.
- `rel_l2_thresholds::RelL2Thresholds`: the bands of
  `globtimpostprocessing/quality_thresholds.toml` (0.03 / 0.05 / 0.10).
- `rel_l2_solve_below::Float64 = rel_l2_thresholds.structure_visible`.
- `rel_l2_max_reliable_solves::Int = 4`.
- `gate_metric::Symbol = :rel_l2`: the quantity the solve gate and the ladder read.
  `:rel_l2` is ‖f − p‖/‖f‖ as above. `:rel_grad` is the relative gradient error
  ‖∇f − ∇p‖/‖∇f‖ on the fit grid (`relative_gradient_error`, gradient_fit.jl) — HC
  solves ∇p = 0, and value accuracy does not predict whether its roots are near roots of
  ∇f: 16 leaves under 5 % L2 produced 95 % spurious HC roots, and leaf rel-L2 is
  uncorrelated with yield (`docs/research/subdivision_findings.md:13-25`,
  `docs/research/plans/EVIDENCE_MAP_2026-10.md`, N1). With `:rel_grad` the gradient check
  runs on every fitted degree (`gradient_check = true` is implied), the bands come from
  `rel_grad_thresholds`, the unsolved degrees carry `skip_reason =
  "rel_grad_above_solve_threshold"`, and the ladder record names the metric.
- `rel_grad_thresholds::RelL2Thresholds = RelL2Thresholds(reliable = 0.03,
  structure_visible = 0.10, unreliable = 0.30)`: bands for `:rel_grad`. These are NOT
  calibrated by a campaign the way the rel-L2 bands are; they are the starting point for
  the calibration run (N1 benchmark: the 3× LV tree of
  `globtim_results/cluster/cert_subdiv_sweep/SEEDING_FINDINGS.md`).

# Gradient information
- `gradient_weight::Float64 = 0.0`: > 0 fits by gradient-enhanced least squares
  (`Constructor(...; gradient_weight)`, gradient_fit.jl).
- `gradient_method::Symbol = :forwarddiff`: or `:finitediff` for non-AD objectives.
- `gradient_check::Bool = gradient_weight > 0`: record the relative gradient error
  ‖∇f − ∇p‖/‖∇f‖ of every fitted degree in `metadata["relative_gradient_error"]`.
- `gradient_check_points::Int = 20·dim`: grid rows used by that check (one ∇f each).
- `box_census::Bool = false`: run `box_strata_census` on every solved degree's surrogate
  (3ⁿ HC face solves) and record sum / ok / boundary counts in
  `metadata["box_strata_census"]`. A sum ≠ 1 means the surrogate census missed points.

# Objective pre-processing (value_transform.jl, eval_cache.jl)
- `cache_evaluations::Bool = true`: wrap the objective in a `CachedObjective` so the
  degree sweep evaluates it once per grid point — `Constructor` re-evaluates the full
  `(GN+1)^dim` grid at every degree otherwise. Hit/miss counts land in
  `metadata["evaluation_cache"]`. Set `false` for non-deterministic objectives whose
  repeated evaluation is intended.
- `value_transform = nothing`: fit `g ∘ f` instead of `f` for a strictly increasing `g`
  (critical points and Morse indices are invariant; see `AbstractValueTransform`). Pass
  a transform (`AsinhTransform(scale; shift)`), or a `Symbol` (`:asinh`, `:log`, `:sqrt`)
  to fit one with `fit_value_transform` on the fit grid's own values — with
  `cache_evaluations` those evaluations are reused by the first fit, so the pilot costs
  nothing. Objective values reported at critical points are always those of the
  ORIGINAL `f`; the relative L² and gradient errors are those of the transformed fit.
  Recorded in `metadata["value_transform"]`.
- `msolve_coeff_tol::Float64 = 0.0`: (`solver = :msolve`) round coefficients onto a common
  dyadic grid before the exact basis conversion (`dyadic_quantize`); `0.0` is exact.

# Admissibility of the fit grid (admissibility.jl; N3 of docs/research/plans/EVIDENCE_MAP_2026-10.md)
- `admissibility::Bool = true`: every degree's fit grid is checked before the least-squares
  solve; a grid holding non-finite values, the objective's registered `penalty_value`
  (`isapprox`, rtol 1e-3), or values with `|f| > max_abs_value` raises
  `InadmissibleGridError` with the counts. The degree is recorded with status
  `"inadmissible"` (counts in its `error` dictionary and in
  `metadata["stopped_inadmissible"]`) and the sweep STOPS: with a fixed `GN` every
  degree samples the same grid, so the later degrees would fail identically. Why: a
  least-squares fit through penalty nodes is a fit of the wall ("treat a nonzero
  penalty-node count as a failure, not a statistic", `pkg/Opt_Traj/.claude/CLAUDE.md`);
  the subdivision path already masks such leaves (`barrier_mask.jl`), the single-domain
  path had no gate.
- `penalty_value = nothing`: the objective's sentinel (Opt_Traj: `barrier_value(obj)`).
- `max_abs_value::Real = Inf`: dynamic-range cap (LV / FHN draws reach `1e18`–`1e113`
  inside the box; such values are plateau noise, not landscape).

# Analyticity detector (analyticity.jl; N7 of docs/research/plans/EVIDENCE_MAP_2026-10.md)
- `analyticity_check::Bool = true`: after every fit, `analyticity_verdict` reads the
  per-axis coefficient envelopes: an analytic objective's Chebyshev coefficients decay
  geometrically along each axis, a kink / plateau edge / wall inside the box makes them
  decay algebraically on that axis (`|c_k| ~ k^{-ν}`), and further degrees then buy
  nothing (the porkchop Δv sweep, rel-L2 0.09 → 0.18 → 0.17 at d = 8/12/16). Per-degree
  verdicts land in `metadata["analyticity"]` (verdict, decay rate, algebraic exponent,
  model RSS ratio, offending axes, suggested axis).
- `analyticity_stop::Bool = false`: stop the sweep on the first `:non_analytic` verdict at
  `degree ≥ analyticity_min_degree` (default 12: the laws are fitted on the peaks of the
  envelope and need about nine of them before geometric and algebraic decay separate —
  a kink at 0.2 is flagged at degree 14, not 10) and record
  `metadata["stopped_non_analytic"]` with the offending axes and the hand-off
  (subdivide along `suggested_axis`, or reformulate).
- `analyticity_options::NamedTuple = (;)`: keyword overrides for `axis_analyticity`
  (`rate_threshold`, `model_ratio`, `min_points`, `rel_floor`).

# Surrogate-side deduplication (surrogate_dedup.jl; N5 of docs/research/plans/EVIDENCE_MAP_2026-10.md)
- `surrogate_dedup::Bool = true`: after the solve, every raw root is Newton-polished on
  the surrogate (microseconds) and the polished roots are clustered at
  `surrogate_dedup_tol` (box coordinates, default `1e-6`). The raw census is unchanged;
  `critical_points_raw_deg_X.csv` gains `cluster_id`, `cluster_size`, `representative`
  (1 for the first member of each cluster) and `surrogate_polish_move`, and the timing
  records `n_surrogate_clusters`. `GlobtimPostProcessing.refine_experiment_results`
  refines the representatives only (its default) — the recorded waste was 63–97 % of
  the polish iterations on redundant seeds, a median of 16 seeds per point.

# Automatic chop
`experiment_config.truncation_mode = :auto` replaces the manual threshold by
`chop_polynomial`: the coefficient envelope's noise plateau is estimated per degree and
coefficients at or below it are zeroed. The estimate (`floor`, `usable_degree`,
`decay_rate`) is recorded in the degree's timing dictionary.
# Box geometry (aligned_box.jl; N2 of docs/research/plans/EVIDENCE_MAP_2026-10.md)
- `align_box = nothing`: a candidate minimum `x*` (physical coordinates). When given, the
  box is re-centred at `x*` and rotated to the eigenbasis of the Hessian of `f` there
  (`eigen_aligned_box`), keeping the half-widths of `bounds`, and the WHOLE run — fit,
  solve, census, CSV — happens in the aligned frame `y = Qᵀ(x − x*)`; `true_params` is
  mapped into that frame too, so `recovery_error` is unchanged in meaning. Why: no
  axis-aligned box in the LV atlas is closed (outflow 0.67–0.93 on 47/47) and the outflow
  fraction is scale-invariant for an axis-aligned box about a sloppy minimum, while the
  eigen-aligned box closes (`experiments/sandbox/lv_landscape_atlas/BOUNDARY_AND_SUBDIVISION.md:44-74`);
  Poincaré–Hopf is a certificate only on a closed box. Written out: `aligned_box.json`
  (center, `Q` by columns, half-widths, eigenvalues), `metadata["aligned_box"]`, and one
  `critical_points_physical_deg_X.csv` per solved degree with the raw critical points
  mapped back to physical coordinates (`critical_points_raw_deg_X.csv` stays in the
  aligned frame, as do `DegreeResult.critical_points`).
- `align_shape::Symbol = :isotropic`: `:eigen` widens the box along the flat Hessian
  directions (see `eigen_aligned_box`).
- `measure_outflow::Bool = align_box !== nothing`: sample the boundary (`outflow_samples`
  per face) and record `metadata["box_outflow"]` — the fraction of the boundary where ∇f
  points outward, for the box as given and, with `align_box`, for the aligned box.
  `fraction < 1` means the open index sum need not be 1 on this box; read the strata
  census instead.
- `outflow_samples::Int = 64`.

# Returns
Dictionary with:
- `degree_results`: Vector of DegreeResult structs (containing raw critical points)
- `total_critical_points`: Sum of raw critical points across all degrees
- `total_time`: Total computation time
- `success_rate`: Fraction of degrees that succeeded
- `output_dir`: Output directory path

Each DegreeResult contains:
- `n_critical_points::Int`: Number of raw critical points found
- `critical_points::Vector{Vector{Float64}}`: Raw critical point coordinates
- `objective_values::Vector{Float64}`: Objective values at raw critical points
- `best_estimate::Vector{Float64}`: Best critical point (lowest objective)
- `output_dir::String`: Path to CSV file with raw critical points

# CSV Output
- Filename: `critical_points_raw_deg_X.csv` (note the `_raw` suffix)
- Columns: `index`, `p1`, `p2`, ..., `pN`, `objective`
- Contains RAW critical points only (no refinement, no validation columns)

# Refinement (Post-Processing)
To refine critical points, use globtimpostprocessing:
```julia
using Globtim, GlobtimPostProcessing

# Step 1: Run experiment (globtim)
result_raw = run_standard_experiment(
    objective_function = my_objective,
    objective_name = "my_problem",
    bounds = bounds,
    experiment_config = config,
    output_dir = "results/my_experiment"
)

# Step 2: Refine (globtimpostprocessing)
result_refined = refine_experiment_results(
    result_raw[:output_dir],
    my_objective,
    ode_refinement_config()
)
```

# Example
```julia
result = run_standard_experiment(
    objective_function = p -> sum(p.^2),
    objective_name = "quadratic_test",
    bounds = [(0.5, 1.5), (1.5, 2.5), (2.5, 3.5), (3.5, 4.5)],
    experiment_config = parse_experiment_args(ARGS),
    output_dir = "hpc_results/my_experiment",
    metadata = Dict("experiment_type" => "parameter_recovery")
)
```
"""
# GRADRES-GATE: runtime convergence test on the *recovered minimizer*
# rather than the L2 approximation error. The displacement bound ‖H⁻¹∇w(p_true)‖ — and
# hence the recovered global minimizer — saturates at low degree while the L2 error keeps
# falling many orders of magnitude (finding F9; T3 sweep cluster 721071). Unlike
# `recovery_error`, this reads only `best_estimate`, so it needs no true parameters and is
# valid in a genuine estimation run. Returns true once the recovered minimizer has moved
# less than `tol` (relative) for the two most recent successful degrees — i.e. it has
# plateaued. Requires ≥3 minimizers (two consecutive sub-tol steps), mirroring the L2
# stagnation gate's robustness.
function _recovered_minimizer_plateaued(degree_results, tol::Float64)
    ms = [
        r.best_estimate for r in sort(
            filter(
                s -> s.status == "success" && s.best_estimate !== nothing,
                degree_results,
            ),
            by = s -> s.degree,
        )
    ]
    length(ms) >= 3 || return false
    rel(a, b) = norm(a - b) / (norm(b) + 1e-15)
    return rel(ms[end], ms[end-1]) < tol && rel(ms[end-1], ms[end-2]) < tol
end

# Ladder view of the degree results: fitted degrees (solved or deliberately skipped) with a
# finite relative L2; failed and timed-out degrees carry no fit and are left out.
# `metric`: `nothing` ⇒ the entries carry the relative L2 error (the ladder's native
# quantity); a `Dict{Int,Float64}` (degree ⇒ value, e.g. the per-degree relative gradient
# error) ⇒ that value is put in the entry's `rel_l2` slot instead, so the same pure ladder
# runs on the gradient-fidelity metric (gate_metric = :rel_grad). Degrees without a metric
# value are left out.
function _ladder_history(degree_results; metric::Union{Nothing,Dict{Int,Float64}} = nothing)
    rs = sort(
        filter(
            r ->
                r.status in ("success", "skipped_rel_l2") &&
                    isfinite(r.relative_l2_error) &&
                    (metric === nothing || (haskey(metric, r.degree) && isfinite(metric[r.degree]))),
            degree_results,
        ),
        by = r -> r.degree,
    )
    return [
        RelL2LadderEntry(
            r.degree,
            metric === nothing ? r.relative_l2_error : metric[r.degree],
            r.status == "success",
            r.status == "success" ? r.best_estimate : nothing,
        ) for r in rs
    ]
end

function _record_ladder!(
    metadata,
    verdict,
    reason,
    degree,
    degree_results,
    th,
    solve_below;
    metric::Union{Nothing,Dict{Int,Float64}} = nothing,
)
    hist = _ladder_history(degree_results; metric = metric)
    metadata["rel_l2_ladder"] = Dict{String,Any}(
        "verdict" => string(verdict),
        "reason" => reason,
        "metric" => metric === nothing ? "rel_l2" : "rel_grad",
        "stopped_after_degree" => degree,
        "solve_below" => solve_below,
        "thresholds" => Dict(
            "reliable" => th.reliable,
            "structure_visible" => th.structure_visible,
            "unreliable" => th.unreliable,
        ),
        "degrees" => [h.degree for h in hist],
        "relative_l2" => [h.rel_l2 for h in hist],   # the gate metric's values (see "metric")
        "solved" => [h.solved for h in hist],
        "band" => [string(classify_rel_l2(h.rel_l2, th)) for h in hist],
    )
    return metadata
end

function run_standard_experiment(;
    objective_function,
    objective_name::String,
    bounds::Vector{Tuple{Float64,Float64}},
    experiment_config,
    output_dir::String,
    metadata::Dict{String,Any} = Dict{String,Any}(),
    true_params::Union{Vector{Float64},Nothing} = nothing,
    solver::Symbol = :hc,
    start_system::Symbol = :auto,
    msolve_threads::Int = 1,
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing,
    stagnation_stop::Bool = false,
    stagnation_threshold::Float64 = 0.01,
    gradient_residual_gate::Bool = false,
    gradient_residual_tol::Float64 = 1e-3,
    degree_policy::Symbol = :sweep,
    rel_l2_thresholds::RelL2Thresholds = RelL2Thresholds(),
    rel_l2_solve_below::Float64 = rel_l2_thresholds.structure_visible,
    rel_l2_max_reliable_solves::Int = 4,
    gate_metric::Symbol = :rel_l2,
    rel_grad_thresholds::RelL2Thresholds = RelL2Thresholds(
        reliable = 0.03,
        structure_visible = 0.10,
        unreliable = 0.30,
    ),
    gradient_weight::Float64 = 0.0,
    gradient_method::Symbol = :forwarddiff,
    gradient_check::Bool = gradient_weight > 0,
    gradient_check_points::Int = 20 * length(bounds),
    box_census::Bool = false,
    cache_evaluations::Bool = true,
    value_transform::Union{Nothing,Symbol,AbstractValueTransform} = nothing,
    msolve_coeff_tol::Float64 = 0.0,
    admissibility::Bool = true,
    penalty_value::Union{Nothing,Real} = nothing,
    max_abs_value::Real = Inf,
    analyticity_check::Bool = true,
    analyticity_stop::Bool = false,
    analyticity_min_degree::Int = 12,
    analyticity_options::NamedTuple = (;),
    surrogate_dedup::Bool = true,
    surrogate_dedup_tol::Float64 = 1e-6,
    align_box::Union{Nothing,AbstractVector{<:Real}} = nothing,
    align_shape::Symbol = :isotropic,
    measure_outflow::Bool = align_box !== nothing,
    outflow_samples::Int = 64,
)
    degree_policy in (:sweep, :rel_l2_ladder) || throw(
        ArgumentError(
            "degree_policy must be :sweep or :rel_l2_ladder, got :$degree_policy",
        ),
    )
    if degree_policy == :rel_l2_ladder && (stagnation_stop || gradient_residual_gate)
        throw(
            ArgumentError(
                "degree_policy = :rel_l2_ladder already contains the relative-L2 stagnation " *
                "stop and the GRADRES-GATE (restricted to the reliable band); do not also " *
                "set stagnation_stop / gradient_residual_gate",
            ),
        )
    end
    ladder = degree_policy == :rel_l2_ladder
    gate_metric in (:rel_l2, :rel_grad) ||
        throw(ArgumentError("gate_metric must be :rel_l2 or :rel_grad, got :$gate_metric"))
    gate_grad = gate_metric == :rel_grad
    # The thresholds and solve-below the gate and the ladder actually use.
    gate_thresholds = gate_grad ? rel_grad_thresholds : rel_l2_thresholds
    gate_solve_below = gate_grad ? rel_grad_thresholds.structure_visible : rel_l2_solve_below
    # Gradient check (gradient_fit.jl): ‖∇f − ∇p‖/‖∇f‖ on the fit grid, per fitted degree,
    # recorded in metadata["relative_gradient_error"] (degree => value). Mandatory when it
    # is the gate metric.
    grad_errors = (gradient_check || gate_grad) ? Dict{Int,Float64}() : nothing
    # Closed Poincaré–Hopf census (box_strata_census.jl) of every SOLVED degree's surrogate.
    census_out = box_census ? Dict{Int,Dict{String,Any}}() : nothing
    # N7 analyticity detector (analyticity.jl): per-degree, per-axis verdict from the
    # coefficient envelope; recorded in metadata["analyticity"], and with analyticity_stop
    # a :non_analytic verdict at degree ≥ analyticity_min_degree ends the sweep.
    analyticity_out = analyticity_check ? Dict{Int,AnalyticityVerdict}() : nothing
    mkpath(output_dir)

    # Box geometry (aligned_box.jl, N2). With align_box the run is re-expressed in the
    # Hessian eigenframe at the candidate minimum; everything below sees the aligned
    # objective, bounds and true parameters, and `aligned` carries the map back.
    given_box = axis_aligned_box(bounds)
    aligned = nothing
    if measure_outflow
        of = box_outflow(objective_function, given_box; n_samples = outflow_samples)
        metadata["box_outflow"] = Dict{String,Any}(
            "given" => Dict{String,Any}(
                "fraction" => of.fraction,
                "min_cos" => of.min_cos,
                "n_faces_closed" => of.n_faces_closed,
                "samples" => of.samples,
            ),
        )
        @info "Box outflow (given box): $(round(of.fraction, digits=4)) " *
              "($(of.n_faces_closed)/$(2 * length(bounds)) faces closed)"
    end
    if align_box !== nothing
        length(align_box) == length(bounds) || throw(
            ArgumentError("align_box has $(length(align_box)) entries for $(length(bounds)) bounds"),
        )
        aligned = eigen_aligned_box(
            objective_function,
            align_box;
            half_widths = given_box.half_widths,
            shape = align_shape,
        )
        if measure_outflow
            ofa = box_outflow(objective_function, aligned; n_samples = outflow_samples)
            metadata["box_outflow"]["aligned"] = Dict{String,Any}(
                "fraction" => ofa.fraction,
                "min_cos" => ofa.min_cos,
                "n_faces_closed" => ofa.n_faces_closed,
                "samples" => ofa.samples,
            )
            @info "Box outflow (eigen-aligned box): $(round(ofa.fraction, digits=4)) " *
                  "($(ofa.n_faces_closed)/$(2 * length(bounds)) faces closed)"
        end
        metadata["aligned_box"] = box_summary(aligned)
        metadata["aligned_box"]["shape"] = string(align_shape)
        open(joinpath(output_dir, "aligned_box.json"), "w") do io
            JSON3.pretty(io, metadata["aligned_box"])
        end
        objective_function = AlignedObjective(objective_function, aligned)
        bounds = aligned_bounds(aligned)
        true_params = true_params === nothing ? nothing : Vector{Float64}(to_aligned(aligned, true_params))
        @info "Running in the Hessian-eigenaligned frame" center = aligned.center eigenvalues =
            aligned.eigenvalues
    end

    # Pre-compute domain geometry (invariant across degrees)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]

    # The objective the FIT sees. TestInput stores no values — Constructor evaluates the
    # objective on the full (GN+1)^dimension grid at every degree — so the sweep is wrapped
    # in a CachedObjective (eval_cache.jl): bit-identical grid points hit the cache from the
    # second degree on. An optional monotone value transform (value_transform.jl) is
    # composed on top; critical points are invariant under it, the fit is not. Everything
    # downstream (objective values at critical points, true_params recovery) keeps using
    # `objective_function`, the original.
    fit_objective = cache_evaluations ? CachedObjective(objective_function) : objective_function
    transform = if value_transform === nothing
        nothing
    elseif value_transform isa Symbol
        # Pilot sample = the fit grid itself, so with caching the pilot is free.
        pilot_grid = Globtim.generate_grid(dimension, experiment_config.GN; basis = experiment_config.basis)
        # Same affine map and operation order as MainGenerate's eval_fn, so the keys are
        # bit-identical to the fit's; 1-D objectives receive a scalar there too.
        pilot_vals = [
            let sx = sample_range .* collect(x), p = sx .+ center
                dimension == 1 ? fit_objective(p[1]) : fit_objective(p)
            end for x in vec(pilot_grid)
        ]
        fit_value_transform(pilot_vals; kind = value_transform)
    else
        value_transform
    end
    if transform !== nothing && !(transform isa IdentityTransform)
        fit_objective = TransformedObjective(fit_objective, transform)
        metadata["value_transform"] = transform_summary(transform)
        @info "Fitting transformed objective" transform = transform_summary(transform)
    end

    TR = Globtim.TestInput(
        fit_objective,
        dim = dimension,
        center = center,
        GN = experiment_config.GN,
        sample_range = sample_range,
    )

    # Resume: if a compatible checkpoint exists, reuse successful degrees.
    # Failed degrees are retried (user may have restarted to fix whatever broke).
    config_hash = _experiment_config_hash(
        experiment_config,
        bounds,
        objective_name,
        solver,
        msolve_threads,
    )
    resumed = _load_resumable_checkpoint(output_dir, config_hash)
    resumed_success = filter(r -> r.status == "success", resumed)
    completed_degrees = Set(r.degree for r in resumed_success)
    if !isempty(resumed_success)
        @info "Resuming from checkpoint: $(length(resumed_success)) degree(s) already complete" degrees =
            sort(collect(completed_degrees))
    end

    # Process each degree (skipping any already completed successfully on a prior run).
    # Use an explicitly typed Vector{DegreeResult} — `copy(resumed_success)` inherits
    # `resumed_success`'s eltype, which is `Any` when there's no checkpoint (`filter`
    # on an empty `Any[]` returns `Any[]`), and `create_experiment_summary` dispatches
    # on `Vector{DegreeResult}` exactly.
    degree_results = DegreeResult[r for r in resumed_success]
    total_critical_points = sum(r.n_critical_points for r in resumed_success; init = 0)

    for degree in experiment_config.degree_range
        if degree in completed_degrees
            continue
        end
        degree_start = time()

        try
            result = with_solver_timeout(
                () -> process_single_degree(
                    degree,
                    objective_function,
                    TR,
                    bounds,
                    experiment_config,
                    output_dir,
                    true_params;
                    solver = solver,
                    start_system = start_system,
                    msolve_threads = msolve_threads,
                    msolve_timeout_seconds = msolve_timeout_seconds,
                    msolve_coeff_tol = msolve_coeff_tol,
                    solve_rel_l2_max = ladder ? gate_solve_below : Inf,
                    gate_metric = gate_metric,
                    gradient_weight = gradient_weight,
                    gradient_method = gradient_method,
                    gradient_errors = grad_errors,
                    gradient_check_points = gradient_check_points,
                    census_out = census_out,
                    admissibility = admissibility,
                    penalty_value = penalty_value,
                    max_abs_value = max_abs_value,
                    analyticity_out = analyticity_out,
                    analyticity_options = analyticity_options,
                    surrogate_dedup = surrogate_dedup,
                    surrogate_dedup_tol = surrogate_dedup_tol,
                ),
                experiment_config.degree_timeout_seconds;
                label = "degree $degree",
            )

            push!(degree_results, result)
            total_critical_points += result.n_critical_points

            # Checkpoint: save accumulated results after each degree so partial
            # runs are recoverable if the job hits a wall-time limit.
            _save_checkpoint(output_dir, degree_results, config_hash)

            # N7: a non-analytic axis makes every further degree a wasted fit (algebraic
            # coefficient decay); stop and name the axis for a subdivision / reformulation.
            if analyticity_stop &&
               analyticity_out !== nothing &&
               haskey(analyticity_out, degree) &&
               analyticity_out[degree].verdict == :non_analytic &&
               degree >= analyticity_min_degree
                av = analyticity_out[degree]
                @info "Stopping degree sweep: non-analytic axis detected (N7)" degree axes =
                    findall(av.offending) suggested_axis = av.suggested_axis decay_rate =
                    av.decay_rate
                metadata["stopped_non_analytic"] = merge(
                    analyticity_summary(av),
                    Dict{String,Any}(
                        "degree" => degree,
                        "suggestion" => "subdivide along axis $(av.suggested_axis) or reformulate; more degree will not converge",
                    ),
                )
                metadata["stopped_after_degree"] = degree
                break
            end

            # Optional early stop (opt-in; default off ⇒ full-range sweep unchanged):
            # halt once the relative-L2 approximation error has stopped improving.
            # Reuses EnhancedMetrics.detect_stagnation (last ≤3 relative improvements
            # all below threshold). Solving still happens per degree as before — this
            # only trims wasted higher-degree degrees once the fit has plateaued.
            if stagnation_stop
                l2_hist = [
                    r.relative_l2_error for r in sort(
                        filter(s -> s.status == "success", degree_results),
                        by = s -> s.degree,
                    )
                ]
                if length(l2_hist) >= 3 &&
                   EnhancedMetrics.detect_stagnation(l2_hist, stagnation_threshold)
                    @info "Stopping degree sweep: relative-L2 stagnated" degree last_rel_l2 =
                        l2_hist[end] threshold = stagnation_threshold
                    metadata["stopped_stagnation"] = true
                    metadata["stopped_after_degree"] = degree
                    metadata["stagnation_threshold"] = stagnation_threshold
                    break
                end
            end

            # Relative-L2 ladder (degree_policy = :rel_l2_ladder; rel_l2_ladder.jl): degrees
            # whose fit is above rel_l2_solve_below were fitted but not solved; stop on a
            # reliable fit with a plateaued minimizer, on the reliable-solve budget, or on
            # stagnation, and record the verdict in the run metadata.
            if ladder
                lstep = rel_l2_ladder_step(
                    _ladder_history(degree_results; metric = gate_grad ? grad_errors : nothing);
                    thresholds = gate_thresholds,
                    solve_below = gate_solve_below,
                    minimizer_tol = gradient_residual_tol,
                    max_reliable_solves = rel_l2_max_reliable_solves,
                    stagnation_threshold = stagnation_threshold,
                )
                if lstep.action == :stop
                    @info "Stopping degree sweep (rel-L2 ladder): $(lstep.verdict)" degree reason =
                        lstep.reason
                    _record_ladder!(
                        metadata,
                        lstep.verdict,
                        lstep.reason,
                        degree,
                        degree_results,
                        gate_thresholds,
                        gate_solve_below;
                        metric = gate_grad ? grad_errors : nothing,
                    )
                    break
                end
            end

            # GRADRES-GATE (opt-in; default off ⇒ behavior unchanged): halt once the
            # recovered global minimizer has stopped moving across degrees, even though
            # the L2 approximation error is still falling. Reads only the recovered
            # minimizer (no true_params), per finding F9 — recovery saturates early while
            # L2 over-refines 5–8 orders of magnitude. Solving still happens per degree;
            # this only trims the wasted higher-degree solves once recovery has plateaued.
            if gradient_residual_gate &&
               _recovered_minimizer_plateaued(degree_results, gradient_residual_tol)
                @info "Stopping degree sweep: recovered minimizer plateaued (GRADRES-GATE)" degree tol =
                    gradient_residual_tol
                metadata["stopped_gradient_residual_gate"] = true
                metadata["stopped_after_degree"] = degree
                metadata["gradient_residual_tol"] = gradient_residual_tol
                break
            end

        catch e
            degree_time = time() - degree_start
            stop_sweep = false
            if e isa InadmissibleGridError
                # N3: the fit grid is not a sample of the landscape. With a fixed GN every
                # degree sees the same grid, so the sweep stops here (admissibility.jl).
                counts = Dict{String,Any}(
                    "n_total" => e.n_total,
                    "n_nonfinite" => e.n_nonfinite,
                    "n_penalty" => e.n_penalty,
                    "n_above_cap" => e.n_above_cap,
                    "penalty_value" => e.penalty_value,
                    "max_abs_value" => e.max_abs_value,
                )
                @error "Degree $degree: fit grid inadmissible, stopping the sweep" exception = e counts
                metadata["stopped_inadmissible"] = merge(counts, Dict("degree" => degree))
                metadata["stopped_after_degree"] = degree
                stop_sweep = true
                degree_result = DegreeResult(
                    degree,
                    "inadmissible",
                    0,  # n_critical_points
                    Vector{Vector{Float64}}(),
                    Vector{Float64}(),
                    nothing,
                    nothing,
                    nothing,
                    NaN,
                    NaN,
                    NaN,
                    0,
                    0,
                    nothing,
                    nothing,
                    nothing,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    degree_time,
                    output_dir,
                    merge(
                        counts,
                        Dict{String,Any}(
                            "error_type" => "InadmissibleGridError",
                            "error_message" => sprint(showerror, e),
                        ),
                    ),
                )
            elseif e isa SolverTimeoutError
                @warn "Degree $degree timed out" limit = e.seconds elapsed = degree_time

                degree_result = DegreeResult(
                    degree,
                    "timeout",
                    0,  # n_critical_points
                    Vector{Vector{Float64}}(),
                    Vector{Float64}(),
                    nothing,
                    nothing,
                    nothing,
                    NaN,
                    NaN,
                    NaN,
                    0,
                    0,
                    nothing,
                    nothing,
                    nothing,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    degree_time,
                    output_dir,
                    Dict{String,Any}(
                        "error_type" => "SolverTimeoutError",
                        "error_message" => string(e),
                        "limit_seconds" => e.seconds,
                    ),
                )
            else
                @error "Degree $degree failed" exception = (e, catch_backtrace())

                # Capture rich error context for post-processing analysis
                error_context = Dict{String,Any}(
                    "error_message" => string(e),
                    "error_type" => string(typeof(e)),
                    "stacktrace" => string.(stacktrace(catch_backtrace())),
                    "degree" => degree,
                    "dimension" => length(bounds),
                    "GN" => experiment_config.GN,
                    "basis" => string(experiment_config.basis),
                    "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
                    "total_computation_time" => degree_time,
                )

                degree_result = DegreeResult(
                    degree,
                    "failed",
                    0,  # n_critical_points
                    Vector{Vector{Float64}}(),
                    Vector{Float64}(),
                    nothing,
                    nothing,
                    nothing,
                    NaN,
                    NaN,
                    NaN,
                    0,
                    0,
                    nothing,
                    nothing,
                    nothing,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    degree_time,
                    output_dir,
                    error_context,
                )
            end

            push!(degree_results, degree_result)
            _save_checkpoint(output_dir, degree_results, config_hash)
            stop_sweep && break
        end
    end

    # Keep the final ordering stable and matching experiment_config.degree_range
    # so downstream consumers see results in the expected order.
    sort!(degree_results, by = r -> r.degree)

    if census_out !== nothing
        metadata["box_strata_census"] =
            Dict{String,Any}(string(d) => v for (d, v) in sort(collect(census_out)))
    end
    if analyticity_out !== nothing && !isempty(analyticity_out)
        metadata["analyticity"] = Dict{String,Any}(
            string(d) => analyticity_summary(v) for (d, v) in sort(collect(analyticity_out); by = first)
        )
    end
    if cache_evaluations
        # unwrap the transform (if any), keep the cache
        cached = fit_objective isa TransformedObjective ? original_objective(fit_objective) : fit_objective
        if cached isa CachedObjective
            st = cache_stats(cached)
            metadata["evaluation_cache"] = Dict{String,Any}(
                "hits" => st.hits,
                "misses" => st.misses,
                "unique_points" => st.size,
                "hit_rate" => st.hit_rate,
            )
        end
    end
    if grad_errors !== nothing
        metadata["relative_gradient_error"] =
            Dict{String,Any}(string(d) => v for (d, v) in sort(collect(grad_errors)))
        metadata["gradient_weight"] = gradient_weight
        metadata["gradient_method"] = string(gradient_method)
    end
    metadata["gate_metric"] = string(gate_metric)

    if ladder && !haskey(metadata, "rel_l2_ladder")
        fv = rel_l2_final_verdict(
            _ladder_history(degree_results; metric = gate_grad ? grad_errors : nothing);
            thresholds = gate_thresholds,
            solve_below = gate_solve_below,
        )
        last_degree = isempty(degree_results) ? -1 : degree_results[end].degree
        _record_ladder!(
            metadata,
            fv.verdict,
            fv.reason,
            last_degree,
            degree_results,
            gate_thresholds,
            gate_solve_below;
            metric = gate_grad ? grad_errors : nothing,
        )
    end

    # Aligned frame: also write the raw critical points in physical coordinates.
    if aligned !== nothing
        for r in degree_results
            (r.status == "success" && !isempty(r.critical_points)) || continue
            n_cp = length(r.critical_points)
            phys = [to_physical(aligned, cp) for cp in r.critical_points]
            df = DataFrame(
                :index => 1:n_cp,
                [Symbol("p$i") => [phys[j][i] for j in 1:n_cp] for i in 1:length(bounds)]...,
                :objective => r.objective_values,
            )
            CSV.write(joinpath(output_dir, "critical_points_physical_deg_$(r.degree).csv"), df)
        end
    end

    # Generate results summary
    total_time = sum(r.total_computation_time for r in degree_results)
    success_count = count(r -> r.status == "success", degree_results)
    # Degrees the rel-L2 ladder fitted but deliberately did not solve are not failures.
    attempted = count(r -> r.status != "skipped_rel_l2", degree_results)
    success_rate = attempted == 0 ? 0.0 : success_count / attempted

    # Create experiment summary (Schema v3.0.0)
    experiment_summary = create_experiment_summary(
        degree_results,
        experiment_config,
        output_dir,
        metadata,
        total_critical_points,
        total_time,
        success_rate;
        objective_name = objective_name,
        bounds = bounds,
        true_params = true_params,
        solver = solver,
        msolve_threads = msolve_threads,
    )

    # Save experiment summary
    save_experiment_summary(experiment_summary, output_dir)

    # Remove checkpoint — full summary is now authoritative
    checkpoint_path = joinpath(output_dir, "checkpoint.jld2")
    isfile(checkpoint_path) && rm(checkpoint_path)

    # Provenance: one ledger record per run (in-dir ledger_record.json +
    # opportunistic append to experiments/ledger.jsonl). Metadata may carry
    # "ledger_slug", "issue_id", "supersedes", "config_path" to enrich the record.
    # A provenance failure must not discard hours of finished computation, so
    # it warns loudly instead of rethrowing.
    try
        Globtim.emit_ledger_record(;
            slug = string(get(metadata, "ledger_slug", objective_name)),
            outdir = output_dir,
            headline = Dict{String,Any}(
                "total_critical_points" => total_critical_points,
                "success_rate" => success_rate,
                "total_time_s" => total_time,
            ),
            config_path = get(metadata, "config_path", nothing),
            supersedes = String[string(s) for s in get(metadata, "supersedes", String[])],
            issue_id = get(metadata, "issue_id", nothing),
        )
    catch err
        @warn "ExperimentLedger: failed to emit ledger record — run has NO provenance entry" output_dir err
    end

    return experiment_summary
end

"""
    process_single_degree(degree, objective_function, TR, bounds,
                         experiment_config, output_dir, true_params) -> DegreeResult

Process a single polynomial degree through the complete pipeline.

# Arguments
- `degree::Int`: Polynomial degree to process
- `objective_function`: 1-argument objective callable f(x::Vector{Float64}) -> Float64
- `TR`: Pre-computed tensor representation from `Globtim.TestInput` (shared across degrees)
- `bounds`: Vector of (lower, upper) tuples
- `experiment_config`: Experiment parameters (basis, GN, etc.)
- `output_dir`: Directory for CSV output
- `true_params`: Known true parameters (optional, for recovery error)
"""
function process_single_degree(
    degree::Int,
    objective_function,
    TR,
    bounds::Vector{Tuple{Float64,Float64}},
    experiment_config,
    output_dir::String,
    true_params::Union{Vector{Float64},Nothing};
    solver::Symbol = :hc,
    start_system::Symbol = :auto,
    msolve_threads::Int = 1,
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing,
    msolve_coeff_tol::Float64 = 0.0,
    solve_rel_l2_max::Float64 = Inf,
    gate_metric::Symbol = :rel_l2,
    gradient_weight::Float64 = 0.0,
    gradient_method::Symbol = :forwarddiff,
    gradient_errors::Union{Nothing,Dict{Int,Float64}} = nothing,
    gradient_check_points::Int = 0,
    census_out::Union{Nothing,Dict{Int,Dict{String,Any}}} = nothing,
    admissibility::Bool = true,
    penalty_value::Union{Nothing,Real} = nothing,
    max_abs_value::Real = Inf,
    analyticity_out::Union{Nothing,Dict{Int,AnalyticityVerdict}} = nothing,
    analyticity_options::NamedTuple = (;),
    surrogate_dedup::Bool = true,
    surrogate_dedup_tol::Float64 = 1e-6,
)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]
    timing = Dict{String,Float64}()

    # Phase 1: Polynomial Construction (TR is pre-computed, only Constructor is degree-dependent)
    poly_construction_start = time()

    pol = Globtim.Constructor(
        TR,
        degree,
        basis = experiment_config.basis,
        normalized = false,
        gradient_weight = gradient_weight,
        gradient_method = gradient_method,
        admissibility = admissibility,
        penalty_value = penalty_value,
        max_abs_value = max_abs_value,
    )

    timing["polynomial_construction_time"] = time() - poly_construction_start
    timing["l2_approx_error"] = pol.nrm
    timing["relative_l2_error"] = relative_l2_error(pol)
    timing["condition_number"] = pol.cond_vandermonde
    if analyticity_out !== nothing
        # N7: on the fit as produced (before any chop), per axis
        av = analyticity_verdict(pol; analyticity_options...)
        analyticity_out[degree] = av
        timing["analyticity_n_offending_axes"] = Float64(count(av.offending))
        if av.verdict == :non_analytic
            @warn "  Analyticity: axis $(findall(av.offending)) decays algebraically at degree $degree " *
                  "(rate $(round.(av.decay_rate, digits=3)), exponent $(round.(av.algebraic_exponent, digits=2))); " *
                  "suggested subdivision axis $(av.suggested_axis)"
        end
    end
    if gradient_errors !== nothing
        # Against the objective the fit saw (cached / transformed), not the raw one:
        # under a value transform ∇(g∘f) ≠ ∇f and the comparison would be meaningless.
        gradient_errors[degree] = relative_gradient_error(
            pol,
            TR.objective;
            method = gradient_method,
            n_points = gradient_check_points,
        )
    end

    # Solve gate: a fit whose gate metric is above solve_rel_l2_max is not solved — its
    # critical points are not yet those of f. Recorded, not failed. The metric is the
    # relative L2 error (quality_thresholds.toml) or, with gate_metric = :rel_grad, the
    # relative gradient error just computed (N1, EVIDENCE_MAP_2026-10.md).
    rel = timing["relative_l2_error"]
    gate_value = if gate_metric == :rel_grad
        gradient_errors === nothing && error(
            "gate_metric = :rel_grad requires the gradient check (gradient_errors === nothing)",
        )
        gradient_errors[degree]
    else
        rel
    end
    if !(gate_value <= solve_rel_l2_max)
        @debug "Degree $degree fitted, not solved: $(gate_metric) $(gate_value) > $(solve_rel_l2_max)"
        return DegreeResult(
            degree,
            "skipped_rel_l2",
            0,
            Vector{Vector{Float64}}(),
            Vector{Float64}(),
            nothing,
            nothing,
            nothing,
            timing["l2_approx_error"],
            rel,
            timing["condition_number"],
            length(pol.coeffs),
            count(!iszero, pol.coeffs),
            nothing,
            nothing,
            nothing,
            timing["polynomial_construction_time"],
            0.0,
            0.0,
            0.0,
            timing["polynomial_construction_time"],
            output_dir,
            Dict{String,Any}(
                "skip_reason" => string(gate_metric, "_above_solve_threshold"),
                "gate_metric" => string(gate_metric),
                "gate_value" => gate_value,
                "relative_l2_error" => rel,
                "relative_gradient_error" =>
                    gradient_errors === nothing ? NaN : get(gradient_errors, degree, NaN),
                "solve_rel_l2_max" => solve_rel_l2_max,
                "rel_l2_band" => string(classify_rel_l2(rel)),
            ),
        )
    end

    # Phase 1b: Optional coefficient truncation — automatic (noise-floor chop) or manual
    if experiment_config.truncation_mode == :auto
        chop = Globtim.chop_polynomial(pol)
        est = chop.estimate
        timing["chop_plateau_found"] = est.plateau_found ? 1.0 : 0.0
        timing["chop_usable_degree"] = Float64(est.usable_degree)
        timing["chop_decay_rate"] = est.decay_rate
        timing["chop_floor"] = est.floor
        timing["chop_relative_floor"] = est.relative_floor
        timing["truncation_original_nnz"] = chop.original_nnz
        timing["truncation_new_nnz"] = chop.new_nnz
        timing["truncation_l2_ratio"] = chop.l2_ratio
        if est.plateau_found
            @info "  Chop: noise floor $(est.floor) (relative $(est.relative_floor)), " *
                  "usable total degree $(est.usable_degree), decay $(round(est.decay_rate, digits=3))/degree: " *
                  "$(chop.original_nnz) → $(chop.new_nnz) coefficients (L² ratio $(round(chop.l2_ratio, digits=6)))"
            pol = chop.polynomial
        else
            @info "  Chop: no noise plateau at degree $degree (still converging, decay " *
                  "$(round(est.decay_rate, digits=3))/degree); nothing removed"
        end
    elseif experiment_config.truncation_threshold !== nothing
        sparse_result = Globtim.sparsify_polynomial(
            pol,
            experiment_config.truncation_threshold,
            mode = experiment_config.truncation_mode,
        )
        @info "  Truncation (threshold=$(experiment_config.truncation_threshold), " *
              "mode=$(experiment_config.truncation_mode)): " *
              "$(sparse_result.original_nnz) → $(sparse_result.new_nnz) coefficients " *
              "(L² ratio: $(round(sparse_result.l2_ratio, digits=6)))"
        pol = sparse_result.polynomial
        timing["truncation_original_nnz"] = sparse_result.original_nnz
        timing["truncation_new_nnz"] = sparse_result.new_nnz
        timing["truncation_l2_ratio"] = sparse_result.l2_ratio
    end

    # Phase 1c: closed Poincaré–Hopf census of the surrogate on the box (opt-in)
    if census_out !== nothing
        c = box_strata_census(pol)
        census_out[degree] = Dict{String,Any}(
            "sum" => c.sum,
            "ok" => c.ok,
            "exact" => c.exact,
            "n_counted" => c.n_counted,
            "n_interior" => c.n_interior,
            "n_boundary_counted" => c.n_boundary_counted,
            "n_ambiguous" => c.n_ambiguous,
            "n_singular_faces" => c.n_singular_faces,
            "n_degenerate_faces" => c.n_degenerate_faces,
        )
    end

    # Phase 2: Critical Point Solving + coordinate transformation
    critical_points_array, solve_time = solve_and_transform(
        pol,
        bounds;
        solver = solver,
        start_system = start_system,
        msolve_threads = msolve_threads,
        msolve_timeout_seconds = msolve_timeout_seconds,
        msolve_coeff_tol = msolve_coeff_tol,
    )
    n_critical_points = length(critical_points_array)
    timing["critical_point_solving_time"] = solve_time

    # ERROR if no critical points found
    if n_critical_points == 0
        error("CRITICAL: No critical points found by HomotopyContinuation")
    end

    @info "Found $n_critical_points raw critical points at degree $degree"

    # Phase 3: Use raw critical points (refinement moved to globtimpostprocessing)
    processing_start = time()

    # Compute objective values at critical points (in original coordinates)
    objective_values =
        [objective_function(critical_points_array[i]) for i in 1:n_critical_points]

    # Find best estimate (lowest objective value, even if outside domain)
    best_idx = argmin(objective_values)
    best_estimate = critical_points_array[best_idx]
    best_objective = objective_values[best_idx]

    # Compute recovery error if true params provided
    recovery_error = if true_params !== nothing
        norm(best_estimate - true_params)
    else
        nothing
    end

    # N5 (surrogate_dedup.jl): polish every raw root on the surrogate and cluster the
    # polished points, so the refinement on f downstream starts once per cluster. The
    # raw census above is untouched; the clusters are recorded as CSV columns.
    dedup = nothing
    if surrogate_dedup
        points_box = [(pt .- center) ./ sample_range for pt in critical_points_array]
        dedup = dedupe_on_surrogate(pol, points_box; tol = surrogate_dedup_tol)
        timing["n_surrogate_clusters"] = Float64(dedup.n_clusters)
        timing["n_surrogate_polish_converged"] = Float64(dedup.n_converged)
        timing["surrogate_polish_max_move"] = isempty(dedup.moved) ? 0.0 : maximum(dedup.moved)
        if dedup.n_clusters < n_critical_points
            @info "  Surrogate dedup: $n_critical_points raw roots → $(dedup.n_clusters) clusters " *
                  "(largest $(maximum(dedup.cluster_size)); polish moved ≤ $(round(maximum(dedup.moved), sigdigits=2)) in box units)"
        end
    end

    timing["critical_point_processing_time"] = time() - processing_start

    # Phase 4: CSV Export (raw critical points only)
    io_start = time()

    # Create DataFrame with raw critical points
    df_critical = DataFrame(
        :index => 1:n_critical_points,
        [
            Symbol("p$i") => [critical_points_array[j][i] for j in 1:n_critical_points]
            for i in 1:dimension
        ]...,
        :objective => objective_values,
    )
    if dedup !== nothing
        df_critical[!, :cluster_id] = dedup.cluster_id
        df_critical[!, :cluster_size] = dedup.cluster_size
        df_critical[!, :representative] = Int.(dedup.representative)
        df_critical[!, :surrogate_polish_move] = dedup.moved
    end

    # Export raw critical points (add '_raw' suffix for globtimpostprocessing)
    csv_path = joinpath(output_dir, "critical_points_raw_deg_$degree.csv")
    CSV.write(csv_path, df_critical)

    timing["file_io_time"] = time() - io_start

    # Calculate total time
    total_time = (
        timing["polynomial_construction_time"] +
        timing["critical_point_solving_time"] +
        timing["critical_point_processing_time"] +
        timing["file_io_time"]
    )

    # Extract truncation metrics (nothing if no truncation was applied)
    trunc_original = get(timing, "truncation_original_nnz", nothing)
    trunc_new = get(timing, "truncation_new_nnz", nothing)
    trunc_l2 = get(timing, "truncation_l2_ratio", nothing)

    return DegreeResult(
        degree,
        "success",
        n_critical_points,
        critical_points_array,
        objective_values,
        best_estimate,
        best_objective,
        recovery_error,
        timing["l2_approx_error"],
        timing["relative_l2_error"],
        timing["condition_number"],
        length(pol.coeffs),
        count(!iszero, pol.coeffs),
        trunc_original,
        trunc_new,
        trunc_l2,
        timing["polynomial_construction_time"],
        timing["critical_point_solving_time"],
        timing["critical_point_processing_time"],
        timing["file_io_time"],
        total_time,
        output_dir,
        nothing,
    )
end

"""
Create experiment summary (Schema v3.0.0: full experiment definition).

Stores the complete experiment definition — objective identity, domain, solver config —
alongside per-degree results. This makes experiment outputs self-describing for
parameter sweep analysis across multiple batches.
"""
function create_experiment_summary(
    degree_results::Vector{DegreeResult},
    experiment_config,
    output_dir::String,
    metadata::Dict{String,Any},
    total_critical_points::Int,
    total_time::Float64,
    success_rate::Float64;
    objective_name::String,
    bounds::Vector{Tuple{Float64,Float64}},
    true_params::Union{Vector{Float64},Nothing} = nothing,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
)
    # Build results_summary dict
    results_summary = Dict{String,Any}()

    for result in degree_results
        results_summary["degree_$(result.degree)"] = Dict(
            # Critical point results (raw only)
            "n_critical_points" => result.n_critical_points,
            "status" => result.status,

            # Best estimate (always present)
            "best_estimate" => result.best_estimate,
            "best_objective" => result.best_objective,
            "recovery_error" => result.recovery_error,

            # Quality metrics
            "l2_approx_error" => result.l2_approx_error,
            "relative_l2_error" => result.relative_l2_error,
            "condition_number" => result.condition_number,

            # Coefficient counts
            "n_total_coeffs" => result.n_total_coeffs,
            "support_size" => result.support_size,

            # Truncation/sparsity metrics
            "truncation_original_nnz" => result.truncation_original_nnz,
            "truncation_new_nnz" => result.truncation_new_nnz,
            "truncation_l2_ratio" => result.truncation_l2_ratio,

            # Timing breakdown
            "polynomial_construction_time" => result.polynomial_construction_time,
            "critical_point_solving_time" => result.critical_point_solving_time,
            "critical_point_processing_time" => result.critical_point_processing_time,
            "file_io_time" => result.file_io_time,
            "total_computation_time" => result.total_computation_time,

            # Output location
            "output_dir" => result.output_dir,

            # Error (if failed)
            "error" => result.error,
        )
    end

    # Experiment definition: what problem was solved
    experiment_definition = Dict{String,Any}(
        "objective_name" => objective_name,
        "dimension" => length(bounds),
        "bounds" => [[lb, ub] for (lb, ub) in bounds],
        "true_params" => true_params,
    )

    # Solver config: how it was solved (full ExperimentParams)
    solver_config = Dict{String,Any}(
        "GN" => experiment_config.GN,
        "degree_range" => collect(experiment_config.degree_range),
        "domain_size" => experiment_config.domain_size,
        "max_time" => experiment_config.max_time,
        "basis" => string(experiment_config.basis),
        "optim_f_tol" => experiment_config.optim_f_tol,
        "optim_x_tol" => experiment_config.optim_x_tol,
        "max_iterations" => experiment_config.max_iterations,
        "solver" => string(solver),
        "msolve_threads" => msolve_threads,
    )

    GN = experiment_config.GN
    degree_range = collect(experiment_config.degree_range)
    domain_size_param = experiment_config.domain_size
    max_time = experiment_config.max_time
    params_dict = @dict GN degree_range domain_size_param max_time

    # Build experiment summary
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    experiment_id = basename(output_dir)

    summary = @dict(
        experiment_id,
        experiment_definition,
        solver_config,
        params_dict,
        results_summary,
        total_critical_points,
        total_time,
        timestamp,
        output_dir
    )

    # Add user-provided metadata
    if !isempty(metadata)
        summary[:user_metadata] = metadata
    end

    # Schema version and computed statistics
    summary[:schema_version] = "3.0.0"
    summary[:degrees_processed] = length(degree_results)
    summary[:success_rate] = success_rate
    summary[:degree_results] = degree_results
    summary[:total_critical_points] = total_critical_points

    return summary
end

"""
Sanitize dictionary for JSON serialization by replacing NaN/Inf with nothing.
Handles nested structures including DegreeResult objects.
"""
function sanitize_for_json(obj)
    if obj isa Dict
        return Dict(k => sanitize_for_json(v) for (k, v) in obj)
    elseif obj isa AbstractArray
        return [sanitize_for_json(v) for v in obj]
    elseif obj isa DegreeResult
        # Convert DegreeResult to Dict and sanitize (Phase 2: simplified)
        return Dict(
            "degree" => obj.degree,
            "status" => obj.status,
            "n_critical_points" => obj.n_critical_points,
            "critical_points" => sanitize_for_json(obj.critical_points),
            "objective_values" => sanitize_for_json(obj.objective_values),
            "best_estimate" => sanitize_for_json(obj.best_estimate),
            "best_objective" => sanitize_for_json(obj.best_objective),
            "recovery_error" => sanitize_for_json(obj.recovery_error),
            "l2_approx_error" => sanitize_for_json(obj.l2_approx_error),
            "relative_l2_error" => sanitize_for_json(obj.relative_l2_error),
            "condition_number" => sanitize_for_json(obj.condition_number),
            "n_total_coeffs" => obj.n_total_coeffs,
            "support_size" => obj.support_size,
            "truncation_original_nnz" => obj.truncation_original_nnz,
            "truncation_new_nnz" => obj.truncation_new_nnz,
            "truncation_l2_ratio" => sanitize_for_json(obj.truncation_l2_ratio),
            "polynomial_construction_time" =>
                sanitize_for_json(obj.polynomial_construction_time),
            "critical_point_solving_time" =>
                sanitize_for_json(obj.critical_point_solving_time),
            "critical_point_processing_time" =>
                sanitize_for_json(obj.critical_point_processing_time),
            "file_io_time" => sanitize_for_json(obj.file_io_time),
            "total_computation_time" => sanitize_for_json(obj.total_computation_time),
            "output_dir" => obj.output_dir,
            "error" => sanitize_for_json(obj.error),
        )
    elseif obj isa Float64 || obj isa Float32
        if isnan(obj) || isinf(obj)
            return nothing
        end
        return obj
    else
        return obj
    end
end

"""
Save experiment summary to JSON and JLD2 with Git provenance.
"""
function save_experiment_summary(summary::Dict, output_dir::String)
    # Save JSON (human readable) - sanitize NaN/Inf first
    json_path = joinpath(output_dir, "results_summary.json")
    sanitized_summary = sanitize_for_json(summary)
    open(json_path, "w") do f
        JSON3.pretty(f, sanitized_summary)
    end

    # Save JLD2 with Git provenance (DrWatson) - convert symbols to strings for JLD2
    jld2_path = joinpath(output_dir, "results_summary.jld2")
    summary_for_jld2 = Dict{String,Any}(string(k) => v for (k, v) in summary)
    tagsave(jld2_path, summary_for_jld2; warn = false)
end

"""
Print timing breakdown for a degree result (Phase 2: no refinement).
"""
function print_degree_summary(result::DegreeResult)
    total = result.total_computation_time
    @info "Degree $(result.degree): $(round(total, digits=2))s [poly=$(round(result.polynomial_construction_time, digits=2))s, solve=$(round(result.critical_point_solving_time, digits=2))s, process=$(round(result.critical_point_processing_time, digits=2))s]"
end

end  # module StandardExperiment
