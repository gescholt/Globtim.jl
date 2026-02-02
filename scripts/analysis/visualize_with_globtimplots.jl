#!/usr/bin/env julia
"""
Cluster Results Visualization using GlobtimPlots

Usage:
    # Interactive display (opens window)
    julia --project=. visualize_with_globtimplots.jl --interactive <experiment_dir>

    # Static PNG generation
    julia --project=. visualize_with_globtimplots.jl --static <experiment_dir>
"""

using Pkg
Pkg.activate(".")

using GlobtimPlots

# Import analysis modules
include("../../src/ExperimentDataLoader.jl")
using .ExperimentDataLoader

include("../../src/ParameterRecoveryAnalysis.jl")
using .ParameterRecoveryAnalysis

function print_usage()
    println("""
    Usage:
        julia --project=. visualize_with_globtimplots.jl [--interactive|--static] <experiment_dir>

    Options:
        --interactive, -i    Open interactive CairoMakie display window
        --static, -s         Save static PNG plot

    Example:
        julia --project=. visualize_with_globtimplots.jl -i hpc_results/minimal_4d_lv_test_GN=8_domain_size_param=0.15_max_time=45.0_20250930_142500
    """)
end

function visualize_interactive(experiment_dir::String)
    println("📊 Interactive Plot Display")
    println("📂 Directory: $experiment_dir")
    println()

    # Load data
    data = ExperimentDataLoader.load_experiment_data(experiment_dir)
    system_info = ExperimentDataLoader.get_system_info(data)
    true_params = ExperimentDataLoader.get_true_params(data)
    metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

    if isempty(metrics.degrees)
        println("❌ No degree data found")
        return
    end

    # Build experiment name
    exp_name = basename(experiment_dir)
    if system_info !== nothing
        gn = get(system_info, "GN", "?")
        domain = get(system_info, "domain_size", "?")
        exp_name *= " | GN=$gn, Domain=$domain"
    end

    println("📈 Degrees tested: $(metrics.degrees)")
    println("   Opening interactive window...")
    println()

    # Use GlobtimPlots
    GlobtimPlots.plot_experiment_results_interactive(exp_name, metrics)

    println("✅ Interactive plot displayed")
    println("   Close window when done")
end

function visualize_static(experiment_dir::String)
    println("📊 Static Plot Generation")
    println("📂 Directory: $experiment_dir")
    println()

    # Load data
    data = ExperimentDataLoader.load_experiment_data(experiment_dir)
    system_info = ExperimentDataLoader.get_system_info(data)
    true_params = ExperimentDataLoader.get_true_params(data)
    metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

    if isempty(metrics.degrees)
        println("❌ No degree data found")
        return
    end

    # Build experiment name
    exp_name = basename(experiment_dir)
    if system_info !== nothing
        gn = get(system_info, "GN", "?")
        domain = get(system_info, "domain_size", "?")
        exp_name *= " | GN=$gn, Domain=$domain"
    end

    println("📈 Degrees tested: $(metrics.degrees)")
    println("   Generating PNG...")
    println()

    # Use GlobtimPlots
    output_file = joinpath(experiment_dir, "results_plot.png")
    GlobtimPlots.plot_experiment_results_static(exp_name, metrics; output_file=output_file)

    println("✅ Plot saved: $output_file")
end

# Main
if length(ARGS) < 2
    print_usage()
    exit(1)
end

mode = ARGS[1]
experiment_dir = ARGS[2]

if !isdir(experiment_dir)
    println("❌ Error: Directory not found: $experiment_dir")
    exit(1)
end

if mode == "--interactive" || mode == "-i"
    visualize_interactive(experiment_dir)
elseif mode == "--static" || mode == "-s"
    visualize_static(experiment_dir)
else
    println("❌ Error: Invalid mode: $mode")
    print_usage()
    exit(1)
end