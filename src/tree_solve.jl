"""
    solve_tree_leaves(tree::SubdivisionTree; solver=:hc, dedup_tol=1e-6)
        -> (; critical_points::Vector{Vector{Float64}}, cp_leaf_ids::Vector{Int},
             leaf_status::Dict{Int,Symbol}, path_stats::Dict{Int,NamedTuple})

Solve the gradient system on every leaf polynomial of a finished
`SubdivisionTree`. Returns a NamedTuple with deduplicated critical points
(original-domain coordinates), the id of the leaf that produced each kept
point (`cp_leaf_ids`, aligned with `critical_points`), a per-leaf status
map, and per-leaf HC solve statistics (`path_stats`: start system actually
used, `paths_tracked`, solution counts, and the sparsification support
before/after — recorded per leaf for `:hc`; empty for `:msolve`).

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
- `rational_types::Vector{Tuple{Int,Int}} = []`: union with rational surrogates.
  When non-empty, each leaf ALSO fits the listed rational types (M, N) to its own
  stored samples (`rational_fit_on_points`, LM fit, no new evaluations of f). The one
  with the smallest held-out relative residual among those whose denominator is
  certified positive on the leaf (`certify_positive_denominator`) is kept, and its
  in-leaf critical points are added to the leaf's polynomial critical points.
  Polynomial points come first in the deduplication, so the result is a superset
  of the polynomial-only result. Measured on 64 random instances (152 paired runs,
  bead 8f4p.7.9): it never lost a critical point against polynomial leaves and
  raised recall from 73 % to 89 %, at 1.6–2× the candidates. Types with more
  unknowns than the leaf's training samples are skipped.
- `rational_weights::Symbol = :christoffel`: row weights of those fits.
  `:christoffel` uses √(m / K_Λ(x)) with the leaf degree's kernel, for trees built
  with `sampling = :christoffel`; `:uniform` is for tensor-grid samples.
- `rational_holdout::Float64 = 0.2`, `rational_seed::Int = 0`: the held-out
  fraction and the seed of the split used to choose the type.
- `rational_solver::Symbol = :polyhedral`: `method` of `solve_rational_critical_points`
  for the leaf fits — `:parametric` compiles one family per shape `(n, M, N)` and
  tracks `rational_generic_path_count` paths per leaf (Phase-3 brief B1.2).
- `rational_fit::Symbol = :lm`: `:lm` (`rational_lm_refit`) or `:pts`, the
  positive-denominator fit (q ≥ 0.01 · mean(q) at points and exchanged minimisers
  of q); see `rational_fit_on_points`.

Returns, besides the fields above, `cp_sources` (`:polynomial` or `:rational` per
kept point) and `rational_choice` (leaf id → `(M, N, heldout)` of the kept rational,
or `nothing` when no type was certified).

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
    rational_types::Vector{Tuple{Int,Int}} = Tuple{Int,Int}[],
    rational_weights::Symbol = :christoffel,
    rational_holdout::Float64 = 0.2,
    rational_seed::Int = 0,
    rational_fit::Symbol = :lm,
    rational_solver::Symbol = :polyhedral,
    representation::Symbol = :monomial,
)
    rational_solver in (:polyhedral, :total_degree, :parametric) || throw(
        ArgumentError(
            "rational_solver must be :polyhedral, :total_degree or :parametric, got $rational_solver",
        ),
    )
    rational_weights in (:christoffel, :uniform) || throw(
        ArgumentError(
            "rational_weights must be :christoffel or :uniform, got $rational_weights",
        ),
    )
    0 < rational_holdout < 1 || throw(ArgumentError("rational_holdout must be in (0, 1)"))
    rational_fit in (:lm, :pts) ||
        throw(ArgumentError("rational_fit must be :lm or :pts, got $rational_fit"))
    if !isempty(rational_types)
        for id in vcat(tree.converged_leaves, tree.active_leaves)
            sd = tree.subdomains[id]
            sd.polynomial === nothing && continue
            sd.transform === nothing || throw(
                ArgumentError(
                    "rational_types: leaf $id has a rotated frame (transform); the union is defined for axis-aligned leaves only",
                ),
            )
            sd.samples === nothing &&
                throw(ArgumentError("rational_types: leaf $id kept no samples to fit"))
        end
    end
    all_cps = Vector{Float64}[]
    all_sources = Symbol[]
    rational_choice = Dict{Int,Any}()
    all_leaf_tags = Int[]
    leaf_status = Dict{Int,Symbol}()
    # Per-leaf HC solve statistics: tracked-path counts must be
    # recorded, not inferred from the start-system's nominal bound. :hc only;
    # msolve leaves no entry.
    path_stats = Dict{Int,NamedTuple}()
    leaf_ids = vcat(tree.converged_leaves, tree.active_leaves)

    for leaf_id in leaf_ids
        sd = tree.subdomains[leaf_id]
        if sd.polynomial === nothing
            leaf_status[leaf_id] = :skipped
            continue
        end

        leaf_bounds = get_bounds(sd)
        stats_ref = Base.RefValue{Any}(nothing)

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
                path_stats_ref = stats_ref,
                representation = representation,  # :monomial | :chebyshev (chebyshev_eval.jl)
            )
            append!(all_cps, cps)
            append!(all_leaf_tags, fill(leaf_id, length(cps)))
            append!(all_sources, fill(:polynomial, length(cps)))
            leaf_status[leaf_id] = :ran
            stats_ref[] === nothing || (path_stats[leaf_id] = stats_ref[])
        catch e
            @warn "solve_tree_leaves: HC solve failed on leaf $leaf_id" exception = e
            leaf_status[leaf_id] = _classify_solve_failure(e)
        end
    end

    # union with the leaves' best certified rational surrogates (after all polynomial
    # points, so deduplication keeps the polynomial point when both find one)
    if !isempty(rational_types)
        for leaf_id in leaf_ids
            sd = tree.subdomains[leaf_id]
            sd.polynomial === nothing && continue
            choice, pts = _best_leaf_rational(
                sd,
                rational_types,
                rational_weights,
                rational_holdout,
                rational_seed + leaf_id,
                rational_fit,
                rational_solver,
            )
            rational_choice[leaf_id] = choice
            for u in pts
                push!(all_cps, sd.center .+ sd.half_widths .* u)
                push!(all_leaf_tags, leaf_id)
                push!(all_sources, :rational)
            end
        end
    end

    keep_idx = _dedup_point_indices(all_cps, dedup_tol)
    return (;
        critical_points = all_cps[keep_idx],
        cp_sources = all_sources[keep_idx],
        rational_choice = rational_choice,
        # CP→leaf provenance, aligned with critical_points: yield-vs-observables
        # analysis needs to know which leaf produced each CP.
        cp_leaf_ids = all_leaf_tags[keep_idx],
        leaf_status = leaf_status,
        path_stats = path_stats,
    )
end

"""
    _best_leaf_rational(sd, types, weights, holdout, seed, fit, solver = :polyhedral) -> (choice, points)

The leaf's best certified rational surrogate among `types`, fitted to its stored
samples (penalized rows dropped): the smallest held-out relative residual among fits
whose denominator is certified positive on the leaf; the winner is refit on all
samples and solved. `points` are its critical points inside the leaf, in leaf
coordinates [-1, 1]^n; `choice` is `(M, N, heldout)` or `nothing`.
"""
function _best_leaf_rational(
    sd,
    types,
    weights,
    holdout,
    seed,
    fit,
    solver::Symbol = :polyhedral,
)
    pen = Set(sd.penalized_rows)
    keep = [!(i in pen) for i in 1:size(sd.samples, 1)]
    S = Matrix{Float64}(sd.samples[keep, :])
    y = Vector{Float64}(sd.f_values[keep])
    K, n = size(S)
    w = if weights == :christoffel
        Λ = SupportGen(n, (:one_d_for_all, sd.degree)).data
        [sqrt(size(Λ, 1) / christoffel_kernel_chebyshev(Λ, S[i, :])) for i in 1:K]
    else
        ones(K)
    end
    perm = randperm(Random.Xoshiro(seed), K)
    nho = max(1, floor(Int, holdout * K))
    ho, tr = sort(perm[1:nho]), sort(perm[nho+1:end])
    best = nothing
    for (M, N) in types
        binomial(n + M, M) + binomial(n + N, N) < length(tr) || continue
        R = try
            rational_fit_on_points(S[tr, :], y[tr], M, N; sqrt_w = w[tr], fit = fit)
        catch e
            e isa ArgumentError || e isa LinearAlgebra.SingularException || rethrow()
            continue
        end
        h =
            sqrt(sum(abs2, [R(S[i, :]) for i in ho] .- y[ho]) / nho) / sqrt(sum(abs2, y[ho]) / nho)
        (best === nothing || h < best[3]) || continue
        certify_positive_denominator(R).ok || continue
        best = (M, N, h)
    end
    best === nothing && return nothing, Vector{Float64}[]
    R = rational_fit_on_points(S, y, best[1], best[2]; sqrt_w = w, fit = fit)
    res = solve_rational_critical_points(R; method = solver)
    return best, [Vector{Float64}(x) for x in res.points if all(abs.(x) .<= 1 + 1e-9)]
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
