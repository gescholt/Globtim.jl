# synthetic_generators.jl — DR-ORACLE (bead 8f4p.5.2)
#
# Planted-decay separable test functions with EXACT per-axis Chebyshev decay
# and a closed-form per-(subdomain, degree) decision oracle. This is the
# ground truth the DECISION-RULE epic calibrates against: it generalizes the
# hand-built T₂+T₂₀ RED constructions (4vtd.3/.5) into a family with a
# tunable per-axis knob ρᵢ.
#
# Lives under test/ (bead spec) but is dependency-free pure math, included by
# unit tests AND by experiment drivers:
#     include(joinpath(<repo>, "pkg/globtim/test/synthetic_generators.jl"))
#     using .SyntheticGenerators
#
# ── The family ──────────────────────────────────────────────────────────────
#
# Per axis, the Chebyshev generating function with t = 1/ρ (ρ > 1):
#
#     g_ρ(x) = Σ_{k≥0} ρ^{-k} T_k(x) = (1 - x/ρ) / (1 - 2x/ρ + ρ^{-2})
#
# so the Chebyshev coefficients are EXACTLY c_k = ρ^{-k}: the coefficient
# η²-mass at mode k is ρ^{-2k}, matching the E2 LS-slope model
# log(m_s) = -2·log(ρ)·s + const (per_cut_predicate_lsfit.jl) with the
# planted ρ as the true Bernstein radius. g_ρ is rational with a single pole
# at the Joukowski point x_p = (ρ + 1/ρ)/2 > 1, i.e. analytic in the open
# Bernstein ellipse E_ρ and in no larger one — the planted radius is sharp.
#
# The full function is the anisotropic-separable sum, tilted per axis by the
# linear term that plants an interior global minimum at x*:
#
#     f(x) = Σ_i [ g_{ρᵢ}(xᵢ) - g'_{ρᵢ}(x*ᵢ) · xᵢ ]
#
# g_ρ is strictly convex on [-1,1] (g' = t(1-t²)/(1-2tx+t²)² is positive and
# increasing), so each tilted axis term has its unique minimum exactly at
# x*ᵢ and f has its unique global minimum at x* — a closed-form p_true for
# recovery metrics. The tilt only changes c₁, never the tail k ≥ 2, so all
# decay-based statistics (shells above any base degree ≥ 2) see the pure
# planted ρᵢ.
#
# ── The oracle ──────────────────────────────────────────────────────────────
#
# On a subdomain [lo,hi] ⊆ [-1,1] with center c and half-width h, the local
# Chebyshev expansion of g_ρ has Bernstein radius given by the inverse
# Joukowski map of the pole in local coordinates:
#
#     ρ_eff = u + √(u² - 1),   u = (x_p - c)/h  > 1
#
# Bisection strictly increases ρ_eff on the cut axis (u ↦ 2u ∓ 1 for the two
# children, both > u since u > 1) — the domain-rescaling mechanics jw9g.4
# estimates empirically, here in closed form. The local coefficient tail of a
# degree-d fit is, per axis, the geometric tail
#
#     ε_i(d) = ρ_eff,i^{-(d+1)} / √(1 - ρ_eff,i^{-2})     (η² tail summed, √)
#
# (idealized: the local expansion is treated as exactly geometric at rate
# ρ_eff — true asymptotically, and exact up to the k-independent prefactor,
# which cancels from every comparison the oracle makes). The right decision
# for a (subdomain, degree) pair follows in closed form — see
# `right_decision`.

module SyntheticGenerators

export PlantedDecay, make_planted, effective_rho, planted_tail, right_decision

"""
    PlantedDecay{N}

Ground-truth description of a planted-decay instance: per-axis Bernstein
radii `rho` (each > 1, relative to the reference box [-1,1]^N), the planted
interior minimum `xstar`, and the per-axis tilt slopes `lambda[i] =
g'_{ρᵢ}(x*ᵢ)` that put the minimum there.
"""
struct PlantedDecay{N}
    rho::NTuple{N,Float64}
    xstar::NTuple{N,Float64}
    lambda::NTuple{N,Float64}
end

# g_ρ and its derivative, t = 1/ρ. g'(x) = t(1-t²)/(1-2tx+t²)².
function _g(ρ::Float64, x::Real)
    t = 1.0 / ρ
    return (1 - t * x) / (1 - 2 * t * x + t^2)
end
function _gprime(ρ::Float64, x::Real)
    t = 1.0 / ρ
    return t * (1 - t^2) / (1 - 2 * t * x + t^2)^2
end

_pole(ρ::Float64) = (ρ + 1.0 / ρ) / 2

"""
    make_planted(rho::NTuple{N,<:Real};
                 xstar::NTuple{N,<:Real} = ntuple(_ -> 0.0, N)) -> (f, planted)

Build a planted-decay instance: `f(x)` callable on any length-`N`
`AbstractVector`, and the `PlantedDecay` ground truth. Each `rho[i]` must be
> 1 and each `xstar[i]` in the open interval (-1, 1). The global minimum of
`f` on [-1,1]^N is exactly `collect(xstar)`.
"""
function make_planted(
    rho::NTuple{N,<:Real};
    xstar::NTuple{N,<:Real} = ntuple(_ -> 0.0, Val(N)),
) where {N}
    all(r -> r > 1, rho) ||
        error("planted rho must be > 1 per axis (Bernstein radius), got $rho")
    all(x -> -1 < x < 1, xstar) ||
        error("planted xstar must lie in the open box (-1,1)^$N, got $xstar")
    ρs = Float64.(rho)
    xs = Float64.(xstar)
    λs = ntuple(i -> _gprime(ρs[i], xs[i]), Val(N))
    planted = PlantedDecay{N}(ρs, xs, λs)
    f = function (x::AbstractVector{<:Real})
        length(x) == N || error(
            "planted instance is $N-dimensional, got a length-$(length(x)) point",
        )
        s = 0.0
        @inbounds for i in 1:N
            s += _g(ρs[i], x[i]) - λs[i] * x[i]
        end
        return s
    end
    return f, planted
end

"""
    effective_rho(planted::PlantedDecay{N}, bounds) -> Vector{Float64}

Per-axis Bernstein radius of the planted function RESTRICTED to the
subdomain `bounds` (a length-`N` collection of `(lo, hi)` with
`-1 ≤ lo < hi ≤ 1`), in the subdomain's own normalized coordinates: the
inverse Joukowski image of the pole position. Equals `planted.rho` exactly
on the full reference box; strictly increases under any bisection.
"""
function effective_rho(planted::PlantedDecay{N}, bounds) where {N}
    length(bounds) == N ||
        error("bounds must have $N axes, got $(length(bounds))")
    out = Vector{Float64}(undef, N)
    @inbounds for i in 1:N
        lo, hi = bounds[i]
        (-1 - 1e-12 <= lo < hi <= 1 + 1e-12) || error(
            "axis $i bounds ($lo, $hi) must satisfy -1 ≤ lo < hi ≤ 1: the " *
            "planted family is defined relative to the reference box [-1,1]^$N",
        )
        c = (lo + hi) / 2
        h = (hi - lo) / 2
        u = (_pole(planted.rho[i]) - c) / h
        out[i] = u + sqrt(u^2 - 1)
    end
    return out
end

# Geometric η²-tail beyond degree d at rate ρ, square-rooted to an L2-style
# per-axis error: √(Σ_{k>d} ρ^{-2k}) = ρ^{-(d+1)} / √(1 - ρ^{-2}).
_axis_tail(ρ_eff::Float64, degree::Int) =
    ρ_eff^(-(degree + 1)) / sqrt(1 - ρ_eff^(-2))

"""
    planted_tail(planted::PlantedDecay{N}, bounds, degree::Int) -> Vector{Float64}

Per-axis closed-form truncation error of a degree-`degree` fit on the
subdomain `bounds`: the geometric coefficient tail at the effective
(rescaled) Bernstein radius. This is the quantity whose per-axis ORDER the
decay estimators must reproduce; its absolute scale carries the geometric
idealization documented in the file header.
"""
planted_tail(planted::PlantedDecay{N}, bounds, degree::Int) where {N} =
    _axis_tail.(effective_rho(planted, bounds), degree)

"""
    right_decision(planted::PlantedDecay{N}, bounds, degree::Int;
                   l2_tolerance::Real, max_degree::Int)
        -> (action, cut_dim, degree_needed)

The closed-form RIGHT decision for a leaf at `bounds` currently fitted at
isotropic `degree`, under the planted ground truth:

- `(:done, nothing, degree)` — the total planted tail √(Σᵢ εᵢ²) is already
  ≤ `l2_tolerance`: accept the fit.
- `(:bump, nothing, d*)` — not converged, but the minimal isotropic degree
  `d*` reaching tolerance ON THIS SUBDOMAIN (each axis tail ≤ tol/√N, in
  closed form from the geometric tail) is ≤ `max_degree`: p-refine.
- `(:split, argmin ρ_eff, d*)` — tolerance is unreachable within the degree
  budget: h-refine, cutting the axis with the SLOWEST effective decay (the
  bottleneck axis; for a common degree this is also the largest-tail axis).
  `d*` reports the out-of-budget degree that would have been needed.

The decision accounts for domain rescaling: after bisecting the flagged
axis, `ρ_eff` rises and `d*` falls, so repeated `:split` verdicts terminate.
"""
function right_decision(
    planted::PlantedDecay{N},
    bounds,
    degree::Int;
    l2_tolerance::Real,
    max_degree::Int,
) where {N}
    l2_tolerance > 0 || error("l2_tolerance must be positive, got $l2_tolerance")
    ρe = effective_rho(planted, bounds)
    tails = _axis_tail.(ρe, degree)
    err = sqrt(sum(abs2, tails))
    if err <= l2_tolerance
        return (action = :done, cut_dim = nothing, degree_needed = degree)
    end
    # Per-axis minimal degree with tail ≤ τ = tol/√N:
    #   ρ^{-(d+1)} ≤ τ·√(1-ρ^{-2})  ⇔  d ≥ log(1/(τ√(1-ρ^{-2}))) / log ρ - 1.
    τ = l2_tolerance / sqrt(N)
    d_star = degree + 1  # err > tol ⇒ strictly more degree is needed
    @inbounds for i in 1:N
        need = ceil(Int, -log(τ * sqrt(1 - ρe[i]^(-2))) / log(ρe[i])) - 1
        d_star = max(d_star, need)
    end
    if d_star <= max_degree
        return (action = :bump, cut_dim = nothing, degree_needed = d_star)
    end
    return (action = :split, cut_dim = argmin(ρe), degree_needed = d_star)
end

end # module SyntheticGenerators
