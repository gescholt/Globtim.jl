"""
    solve_tree_leaves(tree::SubdivisionTree; solver=:hc, dedup_tol=1e-6)
        -> (; critical_points::Vector{Vector{Float64}}, cp_leaf_ids::Vector{Int},
             leaf_status::Dict{Int,Symbol})

Solve the gradient system on every leaf polynomial of a finished
`SubdivisionTree`. Returns a NamedTuple with deduplicated critical points
(original-domain coordinates), the id of the leaf that produced each kept
point (`cp_leaf_ids`, aligned with `critical_points`), and a per-leaf status
map.

## Workflow
1. Iterate `converged_leaves ∪ active_leaves` (active leaves hit a depth/count
   limit but still have valid polynomials).
2. Call `solve_and_transform(sd.polynomial, get_bounds(sd); solver)` per leaf.
3. Merge all raw critical points and drop any point within `dedup_tol` of an
   earlier one (simple greedy deduplication).
4. Record per-leaf status: `:ran` (HC completed), `:hc_missing` (the extension
   couldn't load — user forgot `using HomotopyContinuation`), `:exception`
   (any other HC failure), `:skipped` (polynomial was nothing).

## Keyword Arguments
- `solver::Symbol=:hc`: Solver backend (`:hc` or `:msolve`)
- `msolve_threads::Int=1`: Number of threads for msolve

## Notes
- `:hc_missing` exists as a distinct status because silently succeeding with
  zero critical points from a whole tree of HC failures was a real regression
  (see cluster shootout, 2026-04-23). Downstream reporters MUST treat a leaf
  count of `:hc_missing` as a bug signal, not a "no CPs in this domain" result.
- Deduplication only removes near-duplicates that arise because adjacent
  subdomains share boundary regions; it does NOT classify minima vs saddles.
  Post-process with `GlobtimPostProcessing.refine_critical_points_batch` for
  classification and Nelder-Mead refinement.
"""
function solve_tree_leaves(
    tree::SubdivisionTree;
    dedup_tol::Float64 = 1e-6,
    sparsify_threshold::Float64 = 0.0,
    start_system::Symbol = :auto,
    solver::Symbol = :hc,
    msolve_threads::Int = 1,
    search_bounds::Union{Vector{Tuple{Float64,Float64}},Nothing} = nothing,
)
    all_cps = Vector{Float64}[]
    all_leaf_tags = Int[]
    leaf_status = Dict{Int,Symbol}()
    leaf_ids = vcat(tree.converged_leaves, tree.active_leaves)

    for leaf_id in leaf_ids
        sd = tree.subdomains[leaf_id]
        if sd.polynomial === nothing
            leaf_status[leaf_id] = :skipped
            continue
        end

        leaf_bounds = get_bounds(sd)

        try
            cps, _ = solve_and_transform(
                sd.polynomial,
                leaf_bounds;
                sparsify_threshold = sparsify_threshold,
                start_system = start_system,
                solver = solver,
                msolve_threads = msolve_threads,
                search_bounds = search_bounds,
                transform = sd.transform,  # Stage 2b: lift CPs back through the leaf's frame
            )
            append!(all_cps, cps)
            append!(all_leaf_tags, fill(leaf_id, length(cps)))
            leaf_status[leaf_id] = :ran
        catch e
            @warn "solve_tree_leaves: HC solve failed on leaf $leaf_id" exception = e
            leaf_status[leaf_id] = _classify_solve_failure(e)
        end
    end

    keep_idx = _dedup_point_indices(all_cps, dedup_tol)
    return (;
        critical_points = all_cps[keep_idx],
        # CP→leaf provenance, aligned with critical_points (bead 4iy5.2 step 0:
        # yield-vs-observables analysis needs to know which leaf produced each CP).
        cp_leaf_ids = all_leaf_tags[keep_idx],
        leaf_status = leaf_status,
    )
end

"""
    _classify_solve_failure(e) -> Symbol

Classify an exception thrown by `solve_and_transform` into `:hc_missing` when
the message indicates the HomotopyContinuation extension failed to load, or
`:exception` for any other cause.
"""
function _classify_solve_failure(e)
    msg = sprint(showerror, e)
    occursin("requires HomotopyContinuation", msg) && return :hc_missing
    return :exception
end

# ── Internal deduplication ────────────────────────────────────────────────────

"""
    _dedup_points(points, tol) -> Vector{Vector{Float64}}

Greedy deduplication: keep the first occurrence of any cluster of points
whose pairwise Euclidean distance is less than `tol`.
"""
function _dedup_points(points::Vector{Vector{Float64}}, tol::Float64)
    return points[_dedup_point_indices(points, tol)]
end

"""
    _dedup_point_indices(points, tol) -> Vector{Int}

Index-returning core of [`_dedup_points`](@ref): indices of the first
occurrence of each cluster, so callers can subset parallel arrays
(e.g. per-point leaf provenance) consistently.
"""
function _dedup_point_indices(points::Vector{Vector{Float64}}, tol::Float64)
    keep = Int[]
    for (i, pt) in enumerate(points)
        is_dup = any(keep) do j
            sum(abs2, pt .- points[j]) < tol^2
        end
        is_dup || push!(keep, i)
    end
    return keep
end
