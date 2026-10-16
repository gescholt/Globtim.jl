# chebyshev_gradient_system.jl — HomotopyContinuation.jl AbstractSystem for ∇p = 0
# evaluated natively in the Chebyshev basis (src/chebyshev_eval.jl), and the parameter
# homotopy over the coefficient vector that makes every fit with the same support a
# continuation from one generic anchor. CHEBYSHEV_NATIVE_HC_PLAN.md §2, Phase 1.
#
# Included at the end of GlobtimHomotopyContinuationExt.jl. The interface HC 2.22 needs
# from a custom system (model_kit/abstract_system_homotopy.jl, predictor.jl):
#   Base.size(F)                                  (n, n)
#   ModelKit.nparameters(F)                       m (coefficients are the parameters)
#   ModelKit.evaluate!(u, F, x, p)                u ← ∇p(x; c = p)
#   ModelKit.evaluate_and_jacobian!(u, U, F, x, p) U ← ∇²p(x; p)
#   ModelKit.taylor!(u, Val(M), F, tx, p)         u ← order-M Taylor coefficient of
#                                                 ∇p(x(t); c(t)); tx holds x's lower
#                                                 orders, p is the ParameterHomotopy's
#                                                 (pt, p − q) series
# The tracker calls the system with ComplexF64 and, in its mixed-precision refinement,
# ComplexDF64 vectors; the kernels are generic in the element type.

using HomotopyContinuation: AbstractSystem, ModelKit, TaylorVector, TruncatedTaylorSeries

struct ChebyshevGradientSystem <: AbstractSystem
    kernel::Globtim.ChebyshevGradientKernel
end

ChebyshevGradientSystem(pol::Globtim.ApproxPoly) =
    ChebyshevGradientSystem(Globtim.ChebyshevGradientKernel(pol))

Base.size(F::ChebyshevGradientSystem) = (F.kernel.n, F.kernel.n)
# HC's solve / monodromy entry points ask a system for its symbolic variables and
# parameters (names only; the evaluation never touches them)
ModelKit.variables(F::ChebyshevGradientSystem) = [ModelKit.Variable(:x, i) for i in 1:F.kernel.n]
ModelKit.parameters(F::ChebyshevGradientSystem) = [ModelKit.Variable(:c, r) for r in 1:F.kernel.m]
ModelKit.nparameters(F::ChebyshevGradientSystem) = F.kernel.m

function ModelKit.evaluate!(u, F::ChebyshevGradientSystem, x, p = nothing)
    p === nothing && error("ChebyshevGradientSystem needs the coefficient vector as parameters")
    Globtim.evaluate!(u, F.kernel, x, p)
    return u
end

function ModelKit.evaluate_and_jacobian!(u, U, F::ChebyshevGradientSystem, x, p = nothing)
    p === nothing && error("ChebyshevGradientSystem needs the coefficient vector as parameters")
    Globtim.evaluate_and_jacobian!(u, U, F.kernel, x, p)
    return nothing
end

# Taylor terms of a vector argument: a plain vector is a 1-term series, a TaylorVector
# carries its terms per entry, a TruncatedTaylorSeries likewise.
_terms(v::AbstractVector{<:Number}) = [(v[i],) for i in eachindex(v)]
_terms(v::TaylorVector) = [Tuple(v[i].val) for i in 1:length(v)]
_terms(v::AbstractVector{<:TruncatedTaylorSeries}) = [Tuple(v[i].val) for i in eachindex(v)]

function ModelKit.taylor!(
    u,
    v::Val{M},
    F::ChebyshevGradientSystem,
    tx,
    p = nothing;
    assign_highest_order_only::Bool = u isa Vector,
) where {M}
    p === nothing && error("ChebyshevGradientSystem needs the coefficient vector as parameters")
    xt = _terms(tx)
    ct = _terms(p)
    w = Globtim.taylor_series(v, F.kernel, xt, ct)
    if assign_highest_order_only
        for k in 1:F.kernel.n
            u[k] = w[k][M]
        end
    else
        for k in 1:F.kernel.n
            u[k] = w[k].a
        end
    end
    return u
end

# ── anchor cache ─────────────────────────────────────────────────────────────
#
# One generic anchor per support: a random complex coefficient vector c₀ (unit norm,
# in the null space of A(x₀) so that a random x₀ is a critical point) and ALL its
# critical points from monodromy. Every fit on that support is then one parameter
# homotopy c₀ → c. Keyed by the support matrix; guarded by a lock (leaves are solved
# from threads).

const _CHEB_ANCHOR_LOCK = ReentrantLock()
const _CHEB_ANCHOR_CACHE = Dict{Matrix{Int},Any}()

# generic critical-point count of a total-degree support: (d−1)^n; nothing otherwise
function _cheb_generic_count(K::Globtim.ChebyshevGradientKernel)
    d = maximum(sum(K.support, dims = 2))
    return K.m == binomial(K.n + d, K.n) ? (d - 1)^K.n : nothing
end

"""
    chebyshev_anchor(K::ChebyshevGradientKernel; rng, target_count, max_loops_no_progress)
        -> (c0, S0, n_expected, monodromy_result)

Solve the generic member of the family once by monodromy on the Chebyshev-native
system, starting from the constructed pair `(x₀, c₀)` with `A(x₀) c₀ = 0`.
`target_count` defaults to `(d−1)^n` on a total-degree support (`nothing` otherwise:
monodromy then stops on its own no-progress rule).
"""
function chebyshev_anchor(
    K::Globtim.ChebyshevGradientKernel;
    rng = Xoshiro(20261016),
    target_count = _cheb_generic_count(K),
    max_loops_no_progress::Int = 10,
)
    F = ChebyshevGradientSystem(K)
    # Start point inside the box with a small imaginary part: generic for monodromy (a
    # nonsingular Jacobian is all it needs) and keeps T_j(x₀) of order one. A point of
    # modulus > 1 makes T_j grow like |x₀|^j — 1e5 at degree 16 — and the projected pair's
    # residual then only vanishes relative to that scale (korok 1113956 failed here).
    x0 = complex.(2 .* rand(rng, K.n) .- 1, 0.05 .* randn(rng, K.n))
    A = Globtim.gradient_basis_matrix(K, x0)
    c = randn(rng, ComplexF64, K.m)
    c0 = c .- pinv(A) * (A * c)
    c0 ./= norm(c0)
    # the constructed pair must satisfy the system, relative to the gradient scale ‖A‖‖c₀‖
    u0 = zeros(ComplexF64, K.n)
    Globtim.evaluate!(u0, K, x0, c0)
    scale = max(1.0, opnorm(A) * norm(c0))
    norm(u0) <= 1e-9 * scale ||
        error("chebyshev_anchor: constructed start pair has residual $(norm(u0)) against scale $scale")
    R = monodromy_solve(
        F,
        [x0],
        c0;
        target_solutions_count = target_count,
        max_loops_no_progress = max_loops_no_progress,
        show_progress = false,
        threading = false,
    )
    S0 = solutions(R)
    if target_count !== nothing && length(S0) != target_count
        @warn "chebyshev_anchor: monodromy found $(length(S0)) of the expected $target_count critical points on this support"
    end
    return (c0 = c0, S0 = S0, n_expected = target_count, result = R)
end

function _cheb_anchor_cached(K::Globtim.ChebyshevGradientKernel; kwargs...)
    lock(_CHEB_ANCHOR_LOCK)
    try
        a = get(_CHEB_ANCHOR_CACHE, K.support, nothing)
        a === nothing || return a
    finally
        unlock(_CHEB_ANCHOR_LOCK)
    end
    a = chebyshev_anchor(K; kwargs...)
    lock(_CHEB_ANCHOR_LOCK)
    try
        _CHEB_ANCHOR_CACHE[copy(K.support)] = a
    finally
        unlock(_CHEB_ANCHOR_LOCK)
    end
    return a
end

"""
    Globtim._solve_hc_chebyshev(pol::ApproxPoly; anchor = nothing, path_stats_ref = nothing)
        -> Vector{Vector{Float64}}

Same contract as `_solve_hc` (real solutions in box coordinates, raw): the
`ChebyshevGradientSystem` on `pol.support`, the cached anchor of that support, the
parameter homotopy `c₀ → pol.coeffs`, real solutions, and `path_stats_ref` filled with
`(start_system = :chebyshev_anchor, paths_tracked, n_solutions, n_singular, n_real,
n_path_failures, n_at_infinity, cond_jacobian_median, anchor_n, anchor_expected)`.
No monomial polynomial is formed.
"""
function Globtim._solve_hc_chebyshev(
    pol::Globtim.ApproxPoly;
    anchor = nothing,
    path_stats_ref::Union{Nothing,Base.RefValue{Any}} = nothing,
    max_abs_coordinate::Real = 1e3,
)
    K = Globtim.ChebyshevGradientKernel(pol)
    a = anchor === nothing ? _cheb_anchor_cached(K) : anchor
    F = ChebyshevGradientSystem(K)
    target = ComplexF64.(pol.coeffs)
    R = solve(
        F,
        a.S0;
        start_parameters = a.c0,
        target_parameters = target,
        show_progress = false,
    )
    rl_all = real_solutions(R; only_real = true, multiple_results = false)
    # A fit whose top coefficients nearly vanish has fewer finite critical points than the
    # generic member of its support: the surplus paths run off to infinity and come back
    # from the endgame as huge finite points (|x| ~ 1e4 in box coordinates on Rosenbrock
    # at degree 4). They are not critical points of anything inside the box; drop them
    # the way the total-degree / polyhedral endgame drops its paths at infinity.
    rl = [s for s in rl_all if maximum(abs, s) <= max_abs_coordinate]
    n_far = length(rl_all) - length(rl)
    if path_stats_ref !== nothing
        conds = Float64[]
        u = zeros(Float64, K.n)
        U = zeros(Float64, K.n, K.n)
        for s in rl
            Globtim.evaluate_and_jacobian!(u, U, K, s, pol.coeffs)
            push!(conds, cond(U))
        end
        path_stats_ref[] = (;
            start_system = :chebyshev_anchor,
            paths_tracked = ntracked(R),
            n_solutions = nsolutions(R),
            n_singular = nsingular(R),
            n_real = length(rl),
            n_path_failures = nfailed(R),
            n_at_infinity = nat_infinity(R),
            n_far = n_far,
            cond_jacobian_median = isempty(conds) ? NaN : sort(conds)[(length(conds)+1)÷2],
            anchor_n = length(a.S0),
            anchor_expected = a.n_expected,
        )
    end
    return rl
end
