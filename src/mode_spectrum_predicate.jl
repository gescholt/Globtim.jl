# mode_spectrum_predicate.jl
# Per-leaf bump-vs-split predicate driven by the mode-spectrum metrics
# (`shell_decay`, `window_coverage`, `spectral_concentration`) computed from
# `compute_mode_spectrum`. Bead ehaj.1 (epic ehaj — PREDICATE-EPIC).
#
# Used by `adaptive_refine` to decide, when `enable_p_refinement = true`,
# whether to bump the polynomial degree on a leaf or split the leaf. The
# default behavior in `adaptive_refine` (always bump if conditioning OK and
# under degree cap) is preserved by the `default_bump` predicate.

"""
    default_bump(subdomain::Subdomain) -> Symbol

Always returns `:bump`. This is the legacy `adaptive_refine` behavior — when
`enable_p_refinement = true`, every non-converged leaf bumps until the degree
cap or conditioning gate stops it. Used as the baseline in A/B comparisons.

# Predicate return-value contract

A predicate is a `Subdomain -> Symbol` function consulted by `process_subdomain`
in the `enable_p_refinement` branch. Three return values are recognized:

- `:bump`  — try p-refinement (gated by `max_degree` and conditioning).
- `:split` — go directly to h-refinement (skip the bump branch).
- `:done`  — accept the current fit and mark the leaf converged, even if
  `relative_l2_error > l2_tolerance`. Lets a custom predicate own the
  convergence decision (e.g. affine-fit-good, or certified lower bound clears
  a focus-band threshold).

Any other return value falls through to `:split`.
"""
default_bump(::Subdomain) = :bump

"""
    pick_strategy(subdomain::Subdomain;
                  θ_decay::Real = 0.5,
                  θ_coverage::Real = 0.4,
                  θ_concentration::Real = 0.9,
                  θ_stagnant::Real = 1e-2,
                  extended_degree::Int = 0) -> Symbol

Mode-spectrum-driven bump-vs-split predicate (v2 — bead ehaj.6). Returns
`:bump` if the leaf's residual is concentrated near the cutoff (a degree bump
should catch it), else `:split`.

Decision rule (in order):

1. **Stagnation gate**: `window_coverage_sample ≤ θ_coverage` AND
   `relative_l2_error > θ_stagnant`. If most of the residual energy sits
   *outside* the visible extended-degree window while the leaf is still
   genuinely far from converged, bumping inside the window can't help —
   split. Coverage is the Parseval-true sample-based fraction (bead 4vtd.2),
   a real energy fraction in [0,1]: `θ_coverage = 0.4` reads as "less than
   40% of the residual is catchable in-window". (The legacy coefficient-ratio
   `window_coverage` mixed units and was grid-dependent: the ehaj.6 value
   θ = 0.005 was calibrated on 21-pt oversampled fits and the gate almost
   never fired on production auto-grid fits, whose legacy values run 10-40×
   higher.) The rel_l2 conjunct is the v2 fix: near convergence the visible
   window mass collapses toward the noise floor, so low coverage alone also
   fires on nearly-done bump-friendly leaves (ehaj.2: deuflhard_2d, +121%
   evals from 6 spurious splits, every one with shell_decay > 2 and
   rel_l2 ≤ 5.6e-3).
2. **Bump signal**: at least one of
   - `shell_decay > θ_decay` (mass at d+2 exceeds mass at d+4 by a real
     margin — a +`degree_step` bump catches the residual), OR
   - `spectral_concentration ≥ θ_concentration` (η²-mass concentrated in
     shells `{d+1, d+2}` — bump catches it even when shell_decay is
     undefined or noisy because shells d+2/d+4 are both roundoff).

Calibration: dksx.0a fixed-probe measurements plus the ehaj.2 per-degree
decision traces (experiments/sandbox/results/predicate_ab_2d/). The v1
thresholds (θ_decay = 0.0, θ_concentration = 0.5) made the bump signal
vacuously true along real refinement paths — the predicate only ever
disagreed with `default_bump` at the degree cap. Measured discrimination at
low degree: bump-friendly leaves show decay ≥ 1.7 with concentration ≥ 0.97
(deuflhard deg 4-12; locally_id/L2_squared deg 4: decay 6.8, conc 0.99997),
stagnant/cone leaves show decay 0.21-0.38 with concentration 0.46-0.76
(griewank_2d deg 4; locally_id/L2_norm deg 6-12). θ_decay = 0.5 /
θ_concentration = 0.9 separate the two populations; dksx.0a probe verdicts
are preserved:

| Problem      | concentration | shell_decay | cov_sample (21pt/auto) | rel_l2 | verdict |
|--------------|---------------|-------------|------------------------|--------|---------|
| deuflhard_2d | 0.99          | +2.28       | 0.99 / 0.99            | large  | bump    |
| levy_3d      | 0.90          | +3.34       | 0.95 / 1.00            | large  | bump    |
| ackley_3d    | 0.22          | -0.62       | 0.35 / 0.90            | large  | split   |
| griewank_3d  | 0.98          | +1.91       | 0.16 / 0.11            | large  | split   |

θ_coverage = 0.4 reproduces all four verdicts at BOTH grid configs (4vtd.2
probe, 2026-07-04): griewank splits via the gate everywhere; ackley splits
via the gate on oversampled fits and via the decay/concentration axes on
auto-grid fits, where coarse-grid aliasing folds its high-frequency energy
into the window and inflates coverage to 0.90 (a limit of any sample
statistic — grid density is the only cure). Margin: stagnant max 0.35,
bump-friendly min 0.94 at the calibration config.

Fallbacks:
- If `subdomain.polynomial === nothing`, returns `:bump` (no signal; preserve
  the legacy bump-by-default behavior so the predicate is backward-compatible).
- If the spectrum is empty (sample grid too small to extend past `base_degree`),
  returns `:bump` (same reasoning).
- If `window_coverage_sample` is `NaN`, the stagnation gate is bypassed —
  defer to the bump-signal axis alone. If `rel_l2` is `NaN` (spec-accepting
  method without the kwarg), the rel_l2 conjunct is treated as satisfied —
  v1 behavior for callers that can't supply it.

Cost: one Vandermonde build + one least-squares solve over the leaf's existing
sample grid. No new objective evaluations.
"""
function pick_strategy(
    subdomain::Subdomain;
    θ_decay::Real = 0.5,
    θ_coverage::Real = 0.4,
    θ_concentration::Real = 0.9,
    θ_stagnant::Real = 1e-2,
    θ_coverage_full::Real = Inf,
    extended_degree::Int = 0,
)
    if subdomain.polynomial === nothing
        return :bump
    end
    spec = subdomain_mode_spectrum(subdomain; extended_degree = extended_degree)
    return pick_strategy(
        spec;
        θ_decay = θ_decay,
        θ_coverage = θ_coverage,
        θ_concentration = θ_concentration,
        θ_stagnant = θ_stagnant,
        θ_coverage_full = θ_coverage_full,
        rel_l2 = subdomain.relative_l2_error,
    )
end

"""
    pick_strategy(spec::NamedTuple; θ_decay, θ_coverage, θ_concentration,
                  θ_stagnant, θ_coverage_full, rel_l2) -> Symbol

Spectrum-accepting method: same decision rule, operating on a precomputed
`compute_mode_spectrum` / `subdomain_mode_spectrum` result. Callers that
consult several predicates on the same leaf (the audit drivers — bead
8f4p.5.1 DR-INSTR) compute the spectrum once and pass it here. Pass the
leaf's `relative_l2_error` as `rel_l2` to enable the v2 stagnation conjunct;
`NaN` (the default) treats the conjunct as satisfied (v1-compatible gate).
"""
function pick_strategy(
    spec::NamedTuple;
    θ_decay::Real = 0.5,
    θ_coverage::Real = 0.4,
    θ_concentration::Real = 0.9,
    θ_stagnant::Real = 1e-2,
    θ_coverage_full::Real = Inf,
    rel_l2::Real = NaN,
)
    if isempty(spec.spectrum)
        return :bump
    end

    # Full-coverage guard (ehaj.5 v3): sample coverage ≈ 1 means the residual
    # energy is already inside the window, so the structure is resolvable by
    # degree escalation — never split. Calibrated on the ehaj.3 traces: at
    # θ_coverage_full = 0.99 this suppresses 87/116 of levy_3d's harmful
    # splits (and 4/4 of levy_2d's) while touching zero split decisions on
    # ackley/griewank/fhn3d. Disabled by default (Inf) pending DR-FLIP
    # (8f4p.5.3).
    if !isnan(spec.window_coverage_sample) &&
       spec.window_coverage_sample >= θ_coverage_full
        return :bump
    end

    # Stagnation gate: residual invisible in the window AND the leaf is still
    # far from converged. Reads the Parseval-true sample-based coverage
    # (bead 4vtd.2) — a real energy fraction in [0,1], so θ_coverage is
    # interpretable and grid-independent. NaN coverage (empty spectrum, or a
    # hand-built spec without a reference) — skip the gate.
    # NaN rel_l2 means the caller can't supply it — conjunct treated satisfied.
    far_from_converged = isnan(rel_l2) || rel_l2 > θ_stagnant
    if !isnan(spec.window_coverage_sample) &&
       spec.window_coverage_sample <= θ_coverage &&
       far_from_converged
        return :split
    end

    # Bump signal: shell decay OR concentration says the residual is
    # bump-catchable. Decay is the parity-stratified rate (4vtd.1) — finite on
    # single-parity residuals where the fixed-shell scalar NaN'd, +Inf on a
    # decayed-away residual, NaN only when neither parity has ≥ 2 populated
    # shells (`NaN > θ` is false, so an unfittable rate never claims bump).
    decay_says_bump = shell_decay_parity(spec).combined > θ_decay
    conc_says_bump = spec.spectral_concentration >= θ_concentration
    return (decay_says_bump || conc_says_bump) ? :bump : :split
end
