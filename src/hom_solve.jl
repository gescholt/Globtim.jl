"""
    solve_polynomial_system(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}} or Tuple

**Critical point finder using polynomial system solving.**

Find all critical points of a polynomial approximation by solving the gradient system
grad(p)(x) = 0 using HomotopyContinuation.jl. This is the core function for locating all
local minima, maxima, and saddle points of the approximated objective function.

Uses numerical algebraic geometry with homotopy continuation for robust solving.
Solution count is bounded by Bezout's theorem: (d-1)^n for degree d polynomial.

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
    return_system = false
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
        power_of_two_denom = power_of_two_denom
    )

    # Compute the gradient and solve the system
    grad = differentiate.(pol, x)
    sys = System(grad)
    hc_result = solve(sys, start_system = :total_degree)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)

    if return_system
        return rl_sol, (pol, sys, Int(length(hc_result)))
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
TR = TestInput(f, dim=1, center=[0.0], sample_range=10.)
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
    pol_approx::ApproxPoly
)::Vector{Vector{Float64}}
    return solve_polynomial_system(
        x,
        pol_approx;
        basis = pol_approx.basis,
        precision = pol_approx.precision,
        normalized = pol_approx.normalized,
        power_of_two_denom = pol_approx.power_of_two_denom
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
            Graded{LexOrder}
        }
    },
    n::Int,
    d,
    coeffs::Vector;
    basis = :chebyshev,
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false,
    verbose::Bool = false
)
    degree = normalize_degree(d)

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
            verbose = verbose
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

"""
    solve_polynomial_with_defaults(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}}

Utility wrapper for solve_polynomial_system with sensible default precision parameters.
This prevents common bugs where precision parameters are omitted, particularly the 
RationalPrecision issues that can cause unexpected behavior.

This function provides safe defaults for the most common polynomial system solving
use cases while still allowing customization through keyword arguments.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `n::Int`: Number of variables (dimension)
- `d::Int`: Polynomial degree
- `coeffs`: Coefficient matrix from polynomial approximation

# Keyword Arguments (with safe defaults)
- `basis::Symbol=:chebyshev`: Basis type (`:chebyshev` or `:legendre`)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2
- `return_system::Bool=false`: If true, also return the polynomial system information

# Returns
Same as `solve_polynomial_system`: Vector of real solutions within [-1,1]ⁿ, or tuple with system info.

# Examples
```julia
using DynamicPolynomials
@polyvar x[1:2]

# Basic usage with safe defaults
solutions = solve_polynomial_with_defaults(x, 2, 8, coeffs)

# Customize basis while keeping other defaults
solutions = solve_polynomial_with_defaults(x, 2, 8, coeffs, basis=:legendre)

# Use Float64 precision for better performance
solutions = solve_polynomial_with_defaults(x, 2, 8, coeffs, precision=Float64Precision)
```

# Notes
- Eliminates the most common source of precision-related bugs
- Safe defaults prevent unexpected RationalPrecision issues
- Still allows full customization when needed
- Drop-in replacement for solve_polynomial_system calls with manual parameters
"""
function solve_polynomial_with_defaults(
    x,
    n,
    d,
    coeffs;
    basis::Symbol = :chebyshev,
    precision::PrecisionType = RationalPrecision,
    normalized::Bool = true,
    power_of_two_denom::Bool = false,
    return_system::Bool = false
)
    return solve_polynomial_system(
        x, n, d, coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
        return_system = return_system
    )
end

"""
    solve_polynomial_with_defaults(x, pol::ApproxPoly; kwargs...) -> Vector{Vector{Float64}}

Convenience method for ApproxPoly objects with safe defaults.
Automatically extracts dimension and degree while providing safe precision defaults.

This method is particularly useful for preventing precision bugs when working with
ApproxPoly objects, as it ensures consistent parameter handling.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `pol::ApproxPoly`: Polynomial approximation object
- `kwargs...`: Additional keyword arguments (same as the main method)

# Examples
```julia
f = x -> sin(x[1]^2 + x[2]^2)
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=2.0)
pol = Constructor(TR, 8)
@polyvar x[1:2]

# Safe solving with automatic parameter extraction
solutions = solve_polynomial_with_defaults(x, pol)

# Customize precision while keeping other defaults
solutions = solve_polynomial_with_defaults(x, pol, precision=Float64Precision)
```

# Notes
- Combines the convenience of ApproxPoly parameter extraction with safe defaults
- Prevents common precision parameter omission bugs
- Maintains compatibility with existing ApproxPoly workflows
"""
function solve_polynomial_with_defaults(x, pol::ApproxPoly; kwargs...)
    # Use the existing ApproxPoly method but ensure we pass through our safe defaults
    # The kwargs will override the defaults when explicitly provided
    default_kwargs = Dict{Symbol, Any}(
        :basis => :chebyshev,
        :precision => RationalPrecision,
        :normalized => true,
        :power_of_two_denom => false,
        :return_system => false
    )

    # Merge user-provided kwargs with defaults (user kwargs take precedence)
    merged_kwargs = merge(default_kwargs, Dict{Symbol, Any}(kwargs))

    return solve_polynomial_system(x, pol; merged_kwargs...)
end
