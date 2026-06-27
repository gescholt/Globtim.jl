# per_axis_cut_selection.jl
# Per-axis spectrum-based cut-dim selector (bead globopt_merged-4vtd.5,
# Phase 1 GREEN). Companion to per_cut_predicate.jl's `pick_strategy_per_axis`
# / `decide_action`: both consume the same per-axis-restricted mode spectrum,
# but this file's `pick_cut_dim_spectrum` answers a different question — once
# the leaf has been decided "split", which axis carries the most resistance
# to bumping?
#
# Hypothesis (bead 4vtd.5): the slowest-decay axis is the best cut. Variance
# in residuals (the current `select_cut_dimension` heuristic at
# adaptive_subdivision.jl:413-482) is a 2nd moment; it doesn't see where
# the residual energy lives in frequency. The spectrum does.
#
# The cluster aggregation in bead 4vtd.3 (28/28 cut-dim disagreements on
# fhn3d at population scale where the variance scorer and spectrum scorer
# diverge entirely) is the field-scale signal that motivated this bead.

"""
    pick_cut_dim_spectrum(subdomain::Subdomain;
                          extended_degree::Int = 0,
                          axis_mass_floor::Real = 1e-12) -> Int

Spectrum-based cut-dimension selector. Returns a 1-indexed dimension to cut.

Mirrors the per-axis spectrum walk from `_per_axis_verdict` (see
`per_cut_predicate.jl`), but instead of emitting a bump/split verdict per
axis, scores each axis by *resistance to bumping*:

- `axis_total < axis_mass_floor` → score `0.0` (axis carries no residual mass).
- `decay` is NaN (noise-floor guard tripped — shells `d+2`, `d+4` together
  carry less than 0.1% of axis mass, so `log(m_dp2 / m_dp4)` cannot be
  trusted) → score `axis_total` (all the residual lives at shells `> d+4`;
  the axis with more such mass is the better cut).
- Otherwise → score `-decay`. Slower decay (smaller `decay`, possibly
  negative) means more spectrum-mass refuses to fall off and a polynomial
  bump won't capture it; that axis needs the split.

Returns `argmax(scores)` with the documented tie-break: **lowest index**.
This matches `decide_action`'s convention from bead 4vtd.3 so the two
predicates compose deterministically — if `decide_action` says split along
axis k as a tie-break, `pick_cut_dim_spectrum` won't pick a different axis
for an indistinguishable reason.

Fallbacks (matching `pick_strategy_per_axis`):
- `subdomain.polynomial === nothing` → returns `1`.
- Empty / unavailable spectrum → returns `1`.

# Examples (the contract pinned by `test_per_axis_cut_selection.jl`)

```julia
# Anisotropic slow-y: T_2(x) + T_12(y) fit at degree 6
#  → x captured, all residual on y-axis spectrum at shell 12
#  → pick_cut_dim_spectrum returns 2.
#
# Equal axis-mass, different decay:
#  x: m(8)=1.66, m(10)=0.149   → decay = 0.5*log(11.1) ≈ 1.20 (fast)
#  y: m(8)=1.00, m(10)=0.81    → decay = 0.5*log(1.23) ≈ 0.11 (slow)
#  axis_total ≈ 1.81 on both axes (variance-blind)
#  → score_x = -1.20, score_y = -0.11, argmax = 2.
```
"""
function pick_cut_dim_spectrum(
    subdomain::Subdomain;
    extended_degree::Int = 0,
    axis_mass_floor::Real = 1e-12,
)
    if subdomain.polynomial === nothing
        return 1
    end
    rel_l2_squared =
        isfinite(subdomain.relative_l2_error) ? subdomain.relative_l2_error^2 : NaN
    spec = compute_mode_spectrum(
        subdomain.polynomial;
        extended_degree = extended_degree,
        rel_l2_squared = rel_l2_squared,
    )
    n_dim = size(spec.modes, 2)
    n_dim == 0 && return 1
    isempty(spec.spectrum) && return 1

    base_degree = spec.base_degree
    eta_sq = abs2.(spec.spectrum)
    n_modes = length(spec.spectrum)

    scores = fill(0.0, n_dim)
    for d in 1:n_dim
        axis_total, decay =
            _per_axis_total_and_decay(spec.modes, eta_sq, n_modes, d, base_degree)
        if axis_total < axis_mass_floor
            scores[d] = 0.0
        elseif isnan(decay)
            scores[d] = axis_total
        else
            scores[d] = -decay
        end
    end

    # argmax with lowest-index tie-break (Base.argmax already returns the
    # first maximum, which equals the lowest index for equal values).
    return argmax(scores)
end

# Per-axis spectrum walker. Returns `(axis_total, decay)` where:
#   axis_total = Σ η²_α over modes α with α[d] == |α|_∞ (axis-d-dominated).
#   decay      = 0.5 · log(m(d+2) / m(d+4)) over those restricted shells,
#                NaN when the noise-floor guard (shells d+2, d+4 together
#                ≥ 1e-3 · axis_total) is not satisfied.
#
# Mirrors `_per_axis_verdict` (per_cut_predicate.jl) but emits the raw
# spectrum quantities instead of a bump/split symbol so both predicates
# share one definition of the per-axis restriction.
function _per_axis_total_and_decay(
    modes::AbstractMatrix{Int},
    eta_sq::AbstractVector{Float64},
    n_modes::Int,
    d::Int,
    base_degree::Int,
)
    n_dim = size(modes, 2)
    axis_shell_mass = Dict{Int,Float64}()
    axis_total = 0.0
    @inbounds for j in 1:n_modes
        max_a = 0
        for k in 1:n_dim
            v = Int(modes[j, k])
            v > max_a && (max_a = v)
        end
        if Int(modes[j, d]) == max_a
            axis_shell_mass[max_a] = get(axis_shell_mass, max_a, 0.0) + eta_sq[j]
            axis_total += eta_sq[j]
        end
    end

    m_dp2 = get(axis_shell_mass, base_degree + 2, 0.0)
    m_dp4 = get(axis_shell_mass, base_degree + 4, 0.0)
    decay_signal_meaningful = axis_total > 0 && (m_dp2 + m_dp4) >= 1e-3 * axis_total
    decay =
        (decay_signal_meaningful && m_dp2 > 0 && m_dp4 > 0) ? 0.5 * log(m_dp2 / m_dp4) : NaN

    return axis_total, decay
end

"""
    _frame_from_normal(normal::AbstractVector{Float64}) -> Matrix{Float64}

Build an orthonormal `n×n` frame whose FIRST column is `normal/‖normal‖` (the
remaining columns complete the basis via QR). Used by Stage 3 to rotate a leaf so a
fold's normal becomes box-axis 1 — then a plain axis-1 cut slices perpendicular to
the fold. Raises on a zero vector (no silent fallback).
"""
function _frame_from_normal(normal::AbstractVector{Float64})
    nrm = norm(normal)
    nrm > 0 || error("_frame_from_normal: zero normal vector")
    v = collect(Float64, normal) ./ nrm
    n = length(v)
    Q = Matrix(qr(hcat(v, Matrix{Float64}(I, n, n))).Q)   # first column ≈ ±v
    dot(view(Q, :, 1), v) < 0 && (Q[:, 1] .*= -1.0)        # fix sign so Q[:,1] = v
    return Q
end

"""
    pick_cut_direction_spectrum(subdomain::Subdomain;
                                coh_threshold::Real = 0.7,
                                extended_degree::Int = 0,
                                axis_mass_floor::Real = 1e-12)
        -> (dim::Int, Q_new::Union{Nothing, Matrix{Float64}})

Stage 3 generalization of [`pick_cut_dim_spectrum`](@ref) from best-AXIS to
best-DIRECTION. When the leaf carries a degeneracy verdict of `:fold_caustic` with
`fold_coherence ≥ coh_threshold` (a single coherent sheet) and is still axis-aligned
(`transform === nothing`), it returns `(1, Q)` where `Q`'s first column is the fold
normal — the caller re-rotates the leaf to `Q` and cuts axis 1, slicing perpendicular
to the fold. Otherwise it returns `(pick_cut_dim_spectrum(...), nothing)` — the
existing axis-aligned behavior, byte-identical.

The fold normal comes from the leaf's `degeneracy` diagnostics (filled by
`detect_degeneracy!`), so this costs no extra objective evaluations. A coherent fold
that is already axis-aligned, or a leaf with no fold verdict, takes the axis fallback.
"""
function pick_cut_direction_spectrum(
    subdomain::Subdomain;
    coh_threshold::Real = 0.7,
    extended_degree::Int = 0,
    axis_mass_floor::Real = 1e-12,
)
    deg = subdomain.degeneracy
    if subdomain.transform === nothing &&
       deg !== nothing &&
       deg.verdict === :fold_caustic &&
       isfinite(deg.fold_coherence) &&
       deg.fold_coherence >= coh_threshold &&
       norm(deg.fold_normal) > 0
        return (1, _frame_from_normal(deg.fold_normal))
    end
    return (
        pick_cut_dim_spectrum(
            subdomain;
            extended_degree = extended_degree,
            axis_mass_floor = axis_mass_floor,
        ),
        nothing,
    )
end
