# ── Solver selection heuristic ────────────────────────────────────────────────
#
# Empirical timing ranges (Apple M-series, msolve 0.9.4, HC.jl 2.x, 2026-03):
#
#   dim=2:  msolve 10-25x faster at deg 4-6, ~2-5x at deg 8, ~1x at deg 10
#   dim=3:  HC 100-600x faster (msolve Groebner basis wall)
#   dim=4:  HC 30-2200x faster
#
# Correctness: identical CP sets across all tested (dim, degree) pairs.
# Both solvers find the same points — no observed HC path loss on benchmarks.

"""
    recommended_solver(dim::Int; msolve_available::Bool=false) -> Symbol

Return `:msolve` or `:hc` based on empirical timing data.

Rules (from benchmarks on Levy, Rastrigin, Sphere, DeJong5):
- **2D with msolve available**: `:msolve` (10-25x faster at typical degrees)
- **3D+** or **msolve unavailable**: `:hc` (Groebner basis cost explodes in dim ≥ 3)

This is a heuristic — both solvers produce identical results in all tested cases.
Pass `solver=:hc` or `solver=:msolve` explicitly to override.
"""
function recommended_solver(dim::Int; msolve_available::Bool=false)
    if dim <= 2 && msolve_available
        return :msolve
    else
        return :hc
    end
end

"""
    solve_polynomial_system(x, n, d, coeffs; solver=:hc, kwargs...) -> Vector{Vector{Float64}} or Tuple

**Critical point finder using polynomial system solving.**

Find all critical points of a polynomial approximation by solving the gradient system
∇p(x) = 0. Two solver backends are available:

- `:hc` (default) — HomotopyContinuation.jl: numerical algebraic geometry via homotopy
  continuation. Fast, handles large systems, but may lose paths (miss solutions).
- `:msolve` — msolve binary: exact Gröbner basis computation over ℚ with certified
  real root isolation. Guaranteed to find all real solutions (no path loss), but
  may be slower for large systems.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `n::Int`: Number of variables (dimension)
- `d::Int`: Polynomial degree
- `coeffs`: Coefficient matrix from polynomial approximation

# Keyword Arguments
- `solver::Symbol=:hc`: Solver backend (`:hc` or `:msolve`)
- `basis::Symbol=:chebyshev`: Basis type (`:chebyshev` or `:legendre`)
- `precision::PrecisionType=RationalPrecision`: Precision type for coefficients
- `normalized::Bool=true`: Whether to use normalized basis polynomials
- `power_of_two_denom::Bool=false`: For rational precision, ensures denominators are powers of 2
- `return_system::Bool=false`: If true, also return the polynomial system information (`:hc` only)
- `msolve_threads::Int=1`: Number of threads for msolve (`:msolve` only)

# Returns
- If `return_system=false`: `Vector{Vector{Float64}}` — Real solutions within [-1,1]ⁿ
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
@polyvar x[1:2]

# Using HomotopyContinuation (default)
crit_pts = solve_polynomial_system(x, 2, 8, coeffs)

# Using msolve (exact, no path loss)
crit_pts = solve_polynomial_system(x, 2, 8, coeffs; solver=:msolve)

# msolve with 4 threads
crit_pts = solve_polynomial_system(x, 2, 8, coeffs; solver=:msolve, msolve_threads=4)
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
    sparsify_threshold::Float64 = 0.0,
    start_system::Symbol = :auto,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
    search_bounds::Union{Vector{Tuple{Float64,Float64}}, Nothing} = nothing,
)
    # Optional coefficient sparsification: zero out small coefficients before
    # constructing the DynamicPolynomials polynomial. DynamicPolynomials automatically
    # drops zero-coefficient terms, so the resulting polynomial (and its Newton polytope)
    # will be genuinely sparser. This reduces the number of HC paths when using
    # polyhedral homotopy.
    actual_coeffs = if sparsify_threshold > 0.0 && !isempty(coeffs)
        max_c = maximum(abs, coeffs)
        if max_c > 0
            cutoff = sparsify_threshold * max_c
            [abs(c) < cutoff ? zero(c) : c for c in coeffs]
        else
            coeffs
        end
    else
        coeffs
    end

    if solver == :hc
        result = _solve_hc(
            x, n, d, actual_coeffs;
            basis, precision, normalized, power_of_two_denom,
            return_system, start_system,
        )
        # Apply search_bounds as midpoint filter for HC (no interval data available)
        if search_bounds !== nothing && !return_system
            result = filter(result) do pt
                all(zip(pt, search_bounds)) do (val, (lo, hi))
                    lo <= val <= hi
                end
            end
            result = collect(result)
        end
        return result
    elseif solver == :msolve
        return_system && error("return_system=true is not supported with solver=:msolve")
        return _solve_msolve(
            x, n, d, actual_coeffs;
            basis, precision, normalized, power_of_two_denom,
            threads = msolve_threads,
            search_bounds = search_bounds,
        )
    else
        error("Unknown solver: $solver. Available: :hc, :msolve")
    end
end

"""
    _solve_hc(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}}

Solve the gradient system using HomotopyContinuation.jl.
This is the original code path — extracted for dispatch clarity.
"""
function _solve_hc(
    x, n, d, coeffs;
    basis, precision, normalized, power_of_two_denom,
    return_system, start_system,
)
    # Use the updated main_nd function with all parameters
    pol = main_nd(
        x, n, d, coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
    )

    # Resolve start system: :auto picks :polyhedral for n >= 3, :total_degree otherwise.
    # Polyhedral homotopy uses the Newton polytope (mixed volume) which is much smaller
    # than the Bezout bound for sparse systems (e.g., after sparsification or with
    # anisotropic tensor-product supports).
    actual_start = if start_system == :auto
        n >= 3 ? :polyhedral : :total_degree
    else
        start_system
    end

    # Compute the gradient and solve the system
    grad = differentiate.(pol, x)
    sys = System(grad)
    hc_result = solve(sys, start_system = actual_start)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)

    if return_system
        return rl_sol, (pol, sys, Int(length(hc_result)))
    else
        return rl_sol
    end
end

"""
    _solve_msolve(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}}

Solve the gradient system using the msolve binary (Gröbner basis + real root isolation).
Returns raw solution points in [-1,1]^n — same contract as `_solve_hc`.

Uses rational arithmetic internally for exact Gröbner basis computation.
Calls the system `msolve` binary via `msolve_polynomial_system`, then parses
the output with `msolve_raw_points`.
"""
function _solve_msolve(
    x, n, d, coeffs;
    basis, precision, normalized, power_of_two_denom,
    threads::Int = 1,
    search_bounds::Union{Vector{Tuple{Float64,Float64}}, Nothing} = nothing,
)
    # Convert coefficients to the format expected by construct_orthopoly_polynomial
    rational_coeffs = [Rational{BigInt}(c) for c in coeffs]

    # Build the polynomial in monomial basis (rational precision for msolve)
    degree = normalize_degree(d)
    p = construct_orthopoly_polynomial(
        x,
        rational_coeffs,
        degree,
        basis,
        RationalPrecision;
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
    )

    # Compute gradient
    grad = differentiate.(p, x)

    # Write input file for msolve
    random_suffix = randstring(8)
    input_file = tempname() * "_msolve_$(random_suffix).ms"
    output_file = tempname() * "_msolve_$(random_suffix)_out.ms"

    try
        # Write msolve input: variable names, characteristic, gradient polynomials
        names = [string(x[i]) for i in 1:length(x)]
        open(input_file, "w") do file
            println(file, join(names, ", "))
            println(file, 0)  # characteristic 0 = rationals
            for i in 1:n
                poly_str = replace(string(grad[i]), "//" => "/")
                if i < n
                    println(file, poly_str, ",")
                else
                    println(file, poly_str)
                end
            end
        end

        # Run msolve
        msolve_cmd = `msolve -v 0 -t $threads -f $input_file -o $output_file`
        run(msolve_cmd)

        if search_bounds !== nothing
            # Certified range search: parse intervals and filter by box overlap
            pts, ivs = msolve_raw_points_with_intervals(output_file, n)
            filtered_pts, _ = filter_solutions_by_box(pts, ivs, search_bounds)
            return filtered_pts
        else
            # Standard path: midpoints only
            return msolve_raw_points(output_file, n)
        end
    finally
        isfile(input_file) && rm(input_file)
        # output_file is cleaned up by msolve_raw_points / msolve_raw_points_with_intervals
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
function solve_polynomial_system(
    x, pol::ApproxPoly;
    solver::Symbol = :hc,
    search_bounds::Union{Vector{Tuple{Float64,Float64}}, Nothing} = nothing,
    kwargs...,
)
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

    # Pass the full degree spec through — main_nd → normalize_degree handles
    # both (:one_d_for_all, d) and (:one_d_per_dim, [d1, d2, ...]) correctly.
    return solve_polynomial_system(
        x_vec, n, pol.degree, pol.coeffs;
        solver = solver, search_bounds = search_bounds, kwargs...,
    )
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
    pol_approx::ApproxPoly;
    sparsify_threshold::Float64 = 0.0,
    start_system::Symbol = :auto,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
    search_bounds::Union{Vector{Tuple{Float64,Float64}}, Nothing} = nothing,
)::Vector{Vector{Float64}}
    return solve_polynomial_system(
        x,
        pol_approx;
        basis = pol_approx.basis,
        precision = pol_approx.precision,
        normalized = pol_approx.normalized,
        power_of_two_denom = pol_approx.power_of_two_denom,
        sparsify_threshold = sparsify_threshold,
        start_system = start_system,
        solver = solver,
        msolve_threads = msolve_threads,
        search_bounds = search_bounds,
    )
end

"""
    main_nd(
        x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder}, Graded{LexOrder}}},
        n::Int,
        d,
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
    return_system::Bool = false,
    sparsify_threshold::Float64 = 0.0,
    start_system::Symbol = :auto,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
)
    return solve_polynomial_system(
        x, n, d, coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
        return_system = return_system,
        sparsify_threshold = sparsify_threshold,
        start_system = start_system,
        solver = solver,
        msolve_threads = msolve_threads,
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
function solve_polynomial_with_defaults(x, pol::ApproxPoly; solver::Symbol = :hc, kwargs...)
    # Use the existing ApproxPoly method but ensure we pass through our safe defaults
    # The kwargs will override the defaults when explicitly provided
    default_kwargs = Dict{Symbol, Any}(
        :basis => :chebyshev,
        :precision => RationalPrecision,
        :normalized => true,
        :power_of_two_denom => false,
        :return_system => false,
    )

    # Merge user-provided kwargs with defaults (user kwargs take precedence)
    merged_kwargs = merge(default_kwargs, Dict{Symbol, Any}(kwargs))

    return solve_polynomial_system(x, pol; solver = solver, merged_kwargs...)
end
