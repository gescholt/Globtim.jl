"""
    solve_polynomial_system(
        x,
        n,
        d,
        coeffs;
        basis = :chebyshev,
        precision::PrecisionType = RationalPrecision,
        normalized::Bool = true,
        power_of_two_denom::Bool = false
    )::Vector{Vector{Float64}}

Solve a polynomial system using HomotopyContinuation.jl.

# Arguments
- `x`: Variables
- `n`: Number of variables
- `d`: Degree
- `coeffs`: Coefficients
- `basis`: Type of basis (:chebyshev or :legendre)
- `precision`: Precision type for coefficients
- `normalized`: Whether to use normalized basis polynomials
- `power_of_two_denom`: For rational precision, ensures denominators are powers of 2

# Returns
- Vector of solution vectors
"""
TimerOutputs.@timeit _TO function solve_polynomial_system(
    x,
    n,
    d,
    coeffs;
    basis=:chebyshev,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false
)::Vector{Vector{Float64}}
    # Use the updated main_nd function with all parameters
    pol = main_nd(
        x, n, d, coeffs;
        basis=basis,
        precision=precision,
        normalized=normalized,
        power_of_two_denom=power_of_two_denom
    )

    # Compute the gradient and solve the system
    grad = differentiate.(pol, x)
    sys = System(grad)
    solutions = solve(sys, start_system=:total_degree)
    rl_sol = real_solutions(solutions; only_real=true, multiple_results=false)
    return rl_sol
end

"""
    solve_polynomial_system_from_approx(
        x,
        pol_approx::ApproxPoly
    )::Vector{Vector{Float64}}

Convenience function to solve a polynomial system directly from an ApproxPoly object.
"""
function solve_polynomial_system_from_approx(
    x,
    pol_approx::ApproxPoly
)::Vector{Vector{Float64}}
    return solve_polynomial_system(
        x,
        pol_approx.n,
        pol_approx.d,
        pol_approx.coeffs;
        basis=pol_approx.basis,
        precision=pol_approx.precision,
        normalized=pol_approx.normalized,
        power_of_two_denom=pol_approx.power_of_two_denom
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
    x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
    n::Int,
    d::Int,
    coeffs::Vector;
    basis=:chebyshev,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false,
    verbose::Bool=false
)
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
            d,
            basis,
            precision;
            normalized=normalized,
            power_of_two_denom=power_of_two_denom,
            verbose=verbose
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