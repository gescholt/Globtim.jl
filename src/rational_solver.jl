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

import JLD2
using MultivariatePolynomials: terms, monomial, coefficient, degree

"""
    _solve_rational_hc(eqs, vars; start_system = :polyhedral, compile = nothing) -> (sols, stats)

Solve the square polynomial system `eqs` in the variables `vars` (a
`Vector{<:DynamicPolynomials.Variable}`, the `x` variables followed by `y`) with
HomotopyContinuation and return the real solutions (as `Vector{Vector{Float64}}`,
each of length `length(vars)`) together with a `stats` NamedTuple
`(; start_system, n_paths, n_solutions, n_singular, n_real)`. `compile` is passed
to HC's `solve` when given (`false`: interpret the system, for many small solves).

Implemented in GlobtimHomotopyContinuationExt — requires `using HomotopyContinuation`.
"""
function _solve_rational_hc(args...; kwargs...)
    error(
        "solve_rational_critical_points requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling.",
    )
end

"""
    _solve_rational_hc_parametric(n, M, N, fits; anchor = :monodromy,
                                  anchor_dir = _default_rational_anchor_dir(), verbose = 0,
                                  compile = :auto)
        -> (; per_fit, anchor)

Parametric lifted solve (docs/research/plans/RATIONAL_PHASE3_BRIEF.md, B1.2/B1.3).
The lifted system `p − y q = 0, ∇p − y ∇q = 0` is built ONCE per shape `(n, M, N)`
with the monomial coefficients of `p` and `q` (over `SupportGen(n, (:one_d_for_all, M))`
and `(…, N)`) as HomotopyContinuation parameters. One generic complex anchor
`(θ₀, S₀)` is solved per shape and cached (module-level, keyed on `(n, M, N)`; the
orthogonal basis of a fit does not enter the family, only its conversion to
monomials), then each fit `(a, b)` in `fits` is a parameter homotopy from `θ₀` to
`vcat(a, b)` tracking exactly `C(n, M, N) = rational_generic_path_count(n, M, N)` paths.

`anchor`:
- `:monodromy` (default): `monodromy_solve` from a CONSTRUCTED seed (`x₀, y₀, b` random,
  `a` solved from the `n + 1` linear conditions) with `target_solutions_count = C` as the
  stopping rule — no start system at all, which is what makes `(8, 4)` run at `n ≥ 7`
  where the polyhedral start overflows, and is ≈ 10× cheaper than the polyhedral anchor at
  equal count (B1.0: 5.9 s vs 66 s on `(4,8,4)` = 4721; the five cold shapes of a 4-D
  shooting-tree chart cost 150 s polyhedral). Errors if monodromy stops short of `C`.
- `:polyhedral`: `solve` the family at a random complex `θ₀` with the polyhedral start
  (0 singular endpoints required). HC's polyhedral tracker loses a path now and then
  (80 of 81 on `(2,10,0)`, 88 of 89 on `(2,8,4)` in one audit run); a short start set
  is completed by `monodromy_solve` from the solutions found, with a `@warn`, and the
  anchor is then recorded as `:polyhedral_completed`. Still short after that: error.
  Kept as the independent check of `C`: monodromy can only stop AT `C`, the polyhedral
  start can also exceed it (`test_rational_pathcount.jl`).

`compile`: how HC represents the family — `:mixed` (HC's default, a compiled
straight-line program), `false` (interpreted), or `:auto` (default): interpreted when
the family has more than `_RAT_PARAM_COMPILE_MAX_PARAMS` = 2000 parameters. The compile
is serial codegen on one function the size of the family and grows faster than the
parameter count — (8,8,4), 13 365 parameters, had not finished after 10 h on cluster job
1104280 — while interpreted evaluation costs ~1.5–2× a compiled one per call.
Fixed once per shape and shared by the anchor and every track.

`anchor_dir` (`nothing` disables): the anchor of each shape is stored as
`<anchor_dir>/n<n>_M<M>_N<N>.jld2` and loaded on the next cold start, so an anchor
that took hours is paid once per machine.

Returns `per_fit::Vector{Tuple{sols, stats}}` in the order of `fits` — `sols` are the
real solutions (`Vector{Vector{Float64}}` of length `n + 1`), `stats` is
`(; start_system = :parametric, anchor, n_paths, n_solutions, n_singular, n_real,
n_path_failures, n_at_infinity, cache_hit, t_anchor, C, compile)` — and
`anchor = (; n_solutions, t_anchor, cache_hit, anchor, source)` with `source` one of
`:polyhedral`, `:monodromy`, `:disk`.

Implemented in GlobtimHomotopyContinuationExt — requires `using HomotopyContinuation`.
"""
function _solve_rational_hc_parametric(args...; kwargs...)
    error(
        "solve_rational_critical_points(method = :parametric) requires HomotopyContinuation.jl. " *
        "Add `using HomotopyContinuation` before calling.",
    )
end

# The cache lives in the HC extension; these dispatch on the loaded extension
# module (`nothing` when HomotopyContinuation is not loaded), so the source keeps
# a fallback without the extension overwriting a method at precompile time.
_rational_hc_ext() = Base.get_extension(@__MODULE__, :GlobtimHomotopyContinuationExt)

"""
    _rational_parametric_cache_info() -> (; n_shapes, hits, misses)

Hit/miss counters of the per-shape cache behind `_solve_rational_hc_parametric`
(a subdivision tree with 300 leaves of one shape should show 1 miss, 299 hits).
Without the HC extension the counters are all zero.
"""
_rational_parametric_cache_info() = _rational_parametric_cache_info(_rational_hc_ext())
_rational_parametric_cache_info(::Nothing) = (; n_shapes = 0, hits = 0, misses = 0)

"""
    _rational_parametric_cache_clear!()

Drop every compiled family and in-memory anchor (the on-disk store is untouched).
"""
_rational_parametric_cache_clear!() = _rational_parametric_cache_clear!(_rational_hc_ext())
_rational_parametric_cache_clear!(::Nothing) = nothing

"""
    _default_rational_anchor_dir() -> String

`_generated/rational_anchors` (relative to the working directory; gitignored). An
anchor worth keeping is promoted to `globtim_results/rational_anchors/` by hand with a
ledger record (brief, "Things to decide").
"""
_default_rational_anchor_dir() = joinpath("_generated", "rational_anchors")

_rational_anchor_path(dir::AbstractString, n::Int, M::Int, N::Int) =
    joinpath(dir, "n$(n)_M$(M)_N$(N).jld2")

"""
    _rational_anchor_save(dir, n, M, N; params, solutions, anchor, t_anchor) -> path

Write the anchor of shape `(n, M, N)` to `_rational_anchor_path(dir, n, M, N)`
atomically (temporary file, then `mv`). `solutions` is stored as an
`(n+1) × C` `ComplexF64` matrix.
"""
function _rational_anchor_save(
    dir::AbstractString,
    n::Int,
    M::Int,
    N::Int;
    params::AbstractVector,
    solutions::AbstractVector,
    anchor::Symbol,
    t_anchor::Real,
)
    mkpath(dir)
    path = _rational_anchor_path(dir, n, M, N)
    S =
        isempty(solutions) ? zeros(ComplexF64, n + 1, 0) :
        reduce(hcat, (Vector{ComplexF64}(s) for s in solutions))
    tmp = path * ".tmp-" * string(getpid())
    JLD2.jldsave(
        tmp;
        n = n,
        M = M,
        N = N,
        C = length(solutions),
        params = Vector{ComplexF64}(params),
        solutions = S,
        anchor = String(anchor),
        t_anchor = Float64(t_anchor),
        created = string(Dates.now()),
    )
    mv(tmp, path; force = true)
    return path
end

"""
    _rational_anchor_load(dir, n, M, N) -> NamedTuple or nothing

Read a stored anchor: `(; params, solutions, n_solutions, anchor, t_anchor)`, or
`nothing` when no file exists for the shape.
"""
function _rational_anchor_load(dir::AbstractString, n::Int, M::Int, N::Int)
    path = _rational_anchor_path(dir, n, M, N)
    isfile(path) || return nothing
    d = JLD2.load(path)
    (d["n"], d["M"], d["N"]) == (n, M, N) || error(
        "anchor file $path is for shape $((d["n"], d["M"], d["N"])), expected $((n, M, N))",
    )
    S = d["solutions"]
    sols = [Vector{ComplexF64}(S[:, j]) for j in 1:size(S, 2)]
    return (;
        params = Vector{ComplexF64}(d["params"]),
        solutions = sols,
        n_solutions = Int(d["C"]),
        anchor = Symbol(d["anchor"]),
        t_anchor = Float64(d["t_anchor"]),
    )
end

"""
    _coefficients_on_support(p, x, S) -> Vector{Float64}

Coefficients of the polynomial `p` (in the variables `x`) over the rows of the
exponent matrix `S`: entry `k` is the coefficient of `x^S[k, :]`, zero when `p` has no
such term. A term of `p` outside the support is an error (never dropped).
"""
function _coefficients_on_support(p, x::AbstractVector, S::AbstractMatrix{<:Integer})
    idx = Dict{Vector{Int},Int}(Vector{Int}(S[k, :]) => k for k in 1:size(S, 1))
    c = zeros(Float64, size(S, 1))
    for t in terms(p)
        m = monomial(t)
        α = [degree(m, x[i]) for i in 1:length(x)]
        k = get(idx, α, nothing)
        k === nothing && error(
            "monomial $m of $p lies outside the $(size(S, 1))-element support (degree $(maximum(sum(S; dims = 2); init = 0)))",
        )
        c[k] += Float64(coefficient(t))
    end
    return c
end

"""
    _rational_monomial_coefficients(R::ApproxRational) -> (; a, b, SM, SN)

Monomial coefficients of `p` and `q` of `R` over `SM = SupportGen(n, (:one_d_for_all, R.M)).data`
and `SN = SupportGen(n, (:one_d_for_all, R.N)).data` — the parameter vector
`vcat(a, b)` of the family solved by `_solve_rational_hc_parametric`. Goes through
`rational_critical_system` (exact basis conversion, then `Float64`).
"""
function _rational_monomial_coefficients(R::ApproxRational)
    n = size(R.grid, 2)
    sys = rational_critical_system(R)
    SM = SupportGen(n, (:one_d_for_all, R.M)).data
    SN = SupportGen(n, (:one_d_for_all, R.N)).data
    a = _coefficients_on_support(sys.p, sys.x, SM)
    b = _coefficients_on_support(sys.q, sys.x, SN)
    return (; a = a, b = b, SM = SM, SN = SN)
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
    rational_generic_path_count(n, M, N) -> Int

Number of isolated solutions of the lifted system p − y q = 0, ∇p − y ∇q = 0 for
a GENERIC rational function p/q of type (M, N) in `n` variables, i.e. the
number of critical points of a generic rational function of that type
(docs/research/plans/RATIONAL_PHASE3_BRIEF.md, B1.0). For M ≠ N it is also
the number of paths HC's polyhedral start tracks (the mixed volume, attained):

    C(n, M, N) = (M−1)^n + N · Σ_{k=1}^{n} (M−1)^{n−k} (N−1)^{k−1}      (M ≠ N)

It reproduces every ledgered polyhedral count — (8,4) in 2–6-D: 89, 659,
4 721, 33 371, 234 569; (6,3) at n = 6, 7, 8: 31 186, 156 122, 780 994 — and
gives M + N − 1 at n = 1.

For M = N the mixed volume is NOT attained: the top-degree coefficients of p and
q cancel (at n = 1, p′q − pq′ has degree 2M − 2, not 2M − 1) and the excess
paths go to infinity. The solution count is then

    C(n, M, M) = (n + 1) (M−1)^n                                        (M = N)

i.e. the formula above with the multiplier N replaced by N − 1. Measured by
polyhedral solves at (1,4,4), (2,3,3), (2,4,4), (3,4,4), (2,6,6), (3,6,6) and by
monodromy at (4,6,6) (3 125 of the formula's 3 625; cluster job 1203659, 2026-10-16).
This function returns the solution count, which is what the monodromy target and
the parametric solver's start set need; polyhedral `ntracked` exceeds it at M = N. The formula is a cost model: `M` sets the exponent,
`N` only the multiplier. `N = 0` is the polynomial case, (M−1)^n (the Bézout
count of ∇p = 0). Overflow-safe: computed in `Int128` and converted, so a
count above `typemax(Int)` raises instead of wrapping.
"""
function rational_generic_path_count(n::Integer, M::Integer, N::Integer)
    n >= 1 || throw(ArgumentError("n must be ≥ 1, got $n"))
    M >= 1 || throw(ArgumentError("M must be ≥ 1, got $M"))
    N >= 0 || throw(ArgumentError("N must be ≥ 0, got $N"))
    a, b = Int128(M - 1), Int128(N - 1)
    M == N && return Int((n + 1) * a^n)
    c = a^n
    if N > 0
        c += Int128(N) * sum(a^(n - k) * b^(k - 1) for k in 1:n)
    end
    return Int(c)
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
- `method = start_system`: `:polyhedral` or `:total_degree` solve the lifted system of
  this `R` from scratch (one HC compile per call); `:parametric` tracks the
  `rational_generic_path_count(n, M, N)` paths of a cached generic anchor of the shape
  `(n, M, N)` to this fit's coefficients (`_solve_rational_hc_parametric`): the family
  compiles once per shape, so a tree with hundreds of leaves of one shape pays the
  compile and the anchor once. Phase-3 brief B1.2; `:polyhedral` stays the default.
- `anchor = :monodromy` (`:parametric` only): how the shape's anchor is solved on a
  cold cache — `:monodromy` from a constructed seed (brief B1.3; ≈ 10× cheaper than the
  polyhedral anchor at equal count and the only route where that start overflows) or
  `:polyhedral` (the independent check of `C`). Ignored on a cache or disk hit.
- `anchor_dir = _default_rational_anchor_dir()` (`:parametric` only): on-disk anchor
  store, `nothing` to disable.
- `compile = :auto` (`:parametric` only): `:mixed` (compiled straight-line program, HC's
  default), `false` (interpreted) or `:auto` — interpreted above 2000 family parameters,
  where the serial compile runs for hours (see `_solve_rational_hc_parametric`).
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
- `n_path_failures`: paths HC gave up on (step size, iteration cap); 0 on every
  well-conditioned fit, and the brief's B1.2 test asserts it. Under `:parametric`
  the `C − n_solutions` remaining paths went to infinity (`stats.n_at_infinity`),
  which a non-generic fit (sparsified, degenerate leading coefficients) does legitimately.
- `n_outside`: real solutions outside the box.
- `raw`: every real solution as `(; x, y, q, status)` with status one of
  `:accepted`, `:outside`, `:q_zero`, `:y_mismatch`, so the audit can count them.
"""
function solve_rational_critical_points(
    R::ApproxRational;
    q_tol::Real = 1e-8,
    y_tol::Real = 1e-8,
    start_system::Symbol = :polyhedral,
    method::Symbol = start_system,
    anchor::Symbol = :monodromy,
    anchor_dir::Union{Nothing,AbstractString} = _default_rational_anchor_dir(),
    verbose::Int = 0,
    compile::Union{Symbol,Bool} = :auto,
)
    method in (:polyhedral, :total_degree, :parametric) || throw(
        ArgumentError(
            "method must be :polyhedral, :total_degree or :parametric, got $method",
        ),
    )
    anchor in (:polyhedral, :monodromy) ||
        throw(ArgumentError("anchor must be :polyhedral or :monodromy, got $anchor"))
    n = size(R.grid, 2)
    sols, stats = if method == :parametric
        coef = _rational_monomial_coefficients(R)
        out = _solve_rational_hc_parametric(
            n,
            R.M,
            R.N,
            [(coef.a, coef.b)];
            anchor = anchor,
            anchor_dir = anchor_dir,
            verbose = verbose,
            compile = compile,
        )
        out.per_fit[1]
    else
        sys = rational_critical_system(R)
        _solve_rational_hc(sys.eqs, sys.vars; start_system = method)
    end

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
        @info "solve_rational_critical_points ($method): $(stats.n_paths) paths, $(length(sols)) real, " *
              "$(length(points)) in box, $n_outside outside, $n_rejected_q with |q| ≤ $q_tol, " *
              "$n_inconsistent_y y-inconsistent, $(stats.n_singular) singular, " *
              "$(stats.n_path_failures) failed paths"
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
        n_path_failures = stats.n_path_failures,
        raw = raw,
        stats = stats,
    )
end

# ── positivity certificate for q ───────────────────────────────────────────────

"""
    certify_positive_denominator(R::ApproxRational; tau = 0.0, method = :recursion,
                                 face_samples = 41, start_system = :auto,
                                 bernstein_degree = R.N) -> NamedTuple

Decide whether `q > tau` on the closed box `[-1,1]^n`. Poincaré–Hopf holds for
`r = p/q` on the box only when `q` has no zero there, so this is a requirement of the
critical-point census, not a nicety.

`method`:

- `:recursion` (default) computes the minimum of `q` over the closed box exactly.
  The minimiser is a stationary point of `q` relative to the face of the box whose
  relative interior contains it, so the stationary points of `q` restricted to every
  one of the `3^n` faces (each coordinate fixed at −1 or +1, or free) are candidates.
  - `N ≤ 2`: `q(x) = c + gᵀx + ½xᵀHx` is read off `q` itself, and each face is one
    linear solve `H_FF x_F = −(g_F + H_FF̄ x_F̄)`. A face with singular `H_FF` is
    skipped: there the stationary set is affine and meets the face's boundary, so a
    lower face carries the same value.
  - `N ≥ 3` (only for `n ≤ 8`): one HomotopyContinuation solve of `∇_F q = 0` per
    face, on `q` in monomials (`rational_critical_system`). `exact = false` when a
    face solve reports singular endpoints (a degenerate or positive-dimensional
    stationary set, which HC does not enumerate); `ok` then stays `false`.
- `:bernstein`: `q > tau` proved when `bernstein_lower_bound(R; degree =
  bernstein_degree)` exceeds `tau`; `qmin` is that lower bound, not the minimum.
- `:sampling`: the interior stationary points plus a lattice of `face_samples`
  points per face coordinate on the `2n` facets. Not a proof: a minimum on a face
  between lattice points is missed (the Phase-1 stand-in).

Returns `(; ok, qmin, argmin, method, exact, n_interior_candidates,
n_boundary_samples, n_faces, n_singular_faces)` with `ok = exact && qmin > tau` and
`argmin` in surrogate coordinates (`NaN`s for `:bernstein`).
"""
function certify_positive_denominator(
    R::ApproxRational;
    tau::Real = 0.0,
    method::Symbol = :recursion,
    face_samples::Int = 41,
    start_system::Symbol = :auto,
    bernstein_degree::Int = R.N,
)
    n = size(R.grid, 2)
    if method == :recursion
        R.N <= 2 && return _certify_quadratic(R, tau)
        n <= 8 || throw(
            ArgumentError(
                "certify_positive_denominator: face recursion for N = $(R.N) solves one " *
                "HC system per face, 3^$n faces at n = $n; pass method = :bernstein (a " *
                "proof when its bound is positive) or :sampling (not a proof)",
            ),
        )
        return _certify_face_recursion(R, tau)
    elseif method == :bernstein
        lb = bernstein_lower_bound(R; degree = bernstein_degree)
        return (;
            ok = lb > tau,
            qmin = lb,
            argmin = fill(NaN, n),
            method = :bernstein,
            exact = true,
            n_interior_candidates = 0,
            n_boundary_samples = 0,
            n_faces = 0,
            n_singular_faces = 0,
        )
    elseif method == :sampling
        return _certify_sampling(R, tau, face_samples, start_system)
    end
    throw(ArgumentError("method must be :recursion, :bernstein or :sampling, got :$method"))
end

# q(x) = c + gᵀx + ½ xᵀHx for a q of degree ≤ 2, from values of q at 0, ±eᵢ and
# ±eᵢ ± eⱼ (identities that are exact for quadratics); checked at random points
function _denominator_quadratic_form(R::ApproxRational)
    n = size(R.grid, 2)
    qf(x) = rational_denominator(R, x)
    unit(i) = (v = zeros(n); v[i] = 1.0; v)
    c = qf(zeros(n))
    g = zeros(n)
    H = zeros(n, n)
    for i in 1:n
        qp, qm = qf(unit(i)), qf(-unit(i))
        g[i] = (qp - qm) / 2
        H[i, i] = qp + qm - 2c
    end
    for i in 1:n, j in (i+1):n
        v = zeros(n)
        v[i] = 1.0
        v[j] = 1.0
        a = qf(v)
        v[j] = -1.0
        b = qf(v)
        v[i] = -1.0
        d = qf(v)
        v[j] = 1.0
        e = qf(v)
        H[i, j] = H[j, i] = (a - b - e + d) / 4
    end
    rng = Random.Xoshiro(0)
    for _ in 1:5
        x = 2 .* rand(rng, n) .- 1
        v = qf(x)
        abs(v - (c + dot(g, x) + dot(x, H * x) / 2)) <=
        1e-9 * max(1.0, abs(c), norm(g), opnorm(H)) || error(
            "_denominator_quadratic_form: q of degree N = $(R.N) is not reproduced by its quadratic form",
        )
    end
    return c, g, H
end

"""
    _box_min_quadratic(c, g, H) -> (qmin, argmin, n_interior)

Exact minimum of `c + gᵀx + ½xᵀHx` over `[-1,1]^n`: the stationary point relative
to each of the `3^n` faces (coordinates fixed at ±1 or free), one linear solve per
face; faces with singular `H_FF` are skipped (their stationary set is affine and
reaches a lower face, which carries the same value).
"""
function _box_min_quadratic(c::Real, g::AbstractVector, H::AbstractMatrix)
    n = length(g)
    n <= 16 ||
        throw(ArgumentError("face recursion enumerates 3^n faces; n = $n is too large"))
    quad(x) = c + dot(g, x) + dot(x, H * x) / 2
    qmin = Inf
    argmin = fill(NaN, n)
    n_interior = 0
    digits_ = zeros(Int, n)     # per coordinate: 0 free, 1 fixed at −1, 2 fixed at +1
    x = zeros(n)
    for code in 0:(3^n-1)
        k = code
        for i in 1:n
            digits_[i] = k % 3
            k ÷= 3
        end
        for i in 1:n
            x[i] = digits_[i] == 1 ? -1.0 : digits_[i] == 2 ? 1.0 : 0.0
        end
        free = findall(==(0), digits_)
        if !isempty(free)
            fixed = findall(!=(0), digits_)
            fac = lu(H[free, free]; check = false)
            issuccess(fac) || continue
            y = fac \ (-(g[free] .+ H[free, fixed] * x[fixed]))
            all(abs.(y) .<= 1 + 1e-12) || continue
            x[free] .= clamp.(y, -1.0, 1.0)
            length(free) == n && (n_interior += 1)
        end
        v = quad(x)
        if v < qmin
            qmin = v
            argmin = copy(x)
        end
    end
    return qmin, argmin, n_interior
end

function _certify_quadratic(R::ApproxRational, tau::Real)
    n = size(R.grid, 2)
    c, g, H = _denominator_quadratic_form(R)
    _, argmin, n_interior = _box_min_quadratic(c, g, H)
    # report the value of q itself at the minimiser, not of its reconstruction
    qmin = rational_denominator(R, argmin)
    return (;
        ok = qmin > tau,
        qmin = qmin,
        argmin = argmin,
        method = :recursion,
        exact = true,
        n_interior_candidates = n_interior,
        n_boundary_samples = 0,
        n_faces = 3^n,
        n_singular_faces = 0,
    )
end

function _certify_face_recursion(R::ApproxRational, tau::Real)
    n = size(R.grid, 2)
    sys = rational_critical_system(R)
    q, xv = sys.q, sys.x
    qmin = Inf
    argmin = fill(NaN, n)
    n_interior = 0
    n_singular_faces = 0
    digits_ = zeros(Int, n)
    for code in 0:(3^n-1)
        k = code
        for i in 1:n
            digits_[i] = k % 3
            k ÷= 3
        end
        base = [d == 1 ? -1.0 : d == 2 ? 1.0 : 0.0 for d in digits_]
        free = findall(==(0), digits_)
        candidates = Vector{Vector{Float64}}()
        if isempty(free)
            push!(candidates, base)
        else
            fixed = findall(!=(0), digits_)
            qF = isempty(fixed) ? q : subs(q, (xv[j] => base[j] for j in fixed)...)
            eqs = [differentiate(qF, xv[i]) for i in free]
            # a free coordinate q does not depend on: the stationary set is a line
            # through the face, and a lower face carries its value
            any(iszero, eqs) && continue
            # a nonzero constant equation: no stationary point on this face
            any(e -> maxdegree(e) == 0, eqs) && continue
            sols, st = _solve_rational_hc(
                eqs,
                xv[free];
                start_system = :total_degree,
                compile = false,
            )
            st.n_singular > 0 && (n_singular_faces += 1)
            for s in sols
                y = Vector{Float64}(real.(s))
                all(abs.(y) .<= 1 + 1e-10) || continue
                p = copy(base)
                p[free] .= clamp.(y, -1.0, 1.0)
                push!(candidates, p)
                length(free) == n && (n_interior += 1)
            end
        end
        for p in candidates
            v = rational_denominator(R, p)
            if v < qmin
                qmin = v
                argmin = p
            end
        end
    end
    exact = n_singular_faces == 0
    return (;
        ok = exact && qmin > tau,
        qmin = qmin,
        argmin = argmin,
        method = :recursion,
        exact = exact,
        n_interior_candidates = n_interior,
        n_boundary_samples = 0,
        n_faces = 3^n,
        n_singular_faces = n_singular_faces,
    )
end

# the Phase-1 stand-in: interior stationary points plus a facet lattice
function _certify_sampling(
    R::ApproxRational,
    tau::Real,
    face_samples::Int,
    start_system::Symbol,
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
        method = :sampling,
        exact = false,
        n_interior_candidates = length(candidates),
        n_boundary_samples = n_boundary,
        n_faces = 0,
        n_singular_faces = 0,
    )
end
