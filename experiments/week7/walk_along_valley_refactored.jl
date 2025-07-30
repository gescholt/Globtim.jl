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
println("TESTING DIFFERENT POLYNOMIAL DEGREES")
println("="^80)

# Test different polynomial degrees
@timeit TIMER "Polynomial degree testing" begin
    test_results = test_polynomial_degrees(
        objective_func, 
        base_config, 
        degree_configs,
        timer=TIMER,
        verbose=true
    )
end

# Collect all critical points from all polynomial degrees for visualization
all_critical_points_by_degree = Dict{Int, DataFrame}()
for result in test_results
    if haskey(result, :critical_points) && !isnothing(result.critical_points)
        all_critical_points_by_degree[result.degree] = result.critical_points
        println("Degree $(result.degree): $(nrow(result.critical_points)) critical points")
    end
end

# Display comparison table
display_polynomial_comparison_table(test_results)

# Analyze convergence to true minimum
# For functions with multiple minima, use the first one as reference
true_minimum_ref = if isa(true_minima[1], Vector)
    true_minima[1]  # First minimum for multi-minima functions
else
    true_minima  # Single minimum
end
convergence_results = analyze_convergence_to_minimum(test_results, true_minimum_ref)
display_convergence_table(convergence_results, true_minimum_ref)

# Select best configuration
best_config, best_idx = select_best_configuration(test_results)

if best_config === nothing
    println("\n⚠️  No suitable configuration found - using fallback")
    # Create fallback configuration
    config = merge(base_config, (
        d = (:one_d_for_all, 8),
        GN = 120,
    ))
    
    # Manually create polynomial approximation using direct Globtim calls
    degree = 8
    
    # Step 1: Create test input
    TR = Globtim.test_input(
        objective_func,
        dim = config.n,
        center = config.p_center,
        sample_range = config.sample_range,
        GN = config.GN,
        tolerance = nothing  # Disable automatic degree increase
    )
    
    # Step 2: Construct polynomial
    polynomial = Globtim.Constructor(TR, degree,
                                   basis = config.basis,
                                   precision = config.precision)
    
    # Step 3: Find critical points
    @polyvar x[1:config.n]
    solutions = Globtim.solve_polynomial_system(
        x, config.n, degree, polynomial.coeffs;
        basis = polynomial.basis,
        precision = polynomial.precision,
        normalized = config.basis == :legendre,
        power_of_two_denom = polynomial.power_of_two_denom
    )
    
    # Step 4: Process critical points
    critical_points_df = Globtim.process_crit_pts(solutions, objective_func, TR)
else
    println("\nSelected configuration: Degree $(best_config.degree) with $(best_config.samples) samples")
    
    # Use best configuration
    config = merge(base_config, (
        d = (:one_d_for_all, best_config.degree),
        GN = best_config.samples,
    ))
    
    polynomial = best_config.polynomial
    critical_points_df = best_config.critical_points
end

# ============================================================================
# CRITICAL POINTS ANALYSIS
# ============================================================================

println("\n" * "="^80)
println("CRITICAL POINTS ANALYSIS")
println("="^80)

# Display critical points table (show all critical points)
display_critical_points_table(critical_points_df, max_rows=20)

# Find best critical point (with smallest function value) using direct DataFrame operation
if !isempty(critical_points_df)
    best_idx = argmin(critical_points_df.z)
    best_row = critical_points_df[best_idx, :]
    n_dims = count(name -> startswith(String(name), "x"), names(critical_points_df))
    best_critical_point = [best_row[Symbol("x$i")] for i in 1:n_dims]
    best_f_value = best_row.z
else
    best_critical_point = nothing
    best_f_value = Inf
end

# Check if we have refined critical points
has_refined = best_config !== nothing && 
              haskey(best_config, :critical_points_refined) && 
              !isnothing(best_config.critical_points_refined)

# Use the best refined critical point as the true minimum for plotting
# If refined points exist, use the best one; otherwise use the best raw critical point
true_minimum_for_plot = nothing
if has_refined && !isempty(best_config.critical_points_refined)
    # Find the best refined critical point
    sorted_refined = sort(best_config.critical_points_refined, :z)
    true_minimum_for_plot = [sorted_refined[1, :x1], sorted_refined[1, :x2]]
    println("\nUsing best refined critical point as true minimum: $(format_point(true_minimum_for_plot))")
    println("Function value: $(@sprintf("%.6e", sorted_refined[1, :z]))")
elseif best_critical_point !== nothing
    true_minimum_for_plot = best_critical_point
    println("\nUsing best raw critical point as true minimum: $(format_point(true_minimum_for_plot))")
    println("Function value: $(@sprintf("%.6e", best_f_value))")
else
    # Fallback to hardcoded value if no critical points found
    true_minimum_for_plot = isa(true_minima[1], Vector) ? true_minima[1] : true_minima
    println("\nNo critical points found, using default: $(format_point(true_minimum_for_plot))")
end

# ============================================================================
# VALLEY WALKING FROM CRITICAL POINTS AND OTHER STARTING POINTS
# ============================================================================

println("\n" * "="^80)
println("VALLEY WALKING FROM MULTIPLE STARTING POINTS")
println("="^80)

# Initialize results storage for different starting points
valley_results_by_degree = Dict{Int, Vector}()  # Store results by polynomial degree

# Function to perform valley walking from a set of critical points
function perform_valley_walks(critical_points_df, label)
    results = []
    
    if !isempty(critical_points_df)
        # Use ALL critical points (not just top N)
        n_start_points = nrow(critical_points_df)  # Use all critical points
        sorted_df = sort(critical_points_df, :z)
        starting_points = [[row.x1, row.x2] for row in eachrow(sorted_df[1:n_start_points, :])]
        
        println("\n$label: Starting valley walking from $(length(starting_points)) critical points")
        
        for (i, x0) in enumerate(starting_points)
            println("  Starting valley walk from point $i: $(format_point(x0))")
            
            try
                @timeit TIMER "Valley walk $label $i" begin
                    points, eigenvals, f_vals, step_types = enhanced_valley_walk(
                        objective_func, x0;
                        n_steps = 200,              # Maximum number of steps in the walk
                        step_size = 0.015,          # Step size for valley walking (when Hessian is rank-deficient)
                        ε_null = 1e-6,              # Threshold for identifying null space of Hessian
                        gradient_step_size = 0.008, # Step size for gradient descent (when Hessian is well-conditioned)
                        rank_deficiency_threshold = 1e-5,  # Threshold for detecting rank deficiency in Hessian
                        gradient_norm_tolerance = 1e-6,    # Threshold for gradient norm to switch strategies
                        verbose = true              # Show detailed output during walking
                    )
                end
                
                push!(results, (
                    start_point = x0,
                    points = points,
                    eigenvalues = eigenvals,
                    f_values = f_vals,
                    step_types = step_types,
                    critical_point_index = i,
                    source = label
                ))
                
                # Quick summary
                n_valley = count(s -> s == "valley", step_types)
                n_gradient = count(s -> s == "gradient", step_types)
                println("    Completed: $(length(points)) points, $n_valley valley steps, $n_gradient gradient steps")
                println("    Function decrease: $(f_vals[1]) → $(f_vals[end])")
                
            catch e
                println("    Failed: $e")
            end
        end
    else
        println("$label: No critical points found - cannot perform valley walking")
    end
    
    return results
end

# Perform valley walking from critical points of each polynomial degree
for (degree, cp_df) in all_critical_points_by_degree
    degree_results = perform_valley_walks(cp_df, "Degree $degree critical points")
    
    # Add degree information to each result
    for result in degree_results
        result = merge(result, (degree = degree,))
    end
    
    valley_results_by_degree[degree] = degree_results
end

# Removed test points - only using critical points from polynomial approximation

# Combine all results for compatibility with existing code
valley_results = []
for (degree, degree_results) in valley_results_by_degree
    for result in degree_results
        # Add degree and source information
        result_with_degree = merge(result, (degree = degree, source = "Degree $degree"))
        push!(valley_results, result_with_degree)
    end
end
# No test point results to add

# ============================================================================
# VISUALIZATION
# ============================================================================

if !isempty(valley_results)
    println("\n" * "="^80)
    println("CREATING VISUALIZATIONS")
    println("="^80)
    
    # Create the visualization showing all paths (raw and refined)
    @timeit TIMER "Creating visualization" begin
        # Create the simple visualization with all paths
        fig = plot_valley_walk_simple(
            valley_results,
            objective_func,
            domain_bounds,
            fig_size = (2000, 500),
            show_true_minimum = true_minimum_for_plot,
            path_index = :all,  # Show all paths
            colormap = :viridis,
            use_log_scale = true,
            raw_color = :red,       # Red for raw critical points
            refined_color = :blue,   # Blue for refined critical points
            degree_colors = Dict(4 => :red, 6 => :blue, 8 => :purple, 14 => :green, 18 => :orange)
        )
        
        # Create the visualization with approximation error
        # Use the best polynomial from our testing
        if best_config !== nothing && haskey(best_config, :polynomial) && haskey(best_config, :test_input)
            fig_with_error = plot_valley_walk_with_error(
                valley_results,
                objective_func,
                best_config.polynomial,
                best_config.test_input,
                domain_bounds,
                fig_size = (1800, 500),
                show_true_minimum = true_minimum_for_plot,
                path_index = :all,
                colormap = :viridis,
                use_log_scale = true,
                error_use_log_scale = true,
                degree_colors = Dict(4 => :red, 6 => :blue, 8 => :purple)
            )
        elseif !isnothing(polynomial)
            # Fallback to using the polynomial variable if best_config failed
            # TR is the global test_input we created at the beginning
            fig_with_error = plot_valley_walk_with_error(
                valley_results,
                objective_func,
                polynomial,
                TR,
                domain_bounds,
                fig_size = (1800, 500),
                show_true_minimum = true_minimum_for_plot,
                path_index = :all,
                colormap = :viridis,
                use_log_scale = true,
                error_use_log_scale = true,
                degree_colors = Dict(4 => :red, 6 => :blue, 8 => :purple)
            )
        end
        
        # Add critical points to BOTH level set plots
        # Get axes by iterating through figure content to find Axis objects
        axes = [c for c in fig.content if isa(c, Axis)]
        ax_level_linear = axes[1]  # Linear scale level set axis
        ax_level_log = axes[2]     # Log scale level set axis
        
        # Define degree colors to match path colors
        degree_color_map = Dict(4 => :red, 6 => :blue, 8 => :purple, 14 => :green, 18 => :orange)
        
        # PLOT RAW CRITICAL POINTS on BOTH axes
        # Plot all raw critical points from all polynomial degrees
        for (degree, cp_df) in all_critical_points_by_degree
            if !isempty(cp_df)
                color = get(degree_color_map, degree, :gray)
                # Plot on linear scale axis
                plot_critical_points!(ax_level_linear, cp_df,
                                    color = color,
                                    markersize = 15,
                                    marker = :circle,
                                    label = "Raw critical points (deg $degree)")
                # Plot on log scale axis
                plot_critical_points!(ax_level_log, cp_df,
                                    color = color,
                                    markersize = 15,
                                    marker = :circle,
                                    label = "Raw critical points (deg $degree)")
                println("Plotted $(nrow(cp_df)) raw critical points for degree $degree")
            end
        end
        
        # Collect all refined critical points from all degrees
        all_refined_points = DataFrame()
        for result in test_results
            if haskey(result, :critical_points_refined) && !isnothing(result.critical_points_refined)
                if !isempty(result.critical_points_refined)
                    println("Debug: Found refined points for degree $(result.degree)")
                    println("  Columns: ", names(result.critical_points_refined))
                    # Filter to only the best (minima) from each degree
                    # Check if critical_point_type column exists, otherwise use all points
                    if "critical_point_type" in names(result.critical_points_refined)
                        unique_types = unique(result.critical_points_refined.critical_point_type)
                        println("  Unique critical point types: ", unique_types)
                        # Filter for minima (critical_point_type is a symbol)
                        minima_df = result.critical_points_refined[
                            result.critical_points_refined.critical_point_type .== :minimum, :]
                    else
                        # If no type info, use points with low function values (the 4 true minima)
                        local sorted_refined = sort(result.critical_points_refined, :z)
                        minima_df = sorted_refined[1:min(4, nrow(sorted_refined)), :]
                    end
                    if !isempty(minima_df)
                        println("  Adding $(nrow(minima_df)) refined minima")
                        append!(all_refined_points, minima_df)
                    end
                end
            end
        end
        
        # Plot all refined/optimized critical points as black stars on BOTH axes
        if !isempty(all_refined_points)
            unique_refined = unique(all_refined_points, [:x1, :x2])
            # Plot on linear scale axis
            plot_critical_points!(ax_level_linear, unique_refined,
                                color = :black, 
                                markersize = 20,
                                marker = :star5,
                                label = "Optimized minima")
            # Plot on log scale axis
            plot_critical_points!(ax_level_log, unique_refined,
                                color = :black, 
                                markersize = 20,
                                marker = :star5,
                                label = "Optimized minima")
        end
    end
    
    # Display only the figure with approximation error
    if @isdefined(fig_with_error)
        display(fig_with_error)
    else
        # Fallback to simple figure if error figure wasn't created
        display(fig)
    end
end

# ============================================================================
# SUMMARY TABLES AND STATISTICS
# ============================================================================

println("\n" * "="^80)
println("FINAL SUMMARY")
println("="^80)

# Valley walking summary
if !isempty(valley_results)
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