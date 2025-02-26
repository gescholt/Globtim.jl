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
function solve_polynomial_system(
    x,
    n,
    d,
    coeffs;
    basis=:chebyshev,
    precision::PrecisionType=RationalPrecision,
    normalized::Bool=true,
    power_of_two_denom::Bool=false
)::Vector{Vector{Float64}}
    # Use the new main_nd with our precision parameters
    pol = main_nd(
        x, n, d, coeffs;
        basis=basis,
        precision=precision,
        normalized=normalized,
        power_of_two_denom=power_of_two_denom
    )

    grad = differentiate.(pol, x)
    sys = System(grad)
    solutions = solve(sys, start_system=:total_degree)
    rl_sol = real_solutions(solutions; only_real=true, multiple_results=false)
    return rl_sol
end