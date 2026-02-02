"""
TextVisualization Module

ASCII-based visualization utilities for terminal output:
- Simple line plots with text characters
- Data tables with formatted numeric output
- Summary displays for experiment information

Designed for quick visualization without graphics dependencies.

Usage:
    include("src/TextVisualization.jl")
    using .TextVisualization

    plot_text(degrees, values, "Title", "Y-axis Label")
    display_experiment_info(data, system_info, true_params)
"""
module TextVisualization

using Printf

export plot_text,
       display_experiment_info,
       display_convergence_summary

"""
    plot_text(degrees::Vector, values::Vector, title::String, ylabel::String)

Create ASCII text-based visualization with:
1. Data table showing degree vs value
2. Simple ASCII trend plot (normalized 0-50 scale)
3. Min/max range display

Handles NaN values gracefully.
"""
function plot_text(degrees::Vector, values::Vector, title::String, ylabel::String)
    println("\n" * "="^70)
    println(title)
    println("="^70)
    println()

    if isempty(degrees)
        println("  (no data)")
        return
    end

    # Print table
    @printf("%-10s | %s\n", "Degree", ylabel)
    println("-"^40)
    for (d, v) in zip(degrees, values)
        if isnan(v)
            @printf("%-10d | %s\n", d, "N/A")
        else
            @printf("%-10d | %.6e\n", d, v)
        end
    end

    # Simple ASCII plot if we have numeric data
    valid_indices = findall(!isnan, values)
    if !isempty(valid_indices)
        println()
        println("Visual trend:")

        valid_degrees = degrees[valid_indices]
        valid_values = values[valid_indices]

        # Normalize to 0-50 scale for ASCII plot
        min_val = minimum(valid_values)
        max_val = maximum(valid_values)
        range_val = max_val - min_val

        for (d, v) in zip(valid_degrees, valid_values)
            if range_val > 0
                normalized = Int(round((v - min_val) / range_val * 50))
            else
                normalized = 0
            end
            @printf("  %2d: %s●\n", d, " "^normalized)
        end

        println()
        @printf("  Min: %.6e    Max: %.6e\n", min_val, max_val)
    end
end

"""
    display_experiment_info(data::Dict, system_info::Union{Dict, Nothing}, true_params::Union{Vector, Nothing})

Display formatted experiment metadata including:
- Experiment ID and timestamp
- System parameters and equilibrium (if available)
- Ground truth parameters for recovery (if available)
- Experiment parameters (domain, sampling, etc.)
"""
function display_experiment_info(data::Dict, system_info::Union{Dict, Nothing}, true_params::Union{Vector, Nothing})
    println("\n" * "="^70)
    println("EXPERIMENT INFORMATION")
    println("="^70)

    if haskey(data, "experiment_id")
        println("Experiment ID: $(data["experiment_id"])")
    end

    if haskey(data, "timestamp")
        println("Timestamp: $(data["timestamp"])")
    end

    # Display system information
    if system_info !== nothing
        println("\nSystem Information:")
        if haskey(system_info, "system_type")
            println("  System Type: $(system_info["system_type"])")
        end
        if haskey(system_info, "system_params")
            println("  System Parameters:")
            for (k, v) in system_info["system_params"]
                println("    $k: $v")
            end
        end
        if haskey(system_info, "known_equilibrium")
            println("  Known Equilibrium: $(system_info["known_equilibrium"])")
        end
    end

    # Display true parameters (ground truth for parameter recovery)
    if true_params !== nothing
        println("\nGround Truth Parameters (target for recovery):")
        param_names = ["α", "β", "γ", "δ"]
        for (i, (name, val)) in enumerate(zip(param_names, true_params))
            println("  $name: $val")
        end
    end

    # Display experiment parameters
    if haskey(data, "parameters")
        params = data["parameters"]
        println("\nExperiment Parameters:")
        for (k, v) in params
            println("  $k: $v")
        end
    elseif haskey(data, "params_dict")
        params = data["params_dict"]
        println("\nExperiment Parameters:")
        for (k, v) in params
            println("  $k: $v")
        end
    end
end

"""
    display_convergence_summary(metrics::NamedTuple, true_params::Union{Vector, Nothing})

Display summary statistics showing best results for:
- L2 approximation error
- Numerical stability (condition number)
- Parameter recovery distance (if true_params available)
"""
function display_convergence_summary(metrics::NamedTuple, true_params::Union{Vector, Nothing})
    println("\n" * "="^70)
    println("SUMMARY")
    println("="^70)
    println()

    if true_params !== nothing
        println("True Parameters (target): $true_params")
        println()
    end

    if !all(isnan, metrics.l2_norms)
        best_l2_idx = argmin(metrics.l2_norms)
        println("Best L2 Norm:")
        @printf("  Degree %d: %.6e\n", metrics.degrees[best_l2_idx], metrics.l2_norms[best_l2_idx])
    end

    if !all(isnan, metrics.condition_numbers)
        best_cond_idx = argmin(metrics.condition_numbers)
        println("\nBest Condition Number:")
        @printf("  Degree %d: %.6e\n", metrics.degrees[best_cond_idx], metrics.condition_numbers[best_cond_idx])
    end

    if true_params !== nothing && !all(isnan, metrics.min_distances)
        best_dist_idx = argmin(metrics.min_distances)
        println("\nClosest to True Parameters:")
        @printf("  Degree %d: %.6e\n", metrics.degrees[best_dist_idx], metrics.min_distances[best_dist_idx])
    end

    println()
end

end # module