# Valley Detection and Manifold Following
#
# This module implements algorithms for detecting and following valleys (positive dimensional
# regions of local minimizers) in optimization landscapes using Hessian rank deficiency analysis.

using LinearAlgebra
using ForwardDiff

"""
    ValleyDetectionConfig

Configuration parameters for valley detection algorithm.

# Fields
- `zero_eigenvalue_threshold::Float64`: Threshold below which eigenvalues are considered zero (default: 1e-6)
- `manifold_step_size::Float64`: Step size for manifold following (default: 1e-4, very small!)
- `max_manifold_steps::Int`: Maximum steps when following manifold (default: 1000)
- `gradient_tolerance::Float64`: Tolerance for gradient norm in valley (default: 1e-8)
- `hessian_condition_threshold::Float64`: Threshold for detecting ill-conditioned Hessian (default: 1e12)
- `valley_width_factor::Float64`: Factor for determining valley width from eigenvalues (default: 3.0)
- `function_value_tolerance::Float64`: Maximum allowed increase in function value (default: 1e-10)
- `function_value_decrease_required::Bool`: Require function value to decrease or stay same (default: true)
- `adaptive_step_reduction::Float64`: Factor to reduce step size if function value increases (default: 0.5)
- `min_step_size::Float64`: Minimum allowed step size before giving up (default: 1e-12)
"""
struct ValleyDetectionConfig
    zero_eigenvalue_threshold::Float64
    manifold_step_size::Float64
    max_manifold_steps::Int
    gradient_tolerance::Float64
    hessian_condition_threshold::Float64
    valley_width_factor::Float64
    function_value_tolerance::Float64
    function_value_decrease_required::Bool
    adaptive_step_reduction::Float64
    min_step_size::Float64
    
    function ValleyDetectionConfig(;
        zero_eigenvalue_threshold::Float64 = 1e-6,
        manifold_step_size::Float64 = 1e-4,  # Very small steps!
        max_manifold_steps::Int = 1000,      # More steps since they're smaller
        gradient_tolerance::Float64 = 1e-8,
        hessian_condition_threshold::Float64 = 1e12,
        valley_width_factor::Float64 = 3.0,
        function_value_tolerance::Float64 = 1e-10,  # Very strict
        function_value_decrease_required::Bool = true,
        adaptive_step_reduction::Float64 = 0.5,
        min_step_size::Float64 = 1e-12
    )
        new(zero_eigenvalue_threshold, manifold_step_size, max_manifold_steps, 
            gradient_tolerance, hessian_condition_threshold, valley_width_factor,
            function_value_tolerance, function_value_decrease_required, 
            adaptive_step_reduction, min_step_size)
    end
end

"""
    ValleyInfo

Information about a detected valley at a critical point.

# Fields
- `point::Vector{Float64}`: The critical point location
- `is_valley::Bool`: Whether this point is in a valley (rank-deficient Hessian)
- `valley_dimension::Int`: Dimension of the valley (number of near-zero eigenvalues)
- `eigenvalues::Vector{Float64}`: All Hessian eigenvalues
- `nullspace_vectors::Matrix{Float64}`: Approximate nullspace vectors (columns)
- `valley_directions::Matrix{Float64}`: Primary valley directions
- `valley_width::Float64`: Estimated width of valley in transverse directions
- `manifold_score::Float64`: Score indicating strength of manifold evidence (0-1)
"""
struct ValleyInfo
    point::Vector{Float64}
    is_valley::Bool
    valley_dimension::Int
    eigenvalues::Vector{Float64}
    nullspace_vectors::Matrix{Float64}
    valley_directions::Matrix{Float64}
    valley_width::Float64
    manifold_score::Float64
end

"""
    detect_valley_at_point(f, x, config::ValleyDetectionConfig = ValleyDetectionConfig())

Detect if a critical point lies in a valley (positive dimensional minimizer set).

Uses Hessian eigenvalue analysis to determine if the point lies on a manifold of
critical points. A valley is detected when the Hessian has eigenvalues close to zero,
indicating rank deficiency.

# Arguments
- `f`: Objective function
- `x::Vector{Float64}`: Point to analyze
- `config::ValleyDetectionConfig`: Detection configuration

# Returns
- `ValleyInfo`: Comprehensive information about valley detection

# Algorithm
1. Compute Hessian matrix at the point
2. Perform eigenvalue decomposition
3. Identify near-zero eigenvalues (below threshold)
4. Extract nullspace/valley directions
5. Estimate valley width from transverse eigenvalues
6. Compute manifold strength score

# Examples
```julia
f = x -> x[1]^4 + x[2]^2  # Valley along x[1] = 0
valley_info = detect_valley_at_point(f, [0.0, 0.0])
println("Valley dimension: ", valley_info.valley_dimension)
println("Valley directions: ", valley_info.valley_directions)
```
"""
function detect_valley_at_point(f, x::Vector{Float64}, config::ValleyDetectionConfig = ValleyDetectionConfig())
    # Compute gradient and Hessian
    grad = ForwardDiff.gradient(f, x)
    hessian = ForwardDiff.hessian(f, x)
    
    # Check if we're actually at a critical point
    grad_norm = norm(grad)
    if grad_norm > config.gradient_tolerance
        @warn "Point may not be a critical point (||∇f|| = $grad_norm > $(config.gradient_tolerance))"
    end
    
    # Eigenvalue decomposition of Hessian
    eigen_decomp = eigen(hessian)
    eigenvalues = eigen_decomp.values
    eigenvectors = eigen_decomp.vectors
    
    # Sort eigenvalues by magnitude (smallest first)
    sorted_indices = sortperm(abs.(eigenvalues))
    sorted_eigenvalues = eigenvalues[sorted_indices]
    sorted_eigenvectors = eigenvectors[:, sorted_indices]
    
    # Detect near-zero eigenvalues (valley directions)
    near_zero_mask = abs.(sorted_eigenvalues) .< config.zero_eigenvalue_threshold
    valley_dimension = sum(near_zero_mask)
    
    # Extract nullspace vectors (eigenvectors corresponding to near-zero eigenvalues)
    if valley_dimension > 0
        nullspace_vectors = sorted_eigenvectors[:, near_zero_mask]
        valley_directions = nullspace_vectors
        
        # Estimate valley width from smallest non-zero eigenvalue
        non_zero_eigenvalues = sorted_eigenvalues[.!near_zero_mask]
        if length(non_zero_eigenvalues) > 0
            min_nonzero_eigenval = minimum(abs.(non_zero_eigenvalues))
            valley_width = config.valley_width_factor / sqrt(abs(min_nonzero_eigenval))
        else
            valley_width = Inf  # Completely flat
        end
        
        # Compute manifold score based on eigenvalue gap
        if length(non_zero_eigenvalues) > 0
            eigenvalue_gap = minimum(abs.(non_zero_eigenvalues)) / maximum(abs.(sorted_eigenvalues[near_zero_mask]))
            manifold_score = min(1.0, log10(max(eigenvalue_gap, 1.0)) / 6.0)  # Scale to [0,1]
        else
            manifold_score = 1.0
        end
        
        is_valley = true
    else
        nullspace_vectors = zeros(Float64, length(x), 0)
        valley_directions = zeros(Float64, length(x), 0)
        valley_width = 0.0
        manifold_score = 0.0
        is_valley = false
    end
    
    return ValleyInfo(
        copy(x),
        is_valley,
        valley_dimension,
        sorted_eigenvalues,
        nullspace_vectors,
        valley_directions,
        valley_width,
        manifold_score
    )
end

"""
    follow_valley_manifold(f, valley_info::ValleyInfo, config::ValleyDetectionConfig = ValleyDetectionConfig())

Follow the valley manifold from a detected valley point.

Starting from a point known to be in a valley, this function traces the manifold
by taking steps in the nullspace directions while maintaining the critical point
condition ∇f = 0.

# Arguments
- `f`: Objective function
- `valley_info::ValleyInfo`: Valley information from detect_valley_at_point
- `config::ValleyDetectionConfig`: Configuration parameters

# Returns
- `Vector{Vector{Float64}}`: Sequence of points along the valley manifold
- `Vector{ValleyInfo}`: Valley information at each traced point

# Algorithm
1. Start from the valley point
2. Choose a direction in the nullspace
3. Take a small step in that direction
4. Project back to the critical point manifold using Newton's method
5. Verify we're still in a valley
6. Repeat until convergence or max steps

# Examples
```julia
f = x -> x[1]^4 + x[2]^2  # Valley along x[1] = 0
valley_info = detect_valley_at_point(f, [0.0, 0.0])
if valley_info.is_valley
    manifold_points, manifold_infos = follow_valley_manifold(f, valley_info)
    println("Traced $(length(manifold_points)) points along valley")
end
```
"""
function follow_valley_manifold(f, valley_info::ValleyInfo, config::ValleyDetectionConfig = ValleyDetectionConfig())
    if !valley_info.is_valley
        @warn "Point is not in a valley - cannot follow manifold"
        return [valley_info.point], [valley_info]
    end
    
    manifold_points = [copy(valley_info.point)]
    manifold_infos = [valley_info]
    
    current_point = copy(valley_info.point)
    
    # Choose primary valley direction (first nullspace vector)
    if size(valley_info.valley_directions, 2) == 0
        @warn "No valley directions available"
        return manifold_points, manifold_infos
    end
    
    direction = valley_info.valley_directions[:, 1]
    step_size = config.manifold_step_size
    
    for step in 1:config.max_manifold_steps
        # Take step in valley direction
        candidate_point = current_point + step_size * direction
        
        # Project back to critical point manifold using Newton-Raphson
        projected_point = project_to_critical_manifold(f, candidate_point, config)
        
        # Check if projection was successful and we're still in domain
        if isnothing(projected_point)
            @debug "Manifold following terminated: projection failed at step $step"
            break
        end
        
        # Detect valley at new point
        new_valley_info = detect_valley_at_point(f, projected_point, config)
        
        # Check if we're still in a valley of same dimension
        if !new_valley_info.is_valley || new_valley_info.valley_dimension != valley_info.valley_dimension
            @debug "Manifold following terminated: left valley at step $step"
            break
        end
        
        # Update for next iteration
        current_point = projected_point
        push!(manifold_points, copy(current_point))
        push!(manifold_infos, new_valley_info)
        
        # Update direction based on new valley information
        if size(new_valley_info.valley_directions, 2) > 0
            # Choose direction that's most aligned with previous direction
            new_directions = new_valley_info.valley_directions
            alignments = abs.(new_directions' * direction)
            best_idx = argmax(alignments)
            direction = new_directions[:, best_idx]
            
            # Ensure consistent orientation
            if dot(direction, manifold_points[end] - manifold_points[end-1]) < 0
                direction = -direction
            end
        end
        
        # Adaptive step size based on valley width
        step_size = min(config.manifold_step_size, new_valley_info.valley_width / 10)
    end
    
    return manifold_points, manifold_infos
end

"""
    project_to_critical_manifold(f, x, config::ValleyDetectionConfig, max_iterations::Int = 10)

Project a point to the nearest critical point using Newton-Raphson method.

# Arguments
- `f`: Objective function
- `x::Vector{Float64}`: Starting point
- `config::ValleyDetectionConfig`: Configuration parameters
- `max_iterations::Int`: Maximum Newton iterations

# Returns
- `Vector{Float64}` or `nothing`: Projected critical point, or nothing if failed
"""
function project_to_critical_manifold(f, x::Vector{Float64}, config::ValleyDetectionConfig, max_iterations::Int = 10)
    current_x = copy(x)
    
    for iter in 1:max_iterations
        grad = ForwardDiff.gradient(f, current_x)
        grad_norm = norm(grad)
        
        # Check convergence
        if grad_norm < config.gradient_tolerance
            return current_x
        end
        
        # Newton step: x_{k+1} = x_k - H^{-1} * ∇f
        hessian = ForwardDiff.hessian(f, current_x)
        
        # Check for numerical issues
        if cond(hessian) > config.hessian_condition_threshold
            @debug "Hessian is ill-conditioned during projection"
            return nothing
        end
        
        try
            newton_step = hessian \ grad
            current_x = current_x - newton_step
        catch e
            @debug "Newton step failed during projection: $e"
            return nothing
        end
    end
    
    @debug "Newton method did not converge in projection"
    return nothing
end

"""
    analyze_valleys_in_critical_points(f, df::DataFrame, config::ValleyDetectionConfig = ValleyDetectionConfig())

Analyze all critical points in a DataFrame for valley detection.

Extends the existing critical point analysis to include valley detection information.

# Arguments
- `f`: Objective function
- `df::DataFrame`: DataFrame of critical points (from process_crit_pts)
- `config::ValleyDetectionConfig`: Valley detection configuration

# Returns
- `DataFrame`: Enhanced DataFrame with valley analysis columns

# New Columns Added
- `is_valley::Bool`: Whether point is in a valley
- `valley_dimension::Int`: Dimension of valley (0 if not in valley)
- `manifold_score::Float64`: Strength of manifold evidence (0-1)
- `valley_width::Float64`: Estimated valley width
- `smallest_eigenvalue::Float64`: Smallest Hessian eigenvalue magnitude
- `eigenvalue_gap::Float64`: Gap between zero and non-zero eigenvalues
"""
function analyze_valleys_in_critical_points(f, df::DataFrame, config::ValleyDetectionConfig = ValleyDetectionConfig())
    # Create enhanced dataframe
    df_enhanced = copy(df)
    n_points = nrow(df)
    
    # Initialize new columns
    df_enhanced[!, :is_valley] = fill(false, n_points)
    df_enhanced[!, :valley_dimension] = fill(0, n_points)
    df_enhanced[!, :manifold_score] = fill(0.0, n_points)
    df_enhanced[!, :valley_width] = fill(0.0, n_points)
    df_enhanced[!, :smallest_eigenvalue] = fill(0.0, n_points)
    df_enhanced[!, :eigenvalue_gap] = fill(0.0, n_points)
    
    # Analyze each critical point
    for i in 1:n_points
        # Extract point coordinates
        x_cols = filter(name -> startswith(string(name), "x_"), names(df))
        x = [df[i, col] for col in x_cols]
        
        # Detect valley
        valley_info = detect_valley_at_point(f, x, config)
        
        # Store results
        df_enhanced[i, :is_valley] = valley_info.is_valley
        df_enhanced[i, :valley_dimension] = valley_info.valley_dimension
        df_enhanced[i, :manifold_score] = valley_info.manifold_score
        df_enhanced[i, :valley_width] = valley_info.valley_width
        df_enhanced[i, :smallest_eigenvalue] = length(valley_info.eigenvalues) > 0 ? 
            minimum(abs.(valley_info.eigenvalues)) : 0.0
        
        # Compute eigenvalue gap
        if valley_info.is_valley && length(valley_info.eigenvalues) > valley_info.valley_dimension
            zero_eigenvals = abs.(valley_info.eigenvalues[1:valley_info.valley_dimension])
            nonzero_eigenvals = abs.(valley_info.eigenvalues[valley_info.valley_dimension+1:end])
            if length(nonzero_eigenvals) > 0
                df_enhanced[i, :eigenvalue_gap] = minimum(nonzero_eigenvals) / maximum(zero_eigenvals)
            end
        end
    end
    
    return df_enhanced
end

"""
    create_valley_test_function()

Create a test function with a known valley structure for validation.

Returns a function f(x) = x[1]^4 + x[2]^2 which has a valley along the line x[1] = 0.
All points (0, y) for any y are critical points with the same function value.

# Returns
- `Function`: Test function with valley structure
- `Function`: Analytical valley description function
"""
function create_valley_test_function()
    # Valley function: f(x,y) = x^4 + y^2
    # Valley along x = 0 (1-dimensional manifold of minima)
    f = x -> x[1]^4 + x[2]^2
    
    # Analytical valley description: points (0, y) are all minima
    valley_points = y -> [0.0, y]
    
    return f, valley_points
end

"""
    create_ridge_test_function()

Create a test function with a ridge structure (1D manifold of maxima).

Returns a function f(x) = -(x[1]^4 + x[2]^2) which has a ridge along x[1] = 0.

# Returns
- `Function`: Test function with ridge structure
- `Function`: Analytical ridge description function
"""
function create_ridge_test_function()
    # Ridge function: f(x,y) = -(x^4 + y^2)
    # Ridge along x = 0 (1-dimensional manifold of maxima)
    f = x -> -(x[1]^4 + x[2]^2)
    
    # Analytical ridge description: points (0, y) are all maxima
    ridge_points = y -> [0.0, y]
    
    return f, ridge_points
end