"""
    solve_polynomial_system(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}} or Tuple

Find all critical points of a polynomial by solving ∇p(x) = 0 using HomotopyContinuation.jl.

This function constructs the gradient system of the polynomial approximation and solves it
to find all stationary points. It handles both Chebyshev and Legendre basis polynomials.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `n::Int`: Number of variables (dimension)
- `d::Int`: Polynomial degree
- `coeffs`: Coefficient matrix from polynomial approximation

# Keyword Arguments
- `basis::Symbol=:chebyshev`: Basis type (`:chebyshev` or `:legendre`)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2
- `return_system::Bool=false`: If true, also return the polynomial system information

# Returns
- If `return_system=false`: `Vector{Vector{Float64}}` - Real solutions within [-1,1]ⁿ
- If `return_system=true`: `Tuple` containing:
  - Solutions vector
  - Tuple of (polynomial system, HC system, total solution count)

# Notes
- Only returns real solutions within the domain [-1,1]ⁿ
- Complex solutions and solutions outside the domain are filtered out
- The number of solutions can vary significantly based on the polynomial degree

# Examples
```julia
using DynamicPolynomials

# Basic usage (assuming pol is an ApproxPoly object)
@polyvar x[1:2]
# coeffs = ... # coefficient matrix from polynomial approximation
# crit_pts = solve_polynomial_system(x, 2, 8, coeffs)
# println("Found \$(length(crit_pts)) critical points")

# With system information for debugging
# crit_pts, (polysys, hc_sys, total) = solve_polynomial_system(
#     x, 2, 8, coeffs,
#     return_system=true
# )
# println("Total solutions (including complex): \$total")
# println("Real solutions in domain: \$(length(crit_pts))")

# Using Legendre basis
# crit_pts = solve_polynomial_system(x, 2, 6, coeffs, basis=:legendre)
```
"""
TimerOutputs.@timeit _TO function solve_polynomial_system(
    x,
    n,
    d,
    coeffs;
    basis = :chebyshev,
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false,
    return_system = false,
)
    # Use the updated main_nd function with all parameters
    pol = main_nd(
        x,
        n,
        d,
        coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
    )

    # Compute the gradient and solve the system
    grad = differentiate.(pol, x)
    sys = System(grad)
    hc_result = solve(sys, start_system = :total_degree)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)

    if return_system
        return rl_sol, (pol, sys, length(hc_result))
    else
        return rl_sol
    end
end

"""
    solve_polynomial_system(x, pol::ApproxPoly; kwargs...)

Convenience method that automatically extracts dimension and degree from an ApproxPoly object.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `pol::ApproxPoly`: Polynomial approximation object
- `kwargs...`: Additional keyword arguments passed to the main method

# Returns
Same as the main `solve_polynomial_system` method.

# Example
```julia
f = x -> sin(x)
TR = test_input(f, dim=1, center=[0.0], sample_range=10.)
pol = Constructor(TR, 8)
@polyvar x
solutions = solve_polynomial_system(x, pol)  # No need to specify dim and degree
```
"""
function solve_polynomial_system(x, pol::ApproxPoly; kwargs...)
    # Handle both single variable and vector of variables
    x_vec = if isa(x, AbstractVector)
        x
    else
        # Single variable - wrap in vector
        [x]
    end

    # Extract dimension and degree from ApproxPoly
    n = size(pol.support, 2)  # Number of variables (from support matrix)

    # Validate dimension matches
    if length(x_vec) != n
        error("Number of variables ($(length(x_vec))) must match polynomial dimension ($n)")
    end

    # Extract degree from the ApproxPoly object
    degree_info = pol.degree
    d = if degree_info[1] == :one_d_for_all
        degree_info[2]
    elseif degree_info[1] == :one_d_per_dim
        maximum(degree_info[2])
    else
        error("Unsupported degree format in ApproxPoly")
    end

    return solve_polynomial_system(x_vec, n, d, pol.coeffs; kwargs...)
end

"""
    solve_polynomial_system_from_approx(
        x,
        pol_approx::ApproxPoly
    )::Vector{Vector{Float64}}

Convenience function to solve a polynomial system directly from an ApproxPoly object.
Automatically determines the correct degree from the ApproxPoly structure.
"""
function solve_polynomial_system_from_approx(
    x,
    pol_approx::ApproxPoly,
)::Vector{Vector{Float64}}
    return solve_polynomial_system(
        x,
        pol_approx;
        basis = pol_approx.basis,
        precision = pol_approx.precision,
        normalized = pol_approx.normalized,
        power_of_two_denom = pol_approx.power_of_two_denom,
    )
end

"""
    main_nd(
        x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder}, Graded{LexOrder}}},
        n::Int,
        d::Int,
        coeffs::Vector;
        basis=:chebyshev,
        precision::PrecisionType=RationalPrecision,
        normalized::Bool=true,
        power_of_two_denom::Bool=false,
        verbose::Bool=true
    )

Construct a polynomial in the standard monomial basis from a vector of coefficients
(which have been computed in the tensorized Chebyshev or tensorized Legendre basis).
This updated version uses construct_orthopoly_polynomial for the construction
and ensures the result is compatible with homotopy continuation.
"""
function main_nd(
    x::Vector{
        Variable{
            DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},
            Graded{LexOrder},
        },
    },
    n::Int,
    d,
    coeffs::Vector;
    basis = :chebyshev,
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false,
    verbose::Bool = false,
)
    # Handle backward compatibility: convert integer degree to tuple format
    degree = if isa(d, Int)
        (:one_d_for_all, d)
    else
        d
    end

    # For backwards compatibility
    bigint = (precision == RationalPrecision)

    if verbose
        println("Building polynomial with:")
        println("  basis: ", basis)
        println("  precision: ", precision)
        println("  normalized: ", normalized)
        println("  power_of_two_denom: ", power_of_two_denom)
    end

    # Time the construct_orthopoly_polynomial call
    local pol
    time_taken = @elapsed begin
        pol = construct_orthopoly_polynomial(
            x,
            coeffs,
            degree,
            basis,
            precision;
            normalized = normalized,
            power_of_two_denom = power_of_two_denom,
            verbose = verbose,
        )
    end

    if verbose
        println("Time to construct polynomial: $(time_taken) seconds")
    end

    # Always convert to a polynomial with Float64 coefficients for homotopy continuation
    # This ensures numerical stability during solving
    return convert_to_float_poly(pol)
end

"""
Convert a polynomial to a polynomial with Float64 coefficients
for better compatibility with homotopy continuation
"""
function convert_to_float_poly(p)
    terms_array = terms(p)
    float_terms = map(terms_array) do term
        coeff = coefficient(term)
        Float64(coeff) * monomial(term)
    end
    return sum(float_terms)
end
