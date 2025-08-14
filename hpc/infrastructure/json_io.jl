"""
JSON I/O Utilities for Globtim HPC Tracking

This module provides functions to serialize and deserialize Globtim data structures
to/from JSON format for HPC computation tracking and reproducibility.
"""

# Ensure we're in the right environment for dependencies
try
    using JSON3
catch
    using Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
    using JSON3
end

using UUIDs
using Dates
using DataFrames
using CSV
using SHA

# Import Globtim types (adjust path as needed)
# using Globtim

"""
    generate_computation_id() -> String

Generate a unique 8-character computation ID.
"""
function generate_computation_id()
    return string(uuid4())[1:8]
end

"""
    serialize_test_input(TR::test_input, metadata::Dict=Dict()) -> Dict

Convert a test_input struct to a JSON-serializable dictionary.
"""
function serialize_test_input(TR, metadata::Dict=Dict())
    # Extract function name (handle both named functions and anonymous functions)
    function_name = if hasfield(typeof(TR.objective), :name)
        string(TR.objective.name)
    else
        "anonymous_function"
    end
    
    input_config = Dict(
        "metadata" => merge(Dict(
            "computation_id" => get(metadata, "computation_id", generate_computation_id()),
            "timestamp" => string(now()),
            "function_name" => function_name,
            "description" => get(metadata, "description", "Globtim computation"),
            "tags" => get(metadata, "tags", String[])
        ), metadata),
        
        "test_input" => Dict(
            "function_name" => function_name,
            "dimension" => TR.dim,
            "center" => TR.center,
            "sample_range" => TR.sample_range,
            "GN" => TR.GN,
            "tolerance" => TR.tolerance,
            "precision_params" => TR.prec,
            "noise_params" => TR.noise,
            "reduce_samples" => TR.reduce_samples,
            "degree_max" => TR.degree_max
        )
    )
    
    return input_config
end

"""
    serialize_polynomial_config(degree::Int, basis::Symbol, precision_type, 
                               normalized::Bool=false, power_of_two_denom::Bool=false,
                               verbose::Int=0) -> Dict

Serialize polynomial construction parameters.
"""
function serialize_polynomial_config(degree::Int, basis::Symbol, precision_type, 
                                   normalized::Bool=false, power_of_two_denom::Bool=false,
                                   verbose::Int=0)
    return Dict(
        "degree" => degree,
        "basis" => string(basis),
        "precision_type" => string(precision_type),
        "normalized" => normalized,
        "power_of_two_denom" => power_of_two_denom,
        "verbose" => verbose
    )
end

"""
    serialize_analysis_config(; tol_dist=0.025, enable_hessian=true, 
                             max_iters_in_optim=100, kwargs...) -> Dict

Serialize critical point analysis parameters.
"""
function serialize_analysis_config(; tol_dist=0.025, enable_hessian=true, 
                                  max_iters_in_optim=100, kwargs...)
    config = Dict(
        "tol_dist" => tol_dist,
        "enable_hessian" => enable_hessian,
        "max_iters_in_optim" => max_iters_in_optim
    )
    
    # Add additional parameters from kwargs
    for (key, value) in kwargs
        config[string(key)] = value
    end
    
    return config
end

"""
    serialize_computational_environment() -> Dict

Capture current computational environment information.
"""
function serialize_computational_environment()
    return Dict(
        "julia_version" => string(VERSION),
        "hostname" => gethostname(),
        "threads" => Threads.nthreads(),
        "slurm_job_id" => get(ENV, "SLURM_JOB_ID", nothing),
        "partition" => get(ENV, "SLURM_JOB_PARTITION", nothing)
    )
end

"""
    create_input_config(TR, degree::Int, basis::Symbol, precision_type;
                       analysis_params::Dict=Dict(), metadata::Dict=Dict()) -> Dict

Create complete input configuration dictionary.
"""
function create_input_config(TR, degree::Int, basis::Symbol, precision_type;
                           analysis_params::Dict=Dict(), metadata::Dict=Dict(),
                           normalized::Bool=false, power_of_two_denom::Bool=false)
    
    config = serialize_test_input(TR, metadata)
    
    config["polynomial_construction"] = serialize_polynomial_config(
        degree, basis, precision_type, normalized, power_of_two_denom
    )
    
    config["critical_point_analysis"] = analysis_params
    config["computational_environment"] = serialize_computational_environment()
    
    return config
end

"""
    save_input_config(config::Dict, filepath::String)

Save input configuration to JSON file.
"""
function save_input_config(config::Dict, filepath::String)
    mkpath(dirname(filepath))
    open(filepath, "w") do f
        JSON3.pretty(f, config)
    end
    println("✅ Input configuration saved to: $filepath")
end

"""
    serialize_polynomial_results(pol, construction_time::Float64) -> Dict

Serialize polynomial construction results.
"""
function serialize_polynomial_results(pol, construction_time::Float64)
    return Dict(
        "construction_time" => construction_time,
        "l2_error" => pol.nrm,
        "condition_number" => get(pol, :cond_vandermonde, nothing),
        "n_coefficients" => length(pol.coeffs),
        "n_samples_used" => get(pol, :GN, nothing),
        "convergence_achieved" => true,  # Assume success if we have results
        "basis_used" => string(get(pol, :basis, "unknown")),
        "precision_used" => string(get(pol, :precision, "unknown"))
    )
end

"""
    serialize_critical_point_results(df_critical, df_min, solving_time::Float64, 
                                    analysis_time::Float64, n_raw_solutions::Int) -> Dict

Serialize critical point analysis results.
"""
function serialize_critical_point_results(df_critical, df_min, solving_time::Float64, 
                                         analysis_time::Float64, n_raw_solutions::Int)
    n_critical = nrow(df_critical)
    n_minima = nrow(df_min)
    
    # Calculate convergence statistics if available
    convergence_stats = Dict(
        "n_converged" => n_critical,  # Assume all converged if in results
        "n_failed" => 0
    )
    
    # Calculate function value statistics
    function_stats = Dict()
    if n_critical > 0 && "z" in names(df_critical)
        function_stats = Dict(
            "min_value" => minimum(df_critical.z),
            "max_value" => maximum(df_critical.z),
            "mean_value" => mean(df_critical.z),
            "global_minimum_value" => minimum(df_critical.z)
        )
    end
    
    return Dict(
        "solving_time" => solving_time,
        "analysis_time" => analysis_time,
        "n_raw_solutions" => n_raw_solutions,
        "n_real_solutions" => n_raw_solutions,  # Approximate
        "n_valid_critical_points" => n_critical,
        "n_local_minima" => n_minima,
        "convergence_statistics" => convergence_stats,
        "function_value_statistics" => function_stats
    )
end

"""
    serialize_hessian_results(df_critical; computation_time::Float64=0.0) -> Dict

Serialize Hessian analysis results if available.
"""
function serialize_hessian_results(df_critical; computation_time::Float64=0.0)
    if !("critical_point_type" in names(df_critical))
        return Dict("enabled" => false)
    end
    
    # Count classifications
    classifications = df_critical.critical_point_type
    classification_counts = Dict(
        "minimum" => count(==(Symbol("minimum")), classifications),
        "maximum" => count(==(Symbol("maximum")), classifications),
        "saddle" => count(==(Symbol("saddle")), classifications),
        "degenerate" => count(==(Symbol("degenerate")), classifications),
        "unknown" => count(==(Symbol("unknown")), classifications)
    )
    
    # Eigenvalue statistics if available
    eigenval_stats = Dict()
    if "smallest_positive_eigenval" in names(df_critical)
        pos_eigenvals = filter(!isnan, df_critical.smallest_positive_eigenval)
        if !isempty(pos_eigenvals)
            eigenval_stats["min_positive_eigenval"] = minimum(pos_eigenvals)
        end
    end
    
    return Dict(
        "enabled" => true,
        "computation_time" => computation_time,
        "classification_counts" => classification_counts,
        "eigenvalue_statistics" => eigenval_stats
    )
end

"""
    create_output_results(computation_id::String, start_time::DateTime, end_time::DateTime,
                         pol, df_critical, df_min, timings::Dict) -> Dict

Create complete output results dictionary.
"""
function create_output_results(computation_id::String, start_time::DateTime, end_time::DateTime,
                              pol, df_critical, df_min, timings::Dict)
    
    total_runtime = (end_time - start_time).value / 1000.0  # Convert to seconds
    
    results = Dict(
        "metadata" => Dict(
            "computation_id" => computation_id,
            "timestamp_start" => string(start_time),
            "timestamp_end" => string(end_time),
            "total_runtime" => total_runtime,
            "status" => "SUCCESS",
            "warnings" => String[]
        ),
        
        "polynomial_results" => serialize_polynomial_results(
            pol, get(timings, "construction_time", 0.0)
        ),
        
        "critical_point_results" => serialize_critical_point_results(
            df_critical, df_min,
            get(timings, "solving_time", 0.0),
            get(timings, "analysis_time", 0.0),
            get(timings, "n_raw_solutions", nrow(df_critical))
        ),
        
        "hessian_analysis" => serialize_hessian_results(
            df_critical, computation_time=get(timings, "hessian_time", 0.0)
        ),
        
        "quality_metrics" => Dict(
            "overall_success" => true
        )
    )
    
    return results
end

"""
    save_output_results(results::Dict, filepath::String)

Save output results to JSON file.
"""
function save_output_results(results::Dict, filepath::String)
    mkpath(dirname(filepath))
    open(filepath, "w") do f
        JSON3.pretty(f, results)
    end
    println("✅ Output results saved to: $filepath")
end

"""
    save_detailed_outputs(df_critical, df_min, pol, output_dir::String)

Save detailed outputs (CSV files, etc.) to specified directory.
"""
function save_detailed_outputs(df_critical, df_min, pol, output_dir::String)
    mkpath(output_dir)
    
    # Save critical points
    if nrow(df_critical) > 0
        CSV.write(joinpath(output_dir, "critical_points.csv"), df_critical)
    end
    
    # Save minima
    if nrow(df_min) > 0
        CSV.write(joinpath(output_dir, "minima.csv"), df_min)
    end
    
    # Save polynomial coefficients
    coeffs_data = Dict(
        "coefficients" => pol.coeffs,
        "degree" => get(pol, :degree, nothing),
        "basis" => string(get(pol, :basis, "unknown")),
        "l2_error" => pol.nrm
    )
    
    open(joinpath(output_dir, "polynomial_coeffs.json"), "w") do f
        JSON3.pretty(f, coeffs_data)
    end
    
    println("✅ Detailed outputs saved to: $output_dir")
end

"""
    compute_parameter_hash(config::Dict) -> String

Compute SHA256 hash of input parameters for duplicate detection.
"""
function compute_parameter_hash(config::Dict)
    # Extract only the computational parameters (exclude metadata)
    params = Dict(
        "test_input" => config["test_input"],
        "polynomial_construction" => config["polynomial_construction"],
        "critical_point_analysis" => get(config, "critical_point_analysis", Dict())
    )

    param_string = JSON3.write(params)
    return bytes2hex(sha256(param_string))
end

"""
    load_input_config(filepath::String) -> Dict

Load input configuration from JSON file.
"""
function load_input_config(filepath::String)
    if !isfile(filepath)
        error("Input configuration file not found: $filepath")
    end

    return JSON3.read(read(filepath, String), Dict)
end

"""
    load_output_results(filepath::String) -> Dict

Load output results from JSON file.
"""
function load_output_results(filepath::String)
    if !isfile(filepath)
        error("Output results file not found: $filepath")
    end

    return JSON3.read(read(filepath, String), Dict)
end

"""
    create_computation_directory(base_dir::String, function_name::String,
                                computation_id::String, description::String="") -> String

Create organized directory structure for a computation.
"""
function create_computation_directory(base_dir::String, function_name::String,
                                    computation_id::String, description::String="")
    # Create timestamp
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")

    # Create directory name
    if isempty(description)
        dir_name = "$(function_name)_$(timestamp)_$(computation_id)"
    else
        dir_name = "$(description)_$(timestamp)_$(computation_id)"
    end

    # Create full path
    year_month = Dates.format(now(), "yyyy-mm")
    full_path = joinpath(base_dir, "by_function", function_name, year_month, "single_tests", dir_name)

    # Create directories
    mkpath(full_path)
    mkpath(joinpath(full_path, "detailed_outputs"))
    mkpath(joinpath(full_path, "logs"))

    return full_path
end

"""
    validate_input_config(config::Dict) -> Bool

Validate input configuration against schema requirements.
"""
function validate_input_config(config::Dict)
    required_fields = ["metadata", "test_input", "polynomial_construction"]

    for field in required_fields
        if !haskey(config, field)
            @warn "Missing required field: $field"
            return false
        end
    end

    # Validate metadata
    metadata = config["metadata"]
    if !haskey(metadata, "computation_id") || !haskey(metadata, "function_name")
        @warn "Missing required metadata fields"
        return false
    end

    # Validate test_input
    test_input = config["test_input"]
    required_test_fields = ["function_name", "dimension", "center", "sample_range"]
    for field in required_test_fields
        if !haskey(test_input, field)
            @warn "Missing required test_input field: $field"
            return false
        end
    end

    return true
end

"""
    create_symlinks(computation_dir::String, computation_id::String,
                   function_name::String, tags::Vector{String})

Create symlinks for alternative access patterns.
"""
function create_symlinks(computation_dir::String, computation_id::String,
                        function_name::String, tags::Vector{String})
    base_dir = dirname(dirname(dirname(dirname(computation_dir))))  # Go up to results/
    # Note: function_name parameter available for future function-specific symlink organization

    # Create by_date symlink
    date_str = Dates.format(now(), "yyyy-mm-dd")
    date_dir = joinpath(base_dir, "by_date", date_str)
    mkpath(date_dir)

    date_link = joinpath(date_dir, computation_id)
    if !islink(date_link)
        symlink(relpath(computation_dir, date_dir), date_link)
    end

    # Create by_tag symlinks
    for tag in tags
        tag_dir = joinpath(base_dir, "by_tag", tag)
        mkpath(tag_dir)

        tag_link = joinpath(tag_dir, computation_id)
        if !islink(tag_link)
            symlink(relpath(computation_dir, tag_dir), tag_link)
        end
    end
end

"""
    create_parameter_sweep_config(base_config::Dict, parameter_ranges::Dict) -> Vector{Dict}

Generate parameter sweep configurations for systematic testing.
"""
function create_parameter_sweep_config(base_config::Dict, parameter_ranges::Dict)
    configs = Dict[]

    # Get all parameter combinations
    param_names = collect(keys(parameter_ranges))
    param_values = [parameter_ranges[name] for name in param_names]

    # Generate all combinations
    for combination in Iterators.product(param_values...)
        config = deepcopy(base_config)

        # Update configuration with parameter values
        for (i, param_name) in enumerate(param_names)
            value = combination[i]

            # Handle nested parameter paths (e.g., "polynomial_construction.degree")
            if contains(param_name, ".")
                parts = split(param_name, ".")
                current = config
                for part in parts[1:end-1]
                    if !haskey(current, part)
                        current[part] = Dict()
                    end
                    current = current[part]
                end
                current[parts[end]] = value
            else
                config[param_name] = value
            end
        end

        # Generate unique computation ID for this configuration
        config["metadata"]["computation_id"] = generate_computation_id()
        config["metadata"]["parameter_sweep"] = Dict(
            "is_sweep" => true,
            "parameters" => Dict(zip(param_names, combination)),
            "parameter_hash" => compute_parameter_hash(config)
        )

        push!(configs, config)
    end

    return configs
end

"""
    save_parameter_sweep_manifest(configs::Vector{Dict}, base_dir::String) -> String

Save parameter sweep manifest for tracking and analysis.
"""
function save_parameter_sweep_manifest(configs::Vector{Dict}, base_dir::String)
    manifest = Dict(
        "sweep_metadata" => Dict(
            "sweep_id" => generate_computation_id(),
            "timestamp" => string(now()),
            "total_configurations" => length(configs),
            "base_directory" => base_dir
        ),
        "configurations" => [
            Dict(
                "computation_id" => config["metadata"]["computation_id"],
                "parameters" => get(get(config["metadata"], "parameter_sweep", Dict()), "parameters", Dict()),
                "parameter_hash" => get(get(config["metadata"], "parameter_sweep", Dict()), "parameter_hash", compute_parameter_hash(config)),
                "description" => get(config["metadata"], "description", ""),
                "tags" => get(config["metadata"], "tags", String[])
            ) for config in configs
        ]
    )

    manifest_path = joinpath(base_dir, "parameter_sweep_manifest.json")
    mkpath(dirname(manifest_path))

    open(manifest_path, "w") do f
        JSON3.pretty(f, manifest)
    end

    println("✅ Parameter sweep manifest saved: $manifest_path")
    return manifest_path
end

"""
    aggregate_sweep_results(results_dir::String) -> Dict

Aggregate results from a parameter sweep for analysis.
"""
function aggregate_sweep_results(results_dir::String)
    # Find all result files in the directory
    result_files = []
    for (root, dirs, files) in walkdir(results_dir)
        for file in files
            if endswith(file, "_results.json")
                push!(result_files, joinpath(root, file))
            end
        end
    end

    if isempty(result_files)
        @warn "No result files found in $results_dir"
        return Dict()
    end

    # Load and aggregate results
    aggregated = Dict(
        "sweep_summary" => Dict(
            "total_computations" => length(result_files),
            "aggregation_timestamp" => string(now()),
            "results_directory" => results_dir
        ),
        "parameter_analysis" => Dict(),
        "performance_analysis" => Dict(),
        "quality_analysis" => Dict(),
        "individual_results" => []
    )

    # Collect data from all results
    l2_errors = Float64[]
    construction_times = Float64[]
    solving_times = Float64[]
    n_critical_points = Int[]

    for result_file in result_files
        try
            result = load_output_results(result_file)

            # Extract key metrics
            push!(l2_errors, result["polynomial_results"]["l2_error"])
            push!(construction_times, result["polynomial_results"]["construction_time"])
            push!(solving_times, result["critical_point_results"]["solving_time"])
            push!(n_critical_points, result["critical_point_results"]["n_valid_critical_points"])

            # Store individual result summary
            push!(aggregated["individual_results"], Dict(
                "computation_id" => result["metadata"]["computation_id"],
                "l2_error" => result["polynomial_results"]["l2_error"],
                "n_critical_points" => result["critical_point_results"]["n_valid_critical_points"],
                "total_time" => result["metadata"]["total_runtime"]
            ))

        catch e
            @warn "Failed to process result file: $result_file" exception=e
        end
    end

    # Compute aggregate statistics
    if !isempty(l2_errors)
        aggregated["performance_analysis"] = Dict(
            "l2_error_stats" => Dict(
                "mean" => mean(l2_errors),
                "std" => std(l2_errors),
                "min" => minimum(l2_errors),
                "max" => maximum(l2_errors)
            ),
            "timing_stats" => Dict(
                "construction_time" => Dict(
                    "mean" => mean(construction_times),
                    "std" => std(construction_times)
                ),
                "solving_time" => Dict(
                    "mean" => mean(solving_times),
                    "std" => std(solving_times)
                )
            ),
            "critical_points_stats" => Dict(
                "mean" => mean(n_critical_points),
                "std" => std(n_critical_points),
                "min" => minimum(n_critical_points),
                "max" => maximum(n_critical_points)
            )
        )
    end

    return aggregated
end

# Export main functions
export generate_computation_id, serialize_test_input, create_input_config, save_input_config
export create_output_results, save_output_results, save_detailed_outputs
export compute_parameter_hash, load_input_config, load_output_results
export create_computation_directory, validate_input_config, create_symlinks
export create_parameter_sweep_config, save_parameter_sweep_manifest, aggregate_sweep_results
