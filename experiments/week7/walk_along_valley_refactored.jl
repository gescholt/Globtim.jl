"""
    walk_along_valley_refactored.jl

Refactored valley walking experiment using modular components.
This script demonstrates polynomial approximation of error landscapes
and valley walking optimization.
"""

using Pkg; Pkg.activate(@__DIR__)

using Revise
using Globtim
using DynamicPolynomials
using DataFrames
using HomotopyContinuation
using TimerOutputs
using GLMakie
using Printf

# Include modular components
include("test_functions.jl")
include("valley_walking_utils.jl")
include("polynomial_degree_optimization.jl")
include("valley_walking_tables.jl")
include("valley_walking_visualization.jl")

# ============================================================================
# SETUP
# ============================================================================

# Create timer
const TIMER = TimerOutputs.TimerOutput()
reset_timer!(TIMER)

# Precision type
const T = Float64

# Select objective function
# FUNCTION_NAME = :rosenbrock_2d  # Only has 1 critical point
FUNCTION_NAME = :himmelblau  # Has 4 minima and 5 critical points total
func_info = get_test_function_info(FUNCTION_NAME)
objective_func = func_info.func

# ============================================================================
# CONFIGURATION
# ============================================================================

# Base configuration
base_config = (
    n = 2,                          # Dimensionality (number of variables)
    p_center = [0.0, 0.0],          # Center of sampling domain
    sample_range = 5.0,             # Sampling range: creates [-5, 5] x [-5, 5] domain
    basis = :chebyshev,             # Polynomial basis (Chebyshev for numerical stability)
    precision = Globtim.Float64Precision,  # Float64 precision for speed
    my_eps = 0.02,                  # Epsilon for numerical derivatives (if used)
    fine_step = 0.01,               # Fine step size for optimization
    coarse_step = 0.05,             # Coarse step size for initial search
)

# COMPARISON SETUP: We'll compare two approaches
# Approach A: Approximate f, find critical points, walk on f
# Approach B: Approximate log(f), find critical points, walk on log(f)

println("Setting up comparison between f and log(f) approaches...")

# First, create safe log transformation
println("Finding function range for safe log transformation...")
sample_points = []
for x in range(base_config.p_center[1] - base_config.sample_range,
               base_config.p_center[1] + base_config.sample_range, length=20)
    for y in range(base_config.p_center[2] - base_config.sample_range,
                   base_config.p_center[2] + base_config.sample_range, length=20)
        push!(sample_points, [x, y])
    end
end

sample_values = [objective_func(p) for p in sample_points]
min_val = minimum(sample_values)
max_val = maximum(sample_values)

println("Function range: [$min_val, $max_val]")

# Create safe log-transformed version
if min_val <= 0
    shift = abs(min_val) + 1.0  # Ensure all values are > 1
    println("Shifting function by $shift to ensure positivity")
    log_objective_func = x -> log10(objective_func(x) + shift)
else
    # Function is already positive, just add small epsilon
    log_objective_func = x -> log10(objective_func(x) + 1e-12)
end

# Test the transformation
test_point = base_config.p_center
orig_val = objective_func(test_point)
log_val = log_objective_func(test_point)
println("Test at center point $test_point:")
println("  Original f: $orig_val")
println("  Log-transformed log(f): $log_val")

# Define both approaches
original_objective_func = objective_func  # For visualization
approach_A_func = objective_func          # Approximate f, walk on f
approach_B_func = log_objective_func      # Approximate log(f), walk on log(f)

true_minima = func_info.true_minima

println("\n" * "="^80)
println("VALLEY WALKING EXPERIMENT: $(func_info.description)")
println("True minimum/minima: ", true_minima)
println("="^80)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Base configuration
# Center the domain at (0, 0) with range 5 to get [-5, 5] x [-5, 5] sampling domain
# This ensures good coverage of the visualization domain
base_config = (
    n = 2,                          # Dimensionality (number of variables)
    p_center = [0.0, 0.0],          # Center of sampling domain
    sample_range = 5.0,             # Sampling range: creates [-5, 5] x [-5, 5] domain
    basis = :chebyshev,             # Polynomial basis (Chebyshev for numerical stability)
    precision = Globtim.Float64Precision,  # Float64 precision for speed
    my_eps = 0.02,                  # Epsilon for numerical derivatives (if used)
    fine_step = 0.01,               # Fine step size for optimization
    coarse_step = 0.05,             # Coarse step size for initial search
)

# Create degree test configurations
# Testing polynomial degrees 4, 6, 8 with 100 sample points (10x10 grid)
# Lower degrees may miss features; higher degrees risk overfitting and numerical instability
degree_configs = create_degree_test_configs(
    min_degree=18,        # Minimum polynomial degree (degree 2 is just quadratic)
    max_degree=18,        # Maximum polynomial degree (reduced from 14 for clarity)
    degree_step=2,       # Test every other degree: 4, 6, 8
    fixed_samples=200    # Use 100 samples (10x10 grid) for all degrees
)

# Calculate domain bounds from base_config for visualization
# The polynomial approximation domain is centered at p_center with range sample_range
# This creates a box: [p_center[i] - sample_range, p_center[i] + sample_range] for each dimension
domain_bounds = (
    base_config.p_center[1] - base_config.sample_range,  # x_min
    base_config.p_center[1] + base_config.sample_range,  # x_max
    base_config.p_center[2] - base_config.sample_range,  # y_min
    base_config.p_center[2] + base_config.sample_range   # y_max
)

# ============================================================================
# POLYNOMIAL DEGREE OPTIMIZATION
# ============================================================================

println("\n" * "="^80)
println("TESTING BOTH APPROACHES: f vs log(f)")
println("="^80)

# APPROACH A: Test polynomial degrees on original function f
println("\nAPPROACH A: Approximating f, finding critical points of polynomial(f)")
println("-"^60)
@timeit TIMER "Approach A: f polynomial testing" begin
    test_results_A = test_polynomial_degrees(
        approach_A_func,
        base_config,
        degree_configs,
        timer=TIMER,
        verbose=true
    )
end

# APPROACH B: Test polynomial degrees on log-transformed function
println("\nAPPROACH B: Approximating log(f), finding critical points of polynomial(log(f))")
println("-"^60)
@timeit TIMER "Approach B: log(f) polynomial testing" begin
    test_results_B = test_polynomial_degrees(
        approach_B_func,
        base_config,
        degree_configs,
        timer=TIMER,
        verbose=true
    )
end

# Collect critical points from both approaches
all_critical_points_A = Dict{Int, DataFrame}()  # Critical points from approximating f
all_critical_points_B = Dict{Int, DataFrame}()  # Critical points from approximating log(f)

println("\nAPPROACH A RESULTS (approximating f):")
for result in test_results_A
    if haskey(result, :critical_points) && !isnothing(result.critical_points)
        all_critical_points_A[result.degree] = result.critical_points
        println("  Degree $(result.degree): $(nrow(result.critical_points)) critical points")
    end
end

println("\nAPPROACH B RESULTS (approximating log(f)):")
for result in test_results_B
    if haskey(result, :critical_points) && !isnothing(result.critical_points)
        all_critical_points_B[result.degree] = result.critical_points
        println("  Degree $(result.degree): $(nrow(result.critical_points)) critical points")
    end
end

# Display comparison tables for both approaches
println("\nAPPROACH A COMPARISON TABLE (approximating f):")
display_polynomial_comparison_table(test_results_A)

println("\nAPPROACH B COMPARISON TABLE (approximating log(f)):")
display_polynomial_comparison_table(test_results_B)

# Select best configurations from both approaches
best_config_A, best_idx_A = select_best_configuration(test_results_A)
best_config_B, best_idx_B = select_best_configuration(test_results_B)

println("\nSelected configurations:")
if best_config_A !== nothing
    println("✅ Approach A: degree $(best_config_A.degree), $(nrow(best_config_A.critical_points)) critical points")
else
    println("❌ Approach A: No suitable configuration found")
end

if best_config_B !== nothing
    println("✅ Approach B: degree $(best_config_B.degree), $(nrow(best_config_B.critical_points)) critical points")
else
    println("❌ Approach B: No suitable configuration found")
end

# Use the configurations directly (no need to search again)
# The best_config_A and best_config_B already contain the critical points

# We'll use the critical points from both approaches directly
# No need for a single fallback configuration since we have approach-specific ones

# ============================================================================
# CRITICAL POINTS ANALYSIS FOR BOTH APPROACHES
# ============================================================================

println("\n" * "="^80)
println("CRITICAL POINTS ANALYSIS")
println("="^80)

# Display critical points from both approaches
if best_config_A !== nothing && haskey(best_config_A, :critical_points)
    println("\nAPPROACH A: Critical points from polynomial(f)")
    println("Found $(nrow(best_config_A.critical_points)) critical points")
    display_critical_points_table(best_config_A.critical_points, max_rows=50)
end

if best_config_B !== nothing && haskey(best_config_B, :critical_points)
    println("\nAPPROACH B: Critical points from polynomial(log(f))")
    println("Found $(nrow(best_config_B.critical_points)) critical points")
    display_critical_points_table(best_config_B.critical_points, max_rows=50)
end

# For visualization, use the best critical point from approach A as reference
true_minimum_for_plot = nothing
if best_config_A !== nothing && haskey(best_config_A, :critical_points) && !isempty(best_config_A.critical_points)
    best_idx = argmin(best_config_A.critical_points.z)
    best_row = best_config_A.critical_points[best_idx, :]
    true_minimum_for_plot = [best_row.x1, best_row.x2]
    println("\nUsing best critical point from Approach A as reference: $(format_point(true_minimum_for_plot))")
    println("Function value: $(@sprintf("%.6e", best_row.z))")
elseif best_config_B !== nothing && haskey(best_config_B, :critical_points) && !isempty(best_config_B.critical_points)
    best_idx = argmin(best_config_B.critical_points.z)
    best_row = best_config_B.critical_points[best_idx, :]
    true_minimum_for_plot = [best_row.x1, best_row.x2]
    println("\nUsing best critical point from Approach B as reference: $(format_point(true_minimum_for_plot))")
else
    # Fallback to hardcoded value
    true_minimum_for_plot = isa(true_minima[1], Vector) ? true_minima[1] : true_minima
    println("\nNo critical points found, using default: $(format_point(true_minimum_for_plot))")
end

# ============================================================================
# VALLEY WALKING FROM BOTH APPROACHES
# ============================================================================

println("\n" * "="^80)
println("VALLEY WALKING COMPARISON: f vs log(f)")
println("="^80)

# Function to perform valley walking from critical points with specified objective function
function perform_valley_walks_with_func(critical_points_df, objective_function, label, approach_name)
    results = []

    if !isempty(critical_points_df)
        # Use ALL critical points
        starting_points = [[row.x1, row.x2] for row in eachrow(critical_points_df)]

        println("\n$label: Starting valley walking from $(length(starting_points)) critical points")

        for (i, x0) in enumerate(starting_points)
            println("  Starting valley walk from point $i: $(format_point(x0))")

            try
                @timeit TIMER "Valley walk $label $i" begin
                    # Use the improved valley walking algorithm
                    points, eigenvals, f_vals, step_types = enhanced_valley_walk_no_oscillation(
                        objective_function, x0;  # Use the specified objective function
                        n_steps = 100,              # Reduced steps for comparison
                        step_size = 0.015,
                        ε_null = 1e-6,
                        gradient_step_size = 0.008,
                        rank_deficiency_threshold = 1e-5,
                        gradient_norm_tolerance = 1e-6,
                        momentum_factor = 0.3,
                        oscillation_threshold = 3,
                        min_progress_threshold = 1e-8,
                        verbose = false             # Reduced verbosity for comparison
                    )
                end

                push!(results, (
                    start_point = x0,
                    points = points,
                    eigenvalues = eigenvals,
                    f_values = f_vals,
                    step_types = step_types,
                    critical_point_index = i,
                    source = label,
                    approach = approach_name,
                    objective_function = objective_function
                ))

                # Quick summary
                n_valley = count(s -> s == "valley", step_types)
                n_gradient = count(s -> s == "gradient", step_types)
                println("    Completed: $(length(points)) points, $n_valley valley steps, $n_gradient gradient steps")

            catch e
                println("    Failed: $e")
            end
        end
    else
        println("$label: No critical points found - cannot perform valley walking")
    end

    return results
end

# Perform valley walking for both approaches using the selected degree
valley_results_A = []
valley_results_B = []

if best_config_A !== nothing && haskey(best_config_A, :critical_points)
    println("\nAPPROACH A: Valley walking on f using critical points from polynomial(f)")
    valley_results_A = perform_valley_walks_with_func(
        best_config_A.critical_points,
        approach_A_func,  # Walk on original function f
        "Approach A (f)",
        "A"
    )
end

if best_config_B !== nothing && haskey(best_config_B, :critical_points)
    println("\nAPPROACH B: Valley walking on log(f) using critical points from polynomial(log(f))")
    valley_results_B = perform_valley_walks_with_func(
        best_config_B.critical_points,
        approach_B_func,  # Walk on log-transformed function
        "Approach B (log(f))",
        "B"
    )
end

# Combine results for visualization
valley_results = vcat(valley_results_A, valley_results_B)

# ============================================================================
# VISUALIZATION: COMPARISON ON LOG(F) LEVEL SETS
# ============================================================================

if !isempty(valley_results)
    println("\n" * "="^80)
    println("CREATING COMPARISON VISUALIZATION")
    println("="^80)

    # Create a single level set plot of log(f) showing both approaches
    @timeit TIMER "Creating comparison visualization" begin
        # Create figure with single axis for log(f) level sets
        fig = Figure(size = (1200, 800))
        ax = Axis(fig[1, 1],
                 title = "Valley Walking Comparison: f vs log(f) approaches on log(f) level sets",
                 xlabel = "x₁",
                 ylabel = "x₂")

        # Plot level sets of log(f) as background
        x_range = range(domain_bounds[1], domain_bounds[2], length=100)
        y_range = range(domain_bounds[3], domain_bounds[4], length=100)

        # Create grid for level sets
        X = [x for x in x_range, y in y_range]
        Y = [y for x in x_range, y in y_range]
        Z_log = [log_objective_func([x, y]) for x in x_range, y in y_range]

        # Plot level sets of log(f)
        contour!(ax, x_range, y_range, Z_log,
                levels = 20,
                colormap = :grays,
                alpha = 0.6)

        # Plot critical points from both approaches with different colors
        if best_config_A !== nothing && haskey(best_config_A, :critical_points)
            cp_A = best_config_A.critical_points
            scatter!(ax, cp_A.x1, cp_A.x2,
                    color = :red,
                    markersize = 15,
                    marker = :circle,
                    label = "Critical points from polynomial(f) - $(nrow(cp_A)) pts")

            # Add numbers to critical points A
            for (i, row) in enumerate(eachrow(cp_A))
                text!(ax, row.x1, row.x2,
                     text = "A$i",
                     color = :red,
                     fontsize = 10,
                     align = (:center, :bottom),
                     offset = (0, 5))
            end
        end

        if best_config_B !== nothing && haskey(best_config_B, :critical_points)
            cp_B = best_config_B.critical_points
            scatter!(ax, cp_B.x1, cp_B.x2,
                    color = :blue,
                    markersize = 15,
                    marker = :diamond,
                    label = "Critical points from polynomial(log(f)) - $(nrow(cp_B)) pts")

            # Add numbers to critical points B
            for (i, row) in enumerate(eachrow(cp_B))
                text!(ax, row.x1, row.x2,
                     text = "B$i",
                     color = :blue,
                     fontsize = 10,
                     align = (:center, :top),
                     offset = (0, -5))
            end
        end

        # Plot valley walking paths from both approaches
        for result in valley_results
            if result.approach == "A"
                # Approach A paths in red tones
                path_points = result.points
                xs = [p[1] for p in path_points]
                ys = [p[2] for p in path_points]
                lines!(ax, xs, ys,
                      color = (:red, 0.7),
                      linewidth = 2,
                      linestyle = :solid)
                # Mark start point
                scatter!(ax, [xs[1]], [ys[1]],
                        color = :red,
                        markersize = 8,
                        marker = :star5)
            elseif result.approach == "B"
                # Approach B paths in blue tones
                path_points = result.points
                xs = [p[1] for p in path_points]
                ys = [p[2] for p in path_points]
                lines!(ax, xs, ys,
                      color = (:blue, 0.7),
                      linewidth = 2,
                      linestyle = :dash)
                # Mark start point
                scatter!(ax, [xs[1]], [ys[1]],
                        color = :blue,
                        markersize = 8,
                        marker = :star5)
            end
        end

        # Add legend
        axislegend(ax, position = :rt)

        # Set axis limits
        xlims!(ax, domain_bounds[1], domain_bounds[2])
        ylims!(ax, domain_bounds[3], domain_bounds[4])
    end

    # Display the comparison figure
    display(fig)
end

# ============================================================================
# SUMMARY TABLES AND STATISTICS
# ============================================================================

println("\n" * "="^80)
println("FINAL SUMMARY")
println("="^80)

# Critical points summary for both approaches
println("\n" * "="^80)
println("CRITICAL POINTS COMPARISON SUMMARY")
println("="^80)

println("\nAPPROACH A: Critical points from polynomial approximation of f")
println("-"^60)
if best_config_A !== nothing && haskey(best_config_A, :critical_points)
    cp_A = best_config_A.critical_points
    println("Found $(nrow(cp_A)) critical points")
    sorted_cp_A = sort(cp_A, :z)
    for (i, row) in enumerate(eachrow(sorted_cp_A))
        if i <= 5
            println("  A$i: [$(round(row.x1, digits=4)), $(round(row.x2, digits=4))] → f = $(round(row.z, digits=8))")
        elseif i == 6 && nrow(sorted_cp_A) > 5
            println("  ... and $(nrow(sorted_cp_A) - 5) more points")
            break
        end
    end
else
    println("No critical points found for Approach A")
end

println("\nAPPROACH B: Critical points from polynomial approximation of log(f)")
println("-"^60)
if best_config_B !== nothing && haskey(best_config_B, :critical_points)
    cp_B = best_config_B.critical_points
    println("Found $(nrow(cp_B)) critical points")
    sorted_cp_B = sort(cp_B, :z)
    for (i, row) in enumerate(eachrow(sorted_cp_B))
        if i <= 5
            println("  B$i: [$(round(row.x1, digits=4)), $(round(row.x2, digits=4))] → log(f) = $(round(row.z, digits=8))")
        elseif i == 6 && nrow(sorted_cp_B) > 5
            println("  ... and $(nrow(sorted_cp_B) - 5) more points")
            break
        end
    end
else
    println("No critical points found for Approach B")
end

total_A = best_config_A !== nothing && haskey(best_config_A, :critical_points) ? nrow(best_config_A.critical_points) : 0
total_B = best_config_B !== nothing && haskey(best_config_B, :critical_points) ? nrow(best_config_B.critical_points) : 0
println("\nTOTAL: Approach A = $total_A points, Approach B = $total_B points")

# Valley walking summary
if !isempty(valley_results)
    println("\n" * "="^80)
    println("VALLEY WALKING SUMMARY")
    println("="^80)
    display_valley_walking_summary(valley_results)

    # Create summary statistics
    summary_stats = create_summary_statistics(valley_results)
    println("\nSummary Statistics:")
    println(summary_stats)
end

# Skip saving results to file

# Display timer results
println("\n" * "="^80)
println("PERFORMANCE TIMING")
println("="^80)
println(TIMER)

# ============================================================================
# EXPANDED DOMAIN ANALYSIS (Optional)
# ============================================================================

println("\n" * "="^80)
println("EXPANDED DOMAIN ANALYSIS")
println("="^80)

# Test with expanded domain
expanded_config = expand_domain_for_approximation(base_config, 2.0)
println("Testing with expanded domain: sample_range = $(expanded_config.sample_range)")

# You can uncomment the following to test with expanded domain:
# expanded_results = test_polynomial_degrees(
#     objective_func,
#     expanded_config,
#     [DegreeTestConfig(best_config.degree, best_config.samples)],
#     verbose=false
# )
# display_polynomial_comparison_table(expanded_results)