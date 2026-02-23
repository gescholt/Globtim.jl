# Import ForwardDiff for enhanced BFGS functionality
using ForwardDiff
using Logging

"""
    assign_spatial_regions(df::DataFrame, TR::TestInput, n_regions_per_dim::Int=5)::Vector{Int}

Assign spatial region IDs to critical points for convergence analysis.

Divides the domain into n_regions_per_dim^n cubic regions and assigns each point
to its corresponding region for spatial statistics computation.

# Returns
Vector{Int}: Region ID (1 to n_regions_per_dim^n) for each point in df
"""
function assign_spatial_regions(
    df::DataFrame,
    TR::TestInput,
    n_regions_per_dim::Int = 5
)::Vector{Int}
    n_dims = count(col -> startswith(string(col), "x"), names(df))
    n_points = nrow(df)
    region_ids = Vector{Int}(undef, n_points)

    # Get domain bounds
    if isa(TR.sample_range, Number)
        bounds_min = TR.center .- TR.sample_range
        bounds_max = TR.center .+ TR.sample_range
    else
        bounds_min = TR.center .- TR.sample_range
        bounds_max = TR.center .+ TR.sample_range
    end

    # Compute region size per dimension
    region_sizes = (bounds_max .- bounds_min) ./ n_regions_per_dim

    for i in 1:n_points
        region_coords = Vector{Int}(undef, n_dims)
        for j in 1:n_dims
            coord = df[i, Symbol("x$j")]
            # Clamp to avoid boundary issues
            normalized = (coord - bounds_min[j]) / region_sizes[j]
            region_coords[j] = clamp(floor(Int, normalized), 0, n_regions_per_dim - 1)
        end

        # Convert n-dimensional region coordinates to single ID
        region_id = 1
        multiplier = 1
        for j in 1:n_dims
            region_id += region_coords[j] * multiplier
            multiplier *= n_regions_per_dim
        end
        region_ids[i] = region_id
    end

    return region_ids
end

"""
    cluster_function_values(z_values::Vector{Float64}, n_clusters::Int=5)::Vector{Int}

Cluster critical points by function values using k-means.

# Returns  
Vector{Int}: Cluster assignment (1 to n_clusters) for each point
"""
function cluster_function_values(
    z_values::Vector{Float64},
    n_clusters::Int = 5
)::Vector{Int}
    # Handle edge cases
    if length(z_values) <= n_clusters
        return collect(1:length(z_values))
    end

    # Reshape for clustering (k-means expects matrix)
    data = reshape(z_values, 1, :)

    # Use fewer clusters if we have too few unique values
    unique_vals = length(unique(z_values))
    actual_clusters = min(n_clusters, unique_vals)

    try
        result = kmeans(data, actual_clusters)
        return result.assignments
    catch e
        # Fallback: simple binning
        min_z, max_z = extrema(z_values)
        bin_size = (max_z - min_z) / actual_clusters
        return [
            clamp(floor(Int, (z - min_z) / bin_size) + 1, 1, actual_clusters) for
            z in z_values
        ]
    end
end

"""
    compute_nearest_neighbors(df::DataFrame, n_dims::Int)::Vector{Float64}

Compute distance to nearest neighbor for each critical point.

# Returns
Vector{Float64}: Distance to nearest other point for each point
"""
function compute_nearest_neighbors(df::DataFrame, n_dims::Int)::Vector{Float64}
    n_points = nrow(df)
    distances = Vector{Float64}(undef, n_points)

    # Extract coordinates
    coords = Matrix{Float64}(undef, n_points, n_dims)
    for i in 1:n_dims
        coords[:, i] = df[!, Symbol("x$i")]
    end

    for i in 1:n_points
        min_dist = Inf
        for j in 1:n_points
            if i != j
                dist = norm(coords[i, :] - coords[j, :])
                min_dist = min(min_dist, dist)
            end
        end
        distances[i] = min_dist
    end

    return distances
end

"""
    compute_gradients(f, points::Matrix{Float64})::Vector{Float64}

Compute gradient norms at specified points using automatic differentiation.

# Arguments
- f: Function to differentiate (any callable)
- points: Matrix where each row is a point (n_points × n_dims)

# Returns
Vector{Float64}: ||∇f(x)|| for each point
"""
function compute_gradients(f, points::Matrix{Float64})::Vector{Float64}
    n_points, n_dims = size(points)
    grad_norms = Vector{Float64}(undef, n_points)

    # Collect failures for summary reporting
    failed_points = Int[]
    failure_types = Set{String}()

    for i in 1:n_points
        try
            point = Vector{Float64}(points[i, :])
            grad = ForwardDiff.gradient(f, point)
            grad_norms[i] = norm(grad)
        catch e
            push!(failed_points, i)
            push!(failure_types, string(typeof(e)))
            @debug "Point $i: Gradient computation failed with error: $e" exception=(e, catch_backtrace())
            # Fallback for points where gradient computation fails
            grad_norms[i] = NaN
        end
    end

    # Report summary if any points failed
    if !isempty(failed_points)
        sample_points = first(failed_points, min(5, length(failed_points)))
        @warn "Gradient computation failed for $(length(failed_points))/$n_points points" failed_points=sample_points error_types=collect(failure_types)
    end

    return grad_norms
end

"""
    analyze_basins(df::DataFrame, df_min::DataFrame, n_dims::Int, tol_dist::Float64)

Analyze basin of attraction properties for each unique minimizer.

# Returns
Tuple{Vector{Int}, Vector{Float64}, Vector{Int}}: 
- Basin sizes (point count for each minimizer)
- Average convergence steps for each minimizer  
- Region coverage count for each minimizer
"""
function analyze_basins(
    df::DataFrame,
    df_min::DataFrame,
    n_dims::Int,
    tol_dist::Float64
)::Tuple{Vector{Int}, Vector{Float64}, Vector{Int}}
    n_minimizers = nrow(df_min)
    basin_sizes = zeros(Int, n_minimizers)
    avg_steps = zeros(Float64, n_minimizers)
    region_coverage = zeros(Int, n_minimizers)

    # For each minimizer, find which critical points converge to it
    for i in 1:n_minimizers
        minimizer = [df_min[i, Symbol("x$j")] for j in 1:n_dims]
        converging_points = Int[]
        total_steps = 0.0
        regions_covered = Set{Int}()

        for k in 1:nrow(df)
            if df[k, :converged]
                optimized_point = [df[k, Symbol("y$j")] for j in 1:n_dims]
                if norm(optimized_point - minimizer) < tol_dist
                    push!(converging_points, k)
                    total_steps += df[k, :steps]
                    if :region_id in names(df)
                        push!(regions_covered, df[k, :region_id])
                    end
                end
            end
        end

        basin_sizes[i] = length(converging_points)
        avg_steps[i] = basin_sizes[i] > 0 ? total_steps / basin_sizes[i] : 0.0
        region_coverage[i] = length(regions_covered)
    end

    return basin_sizes, avg_steps, region_coverage
end

"""
Applies a mask to the dataframe based on the hypercube defined in the test input TR. 
The mask is a boolean array where each element corresponds to a row in the dataframe. 
If the point is within the hypercube, the mask value is true; otherwise, it is false.
We have the `use_y` to run this check on the y-coordinates (optimized points) instead of 
the x-coordinates (raw critical points).

Now supports per-coordinate scaling factors.
"""
function points_in_hypercube(df::DataFrame, TR; use_y::Bool = false)
    # Count dimensions based on whether we're checking x or y columns
    prefix = use_y ? "y" : "x"
    n_dims = count(col -> startswith(string(col), prefix), names(df))

    # Create boolean array for results
    in_cube = trues(nrow(df))

    # Check each point
    for i in 1:nrow(df)
        for j in 1:n_dims
            coord = df[i, Symbol("$(prefix)$j")]

            # Skip NaN coordinates when checking y values
            if use_y && isnan(coord)
                in_cube[i] = false
                break
            end

            # Handle different sample_range types
            if isa(TR.sample_range, Number)
                # Scalar sample_range
                if abs(coord - TR.center[j]) > TR.sample_range
                    in_cube[i] = false
                    break
                end
            else
                # Vector sample_range
                if abs(coord - TR.center[j]) > TR.sample_range[j]
                    in_cube[i] = false
                    break
                end
            end
        end
    end
    return in_cube
end

"""
Filter points based on function value being within a range of the minimum value.
Now supports per-coordinate scaling.
"""
function points_in_range(df::DataFrame, TR, value_range::Float64)
    # Count x-columns to determine dimensionality
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Create boolean array for results
    in_range = falses(nrow(df))

    # Reference value (minimum found so far)
    min_val = minimum(df.z)

    # Check each point's function evaluation
    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:n_dims]
        val = TR.objective(point)
        if abs(val - min_val) ≤ value_range
            in_range[i] = true
        end
    end

    return in_range
end

"""
    analyze_critical_points(f::Function, df::DataFrame, TR::TestInput; kwargs...)

Comprehensive critical point analysis with enhanced statistics and optional Hessian-based classification.

This function performs detailed analysis of critical points found by polynomial approximation, including:
- BFGS refinement of critical points
- Clustering and proximity analysis
- Enhanced statistical measures
- Optional Hessian-based classification and eigenvalue analysis

# Arguments
- `f::Function`: The objective function to analyze
- `df::DataFrame`: DataFrame containing critical points with columns x1, x2, ..., xn, z
- `TR::TestInput`: Test input specification containing domain information

# Keyword Arguments
- `tol_dist=0.025`: Distance tolerance for clustering critical points
- `verbose=true`: Enable detailed progress output
- `max_iters_in_optim=50`: Maximum iterations for BFGS optimization
- `enable_hessian=true`: Enable Hessian-based classification
- `hessian_tol_zero=1e-8`: Tolerance for zero eigenvalues in Hessian analysis
- `bfgs_g_tol=1e-8`: Gradient tolerance for BFGS optimization
- `bfgs_f_abstol=1e-8`: Absolute function tolerance for BFGS optimization
- `bfgs_x_abstol=0.0`: Absolute parameter tolerance for BFGS optimization

# Returns
- `Tuple{DataFrame, DataFrame}`: (enhanced_df, minimizers_df)
  - `enhanced_df`: Input DataFrame with additional analysis columns
  - `minimizers_df`: Subset containing only unique local minimizers

# Enhanced Statistics (always included)
The enhanced DataFrame includes these additional columns:
- `region_id`: Cluster identifier for spatially close points
- `function_value_cluster`: Cluster identifier for points with similar function values
- `nearest_neighbor_dist`: Distance to nearest neighboring critical point
- `gradient_norm`: L2 norm of gradient at the critical point
- `y1, y2, ..., yn`: BFGS-refined coordinates
- `close`: Boolean indicating if point is close to boundary
- `steps`: Number of BFGS optimization steps taken
- `converged`: Boolean indicating if BFGS optimization converged

# Hessian Classification (when `enable_hessian=true`)
When enabled, adds comprehensive Hessian-based analysis:
- `critical_point_type`: Classification (:minimum, :maximum, :saddle, :degenerate, :error)
- `smallest_positive_eigenval`: Smallest positive eigenvalue (for minima validation)
- `largest_negative_eigenval`: Largest negative eigenvalue (for maxima validation)
- `hessian_norm`: L2 (Frobenius) norm of Hessian matrix
- `hessian_eigenvalue_min`: Smallest eigenvalue of Hessian matrix
- `hessian_eigenvalue_max`: Largest eigenvalue of Hessian matrix
- `hessian_condition_number`: Condition number κ(H) = |λₘₐₓ|/|λₘᵢₙ|
- `hessian_determinant`: Determinant of Hessian matrix
- `hessian_trace`: Trace of Hessian matrix

# Classification Types
- `:minimum`: All eigenvalues > `hessian_tol_zero` (local minimum)
- `:maximum`: All eigenvalues < -`hessian_tol_zero` (local maximum)
- `:saddle`: Mixed positive and negative eigenvalues (saddle point)
- `:degenerate`: At least one eigenvalue ≈ 0 (degenerate critical point)
- `:error`: Hessian computation failed

# Example
```julia
# Proper initialization
# using Pkg; using Revise 
# Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
# using Globtim; using DynamicPolynomials, DataFrames

# Basic usage with full analysis
# f(x) = x[1]^2 + x[2]^2
# TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=2.0)
# pol = Constructor(TR, 8)
# @polyvar x[1:2]
# crit_pts = solve_polynomial_system(x, 2, 8, pol.coeffs)
# df = process_crit_pts(crit_pts, f, TR)

# Full analysis with Hessian classification
# df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Basic analysis without Hessian (faster for large problems)
# df_basic, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)
```

# Performance Notes
- Basic analysis: O(n × m) where n = number of points, m = dimensions
- Hessian analysis: O(n × m²) for Hessian computation, O(n × m³) for eigenvalues
- Memory usage: Additional O(n × m²) for Hessian storage when `enable_hessian=true`

# Implementation Details
Hessian analysis uses ForwardDiff.jl for automatic differentiation to compute Hessian matrices,
then performs eigenvalue decomposition for critical point classification. All eigenvalue
computations include robust error handling for numerical stability.

See also: `compute_hessians`, `classify_critical_points`, `process_crit_pts`
"""

# ============================================================================
# Helper functions extracted from analyze_critical_points
# ============================================================================

"""
    _refine_critical_points!(df, df_min, f, TR, n_dims; kwargs...)

Run NelderMead optimization from each critical point to find nearby minimizers.
Updates `df` in-place with refined coordinates and populates `df_min` with unique minimizers.
"""
function _refine_critical_points!(
    df::DataFrame, df_min::DataFrame, f, TR::TestInput, n_dims::Int;
    max_iters_in_optim::Int=100, tol_dist::Float64=0.025,
    bfgs_f_abstol::Float64=1e-8, bfgs_x_abstol::Float64=0.0, verbose::Bool=true
)
    for i in 1:nrow(df)
        try
            verbose && println("Processing point $i of $(nrow(df))")
            x0 = [df[i, Symbol("x$j")] for j in 1:n_dims]

            res = Logging.with_logger(Logging.NullLogger()) do
                Optim.optimize(
                    f, x0, Optim.NelderMead(),
                    Optim.Options(show_trace=false, iterations=max_iters_in_optim,
                                  f_tol=bfgs_f_abstol, x_tol=bfgs_x_abstol)
                )
            end

            minimizer = Optim.minimizer(res)
            min_value = Optim.minimum(res)
            steps = res.iterations
            optim_converged = Optim.converged(res)

            within_bounds = if isa(TR.sample_range, Number)
                all(abs.(minimizer .- TR.center[1:n_dims]) .<= TR.sample_range)
            else
                all(abs.(minimizer[j] - TR.center[j]) <= TR.sample_range[j] for j in 1:n_dims)
            end
            converged = optim_converged && within_bounds

            if verbose
                green_check = "\e[32m✓\e[0m"; red_cross = "\e[31m✗\e[0m"
                println(
                    converged ? "Optimization has converged within bounds: $green_check" :
                    "Optimization status: $red_cross" *
                    (optim_converged ? " (outside bounds)" : " (did not converge)")
                )
            end

            for j in 1:n_dims
                df[i, Symbol("y$j")] = minimizer[j]
            end
            df[i, :steps] = steps
            df[i, :converged] = converged

            distance = norm([df[i, Symbol("x$j")] - minimizer[j] for j in 1:n_dims])
            df[i, :close] = distance < tol_dist

            !within_bounds && continue

            # Check if minimizer is unique
            is_new = true
            for j in 1:nrow(df_min)
                if norm([df_min[j, Symbol("x$k")] - minimizer[k] for k in 1:n_dims]) < tol_dist
                    is_new = false
                    break
                end
            end

            if is_new
                is_captured = any(
                    norm([df[k, Symbol("x$j")] - minimizer[j] for j in 1:n_dims]) < tol_dist
                    for k in 1:nrow(df)
                )
                new_row = Dict{Symbol, Any}()
                for j in 1:n_dims
                    new_row[Symbol("x$j")] = minimizer[j]
                end
                new_row[:value] = min_value
                new_row[:captured] = is_captured
                push!(df_min, new_row)
            end
        catch e
            verbose && println("Error processing point $i: $e")
            for j in 1:n_dims
                df[i, Symbol("y$j")] = NaN
            end
            df[i, :close] = false
            df[i, :steps] = -1
            df[i, :converged] = false
        end
    end
end

"""
    _compute_enhanced_statistics!(df, df_min, f, TR, n_dims; kwargs...)

Compute spatial regions, function value clusters, nearest neighbors,
gradient norms, and basin analysis. Updates `df` and `df_min` in-place.
"""
function _compute_enhanced_statistics!(
    df::DataFrame, df_min::DataFrame, f, TR::TestInput, n_dims::Int;
    tol_dist::Float64=0.025, enable_gradient_computation::Bool=true, verbose::Bool=true
)
    verbose && println("\n=== Computing Enhanced Statistics ===")

    verbose && println("Computing spatial regions...")
    df[!, :region_id] = assign_spatial_regions(df, TR)

    verbose && println("Clustering function values...")
    df[!, :function_value_cluster] = cluster_function_values(df.z)

    verbose && println("Computing nearest neighbor distances...")
    df[!, :nearest_neighbor_dist] = compute_nearest_neighbors(df, n_dims)

    if enable_gradient_computation
        verbose && println("Computing gradient norms at critical points...")
        points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
        for i in 1:n_dims
            points_matrix[:, i] = df[!, Symbol("x$i")]
        end
        df[!, :gradient_norm] = compute_gradients(f, points_matrix)
    else
        verbose && println("Gradient computation disabled")
        df[!, :gradient_norm] = fill(NaN, nrow(df))
    end

    if nrow(df_min) > 0
        verbose && println("Analyzing basins of attraction...")
        basin_sizes, avg_steps, region_coverage_counts =
            analyze_basins(df, df_min, n_dims, tol_dist)
        df_min[!, :basin_points] = basin_sizes
        df_min[!, :average_convergence_steps] = avg_steps
        df_min[!, :region_coverage_count] = region_coverage_counts

        verbose && println("Computing gradient norms at minimizers...")
        min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
        for i in 1:n_dims
            min_points[:, i] = df_min[!, Symbol("x$i")]
        end
        df_min[!, :gradient_norm_at_min] = compute_gradients(f, min_points)
    end

    verbose && println("Enhanced statistics computed successfully!")
end

"""
    _compute_hessian_analysis!(df, df_min, f, n_dims; kwargs...)

Compute Hessian matrices, eigenvalues, critical point classification,
and related statistics. Updates `df` and `df_min` in-place.
"""
function _compute_hessian_analysis!(
    df::DataFrame, df_min::DataFrame, f, n_dims::Int;
    hessian_tol_zero::Float64=1e-8, verbose::Bool=true
)
    verbose && println("\n=== Computing Complete Hessian Analysis ===")

    verbose && println("Computing Hessian matrices...")
    points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
    for i in 1:n_dims
        points_matrix[:, i] = df[!, Symbol("x$i")]
    end
    @debug "analyze_critical_points: points_matrix size: $(size(points_matrix))"
    hessians = compute_hessians(f, points_matrix)

    verbose && println("Computing all eigenvalues...")
    all_eigenvalues = store_all_eigenvalues(hessians)

    verbose && println("Classifying critical points...")
    classifications = classify_critical_points(hessians, tol_zero=hessian_tol_zero)
    @debug "analyze_critical_points: Classifications: $classifications"
    df[!, :critical_point_type] = classifications

    verbose && println("Extracting critical eigenvalues...")
    smallest_pos_eigenvals, largest_neg_eigenvals =
        extract_critical_eigenvalues(classifications, all_eigenvalues)
    df[!, :smallest_positive_eigenval] = smallest_pos_eigenvals
    df[!, :largest_negative_eigenval] = largest_neg_eigenvals

    verbose && println("Computing Hessian norms...")
    df[!, :hessian_norm] = compute_hessian_norms(hessians)

    verbose && println("Computing eigenvalue statistics...")
    eigenvalue_stats = compute_eigenvalue_stats(hessians)
    for col in names(eigenvalue_stats)
        df[!, Symbol("hessian_$col")] = eigenvalue_stats[!, col]
    end

    if nrow(df_min) > 0
        verbose && println("Computing Hessian analysis for minimizers...")
        min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
        for i in 1:n_dims
            min_points[:, i] = df_min[!, Symbol("x$i")]
        end
        min_hessians = compute_hessians(f, min_points)
        min_all_eigenvalues = store_all_eigenvalues(min_hessians)
        min_classifications = classify_critical_points(min_hessians, tol_zero=hessian_tol_zero)
        min_smallest_pos, min_largest_neg =
            extract_critical_eigenvalues(min_classifications, min_all_eigenvalues)

        df_min[!, :critical_point_type] = min_classifications
        df_min[!, :smallest_positive_eigenval] = min_smallest_pos
        df_min[!, :largest_negative_eigenval] = min_largest_neg
        df_min[!, :hessian_norm] = compute_hessian_norms(min_hessians)
        min_eigenvalue_stats = compute_eigenvalue_stats(min_hessians)
        for col in names(min_eigenvalue_stats)
            df_min[!, Symbol("hessian_$col")] = min_eigenvalue_stats[!, col]
        end
    end

    verbose && println("Hessian analysis complete!")
end

# ============================================================================

TimerOutputs.@timeit _TO function analyze_critical_points(
    f::Function,
    df::DataFrame,
    TR::TestInput;
    tol_dist = 0.025,
    verbose = true,
    max_iters_in_optim = 100,
    enable_hessian = true,
    enable_gradient_computation = true,
    enable_bfgs_refinement = true,
    hessian_tol_zero = 1e-8,
    bfgs_g_tol = 1e-8,
    bfgs_f_abstol = 1e-8,
    bfgs_x_abstol = 0.0
)
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Initialize result columns
    for i in 1:n_dims
        df[!, Symbol("y$i")] = zeros(nrow(df))
    end
    df[!, :close] = falses(nrow(df))
    df[!, :steps] = zeros(nrow(df))
    df[!, :converged] = falses(nrow(df))

    # Create df_min for collecting unique minimizers
    min_cols = [:value, :captured]
    for i in 1:n_dims
        pushfirst!(min_cols, Symbol("x$i"))
    end
    df_min = DataFrame([name => Float64[] for name in min_cols[1:(end - 1)]])
    df_min[!, :captured] = Bool[]

    # Stage 1: Refinement
    if enable_bfgs_refinement
        _refine_critical_points!(df, df_min, f, TR, n_dims;
            max_iters_in_optim, tol_dist=Float64(tol_dist),
            bfgs_f_abstol=Float64(bfgs_f_abstol), bfgs_x_abstol=Float64(bfgs_x_abstol), verbose)
    else
        verbose && println("BFGS refinement disabled, using raw critical points")
        for i in 1:nrow(df)
            for j in 1:n_dims
                df[i, Symbol("y$j")] = df[i, Symbol("x$j")]
            end
            df[i, :steps] = 0
            df[i, :converged] = false
            df[i, :close] = false
        end
    end

    # Stage 2: Enhanced statistics
    _compute_enhanced_statistics!(df, df_min, f, TR, n_dims;
        tol_dist=Float64(tol_dist), enable_gradient_computation, verbose)

    # Stage 3: Hessian analysis
    if enable_hessian
        _compute_hessian_analysis!(df, df_min, f, n_dims;
            hessian_tol_zero=Float64(hessian_tol_zero), verbose)
    end

    return df, df_min
end

# ================================================================================
# ENHANCED BFGS REFINEMENT FUNCTIONS
# ================================================================================

"""
    determine_convergence_reason(result::Optim.OptimizationResults, tolerance_used::Float64, config::BFGSConfig)

Analyze Optim result to determine why optimization stopped.

# Arguments
- `result`: Optimization result from Optim.jl
- `tolerance_used`: The tolerance that was used
- `config`: BFGSConfig structure

# Returns
- `Symbol`: Convergence reason (:gradient, :f_tol, :x_tol, :iterations, etc.)
"""
function determine_convergence_reason(
    result::Optim.OptimizationResults,
    tolerance_used::Float64,
    config::BFGSConfig
)
    if Optim.converged(result)
        # Check which convergence criterion was met
        if Optim.g_converged(result)
            return :gradient
        elseif Optim.f_converged(result)
            return :f_tol
        elseif Optim.x_converged(result)
            return :x_tol
        else
            return :unknown_convergence
        end
    else
        return :iterations
    end
end

"""
    enhanced_bfgs_refinement(initial_points::Vector{Vector{Float64}},
                           initial_values::Vector{Float64},
                           orthant_labels::Vector{String},
                           objective_function::Function,
                           config::BFGSConfig = BFGSConfig();
                           expected_minimum::Union{Vector{Float64}, Nothing} = nothing)

Perform enhanced BFGS refinement with comprehensive hyperparameter tracking.

# Arguments
- `initial_points`: Vector of starting points for refinement
- `initial_values`: Function values at initial points
- `orthant_labels`: Labels identifying orthants/regions
- `objective_function`: The objective function to minimize
- `config`: BFGSConfig with hyperparameters
- `expected_minimum`: Expected global minimum for distance tracking (optional)

# Returns
- `Vector{BFGSResult}`: Detailed results for each refinement
"""
function enhanced_bfgs_refinement(
    initial_points::Vector{Vector{Float64}},
    initial_values::Vector{Float64},
    orthant_labels::Vector{String},
    objective_function::Function,
    config::BFGSConfig = BFGSConfig();
    expected_minimum::Union{Vector{Float64}, Nothing} = nothing
)

    results = BFGSResult[]

    for (i, (point, value, label)) in
        enumerate(zip(initial_points, initial_values, orthant_labels))
        # Tolerance selection logic
        tolerance_used =
            abs(value) < config.precision_threshold ? config.high_precision_tolerance :
            config.standard_tolerance

        tolerance_reason =
            abs(value) < config.precision_threshold ?
            "high_precision: |f| < $(config.precision_threshold)" :
            "standard: |f| ≥ $(config.precision_threshold)"

        # Time the optimization
        start_time = time()

        # Run optimization with selected parameters (with warning suppression)
        # Using NelderMead (gradient-free) for robustness with expensive objectives
        result = Logging.with_logger(Logging.NullLogger()) do
            Optim.optimize(
                objective_function,
                point,
                Optim.NelderMead(),
                Optim.Options(
                    iterations = config.max_iterations,
                    f_tol = config.f_abs_tol,
                    x_tol = config.x_tol,
                    show_trace = config.show_trace,
                    store_trace = true,
                    extended_trace = true
                )
            )
        end

        optimization_time = time() - start_time

        # Calculate metrics
        refined_point = Optim.minimizer(result)
        refined_value = Optim.minimum(result)
        # Note: NelderMead doesn't compute gradients, so we compute it separately if needed
        grad = try
            ForwardDiff.gradient(objective_function, refined_point)
        catch e
            @warn "Gradient computation failed after refinement" exception=(e, catch_backtrace())
            fill(NaN, length(refined_point))
        end

        # Determine convergence reason
        convergence_reason = determine_convergence_reason(result, tolerance_used, config)

        # Extract call counts
        f_calls = Optim.f_calls(result)
        g_calls = 0  # NelderMead doesn't use gradients

        # Calculate distance to expected minimum if provided
        distance_to_expected =
            expected_minimum === nothing ? NaN : norm(refined_point - expected_minimum)

        # Create enhanced result
        bfgs_result = BFGSResult(
            point,
            refined_point,
            value,
            refined_value,
            Optim.converged(result),
            Optim.iterations(result),
            f_calls,
            g_calls,
            convergence_reason,
            config,
            tolerance_used,
            tolerance_reason,
            norm(grad),
            norm(refined_point - point),
            abs(refined_value - value),
            label,
            distance_to_expected,
            optimization_time
        )

        push!(results, bfgs_result)

        # Display progress if verbose
        if config.track_hyperparameters
            println("\nPoint $i/$(length(initial_points)) - Orthant: $label")
            println("  Tolerance used: $tolerance_used ($tolerance_reason)")
            println("  Converged: $(Optim.converged(result)) (reason: $convergence_reason)")
            println(
                "  Iterations: $(bfgs_result.iterations_used), f_calls: $f_calls, g_calls: $g_calls"
            )
            println(
                "  Value improvement: $(round(bfgs_result.value_improvement, sigdigits=3))"
            )
            println(
                "  Final gradient norm: $(round(bfgs_result.final_grad_norm, sigdigits=3))"
            )
            println("  Time: $(round(optimization_time, digits=3))s")
        end
    end

    return results
end

"""
    refine_with_enhanced_bfgs(df::DataFrame, objective_function::Function,
                             config::BFGSConfig = BFGSConfig();
                             expected_minima::Union{Vector{Vector{Float64}}, Nothing} = nothing)

Apply enhanced BFGS refinement to critical points in a DataFrame.

# Arguments
- `df`: DataFrame with critical points (columns x1, x2, ..., z)
- `objective_function`: The objective function
- `config`: BFGSConfig with hyperparameters
- `expected_minima`: Known global minima for comparison (optional)

# Returns
- `DataFrame`: Enhanced DataFrame with BFGS refinement results
"""
function refine_with_enhanced_bfgs(
    df::DataFrame,
    objective_function::Function,
    config::BFGSConfig = BFGSConfig();
    expected_minima::Union{Vector{Vector{Float64}}, Nothing} = nothing
)

    # Extract dimension
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Prepare data for refinement
    initial_points = Vector{Vector{Float64}}()
    initial_values = Float64[]
    orthant_labels = String[]

    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:n_dims]
        push!(initial_points, point)
        push!(initial_values, df[i, :z])

        # Create orthant label based on signs
        label = join([p >= 0 ? "+" : "-" for p in point])
        push!(orthant_labels, label)
    end

    # Find closest expected minimum for each point if provided
    expected_minimum = nothing
    if expected_minima !== nothing && !isempty(expected_minima)
        # For simplicity, use the first expected minimum
        # In practice, you might want to find the closest one
        expected_minimum = expected_minima[1]
    end

    # Run enhanced refinement
    results = enhanced_bfgs_refinement(
        initial_points,
        initial_values,
        orthant_labels,
        objective_function,
        config;
        expected_minimum = expected_minimum
    )

    # Add results to DataFrame
    df[!, :tolerance_used] = [r.tolerance_used for r in results]
    df[!, :tolerance_reason] = [r.tolerance_selection_reason for r in results]
    df[!, :convergence_reason] = [r.convergence_reason for r in results]
    df[!, :iterations_used] = [r.iterations_used for r in results]
    df[!, :f_calls] = [r.f_calls for r in results]
    df[!, :g_calls] = [r.g_calls for r in results]
    df[!, :final_grad_norm] = [r.final_grad_norm for r in results]
    df[!, :point_improvement] = [r.point_improvement for r in results]
    df[!, :value_improvement] = [r.value_improvement for r in results]
    df[!, :optimization_time] = [r.optimization_time for r in results]

    if expected_minimum !== nothing
        df[!, :distance_to_expected] = [r.distance_to_expected for r in results]
    end

    # Add refined coordinates
    for i in 1:nrow(df)
        for j in 1:n_dims
            df[i, Symbol("y$j")] = results[i].refined_point[j]
        end
        df[i, :refined_value] = results[i].refined_value
    end

    return df
end

# Export enhanced BFGS functions
export enhanced_bfgs_refinement, refine_with_enhanced_bfgs, determine_convergence_reason

"""
    detect_distinct_local_minima(
        points::Matrix{Float64},
        objective_values::Vector{Float64},
        classifications::Vector{Symbol};
        distance_threshold::Float64 = 1e-3,
        objective_threshold::Float64 = 1e-6
    )

Identify distinct local minima using spatial+objective clustering.

Only points classified as `:minimum` are considered. Points are grouped into
clusters based on spatial proximity AND objective value similarity. Returns
one representative per cluster (the point with lowest objective value).

# Arguments
- `points`: Matrix where each row is a point (n_points × n_dims)
- `objective_values`: Objective function values at each point
- `classifications`: Critical point classifications (from classify_critical_points)
- `distance_threshold`: Spatial proximity threshold (Euclidean distance)
- `objective_threshold`: Objective value similarity threshold

# Returns
NamedTuple with:
- `n_distinct_minima`: Number of unique local minima clusters
- `cluster_representatives`: Indices of representative points (best in each cluster)
- `cluster_sizes`: Number of points in each cluster
- `representative_objectives`: Objective values of representatives
"""
function detect_distinct_local_minima(
    points::Matrix{Float64},
    objective_values::Vector{Float64},
    classifications::Vector{Symbol};
    distance_threshold::Float64 = 1e-3,
    objective_threshold::Float64 = 1e-6
)
    # Filter for minima only
    minima_indices = findall(c -> c == :minimum, classifications)

    if isempty(minima_indices)
        return (
            n_distinct_minima = 0,
            cluster_representatives = Int[],
            cluster_sizes = Int[],
            representative_objectives = Float64[]
        )
    end

    minima_points = points[minima_indices, :]
    minima_objectives = objective_values[minima_indices]
    n_minima = length(minima_indices)

    # Simple greedy clustering algorithm
    clusters = Vector{Vector{Int}}()
    used = Set{Int}()

    for i in 1:n_minima
        if i ∈ used
            continue
        end

        # Start new cluster with point i
        cluster = [i]
        push!(used, i)

        # Find all points that should be in same cluster
        for j in (i+1):n_minima
            if j ∈ used
                continue
            end

            # Check spatial proximity AND objective similarity
            spatial_dist = norm(minima_points[i, :] - minima_points[j, :])
            objective_diff = abs(minima_objectives[i] - minima_objectives[j])

            if spatial_dist < distance_threshold && objective_diff < objective_threshold
                push!(cluster, j)
                push!(used, j)
            end
        end

        push!(clusters, cluster)
    end

    # Find representative (best objective) for each cluster
    representatives = Int[]
    cluster_sizes = Int[]
    representative_objs = Float64[]

    for cluster in clusters
        # Get index within minima_indices that has best objective
        local_best_idx = argmin([minima_objectives[k] for k in cluster])
        # Convert back to original point index
        global_idx = minima_indices[cluster[local_best_idx]]

        push!(representatives, global_idx)
        push!(cluster_sizes, length(cluster))
        push!(representative_objs, objective_values[global_idx])
    end

    return (
        n_distinct_minima = length(clusters),
        cluster_representatives = representatives,
        cluster_sizes = cluster_sizes,
        representative_objectives = representative_objs
    )
end

# Export functions used by other modules
export compute_gradients, analyze_basins, detect_distinct_local_minima
