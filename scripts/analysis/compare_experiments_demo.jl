#!/usr/bin/env julia
"""
Experiment Comparison Demo

Simple demonstration of the new experiment comparison infrastructure.
This script shows how to:

1. Discover available experiments automatically
2. Load and combine data from multiple runs
3. Compare performance across parameters (degree, domain size)
4. Generate basic comparison plots and analysis

Usage: julia --project=. compare_experiments_demo.jl
"""

using Pkg
Pkg.activate(".")

using CSV, DataFrames, Statistics, Dates
using Printf

# Import the comparison analysis module
include("src/ComparisonAnalysis.jl")
using .ComparisonAnalysis

function main()
    println("🚀 Experiment Comparison Demo")
    println("="^50)

    # Step 1: Discover all available experiments
    println("🔍 Discovering experiments...")
    comparison = create_experiment_comparison(".")

    if isempty(comparison.experiments)
        println("❌ No experiments found. Run some experiments first!")
        return
    end

    # Step 2: Show what we found
    println("\n📊 EXPERIMENT OVERVIEW:")
    println("   $(length(comparison.experiments)) experiments discovered")
    println("   $(nrow(comparison.comparison_data)) total critical points")

    degrees = sort(unique(comparison.comparison_data.degree))
    domain_sizes = sort(unique(skipmissing(comparison.comparison_data.domain_size)))
    println("   Degrees: $degrees")
    println("   Domain sizes: $domain_sizes")

    # Step 3: Performance comparison by experiment
    println("\n🏆 PERFORMANCE RANKING:")
    exp_performance = combine(groupby(comparison.comparison_data, :experiment_id)) do sdf
        DataFrame(
            mean_l2 = mean(sdf.z),
            best_l2 = minimum(sdf.z),
            points = nrow(sdf),
            domain = first(sdf.domain_size)
        )
    end
    sort!(exp_performance, :best_l2)

    for (i, row) in enumerate(eachrow(exp_performance))
        println(@sprintf("   %d. %-35s: best=%.8f, mean=%.6f (domain=%.2f)",
            i, row.experiment_id, row.best_l2, row.mean_l2, row.domain))
    end

    # Step 4: Degree progression analysis
    println("\n📈 DEGREE PROGRESSION:")
    degree_analysis = combine(groupby(comparison.comparison_data, :degree)) do sdf
        DataFrame(
            mean_l2 = mean(sdf.z),
            std_l2 = std(sdf.z),
            best_l2 = minimum(sdf.z),
            experiments = length(unique(sdf.experiment_id))
        )
    end
    sort!(degree_analysis, :degree)

    for row in eachrow(degree_analysis)
        println(@sprintf("   Degree %d: mean=%.6f±%.6f, best=%.8f (%d exp)",
            row.degree, row.mean_l2, row.std_l2, row.best_l2, row.experiments))
    end

    # Step 5: Domain size analysis (if multiple domains)
    if length(domain_sizes) > 1
        println("\n🎯 DOMAIN SIZE ANALYSIS:")
        domain_analysis = combine(groupby(comparison.comparison_data, :domain_size)) do sdf
            DataFrame(
                mean_l2 = mean(sdf.z),
                std_l2 = std(sdf.z),
                best_l2 = minimum(sdf.z),
                experiments = length(unique(sdf.experiment_id))
            )
        end
        sort!(domain_analysis, :domain_size)

        for row in eachrow(domain_analysis)
            println(@sprintf("   Domain %.2f: mean=%.6f±%.6f, best=%.8f (%d exp)",
                row.domain_size, row.mean_l2, row.std_l2, row.best_l2, row.experiments))
        end
    end

    # Step 6: Create basic comparison plots
    println("\n🎨 Creating comparison plots...")
    output_dir = "comparison_demo_output"
    mkpath(output_dir)

    # Export data for advanced plotting
    CSV.write(joinpath(output_dir, "comparison_data.csv"), comparison.comparison_data)
    println("   ✅ Exported: comparison_data.csv")

    # Create plotting-ready datasets
    plot_data = prepare_comparison_plots(comparison.comparison_data)
    for (name, df) in plot_data
        CSV.write(joinpath(output_dir, "$(name).csv"), df)
        println("   ✅ Exported: $(name).csv")
    end

    # Simple text-based visualization
    text_file = joinpath(output_dir, "comparison_summary.txt")
    open(text_file, "w") do f
        println(f, "EXPERIMENT COMPARISON SUMMARY")
        println(f, "="^50)
        println(f, "Generated: $(Dates.now())")
        println(f, "")

        println(f, "PERFORMANCE RANKING:")
        for (i, row) in enumerate(eachrow(exp_performance))
            println(f, @sprintf("%d. %-35s: best=%.8f, mean=%.6f",
                i, row.experiment_id, row.best_l2, row.mean_l2))
        end

        println(f, "\nDEGREE PROGRESSION:")
        for row in eachrow(degree_analysis)
            println(f, @sprintf("Degree %d: mean=%.6f, best=%.8f (%d experiments)",
                row.degree, row.mean_l2, row.best_l2, row.experiments))
        end

        if length(domain_sizes) > 1
            println(f, "\nDOMAIN SIZE ANALYSIS:")
            for row in eachrow(domain_analysis)
                println(f, @sprintf("Domain %.2f: mean=%.6f, best=%.8f (%d experiments)",
                    row.domain_size, row.mean_l2, row.best_l2, row.experiments))
            end
        end
    end
    println("   ✅ Created: comparison_summary.txt")

    # Step 7: Integration with @globtimplots
    println("\n🖼️  @GLOBTIMPLOTS INTEGRATION:")
    globtimplots_path = joinpath(dirname(pwd()), "globtimplots")

    if isdir(globtimplots_path)
        println("   ✅ @globtimplots available")
        println("   📊 To create advanced plots, run:")
        println("      cd $globtimplots_path")
        println("      julia --project=. -e \"")
        println("        using CSV, DataFrames")
        println("        include(\\\"src/comparison_plots.jl\\\")")
        println("        data = CSV.read(\\\"$(pwd())/$output_dir/comparison_data.csv\\\", DataFrame)")
        println("        create_comparison_plots(data; output_dir=\\\"plots\\\")")
        println("      \"")
    else
        println("   ⚠️  @globtimplots not found - using basic text output only")
    end

    println("\n✅ COMPARISON DEMO COMPLETE!")
    println("   Results in: $output_dir/")
    println("   $(nrow(comparison.comparison_data)) data points analyzed across $(length(comparison.experiments)) experiments")

    return comparison
end

# Run if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end