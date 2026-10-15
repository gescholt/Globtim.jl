# certify_critical.jl — SKELETON (not included by Globtim.jl yet)
#
# Certificates C2 (per-point transfer to f) and C3 (global exclusion) of
# docs/research/plans/CERTIFIED_CRITICAL_POINTS_PLAN.md, plus the inertia
# certificate shared with C1. Needs IntervalArithmetic as a weak dependency
# (→ ext/GlobtimIntervalArithmeticExt.jl, which would `include` this file or hold
# the interval-typed methods), and ForwardDiff for ∇f / ∇²f with Interval inputs.
#
# Phase-1 shortcut noted in the plan: IntervalRootFinding.jl's `roots(∇f, Y, Newton)`
# implements interval Newton with the same existence/uniqueness guarantee and can
# stand in for `interval_newton_step` + the bisection in `exclusion_sweep`.

"""
    CertifiedCriticalPoint

- `box`        — the certified enclosure (vector of intervals, box coordinates);
- `midpoint`   — `Vector{Float64}`;
- `level`      — `:surrogate` (C1: zero of ∇p) or `:objective` (C2: zero of ∇f);
- `index_low`, `index_high` — certified Morse index bounds; equal iff certified;
- `contraction` — Krawczyk / interval-Newton contraction ratio `width(N(Y))/width(Y)`
  (< 1 is the proof; how far below 1 is the margin);
- `source`     — index into the raw critical-point list it came from.
"""
struct CertifiedCriticalPoint{B}
    box::B
    midpoint::Vector{Float64}
    level::Symbol
    index_low::Int
    index_high::Int
    contraction::Float64
    source::Int
end

"""
    certify_inertia(H_box; rel_tol = 0.0) -> (index_low, index_high, certified::Bool)

Certified inertia of a symmetric interval matrix `H_box` (the Hessian of `p` or `f`
over a certified box). Sufficient test (plan §2): take the midpoint matrix
`H_mid`, its eigen-decomposition `H_mid = Q Λ Qᵀ`, form the interval matrix
`M = Qᵀ H_box Q` (interval arithmetic, outward rounded), and apply Gershgorin to
`M`: eigenvalue `j` of every `H ∈ H_box` lies in
`M_jj ± Σ_{i≠j} |M_ij|` (interval `M_jj` widened by the row sum). Count the discs
entirely below zero (`index_low`), entirely above zero, and those straddling zero
(`index_high − index_low`). Rump's verified positive-definiteness test
[rump2006verification] is the sharper alternative when Gershgorin leaves discs
straddling zero; apply it to `±H_box` restricted to the undecided block.
"""
function certify_inertia(H_box; rel_tol = 0.0)
    error("not implemented: certify_inertia (CERTIFIED_CRITICAL_POINTS_PLAN.md §2)")
end

"""
    interval_newton_step(grad, hess, Y) -> (N, status)

One interval Newton step for `∇f = 0` on the box `Y` (plan §3):
`x₀ = mid(Y)`, `N = x₀ − hess(Y) \\ grad(x₀)` by interval Gauss–Seidel
[neumaier1990interval, ch. 5] (or the Krawczyk form with the midpoint inverse as
preconditioner). `status`:

- `:unique`   — `N ⊂ int(Y)`: exactly one zero of ∇f in `Y`, contained in `N`;
- `:empty`    — `N ∩ Y = ∅`: no zero in `Y` (the C3 exclusion test);
- `:undecided` — otherwise (bisect or enlarge).

`grad(x)` must return a vector of intervals for an interval or point `x`;
`hess(Y)` the interval Hessian (ForwardDiff with `Interval` inputs). Nothing here
knows about `f`'s origin; ODE objectives supply their own validated `grad`/`hess`
or are reported conditional (plan §4).
"""
function interval_newton_step(grad, hess, Y)
    error("not implemented: interval_newton_step")
end

"""
    transfer_to_objective(grad, hess, cp::CertifiedCriticalPoint; r0, r_max, growth = 2.0)
        -> CertifiedCriticalPoint

C2: enlarge the surrogate box to `Y = mid(cp.box) ± r`, `r = r0, growth·r0, …`
until `interval_newton_step` returns `:unique` (→ certified objective point with
`certify_inertia(hess(N))`) or `r > r_max` (→ `index_low = 0, index_high = n`,
`contraction = Inf`, level `:uncertified`). `r0` defaults to the measured
surrogate-to-objective displacement of the audit (`displacement` column) times a
safety factor; `r_max` to half the distance to the nearest other candidate.
"""
function transfer_to_objective(grad, hess, cp::CertifiedCriticalPoint; r0, r_max, growth = 2.0)
    error("not implemented: transfer_to_objective (CERTIFIED_CRITICAL_POINTS_PLAN.md §3)")
end

"""
    exclusion_sweep(grad_p_lower, grad_diff_upper, certified_boxes, domain; max_depth)
        -> (status, n_boxes_visited, uncovered)

C3 for white-box objectives (plan §4). Branch-and-bound over `domain ∖ ∪ boxes`:
a sub-box `B` is **excluded** when `grad_p_lower(B) > grad_diff_upper(B)` — a
certified lower bound on `‖∇p‖` over `B` (Bernstein enclosure, `rational_bernstein.jl`
machinery, or interval Clenshaw) exceeds a certified upper bound on `‖∇f − ∇p‖`
over `B` — or when `B ⊂` some certified box; otherwise bisected along its longest
axis up to `max_depth`. `status = :complete` iff every leaf was excluded or covered;
`uncovered` lists the leaves that were neither (candidates for missed critical
points, to be fed back as new HC start points).
"""
function exclusion_sweep(grad_p_lower, grad_diff_upper, certified_boxes, domain; max_depth = 40)
    error("not implemented: exclusion_sweep (CERTIFIED_CRITICAL_POINTS_PLAN.md §4)")
end

"""
    certified_census(points::AbstractVector{CertifiedCriticalPoint}) -> NamedTuple

The certified version of `poincare_hopf_sum` (hessian_analysis.jl): the index sum
over points with `index_low == index_high`, the `[lower, upper]` range the
undecided points can add, counts per level, and `exact::Bool`. Combined with
`exclusion_sweep(...) == :complete` the sum is a theorem about `f`.
"""
function certified_census(points::AbstractVector{<:CertifiedCriticalPoint})
    error("not implemented: certified_census")
end
