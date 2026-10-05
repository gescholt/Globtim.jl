# subdomain_gradient_check.jl
# The gradient check (gradient_fit.jl) on a subdivision leaf.
#
# A leaf converges on relative L2, but the critical points solve_tree_leaves reports are
# zeros of the leaf's ∇p. With `adaptive_refine(...; gradient_tolerance = τ)` a leaf must
# also satisfy ‖∇f − ∇p‖/‖∇f‖ ≤ τ (box coordinates) on a deterministic subset of its own
# sample points; otherwise it is treated as not converged (bump or split).

# Box point ẑ ↦ physical x for a leaf, Dual-friendly (box_to_physical! is in-place Float64).
function _leaf_point(sd::Subdomain, ẑ::AbstractVector)
    if sd.transform === nothing
        return sd.center .+ ẑ .* sd.half_widths
    else
        return sd.center .+ sd.transform * (ẑ .* sd.half_widths)
    end
end

"""
    subdomain_gradient_error(f, sd::Subdomain; method = :forwarddiff, n_points = 0) -> Float64

Relative gradient error of the leaf's fit, `relative_gradient_error` evaluated on the
leaf's own sample rows (penalty-substituted rows excluded), with the leaf's own box map
(rotation included). `n_points = 0` uses `min(#rows, 10·n)` rows spread by a fixed
stride; each row costs one gradient of `f`. Returns `Inf` for a leaf without a
polynomial or without usable rows, `NaN` when ∇f vanishes at every checked row.
"""
function subdomain_gradient_error(
    f,
    sd::Subdomain;
    method::Symbol = :forwarddiff,
    n_points::Int = 0,
)
    (sd.polynomial === nothing || sd.samples === nothing) && return Inf
    rows = setdiff(1:size(sd.samples, 1), sd.penalized_rows)
    isempty(rows) && return Inf
    n = size(sd.samples, 2)
    k = n_points > 0 ? n_points : 10 * n
    pick = rows[_strided_rows(length(rows), min(k, length(rows)))]
    return relative_gradient_error(
        sd.polynomial,
        f;
        points = sd.samples[pick, :],
        weights = fill(1.0 / length(pick), length(pick)),
        method = method,
        objective_point = z -> _leaf_point(sd, z),
    )
end

# Convergence side of the check. Infinite tolerance (the default): no check, no cost —
# behavior identical to the L2-only rule. Otherwise measure, store on the leaf, and pass
# iff err ≤ tol. NaN (∇f ≡ 0 on the checked rows, i.e. f flat there) passes: the relative
# error is undefined and the L2 bound already holds; it is logged, not hidden.
function _passes_gradient_check!(
    f,
    sd::Subdomain,
    tol::Float64;
    method::Symbol = :forwarddiff,
    n_points::Int = 0,
)
    isfinite(tol) || return true
    err = subdomain_gradient_error(f, sd; method = method, n_points = n_points)
    sd.relative_grad_error = err
    if isnan(err)
        @debug "gradient check undefined on a flat leaf (∇f = 0 at every checked row); passing" center =
            sd.center
        return true
    end
    return err <= tol
end
