# surrogate_residual.jl
#
# N4 of docs/research/plans/EVIDENCE_MAP_2026-10.md: every root a solver returns is
# checked to be a critical point OF THE FITTED SURROGATE before anything downstream
# sees it. The solver is handed ∇p = 0, so ‖∇p‖ must vanish at its roots; when it does
# not, the polynomial that was solved is not the polynomial that was fitted. Two
# recorded incidents of exactly that:
#
#   - a Legendre fit solved as Chebyshev (the `solve_polynomial_system(x, pol)` overload
#     forwarded only degree and coefficients) returned (±1.1407, 0) for the minima of
#     (x²−1)² + y² at every degree and made tier-A cells report zero in-box critical
#     points; it looked like a landscape finding (pkg/BioObjectives/README.md:138-174);
#   - a degree-12 solve returned "a root with relative gradient 391: the solve, not the
#     loss" (experiments/sandbox/lv_aliasing_remedies/FINDINGS.md:166-168).
#
# Refinement on f hides both (Newton pulls a displaced root back onto a true critical
# point), which is why the check sits on the raw roots, in box coordinates, and raises.

"""
    surrogate_gradient_residuals(pol::ApproxPoly, points; margin = 0.5, scale_rows = 2048)
        -> Vector{Float64}

Relative residual `‖∇p̂(ẑ)‖ / G` of the fitted surrogate at each root `ẑ` (box
coordinates, one point per entry), where `p̂(ẑ) = p(center + scale ⋅ ẑ)` is the surrogate
in the fit's own frame and `G = max_i ‖∇p̂(grid_i)‖` over (a stride-spread subset of at
most `scale_rows` rows of) the fit grid is the surrogate's own gradient scale on the box. Points with some `|ẑ_k| > 1 + margin` get `NaN`: far
outside the box a polynomial's gradient is dominated by its leading terms and the
relative residual is not meaningful there (those roots are discarded downstream anyway).
`G == 0` (constant surrogate) gives `NaN` everywhere.
"""
function surrogate_gradient_residuals(
    pol::ApproxPoly,
    points::AbstractVector{<:AbstractVector{<:Real}};
    margin::Real = 0.5,
    scale_rows::Int = 2048,
)
    margin >= 0 || throw(ArgumentError("margin must be ≥ 0, got $margin"))
    scale_rows >= 1 || throw(ArgumentError("scale_rows must be ≥ 1, got $scale_rows"))
    phat(ẑ) = evaluate(pol, pol.center .+ pol.scale_factor .* ẑ)
    gradhat(ẑ) = ForwardDiff.gradient(phat, Vector{Float64}(ẑ))
    # The fit grid holds one point per ROW on the single-domain path (n_samples × n) and
    # one point per COLUMN on subdivision leaves (n × n_samples, see Subdomain fits);
    # pick the orientation whose other extent is the dimension.
    n = length(pol.center)
    grid = pol.grid
    points_as_rows = if size(grid, 2) == n
        true
    elseif size(grid, 1) == n
        false
    else
        throw(
            DimensionMismatch(
                "fit grid $(size(grid)) has no extent equal to the dimension $n",
            ),
        )
    end
    n_grid = points_as_rows ? size(grid, 1) : size(grid, 2)
    G = 0.0
    for i in _strided_rows(n_grid, scale_rows)
        gi = points_as_rows ? view(grid, i, :) : view(grid, :, i)
        G = max(G, norm(gradhat(gi)))
    end
    out = Vector{Float64}(undef, length(points))
    for (i, ẑ) in enumerate(points)
        if G == 0 || any(z -> abs(z) > 1 + margin, ẑ)
            out[i] = NaN
        else
            out[i] = norm(gradhat(ẑ)) / G
        end
    end
    return out
end

"""
    check_surrogate_residuals(pol::ApproxPoly, points; tol = 1e-4, margin = 0.5) -> Float64

Largest finite relative residual of [`surrogate_gradient_residuals`](@ref) over
`points`; **throws** when it exceeds `tol`, naming the worst point, its residual and the
basis/normalization the surrogate was fitted in — because a root of the wrong
polynomial is a solve-path bug, never a landscape finding, and the repository's rule is
to raise rather than fall back. `tol = Inf` disables the check. Returns `0.0` for an
empty list and `NaN` when every point is outside the margin.

`tol = 1e-4` is far above what a correct HC/msolve root reaches (`≲ 1e-10` relative)
and far below the recorded failure modes (`O(0.1)` for the basis trap, `391` for the
bad solve), so neither a singular endpoint nor a flat trough trips it; tighten it per
run if the audit wants to.
"""
function check_surrogate_residuals(
    pol::ApproxPoly,
    points::AbstractVector{<:AbstractVector{<:Real}};
    tol::Real = 1e-4,
    margin::Real = 0.5,
)
    isempty(points) && return 0.0
    isfinite(tol) || return NaN
    res = surrogate_gradient_residuals(pol, points; margin = margin)
    finite = findall(isfinite, res)
    isempty(finite) && return NaN
    worst_i = finite[argmax(res[finite])]
    worst = res[worst_i]
    if worst > tol
        error(
            "surrogate gradient residual check failed: root $(points[worst_i]) (box coordinates) " *
            "has relative ‖∇p‖ = $(worst) > $(tol) on the fitted surrogate " *
            "(basis = $(pol.basis), normalized = $(pol.normalized), degree = $(pol.degree)). " *
            "The polynomial that was solved is not the polynomial that was fitted — " *
            "pass basis/precision/normalized through (solve_polynomial_system_from_approx) " *
            "or inspect the solver endpoint; $(count(r -> isfinite(r) && r > tol, res)) of " *
            "$(length(finite)) checked roots exceed the tolerance.",
        )
    end
    @debug "surrogate residual check: max relative ‖∇p‖ = $worst over $(length(finite)) roots"
    return worst
end

# ── Sparsification helpers (N4: the residual is measured on the polynomial that was solved) ──

"""
    _sparsify_coeffs(coeffs, threshold) -> Vector

Coefficients with `|c| < threshold * max|c|` set to zero (`threshold <= 0` or an empty
vector: `coeffs` unchanged). The one rule used both by the solver before building the
system and by [`check_surrogate_residuals`](@ref) when it has to check the truncated
polynomial, so the two can never disagree about which polynomial was solved.
"""
function _sparsify_coeffs(coeffs::AbstractVector, threshold::Real)
    (threshold > 0 && !isempty(coeffs)) || return coeffs
    max_c = maximum(abs, coeffs)
    max_c > 0 || return coeffs
    cutoff = threshold * max_c
    return [abs(c) < cutoff ? zero(c) : c for c in coeffs]
end

"""
    _with_coeffs(pol::ApproxPoly, coeffs) -> ApproxPoly

A copy of `pol` with its coefficient vector replaced (same support, degree, frame,
basis and normalisation), for evaluating a sparsified polynomial as a surrogate.
"""
function _with_coeffs(pol::ApproxPoly{T,S}, coeffs::Vector{T}) where {T,S}
    length(coeffs) == length(pol.coeffs) || throw(
        DimensionMismatch(
            "coefficient vector has $(length(coeffs)) entries, the polynomial $(length(pol.coeffs))",
        ),
    )
    return ApproxPoly{T,S}(
        coeffs,
        pol.support,
        pol.degree,
        pol.nrm,
        pol.N,
        pol.scale_factor,
        pol.center,
        pol.grid,
        pol.z,
        pol.basis,
        pol.precision,
        pol.normalized,
        pol.power_of_two_denom,
        pol.cond_vandermonde,
    )
end
