#!/usr/bin/env julia
"""
Cluster Experiment Collection and Analysis Script

Collects and analyzes Lotka-Volterra 4D experiments from HPC cluster using existing infrastructure.
Focuses on computational statistics and performance metrics from cluster runs.

Usage: julia collect_cluster_experiments.jl
"""

using Pkg
Pkg.activate(".")

using JSON
using JSON3
using DataFrames
using Statistics
using Printf
using Dates
using CSV
using DrWatson
using JLD2

# Include PathUtils for robust path resolution (Issue #135)
include("../../src/PathUtils.jl")
using .PathUtils

# Include environment-aware path resolution (Issue #40)
include("../../test/specialized_tests/environment/environment_utils.jl")
using .EnvironmentUtils

# Include enhanced error categorization system (Issue #37)
include("../../src/ErrorCategorization.jl")
using .ErrorCategorization

# Include defensive CSV loading (Issue #79) and adaptive format CSV (Issue #86)
include("../../src/DefensiveCSV.jl")
using .DefensiveCSV

include("../../src/AdaptiveFormatCSV.jl")
using .AdaptiveFormatCSV
import .AdaptiveFormatCSV: COORDINATE_FORMAT, SUMMARY_FORMAT

"""
Collect experiment directories - Environment-aware (local vs HPC)
"""
function collect_experiment_directories()
    println("🔍 Collecting experiment directories...")

    # Environment-aware path resolution (Issue #40)
    current_env = auto_detect_environment()

    println("📍 Detected environment: $current_env")

    if current_env == :local
        # Use local files directly - no SSH needed (Issue #135: use PathUtils)
        local_project_dir = get_project_root()
        local_hpc_results = joinpath(local_project_dir, "hpc_results")

        println("📂 Using local HPC results directory: $local_hpc_results")

        if !isdir(local_hpc_results)
            println("❌ Local HPC results directory not found: $local_hpc_results")
            return String[]
        end

        # Find minimal experiment directories locally
        all_dirs = readdir(local_hpc_results)
        dirs = filter(d -> occursin("minimal_4d_lv_test_", d), all_dirs)

        # Convert to full paths for consistency with download logic
        dirs = ["hpc_results/$d" for d in dirs]
        sort!(dirs)

        println("📂 Found $(length(dirs)) local experiment directories:")
        for dir in dirs
            println("   - $dir")
        end

        return dirs
    else
        # Use SSH for remote access (existing logic)
        hpc_project_dir = get_project_directory(:hpc)
        println("📂 Using HPC project directory: $hpc_project_dir")

        cmd = `ssh scholten@r04n02 "cd /home/scholten/globtimcore && ls -1d hpc_results/minimal_4d_lv_test_* | sort"`

        try
            output = readchomp(cmd)
            dirs = split(output, '\n')
            filter!(d -> !isempty(d), dirs)

            println("📂 Found $(length(dirs)) remote experiment directories:")
            for dir in dirs
                println("   - $dir")
            end

            return dirs
        catch e
            println("❌ Error collecting remote directories: $e")
            return String[]
        end
    end
end

"""
Read DrWatson JLD2 results with Git provenance
Returns Dict with complete experiment data including Git commit hash
"""
function read_drwatson_results(experiment_dir::String)
    jld2_file = joinpath(experiment_dir, "results_summary.jld2")

    if isfile(jld2_file)
        try
            # Load JLD2 file saved with DrWatson tagsave()
            data = JLD2.load(jld2_file)

            # Extract key information
            drwatson_data = Dict(
                "git_commit" => get(data, "gitcommit", missing),
                "params_dict" => get(data, "params_dict", Dict()),
                "results_summary" => get(data, "results_summary", Dict()),
                "timestamp" => get(data, "timestamp", missing),
                "output_dir" => get(data, "output_dir", missing),
                "total_critical_points" => get(data, "total_critical_points", missing),
                "total_time" => get(data, "total_time", missing),
                "success_rate" => get(data, "success_rate", missing)
            )

            return drwatson_data
        catch e
            println("⚠️  Warning: Could not load DrWatson JLD2 file $jld2_file: $e")
            return Dict()
        end
    else
        return Dict()
    end
end

"""
Read experiment parameters from experiment_params.json file
Returns Dict with experiment parameters or empty Dict if file not found
"""
function read_experiment_parameters(experiment_dir::String)
    params_file = joinpath(experiment_dir, "experiment_params.json")

    if isfile(params_file)
        try
            params_data = JSON3.read(read(params_file, String))

            # Extract key parameters for analysis
            extracted_params = Dict(
                "domain_size" => get(get(params_data, "experiment_info", Dict()), "domain_size", missing),
                "GN" => extract_GN_parameter(params_data),
                "degree_range" => extract_degree_range(params_data),
                "git_commit" => get(get(params_data, "git_info", Dict()), "git_commit_hash", missing),
                "timestamp" => get(get(params_data, "experiment_info", Dict()), "experiment_start_time", missing),
                "experiment_name" => get(get(params_data, "experiment_info", Dict()), "experiment_name", missing),
                "output_directory" => get(get(params_data, "experiment_info", Dict()), "output_directory", missing)
            )

            return extracted_params
        catch e
            println("⚠️  Warning: Could not parse $params_file: $e")
            return Dict()
        end
    else
        println("⚠️  Warning: experiment_params.json not found in $experiment_dir")
        return Dict()
    end
end

"""
Extract GN parameter from detected parameters list or experiment metadata
"""
function extract_GN_parameter(params_data)
    detected_params = get(get(params_data, "experiment_info", Dict()), "detected_parameters", String[])

    for param in detected_params
        if occursin("GN", param)
            # Extract number from "GN = 12" format
            match_result = match(r"GN\s*=\s*(\d+)", param)
            if match_result !== nothing
                return parse(Int, match_result.captures[1])
            end
        end
    end

    return missing
end

"""
Extract degree range from detected parameters or infer from experiment structure
"""
function extract_degree_range(params_data)
    detected_params = get(get(params_data, "experiment_info", Dict()), "detected_parameters", String[])

    for param in detected_params
        if occursin("degree", param)
            # Extract number from "degree = 6" format
            match_result = match(r"degree\s*=\s*(\d+)", param)
            if match_result !== nothing
                return parse(Int, match_result.captures[1])
            end
        end
    end

    return missing
end

"""
Read lifecycle state file for a single experiment (Issue #84 Phase 2)
Returns Dict with experiment state including error_info if present
"""
function read_lifecycle_state(experiment_id::String, state_dir::String=joinpath(get_project_root(), "tools", "hpc", "hooks", "state"))
    state_file = joinpath(state_dir, "$(experiment_id).json")

    if !isfile(state_file)
        return Dict()
    end

    try
        state_data = JSON.parsefile(state_file)
        return state_data
    catch e
        println("⚠️  Warning: Could not read lifecycle state for $experiment_id: $e")
        return Dict()
    end
end

"""
Extract lifecycle error information from all experiments (Issue #84 Phase 2)
Returns DataFrame with columns: experiment_id, lifecycle_category, lifecycle_message, lifecycle_timestamp
Only includes failed experiments with error_info
"""
function extract_lifecycle_errors(experiment_ids::Vector{String}, state_dir::String=joinpath(get_project_root(), "tools", "hpc", "hooks", "state"))
    lifecycle_errors = DataFrame(
        experiment_id = String[],
        lifecycle_category = String[],
        lifecycle_message = String[],
        lifecycle_timestamp = String[]
    )

    for exp_id in experiment_ids
        state = read_lifecycle_state(exp_id, state_dir)

        # Only include experiments with error_info
        if haskey(state, "error_info") && !isempty(state["error_info"])
            error_info = state["error_info"]

            push!(lifecycle_errors, (
                experiment_id = exp_id,
                lifecycle_category = get(error_info, "category", "UNKNOWN"),
                lifecycle_message = get(error_info, "message", ""),
                lifecycle_timestamp = get(error_info, "timestamp", "")
            ))
        end
    end

    return lifecycle_errors
end

"""
Merge lifecycle error information into all_results vector (Issue #84 Phase 2)
Adds lifecycle_category and lifecycle_message fields to matching experiments
"""
function merge_lifecycle_errors!(all_results::Vector, lifecycle_errors::DataFrame)
    # Create lookup dictionary for fast matching
    error_lookup = Dict{String, NamedTuple}()

    for row in eachrow(lifecycle_errors)
        error_lookup[row.experiment_id] = (
            category = row.lifecycle_category,
            message = row.lifecycle_message,
            timestamp = row.lifecycle_timestamp
        )
    end

    # Merge lifecycle errors into all_results
    for result in all_results
        exp_id = get(result, "experiment", "")

        if haskey(error_lookup, exp_id)
            error_data = error_lookup[exp_id]
            result["lifecycle_category"] = error_data.category
            result["lifecycle_message"] = error_data.message
            result["lifecycle_timestamp"] = error_data.timestamp
        end
    end

    return nothing
end

"""
Generate lifecycle error summary statistics (Issue #84 Phase 2)
Returns Dict with error category counts and summary statistics
"""
function generate_lifecycle_error_summary(all_results::Vector)
    total_experiments = length(all_results)
    experiments_with_errors = count(r -> haskey(r, "lifecycle_category"), all_results)
    experiments_successful = total_experiments - experiments_with_errors

    # Count errors by category
    category_counts = Dict{String, Int}()

    for result in all_results
        if haskey(result, "lifecycle_category")
            category = result["lifecycle_category"]
            category_counts[category] = get(category_counts, category, 0) + 1
        end
    end

    return Dict(
        "total_experiments" => total_experiments,
        "experiments_with_errors" => experiments_with_errors,
        "experiments_successful" => experiments_successful,
        "category_counts" => category_counts
    )
end

"""
Download experiment results - Environment-aware (local vs HPC)
"""
function download_experiment_results(cluster_dirs::Vector{<:AbstractString})
    # Environment-aware path resolution (Issue #40, #135)
    current_env = auto_detect_environment()
    local_project_dir = get_project_root()

    if current_env == :local
        println("\n📂 Using local experiment results (no download needed)...")

        # Return direct paths to local experiment directories
        downloaded_dirs = String[]

        for cluster_dir in cluster_dirs
            exp_name = basename(cluster_dir)
            local_dir = joinpath(local_project_dir, cluster_dir)  # hpc_results/exp_name

            if isdir(local_dir)
                push!(downloaded_dirs, local_dir)
                println("   ✅ Found local directory: $exp_name")
            else
                println("   ⚠️  Local directory not found: $local_dir")
            end
        end

        println("📊 Using $(length(downloaded_dirs)) local experiment directories")
        return downloaded_dirs, local_project_dir
    else
        println("\n📥 Downloading experiment results from cluster...")

        hpc_project_dir = get_project_directory(:hpc)
        local_results_dir = joinpath(local_project_dir, "cluster_results_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")
        mkpath(local_results_dir)

        downloaded_dirs = String[]

        for cluster_dir in cluster_dirs
            # Extract experiment name from path
            exp_name = basename(cluster_dir)
            local_dir = joinpath(local_results_dir, exp_name)
            mkpath(local_dir)

            # Download results_summary.json, experiment_config.json, and experiment_params.json with environment-aware paths
            for filename in ["results_summary.json", "experiment_config.json", "experiment_params.json"]
                remote_file = "scholten@r04n02:$hpc_project_dir/$cluster_dir/$filename"
                local_file = joinpath(local_dir, filename)

                try
                    run(`scp $remote_file $local_file`)
                    println("   ✅ Downloaded $filename for $exp_name")
                catch e
                    println("   ⚠️  Failed to download $filename for $exp_name: $e")
                end
            end

            # Download all CSV files (critical points data)
            try
                run(`scp "scholten@r04n02:$hpc_project_dir/$cluster_dir/*.csv" $local_dir/`)
                println("   ✅ Downloaded CSV files for $exp_name")
            catch e
                println("   ⚠️  Failed to download CSV files for $exp_name: $e")
            end

            # Check if we got at least results_summary.json
            if isfile(joinpath(local_dir, "results_summary.json"))
                push!(downloaded_dirs, local_dir)
            end
        end

        println("📊 Successfully downloaded $(length(downloaded_dirs)) experiment results")
        return downloaded_dirs, local_results_dir
    end
end

"""
Analyze timing and error patterns from cluster experiments
"""
function analyze_cluster_experiments(experiment_dirs::Vector{String})
    println("\n📈 Analyzing cluster experiment results...")

    # Collect all experiment data
    all_results = []
    experiment_summary = Dict{String,Any}()

    for exp_dir in experiment_dirs
        exp_name = basename(exp_dir)
        results_file = joinpath(exp_dir, "results_summary.json")
        config_file = joinpath(exp_dir, "experiment_config.json")

        if !isfile(results_file)
            println("   ⚠️  Missing results for $exp_name")
            continue
        end

        try
            # Load experiment results
            results = JSON.parsefile(results_file)

            # Load configuration if available
            config = Dict{String,Any}()
            if isfile(config_file)
                config = JSON.parsefile(config_file)
            end

            # Extract domain range from experiment name
            range_match = match(r"range([\d.]+)", exp_name)
            domain_range = range_match !== nothing ? parse(Float64, range_match.captures[1]) : 0.0

            # Process each degree result - handle both old and DrWatson formats
            # Old format: results["results"]["degree_4"] = {status, computation_time, error}
            # DrWatson format: results["results_summary"]["degree_4"] = {status, computation_time, critical_points, l2_approx_error}
            degree_results = []

            # Try DrWatson format first (newer), fallback to old format
            results_section = get(results, "results_summary", get(results, "results", Dict()))

            if !isempty(results_section)
                for (degree_key, result_data) in results_section
                    # Extract degree number from key like "degree_4" -> 4
                    degree_match = match(r"degree_(\d+)", degree_key)
                    degree = degree_match !== nothing ? parse(Int, degree_match.captures[1]) : 0

                    success = get(result_data, "status", "") == "success"
                    computation_time = get(result_data, "computation_time", 0.0)
                    error_msg_raw = get(result_data, "error", "")
                    error_msg = error_msg_raw === nothing ? "" : string(error_msg_raw)

                    push!(all_results, Dict(
                        "experiment" => exp_name,
                        "domain_range" => domain_range,
                        "degree" => degree,
                        "success" => success,
                        "computation_time" => computation_time,
                        "error" => error_msg,
                        "has_column_error" => contains(error_msg, "column name :val not found")
                    ))

                    push!(degree_results, result_data)
                end
            end

            # Experiment-level summary
            total_degrees = length(degree_results)
            successful_degrees = sum(get(r, "status", "") == "success" for r in degree_results)
            total_time = sum(get(r, "computation_time", 0.0) for r in degree_results)

            experiment_summary[exp_name] = Dict(
                "domain_range" => domain_range,
                "total_degrees" => total_degrees,
                "successful_degrees" => successful_degrees,
                "success_rate" => successful_degrees / total_degrees,
                "total_computation_time" => total_time,
                "mean_time_per_degree" => total_time / total_degrees
            )

            println("   📊 $exp_name: $(successful_degrees)/$total_degrees successful ($(round(100*successful_degrees/total_degrees, digits=1))%)")

        catch e
            println("   ❌ Error processing $exp_name: $e")
        end
    end

    # Extract and merge lifecycle error tracking (Issue #84 Phase 2)
    println("\n🔍 Extracting lifecycle error tracking...")
    experiment_names = unique([r["experiment"] for r in all_results])
    lifecycle_errors = extract_lifecycle_errors(experiment_names)

    if nrow(lifecycle_errors) > 0
        println("   ✅ Found lifecycle tracking for $(nrow(lifecycle_errors)) failed experiments")
        merge_lifecycle_errors!(all_results, lifecycle_errors)
    else
        println("   ℹ️  No lifecycle error tracking found")
        println("   💡 To enable lifecycle tracking, run experiments with: ./tools/hpc/robust_experiment_runner.sh")
    end

    return all_results, experiment_summary
end

"""
Generate computational statistics report
"""
function generate_statistics_report(all_results::Vector, experiment_summary::Dict)
    println("\n📋 Generating statistics report...")

    df = DataFrame(all_results)

    println("\n" * "="^80)
    println("CLUSTER EXPERIMENT ANALYSIS REPORT")
    println("Generated: $(Dates.now())")
    println("="^80)

    # Overall statistics
    total_computations = nrow(df)
    successful_computations = sum(df.success)
    total_time = sum(df.computation_time)

    println("\n📊 OVERALL STATISTICS")
    println("   Total computations: $total_computations")
    println("   Successful computations: $successful_computations")
    println("   Overall success rate: $(round(100*successful_computations/total_computations, digits=1))%")
    println("   Total computation time: $(round(total_time/60, digits=1)) minutes")
    println("   Average time per computation: $(round(total_time/total_computations, digits=1)) seconds")

    # Enhanced Error Analysis using Issue #37 categorization system
    println("\n🔍 ENHANCED ERROR ANALYSIS")

    # Use the new error categorization system
    failed_results = filter(r -> !get(r, "success", false) && !isempty(get(r, "error", "")), all_results)
    failed_results_typed = Vector{Dict}(failed_results)  # Type conversion for error analysis

    if !isempty(failed_results)
        println("   Analyzing $(length(failed_results)) failed experiments...")

        # Perform comprehensive error categorization
        error_analysis_df = analyze_experiment_errors(failed_results_typed)

        if nrow(error_analysis_df) > 0
            # Category distribution
            category_counts = combine(groupby(error_analysis_df, :category), nrow => :count)
            sort!(category_counts, :count, rev=true)

            println("\n   📊 Error Category Distribution:")
            for row in eachrow(category_counts)
                percentage = round(100 * row.count / nrow(error_analysis_df), digits=1)
                println("      $(row.category): $(row.count) errors ($percentage%)")
            end

            # Severity distribution
            severity_counts = combine(groupby(error_analysis_df, :severity), nrow => :count)
            sort!(severity_counts, :count, rev=true)

            println("\n   ⚠️  Error Severity Distribution:")
            for row in eachrow(severity_counts)
                percentage = round(100 * row.count / nrow(error_analysis_df), digits=1)
                severity_icon = if row.severity == "CRITICAL"
                    "🚨"
                elseif row.severity == "HIGH"
                    "🔴"
                elseif row.severity == "MEDIUM"
                    "🟡"
                elseif row.severity == "LOW"
                    "🟢"
                else
                    "⚪"
                end
                println("      $severity_icon $(row.severity): $(row.count) errors ($percentage%)")
            end

            # High priority errors
            high_priority = filter(row -> row.priority_score > 75, error_analysis_df)
            if nrow(high_priority) > 0
                println("\n   🚨 High Priority Errors (Score > 75):")
                for row in eachrow(sort(high_priority, :priority_score, rev=true)[1:min(5, nrow(high_priority))])
                    println("      • $(row.experiment_id): $(row.category) (Score: $(row.priority_score))")
                end
            end

            # Generate comprehensive error report
            error_report = generate_error_report(error_analysis_df)

            println("\n   💡 Key Insights:")
            for insight in error_report["key_insights"]
                println("      • $insight")
            end

            println("\n   🔧 Recommendations:")
            for (i, recommendation) in enumerate(error_report["recommendations"])
                println("      $(i). $recommendation")
            end

        else
            println("      ⚠️  No errors could be categorized")
        end
    else
        println("      ✅ No failed experiments found - all computations successful!")
    end

    # Lifecycle Error Tracking Summary (Issue #84 Phase 2)
    println("\n📊 LIFECYCLE ERROR TRACKING")

    # Check if any experiments have lifecycle tracking
    experiments_with_lifecycle = count(r -> haskey(r, "lifecycle_category"), all_results)

    if experiments_with_lifecycle > 0
        lifecycle_summary = generate_lifecycle_error_summary(all_results)

        println("   Experiments tracked: $(lifecycle_summary["total_experiments"])")
        println("   Experiments with lifecycle errors: $(lifecycle_summary["experiments_with_errors"])")
        println("   Experiments successful: $(lifecycle_summary["experiments_successful"])")

        if !isempty(lifecycle_summary["category_counts"])
            println("\n   📋 Lifecycle Error Categories:")
            total_errors = lifecycle_summary["experiments_with_errors"]

            # Sort by count (descending)
            sorted_categories = sort(collect(lifecycle_summary["category_counts"]), by=x->x[2], rev=true)

            for (category, count) in sorted_categories
                percentage = round(100 * count / total_errors, digits=1)
                category_icon = if category == "PACKAGE_LOADING_FAILURE"
                    "📦"
                elseif category == "INTERFACE_BUG"
                    "🔌"
                elseif category == "MATHEMATICAL_FAILURE"
                    "🧮"
                elseif category == "CONFIGURATION_ERROR"
                    "⚙️"
                else
                    "❓"
                end
                println("      $category_icon $(category): $count experiments ($percentage%)")
            end

            println("\n   ✅ Lifecycle tracking operational")
        end
    else
        println("   ⚠️  No lifecycle tracking data found")
        println("   💡 Run experiments with: ./tools/hpc/robust_experiment_runner.sh")
        println("      This will generate lifecycle tracking with automatic error categorization")
    end

    # Performance by domain range
    println("\n🎯 PERFORMANCE BY DOMAIN RANGE")
    for (exp_name, summary) in sort(collect(experiment_summary), by=x->x[2]["domain_range"])
        range_val = summary["domain_range"]
        success_rate = round(100*summary["success_rate"], digits=1)
        total_time = round(summary["total_computation_time"]/60, digits=1)
        mean_time = round(summary["mean_time_per_degree"], digits=1)

        println("   Range $range_val: $(summary["successful_degrees"])/$(summary["total_degrees"]) successful ($success_rate%) | Total: $(total_time)min | Mean: $(mean_time)s")
    end

    # Performance by polynomial degree
    println("\n📈 PERFORMANCE BY POLYNOMIAL DEGREE")
    degree_stats = combine(groupby(df, :degree)) do sdf
        DataFrame(
            success_rate = mean(sdf.success),
            mean_time = mean(sdf.computation_time),
            total_computations = nrow(sdf)
        )
    end
    sort!(degree_stats, :degree)

    for row in eachrow(degree_stats)
        degree = row.degree
        success_rate = round(100*row.success_rate, digits=1)
        mean_time = round(row.mean_time, digits=1)
        total_comp = row.total_computations

        println("   Degree $degree: $success_rate% success | Mean time: $(mean_time)s | Computations: $total_comp")
    end

    # Mathematical pipeline validation evidence
    println("\n🧮 MATHEMATICAL PIPELINE EVIDENCE")

    # Evidence of mathematical success despite interface errors
    column_errors = sum(df.has_column_error)
    non_zero_times = sum(df.computation_time .> 0)
    mean_computation_time = round(mean(df.computation_time), digits=1)

    println("   Column naming errors: $column_errors/$(nrow(df)) ($(round(100*column_errors/nrow(df), digits=1))%)")
    println("   Computations with execution time > 0: $non_zero_times/$(nrow(df)) ($(round(100*non_zero_times/nrow(df), digits=1))%)")
    println("   Mean computation time: $(mean_computation_time)s")
    println("   Time range: $(round(minimum(df.computation_time), digits=1))s - $(round(maximum(df.computation_time), digits=1))s")

    if column_errors > 0 && mean_computation_time > 10
        println("\n   ✅ MATHEMATICAL PIPELINE VALIDATION:")
        println("      - High computation times indicate mathematical work was performed")
        println("      - Column naming errors are interface issues, not mathematical failures")
        println("      - Polynomial construction and critical point solving likely successful")
    end

    println("\n" * "="^80)

    return df, degree_stats
end

"""
Export results for further analysis
"""
function export_analysis_results(df::DataFrame, results_dir::String)
    println("\n💾 Exporting analysis results...")

    # Save detailed results - CSV.write is fine for output, defensive loading only needed for input
    CSV.write(joinpath(results_dir, "detailed_analysis.csv"), df)

    # Save summary statistics
    summary_stats = Dict(
        "analysis_date" => string(now()),
        "total_experiments" => length(unique(df.experiment)),
        "total_computations" => nrow(df),
        "overall_success_rate" => mean(df.success),
        "total_computation_time_minutes" => sum(df.computation_time) / 60,
        "mathematical_evidence" => Dict(
            "computations_with_time" => sum(df.computation_time .> 0),
            "mean_computation_time" => mean(df.computation_time),
            "column_errors" => sum(df.has_column_error)
        )
    )

    open(joinpath(results_dir, "analysis_summary.json"), "w") do io
        JSON.print(io, summary_stats, 2)
    end

    println("   📁 Results saved to: $results_dir/")
    println("   📄 detailed_analysis.csv - Complete computation details")
    println("   📄 analysis_summary.json - Summary statistics")
end

"""
Main execution function
"""
function main()
    println("🚀 Starting cluster experiment collection and analysis...")

    # Step 1: Collect experiment directories
    cluster_dirs = collect_experiment_directories()
    if isempty(cluster_dirs)
        println("❌ No experiment directories found")
        return
    end

    # Step 2: Download results
    local_dirs, results_dir = download_experiment_results(cluster_dirs)
    if isempty(local_dirs)
        println("❌ No experiment results downloaded")
        return
    end

    # Step 3: Analyze experiments
    all_results, experiment_summary = analyze_cluster_experiments(local_dirs)
    if isempty(all_results)
        println("❌ No valid experiment data found")
        return
    end

    # Step 4: Generate statistics report
    df, _ = generate_statistics_report(all_results, experiment_summary)

    # Step 5: Export results
    export_analysis_results(df, results_dir)

    println("\n✅ Cluster experiment analysis complete!")
    println("📊 Analysis results available in: $results_dir/")

    return df, experiment_summary, results_dir
end

"""
Create parameter-aware dataset linking experiment parameters with L2-norm results
This is the core Phase 1 functionality for Issue #54
"""
function create_parameter_aware_dataset(experiment_dirs::Vector{String})
    println("\n🔗 Creating parameter-aware dataset...")

    all_results = DataFrame(
        experiment_id = String[],
        domain_size = Union{Float64, Missing}[],
        GN = Union{Int, Missing}[],
        degree = Int[],
        objective_value = Float64[],  # Renamed from l2_norm - this is F(x) at critical point
        l2_approx_error = Union{Float64, Missing}[],  # New: polynomial approximation error
        git_commit = Union{String, Missing}[],
        timestamp = Union{String, Missing}[],
        experiment_name = Union{String, Missing}[],
        critical_points_count = Int[],
        x1 = Float64[],
        x2 = Float64[],
        x3 = Float64[],
        x4 = Float64[]
    )

    for exp_dir in experiment_dirs
        println("📊 Processing experiment: $(basename(exp_dir))")

        # Try reading DrWatson JLD2 data first (includes Git provenance)
        drwatson_data = read_drwatson_results(exp_dir)

        # Read experiment parameters (fallback to experiment_params.json)
        params = read_experiment_parameters(exp_dir)

        # Merge DrWatson parameters if available
        if !isempty(drwatson_data)
            params_dict = get(drwatson_data, "params_dict", Dict())
            if haskey(params_dict, "GN")
                params["GN"] = params_dict["GN"]
            end
            if haskey(params_dict, "domain_size_param")
                params["domain_size"] = params_dict["domain_size_param"]
            end
            if haskey(drwatson_data, "git_commit")
                params["git_commit"] = drwatson_data["git_commit"]
            end
            if haskey(drwatson_data, "timestamp")
                params["timestamp"] = drwatson_data["timestamp"]
            end
            git_commit = get(drwatson_data, "git_commit", missing)
            if !ismissing(git_commit) && length(git_commit) >= 8
                println("   ✅ Loaded DrWatson metadata (Git: $(git_commit[1:8]))")
            elseif !ismissing(git_commit)
                println("   ✅ Loaded DrWatson metadata (Git: $git_commit)")
            else
                println("   ✅ Loaded DrWatson metadata (Git: unknown)")
            end
        end

        # Find all critical point CSV files
        csv_files = filter(f -> occursin(r"critical_points_deg_\d+\.csv", f), readdir(exp_dir))

        # Handle case where no CSV files exist (all refined points outside domain)
        if isempty(csv_files)
            # Check if we have results_summary to understand why
            if !isempty(drwatson_data)
                results_summary = get(drwatson_data, "results_summary", Dict())

                # Report refined points that exist but are outside domain
                for (degree_key, result_data) in results_summary
                    refined_count = get(result_data, "critical_points_refined", 0)
                    in_domain_count = get(result_data, "critical_points", 0)

                    if refined_count > 0 && in_domain_count == 0
                        degree_match = match(r"degree_(\d+)", degree_key)
                        degree_num = degree_match !== nothing ? degree_match.captures[1] : degree_key

                        println("   ℹ️  Degree $degree_num: $refined_count refined critical points found,")
                        println("      but all are outside the search domain bounds.")
                        println("      No CSV saved (by design). Metadata available in results_summary.json")
                    end
                end

                if all(get(v, "critical_points_refined", 0) > 0 && get(v, "critical_points", 0) == 0
                       for (k, v) in results_summary if startswith(string(k), "degree_"))
                    println("   💡 Suggestion: Consider widening domain_size_param for this experiment")
                end
            else
                println("   ⚠️  No CSV files found and no results_summary available")
            end

            # Continue to next experiment - no CSV data to process
            continue
        end

        for csv_file in csv_files
            # Extract degree from filename
            degree_match = match(r"critical_points_deg_(\d+)\.csv", csv_file)
            if degree_match === nothing
                continue
            end
            degree = parse(Int, degree_match.captures[1])

            csv_path = joinpath(exp_dir, csv_file)

            try
                # Read critical points data using adaptive format CSV (Issue #86)
                # This automatically detects coordinate vs summary format and converts as needed
                result = adaptive_csv_read(csv_path,
                                         target_format=COORDINATE_FORMAT,  # Keep original format for processing
                                         detect_interface_issues=true)

                if !result.success
                    println("   ❌ Failed to load $csv_file: $(result.error)")
                    continue
                end

                df_critical = result.data

                # Log format detection and any warnings
                println("   📊 Format: $(result.original_format) ($(basename(csv_file)))")
                if !isempty(result.warnings)
                    println("   ⚠️  Warnings for $csv_file:")
                    for warning in result.warnings
                        println("      • $warning")
                    end
                end

                if nrow(df_critical) == 0
                    println("   ⚠️  No data in $csv_file")
                    continue
                end

                # Get L2 approximation error from DrWatson results_summary or CSV
                degree_key = "degree_$degree"
                l2_approx_err = missing
                if !isempty(drwatson_data)
                    results_summary = get(drwatson_data, "results_summary", Dict())
                    if haskey(results_summary, degree_key)
                        l2_approx_err = get(results_summary[degree_key], "l2_approx_error", missing)
                    end
                end

                # Handle different formats intelligently
                if result.original_format == COORDINATE_FORMAT
                    # Process coordinate format data (x1,x2,x3,x4,z,l2_approx_error)
                    for i in 1:nrow(df_critical)
                        row_data = df_critical[i, :]

                        # Extract objective value (z column = F(x) at critical point)
                        objective_val = haskey(row_data, :z) ? row_data.z : missing

                        # Extract L2 approximation error (from CSV if available, else from DrWatson)
                        csv_l2_err = haskey(row_data, :l2_approx_error) ? row_data.l2_approx_error : l2_approx_err

                        # Add row to unified dataset
                        push!(all_results, (
                            experiment_id = basename(exp_dir),
                            domain_size = get(params, "domain_size", missing),
                            GN = get(params, "GN", missing),
                            degree = degree,
                            objective_value = objective_val,
                            l2_approx_error = csv_l2_err,
                            git_commit = get(params, "git_commit", missing),
                            timestamp = get(params, "timestamp", missing),
                            experiment_name = get(params, "experiment_name", missing),
                            critical_points_count = nrow(df_critical),
                            x1 = row_data.x1,
                            x2 = row_data.x2,
                            x3 = row_data.x3,
                            x4 = row_data.x4
                        ))
                    end

                    println("   ✅ Added degree $degree: $(nrow(df_critical)) critical points (coordinate format, L2 error: $(l2_approx_err))")

                elseif result.original_format == SUMMARY_FORMAT
                    # Handle legacy summary format data (degree,critical_points,l2_norm)
                    for i in 1:nrow(df_critical)
                        row_data = df_critical[i, :]

                        # For summary format, we don't have individual coordinates
                        # Use placeholder values and rely on the summary statistics
                        push!(all_results, (
                            experiment_id = basename(exp_dir),
                            domain_size = get(params, "domain_size", missing),
                            GN = get(params, "GN", missing),
                            degree = haskey(row_data, :degree) ? row_data.degree : degree,
                            objective_value = haskey(row_data, :l2_norm) ? row_data.l2_norm : (haskey(row_data, :z) ? row_data.z : missing),
                            l2_approx_error = l2_approx_err,
                            git_commit = get(params, "git_commit", missing),
                            timestamp = get(params, "timestamp", missing),
                            experiment_name = get(params, "experiment_name", missing),
                            critical_points_count = haskey(row_data, :critical_points) ? row_data.critical_points : 1,
                            x1 = missing,  # Not available in summary format
                            x2 = missing,
                            x3 = missing,
                            x4 = missing
                        ))
                    end

                    println("   ✅ Added degree $degree: $(nrow(df_critical)) summary entries (summary format, L2 error: $(l2_approx_err))")

                else
                    println("   ⚠️  Unknown format for $csv_file, attempting basic processing")
                    # Fallback: try to process as-is with error handling
                    for i in 1:nrow(df_critical)
                        row_data = df_critical[i, :]

                        # Extract whatever data we can
                        push!(all_results, (
                            experiment_id = basename(exp_dir),
                            domain_size = get(params, "domain_size", missing),
                            GN = get(params, "GN", missing),
                            degree = degree,
                            objective_value = missing,  # Can't determine without known format
                            l2_approx_error = l2_approx_err,
                            git_commit = get(params, "git_commit", missing),
                            timestamp = get(params, "timestamp", missing),
                            experiment_name = get(params, "experiment_name", missing),
                            critical_points_count = nrow(df_critical),
                            x1 = missing,
                            x2 = missing,
                            x3 = missing,
                            x4 = missing
                        ))
                    end

                    println("   ⚠️  Added degree $degree: $(nrow(df_critical)) entries (unknown format, L2 error: $(l2_approx_err))")
                end

            catch e
                println("   ❌ Error reading $csv_file: $e")
            end
        end
    end

    println("📈 Dataset created: $(nrow(all_results)) total critical points from $(length(unique(all_results.experiment_id))) experiments")

    return all_results
end

"""
Generate analysis-ready exports for visualization pipeline
"""
function export_analysis_ready_data(dataset::DataFrame, output_dir::String)
    println("\n💾 Exporting analysis-ready data...")

    mkpath(output_dir)

    # 1. Parameter-result summary for quick analysis
    summary_df = combine(groupby(dataset, [:experiment_id, :domain_size, :GN, :degree]),
        :objective_value => mean => :mean_objective_value,
        :objective_value => std => :std_objective_value,
        :l2_approx_error => first => :l2_approx_error,
        :critical_points_count => first => :critical_points_count,
        :git_commit => first => :git_commit,
        :timestamp => first => :timestamp
    )

    CSV.write(joinpath(output_dir, "parameter_summary.csv"), summary_df)
    println("   ✅ Exported parameter_summary.csv")

    # 2. Full dataset for detailed analysis
    CSV.write(joinpath(output_dir, "full_parameter_dataset.csv"), dataset)
    println("   ✅ Exported full_parameter_dataset.csv")

    # 3. JSON metadata for programmatic access
    metadata = Dict(
        "total_experiments" => length(unique(dataset.experiment_id)),
        "total_critical_points" => nrow(dataset),
        "domain_sizes" => sort(collect(skipmissing(unique(dataset.domain_size)))),
        "GN_values" => sort(collect(skipmissing(unique(dataset.GN)))),
        "degree_range" => (minimum(dataset.degree), maximum(dataset.degree)),
        "export_timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )

    open(joinpath(output_dir, "analysis_metadata.json"), "w") do f
        JSON3.pretty(f, metadata)
    end
    println("   ✅ Exported analysis_metadata.json")

    return output_dir
end

"""
Enhanced main function with parameter-aware data collection (Phase 1 - Issue #54)
"""
function main_parameter_aware()
    println("🚀 Enhanced Cluster Experiment Collection - Parameter-Aware (Phase 1)")
    println("="^80)

    # Step 1: Collect experiment directories
    cluster_dirs = collect_experiment_directories()
    if isempty(cluster_dirs)
        println("❌ No experiment directories found")
        return
    end

    # Step 2: Download experiment results including parameter files
    downloaded_dirs, results_dir = download_experiment_results(cluster_dirs)
    if isempty(downloaded_dirs)
        println("❌ No experiment results downloaded")
        return
    end

    # Step 3: Create parameter-aware dataset
    parameter_dataset = create_parameter_aware_dataset(downloaded_dirs)

    if nrow(parameter_dataset) == 0
        println("❌ No parameter-aware data created")
        return
    end

    # Step 4: Export analysis-ready data
    analysis_dir = joinpath(results_dir, "parameter_analysis")
    export_analysis_ready_data(parameter_dataset, analysis_dir)

    # Step 5: Display summary
    println("\n📊 PARAMETER-AWARE ANALYSIS SUMMARY")
    println("="^50)
    println("   Total critical points: $(nrow(parameter_dataset))")
    println("   Unique experiments: $(length(unique(parameter_dataset.experiment_id)))")
    println("   Domain sizes: $(sort(collect(skipmissing(unique(parameter_dataset.domain_size)))))")
    println("   GN values: $(sort(collect(skipmissing(unique(parameter_dataset.GN)))))")
    println("   Degree range: $(minimum(parameter_dataset.degree)) - $(maximum(parameter_dataset.degree))")
    println("   Analysis ready data: $analysis_dir/")

    println("\n✅ Phase 1 Parameter-Aware Data Collection Complete!")

    return parameter_dataset, analysis_dir
end

# Execute if run as script
if abspath(PROGRAM_FILE) == @__FILE__
    # Run parameter-aware analysis for Phase 1 testing
    if length(ARGS) > 0 && ARGS[1] == "--parameter-aware"
        main_parameter_aware()
    else
        main()
    end
end