# per_cut_predicate.jl
# Per-cut-direction bump-vs-split predicate (bead globopt_merged-4vtd.3,
# Phase 1 GREEN). Extends the global `pick_strategy` (mode_spectrum_predicate.jl)
# with per-axis verdicts and a coupled split/cut-dim decision.
#
# Motivation (from bead 4vtd.3): the global predicate decides "should I split?"
# before knowing "where would I split?" On anisotropic landscapes (e.g.
# T_2(x) + T_20(y)) the global verdict can be wrong because the per-axis
# information is already in the spectrum but is being averaged away.
#
# Approach (option 1 — project then reduce per axis): for each input axis k,
# restrict the residual mode spectrum to multi-indices α with `α[k] = |α|_∞`
# (modes where axis k is "the offender") and apply the same shell_decay /
# spectral_concentration rule used by `pick_strategy` to that restriction.
#
# Coverage is intentionally NOT projected per-axis — `window_coverage` is
# defined as `inside_window_mass / total_residual_squared`, and we don't have
# an out-of-window mass estimate per axis. The global coverage gate (handled
# at the call site if desired) remains a leaf-level pre-filter.

"""
    pick_strategy_per_axis(subdomain::Subdomain;
                           θ_decay::Real = 0.0,
                           θ_concentration::Real = 0.5,
                           extended_degree::Int = 0,
                           axis_mass_floor::Real = 1e-12) -> Vector{Symbol}

Per-axis bump-vs-split verdict. Returns a `Vector{Symbol}` of length equal
to the leaf's input dimension; each entry is `:bump` or `:split`.

Decision rule per axis k (mirrors `pick_strategy`'s bump-signal axis):

1. Restrict the spectrum to the offender modes `S_k = {α : α[k] = |α|_∞}`.
   Modes tied between axes (`α[k] == α[j]` for `j ≠ k`, both equal to `|α|_∞`)
   are counted toward every tied axis's restriction.
2. If the restricted η²-mass is below `axis_mass_floor`, return `:bump`
   (no signal on this axis — nothing to fix; the legacy bump-by-default
   behavior is preserved).
3. Compute axis-k `concentration_k = (m_k(d+1) + m_k(d+2)) / total_k` and
   `decay_k = 0.5 * log(m_k(d+2) / m_k(d+4))` over the restricted shell mass.
4. Return `:bump` iff `decay_k > θ_decay` OR `concentration_k ≥ θ_concentration`.
   Otherwise `:split`.

Fallbacks (matching `pick_strategy`):
- `subdomain.polynomial === nothing` → all-`:bump` of length `length(subdomain.center)`.
- Empty / unavailable spectrum → all-`:bump`.
"""
function pick_strategy_per_axis(
    subdomain::Subdomain;
    θ_decay::Real = 0.0,
    θ_concentration::Real = 0.5,
    extended_degree::Int = 0,
    axis_mass_floor::Real = 1e-12,
)
    if subdomain.polynomial === nothing
        return fill(:bump, length(subdomain.center))
    end
    spec = subdomain_mode_spectrum(subdomain; extended_degree = extended_degree)
    return pick_strategy_per_axis(
        spec;
        θ_decay = θ_decay,
        θ_concentration = θ_concentration,
        axis_mass_floor = axis_mass_floor,
    )
end

"""
    pick_strategy_per_axis(spec::NamedTuple; θ_decay, θ_concentration,
                           axis_mass_floor) -> Vector{Symbol}

Spectrum-accepting method: same per-axis rule, operating on a precomputed
`compute_mode_spectrum` / `subdomain_mode_spectrum` result. The offender-mode
restriction (the noise-floor guard from the 4vtd.3 finding included) lives in
`axis_shell_stats` and is shared with `pick_strategy_per_axis_lsfit` — one
pass over the modes serves both predicates (bead 8f4p.5.1 DR-INSTR).
"""
function pick_strategy_per_axis(
    spec::NamedTuple;
    θ_decay::Real = 0.0,
    θ_concentration::Real = 0.5,
    axis_mass_floor::Real = 1e-12,
)
    n_dim = size(spec.modes, 2)
    if n_dim == 0
        return [:bump]
    end
    if isempty(spec.spectrum)
        return fill(:bump, n_dim)
    end
    return [
        _per_axis_verdict(
            stat;
            θ_decay = θ_decay,
            θ_concentration = θ_concentration,
            mass_floor = axis_mass_floor,
        ) for stat in axis_shell_stats(spec)
    ]
end

function _per_axis_verdict(
    stat::NamedTuple;
    θ_decay::Real,
    θ_concentration::Real,
    mass_floor::Real,
)
    if stat.total < mass_floor
        return :bump
    end
    decay_says_bump = !isnan(stat.decay) && stat.decay > θ_decay
    conc_says_bump = stat.concentration >= θ_concentration
    return (decay_says_bump || conc_says_bump) ? :bump : :split
end

"""
    decide_action(verdicts::AbstractVector{Symbol})
        -> (action::Symbol, cut_dim::Union{Int,Nothing})

Combine per-axis verdicts into a leaf-level decision.

- All `:bump` → `(:bump, nothing)`.
- Any `:split` → `(:split, k)` where `k` is the lowest-indexed axis whose
  verdict is `:split`. Lowest-index tie-break is documented and deterministic.

This separation (per-axis verdict ↔ leaf decision) lets callers override the
combination policy — e.g., bead 4vtd.5 may swap the lowest-index tie-break
for "axis with greatest restricted mass" without changing the per-axis
predicate itself.
"""
function decide_action(verdicts::AbstractVector{Symbol})
    split_idx = findfirst(==(:split), verdicts)
    if split_idx === nothing
        return (:bump, nothing)
    else
        return (:split, split_idx)
    end
end
