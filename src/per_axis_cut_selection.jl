# per_axis_cut_selection.jl
# Per-axis spectrum-based cut-dim selector (bead 4vtd.5,
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
    spec = subdomain_mode_spectrum(subdomain; extended_degree = extended_degree)
    return pick_cut_dim_spectrum(spec; axis_mass_floor = axis_mass_floor)
end

"""
    pick_cut_dim_spectrum(spec::NamedTuple; axis_mass_floor) -> Int

Spectrum-accepting method: same axis scoring, operating on a precomputed
`compute_mode_spectrum` / `subdomain_mode_spectrum` result. The per-axis
restriction is shared with `pick_strategy_per_axis` via `axis_shell_stats`
(bead 8f4p.5.1 DR-INSTR).
"""
function pick_cut_dim_spectrum(spec::NamedTuple; axis_mass_floor::Real = 1e-12)
    n_dim = size(spec.modes, 2)
    n_dim == 0 && return 1
    isempty(spec.spectrum) && return 1

    stats = axis_shell_stats(spec)
    scores = fill(0.0, n_dim)
    for d in 1:n_dim
        if stats[d].total < axis_mass_floor
            scores[d] = 0.0
        elseif isnan(stats[d].decay)
            scores[d] = stats[d].total
        else
            scores[d] = -stats[d].decay
        end
    end

    # argmax with lowest-index tie-break (Base.argmax already returns the
    # first maximum, which equals the lowest index for equal values).
    return argmax(scores)
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
