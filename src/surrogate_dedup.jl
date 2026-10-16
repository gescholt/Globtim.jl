# surrogate_dedup.jl
#
# N5 of docs/research/plans/EVIDENCE_MAP_2026-10.md: deduplicate on the surrogate before
# touching f. The record: 63–97 % of tree polish iterations go to redundant seeds (median
# 16 seeds per point), the Nelder–Mead polish is 40–70 % of the Mars wall, and the batch
# refiner runs sequentially at 1.7 s per candidate with ~1000 ODE solves each
# (`SEEDING_FINDINGS.md:985-1001`, `mars_globtim_census/README.md:32-34`). Every one of
# those seeds was a root of the same polynomial p; polishing it on p costs microseconds
# and makes the duplicates coincide, so the expensive refinement on f needs one start per
# cluster.
#
# Everything here is in BOX coordinates ẑ ∈ [−1,1]^n, where the solver returns its roots
# and the surrogate is best conditioned; p̂(ẑ) = p(center + scale ⋅ ẑ) as in
# surrogate_residual.jl. The raw census is not changed by this file: it tags points.

"""
    newton_polish_on_surrogate(pol::ApproxPoly, ẑ0; iters = 20, step_max = 0.05, gtol = 1e-13)
        -> (ẑ, converged, grad_norm, n_iter)

Damped Newton on `∇p̂ = 0` from `ẑ0` (box coordinates), gradient and Hessian by
ForwardDiff on the surrogate. Steps are capped at `step_max` per coordinate so a root
that HC placed on a flat ridge does not jump to another basin; `converged` when
`‖∇p̂‖ ≤ gtol · G` for the surrogate's own gradient scale `G` (max over the fit grid, as
in [`surrogate_gradient_residuals`](@ref)) or when the step falls below `1e-14`.
"""
function newton_polish_on_surrogate(
    pol::ApproxPoly,
    ẑ0::AbstractVector{<:Real};
    iters::Int = 20,
    step_max::Real = 0.05,
    gtol::Real = 1e-13,
    gscale::Real = NaN,
)
    phat(ẑ) = evaluate(pol, pol.center .+ pol.scale_factor .* ẑ)
    G = isnan(gscale) ? _surrogate_gradient_scale(pol) : Float64(gscale)
    G = G > 0 ? G : 1.0
    ẑ = Vector{Float64}(ẑ0)
    gn = NaN
    k = 0
    while k < iters
        k += 1
        g = ForwardDiff.gradient(phat, ẑ)
        gn = norm(g)
        gn <= gtol * G && return (ẑ, true, gn, k)
        H = ForwardDiff.hessian(phat, ẑ)
        step = try
            -(H \ g)
        catch
            return (ẑ, false, gn, k)
        end
        all(isfinite, step) || return (ẑ, false, gn, k)
        s = maximum(abs, step)
        s > step_max && (step .*= step_max / s)
        ẑ .+= step
        s < 1e-14 && break
    end
    gn = norm(ForwardDiff.gradient(phat, ẑ))
    return (ẑ, gn <= gtol * G, gn, k)
end

function _surrogate_gradient_scale(pol::ApproxPoly; scale_rows::Int = 2048)
    phat(ẑ) = evaluate(pol, pol.center .+ pol.scale_factor .* ẑ)
    n = length(pol.center)
    grid = pol.grid
    rows = size(grid, 2) == n
    n_grid = rows ? size(grid, 1) : size(grid, 2)
    G = 0.0
    for i in _strided_rows(n_grid, scale_rows)
        gi = rows ? view(grid, i, :) : view(grid, :, i)
        G = max(G, norm(ForwardDiff.gradient(phat, Vector{Float64}(gi))))
    end
    return G
end

"""
    cluster_points(points, tol) -> (cluster_id::Vector{Int}, cluster_size::Vector{Int}, representative::Vector{Bool})

Greedy clustering by Euclidean distance `< tol` to a cluster's first member (the same
rule as `_dedup_point_indices`, returning the membership instead of the kept indices).
The representative of a cluster is its first member.
"""
function cluster_points(points::AbstractVector{<:AbstractVector{<:Real}}, tol::Real)
    tol > 0 || throw(ArgumentError("cluster tolerance must be > 0, got $tol"))
    n = length(points)
    cluster_id = zeros(Int, n)
    reps = Int[]
    for i in 1:n
        found = 0
        for (c, j) in enumerate(reps)
            if sum(abs2, points[i] .- points[j]) < tol^2
                found = c
                break
            end
        end
        if found == 0
            push!(reps, i)
            cluster_id[i] = length(reps)
        else
            cluster_id[i] = found
        end
    end
    sizes = zeros(Int, length(reps))
    for c in cluster_id
        sizes[c] += 1
    end
    representative = falses(n)
    for j in reps
        representative[j] = true
    end
    return (cluster_id = cluster_id, cluster_size = sizes[cluster_id], representative = representative)
end

"""
    dedupe_on_surrogate(pol::ApproxPoly, points_box; tol = 1e-6, polish = true, kwargs...)
        -> NamedTuple

Polish every root on the surrogate ([`newton_polish_on_surrogate`](@ref), skipped with
`polish = false`), then cluster the polished points at `tol` (box coordinates). Returns
`(polished, cluster_id, cluster_size, representative, n_clusters, n_converged, moved)`
where `moved[i] = ‖polished_i − points_i‖` and `n_converged` counts polishes that reached
the gradient tolerance. Points outside `[-1-margin, 1+margin]^n` are clustered as they
are (no polish): the surrogate is meaningless there and they are discarded downstream.
"""
function dedupe_on_surrogate(
    pol::ApproxPoly,
    points_box::AbstractVector{<:AbstractVector{<:Real}};
    tol::Real = 1e-6,
    polish::Bool = true,
    margin::Real = 0.5,
    kwargs...,
)
    n = length(points_box)
    polished = [Vector{Float64}(p) for p in points_box]
    moved = zeros(n)
    n_conv = 0
    if polish && n > 0
        G = _surrogate_gradient_scale(pol)
        for i in 1:n
            any(z -> abs(z) > 1 + margin, points_box[i]) && continue
            ẑ, conv, _, _ = newton_polish_on_surrogate(pol, points_box[i]; gscale = G, kwargs...)
            conv && (n_conv += 1)
            moved[i] = norm(ẑ .- points_box[i])
            polished[i] = ẑ
        end
    end
    cl = cluster_points(polished, tol)
    return (
        polished = polished,
        cluster_id = cl.cluster_id,
        cluster_size = cl.cluster_size,
        representative = cl.representative,
        n_clusters = isempty(cl.cluster_id) ? 0 : maximum(cl.cluster_id),
        n_converged = n_conv,
        moved = moved,
    )
end
