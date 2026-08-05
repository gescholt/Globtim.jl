# barrier_mask.jl
# Penalty / flat-barrier leaf masking for adaptive_subdivision (bead yhta).
#
# Some objectives return a finite *penalty sentinel* over part of the domain
# instead of raising — e.g. an ODE-shooting objective that returns
# `log1p(penalty)` for samples that drive the integrated arc to
# `retcode=Unstable` (keeping the objective total rather than crashing the
# run). Such a region is a flat plateau with a discontinuous edge. The L2
# estimator sees high error at the edge and keeps splitting (and, with
# `enable_p_refinement`, re-fits ever-higher-degree polynomials on the
# discontinuity) — work that never reduces error and either exhausts the
# leaf/time budget or times out. Long high-dimensional shooting runs with
# `--prefine` have timed out at 6 h on exactly this (bead yhta).
#
# A *barrier detector* is a `Vector{Float64} -> Bool` predicate consulted by
# `process_subdomain` (and the `adaptive_refine` / `two_phase_refine` finalize
# passes). When it returns `true` for a leaf's sampled values, the leaf is
# marked `subdomain.masked = true` and terminated as `ActionPruned`: no
# h-split, no p-refinement, excluded from `total_error` and from
# `solve_tree_leaves` (its polynomial fits a step, so any critical points it
# would yield are spurious). The budget then flows to the genuinely-curved
# feasible region.
#
# Detection is opt-in: `barrier_detector = nothing` (the default everywhere)
# leaves behavior unchanged.

"""
    penalty_barrier_detector(penalty_value; frac=0.5, rtol=1e-3, atol=1e-9)

Build a barrier detector that flags a leaf when at least a fraction `frac` of
its sampled values sit at the `penalty_value` sentinel (compared with
`isapprox(·; rtol, atol)`).

For an objective with a known penalty return value — e.g.
`log1p(obj.penalty)` when `obj.use_log` — this masks barrier-dominated leaves.
A leaf straddling the barrier edge (penalty fraction below `frac`) is allowed
to split; each split pushes the barrier-side child's penalty fraction up and
the feasible-side child's down, so the barrier side crosses `frac` and gets
masked within a bounded number of levels while the feasible side keeps
refining. This bounds subdivision instead of letting it chase the discontinuity
forever.

`frac = 0.5` masks a leaf once the penalty region is the majority of samples.

# Example
```julia
det = penalty_barrier_detector(log1p(10.0))          # ODE-shooting penalty sentinel
tree = adaptive_refine(obj, bounds, 6; enable_p_refinement=true, barrier_detector=det)
```
"""
function penalty_barrier_detector(
    penalty_value::Real;
    frac::Float64 = 0.5,
    rtol::Float64 = 1e-3,
    atol::Float64 = 1e-9,
)
    0.0 < frac <= 1.0 ||
        error("penalty_barrier_detector: frac must be in (0, 1], got $frac")
    pv = Float64(penalty_value)
    return function (f_values::AbstractVector{<:Real})
        n = length(f_values)
        n == 0 && return false
        n_at = count(v -> isapprox(Float64(v), pv; rtol = rtol, atol = atol), f_values)
        return n_at / n >= frac
    end
end

"""
    flat_barrier_detector(; rstd=1e-6, atol=1e-12)

Build a barrier detector that flags a leaf whose sampled values are
(near-)constant: `std(f) / (|mean(f)| + atol) ≤ rstd`. Use when the plateau
value is not known a priori (generic flat-barrier masking). A truly flat leaf
fits a constant polynomial with no isolated critical points, so masking it
costs nothing and saves the per-leaf solve.

Note this is stricter than `penalty_barrier_detector`: it only fires on
*fully* flat leaves (entirely inside a plateau), not on barrier *edges*. Prefer
`penalty_barrier_detector` when the sentinel value is known.
"""
function flat_barrier_detector(; rstd::Float64 = 1e-6, atol::Float64 = 1e-12)
    return function (f_values::AbstractVector{<:Real})
        n = length(f_values)
        n < 2 && return false
        m = sum(f_values) / n
        s2 = sum(v -> (Float64(v) - m)^2, f_values) / (n - 1)
        return sqrt(max(s2, 0.0)) / (abs(m) + atol) <= rstd
    end
end
