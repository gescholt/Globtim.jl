"""
DashboardCore.jl

Core dashboard generation and analysis functionality for the @globtimcore interactive
comparison workflow. This module provides clean separation between basic text-based
dashboards and visual dashboard coordination.

Key Features:
- Text-based dashboard generation with comprehensive analysis
- Visual dashboard coordination through EnvironmentBridge
- Flexible dashboard templates and customization
- Error-resistant dashboard creation with detailed reporting
- Support for experiment comparison and performance analysis

This module is part of Phase 2 of the modular architecture refactoring.
Dependencies: DataFrameInterface.jl, EnvironmentBridge.jl

Author: @globtimcore modular architecture Phase 2
"""

module DashboardCore

using DataFrames
using CSV
using Dates
using Statistics
using Printf
using LinearAlgebra

# Import required modules
include("DataFrameInterface.jl")
using .DataFrameInterface

include("EnvironmentBridge.jl")
using .EnvironmentBridge

# Import specific functions we need from the submodules
import .DataFrameInterface: quick_validate, quick_validate_any_schema, get_critical_values, detect_column_convention
import .EnvironmentBridge: safe_visualization_call, EnvironmentBridgeError

export DashboardConfig, DashboardResult
export create_text_dashboard, create_visual_dashboard, create_combined_dashboard
export generate_experiment_summary, generate_performance_analysis
export format_dashboard_output, save_dashboard_results
export safe_visualization_call

# Dashboard configuration structure
struct DashboardConfig
    output_directory::String
    include_visual::Bool
    include_text::Bool
    experiment_analysis::Bool
    performance_metrics::Bool
    custom_templates::Dict{String, Any}

    function DashboardConfig(;
        output_directory::String = "dashboard_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS"))",
        include_visual::Bool = true,
        include_text::Bool = true,
        experiment_analysis::Bool = true,
        performance_metrics::Bool = true,
        custom_templates::Dict{String, Any} = Dict{String, Any}()
    )
        new(output_directory, include_visual, include_text, experiment_analysis, performance_metrics, custom_templates)
    end
end

# Dashboard result structure
struct DashboardResult
    success::Bool
    dashboard_directory::String
    text_files::Vector{String}
    visual_files::Vector{String}
    summary_data::Dict{String, Any}
    execution_time::Float64
    errors::Vector{String}
    warnings::Vector{String}

    function DashboardResult(success, dashboard_directory, text_files, visual_files, summary_data, execution_time, errors, warnings)
        new(success, dashboard_directory, text_files, visual_files, summary_data, execution_time, errors, warnings)
    end
end

"""
Create comprehensive text-based dashboard from experiment data.
Returns detailed analysis files and summary statistics.
"""
function create_text_dashboard(
    data::DataFrame,
    config::DashboardConfig;
    source_file::String = "unknown"
)::DashboardResult

    start_time = time()
    errors = String[]
    warnings = String[]
    text_files = String[]
    summary_data = Dict{String, Any}()

    try
        # Validate input data
        if !quick_validate_any_schema(data)
            error("Invalid DataFrame schema - cannot create dashboard")
        end

        # Create output directory
        mkpath(config.output_directory)
        println("📂 Created dashboard directory: $(config.output_directory)")

        # Generate main analysis file
        main_analysis_file = joinpath(config.output_directory, "analysis_dashboard.txt")
        push!(text_files, main_analysis_file)

        # Create comprehensive analysis
        analysis_data = create_comprehensive_analysis(data, source_file)
        summary_data = merge(summary_data, analysis_data)

        # Write main analysis file
        write_main_analysis_file(main_analysis_file, analysis_data)
        println("📊 Created main analysis: $(basename(main_analysis_file))")

        # Generate experiment summary if requested
        if config.experiment_analysis && "experiment_id" in names(data)
            experiment_file = joinpath(config.output_directory, "experiment_summary.txt")
            push!(text_files, experiment_file)

            experiment_analysis = generate_experiment_summary(data)
            summary_data["experiment_analysis"] = experiment_analysis

            write_experiment_summary_file(experiment_file, experiment_analysis)
            println("🧪 Created experiment summary: $(basename(experiment_file))")
        end

        # Generate performance metrics if requested
        if config.performance_metrics
            performance_file = joinpath(config.output_directory, "performance_metrics.txt")
            push!(text_files, performance_file)

            performance_analysis = generate_performance_analysis(data)
            summary_data["performance_analysis"] = performance_analysis

            write_performance_analysis_file(performance_file, performance_analysis)
            println("📈 Created performance metrics: $(basename(performance_file))")
        end

        # Copy source data file to dashboard directory
        if source_file != "unknown" && isfile(source_file)
            data_copy = joinpath(config.output_directory, "source_data.csv")
            cp(source_file, data_copy)
            push!(text_files, data_copy)
            println("📄 Copied source data: $(basename(data_copy))")
        end

        # Create dashboard summary file
        summary_file = joinpath(config.output_directory, "dashboard_summary.json")
        write_dashboard_summary(summary_file, summary_data)
        push!(text_files, summary_file)

        execution_time = time() - start_time

        return DashboardResult(
            true,
            config.output_directory,
            text_files,
            String[],
            summary_data,
            execution_time,
            errors,
            warnings
        )

    catch e
        execution_time = time() - start_time
        error_msg = "Text dashboard creation failed: $e"
        push!(errors, error_msg)
        println("❌ $error_msg")

        return DashboardResult(
            false,
            config.output_directory,
            text_files,
            String[],
            summary_data,
            execution_time,
            errors,
            warnings
        )
    end
end

"""
Create visual dashboard using EnvironmentBridge for safe cross-environment calls.
Coordinates with @globtimplots repository for visualization generation.
"""
function create_visual_dashboard(
    data::DataFrame,
    config::DashboardConfig,
    globtimplots_path::String;
    source_file::String = "unknown"
)::DashboardResult

    start_time = time()
    errors = String[]
    warnings = String[]
    visual_files = String[]
    summary_data = Dict{String, Any}()

    try
        # Validate input data for cross-environment use
        if !quick_validate_any_schema(data)
            error("Invalid DataFrame schema - cannot create visual dashboard")
        end

        println("🎯 Creating visual dashboard using EnvironmentBridge...")

        # Use EnvironmentBridge for safe cross-environment visualization
        result = safe_visualization_call(
            data,
            globtimplots_path,
            config.output_directory,
            parameters=Dict{String, Any}("dashboard_mode" => true),
            timeout=300
        )

        if result.success
            visual_files = result.output_files
            summary_data["visual_generation"] = Dict(
                "execution_time" => result.execution_time,
                "files_created" => length(visual_files),
                "output_directory" => config.output_directory,
                "source_file" => source_file
            )

            println("✅ Visual dashboard created successfully")
            println("   📁 Output directory: $(config.output_directory)")
            println("   🎨 Files created: $(length(visual_files))")

            for file in visual_files
                println("      • $(basename(file))")
            end

        else
            error("Visual dashboard generation failed: exit code $(result.exit_code)")
        end

        execution_time = time() - start_time

        return DashboardResult(
            true,
            config.output_directory,
            String[],
            visual_files,
            summary_data,
            execution_time,
            errors,
            warnings
        )

    catch e
        execution_time = time() - start_time
        error_msg = "Visual dashboard creation failed: $e"
        push!(errors, error_msg)
        println("❌ $error_msg")

        # For EnvironmentBridge errors, fail fast (no fallback per user requirements)
        if isa(e, EnvironmentBridgeError)
            rethrow(e)
        end

        return DashboardResult(
            false,
            config.output_directory,
            String[],
            visual_files,
            summary_data,
            execution_time,
            errors,
            warnings
        )
    end
end

"""
Create combined dashboard with both text and visual components.
Provides comprehensive analysis with both data insights and visualizations.
"""
function create_combined_dashboard(
    data::DataFrame,
    config::DashboardConfig,
    globtimplots_path::String;
    source_file::String = "unknown"
)::DashboardResult

    start_time = time()
    all_errors = String[]
    all_warnings = String[]
    all_text_files = String[]
    all_visual_files = String[]
    combined_summary = Dict{String, Any}()

    try
        println("🚀 Creating combined dashboard (text + visual)")

        # Create text dashboard
        if config.include_text
            println("📊 Generating text analysis...")
            text_result = create_text_dashboard(data, config; source_file=source_file)

            append!(all_errors, text_result.errors)
            append!(all_warnings, text_result.warnings)
            append!(all_text_files, text_result.text_files)
            combined_summary["text_dashboard"] = text_result.summary_data

            if text_result.success
                println("✅ Text dashboard completed")
            else
                push!(all_warnings, "Text dashboard creation had issues")
            end
        end

        # Create visual dashboard
        if config.include_visual
            println("🎨 Generating visual components...")
            visual_result = create_visual_dashboard(data, config, globtimplots_path; source_file=source_file)

            append!(all_errors, visual_result.errors)
            append!(all_warnings, visual_result.warnings)
            append!(all_visual_files, visual_result.visual_files)
            combined_summary["visual_dashboard"] = visual_result.summary_data

            if visual_result.success
                println("✅ Visual dashboard completed")
            else
                push!(all_warnings, "Visual dashboard creation had issues")
            end
        end

        # Create combined summary
        overview_file = joinpath(config.output_directory, "combined_dashboard_overview.txt")
        create_combined_overview(overview_file, combined_summary, all_text_files, all_visual_files)
        push!(all_text_files, overview_file)

        execution_time = time() - start_time
        overall_success = isempty(all_errors)

        println("🎉 Combined dashboard completed!")
        println("   ⏱️  Total execution time: $(round(execution_time, digits=2))s")
        println("   📁 Dashboard directory: $(config.output_directory)")
        println("   📊 Text files: $(length(all_text_files))")
        println("   🎨 Visual files: $(length(all_visual_files))")

        return DashboardResult(
            overall_success,
            config.output_directory,
            all_text_files,
            all_visual_files,
            combined_summary,
            execution_time,
            all_errors,
            all_warnings
        )

    catch e
        execution_time = time() - start_time
        error_msg = "Combined dashboard creation failed: $e"
        push!(all_errors, error_msg)
        println("❌ $error_msg")

        return DashboardResult(
            false,
            config.output_directory,
            all_text_files,
            all_visual_files,
            combined_summary,
            execution_time,
            all_errors,
            all_warnings
        )
    end
end

"""
Generate comprehensive analysis data structure from DataFrame.
"""
function create_comprehensive_analysis(data::DataFrame, source_file::String)::Dict{String, Any}
    analysis = Dict{String, Any}()

    # Basic data information
    analysis["metadata"] = Dict(
        "total_rows" => nrow(data),
        "total_columns" => ncol(data),
        "column_names" => names(data),
        "source_file" => source_file,
        "generation_time" => Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
    )

    # Column convention analysis
    convention = detect_column_convention(data)
    analysis["column_convention"] = Dict(
        "detected" => convention,
        "value_column" => convention in ["z", "val"] ? convention : "unknown"
    )

    # Critical values analysis
    if convention in ["z", "val"]
        try
            values = get_critical_values(data)
            analysis["critical_values"] = Dict(
                "count" => length(values),
                "min" => minimum(values),
                "max" => maximum(values),
                "mean" => mean(values),
                "median" => median(values),
                "std" => std(values)
            )
        catch e
            analysis["critical_values"] = Dict("error" => "Failed to analyze: $e")
        end
    end

    # Type distribution analysis
    if "type" in names(data)
        type_counts = Dict{String, Int}()
        for t in data.type
            if !ismissing(t)
                type_counts[string(t)] = get(type_counts, string(t), 0) + 1
            end
        end
        analysis["type_distribution"] = type_counts
    end

    # Experiment analysis if experiment_id present
    if "experiment_id" in names(data)
        valid_data = filter(row -> !ismissing(row.experiment_id), data)
        experiments = unique(valid_data.experiment_id)
        analysis["experiments"] = Dict(
            "total_experiments" => length(experiments),
            "experiment_ids" => collect(experiments),
            "avg_points_per_experiment" => nrow(valid_data) / max(1, length(experiments))
        )
    end

    return analysis
end

"""
Generate detailed experiment summary analysis.
"""
function generate_experiment_summary(data::DataFrame)::Dict{String, Any}
    summary = Dict{String, Any}()

    if !("experiment_id" in names(data))
        return Dict("error" => "No experiment_id column found")
    end

    # Filter out missing experiment_ids
    valid_data = filter(row -> !ismissing(row.experiment_id), data)
    experiments = unique(valid_data.experiment_id)

    experiment_details = Dict{String, Any}()

    for exp_id in experiments
        exp_data = filter(row -> row.experiment_id == exp_id, valid_data)

        exp_summary = Dict{String, Any}(
            "data_points" => nrow(exp_data),
            "experiment_id" => exp_id
        )

        # Add degree information if available
        if "degree" in names(exp_data) && nrow(exp_data) > 0
            exp_summary["degree_range"] = [minimum(exp_data.degree), maximum(exp_data.degree)]
        end

        # Add performance metrics if z column available
        if "z" in names(exp_data) && nrow(exp_data) > 0
            exp_summary["performance"] = Dict(
                "best_l2" => minimum(exp_data.z),
                "worst_l2" => maximum(exp_data.z),
                "mean_l2" => mean(exp_data.z)
            )
        end

        # Add domain size if available
        if "domain_size" in names(exp_data) && nrow(exp_data) > 0
            domain_val = exp_data.domain_size[1]
            if !ismissing(domain_val)
                exp_summary["domain_size"] = domain_val
            end
        end

        experiment_details[string(exp_id)] = exp_summary
    end

    summary["experiments"] = experiment_details
    summary["total_experiments"] = length(experiments)

    return summary
end

"""
Generate performance analysis and benchmarking data.
"""
function generate_performance_analysis(data::DataFrame)::Dict{String, Any}
    analysis = Dict{String, Any}()

    if !("z" in names(data) || "val" in names(data))
        return Dict("error" => "No performance metric column (z or val) found")
    end

    try
        values = get_critical_values(data)

        # Basic performance statistics
        analysis["overall_performance"] = Dict(
            "best_value" => minimum(values),
            "worst_value" => maximum(values),
            "performance_range" => maximum(values) - minimum(values),
            "mean_performance" => mean(values),
            "median_performance" => median(values),
            "std_deviation" => std(values)
        )

        # Performance distribution analysis
        sorted_values = sort(values)
        n = length(values)

        analysis["distribution_analysis"] = Dict(
            "top_10_percent_threshold" => sorted_values[max(1, div(n, 10))],
            "top_25_percent_threshold" => sorted_values[max(1, div(n, 4))],
            "bottom_25_percent_threshold" => sorted_values[max(1, 3 * div(n, 4))],
            "quartiles" => [
                sorted_values[max(1, div(n, 4))],
                sorted_values[max(1, div(n, 2))],
                sorted_values[max(1, 3 * div(n, 4))]
            ]
        )

        # Performance by experiment if available
        if "experiment_id" in names(data)
            valid_data = filter(row -> !ismissing(row.experiment_id), data)
            exp_performance = Dict{String, Float64}()

            for exp_id in unique(valid_data.experiment_id)
                exp_data = filter(row -> row.experiment_id == exp_id, valid_data)
                if nrow(exp_data) > 0
                    exp_values = get_critical_values(exp_data)
                    exp_performance[string(exp_id)] = minimum(exp_values)
                end
            end

            analysis["experiment_rankings"] = sort(collect(exp_performance), by=x->x[2])
        end

    catch e
        analysis["error"] = "Performance analysis failed: $e"
    end

    return analysis
end

"""
Write main analysis file with comprehensive formatting.
"""
function write_main_analysis_file(filepath::String, analysis::Dict{String, Any})
    open(filepath, "w") do f
        println(f, "EXPERIMENT ANALYSIS DASHBOARD")
        println(f, "=" ^ 60)
        println(f, "Generated: $(analysis["metadata"]["generation_time"])")
        println(f, "Source: $(analysis["metadata"]["source_file"])")
        println(f, "Data Points: $(analysis["metadata"]["total_rows"])")
        println(f, "Columns: $(analysis["metadata"]["total_columns"])")
        println(f, "")

        # Column information
        println(f, "DATA SCHEMA")
        println(f, "-" ^ 30)
        println(f, "Columns: $(join(analysis["metadata"]["column_names"], ", "))")
        println(f, "Value Convention: $(analysis["column_convention"]["detected"])")
        println(f, "")

        # Critical values analysis
        if haskey(analysis, "critical_values") && !haskey(analysis["critical_values"], "error")
            cv = analysis["critical_values"]
            println(f, "CRITICAL VALUES ANALYSIS")
            println(f, "-" ^ 30)
            println(f, "Count: $(cv["count"])")
            println(f, @sprintf "Best (minimum): %.8f" cv["min"])
            println(f, @sprintf "Worst (maximum): %.8f" cv["max"])
            println(f, @sprintf "Mean: %.6f" cv["mean"])
            println(f, @sprintf "Median: %.6f" cv["median"])
            println(f, @sprintf "Std Deviation: %.6f" cv["std"])
            println(f, "")
        end

        # Type distribution
        if haskey(analysis, "type_distribution")
            println(f, "TYPE DISTRIBUTION")
            println(f, "-" ^ 30)
            for (type_name, count) in analysis["type_distribution"]
                println(f, "$type_name: $count")
            end
            println(f, "")
        end

        # Experiment overview
        if haskey(analysis, "experiments")
            exp = analysis["experiments"]
            println(f, "EXPERIMENT OVERVIEW")
            println(f, "-" ^ 30)
            println(f, "Total Experiments: $(exp["total_experiments"])")
            println(f, @sprintf "Average Points/Experiment: %.1f" exp["avg_points_per_experiment"])
            println(f, "Experiment IDs: $(join(exp["experiment_ids"], ", "))")
            println(f, "")
        end
    end
end

"""
Write experiment summary file with detailed per-experiment analysis.
"""
function write_experiment_summary_file(filepath::String, experiment_analysis::Dict{String, Any})
    open(filepath, "w") do f
        println(f, "DETAILED EXPERIMENT SUMMARY")
        println(f, "=" ^ 50)
        println(f, "Total Experiments: $(experiment_analysis["total_experiments"])")
        println(f, "")

        if haskey(experiment_analysis, "experiments")
            for (exp_id, details) in experiment_analysis["experiments"]
                println(f, "EXPERIMENT: $exp_id")
                println(f, "-" ^ 40)

                println(f, "Data Points: $(details["data_points"])")

                if haskey(details, "degree_range")
                    degrees = details["degree_range"]
                    println(f, "Degree Range: $(degrees[1]) - $(degrees[2])")
                end

                if haskey(details, "performance")
                    perf = details["performance"]
                    println(f, @sprintf "Best L2: %.8f" perf["best_l2"])
                    println(f, @sprintf "Mean L2: %.6f" perf["mean_l2"])
                    println(f, @sprintf "Worst L2: %.6f" perf["worst_l2"])
                end

                if haskey(details, "domain_size")
                    println(f, "Domain Size: $(details["domain_size"])")
                end

                println(f, "")
            end
        end
    end
end

"""
Write performance analysis file with benchmarking data.
"""
function write_performance_analysis_file(filepath::String, performance_analysis::Dict{String, Any})
    open(filepath, "w") do f
        println(f, "PERFORMANCE ANALYSIS REPORT")
        println(f, "=" ^ 50)
        println(f, "")

        if haskey(performance_analysis, "overall_performance")
            perf = performance_analysis["overall_performance"]
            println(f, "OVERALL PERFORMANCE")
            println(f, "-" ^ 30)
            println(f, @sprintf "Best Value: %.8f" perf["best_value"])
            println(f, @sprintf "Worst Value: %.6f" perf["worst_value"])
            println(f, @sprintf "Performance Range: %.6f" perf["performance_range"])
            println(f, @sprintf "Mean: %.6f" perf["mean_performance"])
            println(f, @sprintf "Median: %.6f" perf["median_performance"])
            println(f, @sprintf "Std Deviation: %.6f" perf["std_deviation"])
            println(f, "")
        end

        if haskey(performance_analysis, "distribution_analysis")
            dist = performance_analysis["distribution_analysis"]
            println(f, "PERFORMANCE DISTRIBUTION")
            println(f, "-" ^ 30)
            println(f, @sprintf "Top 10%% Threshold: %.8f" dist["top_10_percent_threshold"])
            println(f, @sprintf "Top 25%% Threshold: %.8f" dist["top_25_percent_threshold"])
            println(f, @sprintf "Bottom 25%% Threshold: %.6f" dist["bottom_25_percent_threshold"])

            quartiles = dist["quartiles"]
            println(f, "Quartiles:")
            println(f, @sprintf "  Q1: %.8f" quartiles[1])
            println(f, @sprintf "  Q2 (Median): %.8f" quartiles[2])
            println(f, @sprintf "  Q3: %.8f" quartiles[3])
            println(f, "")
        end

        if haskey(performance_analysis, "experiment_rankings")
            rankings = performance_analysis["experiment_rankings"]
            println(f, "EXPERIMENT RANKINGS (by best performance)")
            println(f, "-" ^ 50)
            for (i, (exp_id, best_value)) in enumerate(rankings)
                println(f, @sprintf "%2d. %s: %.8f" i exp_id best_value)
            end
            println(f, "")
        end
    end
end

"""
Write dashboard summary as JSON for programmatic access.
"""
function write_dashboard_summary(filepath::String, summary_data::Dict{String, Any})
    # Create a simplified version for JSON serialization
    json_summary = Dict{String, Any}()

    for (key, value) in summary_data
        try
            # Only include serializable data
            if isa(value, Dict) || isa(value, Array) || isa(value, String) || isa(value, Number) || isa(value, Bool)
                json_summary[key] = value
            else
                json_summary[key] = string(value)
            end
        catch
            json_summary[key] = "serialization_error"
        end
    end

    open(filepath, "w") do f
        # Write simplified JSON-like format (Julia doesn't have built-in JSON)
        println(f, "{")
        for (i, (key, value)) in enumerate(json_summary)
            comma = i < length(json_summary) ? "," : ""
            println(f, "  \"$key\": $(repr(value))$comma")
        end
        println(f, "}")
    end
end

"""
Create combined overview file linking text and visual components.
"""
function create_combined_overview(filepath::String, summary_data::Dict{String, Any}, text_files::Vector{String}, visual_files::Vector{String})
    open(filepath, "w") do f
        println(f, "COMBINED DASHBOARD OVERVIEW")
        println(f, "=" ^ 60)
        println(f, "Generated: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))")
        println(f, "")

        println(f, "TEXT ANALYSIS FILES")
        println(f, "-" ^ 30)
        for file in text_files
            println(f, "• $(basename(file))")
        end
        println(f, "")

        println(f, "VISUAL FILES")
        println(f, "-" ^ 30)
        for file in visual_files
            println(f, "• $(basename(file))")
        end
        println(f, "")

        if haskey(summary_data, "text_dashboard") && haskey(summary_data["text_dashboard"], "critical_values")
            cv = summary_data["text_dashboard"]["critical_values"]
            if !haskey(cv, "error")
                println(f, "KEY PERFORMANCE METRICS")
                println(f, "-" ^ 30)
                println(f, @sprintf "Best Performance: %.8f" cv["min"])
                println(f, @sprintf "Mean Performance: %.6f" cv["mean"])
                println(f, @sprintf "Total Data Points: %d" cv["count"])
                println(f, "")
            end
        end

        println(f, "DASHBOARD COMPONENTS")
        println(f, "-" ^ 30)
        println(f, "✅ Text Analysis: $(length(text_files)) files")
        println(f, "✅ Visual Components: $(length(visual_files)) files")
        println(f, "")
        println(f, "Open any of the above files to explore detailed analysis results.")
    end
end

end # module DashboardCore