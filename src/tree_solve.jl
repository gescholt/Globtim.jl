"""
    solve_tree_leaves(tree::SubdivisionTree; dedup_tol=1e-6) -> Vector{Vector{Float64}}

Run HomotopyContinuation solving on every leaf polynomial of a finished
`SubdivisionTree` and return all critical points (in original-domain
coordinates), deduplicated by pairwise distance.

## Workflow
1. Iterate `converged_leaves ∪ active_leaves` (active leaves hit a depth/count
   limit but still have valid polynomials).
2. Call `solve_and_transform(sd.polynomial, get_bounds(sd))` per leaf.
3. Merge all raw critical points and drop any point within `dedup_tol` of an
   earlier one (simple greedy deduplication).

## Notes
- Leaves whose `.polynomial` field is `nothing` are silently skipped.
- Deduplication only removes near-duplicates that arise because adjacent
  subdomains share boundary regions; it does NOT classify minima vs saddles.
  Post-process with `GlobtimPostProcessing.refine_critical_points_batch` for
  classification and Nelder-Mead refinement.
"""
function solve_tree_leaves(
    tree      :: SubdivisionTree;
    dedup_tol :: Float64 = 1e-6,
)
    all_cps = Vector{Float64}[]
    leaf_ids = vcat(tree.converged_leaves, tree.active_leaves)

    for leaf_id in leaf_ids
        sd = tree.subdomains[leaf_id]
        sd.polynomial === nothing && continue

        leaf_bounds = get_bounds(sd)

        try
            cps, _ = solve_and_transform(sd.polynomial, leaf_bounds)
            append!(all_cps, cps)
        catch e
            @warn "solve_tree_leaves: HC solve failed on leaf $leaf_id" exception=e
        end
    end

    return _dedup_points(all_cps, dedup_tol)
end

# ── Internal deduplication ────────────────────────────────────────────────────

"""
    _dedup_points(points, tol) -> Vector{Vector{Float64}}

Greedy deduplication: keep the first occurrence of any cluster of points
whose pairwise Euclidean distance is less than `tol`.
"""
function _dedup_points(points::Vector{Vector{Float64}}, tol::Float64)
    isempty(points) && return points
    kept = Vector{Float64}[]
    for pt in points
        is_dup = any(kept) do k
            sum(abs2, pt .- k) < tol^2
        end
        is_dup || push!(kept, pt)
    end
    return kept
end
