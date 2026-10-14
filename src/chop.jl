# chop.jl
#
# Automatic noise-floor detection on the coefficient envelope of an `ApproxPoly`, and the
# chop that follows from it.
#
# For an analytic objective the Chebyshev (or Legendre) coefficients decay geometrically
# with total degree until they hit the level of the noise in the samples — the ODE
# solver's tolerance, rounding in the least-squares solve, or the model error of a
# transformed objective. Past that point the fitted coefficients carry no information
# about f: raising the degree fits noise, and every such coefficient is a term the
# solver has to carry. The envelope
#
#     e_k = max{ |c_α| : |α| = k },   k = 0 … D
#
# therefore looks like a straight line in log scale followed by a flat plateau. This file
# locates the plateau by a two-piece (line + constant) least-squares split of log10 e_k
# — the multivariate analogue of chebfun's `standardChop` (Aurentz & Trefethen 2017),
# which cannot be used directly because it assumes a long 1-D coefficient sequence and
# our envelopes have D+1 ≤ ~20 entries — and reports
#
#   * `floor`: the plateau level (absolute), i.e. the estimated noise floor,
#   * `usable_degree`: the last total degree still on the decaying line,
#   * `decay_rate`: the geometric ratio ρ per degree on the decaying part (ρ < 1).
#
# `chop_polynomial` zeroes every coefficient at or below the floor through the existing
# `sparsify_polynomial` (absolute mode), so the L² bookkeeping and the `ApproxPoly`
# reconstruction are the ones already tested.

"""
    coefficient_envelope(pol::ApproxPoly) -> (degrees::Vector{Int}, envelope::Vector{Float64})

`envelope[k+1] = max |c_α|` over the multi-indices of total degree `k` present in the
support of `pol`, for `k = 0 … D`. Degrees absent from the support get `0.0`.
"""
function coefficient_envelope(pol::ApproxPoly)
    S = _support_matrix(pol)
    tot = vec(sum(S, dims = 2))
    D = isempty(tot) ? 0 : maximum(tot)
    env = zeros(Float64, D + 1)
    for (i, k) in enumerate(tot)
        a = abs(Float64(pol.coeffs[i]))
        env[k+1] = max(env[k+1], a)
    end
    return (degrees = collect(0:D), envelope = env)
end

"""
    axis_envelopes(pol::ApproxPoly) -> Vector{Vector{Float64}}

For each coordinate `i`, `env_i[k+1] = max |c_α|` over multi-indices with `α_i = k`.
The per-axis decay rates fitted from these (see [`axis_decay_rates`](@ref)) are the
anisotropy diagnostic: a slow axis needs degree, a fast one does not.
"""
function axis_envelopes(pol::ApproxPoly)
    S = _support_matrix(pol)
    n = size(S, 2)
    out = Vector{Vector{Float64}}(undef, n)
    for i in 1:n
        D = isempty(S) ? 0 : maximum(view(S, :, i))
        env = zeros(Float64, D + 1)
        for r in 1:size(S, 1)
            k = S[r, i]
            env[k+1] = max(env[k+1], abs(Float64(pol.coeffs[r])))
        end
        out[i] = env
    end
    return out
end

function _support_matrix(pol::ApproxPoly)
    S = pol.support
    if S === nothing
        n = size(pol.grid, 2)
        S = SupportGen(n, normalize_degree(pol.degree)).data
    end
    M = Matrix{Int}(S)
    size(M, 1) == length(pol.coeffs) || error(
        "coefficient_envelope: support has $(size(M, 1)) rows but the polynomial has " *
        "$(length(pol.coeffs)) coefficients",
    )
    return M
end

"""
    NoiseFloorEstimate

Result of [`estimate_noise_floor`](@ref).

- `floor::Float64` — estimated absolute noise level of the coefficients (`NaN` when no
  plateau was found);
- `relative_floor::Float64` — `floor / max|c|`, the relative accuracy the fit can reach;
- `usable_degree::Int` — last total degree on the decaying line (`D` when no plateau);
- `decay_rate::Float64` — fitted geometric ratio per degree on the decaying part;
- `plateau_found::Bool`;
- `envelope::Vector{Float64}` — the raw envelope that was analysed.
"""
struct NoiseFloorEstimate
    floor::Float64
    relative_floor::Float64
    usable_degree::Int
    decay_rate::Float64
    plateau_found::Bool
    envelope::Vector{Float64}
end

function _linefit(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    n = length(x)
    mx = sum(x) / n
    my = sum(y) / n
    sxx = sum((xi - mx)^2 for xi in x)
    slope = sxx == 0 ? 0.0 : sum((x[i] - mx) * (y[i] - my) for i in 1:n) / sxx
    intercept = my - slope * mx
    rss = sum((y[i] - (intercept + slope * x[i]))^2 for i in 1:n)
    return (slope = slope, intercept = intercept, rss = rss)
end

"""
    estimate_noise_floor(envelope::AbstractVector{<:Real};
                         min_decay_points = 3, min_plateau_points = 2,
                         min_separation_decades = 1.0, min_rss_gain = 0.9,
                         max_plateau_decay = 0.7) -> NoiseFloorEstimate
    estimate_noise_floor(pol::ApproxPoly; kwargs...) -> NoiseFloorEstimate

Split `log10(envelope)` into a decaying line on degrees `0…s` and a constant on
`s+1…D`, choosing `s` to minimise the residual sum of squares. The split is accepted
as a plateau only if

1. both pieces have enough points (`min_decay_points`, `min_plateau_points`),
2. the plateau level lies at least `min_separation_decades` above the line's extrapolated
   value at the end of the sequence (the tail has stopped decaying — flattening below the
   line is not a plateau), and
3. the two-piece model does not fit worse than a single line (`min_rss_gain`; a weak guard —
   super-geometric decay is concave in log scale, so the line part carries residual of its own),
4. the tail itself is flat: when it has ≥ 3 points its own fitted ratio per degree is at
   least `max_plateau_decay` (a tail that merely decays more slowly is a change of
   analyticity radius, not a noise floor).

Otherwise the series is still converging and `plateau_found = false`,
`usable_degree = D`, `floor = NaN`. Zero envelope entries are excluded from the fit.
"""
function estimate_noise_floor(
    envelope::AbstractVector{<:Real};
    min_decay_points::Int = 3,
    min_plateau_points::Int = 2,
    min_separation_decades::Real = 1.0,
    min_rss_gain::Real = 0.9,
    max_plateau_decay::Real = 0.7,
)
    0 < max_plateau_decay <= 1 ||
        throw(ArgumentError("max_plateau_decay must lie in (0, 1], got $max_plateau_decay"))
    env = Float64.(envelope)
    D = length(env) - 1
    cmax = isempty(env) ? 0.0 : maximum(env)
    none(decay) = NoiseFloorEstimate(NaN, NaN, D, decay, false, env)
    cmax > 0 || return none(NaN)

    idx = findall(>(0), env)
    x = Float64.(idx .- 1)          # degree
    y = log10.(env[idx])
    m = length(idx)
    whole = _linefit(x, y)
    decay_whole = 10.0^whole.slope
    m >= min_decay_points + min_plateau_points || return none(decay_whole)

    best = nothing
    for cut in min_decay_points:(m-min_plateau_points)   # decay part = 1:cut
        line = _linefit(view(x, 1:cut), view(y, 1:cut))
        tail = view(y, cut+1:m)
        level = sum(tail) / length(tail)
        rss = line.rss + sum((t - level)^2 for t in tail)
        if best === nothing || rss < best.rss
            best = (cut = cut, line = line, level = level, rss = rss)
        end
    end
    best === nothing && return none(decay_whole)

    extrap_end = best.line.intercept + best.line.slope * x[end]
    separated = best.level - extrap_end >= min_separation_decades
    gained = whole.rss == 0 ? false : best.rss <= min_rss_gain * whole.rss
    decaying = best.line.slope < 0
    flat = if m - best.cut >= 3
        _linefit(view(x, best.cut+1:m), view(y, best.cut+1:m)).slope >= log10(max_plateau_decay)
    else
        true
    end
    (separated && gained && decaying && flat) || return none(decay_whole)

    plateau_max = maximum(view(env, idx[best.cut+1:m]))
    usable = Int(x[best.cut])
    return NoiseFloorEstimate(plateau_max, plateau_max / cmax, usable, 10.0^best.line.slope, true, env)
end

estimate_noise_floor(pol::ApproxPoly; kwargs...) =
    estimate_noise_floor(coefficient_envelope(pol).envelope; kwargs...)

"""
    axis_decay_rates(pol::ApproxPoly) -> Vector{Float64}

Geometric decay ratio per degree along each axis, fitted on the decaying part of the
per-axis envelope (noise plateau excluded when one is detected). Values close to 1
mark the axes that limit the approximation.
"""
function axis_decay_rates(pol::ApproxPoly)
    return [estimate_noise_floor(env).decay_rate for env in axis_envelopes(pol)]
end

"""
    chop_polynomial(pol::ApproxPoly; safety = 1.0, kwargs...) -> NamedTuple

Estimate the noise floor of `pol` and zero every coefficient with
`|c| ≤ safety * floor`. Returns `(polynomial, estimate, original_nnz, new_nnz, l2_ratio)`;
when no plateau is detected the polynomial is returned unchanged (`new_nnz ==
original_nnz`). `kwargs` go to [`estimate_noise_floor`](@ref).
"""
function chop_polynomial(pol::ApproxPoly; safety::Real = 1.0, kwargs...)
    est = estimate_noise_floor(pol; kwargs...)
    nnz0 = count(!iszero, pol.coeffs)
    if !est.plateau_found
        return (polynomial = pol, estimate = est, original_nnz = nnz0, new_nnz = nnz0, l2_ratio = 1.0)
    end
    # sparsify_polynomial zeroes |c| < threshold; nextfloat makes the floor itself go too.
    thr = nextfloat(safety * est.floor)
    sp = sparsify_polynomial(pol, thr; mode = :absolute)
    return (
        polynomial = sp.polynomial,
        estimate = est,
        original_nnz = sp.original_nnz,
        new_nnz = sp.new_nnz,
        l2_ratio = sp.l2_ratio,
    )
end
