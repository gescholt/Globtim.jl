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
                  θ_decay::Real = 0.0,
                  θ_coverage::Real = 0.005,
                  θ_concentration::Real = 0.5,
                  extended_degree::Int = 0) -> Symbol

Mode-spectrum-driven bump-vs-split predicate. Returns `:bump` if the leaf's
residual is concentrated near the cutoff (a degree bump should catch it),
else `:split`.

Decision rule (in order):

1. **Coverage gate**: `window_coverage > θ_coverage`. If most of the residual
   energy sits *outside* the visible window `|α|_∞ ≤ extended_degree`, no
   amount of bumping inside the window helps — split.
2. **Bump signal**: at least one of
   - `shell_decay > θ_decay` (mass at d+2 strictly exceeds mass at d+4 — a
     +`degree_step` bump catches the residual), OR
   - `spectral_concentration ≥ θ_concentration` (η²-mass concentrated in
     shells `{d+1, d+2}` — bump catches it even when shell_decay is
     undefined or noisy because shells d+2/d+4 are both roundoff).

Calibration is from bead `dksx.0a` on 4 analytical problems:

| Problem      | concentration | shell_decay | coverage | Expected |
|--------------|---------------|-------------|----------|----------|
| deuflhard_2d | 0.99          | +2.28       | 0.018    | bump     |
| levy_3d      | 0.90          | +3.34       | 0.019    | bump     |
| ackley_3d    | 0.22          | -0.62       | 0.004    | split    |
| griewank_3d  | 0.98          | +1.91       | 0.001    | split    |

The coverage threshold 0.005 catches griewank's tail-outside-window pattern;
the shell_decay threshold 0.0 catches ackley's "mass past d+2" pattern;
concentration 0.5 fallback handles the T_5 case where d+2/d+4 are both
roundoff-zero.

Fallbacks:
- If `subdomain.polynomial === nothing`, returns `:bump` (no signal; preserve
  the legacy bump-by-default behavior so the predicate is backward-compatible).
- If the spectrum is empty (sample grid too small to extend past `base_degree`),
  returns `:bump` (same reasoning).
- If `window_coverage` is `NaN`, the coverage gate is bypassed — defer to the
  bump-signal axis alone.

Cost: one Vandermonde build + one least-squares solve over the leaf's existing
sample grid. No new objective evaluations.
"""
function pick_strategy(
    subdomain::Subdomain;
    θ_decay::Real = 0.0,
    θ_coverage::Real = 0.005,
    θ_concentration::Real = 0.5,
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
    )
end

"""
    pick_strategy(spec::NamedTuple; θ_decay, θ_coverage, θ_concentration) -> Symbol

Spectrum-accepting method: same decision rule, operating on a precomputed
`compute_mode_spectrum` / `subdomain_mode_spectrum` result. Callers that
consult several predicates on the same leaf (the audit drivers — bead
8f4p.5.1 DR-INSTR) compute the spectrum once and pass it here.
"""
function pick_strategy(
    spec::NamedTuple;
    θ_decay::Real = 0.0,
    θ_coverage::Real = 0.005,
    θ_concentration::Real = 0.5,
)
    if isempty(spec.spectrum)
        return :bump
    end

    # Coverage gate: residual must live inside the visible window.
    # NaN means "no reference", skip the gate (bump-signal axis decides).
    if !isnan(spec.window_coverage) && spec.window_coverage <= θ_coverage
        return :split
    end

    # Bump signal: shell_decay OR concentration says the residual is bump-catchable.
    decay_says_bump = !isnan(spec.shell_decay) && spec.shell_decay > θ_decay
    conc_says_bump = spec.spectral_concentration >= θ_concentration
    return (decay_says_bump || conc_says_bump) ? :bump : :split
end
