# monomial_vandermonde.jl
# High-precision Vandermonde matrix construction for monomial basis

using DynamicPolynomials
using MultivariatePolynomials
using LinearAlgebra

"""
    build_monomial_vandermonde(grid::Matrix{T}, monomials::Vector{<:Monomial},
                               precision::Type{P}=Float64) where {T, P<:AbstractFloat}

Build Vandermonde matrix for monomial basis in specified precision.

# Arguments
- `grid::Matrix{T}`: Grid points (n_points × dim)
- `monomials::Vector{<:Monomial}`: Monomial terms
- `precision::Type{P}`: Arithmetic precision (Float64, BigFloat, etc.)

# Returns
- `Matrix{P}`: Vandermonde matrix (n_points × n_monomials)

# Algorithm
For each grid point i and monomial j with exponents α:
    V[i,j] = ∏ₖ grid[i,k]^α[k]

Uses high precision to handle ill-conditioned monomial basis.

# Example
```julia
grid = [0.0 0.0; 1.0 0.0; 0.0 1.0; 1.0 1.0]
@polyvar x[1:2]
monomials = [x[1]^0*x[2]^0, x[1]^1*x[2]^0, x[1]^0*x[2]^1, x[1]^1*x[2]^1]

V = build_monomial_vandermonde(grid, monomials, Float64)
V_hp = build_monomial_vandermonde(grid, monomials, BigFloat)  # High precision
```
"""
function build_monomial_vandermonde(
    grid::Matrix{T},
    monomials::Vector{<:Monomial},
    precision::Type{P} = Float64
) where {T, P <: AbstractFloat}
    n_points, dim = size(grid)
    n_monomials = length(monomials)

    # Convert grid to specified precision
    grid_hp = convert.(precision, grid)

    # Allocate Vandermonde matrix
    V = zeros(precision, n_points, n_monomials)

    # Get variables from monomials
    vars = variables(monomials[1])

    # Build Vandermonde matrix
    for j in 1:n_monomials
        monom = monomials[j]

        # Extract exponents for this monomial
        exponents = [degree(monom, var) for var in vars]

        # Evaluate at each grid point
        for i in 1:n_points
            # Compute product: ∏ grid[i,k]^exponent[k]
            val = one(precision)
            for k in 1:dim
                if exponents[k] > 0
                    val *= grid_hp[i, k]^exponents[k]
                end
            end
            V[i, j] = val
        end
    end

    return V
end

"""
    build_sparse_monomial_vandermonde(grid::Matrix{T}, monomials::Vector{<:Monomial},
                                      active_indices::Vector{Int},
                                      precision::Type{P}=Float64) where {T, P<:AbstractFloat}

Build Vandermonde matrix for only a subset of monomials (sparsity pattern).

# Arguments
- `grid::Matrix{T}`: Grid points
- `monomials::Vector{<:Monomial}`: All monomial terms
- `active_indices::Vector{Int}`: Indices of non-zero coefficients
- `precision::Type{P}`: Arithmetic precision

# Returns
- `Matrix{P}`: Sparse Vandermonde (n_points × length(active_indices))

Only computes columns for active monomials, saving computation.

# Example
```julia
# Only build Vandermonde for monomials 1, 3, 5
active_indices = [1, 3, 5]
V_sparse = build_sparse_monomial_vandermonde(grid, monomials, active_indices, BigFloat)
```
"""
function build_sparse_monomial_vandermonde(
    grid::Matrix{T},
    monomials::Vector{<:Monomial},
    active_indices::Vector{Int},
    precision::Type{P} = Float64
) where {T, P <: AbstractFloat}
    # Extract active monomials
    active_monomials = monomials[active_indices]

    # Build Vandermonde for active monomials only
    return build_monomial_vandermonde(grid, active_monomials, precision)
end

"""
    build_monomial_vandermonde_from_pattern(grid::Matrix{T}, monomials::Vector{<:Monomial},
                                            sparsity_pattern::BitVector,
                                            precision::Type{P}=Float64) where {T, P<:AbstractFloat}

Build Vandermonde matrix from BitVector sparsity pattern.

# Arguments
- `sparsity_pattern::BitVector`: true for active monomials, false for zeros

Convenience wrapper for build_sparse_monomial_vandermonde.
"""
function build_monomial_vandermonde_from_pattern(
    grid::Matrix{T},
    monomials::Vector{<:Monomial},
    sparsity_pattern::BitVector,
    precision::Type{P} = Float64
) where {T, P <: AbstractFloat}
    active_indices = findall(sparsity_pattern)
    return build_sparse_monomial_vandermonde(grid, monomials, active_indices, precision)
end

"""
    analyze_monomial_conditioning(grid::Matrix{Float64}, monomials::Vector{<:Monomial};
                                  precision_types=[Float64, BigFloat])

Analyze condition number of monomial Vandermonde in different precisions.

# Arguments
- `grid::Matrix{Float64}`: Grid points
- `monomials::Vector{<:Monomial}`: Monomial basis
- `precision_types`: List of precision types to compare

# Returns
- DataFrame with condition numbers for each precision

Demonstrates why high precision is necessary for ill-conditioned monomial basis.

# Example
```julia
@polyvar x[1:2]
monomials = [x[1]^i * x[2]^j for i in 0:10 for j in 0:10]
grid = generate_grid(2, 30, basis=:chebyshev)

analysis = analyze_monomial_conditioning(grid, monomials)
# Shows: Float64 cond ~ 1e10, BigFloat can handle it
```
"""
function analyze_monomial_conditioning(
    grid::Matrix{Float64},
    monomials::Vector{<:Monomial};
    precision_types = [Float64, BigFloat]
)
    results = []

    for P in precision_types
        V = build_monomial_vandermonde(grid, monomials, P)

        # Compute condition number
        cond_num = cond(V)

        # Compute Gram matrix condition
        G = V' * V
        cond_gram = cond(G)

        push!(
            results,
            (
                precision = string(P),
                vandermonde_condition = Float64(cond_num),
                gram_condition = Float64(cond_gram),
                precision_digits = P == Float64 ? 16 : 77  # Approximate
            )
        )
    end

    return results
end

"""
    extract_monomial_exponents(monom::Monomial, vars::Vector)

Extract exponent vector from monomial.

# Returns
- Vector{Int}: Exponents [α₁, α₂, ..., αₙ] where monom = x₁^α₁ * x₂^α₂ * ...
"""
function extract_monomial_exponents(monom::Monomial, vars::Vector)
    return [degree(monom, var) for var in vars]
end

"""
    validate_vandermonde_construction(V::Matrix, grid::Matrix, monomials::Vector)

Validate Vandermonde matrix construction by checking random entries.

# Returns
- Bool: true if validation passes

Sanity check for Vandermonde matrix.
"""
function validate_vandermonde_construction(
    V::Matrix{T},
    grid::Matrix{S},
    monomials::Vector{<:Monomial}
) where {T, S}
    n_points, n_monomials = size(V)
    vars = variables(monomials[1])

    # Check a few random entries
    for _ in 1:min(10, n_points)
        i = rand(1:n_points)
        j = rand(1:n_monomials)

        # Extract exponents
        exponents = extract_monomial_exponents(monomials[j], vars)

        # Compute expected value
        expected = one(T)
        for k in 1:length(exponents)
            if exponents[k] > 0
                expected *= T(grid[i, k])^exponents[k]
            end
        end

        # Check
        if abs(V[i, j] - expected) > 1e-10 * abs(expected)
            @warn "Vandermonde validation failed at ($i,$j)" V[i, j] expected
            return false
        end
    end

    return true
end

"""
    compare_monomial_vs_orthogonal_conditioning(degree::Int, dim::Int, basis::Symbol=:chebyshev)

Compare condition numbers: monomial vs orthogonal basis.

Demonstrates why orthogonal basis (Chebyshev/Legendre) is preferred for
least squares, but monomial basis needed for critical points.

# Example
```julia
compare_monomial_vs_orthogonal_conditioning(10, 2, :chebyshev)
# Shows: Chebyshev cond ~ 1e2, Monomial cond ~ 1e8
```
"""
function compare_monomial_vs_orthogonal_conditioning(
    degree::Int,
    dim::Int,
    basis::Symbol = :chebyshev
)
    # Generate grid
    GN = 5 * degree  # Oversample
    grid = generate_grid(dim, GN, basis = basis)

    # Build orthogonal Vandermonde
    Lambda = SupportGen(dim, (:total_degree, degree))
    V_ortho = lambda_vandermonde(Lambda, grid, basis = basis)
    cond_ortho = cond(V_ortho)

    # Build monomial Vandermonde
    @polyvar x[1:dim]
    monomials = []
    for row in eachrow(Lambda.data)
        monom = prod(x[i]^row[i] for i in 1:dim)
        push!(monomials, monom)
    end

    V_mono = build_monomial_vandermonde(grid, monomials, Float64)
    cond_mono = cond(V_mono)

    println("Conditioning Comparison (dim=$dim, degree=$degree):")
    println("  Orthogonal ($basis): $(scientific(cond_ortho))")
    println("  Monomial:            $(scientific(cond_mono))")
    println("  Ratio:               $(scientific(cond_mono / cond_ortho))x worse")
    println()
    println("This is why high precision is needed for monomial re-optimization!")

    return (orthogonal = cond_ortho, monomial = cond_mono, ratio = cond_mono / cond_ortho)
end

"""
Format number in scientific notation.
"""
function scientific(x::Real)
    if x < 1e-3 || x > 1e6
        return @sprintf("%.2e", x)
    else
        return @sprintf("%.2f", x)
    end
end

# Export functions
export build_monomial_vandermonde,
    build_sparse_monomial_vandermonde,
    build_monomial_vandermonde_from_pattern,
    analyze_monomial_conditioning,
    validate_vandermonde_construction,
    compare_monomial_vs_orthogonal_conditioning,
    extract_monomial_exponents
