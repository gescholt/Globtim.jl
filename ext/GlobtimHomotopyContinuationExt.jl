module GlobtimHomotopyContinuationExt

using Globtim
using HomotopyContinuation:
    solve, real_solutions, System, solutions, nsolutions, ntracked, nsingular, nfailed,
    nat_infinity, nparameters, monodromy_solve, @var
import HomotopyContinuation   # for HomotopyContinuation.differentiate (parametric path)
using MultivariatePolynomials: differentiate   # cold path: differentiate DynamicPolynomials
using LinearAlgebra: norm, pinv
using Random: Xoshiro, randn

function Globtim._solve_hc(
    x,
    n,
    d,
    coeffs;
    basis,
    precision,
    normalized,
    power_of_two_denom,
    return_system,
    start_system,
    path_stats_ref::Union{Nothing,Base.RefValue{Any}} = nothing,
)
    pol = Globtim.main_nd(
        x,
        n,
        d,
        coeffs;
        basis = basis,
        precision = precision,
        normalized = normalized,
        power_of_two_denom = power_of_two_denom,
    )

    # :auto picks :polyhedral for n >= 3 (mixed volume << Bezout bound for sparse systems)
    actual_start = if start_system == :auto
        n >= 3 ? :polyhedral : :total_degree
    else
        start_system
    end

    grad = differentiate.(pol, x)
    sys = System(grad)
    hc_result = solve(sys, start_system = actual_start, show_progress = false)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)

    # Out-channel for solve statistics: how many paths the chosen
    # start system actually tracked, vs solutions found. Filled only when the
    # caller passes a Ref — the return contract is unchanged.
    if path_stats_ref !== nothing
        path_stats_ref[] = (;
            start_system = actual_start,
            paths_tracked = ntracked(hc_result),
            n_solutions = nsolutions(hc_result),
            n_singular = nsingular(hc_result),
            n_real = length(rl_sol),
        )
    end

    if return_system
        return rl_sol, (pol, sys, Int(length(hc_result)))
    else
        return rl_sol
    end
end

# Lifted rational critical-point system (rational_solver.jl): a square system
# in the n+1 variables vcat(x, [y]), passed in explicitly. New method, leaves
# _solve_hc untouched (docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md, B2).
function Globtim._solve_rational_hc(
    eqs::AbstractVector,
    vars::AbstractVector;
    start_system::Symbol = :polyhedral,
    compile::Union{Nothing,Bool,Symbol} = nothing,
)
    sys = System(eqs; variables = vars)
    # compile = false interprets the system instead of compiling a straight-line
    # program: the denominator certificate solves one small system per face of
    # the box, where compilation would dominate; nothing keeps HC's default
    ckw = compile === nothing ? (;) : (; compile = compile)
    hc_result = solve(sys; start_system = start_system, show_progress = false, ckw...)
    rl_sol = real_solutions(hc_result; only_real = true, multiple_results = false)
    stats = (;
        start_system = start_system,
        n_paths = ntracked(hc_result),
        n_solutions = nsolutions(hc_result),
        n_singular = nsingular(hc_result),
        n_real = length(rl_sol),
        n_path_failures = nfailed(hc_result),
        n_at_infinity = nat_infinity(hc_result),
    )
    return rl_sol, stats
end

# ── parametric lifted solve (Phase-3 brief B1.2 / B1.3) ──────────────────────
#
# One compiled family per shape (n, M, N): the lifted system with the monomial
# coefficients of p and q as HC parameters, plus a generic complex anchor
# (θ₀, S₀) with |S₀| = C(n, M, N). A fit is then a parameter homotopy θ₀ → θ
# tracking exactly C paths — no start system, no recompile. The cache is
# module-level and guarded by a lock (tree leaves may be solved from threads).

const _RAT_PARAM_LOCK = ReentrantLock()
const _RAT_PARAM_CACHE = Dict{Tuple{Int,Int,Int},Any}()
const _RAT_PARAM_HITS = Ref(0)
const _RAT_PARAM_MISSES = Ref(0)

Globtim._rational_parametric_cache_info(::Module) = lock(_RAT_PARAM_LOCK) do
    (; n_shapes = length(_RAT_PARAM_CACHE), hits = _RAT_PARAM_HITS[], misses = _RAT_PARAM_MISSES[])
end

Globtim._rational_parametric_cache_clear!(::Module) = lock(_RAT_PARAM_LOCK) do
    empty!(_RAT_PARAM_CACHE)
    _RAT_PARAM_HITS[] = 0
    _RAT_PARAM_MISSES[] = 0
    nothing
end

"""
    _rational_family(n, SM, SN) -> System

The lifted system `p − y q, ∂ᵢp − y ∂ᵢq` in `vcat(x, [y])` with the monomial
coefficients `a` (over the rows of `SM`) and `b` (rows of `SN`) as parameters.
"""
function _rational_family(n::Int, SM::AbstractMatrix{<:Integer}, SN::AbstractMatrix{<:Integer})
    @var x[1:n] y
    @var a[1:size(SM, 1)] b[1:size(SN, 1)]
    xv = collect(x)
    mono(α) = prod(xv[i]^Int(α[i]) for i in 1:n)
    p = sum(a[k] * mono(SM[k, :]) for k in 1:size(SM, 1))
    q = sum(b[k] * mono(SN[k, :]) for k in 1:size(SN, 1))
    eqs = vcat(
        p - y * q,
        [
            HomotopyContinuation.differentiate(p, xv[i]) -
            y * HomotopyContinuation.differentiate(q, xv[i]) for i in 1:n
        ],
    )
    return System(eqs; variables = vcat(xv, [y]), parameters = vcat(collect(a), collect(b)))
end

"""
    _rational_constructed_seed(rng, n, SM, SN) -> (; params, sol)

A solution of the family by construction (brief B1.3): `x₀, y₀, b` random complex,
then `a` is a solution of the `n + 1` linear conditions `p(x₀) = y₀ q(x₀)`,
`∇p(x₀) = y₀ ∇q(x₀)`; the least-norm correction of a random `a` keeps it generic.
"""
function _rational_constructed_seed(rng, n::Int, SM::AbstractMatrix{<:Integer}, SN::AbstractMatrix{<:Integer})
    x0 = randn(rng, ComplexF64, n)
    y0 = randn(rng, ComplexF64)
    b = randn(rng, ComplexF64, size(SN, 1))
    monoval(α, x) = prod(x[i]^Int(α[i]) for i in 1:n)
    dmono(α, x, j) =
        α[j] == 0 ? zero(ComplexF64) :
        α[j] * prod(x[i]^Int(α[i] - (i == j)) for i in 1:n)
    A = Matrix{ComplexF64}(undef, n + 1, size(SM, 1))
    B = Matrix{ComplexF64}(undef, n + 1, size(SN, 1))
    for k in 1:size(SM, 1)
        α = SM[k, :]
        A[1, k] = monoval(α, x0)
        for j in 1:n
            A[j+1, k] = dmono(α, x0, j)
        end
    end
    for k in 1:size(SN, 1)
        β = SN[k, :]
        B[1, k] = monoval(β, x0)
        for j in 1:n
            B[j+1, k] = dmono(β, x0, j)
        end
    end
    rhs = y0 .* (B * b)
    a_rand = randn(rng, ComplexF64, size(SM, 1))
    a = a_rand + pinv(A) * (rhs - A * a_rand)
    norm(A * a - rhs) < 1e-8 * (1 + norm(rhs)) ||
        error("constructed monodromy seed does not satisfy the lifted system (residual $(norm(A * a - rhs)))")
    return (; params = vcat(a, b), sol = vcat(x0, [y0]))
end

"""
    _rational_anchor(n, M, N, F, SM, SN; anchor, anchor_dir, verbose) -> NamedTuple

The shape's anchor `(; params, solutions, C, t_anchor, anchor, source)`: loaded from
`anchor_dir` when stored there, else solved (`:polyhedral` start at a random complex
parameter, or `:monodromy` from a constructed seed with `target_solutions_count = C`)
and stored. The solution count must equal `C(n, M, N)`: a polyhedral start that loses
paths (it does, once in a while — 80 of 81 on (2,10,0) at a random complex parameter)
is completed by `monodromy_solve` from the solutions it did find, with a `@warn` and
`anchor = :polyhedral_completed` in the record; an anchor still short of `C` after that
is an error, never a silently deficient start set.
"""
function _rational_anchor(n::Int, M::Int, N::Int, F, SM, SN; anchor::Symbol, anchor_dir, verbose::Int)
    C = Globtim.rational_generic_path_count(n, M, N)
    if anchor_dir !== nothing
        stored = Globtim._rational_anchor_load(anchor_dir, n, M, N)
        if stored !== nothing
            stored.n_solutions == C || error(
                "stored anchor $(Globtim._rational_anchor_path(anchor_dir, n, M, N)) has " *
                "$(stored.n_solutions) solutions but C($n,$M,$N) = $C; delete the file to re-solve",
            )
            verbose >= 1 && @info "rational anchor ($n,$M,$N): loaded $C solutions from $anchor_dir"
            return (;
                params = stored.params,
                solutions = stored.solutions,
                C = C,
                t_anchor = stored.t_anchor,
                anchor = stored.anchor,
                source = :disk,
            )
        end
    end
    # deterministic per shape: the same anchor on every machine, so a stored
    # anchor and a freshly solved one are the same start set
    rng = Xoshiro(hash((n, M, N, :rational_anchor)))
    local θ0, S0
    anchor_kind = anchor
    t = @elapsed begin
        if anchor == :polyhedral
            θ0 = randn(rng, ComplexF64, nparameters(F))
            R0 = solve(F; target_parameters = θ0, start_system = :polyhedral, show_progress = false)
            S0 = solutions(R0)
            nsingular(R0) == 0 || error(
                "polyhedral anchor for shape ($n,$M,$N) has $(nsingular(R0)) singular endpoints " *
                "(tracked $(ntracked(R0)), C = $C); the anchor is not generic — retry or use anchor = :monodromy",
            )
            if length(S0) < C
                # a lost path (nfailed > 0) at a generic parameter: the solution set is
                # still C points, monodromy from the ones found fills in the rest
                @warn "polyhedral anchor for shape ($n,$M,$N): $(length(S0)) of C = $C solutions " *
                      "($(nfailed(R0)) failed paths, $(nat_infinity(R0)) at infinity); completing by monodromy"
                Rm = monodromy_solve(
                    F,
                    S0,
                    θ0;
                    target_solutions_count = C,
                    show_progress = false,
                    max_loops_no_progress = 20,
                )
                S0 = solutions(Rm)
                anchor_kind = :polyhedral_completed
            end
        elseif anchor == :monodromy
            seed = _rational_constructed_seed(rng, n, SM, SN)
            Rm = monodromy_solve(
                F,
                [seed.sol],
                seed.params;
                target_solutions_count = C,
                show_progress = false,
                max_loops_no_progress = 20,
            )
            θ0 = seed.params
            S0 = solutions(Rm)
        else
            throw(ArgumentError("anchor must be :polyhedral or :monodromy, got $anchor"))
        end
    end
    length(S0) == C || error(
        "$anchor_kind anchor for shape ($n,$M,$N) reached $(length(S0)) solutions, the generic count is " *
        "C($n,$M,$N) = $C (brief B1.0 gate); the start set would be deficient — not cached",
    )
    verbose >= 1 && @info "rational anchor ($n,$M,$N): $anchor_kind, $C solutions in $(round(t; digits = 2)) s"
    anchor_dir !== nothing && Globtim._rational_anchor_save(
        anchor_dir, n, M, N; params = θ0, solutions = S0, anchor = anchor_kind, t_anchor = t,
    )
    return (; params = θ0, solutions = S0, C = C, t_anchor = t, anchor = anchor_kind, source = anchor)
end

function Globtim._solve_rational_hc_parametric(
    n::Int,
    M::Int,
    N::Int,
    fits::AbstractVector;
    anchor::Symbol = :polyhedral,
    anchor_dir::Union{Nothing,AbstractString} = Globtim._default_rational_anchor_dir(),
    verbose::Int = 0,
)
    key = (n, M, N)
    entry, hit = lock(_RAT_PARAM_LOCK) do
        if haskey(_RAT_PARAM_CACHE, key)
            _RAT_PARAM_HITS[] += 1
            (_RAT_PARAM_CACHE[key], true)
        else
            SM = Globtim.SupportGen(n, (:one_d_for_all, M)).data
            SN = Globtim.SupportGen(n, (:one_d_for_all, N)).data
            F = _rational_family(n, SM, SN)
            anc = _rational_anchor(n, M, N, F, SM, SN; anchor = anchor, anchor_dir = anchor_dir, verbose = verbose)
            e = (; F = F, SM = SM, SN = SN, anc...)
            _RAT_PARAM_CACHE[key] = e
            _RAT_PARAM_MISSES[] += 1
            (e, false)
        end
    end
    na, nb = size(entry.SM, 1), size(entry.SN, 1)
    per_fit = Vector{Tuple{Vector{Vector{Float64}},NamedTuple}}(undef, length(fits))
    for (j, (a, b)) in enumerate(fits)
        length(a) == na && length(b) == nb || throw(
            ArgumentError("fit $j has $(length(a)) + $(length(b)) coefficients; shape ($n,$M,$N) needs $na + $nb"),
        )
        Rj = solve(
            entry.F,
            entry.solutions;
            start_parameters = entry.params,
            target_parameters = vcat(a, b),
            show_progress = false,
        )
        rl = real_solutions(Rj; only_real = true, multiple_results = false)
        stats = (;
            start_system = :parametric,
            anchor = entry.anchor,
            n_paths = ntracked(Rj),
            n_solutions = nsolutions(Rj),
            n_singular = nsingular(Rj),
            n_real = length(rl),
            n_path_failures = nfailed(Rj),
            n_at_infinity = nat_infinity(Rj),
            cache_hit = hit,
            t_anchor = entry.t_anchor,
            C = entry.C,
        )
        per_fit[j] = (rl, stats)
    end
    return (;
        per_fit = per_fit,
        anchor = (;
            n_solutions = entry.C,
            t_anchor = entry.t_anchor,
            cache_hit = hit,
            anchor = entry.anchor,
            source = entry.source,
        ),
    )
end

function Globtim._solve_hc_parametric(
    support::AbstractMatrix,
    n::Int,
    cell_coeffs::Vector{Vector{Float64}},
)
    m = size(support, 1)
    @var x[1:n]
    @var a[1:m]
    xv = collect(x)
    av = collect(a)

    # p(x; a) = Σ_k a_k · x^support[k,:]  (monomial basis; coefficients are the parameters)
    monos = [prod(xv[i]^Int(support[k, i]) for i in 1:n) for k in 1:m]
    p = sum(av[k] * monos[k] for k in 1:m)
    grad = [HomotopyContinuation.differentiate(p, xv[i]) for i in 1:n]
    F = System(grad; variables = xv, parameters = av)

    # Generic-complex anchor: required (a real anchor is measure-zero and can be
    # path-deficient). Gives the full Bezout solution set to track from.
    a0 = randn(ComplexF64, m)
    R0 = solve(F; target_parameters = a0, show_progress = false)
    S0 = solutions(R0)
    anchor_n = length(S0)

    per_cell = Vector{Tuple{Vector{Vector{Float64}},NTuple{3,Int}}}()
    for cc in cell_coeffs
        Rj = solve(
            F,
            S0;
            start_parameters = a0,
            target_parameters = cc,
            show_progress = false,
        )
        rl = real_solutions(Rj; only_real = true, multiple_results = false)
        push!(per_cell, (rl, (length(S0), nsolutions(Rj), length(rl))))
    end

    return (; anchor_n = anchor_n, per_cell = per_cell)
end

end # module
