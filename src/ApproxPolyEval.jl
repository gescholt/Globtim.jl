# src/ApproxPolyEval.jl
#
# Efficient evaluation of ApproxPoly polynomial approximations.
# Provides evaluate() and gradient() functions for ApproxPoly objects.

using ForwardDiff
using DynamicPolynomials

"""
    evaluate(poly::ApproxPoly, x::AbstractVector{<:Real})::Float64

Evaluate polynomial approximation at point `x`.

The point `x` should be in the original (unscaled) domain. The function internally
scales `x` by `poly.scale_factor` to map to the [-1,1]^n reference domain where
the orthogonal basis polynomials are defined.

# Arguments
- `poly::ApproxPoly`: The polynomial approximation object
- `x::AbstractVector{<:Real}`: Point at which to evaluate (in original domain)

# Returns
- `Float64`: Value of the polynomial approximation at `x`

# Example
```julia
poly = MainGenerate(f, 2, (:one_d_for_all, 8), 0.05, 0.95, 1.5, 1.0)
val = evaluate(poly, [0.5, 0.3])
```
"""
function evaluate(poly::ApproxPoly, x::AbstractVector{T})::T where {T<:Real}
    # Transform from original domain to [-1,1]^n normalized domain
    # x_normalized = (x - center) / scale_factor
    x_scaled = (x .- poly.center) ./ poly.scale_factor

    # Get dimension
    n = length(x)

    # Validate dimensions
    lambda = Matrix(poly.support)  # Convert Adjoint to Matrix if needed
    n_terms = size(lambda, 1)
    n_dims = size(lambda, 2)

    if n != n_dims
        throw(DimensionMismatch("Expected point of dimension $n_dims, got $n"))
    end

    # Get max degree for caching
    max_degree = maximum(lambda)

    # Pre-compute normalized basis polynomial values at each coordinate
    # basis_evals[k, d+1] = value of T_d(x_k) or P_d(x_k) with normalization
    # Use eltype of x_scaled to support ForwardDiff Dual numbers
    basis_evals = Matrix{eltype(x_scaled)}(undef, n, max_degree + 1)

    for k in 1:n
        xk = x_scaled[k]

        if poly.basis == :chebyshev
            # Chebyshev recurrence: T_0=1, T_1=x, T_n = 2x*T_{n-1} - T_{n-2}
            T_prev = one(xk)  # T_0
            T_curr = xk       # T_1

            # Apply normalization: T_0 normalized by 1/sqrt(π), T_n by sqrt(2/π)
            if poly.normalized
                basis_evals[k, 1] = T_prev / sqrt(π)  # T_0 normalized
            else
                basis_evals[k, 1] = T_prev
            end

            if max_degree >= 1
                if poly.normalized
                    basis_evals[k, 2] = T_curr * sqrt(2 / π)  # T_1 normalized
                else
                    basis_evals[k, 2] = T_curr
                end
            end

            for d in 2:max_degree
                T_next = 2 * xk * T_curr - T_prev
                if poly.normalized
                    basis_evals[k, d+1] = T_next * sqrt(2 / π)
                else
                    basis_evals[k, d+1] = T_next
                end
                T_prev = T_curr
                T_curr = T_next
            end
        else  # :legendre
            # Legendre recurrence: P_0=1, P_1=x, P_n = ((2n-1)x*P_{n-1} - (n-1)*P_{n-2})/n
            P_prev = one(xk)  # P_0
            P_curr = xk       # P_1

            # Apply normalization: P_n normalized by sqrt((2n+1)/2)
            if poly.normalized
                basis_evals[k, 1] = P_prev * sqrt(0.5)  # sqrt((2*0+1)/2) = sqrt(0.5)
            else
                basis_evals[k, 1] = P_prev
            end

            if max_degree >= 1
                if poly.normalized
                    basis_evals[k, 2] = P_curr * sqrt(1.5)  # sqrt((2*1+1)/2) = sqrt(1.5)
                else
                    basis_evals[k, 2] = P_curr
                end
            end

            for d in 2:max_degree
                P_next = ((2d-1) * xk * P_curr - (d-1) * P_prev) / d
                if poly.normalized
                    basis_evals[k, d+1] = P_next * sqrt((2d+1) / 2)
                else
                    basis_evals[k, d+1] = P_next
                end
                P_prev = P_curr
                P_curr = P_next
            end
        end
    end

    # Evaluate: sum over all basis terms
    # Each term is c_j * prod_k(basis_k(degree_jk))
    result = zero(eltype(x_scaled))
    for j in 1:n_terms
        term = one(eltype(x_scaled))
        for k in 1:n
            deg = lambda[j, k]
            term *= basis_evals[k, deg + 1]
        end
        result += poly.coeffs[j] * term
    end

    return result
end


"""
    gradient(poly::ApproxPoly, x::AbstractVector{<:Real})::Vector{Float64}

Compute gradient of polynomial approximation at point `x` using automatic differentiation.

The gradient is computed in the original (unscaled) domain coordinates.

# Arguments
- `poly::ApproxPoly`: The polynomial approximation object
- `x::AbstractVector{<:Real}`: Point at which to compute gradient (in original domain)

# Returns
- `Vector{Float64}`: Gradient vector ∇p(x)

# Example
```julia
poly = MainGenerate(f, 2, (:one_d_for_all, 8), 0.05, 0.95, 1.5, 1.0)
grad = gradient(poly, [0.5, 0.3])
```
"""
function gradient(poly::ApproxPoly, x::AbstractVector{<:Real})::Vector{Float64}
    return ForwardDiff.gradient(z -> evaluate(poly, z), collect(x))
end


"""
    evaluate(poly::ApproxPoly, X::AbstractMatrix{<:Real})::Vector{Float64}

Evaluate polynomial approximation at multiple points.

# Arguments
- `poly::ApproxPoly`: The polynomial approximation object
- `X::AbstractMatrix{<:Real}`: Points as rows (n_points × n_dims)

# Returns
- `Vector{Float64}`: Values at each point
"""
function evaluate(poly::ApproxPoly, X::AbstractMatrix{<:Real})::Vector{Float64}
    n_points = size(X, 1)
    values = Vector{Float64}(undef, n_points)
    for i in 1:n_points
        values[i] = evaluate(poly, view(X, i, :))
    end
    return values
end
