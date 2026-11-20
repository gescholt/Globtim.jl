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
function recommended_solver(dim::Int; msolve_available::Bool = false)
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
- `start_system::Symbol=:auto`: HC start system (`:auto` = `:polyhedral` for n ≥ 3, else
  `:total_degree`). `:hc` only.
- `hc_retries::Int=2` (`:hc` only): a solve in which HC gave up on a path (a critical point
  that may be missing) is repeated up to this many times and the attempt with the fewest
  failed paths is kept; `0` is a single solve. Failed paths left after the retries are
  logged with `@warn` and reported as `n_path_failures` in `path_stats_ref`.
- `path_stats_ref` (`:hc` only): a `Ref{Any}` that receives a named tuple of solve
  statistics — `start_system`, `paths_tracked`, `n_solutions`, `n_singular`, `n_real`,
  `n_path_failures`, `n_at_infinity`, `n_solve_attempts` (plus the sparsification counts).
- `msolve_threads::Int=1`: Number of threads for msolve (`:msolve` only)
- `msolve_coeff_tol::Float64=0.0`: (`:msolve` only) relative tolerance for
  [`dyadic_quantize`](@ref): coefficients are rounded onto a common grid `2^-b` with
  `2^-b ≤ msolve_coeff_tol * max|c|` before the exact basis conversion, so msolve works
  with ~`log2(1/msolve_coeff_tol)`-bit integers instead of the 50–100-bit numerators and
  denominators of exact `Float64` conversion. `0.0` keeps the exact conversion. A fit whose
  coefficients are only accurate to `1e-12` loses nothing at `msolve_coeff_tol = 1e-14`.

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
TimerOutputs.@timeit_debug _TO function solve_polynomial_system(
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
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing,
    msolve_coeff_tol::Float64 = 0.0,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
    path_stats_ref::Union{Nothing,Base.RefValue{Any}} = nothing,
    hc_retries::Int = 2,
)
    # Optional coefficient sparsification: zero out small coefficients before
    # constructing the DynamicPolynomials polynomial. DynamicPolynomials automatically
    # drops zero-coefficient terms, so the resulting polynomial (and its Newton polytope)
    # will be genuinely sparser. This reduces the number of HC paths when using
    # polyhedral homotopy.
    actual_coeffs = _sparsify_coeffs(coeffs, sparsify_threshold)

    if solver == :hc
        result = _solve_hc(
            x,
            n,
            d,
            actual_coeffs;
            basis,
            precision,
            normalized,
            power_of_two_denom,
            return_system,
            start_system,
            path_stats_ref,
            hc_retries,
        )
        # Enrich the solve stats with the truncation facts known at this level
        #: support size before/after sparsification.
        if path_stats_ref !== nothing && path_stats_ref[] !== nothing
            path_stats_ref[] = merge(
                path_stats_ref[],
                (;
                    sparsify_threshold = sparsify_threshold,
                    n_coeffs_total = length(coeffs),
                    n_coeffs_kept = count(!iszero, actual_coeffs),
                ),
            )
        end
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
            x,
            n,
            d,
            actual_coeffs;
            basis,
            precision,
            normalized,
            power_of_two_denom,
            threads = msolve_threads,
            timeout_seconds = msolve_timeout_seconds,
            coeff_tol = msolve_coeff_tol,
            search_bounds = search_bounds,
        )
    else
        error("Unknown solver: $solver. Available: :hc, :msolve")
    end
end

"""
    dyadic_quantize(coeffs; rel_tol = 1e-14, bits = nothing) -> Vector{Rational{BigInt}}

Round every coefficient onto a common dyadic grid `k / 2^b` and return exact rationals.

`b` is the smallest integer with `2^-b ≤ rel_tol * max|c|` (so every coefficient moves
by at most `rel_tol * max|c| / 2`), or the explicit `bits` when given. With
`rel_tol = 0` (or `bits = nothing` and `rel_tol = 0`) the conversion is the exact
`Rational{BigInt}(c)` used before this function existed.

Why: exact conversion of a `Float64` gives a 53-bit numerator over `2^(52 - e)`; a
coefficient of size `1e-12` has a ~92-bit denominator, and after clearing the lcm over
all coefficients msolve carries integers of that size times the Chebyshev→monomial
growth. A fit is only accurate to the least-squares residual, so rounding to a common
`2^-b` with `b ≈ 47` for `rel_tol = 1e-14` discards digits the fit never had while
roughly halving the integer size in the Gröbner computation.
"""
function dyadic_quantize(
    coeffs::AbstractVector{<:Real};
    rel_tol::Real = 1e-14,
    bits::Union{Nothing,Int} = nothing,
)
    rel_tol >= 0 ||
        throw(ArgumentError("dyadic_quantize: rel_tol must be ≥ 0, got $rel_tol"))
    out = Vector{Rational{BigInt}}(undef, length(coeffs))
    if bits === nothing && rel_tol == 0
        for (i, c) in enumerate(coeffs)
            out[i] = Rational{BigInt}(c)
        end
        return out
    end
    cmax = isempty(coeffs) ? 0.0 : maximum(abs, coeffs)
    if cmax == 0
        fill!(out, zero(Rational{BigInt}))
        return out
    end
    b = bits === nothing ? max(0, ceil(Int, -log2(rel_tol * cmax))) : bits
    b >= 0 || throw(ArgumentError("dyadic_quantize: bits must be ≥ 0, got $b"))
    den = BigInt(2)^b
    for (i, c) in enumerate(coeffs)
        # exact: c is dyadic, c * 2^b is an integer or a half-integer multiple only when
        # b is below c's own exponent; round(BigInt, Rational) is correct in both cases.
        out[i] = round(BigInt, Rational{BigInt}(c) * den) // den
    end
    return out
end

"""
    _solve_hc(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}}

Solve the gradient system using HomotopyContinuation.jl.
Implemented in GlobtimHomotopyContinuationExt — requires `using HomotopyContinuation`.
"""
function _solve_hc(args...; kwargs...)
    error(
        "solver=:hc requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling, or switch to solver=:msolve.",
    )
end

"""
    _solve_hc_chebyshev(pol::ApproxPoly; anchor = nothing, path_stats_ref = nothing)

Chebyshev-native HC solve of ∇p = 0 (no monomial conversion): the gradient system is
evaluated from the stored coefficients (chebyshev_eval.jl) and every fit on a support is
a parameter homotopy from one cached generic anchor. Implemented in
GlobtimHomotopyContinuationExt (ext/chebyshev_gradient_system.jl); requires
`using HomotopyContinuation`.
"""
function _solve_hc_chebyshev(args...; kwargs...)
    error(
        "representation = :chebyshev requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling.",
    )
end

"""
    _solve_hc_parametric(support, n, cell_coeffs) -> (; anchor_n, per_cell)

Batched parametric "solve-one-sweep-many" critical-point solve for a group of cells
sharing the same monomial `support` (m × n exponent matrix). Builds the gradient system
ONCE with the m monomial coefficients as HC parameters, solves a generic-complex anchor,
then tracks that solution set to each cell's coefficient vector `cell_coeffs[j]` (length m).

Returns `anchor_n` (anchor solution count, should equal the Bezout bound (deg-1)^n) and
`per_cell`: a vector of `(real_solutions_in_[-1,1]^n, (n_paths, n_success, n_real))` per cell.

Implemented in GlobtimHomotopyContinuationExt — requires `using HomotopyContinuation`.
"""
function _solve_hc_parametric(args...; kwargs...)
    error(
        "parametric warm-start (strategy=:parametric) requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling, or use strategy=:coldstart.",
    )
end

"""
    _solve_msolve(x, n, d, coeffs; kwargs...) -> Vector{Vector{Float64}}

Solve the gradient system using the msolve binary (Gröbner basis + real root isolation).
Returns raw solution points in [-1,1]^n — same contract as `_solve_hc`.

Uses rational arithmetic internally for exact Gröbner basis computation.
Writes the gradient system to a temp file, runs the system `msolve` binary
on it, then parses the output with `msolve_raw_points`.
"""
function _solve_msolve(
    x,
    n,
    d,
    coeffs;
    basis,
    precision,
    normalized,
    power_of_two_denom,
    threads::Int = 1,
    timeout_seconds::Union{Nothing,Float64} = nothing,
    coeff_tol::Float64 = 0.0,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
)
    # Convert coefficients to the format expected by construct_orthopoly_polynomial.
    # coeff_tol = 0 is the exact Rational{BigInt}(c); coeff_tol > 0 rounds onto a common
    # dyadic grid first (dyadic_quantize) to keep msolve's integers small.
    rational_coeffs = dyadic_quantize(coeffs; rel_tol = coeff_tol)

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

        # Run msolve (with optional process-level timeout)
        msolve_cmd = `msolve -v 0 -t $threads -f $input_file -o $output_file`
        if timeout_seconds !== nothing
            proc = run(msolve_cmd, wait = false)
            did_finish = timedwait(() -> !process_running(proc), timeout_seconds)
            if did_finish == :timed_out
                kill(proc)
                throw(SolverTimeoutError("msolve", timeout_seconds))
            end
        else
            run(msolve_cmd)
        end

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

Convenience method that extracts dimension, degree **and the basis metadata** from an
ApproxPoly object: `basis`, `precision`, `normalized` and `power_of_two_denom` default to
the fit's own stored values (`pol.basis`, …), so the polynomial solved is the polynomial
fitted. Until 2026-10 this overload forwarded only degree and coefficients and the main
method's defaults (`basis = :chebyshev`, `normalized = true`) took over — a Legendre fit
was solved as Chebyshev and returned `(±1.1407, 0)` for the minima of `(x²−1)² + y²`
(`pkg/BioObjectives/README.md:138-174`). Explicit keyword arguments still override the
stored values; a mismatch is then caught by the surrogate residual check below
(`surrogate_residual_tol`, surrogate_residual.jl), which raises rather than returning
roots of a different polynomial.

# Arguments
- `x`: Polynomial variables (from DynamicPolynomials)
- `pol::ApproxPoly`: Polynomial approximation object
- `surrogate_residual_tol::Real = 1e-4`: relative ‖∇p‖ allowed at a returned root
  (`Inf` disables); `surrogate_residual_margin::Real = 0.5`: roots with a coordinate
  beyond `1 + margin` are not checked
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
    x,
    pol::ApproxPoly;
    solver::Symbol = :hc,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
    basis::Symbol = pol.basis,
    precision::PrecisionType = pol.precision,
    normalized::Bool = pol.normalized,
    power_of_two_denom::Bool = pol.power_of_two_denom,
    sparsify_threshold::Float64 = 0.0,
    surrogate_residual_tol::Real = 1e-4,
    surrogate_residual_margin::Real = 0.5,
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
    result = solve_polynomial_system(
        x_vec,
        n,
        pol.degree,
        pol.coeffs;
        solver = solver,
        search_bounds = search_bounds,
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
        sparsify_threshold = sparsify_threshold,
        kwargs...,
    )

    # N4 (surrogate_residual.jl): every returned root must be a critical point of the
    # surrogate that was FITTED. This overload is exactly where the basis trap lives —
    # a caller who omits basis/normalized gets the main method's defaults and solves a
    # different polynomial — so the check is here, on the raw box-coordinate roots, for
    # HC and msolve alike. `return_system = true` returns (roots, system_info).
    # With sparsification the polynomial that was SOLVED is the truncated one, so the
    # residual is measured on it: a root of the truncated system is not a root of the
    # dense one, and checking against the dense one would raise on legitimate roots.
    roots = result isa Tuple ? result[1] : result
    pol_solved =
        sparsify_threshold > 0.0 ?
        _with_coeffs(pol, _sparsify_coeffs(pol.coeffs, sparsify_threshold)) : pol
    check_surrogate_residuals(
        pol_solved,
        roots;
        tol = surrogate_residual_tol,
        margin = surrogate_residual_margin,
    )
    return result
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
    msolve_timeout_seconds::Union{Nothing,Float64} = nothing,
    msolve_coeff_tol::Float64 = 0.0,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
    path_stats_ref::Union{Nothing,Base.RefValue{Any}} = nothing,
    representation::Symbol = :monomial,
    surrogate_residual_tol::Real = 1e-4,
    hc_retries::Int = 2,
)::Vector{Vector{Float64}}
    representation in (:monomial, :chebyshev) || throw(
        ArgumentError(
            "representation must be :monomial or :chebyshev, got :$representation",
        ),
    )
    if representation === :chebyshev
        # Chebyshev-native path (CHEBYSHEV_NATIVE_HC_PLAN.md): the gradient system is
        # evaluated from the stored coefficients, no monomial polynomial is formed.
        solver === :hc || throw(
            ArgumentError(
                "representation = :chebyshev is an HC path; got solver = :$solver",
            ),
        )
        sparsify_threshold == 0.0 || throw(
            ArgumentError(
                "representation = :chebyshev does not sparsify; got sparsify_threshold = $sparsify_threshold",
            ),
        )
        roots = _solve_hc_chebyshev(pol_approx; path_stats_ref = path_stats_ref)
        check_surrogate_residuals(pol_approx, roots; tol = surrogate_residual_tol)
        return roots
    end
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
        msolve_timeout_seconds = msolve_timeout_seconds,
        msolve_coeff_tol = msolve_coeff_tol,
        search_bounds = search_bounds,
        path_stats_ref = path_stats_ref,
        surrogate_residual_tol = surrogate_residual_tol,
        hc_retries = hc_retries,
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

"""
    group_key(pol::ApproxPoly)

Support-equivalence key for parametric warm-start grouping. Two cells share a monomial
support — and can therefore warm-start from one anchor — iff their keys are equal.
Includes `normalized` and `power_of_two_denom` because they change the orthopoly→monomial
transform (and thus the realized support), not just `(n, degree, basis)`.
"""
group_key(pol::ApproxPoly) = (
    size(pol.support, 2),       # n (dimension)
    pol.degree,                 # degree spec — fixes SupportGen, hence the monomial support
    pol.basis,
    pol.normalized,
    pol.power_of_two_denom,
)

"""
    cell_monomial_coeffs(pol::ApproxPoly) -> Vector{Float64}

A cell's coefficients in the MONOMIAL basis, densified against `pol.support`'s row order
(the `SupportGen(n, degree)` ordering). Reuses `main_nd` to apply the exact orthopoly→
monomial transform, then reads the coefficient of each support monomial off the result.

Densification is mandatory: `main_nd`/`convert_to_float_poly` drop exact-zero terms, so
two cells in the same group can otherwise yield misaligned-length coefficient vectors.
Returning a full length-`m` vector (zeros for absent monomials) keeps every cell's
parameter vector aligned to the shared support for warm-start.
"""
function cell_monomial_coeffs(pol::ApproxPoly)
    n = size(pol.support, 2)
    m = size(pol.support, 1)
    @polyvar x[1:n]
    xv = collect(x)
    p = main_nd(
        xv,
        n,
        pol.degree,
        pol.coeffs;
        basis = pol.basis,
        precision = pol.precision,
        normalized = pol.normalized,
        power_of_two_denom = pol.power_of_two_denom,
    )
    coeffs = zeros(Float64, m)
    for k in 1:m
        mono = prod(xv[i]^Int(pol.support[k, i]) for i in 1:n)
        coeffs[k] = Float64(coefficient(p, mono))
    end
    return coeffs
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
        x,
        n,
        d,
        coeffs;
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
    # The "safe defaults" are the fit's own stored values (anything else solves a
    # different polynomial than the one fitted; see the ApproxPoly overload).
    default_kwargs = Dict{Symbol,Any}(
        :basis => pol.basis,
        :precision => pol.precision,
        :normalized => pol.normalized,
        :power_of_two_denom => pol.power_of_two_denom,
        :return_system => false,
    )

    # Merge user-provided kwargs with defaults (user kwargs take precedence)
    merged_kwargs = merge(default_kwargs, Dict{Symbol,Any}(kwargs))

    return solve_polynomial_system(x, pol; solver = solver, merged_kwargs...)
end
