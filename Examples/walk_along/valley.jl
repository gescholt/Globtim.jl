using ForwardDiff
using LinearAlgebra

function valley_walk(f, x0; n_steps = 10, step_size = 0.1, ε_null = 1e-8)
    """
    Walk along a valley (low eigenvalue manifold) of function f.

    Parameters:
    - f: Objective function
    - x0: Starting point in the valley
    - n_steps: Number of steps to take (default: 10)
    - step_size: Step size (default: 0.1)
    - ε_null: Threshold for identifying valley directions (default: 1e-8)

    Returns:
    - points: Array of all points along the trajectory
    - eigenvalues: Minimum absolute eigenvalue at each step
    - f_values: Function values along the trajectory
    """

    # Initialize storage
    points = [copy(x0)]
    eigenvalues = Float64[]
    f_values = [f(x0)]

    x = copy(x0)
    n = length(x0)

    for step in 1:n_steps
        # Compute gradient and Hessian using ForwardDiff
        g = ForwardDiff.gradient(f, x)
        H = ForwardDiff.hessian(f, x)

        # Eigendecomposition to find valley directions
        λ, V = eigen(H)
        push!(eigenvalues, minimum(abs.(λ)))

        # Identify valley directions (null/near-null space)
        valley_mask = abs.(λ) .< ε_null
        valley_indices = findall(valley_mask)

        if isempty(valley_indices)
            # No clear valley, use direction of smallest eigenvalue
            valley_indices = [argmin(abs.(λ))]
        end

        # Get valley tangent space
        V_valley = V[:, valley_indices]

        # Choose direction in valley
        # Option 1: Project negative gradient onto valley
        g_valley = V_valley' * g
        if norm(g_valley) > 1e-10
            # Move down gradient within valley
            direction_valley = -g_valley / norm(g_valley)
        else
            # Option 2: Random direction in valley
            direction_valley = randn(length(valley_indices))
            direction_valley = direction_valley / norm(direction_valley)
        end

        # Convert back to ambient space
        direction = V_valley * direction_valley

        # Take step
        x_new = x + step_size * direction

        # Project back to valley using Newton steps in normal directions
        for proj_iter in 1:5
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
            for ls in 1:10
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

        # Accept new point
        x = copy(x_new)
        push!(points, copy(x))
        push!(f_values, f(x))

        # Progress info
        println("Step $step: min|λ| = $(eigenvalues[end]), f = $(f_values[end])")
    end

    return points, eigenvalues, f_values
end

# Example: Rosenbrock valley in 3D
function rosenbrock_valley_3d(x)
    """
    Rosenbrock function extended to 3D with a valley structure:
    f(x,y,z) = (1-x)² + 100(y-x²)² + (z-y²)²

    Valley follows: y ≈ x², z ≈ y²
    """
    return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2 + (x[3] - x[2]^2)^2
end

# Example with a simpler valley
function simple_valley(x)
    """
    Simple valley: f(x,y,z) = x² + y² + (z - x² - y²)²
    Valley is the parabola z = x² + y²
    """
    return x[1]^2 + x[2]^2 + (x[3] - x[1]^2 - x[2]^2)^2
end

# Run the algorithm
println("Walking along valley...")
x0 = [0.5, 0.25, 0.3125]  # Start near the valley y≈x², z≈y²
points, eigenvals, f_vals =
    valley_walk(rosenbrock_valley_3d, x0; n_steps = 10, step_size = 0.05)

# Display results
println("\nSummary:")
println("Starting point: $x0")
println("Final point: $(points[end])")
println("Function value: $(f_vals[1]) → $(f_vals[end])")
println("Min eigenvalue: $(eigenvals[1]) → $(eigenvals[end])")

# Export for plotting
function save_trajectory(points, eigenvals, f_vals, filename = "valley_trajectory.csv")
    open(filename, "w") do io
        # Header
        n_dims = length(points[1])
        headers = ["x$i" for i in 1:n_dims]
        println(io, join([headers..., "eigenvalue", "f_value"], ","))

        # Data
        for i in 1:length(points)
            data = [points[i]...,
                i <= length(eigenvals) ? eigenvals[i] : eigenvals[end],
                f_vals[i]]
            println(io, join(data, ","))
        end
    end
    println("\nTrajectory saved to $filename")
end

save_trajectory(points, eigenvals, f_vals)

# Quick plotting if Plots.jl is available
try
    using Plots

    # Extract coordinates
    coords = reduce(hcat, points)

    # 3D trajectory
    p1 = plot(coords[1, :], coords[2, :], coords[3, :],
        line = 2, marker = :circle, markersize = 3,
        xlabel = "x", ylabel = "y", zlabel = "z",
        title = "Valley Walk in 3D",
        label = "Trajectory")
    scatter!([coords[1, 1]], [coords[2, 1]], [coords[3, 1]],
        color = :green, markersize = 8, label = "Start")
    scatter!([coords[1, end]], [coords[2, end]], [coords[3, end]],
        color = :red, markersize = 8, label = "End")

    # Function value evolution
    p2 = plot(f_vals, marker = :circle, line = 2,
        xlabel = "Step", ylabel = "f(x)",
        title = "Function Value Along Valley",
        label = nothing)

    # Eigenvalue evolution (log scale)
    p3 = plot(eigenvals, marker = :circle, line = 2,
        xlabel = "Step", ylabel = "min|λ|",
        yscale = :log10,
        title = "Minimum Eigenvalue",
        label = nothing)
    hline!([ε_null], line = :dash, color = :red, label = "threshold")

    # Combine plots
    plot(p1, p2, p3, layout = (1, 3), size = (1200, 400))
catch
    println("\nPlots.jl not available - data saved for external plotting")
end