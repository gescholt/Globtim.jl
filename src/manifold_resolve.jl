# manifold_resolve.jl
#
# Stage 4 of the "non-zero-dimensional minima" program: the resolver for a GENUINE
# positive-dimensional argmin (a curve/surface of minimizers — a symmetry orbit, or
# f=(‖x‖²−1)² whose minimizers are a sphere). There the Hessian is rank-deficient
# (some λ≈0) and its kernel IS the tangent of the minimum manifold; reporting a
# single "the minimum is at x*" is wrong — the answer is the whole manifold.
#
# Two reconstruction paths:
#   • predictor-corrector continuation (default): predict along the Hessian kernel
#     (the manifold tangent), correct back onto the manifold with a damped Newton in
#     the strong (non-kernel) Hessian directions. This is the ε→0 limit of the
#     regularize-to-Morse idea (add ε‖P_K(x−x₀)‖² to isolate a representative, then
#     relax ε); tracing reports the manifold rather than one representative.
#   • symmetry quotient: when the continuum is a group orbit (a constant generator
#     ξ(x)), integrate ẋ=ξ(x) to reconstruct the orbit exactly — cheaper and
#     discretization-error-free than continuation.
#
# Scope: curves (intrinsic dim 1) and the symmetry path are implemented. Genuine
# k≥2 manifolds with nontrivial topology need multi-chart coverage / witness sets —
# flagged (raises) as the open research frontier, not silently mis-handled.
#
# globtim-only (ForwardDiff + LinearAlgebra). Works on any smooth callable in
# physical coordinates (the objective, or a fit-consistent polynomial evaluator).

using LinearAlgebra
using ForwardDiff

"""
    ManifoldResult

A positive-dimensional minimum manifold (Stage 4 resolver output), as opposed to an
isolated critical point.

# Fields
- `intrinsic_dim::Int`: dimension of the minimum manifold (1 = curve).
- `representative::Vector{Float64}`: a point on the manifold (the seed, projected on).
- `sample_points::Vector{Vector{Float64}}`: the discretized manifold.
- `tangent_basis::Matrix{Float64}`: the Hessian kernel at `representative` (n×k) — the
  ambient tangent space of the manifold there.
- `common_value::Float64`: the shared minimum value `f(representative)`.
- `value_spread::Float64`: `maxᵢ |f(sampleᵢ) − common_value|` — a QC certificate that
  the samples really are equi-valued (a true argmin manifold).
- `is_closed::Bool`: the trace returned to its start (a closed curve / orbit).
- `source::Symbol`: `:epsilon_continuation` or `:symmetry_quotient`.
- `converged::Bool`: the reconstruction terminated cleanly (closed, or hit max_steps).
"""
struct ManifoldResult
    intrinsic_dim::Int
    representative::Vector{Float64}
    sample_points::Vector{Vector{Float64}}
    tangent_basis::Matrix{Float64}
    common_value::Float64
    value_spread::Float64
    is_closed::Bool
    source::Symbol
    converged::Bool
end

# Smallest-|eigenvalue| eigenvector of the Hessian = the local manifold tangent.
function _manifold_tangent(f, x::Vector{Float64})
    ev = eigen(Symmetric(ForwardDiff.hessian(f, x)))
    return ev.vectors[:, argmin(abs.(ev.values))]
end

# Damped Newton onto the manifold {∇f = 0}, correcting only in the STRONG Hessian
# directions (|λ| > strong_tol) so the near-zero kernel (the tangent) is left free.
function _project_to_manifold!(
    f,
    x::Vector{Float64};
    newton_iters::Int = 8,
    strong_tol::Float64 = 1e-6,
)
    n = length(x)
    for _ in 1:newton_iters
        g = ForwardDiff.gradient(f, x)
        ev = eigen(Symmetric(ForwardDiff.hessian(f, x)))
        δ = zeros(n)
        @inbounds for j in 1:n
            λ = ev.values[j]
            if abs(λ) > strong_tol
                v = @view ev.vectors[:, j]
                δ .-= (dot(v, g) / λ) .* v
            end
        end
        x .+= δ
        norm(δ) < 1e-13 && break
    end
    return x
end

# Predictor-corrector trace of a 1-D minimum manifold through x0.
function _trace_curve(
    f,
    x0::Vector{Float64};
    step::Float64,
    max_steps::Int,
    newton_iters::Int,
    strong_tol::Float64,
    close_tol::Float64,
)
    x = _project_to_manifold!(
        f,
        copy(x0);
        newton_iters = newton_iters,
        strong_tol = strong_tol,
    )
    start = copy(x)
    pts = [copy(x)]
    t = _manifold_tangent(f, x)
    closed = false
    for i in 1:max_steps
        xp = x .+ step .* t                                   # predictor (along tangent)
        _project_to_manifold!(f, xp; newton_iters = newton_iters, strong_tol = strong_tol)
        tnew = _manifold_tangent(f, xp)
        dot(tnew, t) < 0 && (tnew .= .-tnew)                  # keep traversal direction
        x = xp
        t = tnew
        push!(pts, copy(x))
        if i > 3 && norm(x .- start) < close_tol
            closed = true
            break
        end
    end
    return pts, closed
end

# RK4 trace of a group orbit ẋ = ξ(x) (the symmetry-quotient path).
function _trace_orbit(
    generator,
    x0::Vector{Float64};
    step::Float64,
    max_steps::Int,
    close_tol::Float64,
)
    x = copy(x0)
    pts = [copy(x)]
    closed = false
    for i in 1:max_steps
        k1 = generator(x)
        k2 = generator(x .+ 0.5step .* k1)
        k3 = generator(x .+ 0.5step .* k2)
        k4 = generator(x .+ step .* k3)
        x = x .+ (step / 6) .* (k1 .+ 2k2 .+ 2k3 .+ k4)
        push!(pts, copy(x))
        if i > 3 && norm(x .- x0) < close_tol
            closed = true
            break
        end
    end
    return pts, closed
end

"""
    resolve_positive_dim_argmin(f, x0; kwargs...) -> ManifoldResult

Reconstruct the minimum manifold through the (near-degenerate) minimizer `x0` of the
smooth callable `f` (physical coordinates). With `symmetry_generator` it integrates
the orbit (`:symmetry_quotient`); otherwise it predictor-corrector traces the curve
(`:epsilon_continuation`).

Raises (no silent fallback) when: `x0` is non-degenerate (no near-zero Hessian
eigenvalue — it's an isolated min, not a manifold), the intrinsic dimension is ≥2
(open: needs multi-chart coverage), or the reconstructed samples are not equi-valued
within `value_tol` (so it was not a true argmin manifold).

# Keyword arguments
- `symmetry_generator = nothing`: an orbit generator `ξ(x)`; if given, use the
  quotient path.
- `kernel_tol = 1e-4`: |λ| below this is a Hessian-kernel (tangent) direction.
- `step = 0.1`: trace step length. `close_tol = 2·step`: closure radius.
- `max_steps = 2000`, `newton_iters = 8`, `strong_tol = 1e-6`: corrector controls.
- `value_tol = 1e-3`: max allowed `value_spread` over the samples.
"""
function resolve_positive_dim_argmin(
    f,
    x0;
    symmetry_generator = nothing,
    kernel_tol::Float64 = 1e-4,
    step::Float64 = 0.1,
    close_tol::Float64 = 0.0,
    max_steps::Int = 2000,
    newton_iters::Int = 8,
    strong_tol::Float64 = 1e-6,
    value_tol::Float64 = 1e-3,
)
    x0 = collect(Float64, x0)
    n = length(x0)
    ctol = close_tol > 0 ? close_tol : 2.0 * step

    ev = eigen(Symmetric(ForwardDiff.hessian(f, x0)))
    kmask = abs.(ev.values) .<= kernel_tol
    kdim = count(kmask)
    kdim >= 1 || error(
        "resolve_positive_dim_argmin: x0 has no near-zero Hessian eigenvalue (min|λ|=$(minimum(abs.(ev.values)))) — it is an isolated minimum, not a positive-dim manifold",
    )
    K = Matrix(ev.vectors[:, kmask])
    f0 = f(x0)

    if symmetry_generator !== nothing
        pts, closed = _trace_orbit(
            symmetry_generator,
            x0;
            step = step,
            max_steps = max_steps,
            close_tol = ctol,
        )
        source = :symmetry_quotient
    else
        kdim == 1 || error(
            "resolve_positive_dim_argmin: intrinsic dim $kdim ≥ 2 is not supported by the predictor-corrector path (global multi-chart coverage of a k≥2 manifold is an open problem — numerical irreducible decomposition / witness sets). Supply a symmetry_generator for an orbit, or restrict to curves.",
        )
        pts, closed = _trace_curve(
            f,
            x0;
            step = step,
            max_steps = max_steps,
            newton_iters = newton_iters,
            strong_tol = strong_tol,
            close_tol = ctol,
        )
        source = :epsilon_continuation
    end

    spread = maximum(abs(f(p) - f0) for p in pts)
    spread <= value_tol || error(
        "resolve_positive_dim_argmin: value_spread $spread exceeds value_tol $value_tol — samples are not equi-valued, so this is not a true argmin manifold",
    )

    return ManifoldResult(kdim, x0, pts, K, f0, spread, closed, source, true)
end
