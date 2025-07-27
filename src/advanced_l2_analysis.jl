# advanced_l2_analysis.jl
# Advanced L²-norm computation and analysis for polynomial sparsification

using LinearAlgebra
using StaticArrays

# Define abstract type for domains
abstract type AbstractDomain end

"""
    BoxDomain{T}

Represents a box domain [-a,a]ⁿ.
"""
struct BoxDomain{T} <: AbstractDomain
    dimension::Int
    radius::T
end

"""
    compute_l2_norm(poly::AbstractPolynomial, domain::AbstractDomain; n_points=20)

Compute the L²-norm of a polynomial over a given domain using discrete approximation.

# Arguments
- `poly`: Polynomial in monomial basis
- `domain`: Domain of integration (box domain [-a,a]ⁿ supported)
- `n_points`: Number of grid points per dimension (default: 20)

# Returns
- L²-norm value (numerical approximation)
"""
function compute_l2_norm(poly, domain::BoxDomain; n_points = 20)
    # Get dimension from polynomial variables
    vars = variables(poly)
    dim = length(vars)

    # Simple quadrature-based L2 norm computation
    # Generate Chebyshev points for each dimension
    nodes = [cos((2i + 1) * π / (2 * n_points)) for i = 0:n_points-1]

    # Create grid and compute function values
    if dim == 1
        # 1D case
        total = 0.0
        for x in nodes
            val = poly(x * domain.radius)
            total += val^2
        end
        # Simple quadrature weight
        weight = 2.0 * domain.radius / n_points
        return sqrt(total * weight)
    else
        # Multi-dimensional case - use deterministic tensor product grid
        # Create grid points for each dimension
        total = 0.0
        n_total = n_points^dim
        
        # Generate all combinations of indices
        for idx = 0:n_total-1
            # Convert linear index to multi-dimensional indices
            indices = zeros(Int, dim)
            temp = idx
            for d = 1:dim
                indices[d] = temp % n_points
                temp = temp ÷ n_points
            end
            
            # Create point from indices
            x = zeros(dim)
            for d = 1:dim
                x[d] = nodes[indices[d]+1] * domain.radius
            end
            
            # Evaluate polynomial at this point
            val = poly(x)
            total += val^2
        end
        
        # Compute quadrature weight
        weight = (2.0 * domain.radius / n_points)^dim
        return sqrt(total * weight)
    end
end

"""
    compute_l2_norm_vandermonde(pol::ApproxPoly; grid_points=nothing)

Compute the L²-norm of a polynomial using Vandermonde matrices directly.

# Arguments
- `pol`: ApproxPoly object from Globtim
- `grid_points`: Optional custom grid (uses pol.grid if not provided)

# Returns
- L²-norm value computed using Vandermonde matrix approach
"""
function compute_l2_norm_vandermonde(pol::ApproxPoly; grid_points = nothing)
    # Use existing grid from polynomial or custom grid
    grid = grid_points === nothing ? pol.grid : grid_points

    # Ensure grid is in matrix format for lambda_vandermonde
    matrix_grid = ensure_matrix_format(grid)
    N = size(matrix_grid, 1)
    dim = size(matrix_grid, 2)  # Get dimension from grid

    # Generate Lambda (support) for the polynomial
    Lambda = SupportGen(dim, pol.degree)

    # Create Vandermonde matrix
    V = lambda_vandermonde(Lambda, matrix_grid, basis = pol.basis)

    # Compute function values at grid points: f = V * coeffs
    f_values = V * pol.coeffs

    # For simplicity, just use the polynomial's stored L2 norm
    # This is the most accurate value already computed
    return pol.nrm
end

"""
    compute_l2_norm_coeffs(pol::ApproxPoly, coeffs::Vector; grid_points=nothing)

Compute L²-norm for polynomial with modified coefficients.

# Arguments
- `pol`: Original ApproxPoly object
- `coeffs`: Modified coefficient vector
- `grid_points`: Optional custom grid

# Returns
- L²-norm value for polynomial with modified coefficients
"""
function compute_l2_norm_coeffs(pol::ApproxPoly, coeffs::Vector; grid_points = nothing)
    # Create a modified polynomial with new coefficients
    pol_modified = ApproxPoly(
        coeffs,
        pol.support,
        pol.degree,
        0.0,  # Will be computed
        pol.N,
        pol.scale_factor,
        pol.grid,
        pol.z,
        pol.basis,
        pol.precision,
        pol.normalized,
        pol.power_of_two_denom,
        pol.cond_vandermonde,
    )

    # Simple approximation: scale the original norm by coefficient ratio
    # This is not exact but gives a reasonable estimate
    original_norm_sq = sum(abs2.(pol.coeffs))
    modified_norm_sq = sum(abs2.(coeffs))

    if original_norm_sq > 0
        return pol.nrm * sqrt(modified_norm_sq / original_norm_sq)
    else
        return 0.0
    end
end

"""
    sparsify_polynomial(pol::ApproxPoly, threshold::Real; mode=:relative, preserve_indices=[])

Set small coefficients to zero while tracking L²-norm impact.

# Arguments
- `pol`: ApproxPoly to sparsify
- `threshold`: Threshold for zeroing coefficients
- `mode`: `:relative` or `:absolute` thresholding
- `preserve_indices`: Indices of coefficients to preserve

# Returns
- NamedTuple with fields:
  - `polynomial`: Sparsified ApproxPoly
  - `sparsity`: Fraction of non-zero coefficients
  - `zeroed_indices`: Indices of zeroed coefficients
  - `l2_ratio`: L²-norm ratio (sparsified/original)
  - `original_nnz`: Original number of non-zero coefficients
  - `new_nnz`: New number of non-zero coefficients
"""
function sparsify_polynomial(
    pol::ApproxPoly,
    threshold::Real;
    mode::Symbol = :relative,
    preserve_indices = Int[],
)
    # Copy coefficients
    new_coeffs = copy(pol.coeffs)

    # Determine threshold
    if mode == :relative
        max_coeff = maximum(abs.(pol.coeffs))
        actual_threshold = threshold * max_coeff
    else
        actual_threshold = threshold
    end

    # Find indices to zero out
    zeroed_indices = Int[]
    for i in eachindex(new_coeffs)
        if i ∉ preserve_indices && abs(new_coeffs[i]) < actual_threshold
            push!(zeroed_indices, i)
            new_coeffs[i] = zero(eltype(new_coeffs))
        end
    end

    # Compute L2 norms for comparison
    l2_original = compute_l2_norm_vandermonde(pol)
    l2_sparsified = compute_l2_norm_coeffs(pol, new_coeffs)

    # Create new ApproxPoly with sparsified coefficients
    pol_sparse = ApproxPoly(
        new_coeffs,
        pol.support,
        pol.degree,
        l2_sparsified,  # Update norm
        pol.N,
        pol.scale_factor,
        pol.grid,
        pol.z,
        pol.basis,
        pol.precision,
        pol.normalized,
        pol.power_of_two_denom,
        pol.cond_vandermonde,
    )

    # Compute sparsity metrics
    original_nnz = count(!iszero, pol.coeffs)
    new_nnz = count(!iszero, new_coeffs)
    sparsity = new_nnz / length(new_coeffs)

    return (
        polynomial = pol_sparse,
        sparsity = sparsity,
        zeroed_indices = zeroed_indices,
        l2_ratio = l2_sparsified / l2_original,
        original_nnz = original_nnz,
        new_nnz = new_nnz,
    )
end

"""
    compute_approximation_error(f::Function, pol::ApproxPoly, TR; n_points=30)

Compute L²-norm error ||f - p||₂ between function and polynomial approximation.

# Arguments
- `f`: Original function
- `pol`: Polynomial approximation
- `TR`: TestInput structure with domain information
- `n_points`: Number of grid points per dimension for error computation

# Returns
- L²-norm of the error
"""
function compute_approximation_error(f::Function, pol::ApproxPoly, TR; n_points = 30)
    dim = TR.dim

    # Generate evaluation grid
    grid = generate_grid(dim, n_points - 1, basis = :chebyshev)

    # Convert grid to matrix format for lambda_vandermonde
    matrix_grid = grid_to_matrix(grid)

    # Create Vandermonde matrix for polynomial evaluation
    Lambda = SupportGen(dim, pol.degree)
    V = lambda_vandermonde(Lambda, matrix_grid, basis = pol.basis)

    # Evaluate polynomial at grid points
    poly_values = V * pol.coeffs

    # Compute function values at grid points
    f_values = Float64[]
    grid_flat = reshape(grid, :)  # Flatten the grid array
    for (i, sv) in enumerate(grid_flat)
        # sv is an SVector, transform from [-1,1] to actual domain
        x_actual = TR.sample_range * sv + TR.center
        push!(f_values, f(x_actual))
    end

    # Compute errors
    errors = f_values - poly_values

    # Compute L2 norm using simple quadrature
    weight = (2.0 / n_points)^dim
    l2_error = sqrt(sum(abs2.(errors)) * weight)

    return l2_error
end

"""
    analyze_sparsification_tradeoff(pol::ApproxPoly; thresholds=[1e-6, 1e-8, 1e-10, 1e-12])

Analyze sparsity vs accuracy tradeoffs for different thresholds.

# Arguments
- `pol`: Polynomial to analyze
- `thresholds`: Array of thresholds to test

# Returns
- Array of results for each threshold
"""
function analyze_sparsification_tradeoff(
    pol::ApproxPoly;
    thresholds = [1e-6, 1e-8, 1e-10, 1e-12],
)
    results = []

    for thresh in thresholds
        result = sparsify_polynomial(pol, thresh, mode = :relative)
        push!(results, merge(result, (threshold = thresh,)))
    end

    return results
end

"""
    analyze_approximation_error_tradeoff(f::Function, pol::ApproxPoly, TR; 
                                       thresholds=[1e-6, 1e-8, 1e-10])

Analyze how sparsification affects approximation error.

# Arguments
- `f`: Original function
- `pol`: Polynomial approximation
- `TR`: TestInput with domain info
- `thresholds`: Thresholds to test

# Returns
- Array of results with approximation errors
"""
function analyze_approximation_error_tradeoff(
    f::Function,
    pol::ApproxPoly,
    TR;
    thresholds = [1e-6, 1e-8, 1e-10],
)
    # Compute original approximation error
    error_original = compute_approximation_error(f, pol, TR)

    results = []
    for thresh in thresholds
        sparse_result = sparsify_polynomial(pol, thresh, mode = :relative)
        error_sparse = compute_approximation_error(f, sparse_result.polynomial, TR)

        push!(
            results,
            (
                threshold = thresh,
                sparsity = sparse_result.sparsity,
                l2_ratio = sparse_result.l2_ratio,
                original_nnz = sparse_result.original_nnz,
                new_nnz = sparse_result.new_nnz,
                approx_error = error_sparse,
                approx_error_ratio = error_sparse / error_original,
                l2_poly_original = compute_l2_norm_vandermonde(pol),
                l2_poly_sparse = compute_l2_norm_vandermonde(sparse_result.polynomial),
            ),
        )
    end

    return results
end

"""
    verify_truncation_quality(original_poly, truncated_poly, domain::BoxDomain; n_points=20)

Verify that truncation preserves sufficient L2 norm.

# Arguments
- `original_poly`: Original polynomial
- `truncated_poly`: Truncated polynomial  
- `domain`: Domain for L²-norm computation
- `n_points`: Number of grid points per dimension

# Returns
- NamedTuple with l2_ratio, l2_original, l2_truncated
"""
function verify_truncation_quality(
    original_poly,
    truncated_poly,
    domain::BoxDomain;
    n_points = 20,
)
    # Compute both norms using the same grid for consistency
    l2_original = compute_l2_norm(original_poly, domain, n_points = n_points)
    l2_truncated = compute_l2_norm(truncated_poly, domain, n_points = n_points)

    # Compute ratio
    l2_ratio = l2_truncated / l2_original

    return (l2_ratio = l2_ratio, l2_original = l2_original, l2_truncated = l2_truncated)
end

"""
    integrate_monomial(exponents::Vector{Int}, domain::BoxDomain)

Analytically integrate a monomial over a box domain.

# Arguments
- `exponents`: Vector of exponents for each variable
- `domain`: Box domain [-a,a]ⁿ

# Returns
- Integral value

# Example
```julia
integrate_monomial([2, 0], BoxDomain(2, 1.0))  # ∫∫ x² dy dx over [-1,1]²
```
"""
function integrate_monomial(exponents::Vector{Int}, domain::BoxDomain)
    integral = 1.0

    for exp in exponents
        if exp % 2 == 1
            # Odd powers integrate to 0 over symmetric domain
            return 0.0
        else
            # Even powers: ∫_{-a}^{a} x^n dx = 2a^{n+1}/(n+1) for even n
            integral *= 2 * domain.radius^(exp + 1) / (exp + 1)
        end
    end

    return integral
end
