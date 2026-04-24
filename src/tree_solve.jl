"""
    solve_tree_leaves(tree::SubdivisionTree; solver=:hc, dedup_tol=1e-6)
        -> (; critical_points::Vector{Vector{Float64}}, leaf_status::Dict{Int,Symbol})

Solve the gradient system on every leaf polynomial of a finished
`SubdivisionTree`. Returns a NamedTuple with deduplicated critical points
(original-domain coordinates) and a per-leaf status map.

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
  (see korok shootout, 2026-04-23). Downstream reporters MUST treat a leaf
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
            )
            append!(all_cps, cps)
            leaf_status[leaf_id] = :ran
        catch e
            @warn "solve_tree_leaves: HC solve failed on leaf $leaf_id" exception = e
            leaf_status[leaf_id] = _classify_solve_failure(e)
        end
    end

    return (;
        critical_points = _dedup_points(all_cps, dedup_tol),
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
