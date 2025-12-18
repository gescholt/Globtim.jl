# Valley Walking Algorithm - "Walk in the Valley"
#
# This module implements the main "walk in the valley" algorithm for comprehensively
# exploring positive dimensional regions of local minimizers.

using LinearAlgebra
using DataFrames
using Clustering

"""
    ValleyWalkingConfig

Configuration for the valley walking algorithm.

# Fields
- `valley_detection_config::ValleyDetectionConfig`: Configuration for valley detection
- `sampling_density::Float64`: Density of sampling along valley directions (default: 0.1)
- `max_walk_distance::Float64`: Maximum distance to walk in each direction (default: 2.0)
- `adaptive_step_size::Bool`: Whether to use adaptive step sizing (default: true)
- `min_step_size::Float64`: Minimum step size (default: 1e-4)
- `max_step_size::Float64`: Maximum step size (default: 0.5)
- `convergence_tolerance::Float64`: Tolerance for detecting convergence (default: 1e-8)
- `cluster_tolerance::Float64`: Distance tolerance for clustering valley points (default: 1e-6)
- `boundary_detection::Bool`: Whether to detect valley boundaries (default: true)
- `max_valley_points::Int`: Maximum number of points to sample per valley (default: 1000)
"""
struct ValleyWalkingConfig
    valley_detection_config::ValleyDetectionConfig
    sampling_density::Float64
    max_walk_distance::Float64
    adaptive_step_size::Bool
    min_step_size::Float64
    max_step_size::Float64
    convergence_tolerance::Float64
    cluster_tolerance::Float64
    boundary_detection::Bool
    max_valley_points::Int

    function ValleyWalkingConfig(;
        valley_detection_config::ValleyDetectionConfig = ValleyDetectionConfig(),
        sampling_density::Float64 = 0.1,
        max_walk_distance::Float64 = 2.0,
        adaptive_step_size::Bool = true,
        min_step_size::Float64 = 1e-4,
        max_step_size::Float64 = 0.5,
        convergence_tolerance::Float64 = 1e-8,
        cluster_tolerance::Float64 = 1e-6,
        boundary_detection::Bool = true,
        max_valley_points::Int = 1000
    )
        new(valley_detection_config, sampling_density, max_walk_distance,
            adaptive_step_size, min_step_size, max_step_size, convergence_tolerance,
            cluster_tolerance, boundary_detection, max_valley_points)
    end
end

"""
    ValleyManifold

Represents a discovered valley manifold with all its explored points.

# Fields
- `manifold_id::Int`: Unique identifier for this manifold
- `dimension::Int`: Dimension of the valley manifold
- `seed_point::Vector{Float64}`: Original critical point that seeded this manifold
- `manifold_points::Vector{Vector{Float64}}`: All points discovered on this manifold
- `function_values::Vector{Float64}`: Function values at manifold points
- `valley_infos::Vector{ValleyInfo}`: Valley information at each point
- `boundary_points::Vector{Vector{Float64}}`: Points where valley ends
- `manifold_bounds::Matrix{Float64}`: Bounding box of manifold (2×d matrix: [min; max])
- `total_length::Float64`: Estimated total length/area/volume of manifold
- `representative_point::Vector{Float64}`: Representative point (e.g., centroid)
- `confidence_score::Float64`: Confidence in manifold quality (0-1)
"""
struct ValleyManifold
    manifold_id::Int
    dimension::Int
    seed_point::Vector{Float64}
    manifold_points::Vector{Vector{Float64}}
    function_values::Vector{Float64}
    valley_infos::Vector{ValleyInfo}
    boundary_points::Vector{Vector{Float64}}
    manifold_bounds::Matrix{Float64}
    total_length::Float64
    representative_point::Vector{Float64}
    confidence_score::Float64
end

"""
    ValleyWalkingResult

Complete result of valley walking analysis.

# Fields
- `discovered_manifolds::Vector{ValleyManifold}`: All discovered valley manifolds
- `isolated_critical_points::Vector{Vector{Float64}}`: Critical points not in valleys
- `total_manifolds::Int`: Number of distinct manifolds found
- `total_valley_points::Int`: Total number of points on all manifolds
- `coverage_analysis::Dict{String, Any}`: Analysis of domain coverage
- `execution_stats::Dict{String, Any}`: Execution statistics and timing
"""
struct ValleyWalkingResult
    discovered_manifolds::Vector{ValleyManifold}
    isolated_critical_points::Vector{Vector{Float64}}
    total_manifolds::Int
    total_valley_points::Int
    coverage_analysis::Dict{String, Any}
    execution_stats::Dict{String, Any}
end

"""
    walk_in_the_valley(f, df::DataFrame, TR, config::ValleyWalkingConfig = ValleyWalkingConfig())

Main "walk in the valley" algorithm for exploring positive dimensional minimizer regions.

This is the primary function that implements comprehensive valley exploration. Starting from
critical points detected by polynomial approximation, it identifies valleys using Hessian
rank deficiency, then systematically explores each valley manifold through adaptive sampling.

# Arguments
- `f`: Objective function
- `df::DataFrame`: Critical points from process_crit_pts
- `TR`: Test input structure (domain information)
- `config::ValleyWalkingConfig`: Algorithm configuration

# Returns
- `ValleyWalkingResult`: Comprehensive results including all discovered manifolds

# Algorithm Overview
1. **Valley Detection Phase**: Analyze all critical points for valley structure
2. **Manifold Seeding Phase**: Identify seed points for distinct manifolds
3. **Valley Walking Phase**: For each manifold, systematically explore:
   - Walk in all valley directions from seed point
   - Use adaptive step sizing based on valley width and curvature
   - Detect boundaries where valley structure breaks down
   - Sample densely within valley bounds
4. **Clustering Phase**: Group discovered points into coherent manifolds
5. **Analysis Phase**: Compute manifold properties and statistics

# Examples
```julia
using Globtim, DynamicPolynomials

# Create function with valley structure
f = x -> x[1]^4 + x[2]^2  # Valley along x[1] = 0

# Standard Globtim workflow to find critical points
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Valley walking analysis
config = ValleyWalkingConfig(max_walk_distance=1.0, sampling_density=0.05)
result = walk_in_the_valley(f, df, TR, config)

println("Found \$(result.total_manifolds) valley manifolds")
for (i, manifold) in enumerate(result.discovered_manifolds)
    println("Manifold \$i: dimension \$(manifold.dimension), \$(length(manifold.manifold_points)) points")
end
```
"""
function walk_in_the_valley(
    f,
    df::DataFrame,
    TR,
    config::ValleyWalkingConfig = ValleyWalkingConfig()
)
    @info "Starting valley walking analysis with $(nrow(df)) critical points"

    start_time = time()
    execution_stats = Dict{String, Any}()

    # Phase 1: Valley Detection
    @info "Phase 1: Detecting valleys at critical points"
    df_enhanced = analyze_valleys_in_critical_points(f, df, config.valley_detection_config)

    valley_points = df_enhanced[df_enhanced.is_valley, :]
    isolated_points = df_enhanced[.!df_enhanced.is_valley, :]

    execution_stats["valley_detection_time"] = time() - start_time
    execution_stats["total_critical_points"] = nrow(df)
    execution_stats["valley_critical_points"] = nrow(valley_points)
    execution_stats["isolated_critical_points"] = nrow(isolated_points)

    @info "Found $(nrow(valley_points)) valley points and $(nrow(isolated_points)) isolated points"

    if nrow(valley_points) == 0
        @info "No valleys detected - returning empty result"
        return ValleyWalkingResult(
            ValleyManifold[],
            [
                extract_point_coordinates(isolated_points, i) for
                i in 1:nrow(isolated_points)
            ],
            0, 0, Dict{String, Any}(), execution_stats
        )
    end

    # Phase 2: Manifold Seeding and Clustering
    @info "Phase 2: Identifying distinct manifolds"
    phase2_start = time()

    manifold_seeds = identify_manifold_seeds(f, valley_points, config)
    execution_stats["manifold_seeding_time"] = time() - phase2_start
    execution_stats["discovered_manifold_seeds"] = length(manifold_seeds)

    @info "Identified $(length(manifold_seeds)) potential manifold seeds"

    # Phase 3: Valley Walking
    @info "Phase 3: Walking valleys and exploring manifolds"
    phase3_start = time()

    discovered_manifolds = Vector{ValleyManifold}()
    total_valley_points = 0

    for (manifold_id, seed_point) in enumerate(manifold_seeds)
        @info "Exploring manifold $manifold_id starting from $seed_point"

        manifold = explore_single_manifold(f, seed_point, manifold_id, TR, config)

        if manifold !== nothing
            push!(discovered_manifolds, manifold)
            total_valley_points += length(manifold.manifold_points)
            @info "Manifold $manifold_id: dimension $(manifold.dimension), $(length(manifold.manifold_points)) points"
        end
    end

    execution_stats["valley_walking_time"] = time() - phase3_start
    execution_stats["total_manifolds_explored"] = length(manifold_seeds)
    execution_stats["successful_manifolds"] = length(discovered_manifolds)

    # Phase 4: Coverage Analysis
    @info "Phase 4: Analyzing domain coverage"
    phase4_start = time()

    coverage_analysis = analyze_valley_coverage(discovered_manifolds, TR, config)
    execution_stats["coverage_analysis_time"] = time() - phase4_start
    execution_stats["total_execution_time"] = time() - start_time

    @info "Valley walking complete: $(length(discovered_manifolds)) manifolds, $total_valley_points total points"

    return ValleyWalkingResult(
        discovered_manifolds,
        [extract_point_coordinates(isolated_points, i) for i in 1:nrow(isolated_points)],
        length(discovered_manifolds),
        total_valley_points,
        coverage_analysis,
        execution_stats
    )
end

"""
    identify_manifold_seeds(f, valley_points::DataFrame, config::ValleyWalkingConfig)

Identify seed points for distinct valley manifolds using clustering.

Groups valley points by proximity and valley dimension to identify distinct manifolds
that should be explored separately.

# Arguments
- `f`: Objective function
- `valley_points::DataFrame`: Points detected as being in valleys
- `config::ValleyWalkingConfig`: Configuration

# Returns
- `Vector{Vector{Float64}}`: Seed points for manifold exploration
"""
function identify_manifold_seeds(f, valley_points::DataFrame, config::ValleyWalkingConfig)
    if nrow(valley_points) == 0
        return Vector{Vector{Float64}}()
    end

    # Extract coordinates
    points_matrix = extract_coordinates_matrix(valley_points)

    # Group by valley dimension first
    dimension_groups = Dict{Int, Vector{Int}}()
    for i in 1:nrow(valley_points)
        dim = valley_points[i, :valley_dimension]
        if !haskey(dimension_groups, dim)
            dimension_groups[dim] = Int[]
        end
        push!(dimension_groups[dim], i)
    end

    seeds = Vector{Vector{Float64}}()

    # Process each dimension group separately
    for (dim, indices) in dimension_groups
        if length(indices) == 1
            # Single point in this dimension - use as seed
            push!(seeds, extract_point_coordinates(valley_points, indices[1]))
        else
            # Multiple points - cluster them
            group_points = points_matrix[indices, :]

            # Use k-means clustering to identify distinct manifolds
            # Start with k = ceil(length(indices) / 5) and adjust
            max_k = min(10, max(1, length(indices) ÷ 5))

            for k in 1:max_k
                try
                    clustering_result = kmeans(group_points', k)

                    # Use cluster centers as seeds, but project to nearest valley point
                    for center in eachcol(clustering_result.centers)
                        # Find nearest actual valley point to this center
                        distances = [
                            norm(group_points[i, :] - center) for
                            i in 1:size(group_points, 1)
                        ]
                        nearest_idx = argmin(distances)
                        actual_idx = indices[nearest_idx]

                        seed_point = extract_point_coordinates(valley_points, actual_idx)

                        # Check if this seed is sufficiently different from existing seeds
                        is_new_seed = true
                        for existing_seed in seeds
                            if norm(seed_point - existing_seed) <
                               config.cluster_tolerance * 10
                                is_new_seed = false
                                break
                            end
                        end

                        if is_new_seed
                            push!(seeds, seed_point)
                        end
                    end

                    break  # Use first successful clustering
                catch e
                    @debug "Clustering failed for k=$k: $e"
                    continue
                end
            end

            # Fallback: if clustering failed, use uniformly spaced points
            if length(seeds) == 0
                step = max(1, length(indices) ÷ 5)
                for i in 1:step:length(indices)
                    push!(seeds, extract_point_coordinates(valley_points, indices[i]))
                end
            end
        end
    end

    return seeds
end

"""
    explore_single_manifold(f, seed_point::Vector{Float64}, manifold_id::Int, TR, config::ValleyWalkingConfig)

Explore a single valley manifold starting from a seed point.

Performs comprehensive exploration of one valley manifold using adaptive walking
in all valley directions, boundary detection, and dense sampling.

# Arguments
- `f`: Objective function
- `seed_point::Vector{Float64}`: Starting point for exploration
- `manifold_id::Int`: Unique identifier for this manifold
- `TR`: Test input structure (domain bounds)
- `config::ValleyWalkingConfig`: Configuration

# Returns
- `ValleyManifold` or `nothing`: Discovered manifold information
"""
function explore_single_manifold(
    f,
    seed_point::Vector{Float64},
    manifold_id::Int,
    TR,
    config::ValleyWalkingConfig
)
    # Detect valley structure at seed point
    valley_info = detect_valley_at_point(f, seed_point, config.valley_detection_config)

    if !valley_info.is_valley
        @warn "Seed point is not in a valley - skipping manifold $manifold_id"
        return nothing
    end

    manifold_points = [copy(seed_point)]
    function_values = [f(seed_point)]
    valley_infos = [valley_info]
    boundary_points = Vector{Vector{Float64}}()

    # Get domain bounds from TR
    domain_bounds = extract_domain_bounds(TR)

    # Explore in each valley direction
    for dir_idx in 1:size(valley_info.valley_directions, 2)
        direction = valley_info.valley_directions[:, dir_idx]

        # Walk in positive direction
        explore_direction_branch!(f, seed_point, direction, manifold_points,
            function_values, valley_infos, boundary_points,
            domain_bounds, config)

        # Walk in negative direction
        explore_direction_branch!(f, seed_point, -direction, manifold_points,
            function_values, valley_infos, boundary_points,
            domain_bounds, config)
    end

    # Remove duplicates based on proximity
    unique_indices = find_unique_points(manifold_points, config.cluster_tolerance)
    manifold_points = manifold_points[unique_indices]
    function_values = function_values[unique_indices]
    valley_infos = valley_infos[unique_indices]

    # Compute manifold properties
    manifold_bounds = compute_manifold_bounds(manifold_points)
    total_length = estimate_manifold_measure(manifold_points, valley_info.valley_dimension)
    representative_point = compute_centroid(manifold_points)
    confidence_score = compute_manifold_confidence(valley_infos)

    return ValleyManifold(
        manifold_id,
        valley_info.valley_dimension,
        copy(seed_point),
        manifold_points,
        function_values,
        valley_infos,
        boundary_points,
        manifold_bounds,
        total_length,
        representative_point,
        confidence_score
    )
end

"""
    explore_direction_branch!(f, start_point, direction, manifold_points, function_values, 
                             valley_infos, boundary_points, domain_bounds, config)

Explore valley manifold in a specific direction from start point.

Modifies the manifold_points, function_values, valley_infos, and boundary_points arrays
by adding newly discovered points along the valley in the given direction.
"""
function explore_direction_branch!(f, start_point::Vector{Float64},
    direction::Vector{Float64},
    manifold_points::Vector{Vector{Float64}},
    function_values::Vector{Float64},
    valley_infos::Vector{ValleyInfo},
    boundary_points::Vector{Vector{Float64}},
    domain_bounds::Matrix{Float64},
    config::ValleyWalkingConfig)

    current_point = copy(start_point)
    current_step_size =
        config.adaptive_step_size ? config.max_step_size / 10 : config.sampling_density
    total_distance = 0.0

    while total_distance < config.max_walk_distance &&
        length(manifold_points) < config.max_valley_points
        # Take step in valley direction
        candidate_point = current_point + current_step_size * direction

        # Check domain bounds
        if !point_in_domain(candidate_point, domain_bounds)
            push!(boundary_points, copy(current_point))
            break
        end

        # Project to critical manifold
        projected_point =
            project_to_critical_manifold(f, candidate_point, config.valley_detection_config)

        if projected_point === nothing
            push!(boundary_points, copy(current_point))
            break
        end

        # Detect valley at new point
        new_valley_info =
            detect_valley_at_point(f, projected_point, config.valley_detection_config)

        # Check if we're still in the same valley structure
        if !new_valley_info.is_valley ||
           new_valley_info.valley_dimension != valley_infos[1].valley_dimension ||
           new_valley_info.manifold_score < 0.1
            push!(boundary_points, copy(current_point))
            break
        end

        # Add point to manifold
        push!(manifold_points, copy(projected_point))
        push!(function_values, f(projected_point))
        push!(valley_infos, new_valley_info)

        # Update for next iteration
        current_point = projected_point
        total_distance += current_step_size

        # Adaptive step size based on valley width and curvature
        if config.adaptive_step_size
            valley_width = new_valley_info.valley_width
            current_step_size = clamp(
                valley_width / 20,  # Step size proportional to valley width
                config.min_step_size,
                config.max_step_size
            )
        end
    end
end

# Helper functions

function extract_point_coordinates(df::DataFrame, row_idx::Int)
    x_cols = filter(name -> startswith(string(name), "x_"), names(df))
    return [df[row_idx, col] for col in x_cols]
end

function extract_coordinates_matrix(df::DataFrame)
    x_cols = filter(name -> startswith(string(name), "x_"), names(df))
    return Matrix(df[:, x_cols])
end

function extract_domain_bounds(TR)
    # Extract domain bounds from test input structure
    # This is a simplified version - adapt based on actual TR structure
    if hasfield(typeof(TR), :sample_range)
        range_val = TR.sample_range
        center = hasfield(typeof(TR), :center) ? TR.center : zeros(length(TR.sample_range))
        dim = length(center)
        bounds = zeros(2, dim)
        for i in 1:dim
            bounds[1, i] = center[i] - range_val[i]  # min
            bounds[2, i] = center[i] + range_val[i]  # max
        end
        return bounds
    else
        # Fallback: assume unit hypercube
        dim = 2  # Default dimension
        return [-ones(1, dim); ones(1, dim)]
    end
end

function point_in_domain(point::Vector{Float64}, bounds::Matrix{Float64})
    for i in 1:length(point)
        if point[i] < bounds[1, i] || point[i] > bounds[2, i]
            return false
        end
    end
    return true
end

function find_unique_points(points::Vector{Vector{Float64}}, tolerance::Float64)
    unique_indices = Int[]
    for i in 1:length(points)
        is_unique = true
        for j in unique_indices
            if norm(points[i] - points[j]) < tolerance
                is_unique = false
                break
            end
        end
        if is_unique
            push!(unique_indices, i)
        end
    end
    return unique_indices
end

function compute_manifold_bounds(points::Vector{Vector{Float64}})
    if isempty(points)
        return zeros(2, 0)
    end

    dim = length(points[1])
    bounds = zeros(2, dim)

    for i in 1:dim
        coords = [p[i] for p in points]
        bounds[1, i] = minimum(coords)
        bounds[2, i] = maximum(coords)
    end

    return bounds
end

function estimate_manifold_measure(points::Vector{Vector{Float64}}, dimension::Int)
    if length(points) <= 1
        return 0.0
    end

    if dimension == 1
        # Estimate total length
        sorted_points = sort(points, by = p -> p[1])  # Sort by first coordinate
        total_length = 0.0
        for i in 2:length(sorted_points)
            total_length += norm(sorted_points[i] - sorted_points[i - 1])
        end
        return total_length
    else
        # For higher dimensions, estimate using convex hull or bounding box volume
        bounds = compute_manifold_bounds(points)
        volume = 1.0
        for i in 1:size(bounds, 2)
            volume *= bounds[2, i] - bounds[1, i]
        end
        return volume
    end
end

function compute_centroid(points::Vector{Vector{Float64}})
    if isempty(points)
        return Float64[]
    end

    dim = length(points[1])
    centroid = zeros(Float64, dim)

    for point in points
        centroid += point
    end

    return centroid / length(points)
end

function compute_manifold_confidence(valley_infos::Vector{ValleyInfo})
    if isempty(valley_infos)
        return 0.0
    end

    scores = [info.manifold_score for info in valley_infos]
    return mean(scores)
end

function analyze_valley_coverage(
    manifolds::Vector{ValleyManifold},
    TR,
    config::ValleyWalkingConfig
)
    coverage = Dict{String, Any}()

    coverage["total_manifolds"] = length(manifolds)
    coverage["manifold_dimensions"] = [m.dimension for m in manifolds]
    coverage["total_manifold_points"] = sum(length(m.manifold_points) for m in manifolds)

    if !isempty(manifolds)
        coverage["average_manifold_size"] =
            mean(length(m.manifold_points) for m in manifolds)
        coverage["largest_manifold_size"] =
            maximum(length(m.manifold_points) for m in manifolds)
        coverage["average_confidence"] = mean(m.confidence_score for m in manifolds)
        coverage["total_manifold_measure"] = sum(m.total_length for m in manifolds)
    else
        coverage["average_manifold_size"] = 0
        coverage["largest_manifold_size"] = 0
        coverage["average_confidence"] = 0.0
        coverage["total_manifold_measure"] = 0.0
    end

    return coverage
end
