"""
# 4D Framework Utilities for High-Dimensional Globtim Examples

This module provides common utilities for constructing 4D active subspace problems
with multiple physical mechanisms and basin structures.
"""

using LinearAlgebra
using Random
using Statistics

"""
    construct_4d_basis(domain, n_total=100; basis_types=[:fourier_low, :fourier_high, :gaussian, :boundary])

Construct a 4D active subspace basis with different mechanism types.

# Arguments
- `domain`: Spatial domain specification (e.g., [0,1]^d)
- `n_total`: Total number of basis functions (divided among 4 mechanisms)
- `basis_types`: Types of basis functions for each mechanism

# Returns
- `W_active`: n_total × 4 matrix defining the active subspace
"""
function construct_4d_basis(domain, n_total=100; basis_types=[:fourier_low, :fourier_high, :gaussian, :boundary])
    n_per_dimension = n_total ÷ 4

    # Initialize basis matrix
    W_active = zeros(n_total, 4)

    # Mechanism 1: Low-frequency modes
    if basis_types[1] == :fourier_low
        for i in 1:n_per_dimension
            k = i
            W_active[i, 1] = fourier_basis_1d(k, domain, :low_freq)
        end
    end

    # Mechanism 2: High-frequency modes
    if basis_types[2] == :fourier_high
        for i in 1:n_per_dimension
            k = i + n_per_dimension
            W_active[n_per_dimension + i, 2] = fourier_basis_1d(k, domain, :high_freq)
        end
    end

    # Mechanism 3: Localized features (Gaussian RBFs)
    if basis_types[3] == :gaussian
        centers = range(domain[1], domain[2], length=n_per_dimension)
        width = (domain[2] - domain[1]) / (2 * n_per_dimension)
        for i in 1:n_per_dimension
            W_active[2*n_per_dimension + i, 3] = gaussian_rbf_weight(centers[i], width)
        end
    end

    # Mechanism 4: Boundary effects
    if basis_types[4] == :boundary
        for i in 1:n_per_dimension
            W_active[3*n_per_dimension + i, 4] = boundary_basis_weight(i, domain)
        end
    end

    # Ensure each column has at least one non-zero entry
    for j in 1:4
        if all(W_active[:, j] .== 0.0)
            # Add a small random component to avoid zero columns
            start_idx = (j-1) * n_per_dimension + 1
            end_idx = min(j * n_per_dimension, n_total)
            W_active[start_idx:end_idx, j] .= 0.1 * randn(end_idx - start_idx + 1)
        end
    end

    return W_active
end

"""
    fourier_basis_1d(k, domain, freq_type)

Generate Fourier basis function weights for 1D domain.
"""
function fourier_basis_1d(k, domain, freq_type)
    L = domain[2] - domain[1]
    if freq_type == :low_freq
        return sin(π * k * (domain[1] + domain[2]) / (2 * L))
    else  # high_freq
        return sin(2π * k * (domain[1] + domain[2]) / L)
    end
end

"""
    gaussian_rbf_weight(center, width)

Generate Gaussian RBF basis function weight.
"""
function gaussian_rbf_weight(center, width)
    return exp(-0.5 * (center / width)^2)
end

"""
    boundary_basis_weight(index, domain)

Generate boundary-localized basis function weight.
"""
function boundary_basis_weight(index, domain)
    # Simple boundary weighting - could be more sophisticated
    domain_size = domain[2] - domain[1]
    boundary_strength = 1.0 / (1.0 + index) * domain_size
    return boundary_strength * ((-1)^index)
end

"""
    multi_objective_4d(y, mechanism_functions, weights, coupling_matrix=nothing)

General 4D multi-objective function framework.

# Arguments
- `y`: 4D active coordinates
- `mechanism_functions`: Vector of 4 functions, one per mechanism
- `weights`: Vector of 4 weights for each mechanism
- `coupling_matrix`: Optional 4×4 matrix for cross-coupling terms

# Returns
- Scalar objective value
"""
function multi_objective_4d(y, mechanism_functions, weights, coupling_matrix=nothing)
    @assert length(y) == 4 "Input must be 4-dimensional"
    @assert length(mechanism_functions) == 4 "Must have 4 mechanism functions"
    @assert length(weights) == 4 "Must have 4 weights"
    
    # Primary objectives (each depends primarily on one mechanism)
    obj1 = mechanism_functions[1](y[1])
    obj2 = mechanism_functions[2](y[2])  
    obj3 = mechanism_functions[3](y[3])
    obj4 = mechanism_functions[4](y[4])
    
    # Weighted sum of primary objectives
    primary_objective = weights[1]*obj1 + weights[2]*obj2 + weights[3]*obj3 + weights[4]*obj4
    
    # Optional cross-coupling terms
    coupling_terms = 0.0
    if coupling_matrix !== nothing
        for i in 1:4, j in 1:4
            if i != j && coupling_matrix[i,j] != 0
                coupling_terms += coupling_matrix[i,j] * interaction_term(y[i], y[j])
            end
        end
    end
    
    return primary_objective + coupling_terms
end

"""
    interaction_term(y1, y2)

Generic interaction term between two mechanisms.
"""
function interaction_term(y1, y2)
    return y1 * y2 * exp(-0.5 * (y1^2 + y2^2))
end

"""
    create_4d_test_problem(problem_type::Symbol; n_params=100, domain=[-2.0, 2.0])

Create a standardized 4D test problem for validation.

# Arguments
- `problem_type`: :simple, :coupled, or :complex
- `n_params`: Total number of parameters (projected to 4D)
- `domain`: Parameter domain bounds

# Returns
- Function that takes θ ∈ ℝ^n_params and returns scalar objective
"""
function create_4d_test_problem(problem_type::Symbol; n_params=100, domain=[-2.0, 2.0])
    
    # Construct 4D active subspace
    W_active = construct_4d_basis([domain[1], domain[2]], n_params)
    
    if problem_type == :simple
        # Simple separable problem
        mechanism_functions = [
            y -> (y - 0.5)^2,      # Quadratic basin at y=0.5
            y -> (y + 0.5)^2,      # Quadratic basin at y=-0.5  
            y -> sin(2π*y)^2,      # Oscillatory with multiple minima
            y -> abs(y)            # V-shaped basin at y=0
        ]
        weights = [1.0, 1.0, 0.5, 0.5]
        coupling_matrix = nothing
        
    elseif problem_type == :coupled
        # Coupled problem with cross-terms
        mechanism_functions = [
            y -> (y - 1.0)^2,
            y -> (y + 1.0)^2,
            y -> 0.5 * y^4 - y^2,  # Double-well potential
            y -> cos(π*y)          # Cosine potential
        ]
        weights = [1.0, 1.0, 1.0, 1.0]
        coupling_matrix = [0.0 0.2 0.0 0.1;
                          0.2 0.0 0.1 0.0;
                          0.0 0.1 0.0 0.2;
                          0.1 0.0 0.2 0.0]
                          
    elseif problem_type == :complex
        # Complex multi-modal problem
        mechanism_functions = [
            y -> sum([(y - k)^2 * exp(-(y - k)^2) for k in [-1.5, 0.0, 1.5]]),  # Multi-Gaussian
            y -> (y^2 - 1)^2,                                                     # Double-well
            y -> sin(3π*y) * exp(-y^2),                                          # Modulated sine
            y -> 0.1*y^4 - 0.5*y^2 + 0.1*abs(y)                                # Asymmetric potential
        ]
        weights = [1.0, 1.2, 0.8, 1.1]
        coupling_matrix = [0.0 0.3 0.1 0.2;
                          0.3 0.0 0.2 0.1;
                          0.1 0.2 0.0 0.3;
                          0.2 0.1 0.3 0.0]
    else
        error("Unknown problem_type: $problem_type. Use :simple, :coupled, or :complex")
    end
    
    # Return the objective function
    return function(θ)
        # Project to 4D active subspace
        y = W_active' * θ
        
        # Evaluate multi-objective function
        return multi_objective_4d(y, mechanism_functions, weights, coupling_matrix)
    end
end

"""
    validate_4d_structure(objective_func, n_params, domain; n_samples=1000)

Validate that a 4D problem has the expected active subspace structure.

# Returns
- Dictionary with validation metrics
"""
function validate_4d_structure(objective_func, n_params, domain; n_samples=1000)
    # Generate random samples
    Random.seed!(42)  # For reproducibility
    samples = [domain[1] .+ (domain[2] - domain[1]) .* rand(n_params) for _ in 1:n_samples]
    
    # Evaluate objective at samples
    values = [objective_func(θ) for θ in samples]
    
    # Basic statistics
    stats = Dict(
        :mean => mean(values),
        :std => std(values),
        :min => minimum(values),
        :max => maximum(values),
        :n_samples => n_samples,
        :n_params => n_params
    )
    
    return stats
end
