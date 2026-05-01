# Pure helpers for y0j parent→child sample reuse (Option A).
#
# These functions take existing `Subdomain` values and a matrix of parent
# sample points in parent-normalized `[-1,1]^n` coordinates, and produce the
# inputs needed for a child's non-tensor Vandermonde LS solve:
#   - `remap_parent_to_child`: change of variables from parent to child normalization.
#   - `points_inside_child`: identify which parent samples land inside the child box.
#   - `combine_inherited_and_fresh`: concatenate inherited + fresh points while
#     dropping fresh points that coincide with an inherited one.
#
# No globtim types are imported beyond `Subdomain`; the functions are pure and
# unit-testable without starting a subdivision run.

"""
    remap_parent_to_child(x_parent, parent, child) -> Vector{Float64}

Transform a sample point `x_parent ∈ [-1, 1]^n` expressed in the parent's
normalized coordinates into the child's normalized coordinates.

The transform in each dimension `d` is affine:
    p_abs[d] = parent.center[d] + x_parent[d] * parent.half_widths[d]
    x_child[d] = (p_abs[d] - child.center[d]) / child.half_widths[d]

In a non-split dimension, `parent.center[d] == child.center[d]` and
`parent.half_widths[d] == child.half_widths[d]`, so the output matches the
input (no drift accumulation).
"""
function remap_parent_to_child(
    x_parent::AbstractVector{<:Real},
    parent::Subdomain,
    child::Subdomain,
)
    n = length(x_parent)
    n == length(parent.center) == length(child.center) ||
        throw(ArgumentError("dimension mismatch between point, parent, and child"))
    x_child = Vector{Float64}(undef, n)
    @inbounds for d in 1:n
        p_abs = parent.center[d] + x_parent[d] * parent.half_widths[d]
        x_child[d] = (p_abs - child.center[d]) / child.half_widths[d]
    end
    return x_child
end

"""
    points_inside_child(parent_samples, parent, child; tol=1e-10) -> Vector{Int}

Return the row indices of `parent_samples` (a `n_samples × n_dims` matrix of
parent-normalized points) whose remapped coordinates all lie within
`[-1 - tol, 1 + tol]` in the child's normalized space.

The tolerance is a defensive guard for floating-point noise at the cut
boundary; `tol=1e-10` is far tighter than any subdivision precision.
"""
function points_inside_child(
    parent_samples::AbstractMatrix{<:Real},
    parent::Subdomain,
    child::Subdomain;
    tol::Float64 = 1e-10,
)
    n_rows, n_dims = size(parent_samples)
    n_dims == length(parent.center) == length(child.center) ||
        throw(ArgumentError("column count must equal subdomain dimension"))
    indices = Int[]
    upper = 1.0 + tol
    @inbounds for i in 1:n_rows
        inside = true
        for d in 1:n_dims
            p_abs = parent.center[d] + parent_samples[i, d] * parent.half_widths[d]
            x_child_d = (p_abs - child.center[d]) / child.half_widths[d]
            if abs(x_child_d) > upper
                inside = false
                break
            end
        end
        inside && push!(indices, i)
    end
    return indices
end

"""
    combine_inherited_and_fresh(inherited, fresh; tol=1e-10)
        -> (combined::Matrix{Float64}, new_idx::Vector{Int})

Concatenate `inherited` (points remapped from the parent, in child coords) and
the subset of `fresh` (a freshly generated Chebyshev grid in child coords) that
are not within `tol` of any inherited row. `combined` is `[inherited; fresh[new_idx, :]]`.

`new_idx` gives the caller the indices into `fresh` that still need an `f(x)`
evaluation — inherited rows already have `f`-values copied from the parent
cache, so no re-evaluation is needed for them.
"""
function combine_inherited_and_fresh(
    inherited::AbstractMatrix{<:Real},
    fresh::AbstractMatrix{<:Real};
    tol::Float64 = 1e-10,
)
    n_inh, n_dims_inh = size(inherited)
    n_fresh, n_dims_fresh = size(fresh)
    n_inh == 0 ||
        n_fresh == 0 ||
        n_dims_inh == n_dims_fresh ||
        throw(ArgumentError("inherited and fresh must have the same number of columns"))
    n_dims = n_inh == 0 ? n_dims_fresh : n_dims_inh

    new_idx = Int[]
    tol2 = tol * tol
    @inbounds for j in 1:n_fresh
        duplicate = false
        for i in 1:n_inh
            dist2 = 0.0
            for d in 1:n_dims
                Δ = fresh[j, d] - inherited[i, d]
                dist2 += Δ * Δ
                dist2 > tol2 && break
            end
            if dist2 ≤ tol2
                duplicate = true
                break
            end
        end
        duplicate || push!(new_idx, j)
    end

    combined = Matrix{Float64}(undef, n_inh + length(new_idx), n_dims)
    @inbounds for i in 1:n_inh, d in 1:n_dims
        combined[i, d] = inherited[i, d]
    end
    @inbounds for (k, j) in enumerate(new_idx)
        for d in 1:n_dims
            combined[n_inh+k, d] = fresh[j, d]
        end
    end
    return combined, new_idx
end
