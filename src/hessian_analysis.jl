# Phase 2: Hessian-Based Critical Point Classification
# Core functions for computing and analyzing Hessian matrices

using ForwardDiff
using LinearAlgebra
using DataFrames

"""
    compute_hessians(f::Function, points::Matrix{Float64})::Vector{Matrix{Float64}}

Compute Hessian matrices at specified points using ForwardDiff automatic differentiation.

# Arguments
- f: Objective function to analyze
- points: Matrix where each row is a point (n_points × n_dims)

# Returns
Vector{Matrix{Float64}}: Hessian matrix for each point
"""
function compute_hessians(f::Function, points::Matrix{Float64})::Vector{Matrix{Float64}}
    n_points, n_dims = size(points)
    hessians = Vector{Matrix{Float64}}(undef, n_points)
    
    for i = 1:n_points
        try
            point = points[i, :]
            @debug "Computing Hessian for point $i: $point"
            H = ForwardDiff.hessian(f, point)
            @debug "Point $i Hessian computed successfully: size=$(size(H)), det=$(det(H))"
            hessians[i] = H
        catch e
            @debug "Point $i: Hessian computation failed with error: $e"
            # Fallback for points where Hessian computation fails
            hessians[i] = fill(NaN, n_dims, n_dims)
        end
    end
    
    return hessians
end

"""
    classify_critical_points(hessians::Vector{Matrix{Float64}}; 
                           tol_zero=1e-8, tol_pos=1e-8, tol_neg=1e-8)::Vector{Symbol}

Classify critical points based on Hessian eigenvalue structure.

# Arguments
- hessians: Vector of Hessian matrices
- tol_zero: Tolerance for zero eigenvalues (degeneracy detection)
- tol_pos: Tolerance for positive eigenvalues
- tol_neg: Tolerance for negative eigenvalues

# Returns
Vector{Symbol}: Classification for each point (:minimum, :maximum, :saddle, :degenerate, :error)
"""
function classify_critical_points(hessians::Vector{Matrix{Float64}}; 
                                tol_zero=1e-8, tol_pos=1e-8, tol_neg=1e-8)::Vector{Symbol}
    n_points = length(hessians)
    classifications = Vector{Symbol}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        # Check for NaN matrices (computation failed)
        if any(isnan, H)
            @debug "Point $i: Hessian contains NaN values, classifying as :error"
            classifications[i] = :error
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))  # Use Symmetric for better numerical stability
            
            # Count eigenvalue signs
            n_positive = count(λ -> λ > tol_pos, eigenvals)
            n_negative = count(λ -> λ < -tol_neg, eigenvals)
            n_zero = count(λ -> abs(λ) < tol_zero, eigenvals)
            n_dims = length(eigenvals)
            
            @debug "Point $i: eigenvals=$eigenvals, n_pos=$n_positive, n_neg=$n_negative, n_zero=$n_zero, dims=$n_dims"
            
            if n_zero > 0
                @debug "Point $i: Classified as :degenerate (n_zero=$n_zero)"
                classifications[i] = :degenerate
            elseif n_positive == n_dims
                @debug "Point $i: Classified as :minimum (all positive)"
                classifications[i] = :minimum
            elseif n_negative == n_dims
                @debug "Point $i: Classified as :maximum (all negative)"
                classifications[i] = :maximum
            else
                @debug "Point $i: Classified as :saddle (mixed signs)"
                classifications[i] = :saddle
            end
            
        catch e
            @debug "Point $i: Exception in eigenvalue computation: $e, classifying as :error"
            classifications[i] = :error
        end
    end
    
    return classifications
end

"""
    store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}

Store all eigenvalues for each Hessian matrix for detailed analysis.

# Returns
Vector{Vector{Float64}}: All eigenvalues for each Hessian matrix
"""
function store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}
    n_points = length(hessians)
    all_eigenvalues = Vector{Vector{Float64}}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))
            all_eigenvalues[i] = sort(eigenvals)  # Sort for consistency
        catch e
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
        end
    end
    
    return all_eigenvalues
end

"""
    extract_critical_eigenvalues(classifications::Vector{Symbol}, 
                                all_eigenvalues::Vector{Vector{Float64}})::
                                Tuple{Vector{Float64}, Vector{Float64}}

Extract critical eigenvalues for minima and maxima classification.

# Returns
Tuple{Vector{Float64}, Vector{Float64}}: 
- smallest_positive_eigenvals: For minima (smallest positive eigenvalue)
- largest_negative_eigenvals: For maxima (largest negative eigenvalue)
"""
function extract_critical_eigenvalues(classifications::Vector{Symbol}, 
                                     all_eigenvalues::Vector{Vector{Float64}})
    n_points = length(classifications)
    smallest_positive_eigenvals = Vector{Float64}(undef, n_points)
    largest_negative_eigenvals = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        eigenvals = all_eigenvalues[i]
        classification = classifications[i]
        
        # Initialize with NaN
        smallest_positive_eigenvals[i] = NaN
        largest_negative_eigenvals[i] = NaN
        
        if any(isnan, eigenvals) || classification == :error
            continue
        end
        
        # For minima: find smallest positive eigenvalue
        if classification == :minimum
            positive_eigenvals = filter(λ -> λ > 1e-12, eigenvals)
            if !isempty(positive_eigenvals)
                smallest_positive_eigenvals[i] = minimum(positive_eigenvals)
            end
        end
        
        # For maxima: find largest negative eigenvalue
        if classification == :maximum
            negative_eigenvals = filter(λ -> λ < -1e-12, eigenvals)
            if !isempty(negative_eigenvals)
                largest_negative_eigenvals[i] = maximum(negative_eigenvals)
            end
        end
    end
    
    return smallest_positive_eigenvals, largest_negative_eigenvals
end

"""
    compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}

Compute L2 (Frobenius) norm of each Hessian matrix.

# Returns
Vector{Float64}: ||H||_F for each Hessian matrix
"""
function compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}
    n_points = length(hessians)
    hessian_norms = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            hessian_norms[i] = NaN
            continue
        end
        
        try
            hessian_norms[i] = norm(H, 2)  # Frobenius norm
        catch e
            hessian_norms[i] = NaN
        end
    end
    
    return hessian_norms
end

"""
    compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame

Compute detailed eigenvalue statistics for each Hessian matrix.

# Returns
DataFrame with columns:
- eigenvalue_min: Smallest eigenvalue
- eigenvalue_max: Largest eigenvalue  
- condition_number: Ratio of largest to smallest absolute eigenvalue
- determinant: Determinant of Hessian
- trace: Trace of Hessian
"""
function compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame
    n_points = length(hessians)
    
    eigenvalue_min = Vector{Float64}(undef, n_points)
    eigenvalue_max = Vector{Float64}(undef, n_points)
    condition_number = Vector{Float64}(undef, n_points)
    determinant = Vector{Float64}(undef, n_points)
    trace = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))
            eigenvalue_min[i] = minimum(eigenvals)
            eigenvalue_max[i] = maximum(eigenvals)
            
            # Condition number (ratio of largest to smallest absolute eigenvalue)
            abs_eigenvals = abs.(eigenvals)
            condition_number[i] = maximum(abs_eigenvals) / minimum(abs_eigenvals)
            
            determinant[i] = det(H)
            trace[i] = tr(H)
            
        catch e
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
        end
    end
    
    return DataFrame(
        eigenvalue_min = eigenvalue_min,
        eigenvalue_max = eigenvalue_max,
        condition_number = condition_number,
        determinant = determinant,
        trace = trace
    )
end