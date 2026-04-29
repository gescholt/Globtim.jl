"""
TOML Experiment Configuration Loader

Parses TOML config files into `ExperimentPipelineConfig` for use with
`run_standard_experiment()` and external orchestrators.

This module lives in Globtim with no external dependencies.
Domain-specific orchestration is handled by downstream packages.

Created: 2026-02-09
"""

# ═══════════════════════════════════════════════════════════════════════════════
# ExperimentPipelineConfig
# ═══════════════════════════════════════════════════════════════════════════════

"""
    ExperimentPipelineConfig

Flat configuration struct parsed from a TOML experiment file.
Maps directly to `run_standard_experiment()` args + catalogue integration.

# Sections (matching TOML layout)

- `[experiment]`: name, description
- `[model]`: catalogue_path + entry_name (catalogue) OR analytical_function + dimension (built-in)
  Optional: time_interval (override catalogue default, catalogue mode only)
  Optional: sample_times (explicit time sample points, overrides time_interval + numpoints)
- `[domain]`: radius (symmetric) OR radii (anisotropic) OR bounds (explicit)
- `[polynomial]`: GN, degree_range, basis, truncation_threshold (opt-in), truncation_mode
- `[solver]`: solver overrides (optional)
- `[refinement]`: post-processing refinement (optional)
- `[analysis]`: Newton CP refinement and classification (optional)
- `[subdivision]`: adaptive-subdivision strategy defaults (optional, svdr)
- `[grid_scoring]`: interestingness scoring thresholds + catalogue list (optional, 0thk)
- `[screening]`: screen_and_probe parameters + model factory (optional, 20p7)
- `[visualization]`: level set / landscape visualization parameters (optional)
- `[output]`: output_dir (optional)
"""
Base.@kwdef struct ExperimentPipelineConfig
    # [experiment]
    name::String
    description::String = ""

    # [model] — exactly one mode: catalogue XOR analytical
    catalogue_path::Union{Nothing,String} = nothing
    entry_name::Union{Nothing,String} = nothing
    analytical_function::Union{Nothing,String} = nothing
    dimension::Union{Nothing,Int} = nothing
    time_interval::Union{Nothing,Vector{Float64}} = nothing  # override catalogue default
    sample_times::Union{Nothing,Vector{Float64}} = nothing   # explicit time sample points (overrides time_interval + numpoints)
    p_true::Union{Nothing,Vector{Float64}} = nothing         # override catalogue p_true

    # [domain] — exactly one mode: radius XOR radii XOR bounds
    radius::Union{Nothing,Float64} = nothing
    radii::Union{Nothing,Vector{Float64}} = nothing
    bounds::Union{Nothing,Vector{Tuple{Float64,Float64}}} = nothing
    p_center::Union{Nothing,Vector{Float64}} = nothing       # domain center (default: p_true)

    # [polynomial]
    GN::Int
    degree_range::StepRange{Int,Int}
    basis::Symbol = :chebyshev
    truncation_threshold::Union{Nothing,Float64} = nothing  # opt-in coefficient truncation
    truncation_mode::Symbol = :relative                      # :relative or :absolute

    # [polynomial] — cluster timeout protection (dljm)
    degree_timeout_seconds::Union{Nothing,Float64} = nothing  # per-degree wall-clock limit
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing  # per-msolve-call process limit

    # [solver] — optional solver overrides
    solver_method::Union{Nothing,String} = nothing
    solver_abstol::Union{Nothing,Float64} = nothing
    solver_reltol::Union{Nothing,Float64} = nothing
    solver_numpoints::Union{Nothing,Int} = nothing

    # [refinement] — optional post-processing
    refinement_enabled::Bool = false
    refinement_method::Union{Nothing,String} = nothing
    refinement_max_time::Union{Nothing,Float64} = nothing
    refinement_gradient_method::Union{Nothing,String} = nothing
    refinement_gradient_tolerance::Union{Nothing,Float64} = nothing
    refinement_step_tolerance::Union{Nothing,Float64} = nothing

    # [analysis] — optional CP refinement and classification
    analysis_enabled::Bool = false
    analysis_refinement_goal::Union{Nothing,String} = nothing  # "minimum" or "critical_point"
    analysis_gradient_method::Union{Nothing,String} = nothing
    analysis_newton_tol::Union{Nothing,Float64} = nothing
    analysis_newton_max_iterations::Union{Nothing,Int} = nothing
    analysis_max_time_per_point::Union{Nothing,Float64} = nothing
    analysis_hessian_tol::Union{Nothing,Float64} = nothing
    analysis_dedup_fraction::Union{Nothing,Float64} = nothing
    analysis_top_k::Union{Nothing,Int} = nothing
    analysis_accept_tol::Union{Nothing,Float64} = nothing
    analysis_f_accept_tol::Union{Nothing,Float64} = nothing
    analysis_newton_patience::Union{Nothing,Int} = nothing
    analysis_newton_min_improvement::Union{Nothing,Float64} = nothing
    analysis_f_accept_tol_multiplier::Union{Nothing,Float64} = nothing
    analysis_valley_walking::Bool = false
    analysis_deep_diagnostics::Bool = false

    # [subdivision] — optional adaptive-subdivision defaults (svdr)
    # Strategies use Globtim symbol names for stability; see KNOWN_SUBDIVISION_STRATEGIES.
    subdivision_strategy::Union{Nothing,String} = nothing
    subdivision_degree::Union{Nothing,Int} = nothing
    subdivision_max_degree::Union{Nothing,Int} = nothing
    subdivision_l2_tolerance::Union{Nothing,Float64} = nothing
    subdivision_max_depth::Union{Nothing,Int} = nothing
    subdivision_max_leaves::Union{Nothing,Int} = nothing
    subdivision_basis::Union{Nothing,Symbol} = nothing

    # [grid_scoring] — optional grid-based interestingness scoring defaults (0thk)
    # Used by experiments/sandbox/run_grid_scoring.jl when the script is given a
    # TOML config; otherwise the script falls back to its hardcoded list + thresholds.
    grid_scoring_points_per_dim::Union{Nothing,Int} = nothing
    grid_scoring_numpoints::Union{Nothing,Int} = nothing
    grid_scoring_interestingness_threshold::Union{Nothing,Float64} = nothing
    grid_scoring_negative_control_threshold::Union{Nothing,Float64} = nothing
    grid_scoring_min_local_minima::Union{Nothing,Int} = nothing
    grid_scoring_catalogue_files::Union{Nothing,Vector{String}} = nothing

    # [screening] — optional screen_and_probe parameters (20p7)
    # Drives the `pkg/Dynamic_objectives/scripts/run_screening.jl` entry point;
    # `model_factory` must resolve through Dynamic_objectives.MODEL_REGISTRY.
    screening_model_factory::Union{Nothing,String} = nothing
    screening_ic::Union{Nothing,Vector{Float64}} = nothing
    screening_bounds::Union{Nothing,Vector{Tuple{Float64,Float64}}} = nothing
    screening_time_interval::Union{Nothing,Vector{Float64}} = nothing
    screening_catalogue_path::Union{Nothing,String} = nothing
    screening_name_prefix::Union{Nothing,String} = nothing
    screening_description::Union{Nothing,String} = nothing
    screening_n_candidates::Union{Nothing,Int} = nothing
    screening_n_probes::Union{Nothing,Int} = nothing
    screening_top_n::Union{Nothing,Int} = nothing
    screening_numpoints_screen::Union{Nothing,Int} = nothing
    screening_numpoints_probe::Union{Nothing,Int} = nothing
    screening_min_finite_fraction::Union{Nothing,Float64} = nothing
    screening_max_noise_ratio::Union{Nothing,Float64} = nothing
    screening_ranking_strategy::Union{Nothing,String} = nothing
    screening_solver::Union{Nothing,String} = nothing

    # [output]
    output_dir::Union{Nothing,String} = nothing

    # [visualization] — optional level set / landscape visualization
    viz_enabled::Bool = false
    viz_n_coarse::Int = 10
    viz_n_refine::Int = 2
    viz_level_max::Float64 = 1.0
    viz_domain_mode::Symbol = :catalogue       # :catalogue or :tight
    viz_tight_frac::Float64 = 0.1
    viz_level_tol::Float64 = 0.005
    viz_figure_size::Tuple{Int,Int} = (1200, 900)
    viz_record_animation::Bool = false
    viz_animation_fps::Int = 30
    viz_animation_duration::Int = 15
    viz_augment_enabled::Bool = true
    viz_augment_fraction::Float64 = 0.25
    viz_augment_n::Int = 4
    viz_near_zero_enabled::Bool = true
    viz_near_zero_threshold::Float64 = 0.5
    viz_near_zero_n::Int = 8
end

# ═══════════════════════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════════════════════

const KNOWN_SOLVER_METHODS = Set([
    "Tsit5",
    "Vern7",
    "Vern9",
    "Rodas5",
    "Rosenbrock23",
    "AutoTsit5",
    "TRBDF2",
    "KenCarp4",
])

const KNOWN_REFINEMENT_METHODS = Set(["NelderMead", "BFGS"])

const KNOWN_GRADIENT_METHODS = Set(["forwarddiff", "finitediff"])

# Globtim canonical strategy symbols, kept aligned with experiments/sandbox/
# adaptive_subdivision_experiment.jl::run_strategy_comparison.
const KNOWN_SUBDIVISION_STRATEGIES = Set([
    "baseline",
    "B_iso",
    "B_aniso",
    "two_phase",
    "uniform_grid",
    "multi_start",
    "adaptive_interleaved",
])

const KNOWN_SUBDIVISION_BASES = Set(["chebyshev", "legendre"])

# Screening rankings (20p7). Only `dynamic_range` exists today; field is
# forward-looking so future strategies (variance, basin_count, etc.) can land
# without changing the TOML schema.
const KNOWN_SCREENING_RANKING_STRATEGIES = Set(["dynamic_range"])

# Screening ODE solvers — string keys mapped to OrdinaryDiffEq solver objects
# in the Dynamic_objectives screening driver. New entries must be added in
# both this set AND the driver's `_resolve_solver` switch.
const KNOWN_SCREENING_SOLVERS = Set([
    "Tsit5",
    "AutoTsit5_Rosenbrock23",
    "Vern7",
    "Vern9",
    "Rosenbrock23",
    "Rodas5",
    "TRBDF2",
])

"""
    validate_experiment_toml(d::Dict)

Validate a parsed TOML dict before constructing ExperimentPipelineConfig.
Collects all errors and raises them together.
"""
function validate_experiment_toml(d::Dict)
    errors = String[]

    # --- Required sections ---
    haskey(d, "experiment") || push!(errors, "Missing required section [experiment]")
    haskey(d, "model") || push!(errors, "Missing required section [model]")
    haskey(d, "polynomial") || push!(errors, "Missing required section [polynomial]")

    # Bail early if required sections are missing — can't validate further
    if !isempty(errors)
        error("TOML validation failed:\n  " * join(errors, "\n  "))
    end

    exp = d["experiment"]
    mod = d["model"]
    poly = d["polynomial"]
    dom = get(d, "domain", Dict())
    sol = get(d, "solver", Dict())
    ref = get(d, "refinement", Dict())

    # --- [domain] mode flags (needed early for cross-validation) ---
    has_radius = haskey(dom, "radius")
    has_radii = haskey(dom, "radii")
    has_bounds = haskey(dom, "bounds")
    n_domain_modes = count([has_radius, has_radii, has_bounds])

    # --- [experiment] ---
    haskey(exp, "name") || push!(errors, "[experiment] missing required field 'name'")

    # --- [model] mode validation ---
    has_catalogue = haskey(mod, "catalogue_path") || haskey(mod, "entry_name")
    has_analytical = haskey(mod, "analytical_function")

    if has_catalogue && has_analytical
        push!(
            errors,
            "[model] cannot specify both catalogue (catalogue_path/entry_name) and analytical_function",
        )
    elseif !has_catalogue && !has_analytical
        push!(
            errors,
            "[model] must specify either catalogue_path+entry_name or analytical_function",
        )
    elseif has_catalogue
        haskey(mod, "catalogue_path") ||
            push!(errors, "[model] catalogue mode requires 'catalogue_path'")
        haskey(mod, "entry_name") ||
            push!(errors, "[model] catalogue mode requires 'entry_name'")
    elseif has_analytical
        haskey(mod, "dimension") ||
            push!(errors, "[model] analytical mode requires 'dimension'")
        # Validate function name against FUNCTION_REGISTRY
        if haskey(mod, "analytical_function")
            known = known_analytical_function_names()
            fname = mod["analytical_function"]
            if !(lowercase(fname) in [lowercase(n) for n in known])
                push!(
                    errors,
                    "[model] unknown analytical_function \"$fname\". Known: $(join(known, ", "))",
                )
            end
        end
    end

    # Validate p_true (only valid in catalogue mode)
    if haskey(mod, "p_true")
        if has_analytical
            push!(
                errors,
                "[model] p_true is only valid in catalogue mode, not with analytical_function",
            )
        else
            pt = mod["p_true"]
            if !(pt isa AbstractVector && all(x -> x isa Number, pt))
                push!(errors, "[model] p_true must be a numeric array, got: $pt")
            end
        end
    end

    # Validate p_center (only meaningful with radius/radii domain modes)
    if haskey(dom, "p_center")
        pc = dom["p_center"]
        if !(pc isa AbstractVector && all(x -> x isa Number, pc))
            push!(errors, "[domain] p_center must be a numeric array, got: $pc")
        end
        if has_bounds
            push!(
                errors,
                "[domain] p_center is not used with explicit bounds (bounds already define the domain)",
            )
        end
        if !has_radius && !has_radii && !has_catalogue
            push!(errors, "[domain] p_center requires radius or radii to define the domain")
        end
    end

    # Validate time_interval override (only valid in catalogue mode)
    if haskey(mod, "time_interval")
        if has_analytical
            push!(
                errors,
                "[model] time_interval is only valid in catalogue mode, not with analytical_function",
            )
        else
            ti = mod["time_interval"]
            if !(ti isa AbstractVector && length(ti) == 2)
                push!(errors, "[model] time_interval must be [start, end], got: $ti")
            elseif !(ti[1] isa Number && ti[2] isa Number)
                push!(errors, "[model] time_interval values must be numbers")
            elseif ti[2] <= ti[1]
                push!(
                    errors,
                    "[model] time_interval end ($(ti[2])) must be > start ($(ti[1]))",
                )
            end
        end
    end

    # Validate sample_times (only valid in catalogue mode, conflicts with time_interval)
    if haskey(mod, "sample_times")
        if has_analytical
            push!(
                errors,
                "[model] sample_times is only valid in catalogue mode, not with analytical_function",
            )
        elseif haskey(mod, "time_interval")
            push!(
                errors,
                "[model] cannot specify both sample_times and time_interval (sample_times implies the time interval)",
            )
        else
            st = mod["sample_times"]
            if !(st isa AbstractVector && length(st) >= 2)
                push!(
                    errors,
                    "[model] sample_times must be an array with at least 2 time points, got: $st",
                )
            elseif !all(x -> x isa Number, st)
                push!(errors, "[model] sample_times values must be numbers")
            else
                st_sorted = sort(Float64.(st))
                if st_sorted != Float64.(st)
                    push!(errors, "[model] sample_times must be in ascending order")
                end
                if st_sorted[end] <= st_sorted[1]
                    push!(errors, "[model] sample_times must span a non-zero time interval")
                end
            end
        end
    end

    # Cross-validate bounds dimension matches declared dimension
    if has_analytical && haskey(mod, "dimension") && has_bounds
        dim = mod["dimension"]
        b = dom["bounds"]
        if b isa AbstractVector && length(b) != dim
            push!(
                errors,
                "[domain] bounds has $(length(b)) entries but [model] dimension is $dim",
            )
        end
    end

    # --- [domain] mode validation ---
    if n_domain_modes == 0 && !has_catalogue
        push!(
            errors,
            "[domain] must specify one of: radius, radii, or bounds (required for analytical models)",
        )
    elseif n_domain_modes > 1
        push!(
            errors,
            "[domain] must specify exactly one of: radius, radii, or bounds (got $(n_domain_modes))",
        )
    end

    if has_radius
        r = dom["radius"]
        (r isa Number && r > 0) ||
            push!(errors, "[domain] radius must be a positive number, got: $r")
    end

    if has_radii
        r = dom["radii"]
        if !(r isa AbstractVector)
            push!(errors, "[domain] radii must be an array of positive numbers")
        elseif any(x -> !(x isa Number && x > 0), r)
            push!(errors, "[domain] all radii must be positive numbers")
        end
    end

    if has_bounds
        b = dom["bounds"]
        if !(b isa AbstractVector)
            push!(errors, "[domain] bounds must be an array of [lo, hi] pairs")
        else
            for (i, pair) in enumerate(b)
                if !(pair isa AbstractVector && length(pair) == 2)
                    push!(errors, "[domain] bounds[$i] must be a [lo, hi] pair")
                elseif pair[1] >= pair[2]
                    push!(
                        errors,
                        "[domain] bounds[$i]: lo ($(pair[1])) must be < hi ($(pair[2]))",
                    )
                end
            end
        end
    end

    # --- [polynomial] ---
    if haskey(poly, "GN")
        gn = poly["GN"]
        (gn isa Integer && 2 <= gn <= 100) ||
            push!(errors, "[polynomial] GN must be an integer in [2, 100], got: $gn")
    else
        push!(errors, "[polynomial] missing required field 'GN'")
    end

    if haskey(poly, "degree_range")
        dr = poly["degree_range"]
        if !(dr isa AbstractVector && length(dr) == 3)
            push!(errors, "[polynomial] degree_range must be [start, step, stop], got: $dr")
        else
            if any(x -> !(x isa Integer), dr)
                push!(errors, "[polynomial] degree_range values must be integers")
            elseif dr[1] < 1
                push!(errors, "[polynomial] degree_range start must be >= 1, got: $dr")
            elseif dr[1] > dr[3]
                push!(
                    errors,
                    "[polynomial] degree_range start ($(dr[1])) must be <= stop ($(dr[3]))",
                )
            elseif dr[2] < 1
                push!(errors, "[polynomial] degree_range step must be >= 1, got: $(dr[2])")
            end
        end
    else
        push!(errors, "[polynomial] missing required field 'degree_range'")
    end

    if haskey(poly, "basis")
        b = poly["basis"]
        b in ["chebyshev", "legendre"] ||
            push!(errors, "[polynomial] basis must be 'chebyshev' or 'legendre', got: '$b'")
    end

    if haskey(poly, "truncation_threshold")
        t = poly["truncation_threshold"]
        (t isa Number && t > 0) ||
            push!(errors, "[polynomial] truncation_threshold must be positive, got: $t")
    end
    if haskey(poly, "truncation_mode")
        m = poly["truncation_mode"]
        m in ["relative", "absolute"] || push!(
            errors,
            "[polynomial] truncation_mode must be 'relative' or 'absolute', got: '$m'",
        )
    end

    # --- [solver] (optional) ---
    if haskey(sol, "method")
        sol["method"] in KNOWN_SOLVER_METHODS || push!(
            errors,
            "[solver] unknown method '$(sol["method"])'. Known: $(join(sort(collect(KNOWN_SOLVER_METHODS)), ", "))",
        )
    end
    if haskey(sol, "abstol")
        (sol["abstol"] isa Number && sol["abstol"] > 0) ||
            push!(errors, "[solver] abstol must be positive")
    end
    if haskey(sol, "reltol")
        (sol["reltol"] isa Number && sol["reltol"] > 0) ||
            push!(errors, "[solver] reltol must be positive")
    end
    if haskey(sol, "numpoints")
        np = sol["numpoints"]
        (np isa Integer && 5 <= np <= 1000) ||
            push!(errors, "[solver] numpoints must be an integer in [5, 1000], got: $np")
    end

    # --- [analysis] (optional — Newton CP validation) ---
    ana = get(d, "analysis", Dict())
    if haskey(ana, "gradient_method")
        ana["gradient_method"] in KNOWN_GRADIENT_METHODS || push!(
            errors,
            "[analysis] unknown gradient_method '$(ana["gradient_method"])'. Known: $(join(sort(collect(KNOWN_GRADIENT_METHODS)), ", "))",
        )
    end
    if haskey(ana, "newton_tol")
        (ana["newton_tol"] isa Number && ana["newton_tol"] > 0) ||
            push!(errors, "[analysis] newton_tol must be positive")
    end
    if haskey(ana, "newton_max_iterations")
        nmi = ana["newton_max_iterations"]
        (nmi isa Integer && nmi > 0) || push!(
            errors,
            "[analysis] newton_max_iterations must be a positive integer, got: $nmi",
        )
    end
    if haskey(ana, "hessian_tol")
        (ana["hessian_tol"] isa Number && ana["hessian_tol"] > 0) ||
            push!(errors, "[analysis] hessian_tol must be positive")
    end
    if haskey(ana, "dedup_fraction")
        df = ana["dedup_fraction"]
        (df isa Number && 0 < df < 1) ||
            push!(errors, "[analysis] dedup_fraction must be in (0, 1), got: $df")
    end
    if haskey(ana, "accept_tol")
        (ana["accept_tol"] isa Number && ana["accept_tol"] > 0) ||
            push!(errors, "[analysis] accept_tol must be positive")
    end
    if haskey(ana, "f_accept_tol")
        (ana["f_accept_tol"] isa Number && ana["f_accept_tol"] > 0) ||
            push!(errors, "[analysis] f_accept_tol must be positive")
    end
    if haskey(ana, "newton_patience")
        np = ana["newton_patience"]
        (np isa Integer && np > 0) ||
            push!(errors, "[analysis] newton_patience must be a positive integer, got: $np")
    end
    if haskey(ana, "newton_min_improvement")
        nmi = ana["newton_min_improvement"]
        (nmi isa Number && 0 < nmi <= 1) ||
            push!(errors, "[analysis] newton_min_improvement must be in (0, 1], got: $nmi")
    end
    if haskey(ana, "f_accept_tol_multiplier")
        m = ana["f_accept_tol_multiplier"]
        (m isa Number && m >= 1) ||
            push!(errors, "[analysis] f_accept_tol_multiplier must be >= 1, got: $m")
    end

    # --- [subdivision] (optional — adaptive-subdivision defaults) ---
    sub = get(d, "subdivision", Dict())
    if haskey(sub, "strategy")
        s = sub["strategy"]
        s in KNOWN_SUBDIVISION_STRATEGIES || push!(
            errors,
            "[subdivision] unknown strategy '$s'. Known: $(join(sort(collect(KNOWN_SUBDIVISION_STRATEGIES)), ", "))",
        )
    end
    if haskey(sub, "basis")
        b = sub["basis"]
        b in KNOWN_SUBDIVISION_BASES || push!(
            errors,
            "[subdivision] unknown basis '$b'. Known: $(join(sort(collect(KNOWN_SUBDIVISION_BASES)), ", "))",
        )
    end
    if haskey(sub, "degree")
        d_ = sub["degree"]
        (d_ isa Integer && d_ >= 1) ||
            push!(errors, "[subdivision] degree must be a positive integer, got: $d_")
    end
    if haskey(sub, "max_degree")
        md = sub["max_degree"]
        (md isa Integer && md >= 1) ||
            push!(errors, "[subdivision] max_degree must be a positive integer, got: $md")
        if haskey(sub, "degree") &&
           sub["degree"] isa Integer &&
           md isa Integer &&
           md < sub["degree"]
            push!(
                errors,
                "[subdivision] max_degree ($md) must be >= degree ($(sub["degree"]))",
            )
        end
    end
    if haskey(sub, "l2_tolerance")
        (sub["l2_tolerance"] isa Number && sub["l2_tolerance"] > 0) ||
            push!(errors, "[subdivision] l2_tolerance must be positive")
    end
    if haskey(sub, "max_depth")
        mxd = sub["max_depth"]
        (mxd isa Integer && mxd >= 1) ||
            push!(errors, "[subdivision] max_depth must be a positive integer, got: $mxd")
    end
    if haskey(sub, "max_leaves")
        mxl = sub["max_leaves"]
        (mxl isa Integer && mxl >= 1) ||
            push!(errors, "[subdivision] max_leaves must be a positive integer, got: $mxl")
    end

    # --- [refinement] (optional) ---
    if haskey(ref, "method")
        ref["method"] in KNOWN_REFINEMENT_METHODS || push!(
            errors,
            "[refinement] unknown method '$(ref["method"])'. Known: $(join(sort(collect(KNOWN_REFINEMENT_METHODS)), ", "))",
        )
    end
    if haskey(ref, "gradient_method")
        ref["gradient_method"] in KNOWN_GRADIENT_METHODS || push!(
            errors,
            "[refinement] unknown gradient_method '$(ref["gradient_method"])'. Known: $(join(sort(collect(KNOWN_GRADIENT_METHODS)), ", "))",
        )
    end
    if haskey(ref, "max_time")
        (ref["max_time"] isa Number && ref["max_time"] > 0) ||
            push!(errors, "[refinement] max_time must be positive")
    end
    if haskey(ref, "gradient_tolerance")
        (ref["gradient_tolerance"] isa Number && ref["gradient_tolerance"] > 0) ||
            push!(errors, "[refinement] gradient_tolerance must be positive")
    end
    if haskey(ref, "step_tolerance")
        (ref["step_tolerance"] isa Number && ref["step_tolerance"] > 0) ||
            push!(errors, "[refinement] step_tolerance must be positive")
    end

    # --- [visualization] (optional) ---
    viz = get(d, "visualization", Dict())
    if haskey(viz, "n_coarse")
        nc = viz["n_coarse"]
        (nc isa Integer && 5 <= nc <= 50) || push!(
            errors,
            "[visualization] n_coarse must be an integer in [5, 50], got: $nc",
        )
    end
    if haskey(viz, "n_refine")
        nr = viz["n_refine"]
        (nr isa Integer && 1 <= nr <= 10) || push!(
            errors,
            "[visualization] n_refine must be an integer in [1, 10], got: $nr",
        )
    end
    if haskey(viz, "level_max")
        lm = viz["level_max"]
        (lm isa Number && lm > 0) ||
            push!(errors, "[visualization] level_max must be positive, got: $lm")
    end
    if haskey(viz, "domain_mode")
        dm = viz["domain_mode"]
        dm in ["catalogue", "tight"] || push!(
            errors,
            "[visualization] domain_mode must be 'catalogue' or 'tight', got: '$dm'",
        )
    end
    if haskey(viz, "tight_frac")
        tf = viz["tight_frac"]
        (tf isa Number && 0 < tf < 10) ||
            push!(errors, "[visualization] tight_frac must be in (0, 10), got: $tf")
    end
    if haskey(viz, "level_tol")
        lt = viz["level_tol"]
        (lt isa Number && lt > 0) ||
            push!(errors, "[visualization] level_tol must be positive, got: $lt")
    end
    if haskey(viz, "figure_size")
        fs = viz["figure_size"]
        (
            fs isa AbstractVector &&
            length(fs) == 2 &&
            all(x -> x isa Integer && x > 0, fs)
        ) || push!(
            errors,
            "[visualization] figure_size must be [width, height] with positive integers, got: $fs",
        )
    end
    if haskey(viz, "animation_fps")
        af = viz["animation_fps"]
        (af isa Integer && 1 <= af <= 120) ||
            push!(errors, "[visualization] animation_fps must be in [1, 120], got: $af")
    end
    if haskey(viz, "animation_duration")
        ad = viz["animation_duration"]
        (ad isa Integer && 1 <= ad <= 300) || push!(
            errors,
            "[visualization] animation_duration must be in [1, 300], got: $ad",
        )
    end
    if haskey(viz, "augment_fraction")
        af = viz["augment_fraction"]
        (af isa Number && 0 < af <= 1) ||
            push!(errors, "[visualization] augment_fraction must be in (0, 1], got: $af")
    end
    if haskey(viz, "augment_n")
        an = viz["augment_n"]
        (an isa Integer && 2 <= an <= 10) || push!(
            errors,
            "[visualization] augment_n must be an integer in [2, 10], got: $an",
        )
    end

    # --- [grid_scoring] (optional — interestingness scoring defaults) ---
    gs = get(d, "grid_scoring", Dict())
    if haskey(gs, "points_per_dim")
        ppd = gs["points_per_dim"]
        (ppd isa Integer && ppd >= 2) || push!(
            errors,
            "[grid_scoring] points_per_dim must be an integer >= 2, got: $ppd",
        )
    end
    if haskey(gs, "numpoints")
        np = gs["numpoints"]
        (np isa Integer && np >= 2) ||
            push!(errors, "[grid_scoring] numpoints must be an integer >= 2, got: $np")
    end
    if haskey(gs, "interestingness_threshold")
        t = gs["interestingness_threshold"]
        (t isa Number && 0 <= t <= 1) || push!(
            errors,
            "[grid_scoring] interestingness_threshold must be in [0, 1], got: $t",
        )
    end
    if haskey(gs, "negative_control_threshold")
        t = gs["negative_control_threshold"]
        (t isa Number && 0 <= t <= 1) || push!(
            errors,
            "[grid_scoring] negative_control_threshold must be in [0, 1], got: $t",
        )
        if haskey(gs, "interestingness_threshold") &&
           gs["interestingness_threshold"] isa Number &&
           t isa Number &&
           t >= gs["interestingness_threshold"]
            push!(
                errors,
                "[grid_scoring] negative_control_threshold ($t) must be < interestingness_threshold ($(gs["interestingness_threshold"]))",
            )
        end
    end
    if haskey(gs, "min_local_minima")
        m = gs["min_local_minima"]
        (m isa Integer && m >= 0) || push!(
            errors,
            "[grid_scoring] min_local_minima must be an integer >= 0, got: $m",
        )
    end
    if haskey(gs, "catalogue_files")
        cf = gs["catalogue_files"]
        (cf isa AbstractVector && all(x -> x isa AbstractString, cf)) || push!(
            errors,
            "[grid_scoring] catalogue_files must be an array of strings, got: $cf",
        )
    end

    # --- [screening] (optional — screen_and_probe parameters) ---
    scr = get(d, "screening", Dict())
    if haskey(scr, "model_factory")
        mf = scr["model_factory"]
        mf isa AbstractString ||
            push!(errors, "[screening] model_factory must be a string, got: $mf")
    end
    if haskey(scr, "ic")
        ic = scr["ic"]
        (ic isa AbstractVector && all(x -> x isa Number, ic)) ||
            push!(errors, "[screening] ic must be an array of numbers, got: $ic")
    end
    if haskey(scr, "bounds")
        b = scr["bounds"]
        bounds_ok =
            b isa AbstractVector &&
            all(p -> p isa AbstractVector && length(p) == 2 && all(x -> x isa Number, p), b)
        bounds_ok ||
            push!(errors, "[screening] bounds must be an array of [lo, hi] pairs, got: $b")
    end
    if haskey(scr, "time_interval")
        ti = scr["time_interval"]
        (ti isa AbstractVector && length(ti) == 2 && all(x -> x isa Number, ti)) ||
            push!(errors, "[screening] time_interval must be [t0, t1], got: $ti")
    end
    if haskey(scr, "n_candidates")
        n = scr["n_candidates"]
        (n isa Integer && n >= 1) ||
            push!(errors, "[screening] n_candidates must be a positive integer, got: $n")
    end
    if haskey(scr, "n_probes")
        n = scr["n_probes"]
        (n isa Integer && n >= 1) ||
            push!(errors, "[screening] n_probes must be a positive integer, got: $n")
    end
    if haskey(scr, "top_n")
        n = scr["top_n"]
        (n isa Integer && n >= 1) ||
            push!(errors, "[screening] top_n must be a positive integer, got: $n")
    end
    if haskey(scr, "numpoints_screen")
        n = scr["numpoints_screen"]
        (n isa Integer && n >= 2) ||
            push!(errors, "[screening] numpoints_screen must be an integer >= 2, got: $n")
    end
    if haskey(scr, "numpoints_probe")
        n = scr["numpoints_probe"]
        (n isa Integer && n >= 2) ||
            push!(errors, "[screening] numpoints_probe must be an integer >= 2, got: $n")
    end
    if haskey(scr, "min_finite_fraction")
        f = scr["min_finite_fraction"]
        (f isa Number && 0 <= f <= 1) ||
            push!(errors, "[screening] min_finite_fraction must be in [0, 1], got: $f")
    end
    if haskey(scr, "max_noise_ratio")
        r = scr["max_noise_ratio"]
        (r isa Number && r >= 0) ||
            push!(errors, "[screening] max_noise_ratio must be >= 0, got: $r")
    end
    if haskey(scr, "ranking_strategy")
        s = scr["ranking_strategy"]
        s in KNOWN_SCREENING_RANKING_STRATEGIES || push!(
            errors,
            "[screening] unknown ranking_strategy '$s'. Known: $(join(sort(collect(KNOWN_SCREENING_RANKING_STRATEGIES)), ", "))",
        )
    end
    if haskey(scr, "solver")
        s = scr["solver"]
        s in KNOWN_SCREENING_SOLVERS || push!(
            errors,
            "[screening] unknown solver '$s'. Known: $(join(sort(collect(KNOWN_SCREENING_SOLVERS)), ", "))",
        )
    end

    # --- Raise all errors ---
    if !isempty(errors)
        error("TOML validation failed:\n  " * join(errors, "\n  "))
    end

    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════════
# Path Resolution
# ═══════════════════════════════════════════════════════════════════════════════

const _RESULTS_PREFIX = "globtim_results/"  # always forward slash — TOML files use "/" on all platforms

"""
    _resolve_config_path(p, config_dir) -> Union{String, Nothing}

Resolve a relative path from a TOML config to an absolute path.

- `nothing` passes through unchanged
- Absolute paths pass through unchanged
- Paths starting with `"globtim_results/"` are resolved via `get_results_root()`
  (respects `GLOBTIM_RESULTS_ROOT` env var)
- Other relative paths are resolved relative to `config_dir` (the TOML file's directory)
"""
function _resolve_config_path(p::Nothing, ::AbstractString)
    return nothing
end

function _resolve_config_path(p::AbstractString, config_dir::AbstractString)
    isabspath(p) && return p

    if startswith(p, _RESULTS_PREFIX)
        # "globtim_results/lv4d_catalogue.jsonl" → get_results_root() * "/lv4d_catalogue.jsonl"
        return joinpath(get_results_root(), p[(length(_RESULTS_PREFIX)+1):end])
    end

    # Other relative paths resolve relative to the TOML file's directory
    return joinpath(config_dir, p)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Parser
# ═══════════════════════════════════════════════════════════════════════════════

"""
    load_experiment_config(path::String) -> ExperimentPipelineConfig

Parse a TOML experiment configuration file and return a validated
`ExperimentPipelineConfig`.

# Example
```julia
config = load_experiment_config("experiments/lv4d_basic.toml")
config.GN          # => 12
config.degree_range # => 4:2:8
config.basis        # => :chebyshev
```
"""
function load_experiment_config(path::String)
    isfile(path) || error("Config file not found: $path")

    d = TOML.parsefile(path)
    validate_experiment_toml(d)

    exp = d["experiment"]
    mod = d["model"]
    poly = d["polynomial"]
    dom = get(d, "domain", Dict())
    sol = get(d, "solver", Dict())
    ref = get(d, "refinement", Dict())
    out = get(d, "output", Dict())

    # Parse degree_range: [start, step, stop] -> StepRange
    dr = poly["degree_range"]
    degree_range = dr[1]:dr[2]:dr[3]

    # Parse basis
    basis = Symbol(get(poly, "basis", "chebyshev"))

    # Parse truncation (optional)
    truncation_threshold =
        haskey(poly, "truncation_threshold") ? Float64(poly["truncation_threshold"]) :
        nothing
    truncation_mode = Symbol(get(poly, "truncation_mode", "relative"))

    # Parse timeout protection (dljm)
    degree_timeout_seconds =
        haskey(poly, "degree_timeout_seconds") ? Float64(poly["degree_timeout_seconds"]) :
        nothing
    msolve_timeout_seconds =
        haskey(poly, "msolve_timeout_seconds") ? Float64(poly["msolve_timeout_seconds"]) :
        nothing

    # Parse domain
    radius = nothing
    radii = nothing
    bounds = nothing
    if haskey(dom, "radius")
        radius = Float64(dom["radius"])
    elseif haskey(dom, "radii")
        radii = Float64.(dom["radii"])
    elseif haskey(dom, "bounds")
        bounds = [
            Tuple{Float64,Float64}((Float64(pair[1]), Float64(pair[2]))) for
            pair in dom["bounds"]
        ]
    end

    # Parse model mode
    catalogue_path = haskey(mod, "catalogue_path") ? String(mod["catalogue_path"]) : nothing
    entry_name = haskey(mod, "entry_name") ? String(mod["entry_name"]) : nothing
    analytical_function =
        haskey(mod, "analytical_function") ? String(mod["analytical_function"]) : nothing
    model_dimension = haskey(mod, "dimension") ? Int(mod["dimension"]) : nothing
    time_interval = haskey(mod, "time_interval") ? Float64.(mod["time_interval"]) : nothing
    sample_times = haskey(mod, "sample_times") ? Float64.(mod["sample_times"]) : nothing
    p_true = haskey(mod, "p_true") ? Float64.(mod["p_true"]) : nothing

    # Parse p_center from [domain]
    p_center = haskey(dom, "p_center") ? Float64.(dom["p_center"]) : nothing

    # Parse solver overrides
    solver_method = haskey(sol, "method") ? String(sol["method"]) : nothing
    solver_abstol = haskey(sol, "abstol") ? Float64(sol["abstol"]) : nothing
    solver_reltol = haskey(sol, "reltol") ? Float64(sol["reltol"]) : nothing
    solver_numpoints = haskey(sol, "numpoints") ? Int(sol["numpoints"]) : nothing

    # Parse refinement
    refinement_enabled = get(ref, "enabled", false)::Bool
    refinement_method = haskey(ref, "method") ? String(ref["method"]) : nothing
    refinement_max_time = haskey(ref, "max_time") ? Float64(ref["max_time"]) : nothing
    refinement_gradient_method =
        haskey(ref, "gradient_method") ? String(ref["gradient_method"]) : nothing
    refinement_gradient_tolerance =
        haskey(ref, "gradient_tolerance") ? Float64(ref["gradient_tolerance"]) : nothing
    refinement_step_tolerance =
        haskey(ref, "step_tolerance") ? Float64(ref["step_tolerance"]) : nothing

    # Parse analysis
    ana = get(d, "analysis", Dict())
    analysis_enabled = get(ana, "enabled", false)::Bool
    analysis_refinement_goal =
        haskey(ana, "refinement_goal") ? String(ana["refinement_goal"]) : nothing
    analysis_gradient_method =
        haskey(ana, "gradient_method") ? String(ana["gradient_method"]) : nothing
    analysis_newton_tol = haskey(ana, "newton_tol") ? Float64(ana["newton_tol"]) : nothing
    analysis_newton_max_iterations =
        haskey(ana, "newton_max_iterations") ? Int(ana["newton_max_iterations"]) : nothing
    analysis_max_time_per_point =
        haskey(ana, "max_time_per_point") ? Float64(ana["max_time_per_point"]) : nothing
    analysis_hessian_tol =
        haskey(ana, "hessian_tol") ? Float64(ana["hessian_tol"]) : nothing
    analysis_dedup_fraction =
        haskey(ana, "dedup_fraction") ? Float64(ana["dedup_fraction"]) : nothing
    analysis_top_k = haskey(ana, "top_k") ? Int(ana["top_k"]) : nothing

    # Parse output
    output_dir = haskey(out, "dir") ? String(out["dir"]) : nothing

    # ── Resolve relative paths ──
    # TOML configs use relative paths like "globtim_results/lv4d_catalogue.jsonl".
    # These must be resolved to absolute paths so they work regardless of pwd().
    # Paths under "globtim_results/" are resolved via PathManager.get_results_root()
    # (which respects the GLOBTIM_RESULTS_ROOT env var). Other relative paths are
    # resolved relative to the TOML file's directory.
    config_dir = dirname(realpath(path))  # realpath: resolve symlinks so copied/linked TOMLs find their relative paths
    catalogue_path = _resolve_config_path(catalogue_path, config_dir)
    output_dir = _resolve_config_path(output_dir, config_dir)

    # Parse visualization
    viz = get(d, "visualization", Dict())
    viz_enabled = get(viz, "enabled", false)::Bool
    viz_n_coarse = haskey(viz, "n_coarse") ? Int(viz["n_coarse"]) : 10
    viz_n_refine = haskey(viz, "n_refine") ? Int(viz["n_refine"]) : 2
    viz_level_max = haskey(viz, "level_max") ? Float64(viz["level_max"]) : 1.0
    viz_domain_mode = Symbol(get(viz, "domain_mode", "catalogue"))
    viz_tight_frac = haskey(viz, "tight_frac") ? Float64(viz["tight_frac"]) : 0.1
    viz_level_tol = haskey(viz, "level_tol") ? Float64(viz["level_tol"]) : 0.005
    viz_figure_size = if haskey(viz, "figure_size")
        (Int(viz["figure_size"][1]), Int(viz["figure_size"][2]))
    else
        (1200, 900)
    end
    viz_record_animation = get(viz, "record_animation", false)::Bool
    viz_animation_fps = haskey(viz, "animation_fps") ? Int(viz["animation_fps"]) : 30
    viz_animation_duration =
        haskey(viz, "animation_duration") ? Int(viz["animation_duration"]) : 15
    viz_augment_enabled = get(viz, "augment_enabled", true)::Bool
    viz_augment_fraction =
        haskey(viz, "augment_fraction") ? Float64(viz["augment_fraction"]) : 0.25
    viz_augment_n = haskey(viz, "augment_n") ? Int(viz["augment_n"]) : 4
    viz_near_zero_enabled = get(viz, "near_zero_enabled", true)::Bool
    viz_near_zero_threshold =
        haskey(viz, "near_zero_threshold") ? Float64(viz["near_zero_threshold"]) : 0.5
    viz_near_zero_n = haskey(viz, "near_zero_n") ? Int(viz["near_zero_n"]) : 8

    # Parse analysis accept tolerances and valley walking
    analysis_accept_tol = haskey(ana, "accept_tol") ? Float64(ana["accept_tol"]) : nothing
    analysis_f_accept_tol =
        haskey(ana, "f_accept_tol") ? Float64(ana["f_accept_tol"]) : nothing
    analysis_newton_patience =
        haskey(ana, "newton_patience") ? Int(ana["newton_patience"]) : nothing
    analysis_newton_min_improvement =
        haskey(ana, "newton_min_improvement") ? Float64(ana["newton_min_improvement"]) :
        nothing
    analysis_f_accept_tol_multiplier =
        haskey(ana, "f_accept_tol_multiplier") ? Float64(ana["f_accept_tol_multiplier"]) :
        nothing
    analysis_valley_walking = Bool(get(ana, "valley_walking", false))
    analysis_deep_diagnostics = Bool(get(ana, "deep_diagnostics", false))

    # Parse subdivision (optional)
    sub = get(d, "subdivision", Dict())
    subdivision_strategy = haskey(sub, "strategy") ? String(sub["strategy"]) : nothing
    subdivision_degree = haskey(sub, "degree") ? Int(sub["degree"]) : nothing
    subdivision_max_degree = haskey(sub, "max_degree") ? Int(sub["max_degree"]) : nothing
    subdivision_l2_tolerance =
        haskey(sub, "l2_tolerance") ? Float64(sub["l2_tolerance"]) : nothing
    subdivision_max_depth = haskey(sub, "max_depth") ? Int(sub["max_depth"]) : nothing
    subdivision_max_leaves = haskey(sub, "max_leaves") ? Int(sub["max_leaves"]) : nothing
    subdivision_basis = haskey(sub, "basis") ? Symbol(sub["basis"]) : nothing

    # Parse grid_scoring (optional, 0thk)
    gs = get(d, "grid_scoring", Dict())
    grid_scoring_points_per_dim =
        haskey(gs, "points_per_dim") ? Int(gs["points_per_dim"]) : nothing
    grid_scoring_numpoints = haskey(gs, "numpoints") ? Int(gs["numpoints"]) : nothing
    grid_scoring_interestingness_threshold =
        haskey(gs, "interestingness_threshold") ? Float64(gs["interestingness_threshold"]) :
        nothing
    grid_scoring_negative_control_threshold =
        haskey(gs, "negative_control_threshold") ?
        Float64(gs["negative_control_threshold"]) : nothing
    grid_scoring_min_local_minima =
        haskey(gs, "min_local_minima") ? Int(gs["min_local_minima"]) : nothing
    grid_scoring_catalogue_files = if haskey(gs, "catalogue_files")
        [String(x) for x in gs["catalogue_files"]]
    else
        nothing
    end

    # Parse screening (optional, 20p7)
    scr = get(d, "screening", Dict())
    screening_model_factory =
        haskey(scr, "model_factory") ? String(scr["model_factory"]) : nothing
    screening_ic = haskey(scr, "ic") ? Float64.(scr["ic"]) : nothing
    screening_bounds = if haskey(scr, "bounds")
        [Tuple{Float64,Float64}((Float64(p[1]), Float64(p[2]))) for p in scr["bounds"]]
    else
        nothing
    end
    screening_time_interval =
        haskey(scr, "time_interval") ? Float64.(scr["time_interval"]) : nothing
    screening_catalogue_path = if haskey(scr, "catalogue_path")
        _resolve_config_path(String(scr["catalogue_path"]), config_dir)
    else
        nothing
    end
    screening_name_prefix =
        haskey(scr, "name_prefix") ? String(scr["name_prefix"]) : nothing
    screening_description =
        haskey(scr, "description") ? String(scr["description"]) : nothing
    screening_n_candidates =
        haskey(scr, "n_candidates") ? Int(scr["n_candidates"]) : nothing
    screening_n_probes = haskey(scr, "n_probes") ? Int(scr["n_probes"]) : nothing
    screening_top_n = haskey(scr, "top_n") ? Int(scr["top_n"]) : nothing
    screening_numpoints_screen =
        haskey(scr, "numpoints_screen") ? Int(scr["numpoints_screen"]) : nothing
    screening_numpoints_probe =
        haskey(scr, "numpoints_probe") ? Int(scr["numpoints_probe"]) : nothing
    screening_min_finite_fraction =
        haskey(scr, "min_finite_fraction") ? Float64(scr["min_finite_fraction"]) : nothing
    screening_max_noise_ratio =
        haskey(scr, "max_noise_ratio") ? Float64(scr["max_noise_ratio"]) : nothing
    screening_ranking_strategy =
        haskey(scr, "ranking_strategy") ? String(scr["ranking_strategy"]) : nothing
    screening_solver = haskey(scr, "solver") ? String(scr["solver"]) : nothing

    return ExperimentPipelineConfig(
        # [experiment]
        name = String(exp["name"]),
        description = String(get(exp, "description", "")),
        # [model]
        catalogue_path = catalogue_path,
        entry_name = entry_name,
        analytical_function = analytical_function,
        dimension = model_dimension,
        time_interval = time_interval,
        sample_times = sample_times,
        p_true = p_true,
        # [domain]
        radius = radius,
        radii = radii,
        bounds = bounds,
        p_center = p_center,
        # [polynomial]
        GN = Int(poly["GN"]),
        degree_range = degree_range,
        basis = basis,
        truncation_threshold = truncation_threshold,
        truncation_mode = truncation_mode,
        degree_timeout_seconds = degree_timeout_seconds,
        msolve_timeout_seconds = msolve_timeout_seconds,
        # [solver]
        solver_method = solver_method,
        solver_abstol = solver_abstol,
        solver_reltol = solver_reltol,
        solver_numpoints = solver_numpoints,
        # [refinement]
        refinement_enabled = refinement_enabled,
        refinement_method = refinement_method,
        refinement_max_time = refinement_max_time,
        refinement_gradient_method = refinement_gradient_method,
        refinement_gradient_tolerance = refinement_gradient_tolerance,
        refinement_step_tolerance = refinement_step_tolerance,
        # [analysis]
        analysis_enabled = analysis_enabled,
        analysis_refinement_goal = analysis_refinement_goal,
        analysis_gradient_method = analysis_gradient_method,
        analysis_newton_tol = analysis_newton_tol,
        analysis_newton_max_iterations = analysis_newton_max_iterations,
        analysis_max_time_per_point = analysis_max_time_per_point,
        analysis_hessian_tol = analysis_hessian_tol,
        analysis_dedup_fraction = analysis_dedup_fraction,
        analysis_top_k = analysis_top_k,
        analysis_accept_tol = analysis_accept_tol,
        analysis_f_accept_tol = analysis_f_accept_tol,
        analysis_newton_patience = analysis_newton_patience,
        analysis_newton_min_improvement = analysis_newton_min_improvement,
        analysis_f_accept_tol_multiplier = analysis_f_accept_tol_multiplier,
        analysis_valley_walking = analysis_valley_walking,
        analysis_deep_diagnostics = analysis_deep_diagnostics,
        # [subdivision]
        subdivision_strategy = subdivision_strategy,
        subdivision_degree = subdivision_degree,
        subdivision_max_degree = subdivision_max_degree,
        subdivision_l2_tolerance = subdivision_l2_tolerance,
        subdivision_max_depth = subdivision_max_depth,
        subdivision_max_leaves = subdivision_max_leaves,
        subdivision_basis = subdivision_basis,
        # [grid_scoring]
        grid_scoring_points_per_dim = grid_scoring_points_per_dim,
        grid_scoring_numpoints = grid_scoring_numpoints,
        grid_scoring_interestingness_threshold = grid_scoring_interestingness_threshold,
        grid_scoring_negative_control_threshold = grid_scoring_negative_control_threshold,
        grid_scoring_min_local_minima = grid_scoring_min_local_minima,
        grid_scoring_catalogue_files = grid_scoring_catalogue_files,
        # [screening]
        screening_model_factory = screening_model_factory,
        screening_ic = screening_ic,
        screening_bounds = screening_bounds,
        screening_time_interval = screening_time_interval,
        screening_catalogue_path = screening_catalogue_path,
        screening_name_prefix = screening_name_prefix,
        screening_description = screening_description,
        screening_n_candidates = screening_n_candidates,
        screening_n_probes = screening_n_probes,
        screening_top_n = screening_top_n,
        screening_numpoints_screen = screening_numpoints_screen,
        screening_numpoints_probe = screening_numpoints_probe,
        screening_min_finite_fraction = screening_min_finite_fraction,
        screening_max_noise_ratio = screening_max_noise_ratio,
        screening_ranking_strategy = screening_ranking_strategy,
        screening_solver = screening_solver,
        # [output]
        output_dir = output_dir,
        # [visualization]
        viz_enabled = viz_enabled,
        viz_n_coarse = viz_n_coarse,
        viz_n_refine = viz_n_refine,
        viz_level_max = viz_level_max,
        viz_domain_mode = viz_domain_mode,
        viz_tight_frac = viz_tight_frac,
        viz_level_tol = viz_level_tol,
        viz_figure_size = viz_figure_size,
        viz_record_animation = viz_record_animation,
        viz_animation_fps = viz_animation_fps,
        viz_animation_duration = viz_animation_duration,
        viz_augment_enabled = viz_augment_enabled,
        viz_augment_fraction = viz_augment_fraction,
        viz_augment_n = viz_augment_n,
        viz_near_zero_enabled = viz_near_zero_enabled,
        viz_near_zero_threshold = viz_near_zero_threshold,
        viz_near_zero_n = viz_near_zero_n,
    )
end

"""
    config_to_experiment_params(config::ExperimentPipelineConfig) -> ExperimentParams

Convert the polynomial/solver fields of an ExperimentPipelineConfig into an
ExperimentParams suitable for `run_standard_experiment()`.

Catalogue objectives may be ForwardDiff-incompatible, so gradient/hessian/BFGS are
disabled when using catalogue models. Analytical models enable them by default.
"""
function config_to_experiment_params(config::ExperimentPipelineConfig)
    is_ode = config.catalogue_path !== nothing

    return ExperimentParams(
        GN = config.GN,
        degree_range = config.degree_range,
        basis = config.basis,
        domain_size = _infer_domain_size(config),
        enable_gradient_computation = !is_ode,
        enable_hessian_computation = !is_ode,
        enable_bfgs_refinement = !is_ode,
        truncation_threshold = config.truncation_threshold,
        truncation_mode = config.truncation_mode,
        degree_timeout_seconds = config.degree_timeout_seconds,
        msolve_timeout_seconds = config.msolve_timeout_seconds,
    )
end

"""Infer a scalar domain_size from the config (used by ExperimentParams)."""
function _infer_domain_size(config::ExperimentPipelineConfig)
    if config.radius !== nothing
        return config.radius
    elseif config.radii !== nothing
        return maximum(config.radii)
    elseif config.bounds !== nothing
        return maximum((hi - lo) / 2 for (lo, hi) in config.bounds)
    else
        return 0.1  # safe default, only used for display
    end
end
