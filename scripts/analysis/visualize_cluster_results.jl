#!/usr/bin/env julia
"""
Unified Cluster Results Visualization Interface

Consolidates all cluster data workflows:
1. Data collection from cluster (SSH/local)
2. Text-based ASCII analysis
3. Cairo plot generation (via globtimcore/src/graphs_cairo.jl)

Usage:
    # Interactive mode - select experiment and visualization type
    julia --project=. visualize_cluster_results.jl

    # Direct mode - text visualization
    julia --project=. visualize_cluster_results.jl hpc_results/experiment_dir

    # Plot generation mode
    julia --project=. visualize_cluster_results.jl --plots hpc_results/experiment_dir

    # Collection mode (SSH from cluster)
    julia --project=. visualize_cluster_results.jl --collect

Dependencies:
    - ExperimentDataLoader: Load and parse experiment data
    - ParameterRecoveryAnalysis: Compute convergence metrics and distances
    - TextVisualization: ASCII-based terminal visualization
    - ComparisonAnalysis: Experiment discovery
    - Plot generation: globtimcore/src/graphs_cairo.jl (optional)
    - Collection: EnvironmentUtils, PostProcessing modules (optional)
"""

using Pkg
Pkg.activate(".")

using Printf

# Import GlobtimPlots package (contains all plotting infrastructure)
using GlobtimPlots

# Import analysis modules
include("../../src/ComparisonAnalysis.jl")
using .ComparisonAnalysis

include("../../src/ExperimentDataLoader.jl")
using .ExperimentDataLoader

include("../../src/ParameterRecoveryAnalysis.jl")
using .ParameterRecoveryAnalysis

include("../../src/TextVisualization.jl")
using .TextVisualization

# === COLLECTION FUNCTIONALITY ===
# Delegated to ExperimentDataLoader module

"""
Text-based visualization of experiment
"""
function visualize_text(experiment_dir::String)
    println("🎨 Text Visualization of Cluster Experiment Results")
    println("📂 Directory: $experiment_dir")

    # Load data using ExperimentDataLoader module
    data = ExperimentDataLoader.load_experiment_data(experiment_dir)
    system_info = ExperimentDataLoader.get_system_info(data)
    true_params = ExperimentDataLoader.get_true_params(data)

    # Display experiment info using TextVisualization module
    TextVisualization.display_experiment_info(data, system_info, true_params)

    # Extract metrics using ParameterRecoveryAnalysis module
    metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

    # Plot 1: L2 norm vs degree
    TextVisualization.plot_text(
        metrics.degrees,
        metrics.l2_norms,
        "Graph 1: L2-Norm of Polynomial Approximation vs Degree",
        "L2 Norm"
    )

    # Plot 2: Distance to ground truth parameters vs degree (primary metric for convergence)
    if true_params !== nothing && any(!isnan, metrics.min_distances)
        TextVisualization.plot_text(
            metrics.degrees,
            metrics.min_distances,
            "Graph 2: Minimum Distance to True Parameters vs Degree",
            "Min Distance"
        )

        # Also plot mean distance for completeness
        if any(!isnan, metrics.mean_distances)
            TextVisualization.plot_text(
                metrics.degrees,
                metrics.mean_distances,
                "Graph 3: Mean Distance to True Parameters vs Degree",
                "Mean Distance"
            )
        end
    else
        println("\n" * "="^70)
        println("Graph 2: Distance to True Parameters")
        println("="^70)
        println("  (no ground truth parameters available for this experiment)")
    end

    # Plot 4: Condition number vs degree (numerical stability indicator)
    if any(!isnan, metrics.condition_numbers)
        TextVisualization.plot_text(
            metrics.degrees,
            metrics.condition_numbers,
            "Graph 4: Condition Number vs Degree (numerical stability)",
            "Cond #"
        )
    end

    # Summary statistics using TextVisualization module
    TextVisualization.display_convergence_summary(metrics, true_params)
end

# === INTERACTIVE PLOT DISPLAY FUNCTIONALITY ===

"""
Display interactive plot display for experiment
Opens interactive window with zoom, pan, and hover capabilities
"""
function visualize_interactive(experiment_dir::String)
    println("📊 Interactive Plot Display for Cluster Experiment")
    println("📂 Directory: $experiment_dir")
    println()

    # Load experiment data
    data = ExperimentDataLoader.load_experiment_data(experiment_dir)
    system_info = ExperimentDataLoader.get_system_info(data)
    true_params = ExperimentDataLoader.get_true_params(data)
    metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

    if isempty(metrics.degrees)
        println("❌ No degree data found in experiment")
        return
    end

    println("📈 Displaying interactive plots for degrees: $(metrics.degrees)")
    println("   Close window or press 'q' to exit")
    println()

    # Create multi-panel figure
    fig = GLMakie.Figure(size = (1400, 900))

    # Plot 1: L2 Norm vs Degree
    ax1 = GLMakie.Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    GLMakie.scatterlines!(ax1, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 15, linewidth = 3,
        label = "L2 Approximation Error")
    GLMakie.axislegend(ax1, position = :rt)

    # Plot 2: Euclidean Distance to True Parameters (primary convergence metric)
    if true_params !== nothing && any(!isnan, metrics.min_distances)
        ax2 = GLMakie.Axis(fig[1, 2],
            title = "Euclidean Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )

        # Min distance (best critical point)
        GLMakie.scatterlines!(ax2, metrics.degrees, metrics.min_distances,
            color = :green, markersize = 15, linewidth = 3,
            label = "Min Distance")

        # Mean distance (average over all critical points)
        if any(!isnan, metrics.mean_distances)
            GLMakie.scatterlines!(ax2, metrics.degrees, metrics.mean_distances,
                color = :orange, markersize = 12, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end

        GLMakie.axislegend(ax2, position = :rt)
    else
        ax2 = GLMakie.Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)",
            xlabel = "Polynomial Degree",
            ylabel = "Distance"
        )
        GLMakie.text!(ax2, "No true parameters available\nfor this experiment",
            position = (mean(metrics.degrees), 0.5),
            align = (:center, :center),
            fontsize = 16)
    end

    # Plot 3: Condition Number vs Degree (numerical stability)
    if any(!isnan, metrics.condition_numbers)
        ax3 = GLMakie.Axis(fig[2, 1],
            title = "Condition Number (Numerical Stability)",
            xlabel = "Polynomial Degree",
            ylabel = "Condition Number"
        )
        GLMakie.scatterlines!(ax3, metrics.degrees, metrics.condition_numbers,
            color = :red, markersize = 15, linewidth = 3,
            label = "Condition Number")
        GLMakie.axislegend(ax3, position = :rt)
    end

    # Plot 4: Convergence Rate Analysis
    if true_params !== nothing && length(metrics.min_distances) >= 2
        # Compute convergence rate between consecutive degrees
        valid_idx = findall(!isnan, metrics.min_distances)
        if length(valid_idx) >= 2
            ax4 = GLMakie.Axis(fig[2, 2],
                title = "Parameter Convergence Rate",
                xlabel = "Polynomial Degree",
                ylabel = "Convergence Rate (log scale)",
                yscale = log10
            )

            # Compute rate: ratio of consecutive distances
            conv_rates = Float64[]
            conv_degrees = Float64[]
            for i in 2:length(valid_idx)
                idx_prev = valid_idx[i-1]
                idx_curr = valid_idx[i]
                rate = metrics.min_distances[idx_prev] / metrics.min_distances[idx_curr]
                push!(conv_rates, rate)
                push!(conv_degrees, metrics.degrees[idx_curr])
            end

            if !isempty(conv_rates)
                GLMakie.scatterlines!(ax4, conv_degrees, conv_rates,
                    color = :purple, markersize = 15, linewidth = 3,
                    label = "Convergence Factor")
                GLMakie.axislegend(ax4, position = :rt)
            end
        end
    end

    # Add overall title with experiment info
    system_info = ExperimentDataLoader.get_system_info(data)
    exp_name = basename(experiment_dir)
    title_str = "Experiment: $exp_name"
    if system_info !== nothing
        gn = get(system_info, "GN", "?")
        domain = get(system_info, "domain_size", "?")
        title_str *= " | GN=$gn, Domain=$domain"
    end
    GLMakie.Label(fig[0, :], title_str, fontsize = 20, tellwidth = false)

    # Display the figure
    display(fig)

    println()
    println("✅ Interactive plot displayed")
    println("   Use mouse to zoom/pan, close window when done")
    println()
end

# === CAIRO PLOT GENERATION FUNCTIONALITY ===

"""
Generate static Cairo plots for experiment (saves PNG files)
"""
function visualize_plots(experiment_dir::String)
    println("📊 Cairo Plot Generation for Cluster Experiment")
    println("📂 Directory: $experiment_dir")
    println()

    # Check if CairoMakie is available
    if !CAIROMAKIE_AVAILABLE
        println("❌ Error: CairoMakie package not available")
        println("   Install with: ] add CairoMakie")
        println()
        return
    end

    # Load experiment data using ExperimentDataLoader module
    data = ExperimentDataLoader.load_experiment_data(experiment_dir)
    true_params = ExperimentDataLoader.get_true_params(data)
    metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

    if isempty(metrics.degrees)
        println("❌ No degree data found in experiment")
        return
    end

    println("📈 Generating plots for degrees: $(metrics.degrees)")
    println()

    # Create multi-panel figure
    fig = CairoMakie.Figure(size = (1200, 800))

    # Plot 1: L2 Norm vs Degree
    ax1 = CairoMakie.Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    CairoMakie.scatterlines!(ax1, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 12, linewidth = 3,
        label = "L2 Approximation Error")

    # Plot 2: Euclidean Distance to True Parameters
    if true_params !== nothing && any(!isnan, metrics.min_distances)
        ax2 = CairoMakie.Axis(fig[1, 2],
            title = "Euclidean Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )
        CairoMakie.scatterlines!(ax2, metrics.degrees, metrics.min_distances,
            color = :green, markersize = 12, linewidth = 3,
            label = "Min Distance")

        if any(!isnan, metrics.mean_distances)
            CairoMakie.scatterlines!(ax2, metrics.degrees, metrics.mean_distances,
                color = :orange, markersize = 8, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end
        CairoMakie.Legend(fig[2, 2], ax2, "Distance Metrics", framevisible = true)
    else
        ax2 = CairoMakie.Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)"
        )
    end

    # Plot 3: Condition Number
    if any(!isnan, metrics.condition_numbers)
        ax3 = CairoMakie.Axis(fig[2, 1],
            title = "Condition Number (Numerical Stability)",
            xlabel = "Polynomial Degree",
            ylabel = "Condition Number"
        )
        CairoMakie.scatterlines!(ax3, metrics.degrees, metrics.condition_numbers,
            color = :red, markersize = 12, linewidth = 3,
            label = "Condition Number")
    end

    # Save plot
    output_file = joinpath(experiment_dir, "convergence_plots.png")
    CairoMakie.save(output_file, fig)
    println("✅ Saved: $output_file")

    # Also save individual plots
    fig_l2 = CairoMakie.Figure(size = (800, 600))
    ax_l2 = CairoMakie.Axis(fig_l2[1, 1],
        title = "L2 Norm vs Polynomial Degree",
        xlabel = "Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    CairoMakie.scatterlines!(ax_l2, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 14, linewidth = 3)

    output_l2 = joinpath(experiment_dir, "plot_l2_norm.png")
    CairoMakie.save(output_l2, fig_l2)
    println("✅ Saved: $output_l2")

    println()
    println("📁 Plots saved to: $experiment_dir")
    println()
end

# === INTERACTIVE SELECTION ===

"""
Interactive experiment selection mode
"""
function select_experiment_interactively()
    println("🔍 Interactive Experiment Selection")
    println("="^70)
    println()

    # Discover experiments in hpc_results directory
    results_dir = "hpc_results"
    if !isdir(results_dir)
        println("❌ No $results_dir directory found")
        println("   Please run some cluster experiments first!")
        exit(1)
    end

    # Discover all experiments
    experiments = discover_experiments(results_dir)

    if isempty(experiments)
        println("❌ No experiments found in $results_dir")
        println("   Please run some cluster experiments first!")
        exit(1)
    end

    # Sort experiments by timestamp (newest first)
    exp_list = collect(experiments)
    sort!(exp_list, by = x -> get(x[2], "timestamp", ""), rev=true)

    # Display options
    println("\n📊 AVAILABLE EXPERIMENTS:")
    println("="^70)
    for (i, (exp_id, exp_info)) in enumerate(exp_list)
        timestamp = get(exp_info, "timestamp", "unknown")
        degrees = exp_info["degrees"]
        params = get(exp_info, "parameters", Dict())

        println("\n[$i] $exp_id")
        println("    Time: $timestamp")
        println("    Degrees: $degrees")

        # Show key parameters if available
        if !isempty(params)
            if haskey(params, "domain_size")
                println("    Domain size: $(params["domain_size"])")
            end
            if haskey(params, "GN")
                println("    GN: $(params["GN"])")
            end
        end
    end

    # Get user selection
    println("\n" * "="^70)
    print("Select experiment number (1-$(length(exp_list))) or 'q' to quit: ")
    choice = readline()

    if lowercase(strip(choice)) == "q"
        println("Exiting...")
        exit(0)
    end

    try
        idx = parse(Int, choice)
        if idx < 1 || idx > length(exp_list)
            println("❌ Invalid selection: $idx")
            exit(1)
        end

        selected_exp = exp_list[idx]
        return selected_exp[2]["path"]
    catch e
        println("❌ Invalid input: $choice")
        exit(1)
    end
end

"""
Interactive visualization mode selection
"""
function select_visualization_mode()
    println("\n📊 SELECT VISUALIZATION MODE:")
    println("="^70)
    println("[1] Text-based ASCII visualization (fast, no dependencies)")
    println("[2] Interactive GLMakie display (requires GLMakie, opens window)")
    println("[3] Cairo plots generation (requires CairoMakie, saves PNG)")
    println("[q] Quit")
    println("="^70)
    print("Select mode (1-3) or 'q' to quit: ")

    choice = readline()

    if lowercase(strip(choice)) == "q"
        println("Exiting...")
        exit(0)
    end

    return choice
end

# === MAIN EXECUTION ===

function print_usage()
    println("""
    📊 Unified Cluster Results Visualization Interface

    Usage:
        julia --project=. visualize_cluster_results.jl [OPTIONS] [EXPERIMENT_DIR]

    Modes:
        (no args)               Interactive mode - select experiment and visualization
        EXPERIMENT_DIR          Direct text visualization
        --interactive, -i DIR   Interactive GLMakie display (opens window)
        --plots DIR             Generate Cairo plots (saves PNG files)
        --collect               Collect experiments from cluster (SSH)

    Examples:
        julia --project=. visualize_cluster_results.jl
        julia --project=. visualize_cluster_results.jl hpc_results/exp_123
        julia --project=. visualize_cluster_results.jl -i hpc_results/exp_123
        julia --project=. visualize_cluster_results.jl --plots hpc_results/exp_123

    Dependencies:
        Text mode:        ComparisonAnalysis (built-in)
        Interactive mode: GLMakie
        Plot mode:        CairoMakie
        Collection:       EnvironmentUtils, PostProcessing modules
    """)
end

function main()
    # Parse arguments
    if length(ARGS) == 0
        # Interactive mode
        experiment_dir = select_experiment_interactively()
        mode_choice = select_visualization_mode()

        if mode_choice == "1"
            visualize_text(experiment_dir)
        elseif mode_choice == "2"
            visualize_interactive(experiment_dir)
        elseif mode_choice == "3"
            visualize_plots(experiment_dir)
        else
            println("❌ Invalid mode selection: $mode_choice")
            exit(1)
        end

    elseif ARGS[1] == "--help" || ARGS[1] == "-h"
        print_usage()

    elseif ARGS[1] == "--collect"
        println("🔄 Collecting experiments from cluster...")
        dirs = ExperimentDataLoader.collect_experiment_directories()
        println("✅ Found $(length(dirs)) experiments")
        for dir in dirs
            println("   - $dir")
        end

    elseif ARGS[1] == "--interactive" || ARGS[1] == "-i"
        if length(ARGS) < 2
            println("❌ Error: --interactive requires experiment directory argument")
            print_usage()
            exit(1)
        end
        experiment_dir = ARGS[2]
        visualize_interactive(experiment_dir)

    elseif ARGS[1] == "--plots"
        if length(ARGS) < 2
            println("❌ Error: --plots requires experiment directory argument")
            print_usage()
            exit(1)
        end
        experiment_dir = ARGS[2]
        visualize_plots(experiment_dir)

    else
        # Direct mode with experiment directory
        experiment_dir = ARGS[1]
        visualize_text(experiment_dir)
    end
end

# Run if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end