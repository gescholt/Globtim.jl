# analyticity.jl
#
# N7 of docs/research/plans/EVIDENCE_MAP_2026-10.md: an analyticity detector read off the
# Chebyshev coefficient envelope of a fit, per axis.
#
# For f analytic on the box the Chebyshev coefficients along an axis decay geometrically,
# |c_k| ≲ M ρ^{-k} with ρ > 1 the Bernstein-ellipse parameter (Trefethen, Approximation
# Theory and Approximation Practice, Thm 8.1): log|c_k| is a LINE in k. A kink, a |·|, a
# plateau edge or a penalty wall inside the box gives algebraic decay |c_k| ~ k^{-ν}
# (ν = 2 for a kink, 1 for a jump; Thm 7.1 there): log|c_k| is a line in log k, concave in
# k, with a per-degree ratio that rises towards 1. Adding degrees to such a fit buys
# nothing (the porkchop Δv sweep: rel-L2 0.09 → 0.18 → 0.17 at d = 8/12/16,
# `pkg/Astrodynamics/.claude/CLAUDE.md`; SIR-2D non-monotone in degree) — the right move
# is a subdivision along that axis or a reformulation, and this detector names the axis.
#
# Two triggers, either suffices on an axis with enough resolved coefficients:
#   (a) the algebraic model fits the envelope above its noise floor clearly better than
#       the geometric one (RSS ratio ≤ `model_ratio`);
#   (b) the geometric ratio per degree is ≥ `rate_threshold` with no noise plateau found
#       (the evidence map's "ρ ≳ 0.9/degree with no plateau").
# Parity: an even or odd function has exactly vanishing coefficients of the other parity;
# entries below `rel_floor · max` are dropped before fitting so those zeros (and the
# least-squares noise that stands in for them) do not masquerade as a plateau.

"""
    AnalyticityVerdict

Result of [`analyticity_verdict`](@ref). `verdict` is `:analytic`, `:non_analytic` or
`:undetermined` (no axis had `min_points` resolved coefficients). Per axis:
`decay_rate` (geometric ratio per degree, `NaN` when unresolved), `algebraic_exponent`
(the ν of `k^{-ν}`, `NaN` when unresolved), `model_rss_ratio` (algebraic RSS over
geometric RSS; small means algebraic), `plateau_found`, `n_points` used, and `offending`
(the axis trips a trigger). `suggested_axis` is the offending axis with the slowest decay,
`0` when none — the hand-off to a subdivision along that axis.
"""
struct AnalyticityVerdict
    verdict::Symbol
    decay_rate::Vector{Float64}
    algebraic_exponent::Vector{Float64}
    model_rss_ratio::Vector{Float64}
    plateau_found::Vector{Bool}
    n_points::Vector{Int}
    offending::Vector{Bool}
    suggested_axis::Int
    rate_threshold::Float64
    model_ratio::Float64
end

"""
    axis_analyticity(envelope; rate_threshold = 0.9, model_ratio = 0.5, min_points = 5,
                     rel_floor = 1e-12, kwargs...) -> NamedTuple

One axis of [`analyticity_verdict`](@ref): `envelope[k+1] = max |c_α|` over `α_i = k`.
Returns `(resolved, offending, decay_rate, algebraic_exponent, model_rss_ratio,
plateau_found, n_points)`. `kwargs` go to [`estimate_noise_floor`](@ref).
"""
function axis_analyticity(
    envelope::AbstractVector{<:Real};
    rate_threshold::Real = 0.9,
    model_ratio::Real = 0.5,
    min_points::Int = 5,
    rel_floor::Real = 1e-12,
    kwargs...,
)
    0 < rate_threshold < 1 ||
        throw(ArgumentError("rate_threshold must lie in (0, 1), got $rate_threshold"))
    0 < model_ratio <= 1 ||
        throw(ArgumentError("model_ratio must lie in (0, 1], got $model_ratio"))
    min_points >= 3 || throw(ArgumentError("min_points must be ≥ 3, got $min_points"))
    env = Float64.(envelope)
    cmax = isempty(env) ? 0.0 : maximum(env)
    unresolved = (
        resolved = false,
        offending = false,
        decay_rate = NaN,
        algebraic_exponent = NaN,
        model_rss_ratio = NaN,
        plateau_found = false,
        n_points = 0,
    )
    cmax > 0 || return unresolved
    est = estimate_noise_floor(env; kwargs...)
    # Degrees k ≥ 1 whose coefficient is resolved: above the parity / rounding floor. The
    # model comparison runs on ALL of them — the noise-floor estimator reads a slowly
    # decaying algebraic tail as a plateau and would cut away the evidence.
    resolved_idx = [k for k in 1:length(env)-1 if env[k+1] > rel_floor * cmax]
    # Fit on the PEAKS of the envelope (the running maximum from the tail): a kink away
    # from the centre modulates the coefficients by cos(kθ₀) and a parity-symmetric f
    # zeroes every other one, so the raw envelope oscillates; the peaks follow the decay
    # law itself, k^{-ν} or ρ^{-k}, and the one-sided maximum needs no sign bookkeeping.
    idx = Int[]
    running = 0.0
    for k in reverse(resolved_idx)
        if env[k+1] >= running
            running = env[k+1]
            push!(idx, k)
        end
    end
    reverse!(idx)
    n = length(idx)
    n >= min_points || return (
        resolved = false,
        offending = false,
        decay_rate = est.decay_rate,
        algebraic_exponent = NaN,
        model_rss_ratio = NaN,
        plateau_found = est.plateau_found,
        n_points = n,
    )
    y = log10.(env[idx.+1])
    geo = _linefit(Float64.(idx), y)            # log c = a + b k      (analytic)
    alg = _linefit(log10.(Float64.(idx)), y)    # log c = a + b log k  (kink / plateau edge)
    exponent = -alg.slope
    ratio = geo.rss == 0 ? Inf : alg.rss / geo.rss
    # A noise plateau is not a decay law: on the peak sequence it shows as flat steps
    # (ratio ≈ 1 between consecutive peaks); algebraic decay keeps every step below 1.
    n_flat = count(i -> abs(y[i+1] - y[i]) < log10(1.001), 1:n-1)
    monotone = n_flat <= 1
    # (a) algebraic model clearly better, a decay (ν > 0), no flat steps
    algebraic = ratio <= model_ratio && exponent > 0 && alg.rss < geo.rss && monotone
    # (b) the evidence map's rule: slow geometric ratio with no plateau. The ratio is
    #     fitted on the decaying part when a plateau was found, on everything otherwise.
    rate = if est.plateau_found
        dec = [k for k in idx if k <= est.usable_degree && env[k+1] > est.floor]
        length(dec) >= 2 ? 10.0^_linefit(Float64.(dec), log10.(env[dec.+1])).slope :
        est.decay_rate
    else
        10.0^geo.slope
    end
    slow = !est.plateau_found && rate >= rate_threshold
    return (
        resolved = true,
        offending = algebraic || slow,
        decay_rate = rate,
        algebraic_exponent = exponent,
        model_rss_ratio = ratio,
        plateau_found = est.plateau_found,
        n_points = n,
    )
end

"""
    analyticity_verdict(pol::ApproxPoly; rate_threshold = 0.9, model_ratio = 0.5,
                        min_points = 5, rel_floor = 1e-12, kwargs...) -> AnalyticityVerdict

Per-axis analyticity test on the fit's coefficient envelopes ([`axis_envelopes`](@ref));
see [`axis_analyticity`](@ref) for the two triggers. The verdict is `:non_analytic` when
any resolved axis trips, `:analytic` when at least one axis is resolved and none trips,
`:undetermined` when no axis has `min_points` resolved coefficients (low degree: the
sweep has not reached the regime where the two decay laws separate).
"""
function analyticity_verdict(pol::ApproxPoly; kwargs...)
    envs = axis_envelopes(pol)
    n = length(envs)
    res = [axis_analyticity(env; kwargs...) for env in envs]
    resolved = [r.resolved for r in res]
    offending = [r.offending for r in res]
    verdict = any(offending) ? :non_analytic : (any(resolved) ? :analytic : :undetermined)
    suggested = 0
    if any(offending)
        rates = [offending[i] ? res[i].decay_rate : -Inf for i in 1:n]
        suggested = argmax(rates)
    end
    rt = Float64(get(kwargs, :rate_threshold, 0.9))
    mr = Float64(get(kwargs, :model_ratio, 0.5))
    return AnalyticityVerdict(
        verdict,
        [r.decay_rate for r in res],
        [r.algebraic_exponent for r in res],
        [r.model_rss_ratio for r in res],
        [r.plateau_found for r in res],
        [r.n_points for r in res],
        offending,
        suggested,
        rt,
        mr,
    )
end

"""
    analyticity_summary(v::AnalyticityVerdict) -> Dict{String,Any}

JSON-ready view of a verdict (metadata / ledger use).
"""
function analyticity_summary(v::AnalyticityVerdict)
    return Dict{String,Any}(
        "verdict" => string(v.verdict),
        "decay_rate" => v.decay_rate,
        "algebraic_exponent" => v.algebraic_exponent,
        "model_rss_ratio" => v.model_rss_ratio,
        "plateau_found" => v.plateau_found,
        "n_points" => v.n_points,
        "offending_axes" => findall(v.offending),
        "suggested_axis" => v.suggested_axis,
        "rate_threshold" => v.rate_threshold,
        "model_ratio" => v.model_ratio,
    )
end
