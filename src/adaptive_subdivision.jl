# adaptive_subdivision.jl
# Adaptive domain subdivision for error-driven polynomial approximation
#
# Key design principles:
# 1. Minimize function evaluations (expensive: ~10ms per ODE solve for trajectory problems)
# 2. Reuse existing Chebyshev samples where possible
# 3. Statistical dimension selection from residuals (no new evaluations)
# 4. Parallel processing of independent subdomains

using LinearAlgebra
using Statistics
using Base.Threads
using Printf

#==============================================================================#
#                           DATA STRUCTURES                                     #
#==============================================================================#

"""
    Subdomain

Represents a subdomain in the adaptive refinement tree.

# Fields
- `center::Vector{Float64}`: Center point in original coordinates
- `half_widths::Vector{Float64}`: Half-width in each dimension (anisotropic support)
- `l2_error::Float64`: Estimated L2 approximation error on this subdomain
- `depth::Int`: Depth in subdivision tree (root = 0)
- `parent_id::Union{Int, Nothing}`: Index of parent subdomain (nothing for root)
- `polynomial::Union{ApproxPoly, Nothing}`: Polynomial approximation (if computed)
- `samples::Union{Matrix{Float64}, Nothing}`: Cached sample points (for reuse)
- `f_values::Union{Vector{Float64}, Nothing}`: Cached function values at samples
- `children::Union{Tuple{Int,Int}, Nothing}`: Child subdomain IDs (left, right) if split
- `split_dim::Union{Int, Nothing}`: Dimension along which this subdomain was split
- `split_pos::Union{Float64, Nothing}`: Cut position in [-1,1] normalized coordinates
"""
mutable struct Subdomain
    center::Vector{Float64}
    half_widths::Vector{Float64}
    l2_error::Float64
    depth::Int
    parent_id::Union{Int, Nothing}
    polynomial::Union{ApproxPoly, Nothing}
    samples::Union{Matrix{Float64}, Nothing}
    f_values::Union{Vector{Float64}, Nothing}
    # Split tracking for tree visualization
    children::Union{Tuple{Int,Int}, Nothing}
    split_dim::Union{Int, Nothing}
    split_pos::Union{Float64, Nothing}
end

# Constructor for new subdomain (no polynomial yet)
function Subdomain(center::Vector{Float64}, half_widths::Vector{Float64};
                   depth::Int=0, parent_id::Union{Int, Nothing}=nothing)
    return Subdomain(center, half_widths, Inf, depth, parent_id, nothing, nothing, nothing,
                     nothing, nothing, nothing)  # children, split_dim, split_pos
end

# Constructor from bounds
function Subdomain(bounds::Vector{Tuple{Float64, Float64}};
                   depth::Int=0, parent_id::Union{Int, Nothing}=nothing)
    center = [(b[1] + b[2]) / 2 for b in bounds]
    half_widths = [(b[2] - b[1]) / 2 for b in bounds]
    return Subdomain(center, half_widths, depth=depth, parent_id=parent_id)
end

"""
    get_bounds(subdomain::Subdomain)

Return bounds as vector of (min, max) tuples.
"""
function get_bounds(subdomain::Subdomain)
    return [(subdomain.center[d] - subdomain.half_widths[d],
             subdomain.center[d] + subdomain.half_widths[d])
            for d in 1:length(subdomain.center)]
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
- `root_id::Int`: Index of root subdomain
"""
mutable struct SubdivisionTree
    subdomains::Vector{Subdomain}
    active_leaves::Vector{Int}
    converged_leaves::Vector{Int}
    root_id::Int
end

# Constructor from initial domain
function SubdivisionTree(initial_domain::Subdomain)
    return SubdivisionTree([initial_domain], [1], Int[], 1)
end

# Constructor from bounds
function SubdivisionTree(bounds::Vector{Tuple{Float64, Float64}})
    root = Subdomain(bounds)
    return SubdivisionTree(root)
end

"""
    n_leaves(tree::SubdivisionTree)

Return total number of leaf subdomains.
"""
n_leaves(tree::SubdivisionTree) = length(tree.active_leaves) + length(tree.converged_leaves)

"""
    n_active(tree::SubdivisionTree)

Return number of subdomains still needing refinement.
"""
n_active(tree::SubdivisionTree) = length(tree.active_leaves)

"""
    get_max_depth(tree::SubdivisionTree)

Return maximum depth of any subdomain in tree.
"""
function get_max_depth(tree::SubdivisionTree)
    return maximum(sd.depth for sd in tree.subdomains)
end

"""
    total_error(tree::SubdivisionTree)

Return sum of L2 errors across all leaves.
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
tree = adaptive_refine(f, bounds, 4, l2_tolerance=0.1)
display_tree(tree, max_leaves=10)
```
"""
function display_tree(tree::SubdivisionTree; max_leaves::Int=20, sort_by::Symbol=:error)
    all_leaves = vcat(tree.converged_leaves, tree.active_leaves)
    isempty(all_leaves) && return println("Empty tree")

    n_dim = length(tree.subdomains[1].center)

    # Sort leaves
    sorted_leaves = copy(all_leaves)
    if sort_by == :error
        sort!(sorted_leaves, by=id -> -tree.subdomains[id].l2_error)
    elseif sort_by == :depth
        sort!(sorted_leaves, by=id -> -tree.subdomains[id].depth)
    end

    # Header
    println("SubdivisionTree: $(n_leaves(tree)) leaves, depth=$(get_max_depth(tree)), dim=$n_dim")
    println("Total L2 error: $(round(total_error(tree), sigdigits=4))")
    println("Converged: $(length(tree.converged_leaves)), Active: $(length(tree.active_leaves))")
    println()

    # Table
    Printf.@printf("%-4s  %-5s  %-10s  %-8s  %s\n", "ID", "Depth", "L2 Error", "Status", "Bounds")
    println("-"^70)

    for id in sorted_leaves[1:min(max_leaves, length(sorted_leaves))]
        sd = tree.subdomains[id]
        bounds = get_bounds(sd)
        bounds_str = join([Printf.@sprintf("[%.2f,%.2f]", b[1], b[2]) for b in bounds], "×")
        status = id in tree.converged_leaves ? "conv" : "active"
        Printf.@printf("%-4d  %-5d  %-10.2e  %-8s  %s\n", id, sd.depth, sd.l2_error, status, bounds_str)
    end

    length(sorted_leaves) > max_leaves && println("... $(length(sorted_leaves) - max_leaves) more")
    nothing
end

#==============================================================================#
#                       SUBDOMAIN OPERATIONS                                    #
#==============================================================================#

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

    child_left = Subdomain(left_center, left_half_widths,
                           depth=subdomain.depth + 1, parent_id=nothing)  # Set parent later
    child_right = Subdomain(right_center, right_half_widths,
                            depth=subdomain.depth + 1, parent_id=nothing)

    return (child_left, child_right)
end

"""
    subdivide_midpoint(subdomain::Subdomain, dim::Int)

Convenience function to subdivide at the midpoint of dimension `dim`.
"""
subdivide_midpoint(subdomain::Subdomain, dim::Int) = subdivide_domain(subdomain, dim, 0.0)

#==============================================================================#
#                     STATISTICAL DIMENSION SELECTION                           #
#==============================================================================#

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
            groups = Dict{Vector{Float64}, Vector{Int}}()
            for i in 1:size(samples, 1)
                key = round.(samples[i, other_dims], digits=10)
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
    V = lambda_vandermonde(Lambda, samples, basis=pol.basis)

    # Evaluate: V * coeffs
    return V * pol.coeffs
end

#==============================================================================#
#                      ERROR ESTIMATION                                         #
#==============================================================================#

"""
    estimate_subdomain_error(f, subdomain::Subdomain, degree;
                             n_samples_per_dim::Int=0, basis::Symbol=:chebyshev)

Estimate L2 approximation error on a subdomain.

Uses sparse Chebyshev sampling (~2× number of coefficients) for efficiency.

# Arguments
- `f`: Function to approximate
- `subdomain`: Subdomain to evaluate
- `degree`: Polynomial degree (or degree specification)
- `n_samples_per_dim`: Grid points per dimension (0 = auto: 2×degree+1)
- `basis`: Basis type (:chebyshev or :legendre)

# Returns
- Estimated L2 error

# Side Effects
Updates subdomain.l2_error, subdomain.polynomial, subdomain.samples, subdomain.f_values
"""
function estimate_subdomain_error(f, subdomain::Subdomain, degree;
                                   n_samples_per_dim::Int=0, basis::Symbol=:chebyshev,
                                   eval_progress::Union{Function,Nothing}=nothing)
    n_dim = dimension(subdomain)

    # Determine grid size: default is ~2× degree for sparse but sufficient LS fit
    if n_samples_per_dim == 0
        d = degree isa Tuple ? degree[2] : degree
        n_samples_per_dim = 2 * d + 1
    end

    # Generate normalized grid in [-1, 1]^n
    grid = generate_grid(n_dim, n_samples_per_dim - 1, basis=basis)

    # Convert to matrix format
    # grid_to_matrix returns (n_samples × n_dim), but we need (n_dim × n_samples) for Vandermonde
    # We'll keep samples as (n_samples × n_dim) for iteration, transpose for Vandermonde
    grid_matrix = grid_to_matrix(grid)  # (n_samples, n_dim)

    # Evaluate function at physical coordinates
    # Pre-allocate arrays to avoid per-iteration allocations (critical for 625+ evals in 4D)
    n_total = size(grid_matrix, 1)
    n_dim = dimension(subdomain)
    f_values = Vector{Float64}(undef, n_total)
    x_physical = Vector{Float64}(undef, n_dim)  # Reusable buffer

    for i in 1:n_total
        eval_progress !== nothing && eval_progress(i, n_total)
        @inbounds for d in 1:n_dim
            x_physical[d] = subdomain.center[d] + grid_matrix[i, d] * subdomain.half_widths[d]
        end
        f_values[i] = f(x_physical)
    end

    # Check for Inf values (failed ODE evaluations or other failures)
    if any(isinf, f_values)
        # Mark subdomain as failed - use Inf as sentinel (not NaN)
        subdomain.l2_error = Inf
        subdomain.polynomial = nothing  # Triggers fallback to width-based dimension selection
        subdomain.samples = grid_matrix
        subdomain.f_values = f_values
        return Inf
    end

    # Construct polynomial approximation
    pol = construct_polynomial_on_subdomain(f, subdomain, degree, grid_matrix, f_values, basis)

    # Compute L2 error
    poly_values = evaluate_polynomial_at_samples(pol, grid_matrix)
    errors = f_values .- poly_values
    weight = (2.0 / n_samples_per_dim)^n_dim
    l2_error = sqrt(sum(abs2.(errors)) * weight)

    # Defensive: catch any remaining NaN from numerical issues
    if isnan(l2_error)
        l2_error = Inf
        pol = nothing
    end

    # Cache everything for reuse
    subdomain.l2_error = l2_error
    subdomain.polynomial = pol
    subdomain.samples = grid_matrix
    subdomain.f_values = f_values

    return l2_error
end

"""
    construct_polynomial_on_subdomain(f, subdomain, degree, samples, f_values, basis)

Construct polynomial approximation on a subdomain using least squares.

This wraps the existing Globtim infrastructure (MainGenerate pattern).
"""
function construct_polynomial_on_subdomain(::Function, subdomain::Subdomain,
                                           degree, samples::Matrix{Float64},
                                           f_values::Vector{Float64}, basis::Symbol)
    n_dim = dimension(subdomain)

    # Generate support (multi-index set)
    d_spec = degree isa Tuple ? degree : (:one_d_for_all, degree)
    Lambda = SupportGen(n_dim, d_spec)

    # Build Vandermonde matrix
    # samples is (n_samples, n_dim) which is the correct format for lambda_vandermonde
    V = lambda_vandermonde(Lambda, samples, basis=basis)

    # Solve least squares for coefficients
    coeffs = V \ f_values

    # Compute L2 norm of approximation
    poly_values = V * coeffs
    weight = (2.0 / size(samples, 1)^(1/n_dim))^n_dim
    nrm = sqrt(sum(abs2.(poly_values)) * weight)

    # Create ApproxPoly with anisotropic scale_factor
    return ApproxPoly{Float64}(
        coeffs,
        Lambda,
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
        cond(V)
    )
end

#==============================================================================#
#                      OPTIMAL CUT SELECTION                                    #
#==============================================================================#

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
"""
function find_optimal_cut_sparse(f, subdomain::Subdomain, dim::Int, degree;
                                  n_candidates::Int=3, basis::Symbol=:chebyshev)
    # Candidate positions in normalized [-1, 1] coordinates
    # Default: -0.5, 0.0, 0.5 (quarter, half, three-quarters)
    if n_candidates == 3
        candidates = [-0.5, 0.0, 0.5]
    else
        candidates = range(-0.75, 0.75, length=n_candidates)
    end

    # Evaluate combined error for each candidate
    errors = Float64[]
    for cut_pos in candidates
        left, right = subdivide_domain(subdomain, dim, cut_pos)

        # Estimate error on both children
        err_left = estimate_subdomain_error(f, left, degree, basis=basis)
        err_right = estimate_subdomain_error(f, right, degree, basis=basis)

        # Combined error (sum weighted by volume for fair comparison)
        combined = err_left * sqrt(volume(left)) + err_right * sqrt(volume(right))
        push!(errors, combined)
    end

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
            opt_pos = candidates[argmin(errors)]
        end
    else
        # Just use best candidate
        opt_pos = candidates[argmin(errors)]
    end

    return opt_pos
end

"""
    find_optimal_cut_midpoint(subdomain::Subdomain, dim::Int)

Always return midpoint cut (for comparison/testing).
"""
find_optimal_cut_midpoint(subdomain::Subdomain, dim::Int) = 0.0

#==============================================================================#
#                      MAIN ADAPTIVE REFINEMENT                                 #
#==============================================================================#

"""
    ProcessResult

Result of processing a single subdomain.
"""
struct ProcessResult
    subdomain_id::Int
    should_split::Bool
    split_dim::Union{Int, Nothing}
    cut_position::Union{Float64, Nothing}
    l2_error::Float64
end

"""
    process_subdomain(f, tree::SubdivisionTree, subdomain_id::Int,
                      degree, l2_tolerance::Float64;
                      optimize_cuts::Bool=true, basis::Symbol=:chebyshev)

Process a single subdomain: estimate error, decide if split needed, find optimal cut.

# Arguments
- `f`: Function to approximate
- `tree`: Subdivision tree (read-only access to subdomain)
- `subdomain_id`: Index of subdomain to process
- `degree`: Polynomial degree
- `l2_tolerance`: Target L2 error tolerance
- `optimize_cuts`: Whether to optimize cut position (vs midpoint)
- `basis`: Basis type

# Returns
- ProcessResult with decision
"""
function process_subdomain(f, tree::SubdivisionTree, subdomain_id::Int,
                           degree, l2_tolerance::Float64;
                           optimize_cuts::Bool=true, basis::Symbol=:chebyshev,
                           eval_progress::Union{Function,Nothing}=nothing)
    subdomain = tree.subdomains[subdomain_id]

    # Estimate error on this subdomain
    l2_error = estimate_subdomain_error(f, subdomain, degree, basis=basis,
                                         eval_progress=eval_progress)

    if l2_error <= l2_tolerance
        # No split needed
        return ProcessResult(subdomain_id, false, nothing, nothing, l2_error)
    else
        # Split needed - determine where
        if subdomain.polynomial !== nothing && subdomain.samples !== nothing
            split_dim = select_cut_dimension(subdomain)
        else
            split_dim = select_cut_dimension_by_width(subdomain)
        end

        if optimize_cuts
            cut_pos = find_optimal_cut_sparse(f, subdomain, split_dim, degree, basis=basis)
        else
            cut_pos = 0.0  # Midpoint
        end

        return ProcessResult(subdomain_id, true, split_dim, cut_pos, l2_error)
    end
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
function update_tree!(tree::SubdivisionTree, result::ProcessResult, subdomain::Subdomain)
    if result.should_split
        # Create children
        left, right = subdivide_domain(subdomain, result.split_dim, result.cut_position)

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
        parent.split_pos = result.cut_position

        # Update active leaves: remove parent, add children
        filter!(id -> id != parent_id, tree.active_leaves)
        push!(tree.active_leaves, left_id)
        push!(tree.active_leaves, right_id)
    else
        # Mark as converged
        filter!(id -> id != result.subdomain_id, tree.active_leaves)
        push!(tree.converged_leaves, result.subdomain_id)
    end
end

#==============================================================================#
#                      GPU BATCHED PROCESSING                                   #
#==============================================================================#

"""
    BatchGroup

Groups subdomains with identical grid configurations for batched GPU processing.

# Fields
- `subdomain_ids::Vector{Int}`: Indices of subdomains in this group
- `n_points::Int`: Number of grid points per subdomain
- `n_terms::Int`: Number of polynomial terms
- `degree::Int`: Polynomial degree
- `n_dims::Int`: Problem dimension
"""
struct BatchGroup
    subdomain_ids::Vector{Int}
    n_points::Int
    n_terms::Int
    degree::Int
    n_dims::Int
end

"""
    group_subdomains_for_gpu(tree, active_ids, degree) -> Vector{BatchGroup}

Group active subdomains by (n_points, n_terms, n_dims) for efficient GPU batching.

Subdomains with identical grid configurations are grouped together so they can
be processed in a single batched GPU operation.

# Arguments
- `tree::SubdivisionTree`: The subdivision tree
- `active_ids::Vector{Int}`: Indices of active subdomains to process
- `degree`: Polynomial degree specification

# Returns
- Vector of BatchGroup, each containing subdomains with matching configurations
"""
function group_subdomains_for_gpu(tree::SubdivisionTree, active_ids::Vector{Int}, degree)
    groups = Dict{Tuple{Int,Int,Int}, Vector{Int}}()

    for id in active_ids
        sd = tree.subdomains[id]
        n_dim = dimension(sd)
        d = degree isa Tuple ? degree[2] : degree
        n_samples_per_dim = 2 * d + 1
        n_points = n_samples_per_dim^n_dim
        n_terms = binomial(n_dim + d, d)

        key = (n_points, n_terms, n_dim)
        if !haskey(groups, key)
            groups[key] = Int[]
        end
        push!(groups[key], id)
    end

    return [BatchGroup(ids, key[1], key[2],
                      degree isa Tuple ? degree[2] : degree, key[3])
            for (key, ids) in groups]
end

"""
    process_subdomains_gpu(f, tree, batch_group, l2_tolerance, basis) -> Vector{ProcessResult}

Process a batch of subdomains on GPU using batched Vandermonde + LS solve.

This function:
1. Generates grids for all subdomains in the batch
2. Evaluates the objective function at all grid points (CPU, sequential)
3. Builds batched Vandermonde matrices on GPU
4. Solves batched least squares on GPU
5. Computes errors and determines split decisions

# Arguments
- `f`: Objective function to approximate (any callable, including TolerantObjective)
- `tree::SubdivisionTree`: The subdivision tree
- `batch_group::BatchGroup`: Group of subdomains with same configuration
- `l2_tolerance::Float64`: Error tolerance for subdivision
- `basis::Symbol`: Polynomial basis (:chebyshev or :legendre)

# Returns
- Vector{ProcessResult}: Results for each subdomain in the batch
"""
function process_subdomains_gpu(
    f,
    tree::SubdivisionTree,
    batch_group::BatchGroup,
    l2_tolerance::Float64,
    basis::Symbol
)::Vector{ProcessResult}

    # Check GPU availability
    if !gpu_available()
        error("GPU requested but CUDA.jl not loaded or GPU not functional. " *
              "Load CUDA.jl before Globtim, or use gpu=false.")
    end

    B = length(batch_group.subdomain_ids)
    n_points = batch_group.n_points
    n_terms = batch_group.n_terms
    n_dim = batch_group.n_dims
    degree = batch_group.degree

    # Check GPU memory
    mem_required = estimate_gpu_memory_requirement(B, n_points, n_terms)
    mem_info = gpu_memory_info()
    if mem_required > 0.8 * mem_info.free
        error("Insufficient GPU memory. Required: $(mem_required ÷ 1_000_000) MB, " *
              "Available: $(mem_info.free ÷ 1_000_000) MB. " *
              "Reduce batch size or use gpu=false.")
    end

    # Generate support (shared across all subdomains)
    Lambda = SupportGen(n_dim, (:one_d_for_all, degree))

    # Prepare grids and collect f_values
    grids = Vector{Matrix{Float64}}(undef, B)
    f_values_all = zeros(Float64, n_points, B)

    n_samples_per_dim = 2 * degree + 1

    for (idx, sd_id) in enumerate(batch_group.subdomain_ids)
        subdomain = tree.subdomains[sd_id]

        # Generate normalized grid [-1, 1]^n
        grid = generate_grid(n_dim, n_samples_per_dim - 1, basis=basis)
        grid_matrix = grid_to_matrix(grid)  # (n_points, n_dim)
        grids[idx] = grid_matrix

        # Evaluate function at physical coordinates (CPU - this is the bottleneck)
        for i in 1:n_points
            x_normalized = grid_matrix[i, :]
            x_physical = subdomain.center .+ x_normalized .* subdomain.half_widths
            f_values_all[i, idx] = f(x_physical)
        end
    end

    # GPU: Build batched Vandermonde matrices
    V_batch_gpu = batched_vandermonde_gpu(Lambda, grids, basis)

    # Transfer f_values to GPU
    f_batch_gpu = CuArray(f_values_all)

    # GPU: Solve batched least squares
    coeffs_batch_gpu = batched_ls_solve_gpu(V_batch_gpu, f_batch_gpu)

    # Transfer results back to CPU
    coeffs_batch = Array(coeffs_batch_gpu)
    V_batch_cpu = Array(V_batch_gpu)

    # Compute errors and create results (on CPU)
    results = Vector{ProcessResult}(undef, B)

    for (idx, sd_id) in enumerate(batch_group.subdomain_ids)
        subdomain = tree.subdomains[sd_id]
        coeffs = coeffs_batch[:, idx]
        V = V_batch_cpu[:, :, idx]
        f_vals = f_values_all[:, idx]

        # Compute L2 error
        poly_values = V * coeffs
        errors = f_vals .- poly_values
        weight = (2.0 / n_samples_per_dim)^n_dim
        l2_error = sqrt(sum(abs2.(errors)) * weight)

        # Create ApproxPoly and cache in subdomain
        nrm = sqrt(sum(abs2.(poly_values)) * weight)
        pol = ApproxPoly{Float64}(
            coeffs, Lambda, (:one_d_for_all, degree), nrm,
            n_points, subdomain.half_widths, subdomain.center,
            collect(grids[idx]'), f_vals, basis,
            Float64Precision, true, false, NaN  # cond skipped for GPU path
        )

        # Update subdomain state
        subdomain.l2_error = l2_error
        subdomain.polynomial = pol
        subdomain.samples = grids[idx]
        subdomain.f_values = f_vals

        # Determine if split needed
        if l2_error <= l2_tolerance
            results[idx] = ProcessResult(sd_id, false, nothing, nothing, l2_error)
        else
            # Determine split dimension (use width-based for GPU path - faster)
            split_dim = select_cut_dimension_by_width(subdomain)
            cut_pos = 0.0  # Midpoint for GPU path (optimize_cuts adds overhead)
            results[idx] = ProcessResult(sd_id, true, split_dim, cut_pos, l2_error)
        end
    end

    return results
end

# Placeholder for CuArray when CUDA not loaded - will be overridden by extension
if !@isdefined(CuArray)
    const CuArray = Array  # Fallback type for non-GPU code paths
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
- `gpu::Bool=false`: Whether to use GPU acceleration (requires CUDA.jl)
- `basis::Symbol=:chebyshev`: Basis type
- `verbose::Bool=false`: Print progress information
- `phase_callback::Union{Function,Nothing}=nothing`: Called with `(f, :refine, 0)` at start.
    Use with `TolerantObjective` to set ODE tolerances per phase.

# Returns
- SubdivisionTree with refined subdomains

# GPU Acceleration
When `gpu=true`, batched Vandermonde matrix construction and least squares solving
are performed on GPU. This provides speedup when processing many subdomains (4+).
Requires CUDA.jl to be loaded before Globtim.

# Example
```julia
using CUDA  # Load before Globtim for GPU support
using Globtim

f(x) = sum(x.^2)
bounds = [(-1.0, 1.0), (-1.0, 1.0)]
tree = adaptive_refine(f, bounds, 4, l2_tolerance=1e-4, gpu=true)
```
"""
function adaptive_refine(f, bounds::Vector{Tuple{Float64, Float64}},
                         degree;
                         l2_tolerance::Float64=1e-6,
                         max_depth::Int=10,
                         max_leaves::Int=1000,
                         optimize_cuts::Bool=true,
                         parallel::Bool=true,
                         gpu::Bool=false,
                         basis::Symbol=:chebyshev,
                         verbose::Bool=false,
                         iteration_callback::Union{Function,Nothing}=nothing,
                         eval_progress::Union{Function,Nothing}=nothing,
                         phase_callback::Union{Function,Nothing}=nothing)

    # Validate GPU option
    if gpu && !gpu_available()
        error("GPU acceleration requested but CUDA.jl not loaded or GPU not functional. " *
              "Load CUDA.jl before Globtim, or use gpu=false.")
    end

    # Initialize tree
    tree = SubdivisionTree(bounds)

    # Notify phase callback that we're starting (single-phase refinement)
    if phase_callback !== nothing
        phase_callback(f, :refine, 0)
    end

    iteration = 0
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

        verbose && println("Iteration $iteration: $(n_active(tree)) active leaves, " *
                          "$(n_leaves(tree)) total leaves")

        # Process all active leaves
        current_active = copy(tree.active_leaves)

        if gpu && length(current_active) >= 4
            # GPU batched processing (worthwhile for 4+ subdomains)
            verbose && println("  Using GPU batched processing")
            batch_groups = group_subdomains_for_gpu(tree, current_active, degree)

            all_results = ProcessResult[]
            for group in batch_groups
                group_results = process_subdomains_gpu(f, tree, group, l2_tolerance, basis)
                append!(all_results, group_results)
            end

            # Sort results by original subdomain order
            results_dict = Dict(r.subdomain_id => r for r in all_results)
            results = [results_dict[id] for id in current_active]

        elseif parallel && length(current_active) > 1 && Threads.nthreads() > 1
            # CPU parallel processing
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(f, tree, leaf_id, degree, l2_tolerance,
                                                 optimize_cuts=optimize_cuts, basis=basis,
                                                 eval_progress=eval_progress)
            end
            results = fetch.(tasks)
        else
            # Sequential processing
            results = [process_subdomain(f, tree, leaf_id, degree, l2_tolerance,
                                        optimize_cuts=optimize_cuts, basis=basis,
                                        eval_progress=eval_progress)
                       for leaf_id in current_active]
        end

        # Update tree sequentially (not thread-safe)
        for (leaf_id, result) in zip(current_active, results)
            update_tree!(tree, result, tree.subdomains[leaf_id])
        end

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
            estimate_subdomain_error(f, sd, degree, basis=basis,
                                      eval_progress=eval_progress)
        end
        # Check if leaf now meets tolerance → mark as converged
        if sd.l2_error <= l2_tolerance
            filter!(id -> id != leaf_id, tree.active_leaves)
            push!(tree.converged_leaves, leaf_id)
        end
    end

    verbose && println("Final: $(n_leaves(tree)) leaves " *
                      "($(length(tree.converged_leaves)) converged, " *
                      "$(length(tree.active_leaves)) active)")

    return tree
end

#==============================================================================#
#                      TWO-PHASE REFINEMENT                                     #
#==============================================================================#

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
- `gpu::Bool=false`: Use GPU acceleration (requires CUDA.jl)
- `basis::Symbol=:chebyshev`: Basis type
- `verbose::Bool=false`: Print progress
- `phase_callback::Union{Function,Nothing}=nothing`: Called with `(f, :coarse, 0)` at
    Phase 1 start and `(f, :fine, 0)` at Phase 2 start. Use with `TolerantObjective` to
    switch ODE tolerances between phases.

# Returns
- SubdivisionTree with refined subdomains
"""
function two_phase_refine(f, bounds::Vector{Tuple{Float64, Float64}},
                          degree;
                          coarse_tolerance::Float64=1e-4,
                          fine_tolerance::Float64=1e-6,
                          balance_threshold::Float64=3.0,
                          max_depth::Int=10,
                          max_leaves::Int=1000,
                          parallel::Bool=true,
                          gpu::Bool=false,
                          basis::Symbol=:chebyshev,
                          verbose::Bool=false,
                          iteration_callback::Union{Function,Nothing}=nothing,
                          phase_callback::Union{Function,Nothing}=nothing)

    # Validate GPU option
    if gpu && !gpu_available()
        error("GPU acceleration requested but CUDA.jl not loaded or GPU not functional. " *
              "Load CUDA.jl before Globtim, or use gpu=false.")
    end

    verbose && println("=== Phase 1: Coarse balancing ===")

    # Notify phase callback for Phase 1 (coarse balancing)
    # This allows TolerantObjective to switch to coarse ODE tolerances
    if phase_callback !== nothing
        phase_callback(f, :coarse, 0)
    end

    # Phase 1: Coarse balancing pass
    tree = SubdivisionTree(bounds)

    phase1_iter = 0
    while !isempty(tree.active_leaves) && phase1_iter < 100
        phase1_iter += 1

        # Process all active leaves
        current_active = copy(tree.active_leaves)

        if gpu && length(current_active) >= 4
            # GPU batched processing
            batch_groups = group_subdomains_for_gpu(tree, current_active, degree)
            all_results = ProcessResult[]
            for group in batch_groups
                group_results = process_subdomains_gpu(f, tree, group, coarse_tolerance, basis)
                append!(all_results, group_results)
            end
            results_dict = Dict(r.subdomain_id => r for r in all_results)
            results = [results_dict[id] for id in current_active]
        elseif parallel && length(current_active) > 1 && Threads.nthreads() > 1
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(f, tree, leaf_id, degree, coarse_tolerance,
                                                 optimize_cuts=true, basis=basis)
            end
            results = fetch.(tasks)
        else
            results = [process_subdomain(f, tree, leaf_id, degree, coarse_tolerance,
                                        optimize_cuts=true, basis=basis)
                       for leaf_id in current_active]
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
            verbose && println("Phase 1 iteration $phase1_iter: ratio = $ratio")

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
    verbose && println("\n=== Phase 2: Accuracy refinement ===")

    # Notify phase callback for Phase 2 (fine accuracy)
    # This allows TolerantObjective to switch to tight ODE tolerances
    if phase_callback !== nothing
        phase_callback(f, :fine, 0)
    end

    # Phase 2: Accuracy refinement
    # Only re-activate leaves whose l2_error exceeds fine_tolerance;
    # leaves already below fine_tolerance from Phase 1 stay converged.
    needs_reeval = filter(id -> tree.subdomains[id].l2_error > fine_tolerance, tree.converged_leaves)
    already_fine = filter(id -> tree.subdomains[id].l2_error <= fine_tolerance, tree.converged_leaves)
    append!(tree.active_leaves, needs_reeval)
    tree.converged_leaves = already_fine

    verbose && length(already_fine) > 0 && println("  Skipping $(length(already_fine)) leaves already below fine_tolerance")

    phase2_iter = 0
    while !isempty(tree.active_leaves) && phase2_iter < 100
        phase2_iter += 1

        current_active = copy(tree.active_leaves)

        if gpu && length(current_active) >= 4
            # GPU batched processing
            batch_groups = group_subdomains_for_gpu(tree, current_active, degree)
            all_results = ProcessResult[]
            for group in batch_groups
                group_results = process_subdomains_gpu(f, tree, group, fine_tolerance, basis)
                append!(all_results, group_results)
            end
            results_dict = Dict(r.subdomain_id => r for r in all_results)
            results = [results_dict[id] for id in current_active]
        elseif parallel && length(current_active) > 1 && Threads.nthreads() > 1
            tasks = map(current_active) do leaf_id
                Threads.@spawn process_subdomain(f, tree, leaf_id, degree, fine_tolerance,
                                                 optimize_cuts=true, basis=basis)
            end
            results = fetch.(tasks)
        else
            results = [process_subdomain(f, tree, leaf_id, degree, fine_tolerance,
                                        optimize_cuts=true, basis=basis)
                       for leaf_id in current_active]
        end

        for (leaf_id, result) in zip(current_active, results)
            update_tree!(tree, result, tree.subdomains[leaf_id])
        end

        # Call iteration callback (phase 2)
        if iteration_callback !== nothing
            iteration_callback(tree, phase2_iter)
        end

        verbose && println("Phase 2 iteration $phase2_iter: " *
                          "$(length(tree.active_leaves)) active, " *
                          "$(length(tree.converged_leaves)) converged")

        if get_max_depth(tree) >= max_depth || n_leaves(tree) >= max_leaves
            break
        end
    end

    # Compute L2 errors for any unprocessed leaves (e.g., when max_depth reached)
    for leaf_id in tree.active_leaves
        sd = tree.subdomains[leaf_id]
        if sd.l2_error == Inf
            estimate_subdomain_error(f, sd, degree, basis=basis)
        end
    end

    verbose && println("\nFinal: $(n_leaves(tree)) leaves " *
                      "($(length(tree.converged_leaves)) converged)")

    return tree
end
