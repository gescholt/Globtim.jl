# ================================================================================
# Subdomain Management for 4D Domain Decomposition
# ================================================================================
#
# This file implements subdomain decomposition strategies for handling high-dimensional
# optimization problems, particularly for 4D Deuflhard and similar test functions.
#
# Key Features:
# - Orthant-based domain decomposition for 4D spaces
# - Subdomain center and range calculation
# - Overlap management for boundary critical points
# - Integration with multi-tolerance analysis framework

"""
    generate_4d_orthant_centers(base_center::Vector{Float64}, base_range::Float64)

Generate centers for 16 orthants in 4D space.

# Arguments
- `base_center::Vector{Float64}`: Center of the full domain (length 4)
- `base_range::Float64`: Range from center for the full domain

# Returns
- `Vector{Vector{Float64}}`: 16 orthant centers
"""
function generate_4d_orthant_centers(base_center::Vector{Float64}, base_range::Float64)
    @assert length(base_center) == 4 "Base center must be 4D"
    @assert base_range > 0 "Base range must be positive"

    orthant_centers = Vector{Vector{Float64}}()

    # Generate all 16 combinations of signs for 4D
    for i1 in [-1, 1], i2 in [-1, 1], i3 in [-1, 1], i4 in [-1, 1]
        offset = [i1, i2, i3, i4] * base_range / 2
        push!(orthant_centers, base_center + offset)
    end

    return orthant_centers
end

"""
    create_orthant_test_inputs(f::Function, base_center::Vector{Float64}, 
                              base_range::Float64, tolerance::Float64;
                              overlap_factor::Float64=0.1)

Create test inputs for all 16 orthants in 4D with optional overlap.

# Arguments
- `f::Function`: Objective function
- `base_center::Vector{Float64}`: Center of full domain
- `base_range::Float64`: Range of full domain
- `tolerance::Float64`: L²-norm tolerance for polynomial approximation
- `overlap_factor::Float64`: Overlap factor (0.1 = 10% overlap)

# Returns
- `Vector{test_input}`: 16 test inputs for orthant subdomains
"""
function create_orthant_test_inputs(
    f::Function,
    base_center::Vector{Float64},
    base_range::Float64,
    tolerance::Float64;
    overlap_factor::Float64 = 0.1
)

    orthant_centers = generate_4d_orthant_centers(base_center, base_range)
    subdomain_range = base_range / 2 * (1 + overlap_factor)

    test_inputs = test_input[]

    for (i, center) in enumerate(orthant_centers)
        TR = test_input(
            f,
            dim = 4,
            center = center,
            sample_range = subdomain_range,
            tolerance = tolerance
        )
        push!(test_inputs, TR)
    end

    return test_inputs
end

"""
    orthant_id_to_signs(orthant_id::Int)

Convert orthant ID (1-16) to sign pattern for 4D.

# Arguments
- `orthant_id::Int`: Orthant identifier (1-16)

# Returns
- `Vector{Int}`: Sign pattern [-1 or 1] for each dimension
"""
function orthant_id_to_signs(orthant_id::Int)
    @assert 1 <= orthant_id <= 16 "Orthant ID must be between 1 and 16"

    # Convert to 0-based index for binary representation
    idx = orthant_id - 1

    signs = Vector{Int}(undef, 4)
    for i in 1:4
        signs[i] = ((idx >> (i - 1)) & 1) == 0 ? -1 : 1
    end

    return signs
end

"""
    signs_to_orthant_id(signs::Vector{Int})

Convert sign pattern to orthant ID for 4D.

# Arguments
- `signs::Vector{Int}`: Sign pattern [-1 or 1] for each dimension

# Returns
- `Int`: Orthant ID (1-16)
"""
function signs_to_orthant_id(signs::Vector{Int})
    @assert length(signs) == 4 "Sign pattern must be 4D"
    @assert all(s -> s == -1 || s == 1, signs) "Signs must be -1 or 1"

    idx = 0
    for i in 1:4
        if signs[i] == 1
            idx |= (1 << (i - 1))
        end
    end

    return idx + 1
end

"""
    point_to_orthant_id(point::Vector{Float64}, center::Vector{Float64})

Determine which orthant a point belongs to relative to a center.

# Arguments
- `point::Vector{Float64}`: Point coordinates (length 4)
- `center::Vector{Float64}`: Center coordinates (length 4)

# Returns
- `Int`: Orthant ID (1-16)
"""
function point_to_orthant_id(point::Vector{Float64}, center::Vector{Float64})
    @assert length(point) == 4 && length(center) == 4 "Points must be 4D"

    signs = [p >= c ? 1 : -1 for (p, c) in zip(point, center)]
    return signs_to_orthant_id(signs)
end

"""
    filter_points_by_orthant(df::DataFrame, orthant_id::Int, base_center::Vector{Float64})

Filter critical points belonging to a specific orthant.

# Arguments
- `df::DataFrame`: DataFrame with critical points (columns x1, x2, x3, x4)
- `orthant_id::Int`: Target orthant ID (1-16)
- `base_center::Vector{Float64}`: Center of full domain

# Returns
- `DataFrame`: Subset of points in the specified orthant
"""
function filter_points_by_orthant(
    df::DataFrame,
    orthant_id::Int,
    base_center::Vector{Float64}
)
    mask = Bool[]

    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:4]
        point_orthant = point_to_orthant_id(point, base_center)
        push!(mask, point_orthant == orthant_id)
    end

    return df[mask, :]
end

"""
    merge_orthant_results(orthant_dfs::Vector{DataFrame}, base_center::Vector{Float64};
                         distance_tolerance::Float64=1e-6)

Merge results from all orthants, removing duplicates at boundaries.

# Arguments
- `orthant_dfs::Vector{DataFrame}`: Results from each orthant
- `base_center::Vector{Float64}`: Center of full domain
- `distance_tolerance::Float64`: Tolerance for identifying duplicates

# Returns
- `DataFrame`: Merged results with duplicates removed
"""
function merge_orthant_results(
    orthant_dfs::Vector{DataFrame},
    base_center::Vector{Float64};
    distance_tolerance::Float64 = 1e-6
)

    # Combine all DataFrames
    merged_df = vcat(orthant_dfs...)

    if nrow(merged_df) == 0
        return merged_df
    end

    # Remove duplicates based on proximity
    n_dims = 4
    keep_mask = trues(nrow(merged_df))

    for i in 1:(nrow(merged_df) - 1)
        if !keep_mask[i]
            continue
        end

        point_i = [merged_df[i, Symbol("x$j")] for j in 1:n_dims]

        for j in (i + 1):nrow(merged_df)
            if !keep_mask[j]
                continue
            end

            point_j = [merged_df[j, Symbol("x$j")] for j in 1:n_dims]

            # Check if points are too close
            if norm(point_i - point_j) < distance_tolerance
                # Keep the one with lower function value
                if merged_df[j, :z] < merged_df[i, :z]
                    keep_mask[i] = false
                    break
                else
                    keep_mask[j] = false
                end
            end
        end
    end

    return merged_df[keep_mask, :]
end

"""
    analyze_orthant_coverage(df::DataFrame, base_center::Vector{Float64})

Analyze distribution of critical points across orthants.

# Arguments
- `df::DataFrame`: DataFrame with critical points
- `base_center::Vector{Float64}`: Center of full domain

# Returns
- `Dict{Int, Int}`: Count of points in each orthant
"""
function analyze_orthant_coverage(df::DataFrame, base_center::Vector{Float64})
    coverage = Dict{Int, Int}()

    # Initialize all orthants
    for i in 1:16
        coverage[i] = 0
    end

    # Count points in each orthant
    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:4]
        orthant_id = point_to_orthant_id(point, base_center)
        coverage[orthant_id] += 1
    end

    return coverage
end

"""
    compute_orthant_statistics(orthant_results::Vector{OrthantResult})

Compute aggregate statistics across all orthants.

# Arguments
- `orthant_results::Vector{OrthantResult}`: Results from each orthant

# Returns
- `NamedTuple`: Aggregate statistics including success rates, point counts, etc.
"""
function compute_orthant_statistics(orthant_results::Vector{OrthantResult})
    @assert length(orthant_results) == 16 "Expected 16 orthant results for 4D"

    # Extract metrics
    success_rates = [r.success_rate for r in orthant_results]
    raw_counts = [r.raw_point_count for r in orthant_results]
    bfgs_counts = [r.bfgs_point_count for r in orthant_results]
    median_distances = [r.median_distance for r in orthant_results]
    computation_times = [r.computation_time for r in orthant_results]

    return (
        mean_success_rate = mean(success_rates),
        std_success_rate = std(success_rates),
        total_raw_points = sum(raw_counts),
        total_bfgs_points = sum(bfgs_counts),
        mean_median_distance = mean(median_distances),
        total_computation_time = sum(computation_times),
        min_success_rate = minimum(success_rates),
        max_success_rate = maximum(success_rates),
        orthants_with_points = count(c -> c > 0, raw_counts)
    )
end

# Export subdomain management functions
export generate_4d_orthant_centers,
    create_orthant_test_inputs,
    orthant_id_to_signs,
    signs_to_orthant_id,
    point_to_orthant_id,
    filter_points_by_orthant,
    merge_orthant_results,
    analyze_orthant_coverage,
    compute_orthant_statistics
