"""
StandardExperiment Module - Unified Experiment Template (Phase 2)

**Phase 2 Update (2025-11-23)**: Critical point refinement moved to globtimpostprocessing.
This module now exports ONLY raw critical points from HomotopyContinuation.

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

# Define objective function (1-arg or 2-arg)
objective = p -> sum(p.^2)  # 1-arg function (auto-detected)

# Run experiment (exports raw critical points only)
result = run_standard_experiment(
    objective_function = objective,
    problem_params = nothing,  # Not needed for 1-arg functions
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

Created: 2025-10-02 (Issue #112 - Template Unification)
Updated: 2025-11-23 (Phase 2 - Refinement Migration)
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

# Import PathManager module (Issue #192, Unified Path Management)
# PathManager consolidates PathUtils, OutputPathManager, ExperimentPaths, etc.
# Phase 5 complete: Old modules deprecated, StandardExperiment now uses only PathManager.
if !isdefined(Main, :PathManager)
    include(joinpath(@__DIR__, "PathManager.jl"))
end
using .PathManager

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
    best_estimate::Union{Vector{Float64}, Nothing}
    best_objective::Union{Float64, Nothing}
    recovery_error::Union{Float64, Nothing}  # Optional: if true params known

    # Quality metrics
    l2_approx_error::Float64
    relative_l2_error::Float64  # l2_approx_error / ||f||_L2 (dimensionless)
    condition_number::Float64

    # Coefficient counts
    n_total_coeffs::Int   # Total coefficients = binomial(n+d, d) for total degree d in n dims
    support_size::Int     # Nonzero coefficients: count(!iszero, pol.coeffs)

    # Timing breakdown
    polynomial_construction_time::Float64
    critical_point_solving_time::Float64
    critical_point_processing_time::Float64
    file_io_time::Float64
    total_computation_time::Float64

    # Output location
    output_dir::String

    # Error information (if failed)
    # Can be String (legacy), Dict{String,Any} (rich context), or Nothing (success)
    error::Union{String, Dict{String, Any}, Nothing}
end

"""
    solve_and_transform(pol::ApproxPoly, bounds) -> (critical_points, solve_time)

Solve a polynomial system via HomotopyContinuation and transform solutions from
normalized [-1,1]^n coordinates to the original domain.

This is the shared kernel used by both `run_standard_experiment` (full polynomials)
and `run_sparsification_experiment` (sparsified polynomial variants).

# Arguments
- `pol::ApproxPoly`: Polynomial approximation (full or sparsified)
- `bounds::Vector{Tuple{Float64, Float64}}`: Domain bounds [(lb₁,ub₁), ...]

# Returns
- `critical_points::Vector{Vector{Float64}}`: Critical points in original domain coordinates
- `solve_time::Float64`: Wall-clock time for HC solve (seconds)
"""
function solve_and_transform(
    pol,  # ApproxPoly — not typed to avoid import dependency
    bounds::Vector{Tuple{Float64, Float64}},
)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]

    # Solve polynomial system via HomotopyContinuation
    @polyvar x[1:dimension]
    solve_time = @elapsed begin
        raw_critical_points = Globtim.solve_polynomial_system_from_approx(x, pol)
    end

    # Transform from normalized [-1,1]^n to original domain coordinates
    critical_points = [
        sample_range .* [pt[i] for i in 1:dimension] .+ center
        for pt in raw_critical_points
    ]

    return critical_points, solve_time
end

"""
    run_standard_experiment(;
        objective_function::Function,
        objective_name::String,
        problem_params,
        bounds::Vector{Tuple{Float64, Float64}},
        experiment_config,
        output_dir::String,
        metadata::Dict{String, Any} = Dict(),
        true_params::Union{Vector{Float64}, Nothing} = nothing
    ) -> Dict{String, Any}

Execute standardized experiment with RAW critical point export only.

**Phase 2 Update**: Refinement has been moved to globtimpostprocessing package.
This function now exports only raw critical points from HomotopyContinuation.

# Arguments
- `objective_function`: Callable with signature f(point::Vector{Float64}) or f(point, params).
  Accepts plain functions or callable structs (e.g., TolerantObjective).
  - 1-argument: f(p::Vector{Float64}) -> Float64 (auto-detected, e.g., Dynamic_objectives)
  - 2-argument: f(p::Vector{Float64}, params) -> Float64 (legacy, requires problem_params)
- `objective_name`: Identifier for the objective function (e.g., "lv4d", "deuflhard_4d_q4").
  Stored in `results_summary.json` under `experiment_definition.objective_name` to make
  experiment outputs self-describing for parameter sweep analysis.
- `problem_params`: Problem-specific parameters (only for 2-arg functions)
- `bounds`: Vector of (min, max) tuples for each dimension
- `experiment_config`: ExperimentParams from ExperimentCLI (GN, degree_range, max_time, domain_size)
- `output_dir`: Output directory path (from DrWatson, --output-dir, or hierarchical path)
- `metadata`: Additional metadata for results_summary.json (system_type, params, etc.)
- `true_params`: Optional true parameters for recovery error calculation

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
    problem_params = nothing,
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
    problem_params = nothing,
    bounds = [(0.5, 1.5), (1.5, 2.5), (2.5, 3.5), (3.5, 4.5)],
    experiment_config = parse_experiment_args(ARGS),
    output_dir = "hpc_results/my_experiment",
    metadata = Dict("experiment_type" => "parameter_recovery")
)
```
"""
function run_standard_experiment(;
    objective_function,
    objective_name::String,
    problem_params,
    bounds::Vector{Tuple{Float64, Float64}},
    experiment_config,
    output_dir::String,
    metadata::Dict{String, Any} = Dict(),
    true_params::Union{Vector{Float64}, Nothing} = nothing
)
    # Validate inputs
    dimension = length(bounds)
    @assert dimension == length(bounds) "Dimension mismatch"

    # NOTE: Output path validation disabled - using static relative paths ../globtim_results
    # validate_output_configuration()

    # Check for legacy path patterns and warn (optional)
    # legacy_warning = get_legacy_path_warning(output_dir)
    # if !isempty(legacy_warning)
    #     @warn legacy_warning
    # end

    mkpath(output_dir)

    # Pre-compute domain geometry (invariant across degrees)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]

    # Detect function signature and create wrapper if needed
    # Support both 1-arg (Dynamic_objectives pattern) and 2-arg (legacy pattern)
    method_sig = first(methods(objective_function)).sig
    while method_sig isa UnionAll
        method_sig = method_sig.body
    end
    n_args = length(method_sig.parameters) - 1

    func = if n_args == 1
        if problem_params !== nothing
            @warn "problem_params provided but objective_function takes 1 argument - ignoring params"
        end
        objective_function
    elseif n_args == 2
        if problem_params === nothing
            error("2-argument objective function requires problem_params")
        end
        x -> objective_function(x, problem_params)
    else
        error("Objective function must accept 1 or 2 arguments, got $n_args")
    end

    # Build tensor representation ONCE (evaluates objective on GN^dimension grid points)
    # This is invariant across degrees — only Constructor depends on degree.
    TR = Globtim.TestInput(
        func,
        dim = dimension,
        center = center,
        GN = experiment_config.GN,
        sample_range = sample_range
    )

    # Process each degree
    degree_results = DegreeResult[]
    total_critical_points = 0

    for degree in experiment_config.degree_range
        degree_start = time()

        try
            result = process_single_degree(
                degree,
                func,
                TR,
                bounds,
                experiment_config,
                output_dir,
                true_params
            )

            push!(degree_results, result)
            total_critical_points += result.n_critical_points

        catch e
            degree_time = time() - degree_start
            println("ERROR degree $degree: $e")

            # Capture rich error context for post-processing analysis
            error_context = Dict{String, Any}(
                "error_message" => string(e),
                "error_type" => string(typeof(e)),
                "stacktrace" => string.(stacktrace(catch_backtrace())),
                "degree" => degree,
                "dimension" => length(bounds),
                "GN" => experiment_config.GN,
                "basis" => string(experiment_config.basis),
                "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
                "computation_time" => degree_time
            )

            # Create failed result
            failed_result = DegreeResult(
                degree, "failed",
                0,  # n_critical_points
                Vector{Vector{Float64}}(),  # critical_points (empty)
                Vector{Float64}(),  # objective_values (empty)
                nothing, nothing, nothing,  # No best estimate
                NaN, NaN, NaN,  # Quality metrics (l2, relative_l2, cond)
                0, 0,  # n_total_coeffs, support_size (unknown for failed)
                0.0, 0.0, 0.0, 0.0, degree_time,  # Timing
                output_dir,
                error_context  # Rich error context
            )

            push!(degree_results, failed_result)
        end
    end

    # Generate results summary
    total_time = sum(r.total_computation_time for r in degree_results)
    success_count = count(r -> r.status == "success", degree_results)
    success_rate = success_count / length(degree_results)

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
        true_params = true_params
    )

    # Save experiment summary
    save_experiment_summary(experiment_summary, output_dir)

    return experiment_summary
end

"""
    process_single_degree(degree, func, TR, bounds,
                         experiment_config, output_dir, true_params) -> DegreeResult

Process a single polynomial degree through the complete pipeline.

# Arguments
- `degree::Int`: Polynomial degree to process
- `func`: Resolved 1-argument objective callable (Function or functor struct)
- `TR`: Pre-computed tensor representation from `Globtim.TestInput` (shared across degrees)
- `bounds`: Vector of (lower, upper) tuples
- `experiment_config`: Experiment parameters (basis, GN, etc.)
- `output_dir`: Directory for CSV output
- `true_params`: Known true parameters (optional, for recovery error)
"""
function process_single_degree(
    degree::Int,
    func,
    TR,
    bounds::Vector{Tuple{Float64, Float64}},
    experiment_config,
    output_dir::String,
    true_params::Union{Vector{Float64}, Nothing}
)
    dimension = length(bounds)
    center = [(bounds[1] + bounds[2]) / 2 for bounds in bounds]
    sample_range = [(bounds[2] - bounds[1]) / 2 for bounds in bounds]
    timing = Dict{String, Float64}()

    # Phase 1: Polynomial Construction (TR is pre-computed, only Constructor is degree-dependent)
    poly_construction_start = time()

    pol = Globtim.Constructor(TR, degree, basis = experiment_config.basis, normalized = false)

    timing["polynomial_construction_time"] = time() - poly_construction_start
    timing["l2_approx_error"] = pol.nrm
    timing["relative_l2_error"] = relative_l2_error(pol)
    timing["condition_number"] = pol.cond_vandermonde

    # Phase 2: Critical Point Solving + coordinate transformation
    critical_points_array, solve_time = solve_and_transform(pol, bounds)
    n_critical_points = length(critical_points_array)
    timing["critical_point_solving_time"] = solve_time

    # CRITICAL FIX (Issue #111): ERROR if no critical points found
    if n_critical_points == 0
        error("CRITICAL: No critical points found by HomotopyContinuation")
    end

    println("Found $n_critical_points raw critical points at degree $degree")

    # Phase 3: Use raw critical points (refinement moved to globtimpostprocessing)
    processing_start = time()

    # Compute objective values at critical points (in original coordinates)
    objective_values = [func(critical_points_array[i]) for i in 1:n_critical_points]

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

    timing["critical_point_processing_time"] = time() - processing_start

    # Phase 4: CSV Export (raw critical points only)
    io_start = time()

    # Create DataFrame with raw critical points
    df_critical = DataFrame(
        :index => 1:n_critical_points,
        [Symbol("p$i") => [critical_points_array[j][i] for j in 1:n_critical_points]
         for i in 1:dimension]...,
        :objective => objective_values
    )

    # Export raw critical points (add '_raw' suffix for globtimpostprocessing)
    csv_path = joinpath(output_dir, "critical_points_raw_deg_$degree.csv")
    CSV.write(csv_path, df_critical)

    timing["file_io_time"] = time() - io_start

    # Calculate total time
    total_time = (timing["polynomial_construction_time"] +
                  timing["critical_point_solving_time"] +
                  timing["critical_point_processing_time"] +
                  timing["file_io_time"])

    return DegreeResult(
        degree, "success",
        n_critical_points,
        critical_points_array,
        objective_values,
        best_estimate, best_objective, recovery_error,
        timing["l2_approx_error"], timing["relative_l2_error"], timing["condition_number"],
        length(pol.coeffs), count(!iszero, pol.coeffs),
        timing["polynomial_construction_time"],
        timing["critical_point_solving_time"],
        timing["critical_point_processing_time"],
        timing["file_io_time"],
        total_time,
        output_dir,
        nothing
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
    metadata::Dict{String, Any},
    total_critical_points::Int,
    total_time::Float64,
    success_rate::Float64;
    objective_name::String,
    bounds::Vector{Tuple{Float64, Float64}},
    true_params::Union{Vector{Float64}, Nothing} = nothing,
)
    # Build results_summary dict
    results_summary = Dict{String, Any}()

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

            # Timing breakdown
            "polynomial_construction_time" => result.polynomial_construction_time,
            "critical_point_solving_time" => result.critical_point_solving_time,
            "critical_point_processing_time" => result.critical_point_processing_time,
            "file_io_time" => result.file_io_time,
            "total_computation_time" => result.total_computation_time,
            "computation_time" => result.total_computation_time,  # Backwards compatibility

            # Output location
            "output_dir" => result.output_dir,

            # Error (if failed)
            "error" => result.error
        )
    end

    # Experiment definition: what problem was solved
    experiment_definition = Dict{String, Any}(
        "objective_name" => objective_name,
        "dimension"      => length(bounds),
        "bounds"         => [[lb, ub] for (lb, ub) in bounds],
        "true_params"    => true_params,
    )

    # Solver config: how it was solved (full ExperimentParams)
    solver_config = Dict{String, Any}(
        "GN"             => experiment_config.GN,
        "degree_range"   => collect(experiment_config.degree_range),
        "domain_size"    => experiment_config.domain_size,
        "max_time"       => experiment_config.max_time,
        "basis"          => string(experiment_config.basis),
        "optim_f_tol"    => experiment_config.optim_f_tol,
        "optim_x_tol"    => experiment_config.optim_x_tol,
        "max_iterations" => experiment_config.max_iterations,
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
            "polynomial_construction_time" => sanitize_for_json(obj.polynomial_construction_time),
            "critical_point_solving_time" => sanitize_for_json(obj.critical_point_solving_time),
            "critical_point_processing_time" => sanitize_for_json(obj.critical_point_processing_time),
            "file_io_time" => sanitize_for_json(obj.file_io_time),
            "total_computation_time" => sanitize_for_json(obj.total_computation_time),
            "output_dir" => obj.output_dir,
            "error" => sanitize_for_json(obj.error)  # Handle both String and Dict errors
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
    summary_for_jld2 = Dict{String, Any}(string(k) => v for (k, v) in summary)
    tagsave(jld2_path, summary_for_jld2; warn=false)
end

"""
Print timing breakdown for a degree result (Phase 2: no refinement).
"""
function print_degree_summary(result::DegreeResult)
    total = result.total_computation_time
    println("Degree $(result.degree): $(round(total, digits=2))s [poly=$(round(result.polynomial_construction_time, digits=2))s, solve=$(round(result.critical_point_solving_time, digits=2))s, process=$(round(result.critical_point_processing_time, digits=2))s]")
end

end  # module StandardExperiment
