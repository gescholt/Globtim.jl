#!/usr/bin/env julia
"""
Convergence Analysis Plotting Script

Generates convergence plots for cluster experiment results.
Interactive GLMakie display by default, with --static flag for PNG export.

Usage:
    # Interactive display (default)
    julia --project=. scripts/analysis/plot_convergence_simple.jl <experiment_dir>

    # Static PNG export
    julia --project=. scripts/analysis/plot_convergence_simple.jl --static <experiment_dir>
"""

using Pkg
Pkg.activate(".")

using JSON
using Printf
using Statistics
using GlobtimPlots

# Check for --static flag
const USE_STATIC = "--static" in ARGS
if USE_STATIC
    filter!(x -> x != "--static", ARGS)
    using CairoMakie
else
    using GLMakie
end

"""
Load experiment data from results_summary.json
"""
function load_experiment_data(exp_dir::String)
    json_file = joinpath(exp_dir, "results_summary.json")

    if !isfile(json_file)
        error("No results_summary.json found in $exp_dir")
    end

    return JSON.parsefile(json_file)
end

"""
Extract convergence metrics from experiment data
"""
function extract_convergence_metrics(data::Dict)
    degrees = Int[]
    l2_norms = Float64[]
    condition_numbers = Float64[]
    critical_points_counts = Int[]

    results_summary = get(data, "results_summary", Dict())

    for (key, result) in results_summary
        if startswith(string(key), "degree_")
            degree_str = replace(string(key), "degree_" => "")
            degree = parse(Int, degree_str)

            push!(degrees, degree)
            push!(l2_norms, get(result, "l2_approx_error", NaN))
            push!(condition_numbers, get(result, "condition_number", NaN))
            push!(critical_points_counts, get(result, "critical_points_refined", 0))
        end
    end

    # Sort by degree
    sort_idx = sortperm(degrees)
    degrees = degrees[sort_idx]
    l2_norms = l2_norms[sort_idx]
    condition_numbers = condition_numbers[sort_idx]
    critical_points_counts = critical_points_counts[sort_idx]

    return (
        degrees = degrees,
        l2_norms = l2_norms,
        condition_numbers = condition_numbers,
        critical_points_counts = critical_points_counts
    )
end

"""
Extract true parameters if this is a parameter recovery experiment
"""
function get_true_parameters(data::Dict)
    system_info = get(data, "system_info", Dict())

    if haskey(system_info, "true_parameters")
        return system_info["true_parameters"]
    end

    return nothing
end

"""
Compute distance to true parameters from CSV files
"""
function compute_distances_to_true(exp_dir::String, degrees::Vector{Int}, true_params::Vector)
    min_distances = Float64[]
    mean_distances = Float64[]

    for degree in degrees
        csv_file = joinpath(exp_dir, "critical_points_deg_$(degree).csv")

        if !isfile(csv_file)
            push!(min_distances, NaN)
            push!(mean_distances, NaN)
            continue
        end

        # Simple CSV reading (just coordinates)
        try
            lines = readlines(csv_file)
            if length(lines) <= 1  # header only or empty
                push!(min_distances, NaN)
                push!(mean_distances, NaN)
                continue
            end

            distances = Float64[]
            for line in lines[2:end]  # skip header
                parts = split(line, ',')
                if length(parts) >= length(true_params)
                    # Extract coordinates (x1, x2, x3, x4, ...)
                    coords = [parse(Float64, parts[i]) for i in 1:length(true_params)]
                    dist = sqrt(sum((coords .- true_params).^2))
                    push!(distances, dist)
                end
            end

            if !isempty(distances)
                push!(min_distances, minimum(distances))
                push!(mean_distances, sum(distances) / length(distances))
            else
                push!(min_distances, NaN)
                push!(mean_distances, NaN)
            end
        catch e
            @warn "Failed to read $csv_file: $e"
            push!(min_distances, NaN)
            push!(mean_distances, NaN)
        end
    end

    return min_distances, mean_distances
end

"""
Create convergence plots (interactive or static based on USE_STATIC flag)
"""
function plot_convergence(exp_dir::String, metrics, true_params, output_file::Union{String,Nothing}=nothing)
    # Create figure with 2x2 grid using appropriate backend
    if USE_STATIC
        fig = CairoMakie.Figure(size = (1200, 900))
        Makie = CairoMakie
    else
        fig = GLMakie.Figure(size = (1400, 900))
        Makie = GLMakie
    end

    exp_name = basename(exp_dir)
    Makie.Label(fig[0, :], "Convergence Analysis: $exp_name", fontsize = 20, tellwidth = false)

    # Plot 1: L2 Norm vs Degree
    ax1 = Makie.Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )

    valid_l2 = .!isnan.(metrics.l2_norms)
    if any(valid_l2)
        Makie.scatterlines!(ax1, metrics.degrees[valid_l2], metrics.l2_norms[valid_l2],
            color = :blue, markersize = 15, linewidth = 3,
            label = "L2 Approximation Error")
        Makie.axislegend(ax1, position = :rt)
    else
        Makie.text!(ax1, "No L2 norm data available", position = (mean(metrics.degrees), 1.0),
            align = (:center, :center))
    end

    # Plot 2: Distance to True Parameters
    if true_params !== nothing
        min_dists, mean_dists = compute_distances_to_true(exp_dir, metrics.degrees, true_params)

        ax2 = Makie.Axis(fig[1, 2],
            title = "Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )

        valid_min = .!isnan.(min_dists)
        valid_mean = .!isnan.(mean_dists)

        if any(valid_min)
            Makie.scatterlines!(ax2, metrics.degrees[valid_min], min_dists[valid_min],
                color = :green, markersize = 15, linewidth = 3,
                label = "Min Distance")
        end

        if any(valid_mean)
            Makie.scatterlines!(ax2, metrics.degrees[valid_mean], mean_dists[valid_mean],
                color = :orange, markersize = 12, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end

        if any(valid_min) || any(valid_mean)
            Makie.axislegend(ax2, position = :rt)
        else
            Makie.text!(ax2, "No distance data available", position = (mean(metrics.degrees), 1.0),
                align = (:center, :center))
        end
    else
        ax2 = Makie.Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)"
        )
        Makie.text!(ax2, "No true parameters\navailable for this experiment",
            position = (mean(metrics.degrees), 0.5),
            align = (:center, :center), fontsize = 14)
    end

    # Plot 3: Condition Number
    ax3 = Makie.Axis(fig[2, 1],
        title = "Condition Number (Numerical Stability)",
        xlabel = "Polynomial Degree",
        ylabel = "Condition Number"
    )

    valid_cond = .!isnan.(metrics.condition_numbers)
    if any(valid_cond)
        Makie.scatterlines!(ax3, metrics.degrees[valid_cond], metrics.condition_numbers[valid_cond],
            color = :red, markersize = 15, linewidth = 3,
            label = "Condition Number")
        Makie.axislegend(ax3, position = :lt)
    else
        Makie.text!(ax3, "No condition number data", position = (mean(metrics.degrees), 1.0),
            align = (:center, :center))
    end

    # Plot 4: Critical Points Count
    ax4 = Makie.Axis(fig[2, 2],
        title = "Critical Points Found",
        xlabel = "Polynomial Degree",
        ylabel = "Number of Critical Points"
    )

    Makie.barplot!(ax4, metrics.degrees, metrics.critical_points_counts,
        color = :purple)

    # Save or display
    if USE_STATIC && output_file !== nothing
        CairoMakie.save(output_file, fig)
        println("✅ Saved: $output_file")
    else
        # Interactive display - show the figure (GLMakie window)
        display(fig)
        if USE_STATIC && output_file !== nothing
            println("💾 Also saving to: $output_file")
            CairoMakie.save(output_file, fig)
        else
            println("🖥️  Interactive display (GLMakie window opened)")
            println("   Close the window when done")
        end
    end

    return fig
end

"""
Main execution
"""
function main()
    if length(ARGS) < 1
        println("Usage: julia --project=. scripts/analysis/plot_convergence_simple.jl <experiment_dir>")
        exit(1)
    end

    exp_dir = ARGS[1]

    if !isdir(exp_dir)
        println("❌ Directory not found: $exp_dir")
        exit(1)
    end

    println("📊 Generating convergence plots for: $(basename(exp_dir))")
    println()

    # Load data
    data = load_experiment_data(exp_dir)
    metrics = extract_convergence_metrics(data)
    true_params = get_true_parameters(data)

    if isempty(metrics.degrees)
        println("❌ No degree data found in experiment")
        exit(1)
    end

    println("📈 Found degrees: $(metrics.degrees)")
    if true_params !== nothing
        println("🎯 True parameters: $true_params")
    else
        println("ℹ️  No true parameters (not a parameter recovery experiment)")
    end

    # Validate minimum degrees for convergence analysis
    if length(metrics.degrees) < 3
        println()
        println("⚠️  WARNING: Only $(length(metrics.degrees)) degree(s) found.")
        println("   Convergence analysis requires at least 3 degrees.")
        println("   See docs/CLUSTER_DATA_STANDARDS.md for details.")
        println()
    end

    println()

    # Generate plots
    if USE_STATIC
        output_file = joinpath(exp_dir, "convergence_analysis.png")
        plot_convergence(exp_dir, metrics, true_params, output_file)
        println()
        println("✅ Done!")
    else
        # Interactive mode - display and wait
        println("🎨 Opening interactive plot...")
        plot_convergence(exp_dir, metrics, true_params, nothing)
        println()
        println("✅ Done! (Press Ctrl+C or close window to exit)")

        # Keep Julia running so GLMakie window stays open
        try
            while true
                sleep(1)
            end
        catch e
            if e isa InterruptException
                println("\n👋 Closing...")
            else
                rethrow(e)
            end
        end
    end
end

# Run if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
