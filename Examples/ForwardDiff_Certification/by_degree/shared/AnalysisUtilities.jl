# AnalysisUtilities.jl - Common analysis patterns and result structures

module AnalysisUtilities

using Printf, LinearAlgebra
using DynamicPolynomials
using Globtim
using DataFrames
using Common4DDeuflhard: get_actual_degree, GN_FIXED, DISTANCE_TOLERANCE

export DegreeAnalysisResult, analyze_single_degree, compute_recovery_metrics

"""
    DegreeAnalysisResult

Structure containing analysis results for a single polynomial degree.

# Fields
- `degree::Int`: Polynomial degree tested
- `l2_norm::Float64`: L²-norm approximation error
- `n_theoretical_points::Int`: Number of expected critical points
- `n_computed_points::Int`: Number of critical points found
- `n_successful_recoveries::Int`: Points recovered within tolerance
- `success_rate::Float64`: Fraction of theoretical points recovered
- `runtime_seconds::Float64`: Computation time for this degree
- `converged::Bool`: Whether L²-norm met target tolerance
- `computed_points::Vector{Vector{Float64}}`: Found critical points
- `min_min_success_rate::Float64`: Success rate for min+min points only
"""
struct DegreeAnalysisResult
    degree::Int
    l2_norm::Float64
    n_theoretical_points::Int
    n_computed_points::Int
    n_successful_recoveries::Int
    success_rate::Float64
    runtime_seconds::Float64
    converged::Bool
    computed_points::Vector{Vector{Float64}}
    min_min_success_rate::Float64
end

"""
    analyze_single_degree(f, degree, center, range, theoretical_points, theoretical_types; 
                         gn=GN_FIXED, tolerance_target=Inf, basis=:chebyshev)

Analyze polynomial approximation for a single degree.

# Arguments
- `f`: Function to approximate
- `degree`: Polynomial degree
- `center`: Domain center
- `range`: Domain half-width
- `theoretical_points`: Expected critical points
- `theoretical_types`: Classifications of theoretical points
- `gn`: Sample count parameter (default: GN_FIXED)
- `tolerance_target`: L²-norm convergence target
- `basis`: Polynomial basis (:chebyshev or :legendre)

# Returns
- `DegreeAnalysisResult`: Comprehensive analysis results
"""
function analyze_single_degree(f, degree, center, range, theoretical_points, theoretical_types; 
                              gn=GN_FIXED, tolerance_target=Inf, basis=:chebyshev)
    start_time = time()
    
    try
        # Create polynomial approximation
        TR = test_input(f, dim=4, center=center, sample_range=range, GN=gn)
        pol = Constructor(TR, degree, basis=basis, verbose=false)
        actual_degree = get_actual_degree(pol)
        
        # Solve polynomial system
        @polyvar x[1:4]
        solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=basis)
        df_crit = process_crit_pts(solutions, f, TR)
        
        # Extract critical points
        computed_points = Vector{Vector{Float64}}()
        if nrow(df_crit) > 0
            for i in 1:nrow(df_crit)
                point = [df_crit[i, Symbol("x$j")] for j in 1:4]
                push!(computed_points, point)
            end
        end
        
        # Compute recovery metrics
        metrics = compute_recovery_metrics(computed_points, theoretical_points, theoretical_types)
        
        runtime = time() - start_time
        converged = pol.nrm <= tolerance_target
        
        return DegreeAnalysisResult(
            actual_degree,
            pol.nrm,
            length(theoretical_points),
            length(computed_points),
            metrics.n_successful_recoveries,
            metrics.success_rate,
            runtime,
            converged,
            computed_points,
            metrics.min_min_success_rate
        )
        
    catch e
        @error "Analysis failed for degree $degree" exception=e
        runtime = time() - start_time
        
        return DegreeAnalysisResult(
            degree,
            Inf,
            length(theoretical_points),
            0,
            0,
            0.0,
            runtime,
            false,
            Vector{Vector{Float64}}(),
            0.0
        )
    end
end

"""
    compute_recovery_metrics(computed_points, theoretical_points, theoretical_types)

Compute distance-based recovery metrics for critical points.

# Arguments
- `computed_points`: Found critical points
- `theoretical_points`: Expected critical points
- `theoretical_types`: Classifications for filtering

# Returns
- NamedTuple with recovery statistics
"""
function compute_recovery_metrics(computed_points, theoretical_points, theoretical_types)
    n_theoretical = length(theoretical_points)
    n_computed = length(computed_points)
    
    if n_computed == 0 || n_theoretical == 0
        return (
            n_successful_recoveries = 0,
            success_rate = 0.0,
            min_min_success_rate = 0.0,
            closest_distances = Float64[]
        )
    end
    
    # Compute closest distances
    closest_distances = Float64[]
    for theoretical_pt in theoretical_points
        min_dist = minimum([norm(theoretical_pt - computed_pt) for computed_pt in computed_points])
        push!(closest_distances, min_dist)
    end
    
    # Overall success metrics
    successful_recoveries = sum(closest_distances .< DISTANCE_TOLERANCE)
    success_rate = successful_recoveries / n_theoretical
    
    # Min+min specific metrics
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    if !isempty(min_min_indices)
        min_min_recoveries = sum(closest_distances[min_min_indices] .< DISTANCE_TOLERANCE)
        min_min_success_rate = min_min_recoveries / length(min_min_indices)
    else
        min_min_success_rate = 0.0
    end
    
    return (
        n_successful_recoveries = successful_recoveries,
        success_rate = success_rate,
        min_min_success_rate = min_min_success_rate,
        closest_distances = closest_distances
    )
end

end # module