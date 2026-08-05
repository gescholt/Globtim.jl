"""
    batched_solve.jl

Bridge between the (stabilized) subdivision tree and a batched critical-point solve.

`collect_stabilized_leaves` snapshots the solvable leaves of a finished
`SubdivisionTree` into a flat, solver-ready list. It is the hand-off point produced
by Part B (refine-until-stabilized) and consumed by Part C (the batched warm-start
solver) — keeping the per-degree construct→solve path in `StandardExperiment` untouched.

The Part C driver (`solve_tree_leaves_warmstart`) will be added to this file.
"""

"""
    StabilizedLeaf

A single solvable leaf snapshot: its tree id, polynomial approximation, and
original-domain bounds. Plain data — no tree references — so the batch solver can
group and process leaves without touching tree internals.
"""
struct StabilizedLeaf
    leaf_id::Int
    polynomial::ApproxPoly
    bounds::Vector{Tuple{Float64,Float64}}
end

"""
    collect_stabilized_leaves(tree::SubdivisionTree) -> Vector{StabilizedLeaf}

Snapshot every solvable leaf of `tree` (converged ∪ active, matching the leaf set
`solve_tree_leaves` iterates) into a flat list. Leaves whose `polynomial` is `nothing`
(never approximated) are skipped — exactly the `:skipped` case in `solve_tree_leaves`.

This is intentionally a pure read of the tree: it performs no solving and mutates
nothing, so it can be called on a stabilized tree and the result handed to either the
cold-start (`solve_tree_leaves`) or warm-start (`solve_tree_leaves_warmstart`) path.
"""
function collect_stabilized_leaves(tree::SubdivisionTree)
    out = StabilizedLeaf[]
    for leaf_id in vcat(tree.converged_leaves, tree.active_leaves)
        sd = tree.subdomains[leaf_id]
        sd.polynomial === nothing && continue
        push!(out, StabilizedLeaf(leaf_id, sd.polynomial, get_bounds(sd)))
    end
    return out
end

# Affine map from normalized [-1,1]^n to a leaf's original-domain coordinates,
# matching solve_and_transform: original = halfwidth .* raw .+ center.
function _to_original_domain(raw_pt, bounds::Vector{Tuple{Float64,Float64}})
    center = [(b[1] + b[2]) / 2 for b in bounds]
    half = [(b[2] - b[1]) / 2 for b in bounds]
    return half .* raw_pt .+ center
end

"""
    solve_tree_leaves_warmstart(tree; dedup_tol=1e-6, solver=:hc)
        -> (; critical_points, leaf_status, path_stats)

Batched parametric warm-start counterpart of `solve_tree_leaves`. Groups leaves by
support (`group_key`) — so it handles mixed-degree trees from `enable_p_refinement`
(one batch per support group; size-1 groups are just a single anchored solve) — and
within each group solves all cells from ONE generic-complex anchor (see
`_solve_hc_parametric`). Returns the same `(critical_points, leaf_status)` shape as
`solve_tree_leaves`, plus `path_stats` (per leaf: `(n_paths, n_success, n_real)`).

Per the cost pin this is ~2-3× faster than the cold-start HC step (which is already a
small fraction of multi-element wall); its main role is as the batched solve that
`solve_tree_and_recover` uses to record subdivision-on recovery_error.

Constraints (explicit, no silent fallback):
  * `solver` must be `:hc` — the parametric homotopy is HC-only.
  * sparsification is rejected: warm-start tracks the dense generic system regardless
    of zeroed targets (so it buys no speed) AND per-cell zeroing breaks the shared
    support grouping. Sparsify XOR warm-start.
  * an anchor failure fails the whole group; the leaves get the classified status
    (`:hc_missing` vs `:exception`) — never a silent empty result (cluster regression).
"""
function solve_tree_leaves_warmstart(
    tree::SubdivisionTree;
    dedup_tol::Float64 = 1e-6,
    solver::Symbol = :hc,
    sparsify_threshold::Float64 = 0.0,
)
    solver == :hc || error(
        "solve_tree_leaves_warmstart requires solver=:hc (parametric homotopy is HC-only)",
    )
    sparsify_threshold > 0.0 && error(
        "sparsify_threshold>0 is incompatible with parametric warm-start: warm-start tracks " *
        "the dense generic system regardless of zeroed targets (no speedup) AND per-cell " *
        "zeroing breaks the shared-support grouping. Use solve_tree_leaves (cold) for sparsification.",
    )

    leaves = collect_stabilized_leaves(tree)
    all_cps = Vector{Float64}[]
    leaf_status = Dict{Int,Symbol}()
    path_stats = Dict{Int,NTuple{3,Int}}()
    isempty(leaves) && return (;
        critical_points = all_cps,
        leaf_status = leaf_status,
        path_stats = path_stats,
    )

    # Group by support so each batch shares one anchor. Mixed-degree (p-refinement)
    # trees naturally produce several groups; we never assume a single group.
    groups = Dict{Any,Vector{StabilizedLeaf}}()
    for l in leaves
        push!(get!(groups, group_key(l.polynomial), StabilizedLeaf[]), l)
    end

    for (key, gleaves) in groups
        support = gleaves[1].polynomial.support
        n = size(support, 2)
        cell_coeffs = [cell_monomial_coeffs(l.polynomial) for l in gleaves]

        local res
        try
            res = _solve_hc_parametric(support, n, cell_coeffs)
        catch e
            status = _classify_solve_failure(e)
            for l in gleaves
                leaf_status[l.leaf_id] = status
            end
            @warn "solve_tree_leaves_warmstart: parametric solve failed for support group" key exception =
                e
            continue
        end

        for (l, (realsols, stats)) in zip(gleaves, res.per_cell)
            for pt in realsols
                push!(all_cps, _to_original_domain(pt, l.bounds))
            end
            leaf_status[l.leaf_id] = :ran
            path_stats[l.leaf_id] = stats
        end
    end

    return (;
        critical_points = _dedup_points(all_cps, dedup_tol),
        leaf_status = leaf_status,
        path_stats = path_stats,
    )
end

"""
    solve_tree_and_recover(tree, true_params; strategy=:coldstart, solver=:hc, dedup_tol=1e-6)
        -> (; critical_points, leaf_status, recovery, path_stats)

Solve every leaf of a (stabilized) tree and RECORD parameter recovery against
`true_params` — the metric the subdivision audits never captured (the Part A gap).
This is the headline deliverable of Part C: it lets a subdivision run finally report a
`recovery_error` so subdivision-ON cells of the benefit matrix can be filled.

`strategy`:
  * `:coldstart` (default) — solve via `solve_tree_leaves` (per-cell cold HC). Lowest risk.
  * `:parametric` — solve via `solve_tree_leaves_warmstart` (batched warm-start, ~2-3× on
    the HC step). Validate no-loss against `:coldstart`/`:msolve` before relying on it.

`recovery` is `nothing` when `true_params === nothing` or no critical points were found;
otherwise `(; recovery_error, best_estimate)` for the critical point closest to `true_params`.
"""
function solve_tree_and_recover(
    tree::SubdivisionTree,
    true_params::Union{AbstractVector,Nothing};
    strategy::Symbol = :coldstart,
    solver::Symbol = :hc,
    dedup_tol::Float64 = 1e-6,
)
    res = if strategy == :parametric
        solve_tree_leaves_warmstart(tree; dedup_tol = dedup_tol, solver = solver)
    elseif strategy == :coldstart
        solve_tree_leaves(tree; dedup_tol = dedup_tol, solver = solver)
    else
        error("unknown strategy=$strategy (use :coldstart or :parametric)")
    end

    cps = res.critical_points
    recovery = if true_params === nothing || isempty(cps)
        nothing
    else
        dists = [sqrt(sum(abs2, cp .- true_params)) for cp in cps]
        i = argmin(dists)
        (; recovery_error = dists[i], best_estimate = cps[i])
    end

    return (;
        critical_points = cps,
        leaf_status = res.leaf_status,
        recovery = recovery,
        path_stats = hasproperty(res, :path_stats) ? res.path_stats : nothing,
    )
end
