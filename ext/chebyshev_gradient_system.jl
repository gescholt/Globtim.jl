# chebyshev_gradient_system.jl — SKELETON (not included by GlobtimHomotopyContinuationExt.jl yet)
#
# The HomotopyContinuation.jl AbstractSystem for ∇p = 0 evaluated natively in the
# Chebyshev basis (src/chebyshev_eval.jl kernels), and the parameter homotopy over
# the coefficient vector that makes every fit with the same support a cheap
# continuation from one generic anchor.
# Plan: docs/research/plans/CHEBYSHEV_NATIVE_HC_PLAN.md §2–§3.
#
# To activate: `include("chebyshev_gradient_system.jl")` at the end of
# GlobtimHomotopyContinuationExt.jl, after the `using HomotopyContinuation` lines
# have been extended with `AbstractSystem, ModelKit, ParameterHomotopy, certify`.
# Every body below errors, so the file is safe to include; nothing dispatches to it
# until `solve_polynomial_system(...; representation = :chebyshev)` exists.

"""
    ChebyshevGradientSystem{N} <: HomotopyContinuation.AbstractSystem

`F(x; c) = ∇ Σ_α c_α T_α(x)` with the coefficient vector `c` as the **parameters**
of the system. `size(F) == (n, n)`. The support (per-axis degree box after
zero-padding) is fixed at construction; `c` is scattered onto the coefficient
tensor on every parameter update (`update_parameters!`), so one
`ChebyshevGradientSystem` serves a whole degree sweep / subdivision leaf set with
the same support.

Fields: `kernel::ChebyshevGradientKernel` (rebuilt on parameter change — the
derivative tensors depend on `c`), `support::Matrix{Int}`, `nparams::Int`.

Required HC.jl interface (HC.jl ≥ 2.6; confirm names against the installed
version — `ModelKit.evaluate!`, `ModelKit.evaluate_and_jacobian!`,
`ModelKit.taylor!`, `Base.size`, `ModelKit.nparameters`):

- `evaluate!(u, F, x, c)`             → `Globtim.evaluate!(u, kernel(c), x)`
- `evaluate_and_jacobian!(u, U, F, x, c)` → `Globtim.evaluate_and_jacobian!`
- `taylor!(u, ::Val{K}, F, tx, c)`    → Clenshaw on HC's `TaylorVector{K}` scalars;
  fallback: scalar loop over the `K` orders. **This is the one non-trivial method**
  (plan §5, risk 1).

The element type of `x` is `ComplexF64` or `ComplexDF64`; `c` is real (`Float64`)
on the target and complex on the anchor (`γ`-trick). The kernel must therefore be
built with `promote_type(eltype(x), eltype(c))` lazily, never by copying the
tensor to a wider type per call.
"""
struct ChebyshevGradientSystem{N}
    # kernel, support, nparams — see docstring; left abstract until the HC.jl
    # AbstractSystem supertype is imported into the extension.
    function ChebyshevGradientSystem{N}(args...) where {N}
        error("not implemented: ChebyshevGradientSystem (CHEBYSHEV_NATIVE_HC_PLAN.md §2)")
    end
end

"""
    chebyshev_anchor(support::Matrix{Int}, n::Int; rng) -> (c_anchor, start_solutions)

Solve the generic member of the family once. `c_anchor` is a random complex
coefficient vector on `support` (unit-normalised, so the anchor system is
well-conditioned in any basis); `start_solutions` are *all* its complex critical
points, obtained by `monodromy_solve` on the Chebyshev-native system or — Phase 1
fallback — by the existing monomial total-degree/polyhedral solve at the anchor,
where random coefficients make the basis conversion harmless. The expected count is
the generic critical-point count of the support (`(d−1)^n` for total degree `d`;
BKK for a general support) and is checked.

Cached on disk under `_generated/hc_anchors/<support_key>.jld2`
(`Globtim._support_key` in poly_solver.jl already defines the key).
"""
function chebyshev_anchor(support::Matrix{Int}, n::Int; rng = Random.default_rng())
    error("not implemented: chebyshev_anchor")
end

"""
    Globtim._solve_hc_chebyshev(pol::ApproxPoly; anchor = nothing, path_stats_ref = nothing)
        -> Vector{Vector{Float64}}

Same contract as `_solve_hc` (real solutions in `[-1,1]^n`, raw): build the
`ChebyshevGradientSystem` on `pol.support`, obtain or reuse the anchor, run the
straight-line parameter homotopy `c(t) = (1−t)·γ·c_anchor + t·pol.coeffs`, filter
real solutions, fill `path_stats_ref` with `(n_paths, n_singular, n_failed,
n_at_infinity, cond_jacobian_median)`. No monomial polynomial is ever formed.
"""
function _solve_hc_chebyshev(pol; anchor = nothing, path_stats_ref = nothing)
    error("not implemented: _solve_hc_chebyshev")
end

"""
    certify_surrogate_critical_points(pol::ApproxPoly, raw_points) -> CertificationResult

C1 of CERTIFIED_CRITICAL_POINTS_PLAN.md: `HomotopyContinuation.certify` on the
Chebyshev-native (interval-evaluable) gradient system, for the candidate
solutions `raw_points`. Returns the certified real boxes, the count of certified
complex / distinct solutions, and `n_unaccounted = n_paths − n_certified` as the
certified bound on what the tracker may have missed. The Morse-index certificate on
each box (`certify_inertia`, src/certify_critical.jl) is applied here so the result
carries `index_low:index_high` per point.
"""
function certify_surrogate_critical_points(pol, raw_points)
    error("not implemented: certify_surrogate_critical_points (CERTIFIED_CRITICAL_POINTS_PLAN.md §2)")
end
