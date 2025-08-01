using Pkg; Pkg.activate(@__DIR__)

using Revise
using Globtim
using DynamicPolynomials, DataFrames
using LinearAlgebra
using TimerOutputs
using Makie
using GLMakie
using ForwardDiff

# Include the valley walking functions and test functions
include("../../Examples/walk_along/valley.jl")

# Create a local timer
const _TO = TimerOutputs.TimerOutput()
reset_timer!(_TO)

# Test functions from Examples/walk_along/valley.jl
function simple_2d_valley(x)
    """
    Simple 2D valley: f(x,y) = x² + (y - x²)²
    Valley follows: y ≈ x²
    """
    return x[1]^2 + (x[2] - x[1]^2)^2
end

function quadratic_2d(x)
    """
    Simple quadratic: f(x,y) = (x-1)² + (y-1)²
    Minimum at (1,1)
    """
    return (x[1] - 1)^2 + (x[2] - 1)^2
end

# Enhanced valley walking function with gradient descent fallback
function enhanced_valley_walk(f, x0; n_steps = 15, step_size = 0.02, ε_null = 1e-6, 
                              gradient_step_size = 0.01, rank_deficiency_threshold = 1e-5)
    """
    Enhanced valley walking that combines:
    1. Valley walking when Hessian is nearly rank deficient (has small eigenvalues)
    2. Gradient descent when Hessian is well-conditioned
    """
    points = [copy(x0)]
    eigenvalues = Float64[]
    f_values = [f(x0)]
    step_types = String[]

    x = copy(x0)
    n = length(x0)

    for step in 1:n_steps
        g = ForwardDiff.gradient(f, x)
        H = ForwardDiff.hessian(f, x)
        λ, V = eigen(H)
        min_eigenval = minimum(abs.(λ))
        push!(eigenvalues, min_eigenval)

        if min_eigenval < rank_deficiency_threshold
            # VALLEY WALKING: Hessian is nearly rank deficient
            push!(step_types, "valley")
            
            valley_mask = abs.(λ) .< ε_null
            valley_indices = findall(valley_mask)
            if isempty(valley_indices)
                valley_indices = [argmin(abs.(λ))]
            end

            V_valley = V[:, valley_indices]
            g_valley = V_valley' * g
            if norm(g_valley) > 1e-10
                direction_valley = -g_valley / norm(g_valley)
            else
                direction_valley = randn(length(valley_indices))
                direction_valley = direction_valley / norm(direction_valley)
            end

            direction = V_valley * direction_valley
            x_new = x + step_size * direction
        else
            # GRADIENT DESCENT: Hessian is well-conditioned
            push!(step_types, "gradient")
            
            if norm(g) > 1e-12
                direction = -g / norm(g)
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
                
                if x_new == x
                    x_new = x + 0.001 * direction
                end
            else
                x_new = x + 1e-6 * randn(n)
            end
        end

        x = copy(x_new)
        push!(points, copy(x))
        push!(f_values, f(x))

        println("Step $step ($(step_types[end])): min|λ| = $(round(min_eigenval, digits=8)), f = $(round(f_values[end], digits=12))")
    end

    return points, eigenvalues, f_values, step_types
end

# Integrated visualization function
function create_integrated_visualization(test_func, best_result, points, f_vals, step_types)
    """
    Create integrated visualization showing:
    1. Level set plot with valley walking path
    2. 1D function values along the path
    """

    fig = Figure(size = (1200, 600), fontsize = 14)

    # Left panel: 2D level set plot with valley path
    ax_main = Axis(fig[1, 1],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "$(test_func.name): Valley Walking on Level Sets",
        aspect = DataAspect(),
        titlesize = 16
    )

    # Create high-resolution grid for smooth level sets
    x1_range = range(test_func.center[1] - test_func.range,
                     test_func.center[1] + test_func.range, length=200)
    x2_range = range(test_func.center[2] - test_func.range,
                     test_func.center[2] + test_func.range, length=200)

    Z = [test_func.func([x1, x2]) for x2 in x2_range, x1 in x1_range]
    Z_log = log10.(Z .+ 1e-12)  # Log scale for better visualization

    # Plot smooth level sets
    heatmap!(ax_main, x1_range, x2_range, Z_log,
             colormap=:plasma, alpha=0.8)
    contour!(ax_main, x1_range, x2_range, Z_log,
             levels=15, color=:white, alpha=0.6, linewidth=0.8)

    # Plot valley walking path
    if length(points) > 1
        points_matrix = reduce(hcat, points)
        x1_path = points_matrix[1, :]
        x2_path = points_matrix[2, :]

        # Color path by step type
        valley_indices = findall(s -> s == "valley", step_types)
        gradient_indices = findall(s -> s == "gradient", step_types)

        # Plot path segments
        lines!(ax_main, x1_path, x2_path,
               color=:cyan, linewidth=4, alpha=0.9, label="Path")

        # Mark valley steps
        if !isempty(valley_indices)
            scatter!(ax_main, x1_path[valley_indices.+1], x2_path[valley_indices.+1],
                    color=:lime, markersize=8, marker=:circle, label="Valley Steps")
        end

        # Mark gradient steps
        if !isempty(gradient_indices)
            scatter!(ax_main, x1_path[gradient_indices.+1], x2_path[gradient_indices.+1],
                    color=:orange, markersize=6, marker=:diamond, label="Gradient Steps")
        end

        # Mark start and end
        scatter!(ax_main, [x1_path[1]], [x2_path[1]],
                color=:red, markersize=12, marker=:circle,
                strokecolor=:white, strokewidth=2, label="Start")
        scatter!(ax_main, [x1_path[end]], [x2_path[end]],
                color=:green, markersize=12, marker=:star4,
                strokecolor=:white, strokewidth=2, label="End")
    end

    # Plot critical points
    if nrow(best_result.critical_points) > 0
        scatter!(ax_main, best_result.critical_points.x1, best_result.critical_points.x2,
                color=:yellow, markersize=14, marker=:diamond,
                strokecolor=:black, strokewidth=2, label="Critical Points")
    end

    # Add colorbar
    Colorbar(fig[1, 2], limits=(minimum(Z_log), maximum(Z_log)),
             colormap=:plasma, label="log₁₀(f(x₁, x₂))")

    axislegend(ax_main, position=:lt, backgroundcolor=(:white, 0.8))

    # Right panel: 1D function values
    ax_f = Axis(fig[1, 3],
        xlabel = "Step Number",
        ylabel = "Function Value f(x)",
        title = "Function Decrease Along Path",
        yscale = log10,
        titlesize = 16
    )

    # Plot function evolution
    steps = 1:length(f_vals)
    f_vals_safe = max.(f_vals, 1e-16)

    lines!(ax_f, steps, f_vals_safe, color=:blue, linewidth=3, alpha=0.8)
    scatter!(ax_f, steps, f_vals_safe, color=:blue, markersize=6,
            strokecolor=:white, strokewidth=1)

    # Color code by step type
    for (i, step_type) in enumerate(step_types)
        color = step_type == "valley" ? :lime : :orange
        scatter!(ax_f, [i+1], [f_vals_safe[i+1]], color=color, markersize=8)
    end

    # Adjust layout
    colsize!(fig.layout, 1, Relative(0.45))  # Level set plot
    colsize!(fig.layout, 2, Relative(0.08))  # Colorbar
    colsize!(fig.layout, 3, Relative(0.47))  # Function values plot
    colgap!(fig.layout, 15)

    display(fig)

    return fig
end

# Test different polynomial degrees on simple functions
println("="^80)
println("TESTING POLYNOMIAL DEGREES ON SIMPLE FUNCTIONS")
println("="^80)

test_functions = [
    (name = "Simple 2D Valley", func = simple_2d_valley, center = [0.5, 0.8], range = 0.6),
    (name = "Quadratic 2D", func = quadratic_2d, center = [1.2, 0.8], range = 0.5),
]

degree_configs = [
    (degree = 4, samples = 40),
    (degree = 6, samples = 60),
    (degree = 8, samples = 100),
    (degree = 10, samples = 140),
]

for test_func in test_functions
    println("\n" * "="^60)
    println("TESTING: $(test_func.name)")
    println("="^60)
    
    results_table = []
    
    for config in degree_configs
        println("\nDegree $(config.degree), Samples $(config.samples):")
        
        try
            # Create test input and polynomial approximation
            TR = Globtim.test_input(
                test_func.func,
                dim = 2,
                center = test_func.center,
                sample_range = test_func.range,
                GN = config.samples
            )
            pol = Globtim.Constructor(TR, config.degree, basis = :chebyshev)
            
            # Find critical points
            @polyvar x[1:2]
            solutions = Globtim.solve_polynomial_system(x, 2, config.degree, pol.coeffs)
            df_crit = Globtim.process_crit_pts(solutions, test_func.func, TR)
            
            push!(results_table, (
                degree = config.degree,
                samples = config.samples,
                n_critical_points = nrow(df_crit),
                condition_number = pol.cond_vandermonde,
                l2_error = pol.nrm,
                critical_points = df_crit
            ))
            
            println("  ✓ Success: $(nrow(df_crit)) critical points, cond=$(round(pol.cond_vandermonde, digits=2)), L2=$(round(pol.nrm, digits=8))")
            
        catch e
            println("  ✗ Failed: $e")
            push!(results_table, (
                degree = config.degree,
                samples = config.samples,
                n_critical_points = 0,
                condition_number = Inf,
                l2_error = Inf,
                critical_points = DataFrame()
            ))
        end
    end
    
    # Print table for this function
    println("\n$(test_func.name) Results:")
    println("| Degree | Samples | Critical Points | Condition Number | L2 Error     |")
    println("|--------|---------|-----------------|------------------|--------------|")
    for result in results_table
        println("| $(lpad(result.degree, 6)) | $(lpad(result.samples, 7)) | $(lpad(result.n_critical_points, 15)) | $(lpad(round(result.condition_number, digits=2), 16)) | $(lpad(round(result.l2_error, digits=8), 12)) |")
    end
    
    # Test enhanced valley walking on best result
    best_result = nothing
    for result in results_table
        if result.n_critical_points > 0 && result.condition_number < 1e10
            best_result = result
        end
    end
    
    if best_result !== nothing && nrow(best_result.critical_points) > 0
        println("\n" * "-"^40)
        println("ENHANCED VALLEY WALKING TEST")
        println("-"^40)

        # Test from first critical point
        crit_point = [best_result.critical_points.x1[1], best_result.critical_points.x2[1]]
        println("Starting from critical point: $(round.(crit_point, digits=4))")

        try
            local points, eigenvals, f_vals, step_types = enhanced_valley_walk(
                test_func.func, crit_point;
                n_steps = 12,
                step_size = 0.02,
                gradient_step_size = 0.01
            )

            n_valley = count(s -> s == "valley", step_types)
            n_gradient = count(s -> s == "gradient", step_types)

            println("\nResults:")
            println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
            println("  Initial f: $(round(f_vals[1], digits=8))")
            println("  Final f: $(round(f_vals[end], digits=8))")
            println("  Function decrease: $(round(f_vals[1] - f_vals[end], digits=8))")

            # Create integrated visualization
            create_integrated_visualization(test_func, best_result, points, f_vals, step_types)

        catch e
            println("Enhanced valley walking failed: $e")
        end
    else
        println("\nNo suitable critical points found for valley walking test")
    end
end

println("\n" * "="^80)
println("TESTING COMPLETE")
println("="^80)
