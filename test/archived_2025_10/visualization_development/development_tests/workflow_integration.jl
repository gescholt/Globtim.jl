#!/usr/bin/env julia
"""
Workflow Integration Script for @globtimcore and @globtimplots

This script demonstrates integration between the mathematical core analysis
from @globtimcore with visualization tools from @globtimplots.

Usage: julia --project=. workflow_integration.jl
"""

using Pkg
Pkg.activate(".")

using CSV, DataFrames, Statistics, Dates
using Printf
import REPL
using REPL.TerminalMenus

# Import defensive CSV loading (Issue #79)
include("src/DefensiveCSV.jl")
using .DefensiveCSV

# Import post-processing capabilities
include("src/PostProcessing.jl")
using .PostProcessing

# Import file selection interface
include("src/FileSelection.jl")
using .FileSelection

"""
Create a simple analysis and visualization workflow
"""
function integrated_analysis_workflow()
    println("🚀 Integrated Analysis Workflow: @globtimcore ↔ @globtimplots")
    println("="^70)

    # Step 1: Find the most recent parameter analysis
    parameter_dirs = String[]
    for (root, dirs, files) in walkdir(".")
        if endswith(root, "parameter_analysis") &&
           any(f -> f == "parameter_summary.csv", files)
            push!(parameter_dirs, root)
        end
    end

    if isempty(parameter_dirs)
        println("❌ No parameter analysis directories found")
        println(
            "   Run: julia --project=. collect_cluster_experiments.jl --parameter-aware"
        )
        return
    end

    # Use most recent analysis
    latest_dir = sort(parameter_dirs)[end]
    println("📂 Using parameter analysis: $latest_dir")

    # Step 2: Load and analyze parameter data using defensive loading (Issue #79)
    param_file = joinpath(latest_dir, "parameter_summary.csv")
    full_data_file = joinpath(latest_dir, "full_parameter_dataset.csv")

    # Defensive loading of parameter summary
    param_result = defensive_csv_read(param_file,
                                    required_columns=["experiment_id", "degree"],
                                    detect_interface_issues=true)

    if !param_result.success
        println("❌ Failed to load parameter data: $(param_result.error)")
        return
    end

    param_df = param_result.data
    println("📊 Loaded $(nrow(param_df)) parameter combinations")

    # Log any warnings from parameter loading
    if !isempty(param_result.warnings)
        println("⚠️  Parameter data warnings:")
        for warning in param_result.warnings
            println("    • $warning")
        end
    end

    # Defensive loading of full dataset if available
    if isfile(full_data_file)
        full_result = defensive_csv_read(full_data_file,
                                       detect_interface_issues=true)

        if full_result.success
            full_df = full_result.data
            println("📈 Loaded $(nrow(full_df)) individual critical points")

            if !isempty(full_result.warnings)
                println("⚠️  Full dataset warnings:")
                for warning in full_result.warnings
                    println("    • $warning")
                end
            end
        else
            println("⚠️  Failed to load full dataset: $(full_result.error)")
            full_df = nothing
        end
    else
        println("⚠️  Full dataset not available")
        full_df = nothing
    end

    # Step 3: Generate comprehensive analysis report
    println("\n" * "="^50)
    println("📋 INTEGRATED ANALYSIS SUMMARY")
    println("="^50)

    # Experiment overview
    experiments = unique(param_df.experiment_id)
    degrees = sort(unique(param_df.degree))

    println("🔬 EXPERIMENTAL OVERVIEW:")
    println("   Experiments: $(length(experiments))")
    println("   Degrees analyzed: $(degrees)")
    println("   Total parameter combinations: $(nrow(param_df))")

    # Performance analysis
    println("\n📈 PERFORMANCE METRICS:")
    for exp in experiments
        exp_data = filter(row -> row.experiment_id == exp, param_df)
        mean_performance = round(mean(exp_data.mean_l2_norm), digits = 4)
        best_performance = round(minimum(exp_data.mean_l2_norm), digits = 6)
        println("   $exp: mean L2=$(mean_performance), best L2=$(best_performance)")
    end

    # Degree progression analysis
    println("\n📊 DEGREE PROGRESSION:")
    degree_stats = combine(groupby(param_df, :degree)) do sdf
        DataFrame(
            experiments = length(unique(sdf.experiment_id)),
            mean_l2 = round(mean(sdf.mean_l2_norm), digits = 6),
            std_l2 = round(std(sdf.mean_l2_norm), digits = 6),
            best_l2 = round(minimum(sdf.mean_l2_norm), digits = 8)
        )
    end
    sort!(degree_stats, :degree)

    for row in eachrow(degree_stats)
        println(
            "   Degree $(row.degree): $(row.experiments) exp, mean=$(row.mean_l2), std=$(row.std_l2), best=$(row.best_l2)"
        )
    end

    # Step 4: Prepare data for plotting visualization
    println("\n🎨 VISUALIZATION PREPARATION:")

    # Create plotting-ready data structures
    viz_data = Dict(
        "experiment_comparison" => combine(groupby(param_df, :experiment_id)) do sdf
            DataFrame(
                total_degrees = nrow(sdf),
                mean_performance = mean(sdf.mean_l2_norm),
                best_performance = minimum(sdf.mean_l2_norm),
                performance_range = maximum(sdf.mean_l2_norm) - minimum(sdf.mean_l2_norm)
            )
        end,
        "degree_progression" => degree_stats,
        "parameter_summary" => param_df
    )

    # Export visualization-ready data
    viz_dir = joinpath(latest_dir, "visualization_data")
    mkpath(viz_dir)

    for (name, data) in viz_data
        output_file = joinpath(viz_dir, "$(name).csv")
        CSV.write(output_file, data)
        println("   ✅ Exported: $(name).csv")
    end

    # Step 5: Generate plotting instructions
    println("\n🖼️  PLOTTING INTEGRATION INSTRUCTIONS:")
    println("   1. Activate @globtimplots environment:")
    println("      cd ../globtimplots && julia --project=.")
    println()
    println("   2. Load visualization data:")
    println("      using CSV, DataFrames")
    println(
        "      exp_data = CSV.read(\"$(viz_dir)/experiment_comparison.csv\", DataFrame)"
    )
    println("      deg_data = CSV.read(\"$(viz_dir)/degree_progression.csv\", DataFrame)")
    println()
    println("   3. Available plotting functions from @globtimplots:")
    println("      - plot_convergence_analysis()")
    println("      - plot_discrete_l2()")
    println("      - plot_distance_statistics()")
    println()
    println("   4. Data locations:")
    println("      - Visualization data: $viz_dir/")
    println("      - Source parameter data: $latest_dir/")

    # Step 6: Integration health check
    println("\n🔍 INTEGRATION HEALTH CHECK:")

    # Check for @globtimplots availability
    globtimplots_path = joinpath(dirname(pwd()), "globtimplots")
    if isdir(globtimplots_path)
        println("   ✅ @globtimplots available at: $globtimplots_path")

        # Check for key plotting modules
        plotting_files =
            ["src/GlobtimPlots.jl", "src/graphs_makie.jl", "src/graphs_cairo.jl"]
        for file in plotting_files
            full_path = joinpath(globtimplots_path, file)
            if isfile(full_path)
                println("   ✅ $file found")
            else
                println("   ⚠️  $file missing")
            end
        end
    else
        println("   ⚠️  @globtimplots not found at expected location")
        println("      Expected: $globtimplots_path")
    end

    println("\n✅ Integrated workflow complete!")
    println("📊 Analysis data processed: $(nrow(param_df)) parameter combinations")
    println("🎨 Visualization data prepared in: $viz_dir/")

    return param_df, viz_data, viz_dir
end

"""
Quick plotting integration test using basic Julia plotting
"""
function create_basic_plots(param_df::DataFrame, output_dir::String)
    println("\n📈 Creating basic analysis plots...")

    try
        # Try to use simple plotting if available
        println("   Creating degree progression analysis...")

        # Degree vs performance analysis (text-based for now)
        degree_analysis = combine(groupby(param_df, :degree)) do sdf
            DataFrame(
                degree = first(sdf.degree),
                mean_l2 = mean(sdf.mean_l2_norm),
                experiments = length(unique(sdf.experiment_id))
            )
        end
        sort!(degree_analysis, :degree)

        # Create simple text visualization
        plot_file = joinpath(output_dir, "degree_analysis.txt")
        open(plot_file, "w") do f
            println(f, "Degree Progression Analysis")
            println(f, "="^40)
            println(f, "Degree | Mean L2 Norm | Experiments")
            println(f, "-------|-------------|------------")
            for row in eachrow(degree_analysis)
                @printf(
                    f,
                    "%6d | %11.6f | %11d\n",
                    row.degree,
                    row.mean_l2,
                    row.experiments
                )
            end
        end

        println("   ✅ Created: degree_analysis.txt")

        # Export summary statistics
        stats_file = joinpath(output_dir, "summary_statistics.txt")
        open(stats_file, "w") do f
            println(f, "Experiment Summary Statistics")
            println(f, "="^40)
            println(f, "Total experiments: $(length(unique(param_df.experiment_id)))")
            println(f, "Total parameter combinations: $(nrow(param_df))")
            println(
                f,
                "Degree range: $(minimum(param_df.degree)) - $(maximum(param_df.degree))"
            )
            println(
                f,
                "L2 norm range: $(round(minimum(param_df.mean_l2_norm), digits=8)) - $(round(maximum(param_df.mean_l2_norm), digits=6))"
            )
            println(f, "Mean L2 norm: $(round(mean(param_df.mean_l2_norm), digits=6))")
        end

        println("   ✅ Created: summary_statistics.txt")

    catch e
        println("   ⚠️  Basic plotting failed: $e")
    end
end

# Main execution
function main()
    println("Starting integrated workflow...")

    param_df, viz_data, viz_dir = integrated_analysis_workflow()

    if param_df !== nothing
        create_basic_plots(param_df, viz_dir)

        println("\n🎯 WORKFLOW INTEGRATION COMPLETE!")
        println("   Analysis processed: ✅")
        println("   Visualization data ready: ✅")
        println("   @globtimplots integration prepared: ✅")
        println("   Ready for advanced plotting with @globtimplots")
    end

    return param_df, viz_data
end

"""
Interactive file comparison workflow with terminal-based selection.
Allows user to select which output files to compare.
"""
function interactive_comparison_workflow()
    println("🎯 Interactive File Comparison Workflow")
    println("="^50)

    # Step 1: Discover available output files
    println("🔍 Searching for comparison data...")

    # Look in common output directories
    search_paths = [
        "simple_comparison_output",
        ".",
        "parameter_analysis_$(Dates.format(Dates.today(), "yyyymmdd"))"  # Today's analysis
    ]

    # Find directories with analysis results
    available_dirs = String[]
    for path in search_paths
        if isdir(path)
            csv_files = FileSelection.discover_csv_files(path)
            if !isempty(csv_files)
                push!(available_dirs, path)
                println("   📁 Found $(length(csv_files)) files in: $path")
            end
        end
    end

    # Also search for parameter analysis directories
    for (root, dirs, files) in walkdir(".")
        for dir in dirs
            if contains(dir, "parameter_analysis") &&
               any(f -> endswith(f, ".csv"), readdir(joinpath(root, dir)))
                full_path = joinpath(root, dir)
                if !(full_path in available_dirs)
                    push!(available_dirs, full_path)
                    csv_count = length(FileSelection.discover_csv_files(full_path))
                    println("   📁 Found $csv_count files in: $full_path")
                end
            end
        end
    end

    if isempty(available_dirs)
        println("❌ No CSV output files found")
        println("   Run experiments first or check output directory paths")
        return nothing
    end

    # Step 2: Let user select directory if multiple available
    selected_dir = if length(available_dirs) == 1
        available_dirs[1]
    else
        println("\n📂 Multiple output directories found:")

        dir_options = [relpath(d, pwd()) for d in available_dirs]
        menu = RadioMenu(dir_options, pagesize = 10)
        choice = request("Select output directory:", menu)

        if choice == -1
            println("Selection cancelled.")
            return nothing
        end

        available_dirs[choice]
    end

    println("✅ Using directory: $(relpath(selected_dir, pwd()))")

    # Step 3: Interactive file selection
    println("\n📊 Select files to compare:")
    selected_files = FileSelection.select_multiple_files(selected_dir)

    if isempty(selected_files)
        println("No files selected.")
        return nothing
    end

    # Step 4: Load and combine selected data
    println("\n📈 Loading selected data...")
    combined_data = FileSelection.load_selected_data(selected_files)

    if nrow(combined_data) == 0
        println("❌ No data loaded from selected files")
        return nothing
    end

    # Step 5: Basic analysis of combined data
    println("\n📊 COMPARISON ANALYSIS:")
    println("   Total data points: $(nrow(combined_data))")
    println("   Data sources: $(length(unique(combined_data.source_file)))")

    # Detect data types and provide relevant analysis
    cols = names(combined_data)

    if "experiment_id" in cols && "degree" in cols && "z" in cols
        # This looks like detailed comparison data
        println("   Experiment type: Detailed comparison data")

        if "experiment_id" in cols
            exp_count = length(unique(combined_data.experiment_id))
            println("   Unique experiments: $exp_count")
        end

        if "degree" in cols
            degrees = sort(unique(combined_data.degree))
            println("   Degree range: $(minimum(degrees)) - $(maximum(degrees))")
        end

        if "z" in cols  # L2 norm values
            best_l2 = minimum(combined_data.z)
            worst_l2 = maximum(combined_data.z)
            mean_l2 = mean(combined_data.z)
            println(
                "   L2 performance: best=$(round(best_l2, digits=6)), mean=$(round(mean_l2, digits=6)), worst=$(round(worst_l2, digits=6))"
            )
        end

        if "domain_size" in cols
            domains = sort(unique(skipmissing(combined_data.domain_size)))
            println("   Domain sizes: $domains")
        end

    elseif "mean_l2" in cols && "degree" in cols
        # This looks like summary data
        println("   Experiment type: Summary comparison data")
        println("   Parameter combinations: $(nrow(combined_data))")

        if "mean_l2" in cols
            best_mean = minimum(combined_data.mean_l2)
            println("   Best mean L2: $(round(best_mean, digits=6))")
        end
    end

    # Step 6: Save combined analysis
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    output_file = "interactive_comparison_$(timestamp).csv"

    CSV.write(output_file, combined_data)
    println("\n💾 Combined data saved to: $output_file")

    # Step 7: Ask user about automatic plot generation (Issue #62 enhancement)
    println("\n🎯 NEXT STEPS:")
    println("   📊 Data ready for analysis in: $output_file")

    # Check if @globtimplots is available
    globtimplots_path = find_globtimplots_path()

    if globtimplots_path !== nothing
        println("\n🎨 AUTOMATIC VISUALIZATION OPTION:")
        print("   Generate plots automatically using @globtimplots? (y/n): ")
        response = strip(readline())

        if lowercase(response) in ["y", "yes", "1", "true"]
            try
                println("\n🚀 Generating automatic plots...")
                create_automatic_plots(combined_data, output_file, globtimplots_path)
                println("✅ Automatic visualization complete!")
            catch e
                println("❌ Automatic plotting failed: $e")
                println("   Falling back to manual instructions...")
                show_manual_plotting_instructions(output_file)
            end
        else
            println("   Skipping automatic visualization.")
            show_manual_plotting_instructions(output_file)
        end
    else
        println("   ⚠️  @globtimplots not found - showing manual instructions.")
        show_manual_plotting_instructions(output_file)
    end

    return combined_data, output_file
end

"""
Find @globtimplots installation path using multiple search strategies
"""
function find_globtimplots_path()
    # Search paths in order of preference
    search_paths = [
        abspath("../globtimplots"),
        joinpath(dirname(dirname(@__FILE__)), "globtimplots"),
        joinpath(pwd(), "..", "globtimplots"),
        joinpath(homedir(), "globtimplots")
    ]

    for path in search_paths
        if isdir(path) && isfile(joinpath(path, "src", "comparison_plots.jl"))
            return path
        end
    end
    return nothing
end

"""
Create automatic plots using @globtimplots integration (Issue #62)
"""
function create_automatic_plots(combined_data::DataFrame, source_file::String, globtimplots_path::String)
    # Save current directory
    original_dir = pwd()

    try
        # Change to globtimplots directory
        cd(globtimplots_path)
        println("   📁 Working in: $(relpath(globtimplots_path, original_dir))")

        # Activate globtimplots environment
        Pkg.activate(".")
        println("   ✅ Activated @globtimplots environment")

        # Include comparison plotting module
        include("src/comparison_plots.jl")
        println("   ✅ Loaded comparison plotting functions")

        # Create output directory with timestamp
        timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
        output_dir = "comparison_plots_$(timestamp)"
        println("   📂 Creating plots in: $output_dir")

        # Generate all comparison plots (use Base.invokelatest to handle world age)
        results = Base.invokelatest(create_comparison_plots, combined_data; output_dir=output_dir)

        # Report results
        println("\n🎨 VISUALIZATION RESULTS:")
        println("   📁 Output directory: $(joinpath(globtimplots_path, output_dir))")

        total_files = 0
        for (plot_type, result) in results
            if result !== nothing
                println("   ✅ $plot_type: completed")
                total_files += 2  # Each plot creates text + CSV
            else
                println("   ⚠️  $plot_type: skipped (no suitable data)")
            end
        end

        println("   📊 Total files created: ~$total_files")
        println("   🔗 Source data: $(basename(source_file))")

    finally
        # Always return to original directory
        cd(original_dir)
    end
end

"""
Show manual plotting instructions when automatic plotting is not used
"""
function show_manual_plotting_instructions(output_file::String)
    println("\n📋 MANUAL VISUALIZATION INSTRUCTIONS:")
    println("   1. Change to @globtimplots directory:")
    println("      cd ../globtimplots")
    println()
    println("   2. Activate environment and run:")
    println("      julia --project=. -e \"\"\"")
    println("      using CSV, DataFrames")
    println("      include(\\\"src/comparison_plots.jl\\\")")
    println("      data = CSV.read(\\\"$(pwd())/$output_file\\\", DataFrame)")
    println("      create_comparison_plots(data; output_dir=\\\"comparison_plots\\\")\"\"\"")
    println()
    println("   3. Available plotting functions:")
    println("      - create_comparison_plots() - ALL plots (recommended)")
    println("      - plot_degree_comparison() - Degree vs L2 performance")
    println("      - plot_domain_comparison() - Domain size analysis")
    println("      - plot_experiment_overview() - Experiment summaries")
    println()
    println("   4. For statistical analysis, use Julia's Statistics package")
end

# Execute if run as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
