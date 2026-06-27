# adaptive_subdivision.jl
# Adaptive domain subdivision for error-driven polynomial approximation
#
# Key design principles:
# 1. Minimize function evaluations (expensive for complex objective functions)
# 2. Reuse existing Chebyshev samples where possible
# 3. Statistical dimension selection from residuals (no new evaluations)
# 4. Parallel processing of independent subdomains

using LinearAlgebra
using Statistics
using Base.Threads
using Printf #==============================================================================#

#                           DATA STRUCTURES                                     #

"""
    Subdomain

Represents a subdomain in the adaptive refinement tree.

# Fields
- `center::Vector{Float64}`: Center point in original coordinates
- `half_widths::Vector{Float64}`: Half-width in each dimension (anisotropic support)
- `l2_error::Float64`: Estimated L2 approximation error on this subdomain
- `depth::Int`: Depth in subdivision tree (root = 0)
- `degree::Int`: Polynomial degree used on this subdomain (0 = not yet assigned;
  children inherit parent's degree on subdivision)
- `parent_id::Union{Int, Nothing}`: Index of parent subdomain (nothing for root)
- `polynomial::Union{ApproxPoly, Nothing}`: Polynomial approximation (if computed)
- `samples::Union{Matrix{Float64}, Nothing}`: Cached sample points (for reuse)
- `f_values::Union{Vector{Float64}, Nothing}`: Cached function values at samples
- `children::Union{Tuple{Int,Int}, Nothing}`: Child subdomain IDs (left, right) if split
- `split_dim::Union{Int, Nothing}`: Dimension along which this subdomain was split
- `split_pos::Union{Float64, Nothing}`: Cut position in [-1,1] normalized coordinates
- `infeasible::Bool`: All sample evaluations returned Inf — region is unfit for polynomial
  approximation and should be terminated as `ActionPruned` rather than split forever.
- `masked::Bool`: Sampled values are a finite penalty/flat-barrier plateau (detected by a
  caller-supplied `barrier_detector`; bead yhta). Like `infeasible` it terminates the leaf as
  `ActionPruned` — but the data is finite, not Inf. Masked leaves are excluded from
  `total_error` and from `solve_tree_leaves` (the polynomial fits a discontinuity, so its
  critical points are spurious). Default `false`; only set when barrier masking is enabled.
- `mode_spectrum::Vector{Float64}`: Per-Chebyshev-mode residual coefficients η_α
  for modes with `degree < |α|_∞ ≤ extended_degree` (bead dksx.0). Empty until
  `compute_subdomain_mode_spectrum!` is called.
- `dominant_mode::Vector{Int}`: argmax_α η_α (multi-index of the residual's
  largest mode); zeros until computed.
- `spectral_concentration::Float64`: fraction of squared η-mass in modes with
  `|α|_∞ ∈ {degree+1, degree+2}`. NaN until computed.
- `per_dim_degree::Union{Nothing, Vector{Int}}`: anisotropic per-axis polynomial degree
  (bead jl9z.7). `nothing` ⇒ isotropic at `degree`. When set, `degree` carries the scalar
  `maximum(per_dim_degree)` summary (for display/metrics/the `degree > 0` sentinel) while the
  vector carries the real spec consumed by `estimate_subdomain_error` / the fit. Children
  inherit the parent's vector (copied, not aliased) on subdivision.
- `degeneracy::Union{Nothing, DegeneracyDiagnostics}`: per-leaf degeneracy verdict
  (Stage 0 detector). `nothing` until `detect_degeneracy!` is called (opt-in via the
  `degeneracy_opts` kwarg of `adaptive_refine`/`two_phase_refine`). Classifies the leaf as
  `:sloppy_valley` / `:positive_dim_argmin` / `:fold_caustic` / `:multi_sheet` /
  `:isolated_morse`; gates the resolvers.
"""
mutable struct Subdomain
    center::Vector{Float64}
    half_widths::Vector{Float64}
    l2_error::Float64
    relative_l2_error::Float64
    depth::Int
    degree::Int
    parent_id::Union{Int,Nothing}
    polynomial::Union{ApproxPoly,Nothing}
    samples::Union{Matrix{Float64},Nothing}
    f_values::Union{Vector{Float64},Nothing}
    # Split tracking for tree visualization
    children::Union{Tuple{Int,Int},Nothing}
    split_dim::Union{Int,Nothing}
    split_pos::Union{Float64,Nothing}
    infeasible::Bool
    masked::Bool  # yhta: finite penalty/flat-barrier plateau — terminal, excluded from solve & error
    # dksx.0: per-mode residual decomposition (filled lazily by
    # compute_subdomain_mode_spectrum! when the spectral predicate is needed).
    mode_spectrum::Vector{Float64}
    dominant_mode::Vector{Int}
    spectral_concentration::Float64
    # jl9z.7: anisotropic per-axis degree; nothing ⇒ isotropic at `degree`.
    per_dim_degree::Union{Nothing,Vector{Int}}
    # Stage 0: per-leaf degeneracy verdict; nothing until detect_degeneracy! runs.
    degeneracy::Union{Nothing,DegeneracyDiagnostics}
end

# Constructor for new subdomain (no polynomial yet)
function Subdomain(
    center::Vector{Float64},
    half_widths::Vector{Float64};
    depth::Int = 0,
    degree::Int = 0,
    parent_id::Union{Int,Nothing} = nothing,
    per_dim_degree::Union{Nothing,Vector{Int}} = nothing,
    degeneracy::Union{Nothing,DegeneracyDiagnostics} = nothing,
)
    return Subdomain(
        center,
        half_widths,
        Inf,
        Inf,
        depth,
        degree,
        parent_id,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        false,              # infeasible
        false,              # masked (yhta)
        Float64[],          # mode_spectrum (uncomputed)
        Int[],              # dominant_mode (uncomputed)
        NaN,                # spectral_concentration (uncomputed)
        per_dim_degree,     # jl9z.7: anisotropic per-axis degree (nothing ⇒ isotropic)
        degeneracy,         # Stage 0: degeneracy verdict (nothing until detected)
    )
end

# Constructor from bounds
function Subdomain(
    bounds::Vector{Tuple{Float64,Float64}};
    depth::Int = 0,
    degree::Int = 0,
    parent_id::Union{Int,Nothing} = nothing,
    per_dim_degree::Union{Nothing,Vector{Int}} = nothing,
    degeneracy::Union{Nothing,DegeneracyDiagnostics} = nothing,
)
    center = [(b[1] + b[2]) / 2 for b in bounds]
    half_widths = [(b[2] - b[1]) / 2 for b in bounds]
    return Subdomain(
        center,
        half_widths,
        depth = depth,
        degree = degree,
        parent_id = parent_id,
        per_dim_degree = per_dim_degree,
        degeneracy = degeneracy,
    )
end

"""
    get_bounds(subdomain::Subdomain)

Return bounds as vector of (min, max) tuples.
"""
function get_bounds(subdomain::Subdomain)
    return [
        (
            subdomain.center[d] - subdomain.half_widths[d],
            subdomain.center[d] + subdomain.half_widths[d],
        ) for d in 1:length(subdomain.center)
    ]
end

"""
    leaf_degree_spec(subdomain::Subdomain)

Return the degree specification to fit this leaf at: a per-dimension tuple
`(:one_d_per_dim, [d₁,…,dₙ])` when the leaf carries an anisotropic `per_dim_degree`
(bead jl9z.7), otherwise the scalar `degree`. This is the single accessor every
fit/estimate call site uses instead of reading `subdomain.degree` directly, so
anisotropy survives splits instead of being collapsed to `maximum(...)`.
"""
function leaf_degree_spec(subdomain::Subdomain)
    return subdomain.per_dim_degree === nothing ? subdomain.degree :
           (:one_d_per_dim, subdomain.per_dim_degree)
end

"""
    dimension(subdomain::Subdomain)

Return the dimension of the subdomain.
"""
dimension(subdomain::Subdomain) = length(subdomain.center)

"""
    volume(subdomain::Subdomain)

Return the volume (Lebesgue measure) of the subdomain.
"""
volume(subdomain::Subdomain) = prod(2 .* subdomain.half_widths)

"""
    SubdivisionTree

Hierarchical structure for adaptive domain subdivision.

# Fields
- `subdomains::Vector{Subdomain}`: All subdomains (both leaves and internal nodes)
- `active_leaves::Vector{Int}`: Indices of leaves that need refinement (error > tolerance)
- `converged_leaves::Vector{Int}`: Indices of leaves that meet tolerance
- `pruned_leaves::Vector{Int}`: Indices of leaves terminated as infeasible (all-Inf samples).
  Excluded from `tree_solve_leaves` and L2-error totals; visible in `display_tree`.
- `root_id::Int`: Index of root subdomain
"""
mutable struct SubdivisionTree
    subdomains::Vector{Subdomain}
    active_leaves::Vector{Int}
    converged_leaves::Vector{Int}
    pruned_leaves::Vector{Int}
    root_id::Int
end

# Constructor from initial domain
function SubdivisionTree(initial_domain::Subdomain)
    return SubdivisionTree([initial_domain], [1], Int[], Int[], 1)
end

# Constructor from bounds (optional degree sets the root subdomain's degree;
# per_dim_degree seeds an anisotropic root, bead jl9z.7)
function SubdivisionTree(
    bounds::Vector{Tuple{Float64,Float64}};
    degree::Int = 0,
    per_dim_degree::Union{Nothing,Vector{Int}} = nothing,
)
    root = Subdomain(bounds; degree = degree, per_dim_degree = per_dim_degree)
    return SubdivisionTree(root)
end

"""
    n_leaves(tree::SubdivisionTree)

Return total number of leaf subdomains (active + converged + pruned).
"""
n_leaves(tree::SubdivisionTree) =
    length(tree.active_leaves) + length(tree.converged_leaves) + length(tree.pruned_leaves)

"""
    n_pruned(tree::SubdivisionTree)

Return number of leaves terminated as infeasible.
"""
n_pruned(tree::SubdivisionTree) = length(tree.pruned_leaves)

"""
    n_masked(tree::SubdivisionTree)

Return number of leaves terminated as penalty/flat-barrier plateaus (bead yhta).
Masked leaves live in `pruned_leaves` (so `n_pruned` counts them too) but carry
`subdomain.masked == true`; this returns the barrier-only subset.
"""
n_masked(tree::SubdivisionTree) =
    count(id -> tree.subdomains[id].masked, tree.pruned_leaves)

"""
    n_active(tree::SubdivisionTree)

Return number of subdomains still needing refinement.
"""
n_active(tree::SubdivisionTree) = length(tree.active_leaves)

"""
    leaf_error_summary(tree, leaf_ids) -> (max_abs, max_rel)

Return the maximum absolute and relative L2 errors across the given leaf
subdomain ids. Returns `(NaN, NaN)` for an empty collection. Inf values are
preserved (they signal an infeasible leaf or unset error). Used by the
verbose paths in `adaptive_refine` / `two_phase_refine` to surface both
metrics regardless of which `tolerance_mode` drove the convergence check.
"""
function leaf_error_summary(tree::SubdivisionTree, leaf_ids)
    isempty(leaf_ids) && return (NaN, NaN)
    max_abs = -Inf
    max_rel = -Inf
    for id in leaf_ids
        sd = tree.subdomains[id]
        max_abs = max(max_abs, sd.l2_error)
        max_rel = max(max_rel, sd.relative_l2_error)
    end
    return (max_abs, max_rel)
end

"""
    get_max_depth(tree::SubdivisionTree)

Return maximum depth of any subdomain in tree.
"""
function get_max_depth(tree::SubdivisionTree)
    return maximum(sd.depth for sd in tree.subdomains)
end

"""
    total_error(tree::SubdivisionTree)

Return sum of L2 errors across all non-pruned leaves. Pruned leaves are excluded
because their `l2_error == Inf` would otherwise make the total meaningless.
"""
function total_error(tree::SubdivisionTree)
    leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    return sum(tree.subdomains[i].l2_error for i in leaf_ids)
end

"""
    error_balance_ratio(tree::SubdivisionTree)

Return max(error) / min(error) across active leaves.
Returns Inf if any error is zero or only one leaf.
"""
function error_balance_ratio(tree::SubdivisionTree)
    if length(tree.active_leaves) < 2
        return 1.0
    end
    errors = [tree.subdomains[i].l2_error for i in tree.active_leaves]
    min_err = minimum(errors)
    max_err = maximum(errors)
    return min_err > 0 ? max_err / min_err : Inf
end

"""
    display_tree(tree::SubdivisionTree; max_leaves=20, sort_by=:error)

Display subdivision tree as formatted table.

# Arguments
- `max_leaves::Int=20`: Maximum leaves to show
- `sort_by::Symbol=:error`: Sort order - `:error` (descending), `:depth`, `:id`

# Example
```julia
tree = adaptive_refine(f, bounds, 4)
display_tree(tree, max_leaves=10)
```
"""
function display_tree(tree::SubdivisionTree; max_leaves::Int = 20, sort_by::Symbol = :error)
    all_leaves = vcat(tree.converged_leaves, tree.active_leaves, tree.pruned_leaves)
    isempty(all_leaves) && return println("Empty tree")

    n_dim = length(tree.subdomains[1].center)
    converged_set = Set(tree.converged_leaves)
    pruned_set = Set(tree.pruned_leaves)

    # Sort leaves
    sorted_leaves = copy(all_leaves)
    if sort_by == :error
        sort!(sorted_leaves, by = id -> -tree.subdomains[id].l2_error)
    elseif sort_by == :depth
        sort!(sorted_leaves, by = id -> -tree.subdomains[id].depth)
    end

    # Header
    println(
        "SubdivisionTree: $(n_leaves(tree)) leaves, depth=$(get_max_depth(tree)), dim=$n_dim",
    )
    println("Total L2 error: $(round(total_error(tree), sigdigits=4))")
    println(
        "Converged: $(length(tree.converged_leaves)), Active: $(length(tree.active_leaves)), Pruned: $(length(tree.pruned_leaves))",
    )
    println()

    # Table
    Printf.@printf(
        "%-4s  %-5s  %-3s  %-10s  %-8s  %s\n",
        "ID",
        "Depth",
        "Deg",
        "L2 Error",
        "Status",
        "Bounds"
    )
    println("-"^75)

    for id in sorted_leaves[1:min(max_leaves, length(sorted_leaves))]
        sd = tree.subdomains[id]
        bounds = get_bounds(sd)
        bounds_str = join([Printf.@sprintf("[%.2f,%.2f]", b[1], b[2]) for b in bounds], "×")
        status =
            id in pruned_set ? (sd.masked ? "masked" : "pruned") :
            (id in converged_set ? "conv" : "active")
        Printf.@printf(
            "%-4d  %-5d  %-3d  %-10.2e  %-8s  %s\n",
            id,
            sd.depth,
            sd.degree,
            sd.l2_error,
            status,
            bounds_str
        )
    end

    length(sorted_leaves) > max_leaves &&
        println("... $(length(sorted_leaves) - max_leaves) more")
    nothing
end #==============================================================================#

#                       SUBDOMAIN OPERATIONS                                    #

"""
    subdivide_domain(subdomain::Subdomain, dim::Int, cut_position::Float64)

Split a subdomain along dimension `dim` at normalized position `cut_position` ∈ [-1, 1].

Returns tuple (child_left, child_right) where:
- child_left covers [center - half_width, center + cut_position * half_width] in dim
- child_right covers [center + cut_position * half_width, center + half_width] in dim

# Arguments
- `subdomain`: Parent subdomain to split
- `dim`: Dimension to split (1-indexed)
- `cut_position`: Position in [-1, 1] normalized coordinates (0 = midpoint)
"""
function subdivide_domain(subdomain::Subdomain, dim::Int, cut_position::Float64)
    @assert 1 <= dim <= dimension(subdomain) "Invalid dimension: $dim"
    @assert -1.0 <= cut_position <= 1.0 "Cut position must be in [-1, 1], got $cut_position"

    # Compute actual cut point in original coordinates
    cut_point = subdomain.center[dim] + cut_position * subdomain.half_widths[dim]

    # Left child: [lower_bound, cut_point]
    left_center = copy(subdomain.center)
    left_half_widths = copy(subdomain.half_widths)
    lower_bound = subdomain.center[dim] - subdomain.half_widths[dim]
    left_center[dim] = (lower_bound + cut_point) / 2
    left_half_widths[dim] = (cut_point - lower_bound) / 2

    # Right child: [cut_point, upper_bound]
    right_center = copy(subdomain.center)
    right_half_widths = copy(subdomain.half_widths)
    upper_bound = subdomain.center[dim] + subdomain.half_widths[dim]
    right_center[dim] = (cut_point + upper_bound) / 2
    right_half_widths[dim] = (upper_bound - cut_point) / 2

    # jl9z.7: children inherit the parent's anisotropic per-dim degree (copied,
    # not aliased, so a later in-place bump on one child can't mutate its sibling
    # or the parent). nothing ⇒ children stay isotropic at `degree`.
    inherited_per_dim =
        subdomain.per_dim_degree === nothing ? nothing : copy(subdomain.per_dim_degree)

    child_left = Subdomain(
        left_center,
        left_half_widths,
        depth = subdomain.depth + 1,
        degree = subdomain.degree,
        parent_id = nothing,
        per_dim_degree = inherited_per_dim,
    )  # parent_id set by update_tree!
    child_right = Subdomain(
        right_center,
        right_half_widths,
        depth = subdomain.depth + 1,
        degree = subdomain.degree,
        parent_id = nothing,
        per_dim_degree =
            inherited_per_dim === nothing ? nothing : copy(inherited_per_dim),
    )

    return (child_left, child_right)
end

"""
    subdivide_midpoint(subdomain::Subdomain, dim::Int)

Convenience function to subdivide at the midpoint of dimension `dim`.
"""
subdivide_midpoint(subdomain::Subdomain, dim::Int) = subdivide_domain(subdomain, dim, 0.0) #==============================================================================#

#                     STATISTICAL DIMENSION SELECTION                           #

"""
    select_cut_dimension(subdomain::Subdomain)

Select which dimension to cut based on statistical analysis of approximation residuals.

Uses variance of residuals along each dimension as a proxy for "difficulty" -
higher variance suggests the function varies more in that direction.

# Arguments
- `subdomain`: Subdomain with computed polynomial and cached samples/values

# Returns
- Index of dimension to cut (1-indexed)

# Notes
This function requires the subdomain to have:
- `polynomial`: The polynomial approximation
- `samples`: The sample points (normalized to [-1,1]^n)
- `f_values`: The function values at samples
"""
function select_cut_dimension(subdomain::Subdomain)
    @assert subdomain.polynomial !== nothing "Subdomain must have polynomial"
    @assert subdomain.samples !== nothing "Subdomain must have samples"
    @assert subdomain.f_values !== nothing "Subdomain must have f_values"

    n_dim = dimension(subdomain)

    # Compute polynomial values at sample points
    poly_values = evaluate_polynomial_at_samples(subdomain.polynomial, subdomain.samples)

    # Compute residuals
    residuals = subdomain.f_values .- poly_values

    # Compute per-dimension "difficulty" scores
    # Score: mean variance of residuals along dimension d (keeping other dims fixed)
    # High variance = function varies unpredictably in that direction = good cut candidate
    dim_scores = zeros(n_dim)

    for d in 1:n_dim
        # Get unique coordinates in dimension d
        d_unique = sort(unique(subdomain.samples[:, d]))

        # For each unique value in other dimensions, compute variance of residuals along d
        # We approximate this by grouping by the "complementary" dimension for 2D case
        # For higher D, we use all unique values in dimension d and average variances

        if n_dim == 2
            # For 2D: group by the other dimension and compute variance along d
            other_d = 3 - d  # Switch between 1 and 2
            other_unique = sort(unique(subdomain.samples[:, other_d]))

            vars = Float64[]
            for other_val in other_unique
                mask = isapprox.(subdomain.samples[:, other_d], other_val)
                if sum(mask) > 1  # Need at least 2 points for variance
                    push!(vars, var(residuals[mask]))
                end
            end
            dim_scores[d] = isempty(vars) ? 0.0 : mean(vars)
        else
            # For nD tensor grids: group by all OTHER dimensions, measure variance along d
            # Points that share coordinates in all dims except d form a 1D "slice" along d
            samples = subdomain.samples
            other_dims = setdiff(1:n_dim, d)

            # Group points by their coordinates in other dimensions
            # Use rounded keys to handle floating point comparison
            groups = Dict{Vector{Float64},Vector{Int}}()
            for i in 1:size(samples, 1)
                key = round.(samples[i, other_dims], digits = 10)
                if !haskey(groups, key)
                    groups[key] = Int[]
                end
                push!(groups[key], i)
            end

            # Compute variance of residuals within each group (along dimension d)
            vars = Float64[]
            for indices in values(groups)
                if length(indices) > 1
                    push!(vars, var(residuals[indices]))
                end
            end
            dim_scores[d] = isempty(vars) ? 0.0 : mean(vars)
        end
    end

    # Return dimension with highest score
    return argmax(dim_scores)
end

"""
    select_cut_dimension_by_width(subdomain::Subdomain)

Simple fallback: select dimension with largest half-width.
"""
function select_cut_dimension_by_width(subdomain::Subdomain)
    return argmax(subdomain.half_widths)
end

"""
    evaluate_polynomial_at_samples(pol::ApproxPoly, samples::Matrix{Float64})

Evaluate polynomial at given sample points (in normalized [-1,1]^n coordinates).

# Arguments
- `pol`: Polynomial approximation
- `samples`: Matrix of sample points (n_samples × n_dim)

# Returns
- Vector of polynomial values at sample points
"""
function evaluate_polynomial_at_samples(pol::ApproxPoly, samples::Matrix{Float64})
    # Create Vandermonde matrix for evaluation
    # samples is (n_samples, n_dim) which is the correct format for lambda_vandermonde
    Lambda = SupportGen(size(samples, 2), pol.degree)
    V = lambda_vandermonde(Lambda, samples, basis = pol.basis)

    # Evaluate: V * coeffs
    return V * pol.coeffs
end #==============================================================================#

#                      DEGREE SPEC UTILITIES                                    #

"""
    _extract_per_dim_degrees(degree, n_dim) -> Vector{Int}

Normalize any degree specification to a per-dimension degree vector.

# Examples
```julia
_extract_per_dim_degrees(4, 2)                       # → [4, 4]
_extract_per_dim_degrees((:one_d_for_all, 4), 2)     # → [4, 4]
_extract_per_dim_degrees((:one_d_per_dim, [4, 8]), 2) # → [4, 8]
```
"""
function _extract_per_dim_degrees(degree, n_dim::Int)::Vector{Int}
    if degree isa Integer
        return fill(Int(degree), n_dim)
    elseif degree isa Tuple
        mode, spec = degree
        if mode == :one_d_for_all
            return fill(Int(spec), n_dim)
        elseif mode == :one_d_per_dim
            length(spec) == n_dim ||
                error("per-dim degree vector length $(length(spec)) ≠ n_dim=$n_dim")
            return Int.(spec)
        else
            error("Unsupported degree mode: $mode")
        end
    else
        error("Unsupported degree type: $(typeof(degree))")
    end
end

"""
    _root_per_dim_degree(degree) -> Union{Nothing, Vector{Int}}

jl9z.7: a caller-supplied `(:one_d_per_dim, [d₁,…,dₙ])` spec seeds the root leaf's
anisotropic `per_dim_degree` so the per-axis budget survives every split. Scalar
and `(:one_d_for_all, d)` specs stay isotropic (returns `nothing`), preserving the
total-degree basis and byte-identical default behavior.
"""
_root_per_dim_degree(degree) =
    (degree isa Tuple && degree[1] === :one_d_per_dim) ? collect(Int.(degree[2])) :
    nothing #==============================================================================#

#                      ERROR ESTIMATION                                         #

"""
    estimate_subdomain_error(f, subdomain::Subdomain, degree;
                             n_samples_per_dim::Int=0, basis::Symbol=:chebyshev,
                             use_cache::Bool=true,
                             thread_evals::Bool=false,
                             inherit_from::Union{Nothing, Subdomain}=nothing)

Estimate L2 approximation error on a subdomain.

Uses sparse Chebyshev sampling (~2× number of coefficients) for efficiency.

# Arguments
- `f`: Function to approximate
- `subdomain`: Subdomain to evaluate
- `degree`: Polynomial degree (or degree specification)
- `n_samples_per_dim`: Grid points per dimension (0 = auto: 2×degree+1)
- `basis`: Basis type (:chebyshev or :legendre)
- `use_cache`: When `true`, return the cached L2 error if the subdomain already
  has `polynomial`/`samples`/`f_values` populated at a compatible grid size (this
  is how the trial-cut reuse from `find_optimal_cut_sparse` avoids redundant
  polynomial construction on the split children). Set to `false` to force
  re-evaluation.
- `thread_evals`: When `true` and `Threads.nthreads() > 1`, evaluate grid
  points concurrently via `@spawn`-chunked tasks. Caller is responsible for
  passing a thread-safe `f` (e.g. an ODE objective that uses `remake` rather
  than in-place parameter mutation). `eval_progress` is ignored in this mode.
- `inherit_from`: Optional parent `Subdomain`. When the parent has cached
  `samples`/`f_values`, any parent sample that remaps inside this subdomain's
  box is reused (its `f`-value is inherited), and `f` is evaluated only on
  the fresh Chebyshev rows that don't coincide with an inherited point. The
  least-squares solve uses the combined (non-tensor) sample set. This is the
  y0j parent→child reuse integration point; see `subdivision_reuse.jl` for
  the pure remap/dedupe helpers.

# Returns
- Estimated L2 error

# Side Effects
Updates subdomain.l2_error, subdomain.polynomial, subdomain.samples, subdomain.f_values
"""
function estimate_subdomain_error(
    f,
    subdomain::Subdomain,
    degree;
    n_samples_per_dim::Int = 0,
    basis::Symbol = :chebyshev,
    eval_progress::Union{Function,Nothing} = nothing,
    use_cache::Bool = true,
    thread_evals::Bool = false,
    inherit_from::Union{Nothing,Subdomain} = nothing,
    sampling::Symbol = :tensor,
    christoffel_oversampling::Float64 = 2.0,
    rng_seed::Union{Nothing,Integer} = nothing,
)
    n_dim = dimension(subdomain)

    # ── Christoffel-sampled branch (E1 Phase 2, opt-in) ────────────────────
    # Bypasses tensor-grid + inheritance + unweighted-LS path entirely.
    # Cache reuse mirrors the tensor path: a previously-fitted christoffel
    # leaf at the same K is reused. RNG is per-leaf-deterministic when
    # `rng_seed` is supplied (the audit driver derives one from cell id).
    if sampling === :christoffel
        if use_cache &&
           subdomain.polynomial !== nothing &&
           subdomain.samples !== nothing &&
           subdomain.f_values !== nothing &&
           isfinite(subdomain.l2_error)
            return subdomain.l2_error
        end
        per_dim_degrees_chr = _extract_per_dim_degrees(degree, n_dim)
        deg_for_chr = maximum(per_dim_degrees_chr)
        rng = rng_seed === nothing ? Random.default_rng() : Random.MersenneTwister(rng_seed)
        chr_result = christoffel_subdomain_fit(
            f,
            subdomain,
            deg_for_chr;
            oversampling_c = christoffel_oversampling,
            basis = basis,
            rng = rng,
            thread_evals = thread_evals,
        )
        if chr_result.infeasible
            subdomain.l2_error = Inf
            subdomain.relative_l2_error = Inf
            subdomain.polynomial = nothing
            subdomain.samples = chr_result.samples
            subdomain.f_values = chr_result.f_values
            subdomain.infeasible = true
            return Inf
        end
        # Build the ApproxPoly with the christoffel coefficients in the same
        # tensor-Chebyshev basis the audit predicate / HC expects.
        d_spec = degree isa Tuple ? degree : (:one_d_for_all, degree)
        pol = ApproxPoly{Float64}(
            chr_result.coeffs,
            chr_result.Lambda.data,
            d_spec,
            chr_result.l2_error,
            chr_result.K_used,
            subdomain.half_widths,
            subdomain.center,
            collect(chr_result.samples'),  # n_dim × K
            chr_result.f_values,
            basis,
            Float64Precision,
            true,
            false,
            chr_result.kappa,
        )
        subdomain.l2_error = chr_result.l2_error
        subdomain.relative_l2_error = chr_result.relative_l2_error
        subdomain.polynomial = pol
        subdomain.samples = chr_result.samples
        subdomain.f_values = chr_result.f_values
        return chr_result.l2_error
    end

    # Determine per-dimension grid sizes (GN values; grid will have GN+1 points per dim)
    per_dim_degrees = _extract_per_dim_degrees(degree, n_dim)
    if n_samples_per_dim > 0
        # Manual override: uniform samples in all dims
        per_dim_GN = fill(n_samples_per_dim - 1, n_dim)
    else
        per_dim_GN = 2 .* per_dim_degrees  # ~2× degree per dimension
    end

    expected_n_samples = prod(per_dim_GN .+ 1)

    # Reuse cached evaluation when the subdomain already has a polynomial built
    # at a compatible grid size (e.g. a child populated by find_optimal_cut_sparse).
    # We verify sample count rather than degree because only the grid determines
    # the underlying evaluation cost we want to avoid.
    if use_cache &&
       subdomain.polynomial !== nothing &&
       subdomain.samples !== nothing &&
       subdomain.f_values !== nothing &&
       size(subdomain.samples, 1) == expected_n_samples &&
       isfinite(subdomain.l2_error)
        return subdomain.l2_error
    end

    # Generate normalized Chebyshev grid in the child's [-1, 1]^n
    grid = if all(==(per_dim_GN[1]), per_dim_GN)
        generate_grid(n_dim, per_dim_GN[1], basis = basis)
    else
        generate_anisotropic_grid(per_dim_GN, basis = basis)
    end
    fresh_grid = grid_to_matrix(grid)  # (n_fresh, n_dim) in child normalized coords
    n_fresh = size(fresh_grid, 1)

    # y0j: inherit parent samples that remap inside this child's box.
    # We split the work into `rows_to_eval` (indices into the combined sample
    # matrix that need a fresh f-evaluation) and the remaining rows whose
    # f-values are copied from the parent cache.
    inherit_ok =
        inherit_from !== nothing &&
        inherit_from.samples !== nothing &&
        inherit_from.f_values !== nothing &&
        size(inherit_from.samples, 1) == length(inherit_from.f_values)
    if inherit_ok
        inside_idx = points_inside_child(inherit_from.samples, inherit_from, subdomain)
    else
        inside_idx = Int[]
    end

    if isempty(inside_idx)
        # Standard path: no inheritable points → evaluate at every fresh row.
        grid_matrix = fresh_grid
        f_values = Vector{Float64}(undef, n_fresh)
        rows_to_eval = 1:n_fresh
        inherited_f_count = 0
    else
        inherited_samples = Matrix{Float64}(undef, length(inside_idx), n_dim)
        @inbounds for (k, i) in enumerate(inside_idx)
            inherited_samples[k, :] .= remap_parent_to_child(
                view(inherit_from.samples, i, :),
                inherit_from,
                subdomain,
            )
        end
        inherited_f = inherit_from.f_values[inside_idx]
        # combined = [inherited; fresh[new_idx]] (new_idx ⊆ 1:n_fresh, no dups with inherited)
        grid_matrix, new_idx = combine_inherited_and_fresh(inherited_samples, fresh_grid)
        n_inh = size(inherited_samples, 1)
        f_values = Vector{Float64}(undef, size(grid_matrix, 1))
        @inbounds for k in 1:n_inh
            f_values[k] = inherited_f[k]
        end
        rows_to_eval = (n_inh+1):(n_inh+length(new_idx))
        inherited_f_count = n_inh
    end
    n_total = size(grid_matrix, 1)

    # Map logical row index (into grid_matrix) → fresh grid index when we need
    # the ORIGINAL normalized coordinates to compute physical f-input. For
    # the inheritance path, fresh rows start at position n_inh+1 and refer to
    # fresh_grid[new_idx[k]]; for the standard path, row i refers directly to
    # grid_matrix[i, :] (which equals fresh_grid[i, :]).
    if isempty(inside_idx)
        eval_sample_source = grid_matrix
        eval_sample_indices = 1:n_fresh  # positions within eval_sample_source
    else
        eval_sample_source = fresh_grid
        eval_sample_indices = new_idx
    end

    # Evaluate function at physical coordinates. Pre-allocate x_physical buffer
    # to avoid per-iteration allocations (critical for 625+ evals in 4D).
    if thread_evals && Threads.nthreads() > 1
        # Threaded path: chunk the eval work across tasks with a per-task x
        # buffer. Per-task (not per-thread) avoids the Threads.threadid()
        # pitfalls that break under task migration in Julia ≥ 1.7.
        # eval_progress is skipped because most callback sinks are not
        # thread-safe.
        n_eval = length(eval_sample_indices)
        chunk_size = max(1, cld(n_eval, 4 * Threads.nthreads()))
        @sync for chunk_start in 1:chunk_size:n_eval
            chunk_end = min(chunk_start + chunk_size - 1, n_eval)
            Threads.@spawn begin
                x_buf = Vector{Float64}(undef, n_dim)
                for k in chunk_start:chunk_end
                    src_i = eval_sample_indices[k]
                    dst_i = rows_to_eval[k]
                    @inbounds for d in 1:n_dim
                        x_buf[d] =
                            subdomain.center[d] +
                            eval_sample_source[src_i, d] * subdomain.half_widths[d]
                    end
                    f_values[dst_i] = f(x_buf)
                end
            end
        end
    else
        x_physical = Vector{Float64}(undef, n_dim)
        n_eval = length(eval_sample_indices)
        for k in 1:n_eval
            eval_progress !== nothing && eval_progress(k, n_eval)
            src_i = eval_sample_indices[k]
            dst_i = rows_to_eval[k]
            @inbounds for d in 1:n_dim
                x_physical[d] =
                    subdomain.center[d] +
                    eval_sample_source[src_i, d] * subdomain.half_widths[d]
            end
            f_values[dst_i] = f(x_physical)
        end
    end

    if inherited_f_count > 0
        @debug "Reused $inherited_f_count/$n_total parent samples" subdomain_n_dim = n_dim
    end

    # Handle Inf values from failed evaluations (e.g., ODE integration failures)
    n_inf = count(isinf, f_values)
    if n_inf == n_total
        # All evaluations failed — no data to fit. Flag infeasible so
        # process_subdomain terminates this leaf as ActionPruned instead of
        # splitting it forever.
        subdomain.l2_error = Inf
        subdomain.relative_l2_error = Inf
        subdomain.polynomial = nothing
        subdomain.samples = grid_matrix
        subdomain.f_values = f_values
        subdomain.infeasible = true
        return Inf
    elseif n_inf > 0
        # Partial failures: replace Inf with a large penalty value so the polynomial
        # can still be constructed. The high error in these regions will cause
        # subdivision to split them, eventually isolating the failing region.
        finite_vals = filter(isfinite, f_values)
        penalty = 10.0 * maximum(abs, finite_vals)
        for i in 1:n_total
            if isinf(f_values[i])
                f_values[i] = penalty
            end
        end
        @debug "Replaced $n_inf/$n_total Inf values with penalty=$penalty"
    end

    # Construct polynomial approximation
    pol = construct_polynomial_on_subdomain(
        f,
        subdomain,
        degree,
        grid_matrix,
        f_values,
        basis,
    )

    # Compute L2 error
    poly_values = evaluate_polynomial_at_samples(pol, grid_matrix)
    errors = f_values .- poly_values
    weight = prod(2.0 ./ (per_dim_GN .+ 1))
    l2_error = sqrt(sum(abs2.(errors)) * weight)

    # Compute relative L2 error: ||f - p||_L2 / ||f||_L2
    norm_f = sqrt(sum(abs2.(f_values)) * weight)
    rel_l2 = if norm_f > 0
        l2_error / norm_f
    elseif l2_error == 0.0
        0.0
    else
        Inf
    end

    # Defensive: catch any remaining NaN from numerical issues
    if isnan(l2_error)
        l2_error = Inf
        rel_l2 = Inf
        pol = nothing
    end

    # Cache everything for reuse
    subdomain.l2_error = l2_error
    subdomain.relative_l2_error = rel_l2
    subdomain.polynomial = pol
    subdomain.samples = grid_matrix
    subdomain.f_values = f_values

    @debug "estimate_subdomain_error" l2_error rel_l2 norm_f degree = per_dim_degrees n_total

    return l2_error
end

"""
    construct_polynomial_on_subdomain(f, subdomain, degree, samples, f_values, basis)

Construct polynomial approximation on a subdomain using least squares.

This wraps the existing Globtim infrastructure (MainGenerate pattern).
"""
function construct_polynomial_on_subdomain(
    _,
    subdomain::Subdomain,
    degree,
    samples::Matrix{Float64},
    f_values::Vector{Float64},
    basis::Symbol,
)
    n_dim = dimension(subdomain)

    # Generate support (multi-index set)
    d_spec = degree isa Tuple ? degree : (:one_d_for_all, degree)
    Lambda = SupportGen(n_dim, d_spec)

    # Build Vandermonde matrix
    # samples is (n_samples, n_dim) which is the correct format for lambda_vandermonde
    V = lambda_vandermonde(Lambda, samples, basis = basis)

    # Solve least squares for coefficients
    coeffs = V \ f_values

    # Compute L2 norm of residual (||f - p||_L2)
    poly_values = V * coeffs
    per_dim_degrees = _extract_per_dim_degrees(degree, n_dim)
    per_dim_GN = 2 .* per_dim_degrees
    weight = prod(2.0 ./ (per_dim_GN .+ 1))
    residuals = f_values .- poly_values
    nrm = sqrt(sum(abs2.(residuals)) * weight)

    # Create ApproxPoly with anisotropic scale_factor
    return ApproxPoly{Float64}(
        coeffs,
        Lambda.data,
        d_spec,
        nrm,
        size(samples, 1),
        subdomain.half_widths,
        subdomain.center,
        collect(samples'),  # Grid stored as n_dim × n_samples (ApproxPoly expects Matrix, not Adjoint)
        f_values,
        basis,
        Float64Precision,
        true,
        false,
        cond(V),
    )
end #==============================================================================#

#                      OPTIMAL CUT SELECTION                                    #

"""
    find_optimal_cut_sparse(f, subdomain::Subdomain, dim::Int, degree;
                            n_candidates::Int=3, basis::Symbol=:chebyshev)

Find optimal cut position along dimension `dim` using sparse evaluation.

Evaluates L2 error at a few candidate cut positions and fits a parabola to find minimum.

# Arguments
- `f`: Function to approximate
- `subdomain`: Subdomain to split
- `dim`: Dimension to split
- `degree`: Polynomial degree
- `n_candidates`: Number of candidate positions to evaluate (default: 3)
- `basis`: Basis type

# Returns
- Optimal cut position in [-1, 1] (0 = midpoint)

# Notes
Uses existing samples where possible to minimize new function evaluations.

# Returns
- `opt_pos::Float64`: Optimal cut position (from parabola fit or best candidate)
- `trial_left::Subdomain`, `trial_right::Subdomain`: Fully-populated trial children
  (samples, f_values, polynomial, l2_error all cached) from the best-scoring
  candidate. Callers can reuse these when the final cut is close to `trial_cut_pos`
  to avoid two redundant polynomial constructions per split.
- `trial_cut_pos::Float64`: The candidate position the returned trial children
  were built at.
"""
function find_optimal_cut_sparse(
    f,
    subdomain::Subdomain,
    dim::Int,
    degree;
    n_candidates::Int = 3,
    basis::Symbol = :chebyshev,
    thread_evals::Bool = false,
)
    # Candidate positions in normalized [-1, 1] coordinates
    # Default: -0.5, 0.0, 0.5 (quarter, half, three-quarters)
    if n_candidates == 3
        candidates = [-0.5, 0.0, 0.5]
    else
        candidates = range(-0.75, 0.75, length = n_candidates)
    end

    # Evaluate combined error for each candidate and keep the trial children so
    # the winner's polynomial construction can be reused downstream.
    errors = Float64[]
    trial_pairs = Vector{Tuple{Subdomain,Subdomain}}(undef, length(candidates))
    for (i, cut_pos) in enumerate(candidates)
        left, right = subdivide_domain(subdomain, dim, cut_pos)

        # Estimate error on both children
        err_left = estimate_subdomain_error(
            f,
            left,
            degree,
            basis = basis,
            thread_evals = thread_evals,
        )
        err_right = estimate_subdomain_error(
            f,
            right,
            degree,
            basis = basis,
            thread_evals = thread_evals,
        )

        # Combined error (sum weighted by volume for fair comparison)
        combined = err_left * sqrt(volume(left)) + err_right * sqrt(volume(right))
        push!(errors, combined)
        trial_pairs[i] = (left, right)
    end

    best_idx = argmin(errors)
    trial_cut_pos = candidates[best_idx]
    trial_left, trial_right = trial_pairs[best_idx]

    # If only 3 candidates, fit parabola and find minimum
    if n_candidates == 3
        # Fit parabola: error = a*x^2 + b*x + c
        A = hcat([[candidates[i]^2, candidates[i], 1.0] for i in 1:3]...)'  # 3×3 matrix
        abc = A \ errors
        a, b = abc[1], abc[2]  # c = abc[3] unused

        # Parabola minimum at x = -b/(2a) if a > 0
        if a > 0
            opt_pos = clamp(-b / (2a), -0.75, 0.75)
        else
            # Parabola opens downward - use best candidate
            opt_pos = trial_cut_pos
        end
    else
        # Just use best candidate
        opt_pos = trial_cut_pos
    end

    return opt_pos, trial_left, trial_right, trial_cut_pos
end

"""
    find_optimal_cut_midpoint(subdomain::Subdomain, dim::Int)

Always return midpoint cut (for comparison/testing).
"""
find_optimal_cut_midpoint(subdomain::Subdomain, dim::Int) = 0.0 #==============================================================================#

#                      MAIN ADAPTIVE REFINEMENT                                 #

"""
    RefinementAction

Action to take on a subdomain after processing.
- `ActionConverged`: L2 error meets tolerance, no further refinement needed.
- `ActionDegreeBump`: Increase polynomial degree and re-fit (p-refinement).
- `ActionSplit`: Subdivide the domain (h-refinement).
- `ActionPruned`: All sample evaluations were Inf — terminate without further work
  (Phase 1 of subdomain pruning; see `pkg/globtim/src/adaptive_subdivision.jl`
  `estimate_subdomain_error` for the detection site).
"""
@enum RefinementAction begin
    ActionConverged
    ActionDegreeBump
    ActionSplit
    ActionPruned
end

"""
    ProcessResult

Result of processing a single subdomain.

When `action == ActionSplit` and `optimize_cuts=true`, `trial_children` carries
the fully-constructed child subdomains from the best candidate cut evaluated by
`find_optimal_cut_sparse`. `update_tree!` reuses them (saving two polynomial
constructions) when the parabola-optimum cut position is within `trial_reuse_tol`
of the candidate position the trials were built at.
"""
struct ProcessResult
    subdomain_id::Int
    action::RefinementAction
    should_split::Bool  # backward compat: action == ActionSplit
    split_dim::Union{Int,Nothing}
    cut_position::Union{Float64,Nothing}
    l2_error::Float64
    new_degree::Union{Int,Nothing}  # for ActionDegreeBump: the scalar degree summary to try next
    trial_children::Union{Nothing,Tuple{Subdomain,Subdomain}}
    trial_cut_pos::Union{Nothing,Float64}
    new_per_dim_degree::Union{Nothing,Vector{Int}}  # jl9z.7: anisotropic bump payload
end

# Backward-compatible constructor for the 7-arg call sites (pre-eqk).
ProcessResult(
    subdomain_id,
    action,
    should_split,
    split_dim,
    cut_position,
    l2_error,
    new_degree,
) = ProcessResult(
    subdomain_id,
    action,
    should_split,
    split_dim,
    cut_position,
    l2_error,
    new_degree,
    nothing,
    nothing,
    nothing,
)

# Backward-compatible constructor for the 9-arg call sites (eqk: trial children,
# pre-jl9z.7 anisotropic bump).
ProcessResult(
    subdomain_id,
    action,
    should_split,
    split_dim,
    cut_position,
    l2_error,
    new_degree,
    trial_children,
    trial_cut_pos,
) = ProcessResult(
    subdomain_id,
    action,
    should_split,
    split_dim,
    cut_position,
    l2_error,
    new_degree,
    trial_children,
    trial_cut_pos,
    nothing,
)

"""
    process_subdomain(f, tree::SubdivisionTree, subdomain_id::Int,
                      degree, l2_tolerance::Float64;
                      optimize_cuts::Bool=true, basis::Symbol=:chebyshev,
                      enable_p_refinement::Bool=false,
                      max_degree::Int=40, degree_step::Int=6,
                      cond_threshold::Float64=1e14)

Process a single subdomain: estimate error, decide action (converge / bump degree / split).

When `enable_p_refinement=true`, a leaf that doesn't meet L2 tolerance will first try
increasing its polynomial degree (p-refinement) before falling back to subdivision
(h-refinement). Degree is increased by `degree_step` up to `max_degree`, gated by
the Vandermonde condition number staying below `cond_threshold`. The `predicate`
keyword chooses between bump and split for each non-converged leaf and may also
return `:done` to short-circuit to `ActionConverged` (see `default_bump` for the
full return-value contract).

# Arguments
- `f`: Function to approximate
- `tree`: Subdivision tree (read-only access to subdomain)
- `subdomain_id`: Index of subdomain to process
- `degree`: Polynomial degree (used if subdomain.degree is 0)
- `l2_tolerance`: Target L2 error tolerance
- `optimize_cuts`: Whether to optimize cut position (vs midpoint)
- `basis`: Basis type
- `enable_p_refinement`: Enable degree bumping before splitting
- `max_degree`: Maximum polynomial degree for p-refinement
- `degree_step`: Degree increment for p-refinement
- `cond_threshold`: Maximum Vandermonde condition number for p-refinement

# Returns
- ProcessResult with decision
"""
function process_subdomain(
    f,
    tree::SubdivisionTree,
    subdomain_id::Int,
    degree,
    l2_tolerance::Float64;
    optimize_cuts::Bool = true,
    basis::Symbol = :chebyshev,
    eval_progress::Union{Function,Nothing} = nothing,
    enable_p_refinement::Bool = false,
    max_degree::Int = 40,
    degree_step::Int = 6,
    cond_threshold::Float64 = 1e14,
    tolerance_mode::Symbol = :relative,
    thread_evals::Bool = false,
    reuse_parent_samples::Bool = true,
    n_samples_per_dim::Int = 0,
    predicate::Function = default_bump,
    barrier_detector::Union{Nothing,Function} = nothing,
    degeneracy_opts::Union{Nothing,NamedTuple} = nothing,
    sampling::Symbol = :tensor,
    christoffel_oversampling::Float64 = 2.0,
    rng_base_seed::Union{Nothing,Integer} = nothing,
)
    tolerance_mode in (:absolute, :relative) ||
        error("Unknown tolerance_mode: $tolerance_mode. Use :absolute or :relative.")

    subdomain = tree.subdomains[subdomain_id]

    # Resolve the degree SPEC to fit this leaf at (jl9z.7). Precedence:
    #   1. an inherited/assigned anisotropic per-dim vector (survives splits), else
    #   2. a previously-bumped scalar degree on the leaf, else
    #   3. the caller's `degree` argument (which may itself be a per-dim tuple).
    # `effective_degree` stays the scalar maximum summary (display/metrics, the
    # `degree > 0` sentinel, and the isotropic p-refinement arithmetic); the spec
    # is what actually drives the fit so anisotropy is no longer collapsed away.
    n_dim = length(subdomain.center)
    effective_spec =
        subdomain.per_dim_degree !== nothing ?
        (:one_d_per_dim, subdomain.per_dim_degree) :
        (subdomain.degree > 0 ? subdomain.degree : degree)
    effective_degree = maximum(_extract_per_dim_degrees(effective_spec, n_dim))
    subdomain.degree = effective_degree

    # y0j: locate the parent's sample cache so inheritable rows can be reused.
    # This fires on the first process_subdomain for a freshly-split child —
    # after that, the subdomain has its own samples cached and the next call
    # (e.g. from a degree bump retry) goes through the standard path.
    inherit_from = nothing
    if reuse_parent_samples &&
       subdomain.samples === nothing &&
       subdomain.parent_id !== nothing
        parent = tree.subdomains[subdomain.parent_id]
        if parent.samples !== nothing && parent.f_values !== nothing
            inherit_from = parent
        end
    end

    # Estimate error on this subdomain. Per-leaf RNG seed is derived from
    # the subdomain id so each leaf's christoffel sample set is reproducible
    # across re-runs (R5 in the E1 plan).
    leaf_seed = rng_base_seed === nothing ? nothing : (rng_base_seed + subdomain_id)
    l2_error = estimate_subdomain_error(
        f,
        subdomain,
        effective_spec,
        basis = basis,
        eval_progress = eval_progress,
        thread_evals = thread_evals,
        inherit_from = inherit_from,
        n_samples_per_dim = n_samples_per_dim,
        sampling = sampling,
        christoffel_oversampling = christoffel_oversampling,
        rng_seed = leaf_seed,
    )

    # Phase 1 prune: every sample returned Inf, no polynomial to fit. Terminate
    # this leaf instead of splitting it indefinitely.
    if subdomain.infeasible
        return ProcessResult(
            subdomain_id,
            ActionPruned,
            false,
            nothing,
            nothing,
            l2_error,
            nothing,
        )
    end

    # yhta: penalty/flat-barrier masking. A leaf whose sampled values are a
    # finite penalty plateau (constant sentinel or near-constant) cannot be
    # improved by splitting or p-refining a discontinuity — the L2 estimator
    # just keeps chasing the step. Mask it as a terminal pruned leaf so the
    # budget flows to the curved feasible region. Excluded from total_error and
    # from solve_tree_leaves (its fit is a step → critical points are spurious).
    # Opt-in: barrier_detector === nothing (the default) leaves behavior unchanged.
    if barrier_detector !== nothing &&
       subdomain.f_values !== nothing &&
       barrier_detector(subdomain.f_values)
        subdomain.masked = true
        @debug "Masked penalty-barrier leaf" subdomain_id l2_error
        return ProcessResult(
            subdomain_id,
            ActionPruned,
            false,
            nothing,
            nothing,
            l2_error,
            nothing,
        )
    end

    # Stage 0: per-leaf degeneracy annotation (opt-in). Runs on every fitted,
    # feasible, non-masked leaf BEFORE the converge/bump/split decision so the
    # verdict is recorded regardless of which action this leaf takes. Non-terminal:
    # it only annotates sd.degeneracy; the resolvers read it. Default-off
    # (degeneracy_opts === nothing) ⇒ behavior unchanged.
    if degeneracy_opts !== nothing && subdomain.polynomial !== nothing
        detect_degeneracy!(subdomain; f = f, degeneracy_opts...)
    end

    # Check convergence using the selected error metric
    effective_error = tolerance_mode == :relative ? subdomain.relative_l2_error : l2_error
    if effective_error <= l2_tolerance
        return ProcessResult(
            subdomain_id,
            ActionConverged,
            false,
            nothing,
            nothing,
            l2_error,
            nothing,
        )
    end

    # Check if p-refinement is possible
    if enable_p_refinement
        decision = predicate(subdomain)
        if decision === :done
            # Predicate explicitly accepts the current fit. Stops refinement on
            # this leaf even when relative_l2_error > l2_tolerance — used by
            # low-start growth strategies whose convergence rule lives in the
            # predicate (e.g. affine-fit-good or certified lower bound clears
            # focus band) rather than in the global l2_tolerance gate.
            return ProcessResult(
                subdomain_id,
                ActionConverged,
                false,
                nothing,
                nothing,
                l2_error,
                nothing,
            )
        end
        next_degree = effective_degree + degree_step
        # jl9z.7: an anisotropic leaf bumps every axis by degree_step so the
        # per-dim shape is preserved; the scalar `next_degree` (= max axis) still
        # gates against max_degree. Isotropic leaves carry nothing → unchanged.
        next_per_dim =
            subdomain.per_dim_degree === nothing ? nothing :
            (subdomain.per_dim_degree .+ degree_step)
        cond_ok =
            subdomain.polynomial !== nothing &&
            subdomain.polynomial.cond_vandermonde < cond_threshold
        if next_degree <= max_degree && cond_ok && decision === :bump
            return ProcessResult(
                subdomain_id,
                ActionDegreeBump,
                false,
                nothing,
                nothing,
                l2_error,
                next_degree,
                nothing,
                nothing,
                next_per_dim,
            )
        end
    end

    # Fall back to h-refinement (split)
    if subdomain.polynomial !== nothing && subdomain.samples !== nothing
        split_dim = select_cut_dimension(subdomain)
    else
        split_dim = select_cut_dimension_by_width(subdomain)
    end

    trial_children = nothing
    trial_cut_pos = nothing
    if optimize_cuts
        cut_pos, trial_left, trial_right, trial_cut_pos = find_optimal_cut_sparse(
            f,
            subdomain,
            split_dim,
            effective_spec,
            basis = basis,
            thread_evals = thread_evals,
        )
        trial_children = (trial_left, trial_right)
    else
        cut_pos = 0.0  # Midpoint
    end

    return ProcessResult(
        subdomain_id,
        ActionSplit,
        true,
        split_dim,
        cut_pos,
        l2_error,
        nothing,
        trial_children,
        trial_cut_pos,
    )
end

"""
    update_tree!(tree::SubdivisionTree, result::ProcessResult, subdomain::Subdomain)

Update tree based on processing result.

# Arguments
- `tree`: Tree to update (mutated)
- `result`: Result from process_subdomain
- `subdomain`: The original subdomain that was processed

# Notes
This function is NOT thread-safe. Call sequentially after parallel processing.
"""
function update_tree!(
    tree::SubdivisionTree,
    result::ProcessResult,
    subdomain::Subdomain;
    trial_reuse_tol::Float64 = 0.1,
)
    if result.action == ActionSplit
        # h-refinement: create children.
        # If find_optimal_cut_sparse already evaluated a candidate cut near the
        # chosen cut_position, reuse those trial children (with cached samples,
        # f_values, polynomial, and l2_error) instead of repeating the work.
        actual_cut_pos = result.cut_position
        if result.trial_children !== nothing &&
           result.trial_cut_pos !== nothing &&
           abs(result.cut_position - result.trial_cut_pos) <= trial_reuse_tol
            # Snap to the trial's cut position so tree geometry matches the
            # children's actual half-widths.
            actual_cut_pos = result.trial_cut_pos
            left, right = result.trial_children
        else
            left, right = subdivide_domain(subdomain, result.split_dim, actual_cut_pos)
        end

        # Set parent IDs
        parent_id = result.subdomain_id
        left.parent_id = parent_id
        right.parent_id = parent_id

        # Add to tree
        push!(tree.subdomains, left)
        push!(tree.subdomains, right)
        left_id = length(tree.subdomains) - 1
        right_id = length(tree.subdomains)

        # Store split info on parent for tree visualization
        parent = tree.subdomains[parent_id]
        parent.children = (left_id, right_id)
        parent.split_dim = result.split_dim
        parent.split_pos = actual_cut_pos

        # Update active leaves: remove parent, add children
        filter!(id -> id != parent_id, tree.active_leaves)
        push!(tree.active_leaves, left_id)
        push!(tree.active_leaves, right_id)
    elseif result.action == ActionDegreeBump
        # p-refinement: increase degree, stay active for re-processing
        subdomain.degree = result.new_degree
        # jl9z.7: install the bumped anisotropic vector (if any) so the re-fit
        # uses the per-dim spec; nothing leaves the leaf isotropic.
        subdomain.per_dim_degree = result.new_per_dim_degree
        subdomain.polynomial = nothing
        subdomain.samples = nothing
        subdomain.f_values = nothing
        subdomain.l2_error = Inf  # will be recomputed at new degree
    # Leave in active_leaves — will be re-processed next iteration
    elseif result.action == ActionPruned
        # Phase 1 prune: terminal state for all-Inf subdomains.
        filter!(id -> id != result.subdomain_id, tree.active_leaves)
        push!(tree.pruned_leaves, result.subdomain_id)
    else  # ActionConverged
        # Mark as converged
        filter!(id -> id != result.subdomain_id, tree.active_leaves)
        push!(tree.converged_leaves, result.subdomain_id)
    end
end

"""
    adaptive_refine(f, bounds::Vector{Tuple{Float64, Float64}},
                    degree; kwargs...)

Main adaptive refinement loop with parallel processing.

# Arguments
- `f`: Callable to approximate (any callable works, including `TolerantObjective`)
- `bounds`: Domain bounds as vector of (min, max) tuples
- `degree`: Polynomial degree (or degree specification)

# Keyword Arguments
- `l2_tolerance::Float64=1e-6`: Target L2 error tolerance
- `max_depth::Int=10`: Maximum subdivision depth
- `max_leaves::Int=1000`: Maximum number of leaf subdomains
- `optimize_cuts::Bool=true`: Whether to optimize cut positions
- `parallel::Bool=true`: Whether to use CPU parallel processing
- `basis::Symbol=:chebyshev`: Basis type
- `verbose::Bool=false`: Print progress information
- `phase_callback::Union{Function,Nothing}=nothing`: Called with `(f, :refine, 0)` at start.
    Use with `TolerantObjective` to set solver tolerances per phase.
- `enable_p_refinement::Bool=false`: Enable hp-refinement (try higher degree before splitting)
- `max_degree::Int=40`: Maximum polynomial degree for p-refinement
- `degree_step::Int=6`: Degree increment per p-refinement step
- `cond_threshold::Float64=1e14`: Maximum Vandermonde condition number for p-refinement

# Returns
- SubdivisionTree with refined subdomains

# Example
```julia
using Globtim

f(x) = sum(x.^2)
bounds = [(-1.0, 1.0), (-1.0, 1.0)]

# Default: relative L2 tolerance (0.03 = reliable CP recovery threshold)
tree = adaptive_refine(f, bounds, 4)

# Explicit relative tolerance
tree = adaptive_refine(f, bounds, 4; l2_tolerance=0.01, tolerance_mode=:relative)

# Absolute tolerance (backward compatible)
tree = adaptive_refine(f, bounds, 4; l2_tolerance=1e-4, tolerance_mode=:absolute)

# hp-adaptive: start at degree 10, bump up to 40 before splitting
tree = adaptive_refine(f, bounds, 10; l2_tolerance=1e-4, tolerance_mode=:absolute,
                       enable_p_refinement=true, max_degree=40, degree_step=6)
```
"""
function adaptive_refine(
    f,
    bounds::Vector{Tuple{Float64,Float64}},
    degree;
    l2_tolerance::Float64 = NaN,
    tolerance_mode::Symbol = :relative,
    max_depth::Int = 10,
    max_leaves::Int = 1000,
    stagnation_stop::Bool = false,
    stagnation_threshold::Float64 = 0.01,
    optimize_cuts::Bool = true,
    parallel::Bool = true,
    basis::Symbol = :chebyshev,
    verbose::Bool = false,
    iteration_callback::Union{Function,Nothing} = nothing,
    eval_progress::Union{Function,Nothing} = nothing,
    phase_callback::Union{Function,Nothing} = nothing,
    enable_p_refinement::Bool = false,
    max_degree::Int = 40,
    degree_step::Int = 6,
    cond_threshold::Float64 = 1e14,
    thread_evals::Bool = false,
    reuse_parent_samples::Bool = true,
    n_samples_per_dim::Int = 0,
    predicate::Function = default_bump,
    barrier_detector::Union{Nothing,Function} = nothing,
    degeneracy_opts::Union{Nothing,NamedTuple} = nothing,
    logger::Union{Metrics.MetricsLogger,Nothing} = nothing,
    leaf_extra_fn::Union{Function,Nothing} = nothing,
    sampling::Symbol = :tensor,
    christoffel_oversampling::Float64 = 2.0,
    rng_base_seed::Union{Nothing,Integer} = nothing,
)
    tolerance_mode in (:absolute, :relative) ||
        error("Unknown tolerance_mode: $tolerance_mode. Use :absolute or :relative.")

    # Resolve default tolerance based on mode
    if isnan(l2_tolerance)
        l2_tolerance = tolerance_mode == :relative ? 0.03 : 1e-6
    end

    # Initialize tree with root degree
    n_dim = length(bounds)
    root_degree = maximum(_extract_per_dim_degrees(degree, n_dim))
    tree = SubdivisionTree(
        bounds;
        degree = root_degree,
        per_dim_degree = _root_per_dim_degree(degree),  # jl9z.7: seed anisotropic root
    )

    if logger !== nothing
        Metrics.log_phase!(
            logger,
            "adaptive_refine_start";
            extra = Dict(
                :n_dim => n_dim,
                :base_degree => root_degree,
                :l2_tolerance => l2_tolerance,
                :tolerance_mode => string(tolerance_mode),
                :max_depth => max_depth,
                :max_leaves => max_leaves,
                :enable_p_refinement => enable_p_refinement,
                :max_degree => max_degree,
                :degree_step => degree_step,
                :predicate_name => string(nameof(predicate)),
                :parallel => parallel,
                :basis => string(basis),
            ),
        )
    end
    t_build_start = time()

    # Notify phase callback that we're starting (single-phase refinement)
    if phase_callback !== nothing
        phase_callback(f, :refine, 0)
    end

    iteration = 0
    total_error_history = Float64[]  # tree total L2 per iteration, for optional stagnation stop
    while !isempty(tree.active_leaves)
        iteration += 1

        # Check stopping conditions
        if max_depth > 0 && get_max_depth(tree) >= max_depth
            verbose && println("Reached max depth: $max_depth")
            break
        end

        if n_leaves(tree) >= max_leaves
            verbose && println("Reached max leaves: $max_leaves")
            break
        end

        # Optional early stop (opt-in; default off ⇒ behavior unchanged): halt
        # subdivision once the tree's TOTAL L2 error stops dropping across iterations.
        # Tree-level (not per-leaf): a split leaf's own error sequence terminates when
        # it spawns children, so the meaningful plateau signal is the aggregate. Reuses
        # EnhancedMetrics.detect_stagnation. Threshold is independent of the degree-sweep
        # gate (different scale: per-split-iteration vs per-degree improvements).
        if stagnation_stop &&
           length(total_error_history) >= 3 &&
           EnhancedMetrics.detect_stagnation(total_error_history, stagnation_threshold)
            verbose && println(
                "Stopping subdivision: total L2 error stagnated at iteration $iteration",
            )
            break
        end

        if verbose
            max_abs_pre, max_rel_pre = leaf_error_summary(tree, tree.active_leaves)
            Printf.@printf(
                "Iteration %d: %d active leaves, %d total leaves (max ‖f-p‖_L2=%.3e, max rel=%.3e)\n",
                iteration,
                n_active(tree),
                n_leaves(tree),
                max_abs_pre,
                max_rel_pre,
            )
        end

        # Process all active leaves
        current_active = copy(tree.active_leaves)

        hp_kwargs = (;
            enable_p_refinement,
            max_degree,
            degree_step,
            cond_threshold,
            tolerance_mode,
            thread_evals,
            reuse_parent_samples,
            n_samples_per_dim,
            predicate,
            barrier_detector,
            degeneracy_opts,
            sampling,
            christoffel_oversampling,
            rng_base_seed,
        )

        if parallel && length(current_active) > 1 && Threads.nthreads() > 1
            # CPU parallel processing
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    l2_tolerance;
                    optimize_cuts = optimize_cuts,
                    basis = basis,
                    eval_progress = eval_progress,
                    hp_kwargs...,
                )
            end
            results = fetch.(tasks)
        else
            # Sequential processing
            results = [
                process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    l2_tolerance;
                    optimize_cuts = optimize_cuts,
                    basis = basis,
                    eval_progress = eval_progress,
                    hp_kwargs...,
                ) for leaf_id in current_active
            ]
        end

        # Update tree sequentially (not thread-safe)
        for (leaf_id, result) in zip(current_active, results)
            update_tree!(tree, result, tree.subdomains[leaf_id])
        end

        # Record the post-iteration tree total L2 for the optional stagnation stop
        # (checked at the top of the next iteration).
        stagnation_stop && push!(total_error_history, total_error(tree))

        # Call iteration callback if provided
        if iteration_callback !== nothing
            iteration_callback(tree, iteration)
        end
    end

    # Compute L2 errors for any unprocessed leaves (e.g., when max_depth reached)
    # These leaves were created by splits but never processed before loop termination
    for leaf_id in copy(tree.active_leaves)  # copy: we modify during iteration
        sd = tree.subdomains[leaf_id]
        if sd.l2_error == Inf
            # Record the degree used (same logic as process_subdomain). jl9z.7:
            # honor an inherited anisotropic per-dim spec; otherwise fall back to
            # the caller's `degree` (byte-identical to the old root_degree path).
            leaf_spec =
                sd.per_dim_degree !== nothing ?
                (:one_d_per_dim, sd.per_dim_degree) : degree
            sd.degree = maximum(_extract_per_dim_degrees(leaf_spec, length(sd.center)))
            estimate_subdomain_error(
                f,
                sd,
                leaf_spec,
                basis = basis,
                eval_progress = eval_progress,
                thread_evals = thread_evals,
                n_samples_per_dim = n_samples_per_dim,
            )
        end
        # Phase 1 prune fires here too — re-eval may discover infeasibility on
        # leaves that were never processed during the main loop.
        if sd.infeasible
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.pruned_leaves, leaf_id)
            continue
        end
        # yhta: barrier masking also applies to leaves that survived to finalize
        # (stopped by the depth/leaf cap while still active) so they aren't
        # solved for spurious critical points or counted in total_error.
        if barrier_detector !== nothing &&
           sd.f_values !== nothing &&
           barrier_detector(sd.f_values)
            sd.masked = true
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.pruned_leaves, leaf_id)
            continue
        end
        # Check if leaf now meets tolerance → mark as converged
        check_error = tolerance_mode == :relative ? sd.relative_l2_error : sd.l2_error
        if check_error <= l2_tolerance
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.converged_leaves, leaf_id)
        end
    end

    if verbose
        all_leaves = vcat(tree.active_leaves, tree.converged_leaves, tree.pruned_leaves)
        max_abs_final, max_rel_final = leaf_error_summary(tree, all_leaves)
        Printf.@printf(
            "Final: %d leaves (%d converged, %d active, %d pruned [%d barrier-masked]) | max ‖f-p‖_L2=%.3e, max rel=%.3e | tolerance_mode=%s, l2_tolerance=%.3e\n",
            n_leaves(tree),
            length(tree.converged_leaves),
            length(tree.active_leaves),
            length(tree.pruned_leaves),
            n_masked(tree),
            max_abs_final,
            max_rel_final,
            tolerance_mode,
            l2_tolerance,
        )
    end

    if logger !== nothing
        _emit_tree_leaves!(logger, tree, leaf_extra_fn)
        Metrics.log_phase!(
            logger,
            "adaptive_refine_done";
            extra = Dict(
                :wall_s => time() - t_build_start,
                :n_leaves => n_leaves(tree),
                :n_active => length(tree.active_leaves),
                :n_converged => length(tree.converged_leaves),
                :n_pruned => length(tree.pruned_leaves),
                :n_masked => n_masked(tree),
                :max_depth_reached => get_max_depth(tree),
            ),
        )
    end

    return tree
end #==============================================================================#

# Emit one leaf row per processed leaf to the supplied Metrics logger.
# Skipped for leaves that were pruned-pre-fit (`polynomial === nothing`) since
# they have no rel_l2 to report. `leaf_extra_fn(sd, leaf_id)` may return a Dict
# whose entries are folded into the row's `extra` field — this is the
# escape hatch for caller-side per-leaf data (HC-side stats, predicate-call
# counters, etc.) that the library itself doesn't track.
function _emit_tree_leaves!(
    logger::Metrics.MetricsLogger,
    tree::SubdivisionTree,
    leaf_extra_fn::Union{Function,Nothing},
)
    active_set = Set(tree.active_leaves)
    converged_set = Set(tree.converged_leaves)
    pruned_set = Set(tree.pruned_leaves)
    for (idx, sd) in enumerate(tree.subdomains)
        sd.polynomial === nothing && continue
        status =
            idx in active_set ? "active" :
            idx in converged_set ? "converged" :
            idx in pruned_set ? (sd.masked ? "masked" : "pruned") : "internal"
        extra = Dict{Symbol,Any}(
            :stage => "tree-build",
            :status => status,
            :split_dim => sd.split_dim === nothing ? nothing : Int(sd.split_dim),
            :parent_id => sd.parent_id === nothing ? nothing : Int(sd.parent_id),
            :l2_error => sd.l2_error,
        )
        if leaf_extra_fn !== nothing
            user_extra = leaf_extra_fn(sd, idx)
            for (k, v) in user_extra
                extra[Symbol(k)] = v
            end
        end
        Metrics.log_leaf!(
            logger,
            idx;
            depth = sd.depth,
            bounds = get_bounds(sd),
            degree = sd.degree,
            rel_l2 = sd.relative_l2_error,
            n_raw_cps = 0,
            extra = extra,
        )
    end
end

#                      TWO-PHASE REFINEMENT                                     #

"""
    two_phase_refine(f, bounds::Vector{Tuple{Float64, Float64}},
                     degree; kwargs...)

Two-phase adaptive refinement: coarse balancing pass, then accuracy refinement.

Phase 1 subdivides until errors are relatively balanced (no stragglers).
Phase 2 refines to meet the final tolerance.

# Arguments
- `f`: Callable to approximate (any callable works, including `TolerantObjective`)
- `bounds`: Domain bounds
- `degree`: Polynomial degree

# Keyword Arguments
- `coarse_tolerance::Float64`: Phase 1 tolerance (should be looser than fine)
- `fine_tolerance::Float64`: Phase 2 final tolerance
- `balance_threshold::Float64=3.0`: Phase 1 stops when max/min error ratio < this
- `max_depth::Int=10`: Maximum subdivision depth
- `max_leaves::Int=1000`: Maximum leaves
- `parallel::Bool=true`: Use CPU parallel processing
- `basis::Symbol=:chebyshev`: Basis type
- `verbose::Bool=false`: Print progress
- `phase_callback::Union{Function,Nothing}=nothing`: Called with `(f, :coarse, 0)` at
    Phase 1 start and `(f, :fine, 0)` at Phase 2 start. Use with `TolerantObjective` to
    switch solver tolerances between phases.
- `enable_p_refinement::Bool=false`: Enable hp-refinement (try higher degree before splitting)
- `max_degree::Int=40`: Maximum polynomial degree for p-refinement
- `degree_step::Int=6`: Degree increment per p-refinement step
- `cond_threshold::Float64=1e14`: Maximum Vandermonde condition number for p-refinement
- `logger::Union{Metrics.MetricsLogger,Nothing}=nothing`: When non-`nothing`, emit
    JSONL phase rows (`two_phase_refine_start`, `two_phase_phase1_done`,
    `two_phase_phase2_start`, `two_phase_refine_done`) plus one `leaf` row per
    processed leaf with `stage="tree-build"`. Mirror of `adaptive_refine`'s
    logger kwarg.
- `leaf_extra_fn::Union{Function,Nothing}=nothing`: Optional `(sd, leaf_id) -> Dict`
    that supplies per-leaf data the library can't know (HC-side stats, predicate
    counters); the returned entries are folded into each leaf row's `extra`.

# Returns
- SubdivisionTree with refined subdomains
"""
function two_phase_refine(
    f,
    bounds::Vector{Tuple{Float64,Float64}},
    degree;
    coarse_tolerance::Float64 = NaN,
    fine_tolerance::Float64 = NaN,
    tolerance_mode::Symbol = :relative,
    balance_threshold::Float64 = 3.0,
    max_depth::Int = 10,
    max_leaves::Int = 1000,
    parallel::Bool = true,
    basis::Symbol = :chebyshev,
    verbose::Bool = false,
    iteration_callback::Union{Function,Nothing} = nothing,
    phase_callback::Union{Function,Nothing} = nothing,
    enable_p_refinement::Bool = false,
    max_degree::Int = 40,
    degree_step::Int = 6,
    cond_threshold::Float64 = 1e14,
    thread_evals::Bool = false,
    reuse_parent_samples::Bool = true,
    predicate::Function = default_bump,
    barrier_detector::Union{Nothing,Function} = nothing,
    degeneracy_opts::Union{Nothing,NamedTuple} = nothing,
    logger::Union{Metrics.MetricsLogger,Nothing} = nothing,
    leaf_extra_fn::Union{Function,Nothing} = nothing,
)
    tolerance_mode in (:absolute, :relative) ||
        error("Unknown tolerance_mode: $tolerance_mode. Use :absolute or :relative.")

    # Resolve default tolerances based on mode
    if isnan(coarse_tolerance)
        coarse_tolerance = tolerance_mode == :relative ? 0.05 : 1e-4
    end
    if isnan(fine_tolerance)
        fine_tolerance = tolerance_mode == :relative ? 0.03 : 1e-6
    end

    t_build_start = time()
    if logger !== nothing
        n_dim_log = length(bounds)
        root_degree_log = maximum(_extract_per_dim_degrees(degree, n_dim_log))
        Metrics.log_phase!(
            logger,
            "two_phase_refine_start";
            extra = Dict(
                :n_dim => n_dim_log,
                :base_degree => root_degree_log,
                :coarse_tolerance => coarse_tolerance,
                :fine_tolerance => fine_tolerance,
                :balance_threshold => balance_threshold,
                :tolerance_mode => string(tolerance_mode),
                :max_depth => max_depth,
                :max_leaves => max_leaves,
                :enable_p_refinement => enable_p_refinement,
                :max_degree => max_degree,
                :degree_step => degree_step,
                :predicate_name => string(nameof(predicate)),
                :parallel => parallel,
                :basis => string(basis),
            ),
        )
    end

    verbose && println("=== Phase 1: Coarse balancing ===")

    # Notify phase callback for Phase 1 (coarse balancing)
    # This allows TolerantObjective to switch to coarse solver tolerances
    if phase_callback !== nothing
        phase_callback(f, :coarse, 0)
    end

    # Phase 1: Coarse balancing pass
    n_dim = length(bounds)
    root_degree = maximum(_extract_per_dim_degrees(degree, n_dim))
    tree = SubdivisionTree(
        bounds;
        degree = root_degree,
        per_dim_degree = _root_per_dim_degree(degree),  # jl9z.7: seed anisotropic root
    )

    hp_kwargs = (;
        enable_p_refinement,
        max_degree,
        degree_step,
        cond_threshold,
        tolerance_mode,
        thread_evals,
        reuse_parent_samples,
        predicate,
        barrier_detector,
        degeneracy_opts,
    )

    phase1_iter = 0
    while !isempty(tree.active_leaves) && phase1_iter < 100
        phase1_iter += 1

        # Process all active leaves
        current_active = copy(tree.active_leaves)

        if parallel && length(current_active) > 1 && Threads.nthreads() > 1
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    coarse_tolerance;
                    optimize_cuts = true,
                    basis = basis,
                    hp_kwargs...,
                )
            end
            results = fetch.(tasks)
        else
            results = [
                process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    coarse_tolerance;
                    optimize_cuts = true,
                    basis = basis,
                    hp_kwargs...,
                ) for leaf_id in current_active
            ]
        end

        # Update tree
        for (leaf_id, result) in zip(current_active, results)
            update_tree!(tree, result, tree.subdomains[leaf_id])
        end

        # Call iteration callback (phase 1)
        if iteration_callback !== nothing
            iteration_callback(tree, phase1_iter)
        end

        # Check balance criterion
        if !isempty(tree.active_leaves)
            ratio = error_balance_ratio(tree)
            if verbose
                max_abs_p1, max_rel_p1 = leaf_error_summary(tree, tree.active_leaves)
                Printf.@printf(
                    "Phase 1 iteration %d: ratio=%.3g, max ‖f-p‖_L2=%.3e, max rel=%.3e\n",
                    phase1_iter,
                    ratio,
                    max_abs_p1,
                    max_rel_p1,
                )
            end

            if ratio <= balance_threshold
                verbose && println("Balanced! Ratio $ratio <= threshold $balance_threshold")
                break
            end
        end

        # Check limits
        if get_max_depth(tree) >= max_depth || n_leaves(tree) >= max_leaves
            break
        end
    end

    verbose && println("Phase 1 complete: $(n_leaves(tree)) leaves")
    if logger !== nothing
        ratio_p1 = isempty(tree.active_leaves) ? NaN : error_balance_ratio(tree)
        Metrics.log_phase!(
            logger,
            "two_phase_phase1_done";
            extra = Dict(
                :phase1_iter => phase1_iter,
                :n_leaves => n_leaves(tree),
                :n_active => length(tree.active_leaves),
                :n_converged => length(tree.converged_leaves),
                :n_pruned => length(tree.pruned_leaves),
                :max_depth_reached => get_max_depth(tree),
                :balance_ratio => ratio_p1,
            ),
        )
    end
    verbose && println("\n=== Phase 2: Accuracy refinement ===")

    # Notify phase callback for Phase 2 (fine accuracy)
    # This allows TolerantObjective to switch to tight solver tolerances
    if phase_callback !== nothing
        phase_callback(f, :fine, 0)
    end

    # Phase 2: Accuracy refinement
    # Only re-activate leaves whose error exceeds fine_tolerance;
    # leaves already below fine_tolerance from Phase 1 stay converged.
    _leaf_error(id) =
        tolerance_mode == :relative ? tree.subdomains[id].relative_l2_error :
        tree.subdomains[id].l2_error
    needs_reeval = filter(id -> _leaf_error(id) > fine_tolerance, tree.converged_leaves)
    already_fine = filter(id -> _leaf_error(id) <= fine_tolerance, tree.converged_leaves)
    append!(tree.active_leaves, needs_reeval)
    tree.converged_leaves = already_fine

    if logger !== nothing
        Metrics.log_phase!(
            logger,
            "two_phase_phase2_start";
            extra = Dict(
                :n_needs_reeval => length(needs_reeval),
                :n_already_fine => length(already_fine),
            ),
        )
    end

    verbose &&
        length(already_fine) > 0 &&
        println("  Skipping $(length(already_fine)) leaves already below fine_tolerance")

    phase2_iter = 0
    while !isempty(tree.active_leaves) && phase2_iter < 100
        phase2_iter += 1

        current_active = copy(tree.active_leaves)

        if parallel && length(current_active) > 1 && Threads.nthreads() > 1
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    fine_tolerance;
                    optimize_cuts = true,
                    basis = basis,
                    hp_kwargs...,
                )
            end
            results = fetch.(tasks)
        else
            results = [
                process_subdomain(
                    f,
                    tree,
                    leaf_id,
                    degree,
                    fine_tolerance;
                    optimize_cuts = true,
                    basis = basis,
                    hp_kwargs...,
                ) for leaf_id in current_active
            ]
        end

        for (leaf_id, result) in zip(current_active, results)
            update_tree!(tree, result, tree.subdomains[leaf_id])
        end

        # Call iteration callback (phase 2)
        if iteration_callback !== nothing
            iteration_callback(tree, phase2_iter)
        end

        if verbose
            max_abs_p2, max_rel_p2 = leaf_error_summary(tree, tree.active_leaves)
            Printf.@printf(
                "Phase 2 iteration %d: %d active, %d converged | max ‖f-p‖_L2=%.3e, max rel=%.3e\n",
                phase2_iter,
                length(tree.active_leaves),
                length(tree.converged_leaves),
                max_abs_p2,
                max_rel_p2,
            )
        end

        if get_max_depth(tree) >= max_depth || n_leaves(tree) >= max_leaves
            break
        end
    end

    # Compute L2 errors for any unprocessed leaves (e.g., when max_depth reached)
    for leaf_id in copy(tree.active_leaves)  # copy: we modify during iteration
        sd = tree.subdomains[leaf_id]
        if sd.l2_error == Inf
            # jl9z.7: honor an inherited anisotropic per-dim spec (parity with
            # adaptive_refine's finalize); else fall back to the caller's `degree`.
            leaf_spec =
                sd.per_dim_degree !== nothing ?
                (:one_d_per_dim, sd.per_dim_degree) : degree
            sd.degree = maximum(_extract_per_dim_degrees(leaf_spec, length(sd.center)))
            estimate_subdomain_error(
                f,
                sd,
                leaf_spec,
                basis = basis,
                thread_evals = thread_evals,
                n_samples_per_dim = n_samples_per_dim,
            )
        end
        if sd.infeasible
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.pruned_leaves, leaf_id)
            continue
        end
        # yhta: barrier masking for leaves still active at the cap (parity with adaptive_refine).
        if barrier_detector !== nothing &&
           sd.f_values !== nothing &&
           barrier_detector(sd.f_values)
            sd.masked = true
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.pruned_leaves, leaf_id)
        end
    end

    if verbose
        all_leaves = vcat(tree.active_leaves, tree.converged_leaves, tree.pruned_leaves)
        max_abs_final, max_rel_final = leaf_error_summary(tree, all_leaves)
        Printf.@printf(
            "\nFinal: %d leaves (%d converged, %d active, %d pruned [%d barrier-masked]) | max ‖f-p‖_L2=%.3e, max rel=%.3e | tolerance_mode=%s, fine_tolerance=%.3e\n",
            n_leaves(tree),
            length(tree.converged_leaves),
            length(tree.active_leaves),
            length(tree.pruned_leaves),
            n_masked(tree),
            max_abs_final,
            max_rel_final,
            tolerance_mode,
            fine_tolerance,
        )
    end

    if logger !== nothing
        _emit_tree_leaves!(logger, tree, leaf_extra_fn)
        Metrics.log_phase!(
            logger,
            "two_phase_refine_done";
            extra = Dict(
                :wall_s => time() - t_build_start,
                :n_leaves => n_leaves(tree),
                :n_active => length(tree.active_leaves),
                :n_converged => length(tree.converged_leaves),
                :n_pruned => length(tree.pruned_leaves),
                :n_masked => n_masked(tree),
                :max_depth_reached => get_max_depth(tree),
            ),
        )
    end

    return tree
end
