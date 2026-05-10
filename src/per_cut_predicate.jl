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
    rel_l2_squared =
        isfinite(subdomain.relative_l2_error) ? subdomain.relative_l2_error^2 : NaN
    spec = compute_mode_spectrum(
        subdomain.polynomial;
        extended_degree = extended_degree,
        rel_l2_squared = rel_l2_squared,
    )
    n_dim = size(spec.modes, 2)
    if n_dim == 0
        return [:bump]
    end
    if isempty(spec.spectrum)
        return fill(:bump, n_dim)
    end

    base_degree = spec.base_degree
    eta_sq = abs2.(spec.spectrum)
    n_modes = length(spec.spectrum)

    verdicts = Vector{Symbol}(undef, n_dim)
    for d in 1:n_dim
        verdicts[d] = _per_axis_verdict(
            spec.modes,
            eta_sq,
            n_modes,
            d,
            base_degree;
            θ_decay = θ_decay,
            θ_concentration = θ_concentration,
            mass_floor = axis_mass_floor,
        )
    end
    return verdicts
end

function _per_axis_verdict(
    modes::AbstractMatrix{Int},
    eta_sq::AbstractVector{Float64},
    n_modes::Int,
    d::Int,
    base_degree::Int;
    θ_decay::Real,
    θ_concentration::Real,
    mass_floor::Real,
)
    n_dim = size(modes, 2)
    axis_shell_mass = Dict{Int,Float64}()
    axis_total = 0.0
    @inbounds for j in 1:n_modes
        max_a = 0
        for k in 1:n_dim
            v = Int(modes[j, k])
            if v > max_a
                max_a = v
            end
        end
        if Int(modes[j, d]) == max_a
            axis_shell_mass[max_a] = get(axis_shell_mass, max_a, 0.0) + eta_sq[j]
            axis_total += eta_sq[j]
        end
    end

    if axis_total < mass_floor
        return :bump
    end

    conc_mass =
        get(axis_shell_mass, base_degree + 1, 0.0) +
        get(axis_shell_mass, base_degree + 2, 0.0)
    concentration = conc_mass / axis_total

    m_dp2 = get(axis_shell_mass, base_degree + 2, 0.0)
    m_dp4 = get(axis_shell_mass, base_degree + 4, 0.0)
    # Noise-floor guard for shell_decay (4vtd.3 finding): when the dominant
    # axis mass lives far above d+4 (e.g. T_12 contribution with base_d=6
    # places ~all mass at shell 12, leaving shells 8 and 10 at ~1e-32 LS-fit
    # noise), `log(m_dp2 / m_dp4)` is computed from roundoff and can give
    # spurious positive values. Require shells d+2 and d+4 to together
    # carry ≥ 0.1% of the axis mass before trusting the ratio.
    decay_signal_meaningful = (m_dp2 + m_dp4) >= 1e-3 * axis_total
    decay =
        (decay_signal_meaningful && m_dp2 > 0 && m_dp4 > 0) ?
        0.5 * log(m_dp2 / m_dp4) : NaN

    decay_says_bump = !isnan(decay) && decay > θ_decay
    conc_says_bump = concentration >= θ_concentration
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
