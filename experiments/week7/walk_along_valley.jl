using Pkg; Pkg.activate(@__DIR__)

using Revise
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using LinearAlgebra
using TimerOutputs
using Makie
using GLMakie
using ForwardDiff  # For valley walking

#

# Include the valley walking functions from Examples
include("../../Examples/walk_along/valley.jl")

# Test functions for valley walking (from Examples/walk_along/valley.jl)
# We'll use these for demonstration:
# - rosenbrock_valley_3d(x): 3D Rosenbrock with valley structure
# - simple_valley(x): Simple 3D valley function

# For 2D polynomial approximation, let's create a 2D version
function rosenbrock_valley_2d(x)
    """
    2D Rosenbrock function with valley structure:
    f(x,y) = (1-x)² + 100(y-x²)²
    Valley follows: y ≈ x²
    """
    return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
end

# Create a local timer if _TO is not accessible
if !@isdefined(_TO)
    const _TO = TimerOutputs.TimerOutput()
end
reset_timer!(_TO)

const T = Float64

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging

# Configuration for testing different polynomial degrees
base_config = (
    n = 2,                      # Number of parameters to estimate
    p_true = [T[1., 1.]],       # True parameter values (Rosenbrock minimum)
    sample_range = 1.5,         # Larger domain to capture valley structure
    basis = :chebyshev,
    precision = Globtim.RationalPrecision,
    my_eps = 0.02,
    fine_step = 0.01,
    coarse_step = 0.05,
)

# Use the Rosenbrock valley function for demonstration
error_func = rosenbrock_valley_2d

# Test different polynomial degrees and sample sizes
degree_test_configs = [
    (degree = 4,  samples = 50),
    (degree = 6,  samples = 80),
    (degree = 8,  samples = 120),
    (degree = 10, samples = 180),
    (degree = 12, samples = 250),
    (degree = 14, samples = 320),
    (degree = 16, samples = 400),
    (degree = 18, samples = 500),
]

println("\n" * "="^80)
println("TESTING DIFFERENT POLYNOMIAL DEGREES")
println("="^80)

# Results table
results_table = []

for (i, test_config) in enumerate(degree_test_configs)
    println("\n" * "-"^60)
    println("Test $i: Degree = $(test_config.degree), Samples = $(test_config.samples)")
    println("-"^60)

    # Create configuration for this test
    local config = merge(base_config, (
        d = (:one_d_for_all, test_config.degree),
        GN = test_config.samples,
        p_center = [1.0, 1.0],  # Center domain around true minimum for better convergence
    ))

    try
        # Create test input and polynomial approximation
        @timeit _TO "Polynomial approximation deg=$(test_config.degree)" begin
            local TR = Globtim.test_input(
                error_func,
                dim = config.n,
                center = config.p_center,
                sample_range = config.sample_range,
                GN = config.GN
            )
            local pol_cheb = Globtim.Constructor(TR, test_config.degree,
                                         basis = config.basis,
                                         precision = config.precision)
        end

        # Find critical points
        @timeit _TO "Critical point finding deg=$(test_config.degree)" begin
            @polyvar x[1:config.n]
            local solutions = Globtim.solve_polynomial_system(x, config.n, test_config.degree, pol_cheb.coeffs)
            local df_cheb = Globtim.process_crit_pts(solutions, error_func, TR)
        end

        # Analyze convergence to true minimum
        true_min = [1.0, 1.0]
        min_distance_to_true = Inf
        best_critical_point = nothing

        if nrow(df_cheb) > 0
            for row in eachrow(df_cheb)
                point = [row.x1, row.x2]
                distance = norm(point - true_min)
                if distance < min_distance_to_true
                    min_distance_to_true = distance
                    best_critical_point = point
                end
            end
        end

        # Store results
        push!(results_table, (
            degree = test_config.degree,
            samples = test_config.samples,
            n_critical_points = nrow(df_cheb),
            condition_number = pol_cheb.cond_vandermonde,
            l2_error = pol_cheb.nrm,
            min_distance_to_true = min_distance_to_true,
            best_critical_point = best_critical_point,
            critical_points = copy(df_cheb)
        ))

        println("✓ Success: Found $(nrow(df_cheb)) critical points")
        println("  Condition number: $(round(pol_cheb.cond_vandermonde, digits=2))")
        println("  L2 approximation error: $(round(pol_cheb.nrm, digits=8))")
        if best_critical_point !== nothing
            println("  Best critical point: $(round.(best_critical_point, digits=4))")
            println("  Distance to true min [1,1]: $(round(min_distance_to_true, digits=6))")
        end

    catch e
        println("✗ Failed: $e")
        push!(results_table, (
            degree = test_config.degree,
            samples = test_config.samples,
            n_critical_points = 0,
            condition_number = Inf,
            l2_error = Inf,
            min_distance_to_true = Inf,
            best_critical_point = nothing,
            critical_points = DataFrame()
        ))
    end
end

# Print summary table
println("\n" * "="^100)
println("POLYNOMIAL DEGREE COMPARISON TABLE - CONVERGENCE TO TRUE MINIMUM [1,1]")
println("="^100)
println("| Degree | Samples | Crit Pts | Condition # | L2 Error   | Distance to [1,1] | Best Critical Point |")
println("|--------|---------|----------|-------------|------------|-------------------|---------------------|")
for result in results_table
    dist_str = result.min_distance_to_true == Inf ? "    ∞" : lpad(round(result.min_distance_to_true, digits=6), 9)
    point_str = result.best_critical_point === nothing ? "       None" :
                "[$(round(result.best_critical_point[1], digits=3)), $(round(result.best_critical_point[2], digits=3))]"
    println("| $(lpad(result.degree, 6)) | $(lpad(result.samples, 7)) | $(lpad(result.n_critical_points, 8)) | $(lpad(round(result.condition_number, digits=1), 11)) | $(lpad(round(result.l2_error, digits=6), 10)) | $(lpad(dist_str, 17)) | $(rpad(point_str, 19)) |")
end
println("="^100)

# Choose the best configuration (highest degree with reasonable condition number)
local best_config_idx = 0
for (i, result) in enumerate(results_table)
    if result.n_critical_points > 0 && result.condition_number < 1e12
        global best_config_idx = i
    end
end

if best_config_idx > 0
    println("\nUsing configuration $(best_config_idx) for valley walking:")
    best_result = results_table[best_config_idx]
    println("  Degree: $(best_result.degree)")
    println("  Samples: $(best_result.samples)")
    println("  Critical points found: $(best_result.n_critical_points)")

    # Set up the final configuration
    config = merge(base_config, (
        d = (:one_d_for_all, best_result.degree),
        GN = best_result.samples,
        p_center = [base_config.p_true[1][1] + 0.2, base_config.p_true[1][2] - 0.15],
    ))

    df_cheb = best_result.critical_points

    # Recreate polynomial for valley walking
    TR = Globtim.test_input(
        error_func,
        dim = config.n,
        center = config.p_center,
        sample_range = config.sample_range,
        GN = config.GN
    )
    pol_cheb = Globtim.Constructor(TR, best_result.degree,
                                 basis = config.basis,
                                 precision = config.precision)
    @polyvar x[1:config.n]
else
    println("\n⚠️  No suitable configuration found - using fallback")
    config = merge(base_config, (
        d = (:one_d_for_all, 8),
        GN = 120,
        p_center = [base_config.p_true[1][1] + 0.1, base_config.p_true[1][2] - 0.1],
    ))

    # Create fallback polynomial
    TR = Globtim.test_input(
        error_func,
        dim = config.n,
        center = config.p_center,
        sample_range = config.sample_range,
        GN = config.GN
    )
    pol_cheb = Globtim.Constructor(TR, 8,
                                 basis = config.basis,
                                 precision = config.precision)
    @polyvar x[1:config.n]
    solutions = Globtim.solve_polynomial_system(x, config.n, 8, pol_cheb.coeffs)
    df_cheb = Globtim.process_crit_pts(solutions, error_func, TR)
end

@polyvar(x[1:config.n]); # Define polynomial ring

# Sample the error function to create training data
TR = test_input(
    error_func,
    dim = config.n,
    center = config.p_center,
    GN = config.GN,
    sample_range = config.sample_range
);

# Construct polynomial approximation w_d of the error function
pol_cheb = Constructor(
    TR,
    config.d,
    basis = config.basis,
    precision = config.precision,
    verbose = true
)

# Find critical points of w_d using polynomial system solving
real_pts_cheb, (wd_in_std_basis, _sys, _nsols) = solve_polynomial_system(
    x,
    config.n,
    config.d,
    pol_cheb.coeffs;
    basis = pol_cheb.basis,
    return_system = true
)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

@info "" df_cheb

id = "$(chopsuffix(basename(@__FILE__), ".jl"))_simple_function"
filename = "$(id)_valley_walking_demo"
@info "Saving results to file: $(filename)"

# Create images directory if it doesn't exist
mkpath(joinpath(@__DIR__, "images"))

open(joinpath(@__DIR__, "images", "$(filename).txt"), "w") do io
    println(io, "config = ", config, "\n\n")
    println(io, "Condition number of the Vandermonde system: ", pol_cheb.cond_vandermonde)
    println(io, "L2 norm (error of approximation): ", pol_cheb.nrm)
    println(io, "Polynomial system:")
    println(io, "   Number of sols: ", _nsols)
    println(
        io,
        "   Bezout bound: ",
        map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys),
        " which is ",
        prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys))
    )
    println(io, "Critical points found:\n", df_cheb)
    if !isempty(df_cheb)
        println(io, "Number of critical points: ", nrow(df_cheb))
    else
        println(io, "No critical points found.")
    end
    println(io, _TO)
end

println(_TO)

# ============================================================================
# VALLEY WALKING INTEGRATION
# ============================================================================

# Enhanced valley walking function with gradient descent fallback
function enhanced_valley_walk(f, x0; n_steps = 15, step_size = 0.01, ε_null = 1e-6,
                              gradient_step_size = 0.005, rank_deficiency_threshold = 1e-6)
    """
    Enhanced valley walking that combines:
    1. Valley walking when Hessian is nearly rank deficient (has small eigenvalues)
    2. Gradient descent when Hessian is well-conditioned
    """
    # Initialize storage
    points = [copy(x0)]
    eigenvalues = Float64[]
    f_values = [f(x0)]
    step_types = String[]  # Track whether we took valley or gradient steps

    x = copy(x0)
    n = length(x0)

    for step in 1:n_steps
        # Compute gradient and Hessian using ForwardDiff
        g = ForwardDiff.gradient(f, x)
        H = ForwardDiff.hessian(f, x)

        # Eigendecomposition to analyze Hessian structure
        λ, V = eigen(H)
        min_eigenval = minimum(abs.(λ))
        push!(eigenvalues, min_eigenval)

        # Decide strategy based on Hessian conditioning
        if min_eigenval < rank_deficiency_threshold
            # VALLEY WALKING: Hessian is nearly rank deficient
            step_types = push!(step_types, "valley")

            # Identify valley directions (null/near-null space)
            valley_mask = abs.(λ) .< ε_null
            valley_indices = findall(valley_mask)

            if isempty(valley_indices)
                # Use direction of smallest eigenvalue
                valley_indices = [argmin(abs.(λ))]
            end

            # Get valley tangent space
            V_valley = V[:, valley_indices]

            # Choose direction in valley
            g_valley = V_valley' * g
            if norm(g_valley) > 1e-10
                # Move down gradient within valley
                direction_valley = -g_valley / norm(g_valley)
            else
                # Random direction in valley if gradient is orthogonal
                direction_valley = randn(length(valley_indices))
                direction_valley = direction_valley / norm(direction_valley)
            end

            # Convert back to ambient space
            direction = V_valley * direction_valley

            # Take valley step
            x_new = x + step_size * direction

            # Project back to valley using Newton steps in normal directions
            for proj_iter in 1:3
                g_proj = ForwardDiff.gradient(f, x_new)
                H_proj = ForwardDiff.hessian(f, x_new)
                λ_proj, V_proj = eigen(H_proj)

                # Identify normal directions (high curvature)
                normal_mask = abs.(λ_proj) .> ε_null
                if !any(normal_mask)
                    break  # Already in valley
                end

                # Project gradient onto normal space
                V_normal = V_proj[:, normal_mask]
                λ_normal = λ_proj[normal_mask]
                g_normal = V_normal' * g_proj

                # Newton step in normal directions only
                δ = -V_normal * (g_normal ./ (λ_normal .+ 1e-10))

                # Update with line search
                α = 1.0
                f_current = f(x_new)
                for ls in 1:5
                    x_test = x_new + α * δ
                    if f(x_test) < f_current
                        x_new = x_test
                        break
                    end
                    α *= 0.5
                end

                # Check convergence
                if norm(α * δ) < 1e-10
                    break
                end
            end

        else
            # GRADIENT DESCENT: Hessian is well-conditioned
            step_types = push!(step_types, "gradient")

            # Simple gradient descent step with line search
            if norm(g) > 1e-12
                direction = -g / norm(g)

                # Line search for step size
                α = gradient_step_size
                f_current = f(x)
                x_new = x

                for ls in 1:10
                    x_test = x + α * direction
                    f_test = f(x_test)
                    if f_test < f_current
                        x_new = x_test
                        break
                    end
                    α *= 0.7
                end

                # If no improvement, take small step anyway
                if x_new == x
                    x_new = x + 0.001 * direction
                end
            else
                # Gradient is very small, take tiny random step
                x_new = x + 1e-6 * randn(n)
            end
        end

        # Accept new point
        x = copy(x_new)
        push!(points, copy(x))
        push!(f_values, f(x))

        # Progress info
        println("Step $step ($(step_types[end])): f = $(round(f_values[end], digits=12))")
    end

    return points, eigenvalues, f_values, step_types
end

# Perform valley walking from all critical points
println("\n" * "="^60)
println("VALLEY WALKING FROM CRITICAL POINTS")
println("="^60)

valley_results = []
if !isempty(df_cheb)
    for (i, row) in enumerate(eachrow(df_cheb))
        local x0 = [row.x1, row.x2]
        println("\nStarting enhanced valley walk from critical point $i: $x0")

        try
            local points, eigenvals, f_vals, step_types = enhanced_valley_walk(
                error_func, x0;
                n_steps = 20,
                step_size = 0.015,
                ε_null = 1e-6,
                gradient_step_size = 0.008,
                rank_deficiency_threshold = 1e-5
            )

            push!(valley_results, (
                start_point = x0,
                points = points,
                eigenvalues = eigenvals,
                f_values = f_vals,
                step_types = step_types,
                critical_point_index = i
            ))

            # Count step types
            n_valley = count(s -> s == "valley", step_types)
            n_gradient = count(s -> s == "gradient", step_types)

            println("Enhanced valley walk completed:")
            println("  Total points: $(length(points))")
            println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
            println("  Final f: $(round(f_vals[end], digits=12))")
            println("  Function decrease: $(round(f_vals[1] - f_vals[end], digits=8))")
        catch e
            println("Enhanced valley walk failed from point $x0: $e")
        end
    end
else
    println("No critical points found - cannot perform valley walking")
end

# Individual plots removed - now using integrated visualization below

# ============================================================================
# ENHANCED VALLEY WALKING VISUALIZATION
# ============================================================================

if !isempty(valley_results)
    println("\n" * "="^60)
    println("CREATING ENHANCED VALLEY WALKING VISUALIZATION")
    println("="^60)

    # Create figure with improved layout and styling
    fig = Figure(size = (1400, 700), fontsize = 14)

    # Left panel: 2D level set plot with valley paths
    ax_main = Axis(fig[1, 1],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "Valley Walking on Function Level Sets",
        aspect = DataAspect(),
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )

    # Create high-resolution grid for smooth level sets (matching polynomial domain)
    # Domain: center=[1.0, 1.0], range=1.5, so domain is [-0.5, 2.5] x [-0.5, 2.5]
    x1_range = range(-0.5, 2.5, length=300)
    x2_range = range(-0.5, 2.5, length=300)
    Z = [rosenbrock_valley_2d([x1, x2]) for x2 in x2_range, x1 in x1_range]

    # Use log scale for better visualization of the valley structure
    Z_log = log10.(Z .+ 1e-10)

    # Plot smooth level sets with enhanced color gradient
    heatmap!(ax_main, x1_range, x2_range, Z_log,
             colormap=:plasma, alpha=0.8)

    # Add contour lines for better level set definition
    contour!(ax_main, x1_range, x2_range, Z_log,
             levels=20, color=:white, alpha=0.6, linewidth=0.8)

    # Enhanced path colors for better visibility
    path_colors = [:cyan, :lime, :orange, :magenta, :yellow, :red, :lightblue, :pink]

    # Plot valley walking paths
    for (i, result) in enumerate(valley_results)
        points_matrix = reduce(hcat, result.points)
        x1_path = points_matrix[1, :]
        x2_path = points_matrix[2, :]

        path_color = path_colors[mod1(i, length(path_colors))]

        # Plot path with enhanced styling
        lines!(ax_main, x1_path, x2_path,
               color=path_color, linewidth=5, alpha=0.9)

        # Mark start point (larger, more visible)
        scatter!(ax_main, [x1_path[1]], [x2_path[1]],
                color=path_color, markersize=16, marker=:circle,
                strokecolor=:black, strokewidth=2)

        # Mark end point
        scatter!(ax_main, [x1_path[end]], [x2_path[end]],
                color=path_color, markersize=16, marker=:star4,
                strokecolor=:black, strokewidth=2)

        # Add directional arrows (fewer, cleaner)
        n_arrows = min(4, length(x1_path)-1)
        arrow_indices = round.(Int, range(1, length(x1_path)-1, length=n_arrows))
        for j in arrow_indices
            if j < length(x1_path)
                dx = x1_path[j+1] - x1_path[j]
                dy = x2_path[j+1] - x2_path[j]
                if abs(dx) > 1e-10 || abs(dy) > 1e-10
                    arrows!(ax_main, [x1_path[j]], [x2_path[j]], [dx*0.8], [dy*0.8],
                           color=path_color, arrowsize=12, linewidth=3, alpha=0.8)
                end
            end
        end
    end

    # Plot critical points with enhanced visibility
    if !isempty(df_cheb)
        scatter!(ax_main, df_cheb.x1, df_cheb.x2,
                color=:red, markersize=18, marker=:diamond,
                strokecolor=:white, strokewidth=3)
    end

    # Plot true minimum with enhanced visibility
    scatter!(ax_main, [1.0], [1.0],
            color=:gold, markersize=24, marker=:star5,
            strokecolor=:black, strokewidth=3)

    # Add colorbar with log scale labels
    cb = Colorbar(fig[1, 2],
                  limits=(minimum(Z_log), maximum(Z_log)),
                  colormap=:plasma,
                  label="log₁₀(f(x₁, x₂))",
                  labelsize=14)

    # Right panel: 1D function values with enhanced styling
    ax_f = Axis(fig[1, 3],
        xlabel = "Step Number",
        ylabel = "Function Value f(x)",
        title = "Function Decrease Along Paths",
        yscale = log10,
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )

    # Collect all function values to determine y-axis range
    all_f_values = Float64[]
    for result in valley_results
        append!(all_f_values, result.f_values)
    end

    # Determine appropriate y-axis limits based on actual data
    min_f = minimum(all_f_values)
    max_f = maximum(all_f_values)

    # Use a small buffer for better visualization, but respect the actual data range
    f_range_buffer = (max_f - min_f) * 0.1
    y_min = max(min_f - f_range_buffer, 1e-16)  # Don't go below machine precision for log scale
    y_max = max_f + f_range_buffer

    # Plot function evolution with enhanced styling
    for (i, result) in enumerate(valley_results)
        path_color = path_colors[mod1(i, length(path_colors))]
        steps = 1:length(result.f_values)
        f_vals_safe = max.(result.f_values, 1e-16)

        # Enhanced line plot
        lines!(ax_f, steps, f_vals_safe,
               color=path_color, linewidth=4, alpha=0.9)

        # Enhanced scatter points
        scatter!(ax_f, steps, f_vals_safe,
                color=path_color, markersize=8,
                strokecolor=:white, strokewidth=1)

        # Add path number annotation at start
        text!(ax_f, 1.2, f_vals_safe[1],
              text="Path $i", color=path_color, fontsize=12,
              align=(:left, :center))
    end

    # Set y-axis limits based on actual data
    ylims!(ax_f, y_min, y_max)

    # Add machine precision reference line only if it's within the visible range
    if 1e-15 >= y_min && 1e-15 <= y_max
        hlines!(ax_f, [1e-15], color=:gray, linestyle=:dash, linewidth=2, alpha=0.7)
        text!(ax_f, length(valley_results[1].f_values)*0.7, 1e-15,
              text="Machine Precision", color=:gray, fontsize=11,
              align=(:center, :bottom), offset=(0, 8))
    end

    # Adjust layout for better proportions
    colsize!(fig.layout, 1, Relative(0.45))  # Level set plot
    colsize!(fig.layout, 2, Relative(0.08))  # Colorbar
    colsize!(fig.layout, 3, Relative(0.47))  # Function values plot

    # Add some spacing
    colgap!(fig.layout, 15)

    display(fig)

    # Print summary statistics
    println("\n" * "="^60)
    println("VALLEY WALKING SUMMARY")
    println("="^60)

    for (i, result) in enumerate(valley_results)
        println("Path $i:")
        println("  Start point: $(round.(result.start_point, digits=4))")
        println("  End point: $(round.(result.points[end], digits=4))")
        println("  Initial f: $(round(result.f_values[1], digits=6))")
        println("  Final f: $(round(result.f_values[end], digits=6))")
        println("  Function decrease: $(round(result.f_values[1] - result.f_values[end], digits=6))")
        println("  Path length: $(length(result.points)) points")
        println()
    end

else
    println("No valley walking results to visualize")
end
