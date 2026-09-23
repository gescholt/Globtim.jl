# rational_solver.jl — critical points of a rational surrogate r = p/q
#
# Phase 1 of docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md, bead B2. The critical
# points of r are found through the LIFTED polynomial system in the n+1
# unknowns (x, y):
#
#     p(x) − y·q(x) = 0,        ∂ᵢp(x) − y·∂ᵢq(x) = 0     (i = 1..n).
#
# Why not q∇p − p∇q = 0: that product form vanishes identically on
# {p = q = 0}, which is positive-dimensional for n ≥ 3, so its solution set is
# not zero-dimensional (non-isolated HC endpoints; no msolve). In the lifted
# system a point with q = 0, p ≠ 0 violates the first equation, and a common
# zero of p and q survives only if in addition ∇p ∥ ∇q — generically never. No
# saturation is computed; the extra variable does it implicitly, and
# y* = r(x*) comes out for free.
#
# The HC backend is the extension method `Globtim._solve_rational_hc`, added
# next to `_solve_hc` in GlobtimHomotopyContinuationExt.jl; `_solve_hc` and
# `solve_polynomial_system` are untouched. msolve for the lifted system is
# Phase 2.

"""
    _solve_rational_hc(eqs, vars; start_system = :polyhedral) -> (sols, stats)

Solve the square polynomial system `eqs` in the variables `vars` (a
`Vector{<:DynamicPolynomials.Variable}`, the `x` variables followed by `y`) with
HomotopyContinuation and return the real solutions (as `Vector{Vector{Float64}}`,
each of length `length(vars)`) together with a `stats` NamedTuple
`(; start_system, n_paths, n_solutions, n_singular, n_real)`.

Implemented in GlobtimHomotopyContinuationExt — requires `using HomotopyContinuation`.
"""
function _solve_rational_hc(args...; kwargs...)
    error(
        "solve_rational_critical_points requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling.",
    )
end

"""
    _rational_polyvars(n) -> (x::Vector{Variable}, y::Variable)

Fresh DynamicPolynomials variables `x[1:n]` and `y` for the lifted system.
"""
function _rational_polyvars(n::Int)
    @polyvar x[1:n] y
    return collect(x), y
end

"""
    rational_critical_system(R::ApproxRational; float_coeffs = true)
        -> (; eqs, vars, x, y, p, q)

Build the lifted critical-point system of `r = p/q`:

    eqs = [ p − y·q ;  ∂₁p − y·∂₁q ; … ; ∂ₙp − y·∂ₙq ]

in the `n + 1` variables `vars = vcat(x, [y])`. `p` and `q` are converted from the
orthogonal basis to monomials exactly (`Rational{BigInt}` coefficients through
`construct_orthopoly_polynomial` with `R.normalized`, as `_solve_msolve` does) and
then, when `float_coeffs = true`, to `Float64` coefficients for HC.

Every real solution `(x*, y*)` with `q(x*) ≠ 0` is a critical point of `r` with
`y* = r(x*)`.
"""
function rational_critical_system(R::ApproxRational; float_coeffs::Bool = true)
    n = size(R.grid, 2)
    x, y = _rational_polyvars(n)
    to_rat(v) = [Rational{BigInt}(c) for c in v]
    p = construct_orthopoly_polynomial(
        x,
        to_rat(R.a),
        R.M,
        R.basis,
        RationalPrecision;
        normalized = R.normalized,
    )
    q = construct_orthopoly_polynomial(
        x,
        to_rat(R.b),
        R.N,
        R.basis,
        RationalPrecision;
        normalized = R.normalized,
    )
    if float_coeffs
        p = convert_to_float_poly(p)
        q = convert_to_float_poly(q)
    end
    gp = differentiate(p, x)
    gq = differentiate(q, x)
    eqs = vcat(p - y * q, [gp[i] - y * gq[i] for i in 1:n])
    return (; eqs = eqs, vars = vcat(x, [y]), x = x, y = y, p = p, q = q)
end

"""
    rational_product_system(R::ApproxRational; float_coeffs = true) -> (; eqs, x, p, q)

The UNLIFTED product form `q·∇p − p·∇q = 0` in the `n` variables `x`. Provided only
so that its failure mode can be exhibited (it vanishes on `{p = q = 0}`, which is
positive-dimensional for `n ≥ 3`); use `rational_critical_system` for solving.
"""
function rational_product_system(R::ApproxRational; float_coeffs::Bool = true)
    sys = rational_critical_system(R; float_coeffs = float_coeffs)
    gp = differentiate(sys.p, sys.x)
    gq = differentiate(sys.q, sys.x)
    eqs = [sys.q * gp[i] - sys.p * gq[i] for i in 1:length(sys.x)]
    return (; eqs = eqs, x = sys.x, p = sys.p, q = sys.q)
end

# ── Hessian index without division ────────────────────────────────────────────

"""
    rational_hessian_inertia(R::ApproxRational, x; tol = 1e-10)
        -> (; eigvals, n_neg, n_zero, n_pos)

Inertia of `q·H_p − p·H_q` at `x` (surrogate coordinates). At a critical point of
`r = p/q`, `H_r = (q·H_p − p·H_q)/q²`, and `q² > 0` wherever `q ≠ 0`, so this inertia is
the inertia of the Hessian of `r`, whatever the sign of `q`, without any division
by `q²`. Second derivatives come from
ForwardDiff on the orthogonal-basis evaluators (exact for polynomials up to
rounding). Eigenvalues with `|λ| ≤ tol · max|λ|` are counted as zero.
"""
function rational_hessian_inertia(R::ApproxRational, x::AbstractVector; tol::Real = 1e-10)
    xv = Vector{Float64}(x)
    pv = rational_numerator(R, xv)
    qv = rational_denominator(R, xv)
    Hp = ForwardDiff.hessian(u -> rational_numerator(R, u), xv)
    Hq = ForwardDiff.hessian(u -> rational_denominator(R, u), xv)
    G = Symmetric(qv .* Hp .- pv .* Hq)
    λ = eigvals(G)
    scale = maximum(abs, λ)
    thr = scale > 0 ? tol * scale : 0.0
    n_zero = count(v -> abs(v) <= thr, λ)
    n_neg = count(v -> v < -thr, λ)
    n_pos = length(λ) - n_zero - n_neg
    return (; eigvals = λ, n_neg = n_neg, n_zero = n_zero, n_pos = n_pos)
end

"""
    rational_hessian_index(R::ApproxRational, x; tol = 1e-10) -> Int

Morse index of `r = p/q` at the critical point `x` (surrogate coordinates): the number
of negative eigenvalues of `q·H_p − p·H_q`. `H_r = (q·H_p − p·H_q)/q²` there and `q² > 0`,
so the sign of `q` does not enter: `(−p)/(−q)` is the same function with the same index.
"""
function rational_hessian_index(R::ApproxRational, x::AbstractVector; tol::Real = 1e-10)
    return rational_hessian_inertia(R, x; tol = tol).n_neg
end

# ── the solve ──────────────────────────────────────────────────────────────────

"""
    solve_rational_critical_points(R::ApproxRational; kwargs...) -> NamedTuple

Critical points of the rational surrogate `R` inside `[-1,1]^n`, from the lifted
system `p − y·q = 0, ∇p − y·∇q = 0` solved with HomotopyContinuation (requires
`using HomotopyContinuation`; errors otherwise — it never returns an empty set
for a missing extension).

# Keyword arguments
- `q_tol = 1e-8`: a real solution with `|q(x*)| ≤ q_tol` is a near-Froissart point,
  kept in `raw` with status `:q_zero` and counted in `n_rejected_q`, not returned.
- `y_tol = 1e-8`: a solution with `|y* − p(x*)/q(x*)| > y_tol · max(1, |y*|)` is
  counted in `n_inconsistent_y` and kept in `raw` with status `:y_mismatch`.
- `start_system = :polyhedral`: `y` enters linearly, so the polyhedral start system is
  the default at every `n` (total degree pays for the loose Bézout bound).
- `verbose = 0`.

# Returns
`(; points, values, index, n_paths, n_rejected_q, n_outside, n_inconsistent_y,
n_singular, raw, stats)`:
- `points::Vector{Vector{Float64}}`: accepted critical points in surrogate coordinates
  (filter: `-1 ≤ xᵢ ≤ 1`, the same box test as `process_crit_pts`).
- `values`: `y* = r(x*)` for each accepted point.
- `index`: Morse index of each accepted point (`rational_hessian_index`).
- `n_paths`, `n_singular`: HC path count and singular endpoints (a nonzero
  `n_singular` on the lifted system deserves a look).
- `n_outside`: real solutions outside the box.
- `raw`: every real solution as `(; x, y, q, status)` with status one of
  `:accepted`, `:outside`, `:q_zero`, `:y_mismatch`, so the audit can count them.
"""
function solve_rational_critical_points(
    R::ApproxRational;
    q_tol::Real = 1e-8,
    y_tol::Real = 1e-8,
    start_system::Symbol = :polyhedral,
    verbose::Int = 0,
)
    n = size(R.grid, 2)
    sys = rational_critical_system(R)
    sols, stats = _solve_rational_hc(sys.eqs, sys.vars; start_system = start_system)

    points = Vector{Vector{Float64}}()
    values = Float64[]
    index = Int[]
    raw = NamedTuple{(:x, :y, :q, :status),Tuple{Vector{Float64},Float64,Float64,Symbol}}[]
    n_rejected_q = 0
    n_outside = 0
    n_inconsistent_y = 0
    for s in sols
        xs = Vector{Float64}(real.(s[1:n]))
        ys = Float64(real(s[n+1]))
        qv = rational_denominator(R, xs)
        status = if !all(-1 .<= xs .<= 1)
            n_outside += 1
            :outside
        elseif abs(qv) <= q_tol
            n_rejected_q += 1
            :q_zero
        elseif abs(ys - rational_numerator(R, xs) / qv) > y_tol * max(1.0, abs(ys))
            n_inconsistent_y += 1
            :y_mismatch
        else
            push!(points, xs)
            push!(values, ys)
            push!(index, rational_hessian_index(R, xs))
            :accepted
        end
        push!(raw, (; x = xs, y = ys, q = qv, status = status))
    end
    if verbose >= 1
        @info "solve_rational_critical_points: $(stats.n_paths) paths, $(length(sols)) real, " *
              "$(length(points)) in box, $n_outside outside, $n_rejected_q with |q| ≤ $q_tol, " *
              "$n_inconsistent_y y-inconsistent, $(stats.n_singular) singular"
    end
    return (;
        points = points,
        values = values,
        index = index,
        n_paths = stats.n_paths,
        n_rejected_q = n_rejected_q,
        n_outside = n_outside,
        n_inconsistent_y = n_inconsistent_y,
        n_singular = stats.n_singular,
        raw = raw,
        stats = stats,
    )
end

# ── positivity certificate for q ───────────────────────────────────────────────

"""
    certify_positive_denominator(R::ApproxRational; tau = 0.0, face_samples = 41,
                                 start_system = :auto) -> NamedTuple

Decide whether `q > tau` on the closed box `[-1,1]^n`. Poincaré–Hopf holds for
`r = p/q` on the box only when `q` has no zero there, so this is a requirement of the
critical-point census, not a nicety.

Interior candidates for the minimum of `q` are its own critical points, obtained by
**reusing the polynomial path on `q`**: `solve_polynomial_system(x, n, R.N, R.b; …)`
(the coefficient vector `R.b` is already in the orthogonal basis of degree `N`).
Boundary candidates are, in Phase 1, a dense lattice on the `2n` faces with
`face_samples` points per face dimension (a stand-in — Phase 2 recurses Globtim on
the faces). The minimum of `q` over all candidates is `qmin`.

Returns `(; ok, qmin, argmin, n_interior_candidates, n_boundary_samples, method)`
with `ok = qmin > tau` and `argmin` in surrogate coordinates.
"""
function certify_positive_denominator(
    R::ApproxRational;
    tau::Real = 0.0,
    face_samples::Int = 41,
    start_system::Symbol = :auto,
)
    n = size(R.grid, 2)
    face_samples >= 2 || throw(ArgumentError("face_samples must be ≥ 2"))
    qfun(x) = rational_denominator(R, x)

    candidates = Vector{Vector{Float64}}()
    # an affine or constant q has no interior stationary point; degree ≥ 2 only
    if R.N >= 2
        x, _ = _rational_polyvars(n)
        raw = solve_polynomial_system(
            x,
            n,
            R.N,
            R.b;
            basis = R.basis,
            precision = R.precision,
            normalized = R.normalized,
            start_system = start_system,
        )
        for s in raw
            xs = Vector{Float64}(real.(s))
            all(-1 .<= xs .<= 1) && push!(candidates, xs)
        end
    end

    qmin = Inf
    argmin = fill(NaN, n)
    for c in candidates
        v = qfun(c)
        if v < qmin
            qmin = v
            argmin = c
        end
    end

    lattice = range(-1.0, 1.0; length = face_samples)
    n_boundary = 0
    pt = zeros(n)
    for k in 1:n, side in (-1.0, 1.0)
        others = [j for j in 1:n if j != k]
        for tup in Iterators.product((lattice for _ in others)...)
            pt[k] = side
            for (j, t) in zip(others, tup)
                pt[j] = t
            end
            n_boundary += 1
            v = qfun(pt)
            if v < qmin
                qmin = v
                argmin = copy(pt)
            end
        end
    end

    return (;
        ok = qmin > tau,
        qmin = qmin,
        argmin = argmin,
        n_interior_candidates = length(candidates),
        n_boundary_samples = n_boundary,
        method = :phase1_face_sampling,
    )
end
