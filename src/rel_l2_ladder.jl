# rel_l2_ladder.jl
# Relative-L2-driven degree policy for `run_standard_experiment`.
#
# The relative L2 error  ‖f − p‖_L2 / ‖f‖_L2  is the one approximation-quality signal
# that transferred across dimension in the 2D–4D campaigns (globtimpostprocessing
# `quality_thresholds.toml`, [relative_l2_thresholds], evidence from 20+ runs, March 2026):
#
#   < 0.03          reliable recovery  (LV-2D 0.018, Goodwin-4D 0.024, DAISY-4D 0.027,
#                                       FHN-3D 0.029, locally-id 2D 0.024)
#   0.03 – 0.05     structure visible, recovery partial (LV-3D 0.034, LV-4D 0.037, Levy-3D 0.038)
#   0.05 – 0.10     unreliable          (LV-2D wide domain 0.056: no recovery)
#   > 0.10          no structure        (Griewank-3D plateau 0.33, daisy4d_entry5 0.74)
#
# Combined with finding F9 (the recovered minimizer saturates at low degree while the
# L2 error keeps falling 5–8 orders of magnitude), this gives a ladder:
#
#   1. Fit at degree d. If rel-L2 > `solve_below` (default: structure_visible), do NOT
#      solve — the critical points of p are not yet those of f. Bump the degree.
#   2. Once rel-L2 ≤ solve_below, solve every degree.
#   3. Stop as soon as rel-L2 ≤ reliable AND the recovered minimizer has plateaued
#      (GRADRES-GATE), or after `max_reliable_solves` reliable solves.
#   4. If rel-L2 stagnates while still above solve_below, stop and say so: more degree
#      will not help — subdivide, change chart, or try a rational surrogate.
#
# All functions here are pure (no fitting, no solving) so the policy is unit-testable
# without HomotopyContinuation.

using Printf

"""
    RelL2Thresholds(; reliable = 0.03, structure_visible = 0.05, unreliable = 0.10)

The relative-L2 bands of `globtimpostprocessing/quality_thresholds.toml`
([relative_l2_thresholds]). Keep the defaults in sync with that file; it records the
evidence for each value.
"""
Base.@kwdef struct RelL2Thresholds
    reliable::Float64 = 0.03
    structure_visible::Float64 = 0.05
    unreliable::Float64 = 0.10
    function RelL2Thresholds(reliable, structure_visible, unreliable)
        0 < reliable <= structure_visible <= unreliable || throw(
            ArgumentError(
                "need 0 < reliable ≤ structure_visible ≤ unreliable, got " *
                "($reliable, $structure_visible, $unreliable)",
            ),
        )
        return new(reliable, structure_visible, unreliable)
    end
end

"""
    classify_rel_l2(r, th = RelL2Thresholds()) -> Symbol

`:reliable` (r < reliable), `:structure_visible` (< structure_visible),
`:unreliable` (< unreliable), `:no_structure` (≥ unreliable), or `:unknown` for a
non-finite `r`. Band edges follow the toml: the lower edge belongs to the better band
only by strict inequality, so r = 0.03 is `:structure_visible`.
"""
function classify_rel_l2(r::Real, th::RelL2Thresholds = RelL2Thresholds())
    isfinite(r) || return :unknown
    r < th.reliable && return :reliable
    r < th.structure_visible && return :structure_visible
    r < th.unreliable && return :unreliable
    return :no_structure
end

"""
    RelL2LadderEntry(degree, rel_l2, solved, best_estimate)

One fitted degree as the ladder sees it. `solved` is false for a degree whose fit was
judged too poor to solve (and for failed solves); `best_estimate` is the lowest-value
raw critical point of a solved degree, `nothing` otherwise.
"""
struct RelL2LadderEntry
    degree::Int
    rel_l2::Float64
    solved::Bool
    best_estimate::Union{Vector{Float64},Nothing}
end

"""
    rel_l2_ladder_step(history; thresholds, solve_below, minimizer_tol,
                       max_reliable_solves, stagnation_threshold)
        -> (; action, verdict, reason)

Decide what to do after the latest entry of `history` (sorted by degree; entries as
`RelL2LadderEntry`). `action` is `:continue` or `:stop`. `verdict` is one of

- `:converged` — reliable fit and the recovered minimizer moved less than
  `minimizer_tol` (relative) over the last two reliable solves (GRADRES-GATE on the
  reliable band only);
- `:reliable_budget` — `max_reliable_solves` reliable solves done without a plateau
  (the minimizer keeps moving: report it, do not spend more degree);
- `:stagnated_unsolvable` — the rel-L2 history stagnated (last three relative
  improvements < `stagnation_threshold`) while still above `solve_below`: more degree
  will not reach a solvable fit. Escalate: subdivide, change chart, or rational surrogate;
- `:stagnated_partial` — stagnated inside (reliable, solve_below]: solved, but recovery
  may be partial;
- `:running` — keep going (`action = :continue`).

`reason` is a one-line human-readable explanation recorded in the run metadata.
"""
function rel_l2_ladder_step(
    history::AbstractVector{RelL2LadderEntry};
    thresholds::RelL2Thresholds = RelL2Thresholds(),
    solve_below::Real = thresholds.structure_visible,
    minimizer_tol::Real = 1e-3,
    max_reliable_solves::Int = 4,
    stagnation_threshold::Real = 0.01,
)
    isempty(history) && return (; action = :continue, verdict = :running, reason = "no degree fitted yet")
    last = history[end]

    # 3. reliable band: GRADRES plateau on the reliable solves only
    reliable_solved = [
        h for h in history if h.solved && h.best_estimate !== nothing && h.rel_l2 < thresholds.reliable
    ]
    if length(reliable_solved) >= 3
        ms = [h.best_estimate for h in reliable_solved]
        rel(a, b) = norm(a - b) / (norm(b) + 1e-15)
        if rel(ms[end], ms[end-1]) < minimizer_tol && rel(ms[end-1], ms[end-2]) < minimizer_tol
            return (;
                action = :stop,
                verdict = :converged,
                reason = @sprintf(
                    "rel-L2 %.3g < %.3g and recovered minimizer moved < %.1e over the last two reliable degrees",
                    last.rel_l2, thresholds.reliable, minimizer_tol
                ),
            )
        end
    end
    if length(reliable_solved) >= max_reliable_solves
        return (;
            action = :stop,
            verdict = :reliable_budget,
            reason = "$(length(reliable_solved)) reliable solves without a minimizer plateau (tol $(minimizer_tol))",
        )
    end

    # 4. stagnation of the fit itself (all fitted degrees, solved or not)
    r = [h.rel_l2 for h in history if isfinite(h.rel_l2)]
    if length(r) >= 3 && _rel_l2_stagnated(r, stagnation_threshold)
        if last.rel_l2 > solve_below
            return (;
                action = :stop,
                verdict = :stagnated_unsolvable,
                reason = @sprintf(
                    "rel-L2 stagnated at %.3g (> solve_below %.3g, band %s): escalate to subdivision, a chart change or a rational surrogate",
                    last.rel_l2, solve_below, classify_rel_l2(last.rel_l2, thresholds)
                ),
            )
        elseif last.rel_l2 >= thresholds.reliable
            return (;
                action = :stop,
                verdict = :stagnated_partial,
                reason = @sprintf(
                    "rel-L2 stagnated at %.3g in the structure-visible band: critical points solved, recovery may be partial",
                    last.rel_l2
                ),
            )
        end
    end
    return (; action = :continue, verdict = :running, reason = "")
end

# Same rule as EnhancedMetrics.detect_stagnation (last ≤3 relative improvements all below
# threshold), restated here because EnhancedMetrics is included after this file.
function _rel_l2_stagnated(r::AbstractVector{<:Real}, threshold::Real)
    length(r) < 3 && return false
    imp = [(r[i-1] - r[i]) / r[i-1] for i in 2:length(r)]
    k = min(3, length(imp))
    return all(<(threshold), imp[(end-k+1):end])
end

"""
    rel_l2_final_verdict(history; thresholds, solve_below) -> (; verdict, reason)

Verdict when the degree range ran out without a stop: `:range_exhausted_reliable`,
`:range_exhausted_partial` or `:range_exhausted_unsolvable` by the band of the last fit.
"""
function rel_l2_final_verdict(
    history::AbstractVector{RelL2LadderEntry};
    thresholds::RelL2Thresholds = RelL2Thresholds(),
    solve_below::Real = thresholds.structure_visible,
)
    isempty(history) && return (; verdict = :no_fit, reason = "no degree was fitted")
    r = history[end].rel_l2
    band = classify_rel_l2(r, thresholds)
    if band == :reliable
        return (; verdict = :range_exhausted_reliable, reason = @sprintf("degree range exhausted at rel-L2 %.3g (reliable)", r))
    elseif isfinite(r) && r <= solve_below
        return (; verdict = :range_exhausted_partial, reason = @sprintf("degree range exhausted at rel-L2 %.3g (%s)", r, band))
    else
        return (;
            verdict = :range_exhausted_unsolvable,
            reason = @sprintf("degree range exhausted at rel-L2 %.3g (%s): no degree was solvable — raise the degree range or escalate", r, band),
        )
    end
end
