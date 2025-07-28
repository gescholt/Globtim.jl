# Sasha: This files seems not Revise-able.

# Import ForwardDiff for enhanced BFGS functionality
using ForwardDiff

"""
    assign_spatial_regions(df::DataFrame, TR::test_input, n_regions_per_dim::Int=5)::Vector{Int}

Assign spatial region IDs to critical points for convergence analysis.

Divides the domain into n_regions_per_dim^n cubic regions and assigns each point
to its corresponding region for spatial statistics computation.

# Returns
Vector{Int}: Region ID (1 to n_regions_per_dim^n) for each point in df
"""
function assign_spatial_regions(
    df::DataFrame,
    TR::test_input,
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
    compute_gradients(f::Function, points::Matrix{Float64})::Vector{Float64}

Compute gradient norms at specified points using automatic differentiation.

# Arguments
- f: Function to differentiate
- points: Matrix where each row is a point (n_points × n_dims)

# Returns
Vector{Float64}: ||∇f(x)|| for each point
"""
function compute_gradients(f::Function, points::Matrix{Float64})::Vector{Float64}
    n_points, n_dims = size(points)
    grad_norms = Vector{Float64}(undef, n_points)

    for i in 1:n_points
        try
            point = points[i, :]
            grad = ForwardDiff.gradient(f, point)
            grad_norms[i] = norm(grad)
        catch e
            # Fallback for points where gradient computation fails
            grad_norms[i] = NaN
        end
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
    analyze_critical_points(f::Function, df::DataFrame, TR::test_input; kwargs...)

Comprehensive critical point analysis with enhanced statistics and optional Hessian-based classification.

This function performs detailed analysis of critical points found by polynomial approximation, including:
- BFGS refinement of critical points
- Clustering and proximity analysis
- Enhanced statistical measures
- Optional Hessian-based classification and eigenvalue analysis

# Arguments
- `f::Function`: The objective function to analyze
- `df::DataFrame`: DataFrame containing critical points with columns x1, x2, ..., xn, z
- `TR::test_input`: Test input specification containing domain information

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
# TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=2.0)
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
TimerOutputs.@timeit _TO function analyze_critical_points(
    f::Function,
    df::DataFrame,
    TR::test_input;
    tol_dist = 0.025,
    verbose = true,
    max_iters_in_optim = 100,
    enable_hessian = true,
    hessian_tol_zero = 1e-8,
    bfgs_g_tol = 1e-8,
    bfgs_f_abstol = 1e-8,
    bfgs_x_abstol = 0.0
)
    n_dims = count(col -> startswith(string(col), "x"), names(df))  # Count x-columns

    # ANSI escape codes for colored output
    green_check = "\e[32m✓\e[0m"
    red_cross = "\e[31m✗\e[0m"

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

    for i in 1:nrow(df)
        try
            verbose && println("Processing point $i of $(nrow(df))")

            # Extract starting point
            x0 = [df[i, Symbol("x$j")] for j in 1:n_dims]

            # Optimization
            res = Optim.optimize(
                f,
                x0,
                Optim.BFGS(),
                Optim.Options(
                    show_trace = false,
                    f_calls_limit = max_iters_in_optim,
                    g_tol = bfgs_g_tol,
                    f_abstol = bfgs_f_abstol,
                    x_abstol = bfgs_x_abstol
                )
                # https://discourse.julialang.org/t/how-to-properly-specify-maximum-interations-in-optimization/109144/5
            )

            minimizer = Optim.minimizer(res)
            min_value = Optim.minimum(res)
            steps = res.iterations
            optim_converged = Optim.converged(res)

            # Check if minimizer is within bounds - handle both scalar and vector scaling
            within_bounds = if isa(TR.sample_range, Number)
                # Scalar sample_range case
                all(abs.(minimizer .- TR.center[1:n_dims]) .<= TR.sample_range)
            else
                # Vector sample_range case
                all(abs.(minimizer[j] - TR.center[j]) <= TR.sample_range[j] for j in 1:n_dims)
            end

            # Only mark as converged if both optimization converged AND within bounds
            converged = optim_converged && within_bounds

            # Print status with appropriate symbol
            if verbose
                println(
                    converged ? "Optimization has converged within bounds: $green_check" :
                    "Optimization status: $red_cross" *
                    (optim_converged ? " (outside bounds)" : " (did not converge)")
                )
            end

            # Update df results
            for j in 1:n_dims
                df[i, Symbol("y$j")] = minimizer[j]
            end
            df[i, :steps] = steps
            df[i, :converged] = converged  # Updated to use new converged status

            # Check if minimizer is close to starting point
            distance = norm([df[i, Symbol("x$j")] - minimizer[j] for j in 1:n_dims])
            df[i, :close] = distance < tol_dist

            # Skip adding to df_min if outside bounds
            !within_bounds && continue

            # Check if the minimizer is new
            is_new = true
            for j in 1:nrow(df_min)
                if norm([df_min[j, Symbol("x$k")] - minimizer[k] for k in 1:n_dims]) <
                   tol_dist
                    is_new = false
                    break
                end
            end

            # Add new unique minimizer
            if is_new
                # Check if minimizer is captured by any initial point
                is_captured = any(
                    norm([df[k, Symbol("x$j")] - minimizer[j] for j in 1:n_dims]) < tol_dist
                    for k in 1:nrow(df)
                )

                # Create new row for df_min
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
            # Handle errors in df
            for j in 1:n_dims
                df[i, Symbol("y$j")] = NaN
            end
            df[i, :close] = false
            df[i, :steps] = -1
            df[i, :converged] = false
        end
    end

    # === Enhanced Statistics Collection ===
    if verbose
        println("\n=== Computing Enhanced Statistics ===")
    end

    # 1. Spatial region analysis
    if verbose
        println("Computing spatial regions...")
    end
    region_ids = assign_spatial_regions(df, TR)
    df[!, :region_id] = region_ids

    # 2. Function value clustering  
    if verbose
        println("Clustering function values...")
    end
    cluster_ids = cluster_function_values(df.z)
    df[!, :function_value_cluster] = cluster_ids

    # 3. Nearest neighbor distances
    if verbose
        println("Computing nearest neighbor distances...")
    end
    nn_distances = compute_nearest_neighbors(df, n_dims)
    df[!, :nearest_neighbor_dist] = nn_distances

    # 4. Gradient norms at critical points
    if verbose
        println("Computing gradient norms at critical points...")
    end
    points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
    for i in 1:n_dims
        points_matrix[:, i] = df[!, Symbol("x$i")]
    end
    grad_norms = compute_gradients(f, points_matrix)
    df[!, :gradient_norm] = grad_norms

    # 5. Basin analysis for df_min (only if we have minimizers)
    if nrow(df_min) > 0
        if verbose
            println("Analyzing basins of attraction...")
        end
        basin_sizes, avg_steps, region_coverage_counts =
            analyze_basins(df, df_min, n_dims, tol_dist)
        df_min[!, :basin_points] = basin_sizes
        df_min[!, :average_convergence_steps] = avg_steps
        df_min[!, :region_coverage_count] = region_coverage_counts

        # 6. Gradient norms at minimizers
        if verbose
            println("Computing gradient norms at minimizers...")
        end
        min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
        for i in 1:n_dims
            min_points[:, i] = df_min[!, Symbol("x$i")]
        end
        min_grad_norms = compute_gradients(f, min_points)
        df_min[!, :gradient_norm_at_min] = min_grad_norms
    end

    if verbose
        println("Enhanced statistics computed successfully!")
        println(
            "New df columns: region_id, function_value_cluster, nearest_neighbor_dist, gradient_norm"
        )
        if nrow(df_min) > 0
            println(
                "New df_min columns: basin_points, average_convergence_steps, region_coverage_count, gradient_norm_at_min"
            )
        end
    end

    # === Complete Hessian Analysis ===
    if enable_hessian
        if verbose
            println("\n=== Computing Complete Hessian Analysis ===")
        end

        # 1. Compute Hessian matrices at critical points
        if verbose
            println("Computing Hessian matrices...")
        end
        points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
        for i in 1:n_dims
            points_matrix[:, i] = df[!, Symbol("x$i")]
        end
        @debug "analyze_critical_points: points_matrix size: $(size(points_matrix))"
        @debug "analyze_critical_points: First few points: $(points_matrix[1:min(3, nrow(df)), :])"
        hessians = compute_hessians(f, points_matrix)

        # 2. Store all eigenvalues
        if verbose
            println("Computing all eigenvalues...")
        end
        all_eigenvalues = store_all_eigenvalues(hessians)

        # 3. Classify critical points
        if verbose
            println("Classifying critical points...")
        end
        classifications = classify_critical_points(hessians, tol_zero = hessian_tol_zero)
        @debug "analyze_critical_points: Classifications: $classifications"
        @debug "analyze_critical_points: Classification counts: $([(c, count(==(c), classifications)) for c in unique(classifications)])"
        df[!, :critical_point_type] = classifications

        # 4. Extract critical eigenvalues for minima/maxima
        if verbose
            println("Extracting critical eigenvalues...")
        end
        smallest_pos_eigenvals, largest_neg_eigenvals =
            extract_critical_eigenvalues(classifications, all_eigenvalues)
        df[!, :smallest_positive_eigenval] = smallest_pos_eigenvals
        df[!, :largest_negative_eigenval] = largest_neg_eigenvals

        # 5. Compute Hessian norms
        if verbose
            println("Computing Hessian norms...")
        end
        hessian_norms = compute_hessian_norms(hessians)
        df[!, :hessian_norm] = hessian_norms

        # 6. Compute standard eigenvalue statistics
        if verbose
            println("Computing eigenvalue statistics...")
        end
        eigenvalue_stats = compute_eigenvalue_stats(hessians)
        for col in names(eigenvalue_stats)
            df[!, Symbol("hessian_$col")] = eigenvalue_stats[!, col]
        end

        # 7. Hessian analysis for minimizers (if any)
        if nrow(df_min) > 0
            if verbose
                println("Computing Hessian analysis for minimizers...")
            end
            min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
            for i in 1:n_dims
                min_points[:, i] = df_min[!, Symbol("x$i")]
            end
            min_hessians = compute_hessians(f, min_points)
            min_all_eigenvalues = store_all_eigenvalues(min_hessians)
            min_classifications =
                classify_critical_points(min_hessians, tol_zero = hessian_tol_zero)
            min_smallest_pos, min_largest_neg =
                extract_critical_eigenvalues(min_classifications, min_all_eigenvalues)
            min_hessian_norms = compute_hessian_norms(min_hessians)
            min_eigenvalue_stats = compute_eigenvalue_stats(min_hessians)

            df_min[!, :critical_point_type] = min_classifications
            df_min[!, :smallest_positive_eigenval] = min_smallest_pos
            df_min[!, :largest_negative_eigenval] = min_largest_neg
            df_min[!, :hessian_norm] = min_hessian_norms
            for col in names(min_eigenvalue_stats)
                df_min[!, Symbol("hessian_$col")] = min_eigenvalue_stats[!, col]
            end
        end

        if verbose
            println("Hessian analysis complete!")
            println(
                "New df columns: critical_point_type, smallest_positive_eigenval, largest_negative_eigenval, hessian_norm, hessian_*"
            )
            if nrow(df_min) > 0
                println("New df_min columns: same Hessian-based columns as df")
            end
        end
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

        # Run BFGS with selected parameters
        result = Optim.optimize(
            objective_function,
            point,
            Optim.BFGS(),
            Optim.Options(
                iterations = config.max_iterations,
                g_tol = tolerance_used,
                f_abstol = config.f_abs_tol,
                x_abstol = config.x_tol,
                show_trace = config.show_trace,
                store_trace = true,
                extended_trace = true
            )
        )

        optimization_time = time() - start_time

        # Calculate metrics
        refined_point = Optim.minimizer(result)
        refined_value = Optim.minimum(result)
        grad = ForwardDiff.gradient(objective_function, refined_point)

        # Determine convergence reason
        convergence_reason = determine_convergence_reason(result, tolerance_used, config)

        # Extract call counts
        f_calls = Optim.f_calls(result)
        g_calls = Optim.g_calls(result)

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

# Export functions used by other modules
export compute_gradients, analyze_basins
