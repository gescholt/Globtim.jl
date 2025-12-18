#!/usr/bin/env julia
"""
Experiment Comparison Workflow for @globtimcore ↔ @globtimplots Integration

This script provides a complete workflow for comparing experiment outputs across
different parameters. It integrates @globtimcore's ComparisonAnalysis module
with @globtimplots plotting capabilities.

Features:
- Automatic experiment discovery
- Parameter-based comparison analysis
- Multi-experiment visualization
- Cross-project integration with @globtimplots

Usage: julia --project=. experiment_comparison_workflow.jl [options]

Options:
  --search-path PATH    Root directory to search for experiments (default: ".")
  --degrees DEGREES     Comma-separated list of degrees to analyze (default: all)
  --output-dir DIR      Output directory for plots and analysis (default: "comparison_output")
  --parameter PARAM     Primary parameter to compare by (degree, domain_size)
"""

using Pkg
Pkg.activate(".")

using ArgParse, CSV, DataFrames, Statistics, Dates
using Printf

# Import analysis capabilities
include("src/ComparisonAnalysis.jl")
using .ComparisonAnalysis

"""
Parse command line arguments
"""
function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--search-path"
            help = "Root directory to search for experiments"
            arg_type = String
            default = "."
        "--degrees"
            help = "Comma-separated degrees to analyze (e.g., 4,5,6)"
            arg_type = String
            default = ""
        "--output-dir"
            help = "Output directory for comparison results"
            arg_type = String
            default = "comparison_output"
        "--parameter"
            help = "Primary comparison parameter"
            arg_type = String
            default = "degree"
        "--use-globtimplots"
            help = "Attempt to use @globtimplots for advanced visualization"
            action = :store_true
    end

    return parse_args(s)
end

"""
Main comparison workflow
"""
function main()
    println("🚀 Experiment Comparison Workflow")
    println("="^60)

    # Parse arguments
    args = parse_commandline()

    search_path = args["search-path"]
    output_dir = args["output-dir"]
    use_globtimplots = args["use-globtimplots"]

    # Parse degrees if provided
    degrees = Int[]
    if !isempty(args["degrees"])
        try
            degrees = [parse(Int, strip(d)) for d in split(args["degrees"], ",")]
            println("📊 Analyzing degrees: $degrees")
        catch e
            println("⚠️  Invalid degrees format: $(args["degrees"])")
            println("   Expected format: 4,5,6")
        end
    end

    println("🔍 Search path: $search_path")
    println("📁 Output directory: $output_dir")
    println()

    # Step 1: Create comprehensive comparison analysis
    comparison = create_experiment_comparison(search_path; degrees=degrees)

    if isempty(comparison.experiments)
        println("❌ No experiments found. Ensure results_summary.json files exist.")
        return 1
    end

    if nrow(comparison.comparison_data) == 0
        println("❌ No data could be loaded from discovered experiments.")
        return 1
    end

    # Step 2: Create output directory
    mkpath(output_dir)
    println("📁 Created output directory: $output_dir")

    # Step 3: Generate analysis report
    report_file = joinpath(output_dir, "comparison_report.txt")
    generate_comparison_report(comparison, report_file)
    println("✅ Generated: comparison_report.txt")

    # Step 4: Export data for plotting
    data_dir = joinpath(output_dir, "data")
    mkpath(data_dir)

    # Export raw comparison data
    CSV.write(joinpath(data_dir, "all_comparison_data.csv"), comparison.comparison_data)
    println("✅ Exported: all_comparison_data.csv")

    # Export plotting-ready data
    plot_data = prepare_comparison_plots(comparison.comparison_data)
    for (name, df) in plot_data
        CSV.write(joinpath(data_dir, "$(name).csv"), df)
        println("✅ Exported: $(name).csv")
    end

    # Step 5: Create basic plots (built-in functionality)
    create_basic_comparison_plots(comparison.comparison_data, output_dir)

    # Step 6: Try to use @globtimplots for advanced visualization
    if use_globtimplots
        try_globtimplots_integration(comparison.comparison_data, output_dir)
    end

    # Step 7: Generate usage instructions
    generate_usage_instructions(output_dir, use_globtimplots)

    println("\n🎯 COMPARISON WORKFLOW COMPLETE!")
    println("   Experiments analyzed: $(length(comparison.experiments))")
    println("   Data points: $(nrow(comparison.comparison_data))")
    println("   Output location: $output_dir")

    return 0
end

"""
Generate comprehensive comparison report
"""
function generate_comparison_report(comparison::ExperimentComparison, report_file::String)
    open(report_file, "w") do f
        println(f, "EXPERIMENT COMPARISON ANALYSIS REPORT")
        println(f, "="^60)
        println(f, "Generated: $(Dates.now())")
        println(f, "")

        # Experiment overview
        println(f, "EXPERIMENT OVERVIEW")
        println(f, "-"^30)
        println(f, "Total experiments: $(length(comparison.experiments))")
        println(f, "Total data points: $(nrow(comparison.comparison_data))")

        degrees = sort(unique(comparison.comparison_data.degree))
        println(f, "Degrees analyzed: $degrees")

        domain_sizes = sort(unique(skipmissing(comparison.comparison_data.domain_size)))
        println(f, "Domain sizes: $domain_sizes")
        println(f, "")

        # Individual experiment details
        println(f, "INDIVIDUAL EXPERIMENT DETAILS")
        println(f, "-"^40)
        for (exp_id, metrics) in comparison.metrics
            println(f, "Experiment: $exp_id")
            println(f, "  Mean L2: $(round(metrics["mean_l2"], digits=6))")
            println(f, "  Best L2: $(round(metrics["best_l2"], digits=8))")
            println(f, "  Std L2:  $(round(metrics["std_l2"], digits=6))")
            println(f, "  Points:  $(Int(metrics["total_points"]))")
            println(f, "  Degrees: $(Int(metrics["degrees_count"]))")
            println(f, "")
        end

        # Parameter analysis
        if haskey(comparison.parameter_groups, "degree")
            println(f, "DEGREE PROGRESSION ANALYSIS")
            println(f, "-"^35)
            for degree in degrees
                degree_data = filter(row -> row.degree == degree, comparison.comparison_data)
                mean_l2 = mean(degree_data.z)
                std_l2 = std(degree_data.z)
                n_exp = length(unique(degree_data.experiment_id))
                println(f, "  Degree $degree: $(n_exp) exp, mean L2: $(round(mean_l2, digits=6)), std: $(round(std_l2, digits=6))")
            end
            println(f, "")
        end

        if length(domain_sizes) > 1
            println(f, "DOMAIN SIZE ANALYSIS")
            println(f, "-"^25)
            for domain in domain_sizes
                domain_data = filter(row -> row.domain_size == domain, comparison.comparison_data)
                mean_l2 = mean(domain_data.z)
                std_l2 = std(domain_data.z)
                n_exp = length(unique(domain_data.experiment_id))
                println(f, "  Domain $domain: $(n_exp) exp, mean L2: $(round(mean_l2, digits=6)), std: $(round(std_l2, digits=6))")
            end
            println(f, "")
        end

        # Best performers
        println(f, "BEST PERFORMERS")
        println(f, "-"^20)

        # Best by mean performance
        best_mean_exp = ""
        best_mean_value = Inf
        for (exp_id, metrics) in comparison.metrics
            if metrics["mean_l2"] < best_mean_value
                best_mean_value = metrics["mean_l2"]
                best_mean_exp = exp_id
            end
        end
        println(f, "Best mean performance: $best_mean_exp ($(round(best_mean_value, digits=6)))")

        # Best individual result
        best_individual = minimum(comparison.comparison_data.z)
        best_individual_exp = comparison.comparison_data[argmin(comparison.comparison_data.z), :experiment_id]
        println(f, "Best individual result: $best_individual_exp ($(round(best_individual, digits=8)))")
    end
end

"""
Create basic comparison plots using built-in functionality
"""
function create_basic_comparison_plots(comparison_data::DataFrame, output_dir::String)
    println("\n📊 Creating basic comparison plots...")

    # Degree comparison table
    degree_file = joinpath(output_dir, "degree_comparison.txt")
    open(degree_file, "w") do f
        println(f, "DEGREE COMPARISON TABLE")
        println(f, "="^50)
        println(f, "Experiment          | Degree | Mean L2  | Best L2   | Points")
        println(f, "-"^50)

        for exp_id in unique(comparison_data.experiment_id)
            exp_data = filter(row -> row.experiment_id == exp_id, comparison_data)
            for degree in sort(unique(exp_data.degree))
                degree_data = filter(row -> row.degree == degree, exp_data)
                mean_l2 = mean(degree_data.z)
                best_l2 = minimum(degree_data.z)
                n_points = nrow(degree_data)
                @printf(f, "%-20s | %6d | %8.5f | %9.6f | %6d\n",
                    exp_id, degree, mean_l2, best_l2, n_points)
            end
        end
    end
    println("   ✅ Created: degree_comparison.txt")

    # Summary statistics
    stats_file = joinpath(output_dir, "summary_statistics.txt")
    open(stats_file, "w") do f
        println(f, "COMPARISON SUMMARY STATISTICS")
        println(f, "="^40)
        println(f, "Total experiments: $(length(unique(comparison_data.experiment_id)))")
        println(f, "Total data points: $(nrow(comparison_data))")
        println(f, "Degree range: $(minimum(comparison_data.degree)) - $(maximum(comparison_data.degree))")
        println(f, "L2 range: $(round(minimum(comparison_data.z), digits=8)) - $(round(maximum(comparison_data.z), digits=6))")
        println(f, "Overall mean L2: $(round(mean(comparison_data.z), digits=6))")
        println(f, "Overall std L2: $(round(std(comparison_data.z), digits=6))")

        # Domain size analysis if available
        domain_sizes = unique(skipmissing(comparison_data.domain_size))
        if length(domain_sizes) > 1
            println(f, "\nDomain size analysis:")
            for domain in sort(domain_sizes)
                domain_data = filter(row -> row.domain_size == domain, comparison_data)
                println(f, "  Domain $domain: $(round(mean(domain_data.z), digits=6)) mean L2")
            end
        end
    end
    println("   ✅ Created: summary_statistics.txt")
end

"""
Try to use @globtimplots for advanced visualization
"""
function try_globtimplots_integration(comparison_data::DataFrame, output_dir::String)
    println("\n🎨 Attempting @globtimplots integration...")

    globtimplots_path = joinpath(dirname(pwd()), "globtimplots")

    if !isdir(globtimplots_path)
        println("   ⚠️  @globtimplots not found at: $globtimplots_path")
        return false
    end

    try
        # Try to activate and use @globtimplots
        old_project = Base.active_project()

        println("   📦 Activating @globtimplots...")
        Pkg.activate(globtimplots_path)

        # Import plotting module
        plots_dir = joinpath(output_dir, "globtimplots_output")
        mkpath(plots_dir)

        # Create a simple data export for @globtimplots
        CSV.write(joinpath(plots_dir, "comparison_data.csv"), comparison_data)

        # Try to use the comparison plotting functions
        try
            include(joinpath(globtimplots_path, "src", "comparison_plots.jl"))

            # Use the plotting functions if they loaded successfully
            create_comparison_plots(comparison_data; output_dir=plots_dir)
            println("   ✅ @globtimplots comparison plots created!")

        catch e
            println("   ⚠️  @globtimplots plotting failed: $e")
            # Create instructions for manual plotting
            instructions_file = joinpath(plots_dir, "globtimplots_instructions.txt")
            open(instructions_file, "w") do f
                println(f, "@globtimplots Integration Instructions")
                println(f, "="^50)
                println(f, "1. Activate @globtimplots environment:")
                println(f, "   cd $globtimplots_path")
                println(f, "   julia --project=.")
                println(f, "")
                println(f, "2. Load the comparison data:")
                println(f, "   using CSV, DataFrames")
                println(f, "   comparison_data = CSV.read(\"$plots_dir/comparison_data.csv\", DataFrame)")
                println(f, "")
                println(f, "3. Use plotting functions:")
                println(f, "   include(\"src/comparison_plots.jl\")")
                println(f, "   create_comparison_plots(comparison_data; output_dir=\"plots\")")
            end
            println("   📝 Created integration instructions")
        end

        # Restore original project
        Pkg.activate(old_project)
        return true

    catch e
        println("   ❌ @globtimplots integration failed: $e")
        return false
    end
end

"""
Generate usage instructions for the comparison results
"""
function generate_usage_instructions(output_dir::String, tried_globtimplots::Bool)
    instructions_file = joinpath(output_dir, "README.md")

    open(instructions_file, "w") do f
        println(f, "# Experiment Comparison Results")
        println(f, "")
        println(f, "This directory contains the results of a comprehensive experiment comparison analysis.")
        println(f, "")
        println(f, "## Generated Files")
        println(f, "")
        println(f, "### Analysis Reports")
        println(f, "- `comparison_report.txt`: Comprehensive analysis report")
        println(f, "- `degree_comparison.txt`: Degree-by-degree performance comparison")
        println(f, "- `summary_statistics.txt`: Overall summary statistics")
        println(f, "")
        println(f, "### Data Files (`data/` directory)")
        println(f, "- `all_comparison_data.csv`: Complete raw comparison dataset")
        println(f, "- `degree_comparison.csv`: Degree progression analysis data")
        println(f, "- `experiment_summary.csv`: Per-experiment summary statistics")

        if tried_globtimplots
            println(f, "")
            println(f, "### Advanced Visualization (`globtimplots_output/`)")
            println(f, "- Enhanced plots created with @globtimplots")
            println(f, "- `globtimplots_instructions.txt`: Manual plotting instructions")
        end

        println(f, "")
        println(f, "## Usage")
        println(f, "")
        println(f, "### View Results")
        println(f, "```bash")
        println(f, "# View comprehensive report")
        println(f, "cat comparison_report.txt")
        println(f, "")
        println(f, "# View degree comparison")
        println(f, "cat degree_comparison.txt")
        println(f, "```")
        println(f, "")
        println(f, "### Load Data in Julia")
        println(f, "```julia")
        println(f, "using CSV, DataFrames")
        println(f, "comparison_data = CSV.read(\"data/all_comparison_data.csv\", DataFrame)")
        println(f, "```")
        println(f, "")
        println(f, "### Re-run Analysis")
        println(f, "```bash")
        println(f, "julia --project=. experiment_comparison_workflow.jl --help")
        println(f, "```")
    end

    println("✅ Generated: README.md")
end

# Execute if run as script
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end