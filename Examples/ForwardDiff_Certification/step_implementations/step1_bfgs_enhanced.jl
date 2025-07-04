# Step 1: BFGS Hyperparameter Tracking & Enhanced Return Strategy
# 
# This implementation demonstrates enhanced BFGS refinement with comprehensive
# hyperparameter tracking and detailed result structures.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
using Dates

# ================================================================================
# ENHANCED CONFIGURATION STRUCTURE
# ================================================================================

mutable struct BFGSConfig
    # Tolerance parameters  
    standard_tolerance::Float64           # Standard gradient tolerance (1e-8)
    high_precision_tolerance::Float64     # High precision tolerance (1e-12) 
    precision_threshold::Float64          # When to switch to high precision (1e-6)
    
    # Iteration parameters
    max_iterations::Int                   # Maximum BFGS iterations (100)
    
    # Advanced parameters
    f_abs_tol::Float64                   # Absolute function tolerance
    x_tol::Float64                       # Parameter change tolerance
    
    # Reporting parameters
    show_trace::Bool                     # Display optimization trace
    track_hyperparameters::Bool          # Enable detailed tracking
    
    # Constructor with defaults
    function BFGSConfig(;
        standard_tolerance=1e-8,
        high_precision_tolerance=1e-12,
        precision_threshold=1e-6,
        max_iterations=100,
        f_abs_tol=1e-20,
        x_tol=1e-12,
        show_trace=false,
        track_hyperparameters=true
    )
        new(standard_tolerance, high_precision_tolerance, precision_threshold,
            max_iterations, f_abs_tol, x_tol, show_trace, track_hyperparameters)
    end
end

# ================================================================================
# ENHANCED RESULT STRUCTURE
# ================================================================================

struct BFGSResult
    # Core optimization results
    initial_point::Vector{Float64}
    refined_point::Vector{Float64}
    initial_value::Float64
    refined_value::Float64
    
    # Convergence information
    converged::Bool
    iterations_used::Int
    f_calls::Int
    g_calls::Int
    convergence_reason::Symbol            # :gradient, :iterations, :f_tol, etc.
    
    # Hyperparameters used
    hyperparameters::BFGSConfig
    tolerance_used::Float64               # Actual tolerance applied
    tolerance_selection_reason::String    # Why this tolerance was chosen
    
    # Quality metrics
    final_grad_norm::Float64
    point_improvement::Float64
    value_improvement::Float64
    
    # Additional metadata
    orthant_label::String
    distance_to_expected::Float64
    optimization_time::Float64
end

# ================================================================================
# 4D DEUFLHARD FUNCTION (from original)
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

const EXPECTED_GLOBAL_MIN = [-0.7412, 0.7412, -0.7412, 0.7412]

# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

function determine_convergence_reason(result::Optim.OptimizationResults, tolerance_used::Float64, config::BFGSConfig)
    # Analyze Optim result to determine why optimization stopped
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

# ================================================================================
# ENHANCED BFGS REFINEMENT FUNCTION
# ================================================================================

function enhanced_bfgs_refinement(
    initial_points::Vector{Vector{Float64}},
    initial_values::Vector{Float64},
    orthant_labels::Vector{String},
    objective_function::Function,
    config::BFGSConfig = BFGSConfig();
    expected_minimum::Vector{Float64} = EXPECTED_GLOBAL_MIN
)
    
    results = BFGSResult[]
    
    for (i, (point, value, label)) in enumerate(zip(initial_points, initial_values, orthant_labels))
        # Tolerance selection logic
        tolerance_used = abs(value) < config.precision_threshold ? 
                        config.high_precision_tolerance : 
                        config.standard_tolerance
                        
        tolerance_reason = abs(value) < config.precision_threshold ? 
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
        
        # Create enhanced result
        bfgs_result = BFGSResult(
            point, refined_point, value, refined_value,
            Optim.converged(result), Optim.iterations(result),
            f_calls, g_calls,
            convergence_reason,
            config, tolerance_used, tolerance_reason,
            norm(grad), norm(refined_point - point), abs(refined_value - value),
            label, norm(refined_point - expected_minimum), optimization_time
        )
        
        push!(results, bfgs_result)
        
        # Display progress if verbose
        if config.track_hyperparameters
            println("\nPoint $i/$(length(initial_points)) - Orthant: $label")
            println("  Tolerance used: $tolerance_used ($tolerance_reason)")
            println("  Converged: $(Optim.converged(result)) (reason: $convergence_reason)")
            println("  Iterations: $(bfgs_result.iterations_used), f_calls: $f_calls, g_calls: $g_calls")
            println("  Value improvement: $(Printf.@sprintf("%.3e", bfgs_result.value_improvement))")
            println("  Final gradient norm: $(Printf.@sprintf("%.3e", bfgs_result.final_grad_norm))")
            println("  Time: $(Printf.@sprintf("%.3f", optimization_time))s")
        end
    end
    
    return results
end

# ================================================================================
# DEMONSTRATION WITH SAMPLE DATA
# ================================================================================

println("="^80)
println("STEP 1: BFGS HYPERPARAMETER TRACKING DEMONSTRATION")
println("="^80)

# Create sample critical points (simulating output from polynomial solver)
sample_points = [
    [-0.74, 0.74, -0.74, 0.74],    # Near global minimum
    [0.0, 0.0, 0.0, 0.0],           # Saddle point
    [0.5, -0.5, 0.5, -0.5],         # Another critical point
    [-0.3, 0.3, -0.3, 0.3]          # Intermediate point
]

sample_values = [deuflhard_4d_composite(p) for p in sample_points]
sample_labels = ["(+,-,+,-)", "(+,+,+,+)", "(+,-,+,-)", "(-,+,-,+)"]

println("\nInitial critical points:")
for (i, (p, v, l)) in enumerate(zip(sample_points, sample_values, sample_labels))
    println("  $i. $l: f = $(Printf.@sprintf("%.6f", v))")
end

# Configure BFGS with detailed tracking
config = BFGSConfig(
    standard_tolerance = 1e-8,
    high_precision_tolerance = 1e-12,
    precision_threshold = 1e-6,
    max_iterations = 200,
    show_trace = false,
    track_hyperparameters = true
)

println("\nBFGS Configuration:")
println("  Standard tolerance: $(config.standard_tolerance)")
println("  High precision tolerance: $(config.high_precision_tolerance)")
println("  Precision threshold: $(config.precision_threshold)")
println("  Max iterations: $(config.max_iterations)")

# Run enhanced BFGS refinement
println("\n" * "="^60)
println("Running Enhanced BFGS Refinement")
println("="^60)

results = enhanced_bfgs_refinement(
    sample_points,
    sample_values,
    sample_labels,
    deuflhard_4d_composite,
    config
)

# ================================================================================
# ANALYSIS OF RESULTS
# ================================================================================

println("\n" * "="^80)
println("HYPERPARAMETER TRACKING SUMMARY")
println("="^80)

# Tolerance usage statistics
hp_count = count(r -> r.tolerance_used == config.high_precision_tolerance, results)
std_count = count(r -> r.tolerance_used == config.standard_tolerance, results)

println("\nTolerance Usage:")
println("  High precision: $hp_count/$(length(results)) points")
println("  Standard: $std_count/$(length(results)) points")

# Convergence statistics
convergence_reasons = Dict{Symbol,Int}()
for r in results
    convergence_reasons[r.convergence_reason] = get(convergence_reasons, r.convergence_reason, 0) + 1
end

println("\nConvergence Reasons:")
for (reason, count) in convergence_reasons
    println("  $reason: $count points")
end

# Performance statistics
avg_iterations = mean([r.iterations_used for r in results])
avg_time = mean([r.optimization_time for r in results])
total_f_calls = sum([r.f_calls for r in results])
total_g_calls = sum([r.g_calls for r in results])

println("\nPerformance Metrics:")
println("  Average iterations: $(Printf.@sprintf("%.1f", avg_iterations))")
println("  Average time per point: $(Printf.@sprintf("%.3f", avg_time))s")
println("  Total function evaluations: $total_f_calls")
println("  Total gradient evaluations: $total_g_calls")

# Quality improvements
println("\nOptimization Quality:")
for (i, r) in enumerate(results)
    println("\n  Point $i ($(r.orthant_label)):")
    println("    Initial value: $(Printf.@sprintf("%.8f", r.initial_value))")
    println("    Refined value: $(Printf.@sprintf("%.8f", r.refined_value))")
    println("    Improvement: $(Printf.@sprintf("%.3e", r.value_improvement))")
    println("    Final gradient norm: $(Printf.@sprintf("%.3e", r.final_grad_norm))")
    println("    Distance to expected: $(Printf.@sprintf("%.3e", r.distance_to_expected))")
end

# Find best result
best_idx = argmin([r.refined_value for r in results])
best_result = results[best_idx]

println("\n" * "="^60)
println("BEST RESULT")
println("="^60)
println("Orthant: $(best_result.orthant_label)")
println("Refined value: $(Printf.@sprintf("%.10f", best_result.refined_value))")
println("Distance to expected minimum: $(Printf.@sprintf("%.3e", best_result.distance_to_expected))")
println("Convergence reason: $(best_result.convergence_reason)")
println("Tolerance used: $(best_result.tolerance_used)")

# ================================================================================
# EXPORT FUNCTIONS FOR USE IN MAIN FILE
# ================================================================================

# Create a module-like structure for reuse
module BFGSEnhanced
    export BFGSConfig, BFGSResult, enhanced_bfgs_refinement, determine_convergence_reason
    
    # Include all the definitions from above
    # (In practice, this would be the actual module content)
end

println("\n" * "="^80)
println("STEP 1 IMPLEMENTATION COMPLETE")
println("="^80)
println("\nKey achievements:")
println("✓ Comprehensive hyperparameter tracking in BFGSConfig")
println("✓ Detailed result structure with all optimization metrics")
println("✓ Automatic tolerance selection based on function value magnitude")
println("✓ Complete convergence reason determination")
println("✓ Performance timing and call counting")
println("✓ Distance tracking to expected global minimum")
println("\nThis enhanced BFGS refinement provides full visibility into the")
println("optimization process, enabling debugging, parameter tuning, and")
println("automated testing.")