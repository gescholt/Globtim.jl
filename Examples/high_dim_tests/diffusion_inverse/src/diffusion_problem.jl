"""
# 4D Diffusion Inverse Problem

Multi-physics transport problem with 4D active subspace:
[Diffusion, Advection, Reaction, Anisotropy]

This implements a realistic groundwater/medical imaging scenario with 4 independent
transport mechanisms that create multiple compensation basins.
"""

using LinearAlgebra
using SparseArrays
using Random

# Include shared framework
include("../../shared/src/4d_framework.jl")

"""
    DiffusionProblem

Structure containing the setup for a 4D diffusion inverse problem.
"""
struct DiffusionProblem
    # Domain specification
    domain_size::Tuple{Float64, Float64}  # (Lx, Ly)
    grid_size::Tuple{Int, Int}            # (nx, ny)
    
    # Active subspace specification
    n_params::Int                         # Total parameter dimension
    W_active::Matrix{Float64}             # n_params × 4 active subspace matrix
    
    # Sensor locations and measurements
    diffusion_sensors::Vector{Tuple{Int, Int}}
    concentration_sensors::Vector{Tuple{Int, Int}}
    gradient_sensors::Vector{Tuple{Int, Int}}
    flux_sensors::Vector{Tuple{Int, Int}}
    
    # "True" measurements (for synthetic problems)
    diffusion_measurements::Vector{Float64}
    concentration_measurements::Vector{Float64}
    gradient_measurements::Vector{Float64}
    flux_measurements::Vector{Float64}
    
    # Regularization parameters
    λ₁::Float64  # Diffusion field smoothness
    λ₂::Float64  # Velocity field smoothness
    λ₃::Float64  # Reaction field smoothness
    λ₄::Float64  # Parameter magnitude penalty
end

"""
    construct_diffusion_tensor(y1, grid_size, domain_size)

Construct spatially-varying diffusion tensor from active coordinate y1.
"""
function construct_diffusion_tensor(y1, grid_size, domain_size)
    nx, ny = grid_size
    Lx, Ly = domain_size
    
    # Base diffusion coefficient (log-normal to ensure positivity)
    D_base = exp(y1)
    
    # Create spatial variation (simple for now, could be more sophisticated)
    D_field = zeros(nx, ny)
    
    for i in 1:nx, j in 1:ny
        x = (i-1) * Lx / (nx-1)
        y = (j-1) * Ly / (ny-1)
        
        # Spatial modulation based on y1
        spatial_factor = 1.0 + 0.3 * sin(2π * x / Lx) * cos(2π * y / Ly)
        D_field[i, j] = D_base * spatial_factor
    end
    
    return D_field
end

"""
    construct_velocity_field(y2, grid_size, domain_size)

Construct advection velocity field from active coordinate y2.
"""
function construct_velocity_field(y2, grid_size, domain_size)
    nx, ny = grid_size
    Lx, Ly = domain_size
    
    # Velocity magnitude
    v_magnitude = y2
    
    # Create velocity field (divergence-free for mass conservation)
    vx = zeros(nx, ny)
    vy = zeros(nx, ny)
    
    for i in 1:nx, j in 1:ny
        x = (i-1) * Lx / (nx-1)
        y = (j-1) * Ly / (ny-1)
        
        # Stream function: ψ = sin(πx/Lx) * sin(πy/Ly)
        # vx = ∂ψ/∂y, vy = -∂ψ/∂x
        vx[i, j] = v_magnitude * (π/Ly) * sin(π*x/Lx) * cos(π*y/Ly)
        vy[i, j] = -v_magnitude * (π/Lx) * cos(π*x/Lx) * sin(π*y/Ly)
    end
    
    return vx, vy
end

"""
    construct_reaction_field(y3, grid_size, domain_size)

Construct reaction coefficient field from active coordinate y3.
"""
function construct_reaction_field(y3, grid_size, domain_size)
    nx, ny = grid_size
    Lx, Ly = domain_size
    
    # Base reaction rate
    R_base = y3
    
    # Create spatial variation
    R_field = zeros(nx, ny)
    
    for i in 1:nx, j in 1:ny
        x = (i-1) * Lx / (nx-1)
        y = (j-1) * Ly / (ny-1)
        
        # Localized reaction zones
        center1 = (0.3*Lx, 0.3*Ly)
        center2 = (0.7*Lx, 0.7*Ly)
        
        dist1 = sqrt((x - center1[1])^2 + (y - center1[2])^2)
        dist2 = sqrt((x - center2[1])^2 + (y - center2[2])^2)
        
        # Gaussian reaction zones
        R_field[i, j] = R_base * (exp(-10*dist1^2/Lx^2) + exp(-10*dist2^2/Lx^2))
    end
    
    return R_field
end

"""
    solve_transport_pde(D_field, vx, vy, R_field, anisotropy_ratio, grid_size, domain_size)

Solve the transport PDE: ∂u/∂t = ∇·(D∇u) - v·∇u + Ru + S

For steady state: 0 = ∇·(D∇u) - v·∇u + Ru + S

This is a simplified implementation - in practice would use more sophisticated PDE solvers.
"""
function solve_transport_pde(D_field, vx, vy, R_field, anisotropy_ratio, grid_size, domain_size)
    nx, ny = grid_size
    Lx, Ly = domain_size
    dx = Lx / (nx - 1)
    dy = Ly / (ny - 1)
    
    # Total number of interior points
    n_interior = (nx-2) * (ny-2)
    
    # Build finite difference matrix (simplified 5-point stencil)
    A = spzeros(n_interior, n_interior)
    b = zeros(n_interior)
    
    # Map 2D indices to 1D
    function idx(i, j)
        return (i-2) * (ny-2) + (j-1)
    end
    
    for i in 2:nx-1, j in 2:ny-1
        row = idx(i, j)
        
        # Get local coefficients
        D_local = D_field[i, j]
        vx_local = vx[i, j]
        vy_local = vy[i, j]
        R_local = R_field[i, j]
        
        # Apply anisotropy (simple scaling)
        Dxx = D_local * anisotropy_ratio
        Dyy = D_local / anisotropy_ratio
        
        # Central differences for diffusion
        # d²u/dx² ≈ (u[i+1,j] - 2u[i,j] + u[i-1,j])/dx²
        coeff_center = -2*Dxx/dx^2 - 2*Dyy/dy^2 + R_local
        coeff_east = Dxx/dx^2 + vx_local/(2*dx)
        coeff_west = Dxx/dx^2 - vx_local/(2*dx)
        coeff_north = Dyy/dy^2 + vy_local/(2*dy)
        coeff_south = Dyy/dy^2 - vy_local/(2*dy)
        
        # Fill matrix
        A[row, row] = coeff_center
        
        if i > 2
            A[row, idx(i-1, j)] = coeff_west
        end
        if i < nx-1
            A[row, idx(i+1, j)] = coeff_east
        end
        if j > 2
            A[row, idx(i, j-1)] = coeff_south
        end
        if j < ny-1
            A[row, idx(i, j+1)] = coeff_north
        end
        
        # Source term (simple point source at center)
        if i == nx÷2 && j == ny÷2
            b[row] = 1.0
        end
    end
    
    # Solve linear system
    u_interior = A \ b
    
    # Reconstruct full solution with boundary conditions (u = 0 on boundary)
    u_full = zeros(nx, ny)
    for i in 2:nx-1, j in 2:ny-1
        u_full[i, j] = u_interior[idx(i, j)]
    end
    
    return u_full
end

"""
    compute_spatial_gradients(u, grid_size, domain_size)

Compute spatial gradients of the solution field.
"""
function compute_spatial_gradients(u, grid_size, domain_size)
    nx, ny = grid_size
    Lx, Ly = domain_size
    dx = Lx / (nx - 1)
    dy = Ly / (ny - 1)
    
    grad_x = zeros(nx, ny)
    grad_y = zeros(nx, ny)
    
    # Central differences in interior
    for i in 2:nx-1, j in 2:ny-1
        grad_x[i, j] = (u[i+1, j] - u[i-1, j]) / (2*dx)
        grad_y[i, j] = (u[i, j+1] - u[i, j-1]) / (2*dy)
    end
    
    # Forward/backward differences at boundaries
    for j in 1:ny
        grad_x[1, j] = (u[2, j] - u[1, j]) / dx
        grad_x[nx, j] = (u[nx, j] - u[nx-1, j]) / dx
    end
    
    for i in 1:nx
        grad_y[i, 1] = (u[i, 2] - u[i, 1]) / dy
        grad_y[i, ny] = (u[i, ny] - u[i, ny-1]) / dy
    end
    
    return grad_x, grad_y
end

"""
    compute_fluxes(u, D_field, vx, vy, anisotropy_ratio, grid_size, domain_size)

Compute diffusive and advective fluxes.
"""
function compute_fluxes(u, D_field, vx, vy, anisotropy_ratio, grid_size, domain_size)
    grad_x, grad_y = compute_spatial_gradients(u, grid_size, domain_size)
    
    nx, ny = grid_size
    flux_x = zeros(nx, ny)
    flux_y = zeros(nx, ny)
    
    for i in 1:nx, j in 1:ny
        # Anisotropic diffusion
        Dxx = D_field[i, j] * anisotropy_ratio
        Dyy = D_field[i, j] / anisotropy_ratio
        
        # Total flux = diffusive + advective
        flux_x[i, j] = -Dxx * grad_x[i, j] + vx[i, j] * u[i, j]
        flux_y[i, j] = -Dyy * grad_y[i, j] + vy[i, j] * u[i, j]
    end
    
    return flux_x, flux_y
end

"""
    total_variation(field)

Compute total variation regularization term for a 2D field.
"""
function total_variation(field)
    nx, ny = size(field)
    tv = 0.0

    for i in 1:nx-1, j in 1:ny-1
        # TV = sum of |∇field|
        grad_x = field[i+1, j] - field[i, j]
        grad_y = field[i, j+1] - field[i, j]
        tv += sqrt(grad_x^2 + grad_y^2)
    end

    return tv
end

"""
    construct_4d_diffusion_objective(problem::DiffusionProblem)

Construct the main 4D diffusion inverse problem objective function.

Returns a function that takes θ ∈ ℝ^n_params and returns the objective value.
"""
function construct_4d_diffusion_objective(problem::DiffusionProblem)

    return function(θ)
        @assert length(θ) == problem.n_params "Parameter vector must have length $(problem.n_params)"

        # === STEP 1: Project to 4D Active Subspace ===
        y = problem.W_active' * θ  # y ∈ ℝ⁴

        # === STEP 2: Construct Multi-Physics Fields ===

        # Dimension 1: Diffusion tensor
        D_field = construct_diffusion_tensor(y[1], problem.grid_size, problem.domain_size)

        # Dimension 2: Advection velocity
        vx, vy = construct_velocity_field(y[2], problem.grid_size, problem.domain_size)

        # Dimension 3: Reaction coefficient
        R_field = construct_reaction_field(y[3], problem.grid_size, problem.domain_size)

        # Dimension 4: Anisotropy ratio
        anisotropy_ratio = exp(y[4])  # Ensures positivity

        # === STEP 3: Solve Forward Problem ===
        pde_solution = try
            solve_transport_pde(D_field, vx, vy, R_field, anisotropy_ratio,
                               problem.grid_size, problem.domain_size)
        catch
            # Return large penalty if PDE solve fails
            return 1e6
        end

        # === STEP 4: Multi-Sensor Objective ===
        total_error = 0.0

        # Diffusion sensors (measure concentration directly)
        diffusion_error = 0.0
        for (k, (i, j)) in enumerate(problem.diffusion_sensors)
            if 1 <= i <= problem.grid_size[1] && 1 <= j <= problem.grid_size[2]
                model_value = pde_solution[i, j]
                true_value = problem.diffusion_measurements[k]
                diffusion_error += (model_value - true_value)^2
            end
        end

        # Concentration sensors (also measure concentration)
        concentration_error = 0.0
        for (k, (i, j)) in enumerate(problem.concentration_sensors)
            if 1 <= i <= problem.grid_size[1] && 1 <= j <= problem.grid_size[2]
                model_value = pde_solution[i, j]
                true_value = problem.concentration_measurements[k]
                concentration_error += (model_value - true_value)^2
            end
        end

        # Gradient sensors
        grad_x, grad_y = compute_spatial_gradients(pde_solution, problem.grid_size, problem.domain_size)
        gradient_error = 0.0
        for (k, (i, j)) in enumerate(problem.gradient_sensors)
            if 1 <= i <= problem.grid_size[1] && 1 <= j <= problem.grid_size[2]
                model_grad_magnitude = sqrt(grad_x[i, j]^2 + grad_y[i, j]^2)
                true_grad_magnitude = problem.gradient_measurements[k]
                gradient_error += (model_grad_magnitude - true_grad_magnitude)^2
            end
        end

        # Flux sensors
        flux_x, flux_y = compute_fluxes(pde_solution, D_field, vx, vy, anisotropy_ratio,
                                       problem.grid_size, problem.domain_size)
        flux_error = 0.0
        for (k, (i, j)) in enumerate(problem.flux_sensors)
            if 1 <= i <= problem.grid_size[1] && 1 <= j <= problem.grid_size[2]
                model_flux_magnitude = sqrt(flux_x[i, j]^2 + flux_y[i, j]^2)
                true_flux_magnitude = problem.flux_measurements[k]
                flux_error += (model_flux_magnitude - true_flux_magnitude)^2
            end
        end

        total_error = diffusion_error + concentration_error + gradient_error + flux_error

        # === STEP 5: Regularization ===
        regularization = (problem.λ₁ * total_variation(D_field) +
                         problem.λ₂ * total_variation(vx) + problem.λ₂ * total_variation(vy) +
                         problem.λ₃ * total_variation(R_field) +
                         problem.λ₄ * norm(y)^2)

        return total_error + regularization
    end
end

"""
    create_synthetic_diffusion_problem(; n_params=100, grid_size=(21, 21),
                                       domain_size=(1.0, 1.0), n_sensors=10)

Create a synthetic 4D diffusion inverse problem for testing.
"""
function create_synthetic_diffusion_problem(; n_params=100, grid_size=(21, 21),
                                           domain_size=(1.0, 1.0), n_sensors=10)

    # Create 4D active subspace matrix
    Random.seed!(42)  # For reproducibility
    W_active = randn(n_params, 4)

    # Normalize columns
    for j in 1:4
        W_active[:, j] ./= norm(W_active[:, j])
    end

    # Create random sensor locations
    nx, ny = grid_size
    sensor_locations = [(rand(2:nx-1), rand(2:ny-1)) for _ in 1:n_sensors]

    # Generate "true" parameter vector and compute measurements
    θ_true = randn(n_params)
    y_true = W_active' * θ_true

    # Construct true fields
    D_true = construct_diffusion_tensor(y_true[1], grid_size, domain_size)
    vx_true, vy_true = construct_velocity_field(y_true[2], grid_size, domain_size)
    R_true = construct_reaction_field(y_true[3], grid_size, domain_size)
    aniso_true = exp(y_true[4])

    # Solve true PDE
    u_true = solve_transport_pde(D_true, vx_true, vy_true, R_true, aniso_true,
                                grid_size, domain_size)

    # Generate measurements with noise
    noise_level = 0.05

    diffusion_measurements = [u_true[i, j] + noise_level * randn() for (i, j) in sensor_locations]
    concentration_measurements = [u_true[i, j] + noise_level * randn() for (i, j) in sensor_locations]

    grad_x_true, grad_y_true = compute_spatial_gradients(u_true, grid_size, domain_size)
    gradient_measurements = [sqrt(grad_x_true[i, j]^2 + grad_y_true[i, j]^2) + noise_level * randn()
                           for (i, j) in sensor_locations]

    flux_x_true, flux_y_true = compute_fluxes(u_true, D_true, vx_true, vy_true, aniso_true,
                                             grid_size, domain_size)
    flux_measurements = [sqrt(flux_x_true[i, j]^2 + flux_y_true[i, j]^2) + noise_level * randn()
                        for (i, j) in sensor_locations]

    # Create problem structure
    problem = DiffusionProblem(
        domain_size,
        grid_size,
        n_params,
        W_active,
        sensor_locations,  # diffusion_sensors
        sensor_locations,  # concentration_sensors
        sensor_locations,  # gradient_sensors
        sensor_locations,  # flux_sensors
        diffusion_measurements,
        concentration_measurements,
        gradient_measurements,
        flux_measurements,
        0.01,  # λ₁
        0.01,  # λ₂
        0.01,  # λ₃
        0.001  # λ₄
    )

    return problem, θ_true
end
