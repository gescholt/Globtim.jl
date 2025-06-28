# High-precision version of 4D Deuflhard analysis with enhanced BFGS parameters
# This demonstrates immediate improvements without modifying the library

# Proper initialization for examples
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials
using Optim
import IterTools
import DataFrames: combine, groupby

# Include the same configuration from original
include("deuflhard_4d_analysis.jl")

# ================================================================================
# HIGH PRECISION REFINEMENT FUNCTION
# ================================================================================
"""
High-precision BFGS refinement for critical points with tiny function values.
This is a custom version that doesn't require modifying the library.
"""
function refine_critical_points_high_precision(
    f::Function,
    df::DataFrame,
    TR::test_input;
    g_tol=1e-14,
    f_tol=1e-16,
    x_tol=1e-12,
    f_abs_tol=1e-16,
    max_iters=300,
    tol_dist=0.01,
    verbose=true
)
    n_dims = count(col -> startswith(string(col), "x"), names(df))
    
    # Create output dataframe with refined coordinates
    df_refined = copy(df)
    
    # Add new columns for refined coordinates and convergence info
    for i = 1:n_dims
        df_refined[!, Symbol("y$i")] = zeros(nrow(df))
    end
    df_refined[!, :converged] = falses(nrow(df))
    df_refined[!, :iterations] = zeros(Int, nrow(df))
    df_refined[!, :gradient_norm_refined] = zeros(nrow(df))
    df_refined[!, :improvement] = zeros(nrow(df))
    
    converged_count = 0
    total_improvement = 0.0
    
    for i in 1:nrow(df)
        x0 = [df[i, Symbol("x$j")] for j = 1:n_dims]
        f0 = f(x0)
        
        try
            # High-precision BFGS optimization
            result = Optim.optimize(
                f, x0,
                Optim.BFGS(linesearch=Optim.BackTracking()),  # More robust line search
                Optim.Options(
                    g_tol=g_tol,
                    f_tol=f_tol,
                    x_tol=x_tol,
                    f_abs_tol=f_abs_tol,
                    iterations=max_iters,
                    show_trace=verbose && (i % 10 == 1),  # Show trace every 10th point
                    extended_trace=false,
                    store_trace=false
                )
            )
            
            x_refined = Optim.minimizer(result)
            f_refined = Optim.minimum(result)
            
            # Store refined coordinates
            for j = 1:n_dims
                df_refined[i, Symbol("y$j")] = x_refined[j]
            end
            
            # Compute gradient norm at refined point
            grad = ForwardDiff.gradient(f, x_refined)
            grad_norm = norm(grad)
            
            df_refined[i, :converged] = Optim.converged(result)
            df_refined[i, :iterations] = result.iterations
            df_refined[i, :gradient_norm_refined] = grad_norm
            df_refined[i, :improvement] = f0 - f_refined
            
            if Optim.converged(result)
                converged_count += 1
                total_improvement += f0 - f_refined
            end
            
            if verbose && grad_norm > g_tol
                println("⚠️  Point $i: gradient norm = $grad_norm > tolerance")
            end
            
        catch e
            if verbose
                println("Error refining point $i: $e")
            end
            # Keep original coordinates on error
            for j = 1:n_dims
                df_refined[i, Symbol("y$j")] = x0[j]
            end
            df_refined[i, :converged] = false
            df_refined[i, :gradient_norm_refined] = NaN
        end
    end
    
    if verbose
        println("\n=== High-Precision Refinement Summary ===")
        println("Converged: $converged_count/$(nrow(df)) points")
        println("Average improvement: $(total_improvement/converged_count)")
        println("Average gradient norm: $(mean(filter(!isnan, df_refined.gradient_norm_refined)))")
    end
    
    return df_refined
end

# ================================================================================
# ENHANCED VERIFICATION FUNCTION
# ================================================================================
function verify_critical_point_quality(
    f::Function,
    df::DataFrame,
    expected_df::DataFrame;
    grad_tol=1e-12,
    dist_tol=1e-6
)
    n_dims = count(col -> startswith(string(col), "y"), names(df))
    
    println("\n=== Critical Point Quality Verification ===")
    
    # Check gradient norms
    grad_norms = Float64[]
    for i in 1:nrow(df)
        if df[i, :converged]
            point = [df[i, Symbol("y$j")] for j in 1:n_dims]
            grad = ForwardDiff.gradient(f, point)
            push!(grad_norms, norm(grad))
        end
    end
    
    high_quality = sum(grad_norms .< grad_tol)
    println("\nGradient Quality:")
    println("  • Points with ||∇f|| < $grad_tol: $high_quality/$(length(grad_norms))")
    println("  • Min gradient norm: $(minimum(grad_norms))")
    println("  • Max gradient norm: $(maximum(grad_norms))")
    println("  • Mean gradient norm: $(mean(grad_norms))")
    
    # Check distances to expected points
    if nrow(expected_df) > 0
        min_distances = Float64[]
        for i in 1:nrow(df)
            if df[i, :converged]
                point = [df[i, Symbol("y$j")] for j in 1:n_dims]
                min_dist = minimum([
                    norm(point - [expected_df[k, Symbol("x$j")] for j in 1:n_dims])
                    for k in 1:nrow(expected_df)
                ])
                push!(min_distances, min_dist)
            end
        end
        
        close_matches = sum(min_distances .< dist_tol)
        println("\nDistance to Expected Points:")
        println("  • Points within $dist_tol: $close_matches/$(length(min_distances))")
        println("  • Min distance: $(minimum(min_distances))")
        println("  • Max distance: $(maximum(min_distances))")
        println("  • Mean distance: $(mean(min_distances))")
    end
    
    return grad_norms, high_quality
end

# ================================================================================
# RUN HIGH-PRECISION ANALYSIS
# ================================================================================
println("\n" * "="^80)
println("HIGH-PRECISION 4D DEUFLHARD ANALYSIS")
println("="^80)

# Step 1: Run standard polynomial approximation (reuse from original)
println("\nStep 1: Using polynomial approximation from standard analysis...")
# Assuming df_polynomial_4d is available from the included file

# Step 2: Apply high-precision refinement
println("\nStep 2: Applying high-precision BFGS refinement...")
df_high_precision = refine_critical_points_high_precision(
    deuflhard_4d_composite,
    df_polynomial_4d,
    TR_4d,
    g_tol=1e-14,
    f_tol=1e-16,
    x_tol=1e-12,
    f_abs_tol=1e-16,
    max_iters=300,
    verbose=true
)

# Step 3: Filter to domain and identify minimizers
inside_mask_hp = points_in_hypercube(df_high_precision, TR_4d, use_y=true)
df_hp_inside = df_high_precision[inside_mask_hp, :]

# Update z values with refined function evaluations
for i in 1:nrow(df_hp_inside)
    point = [df_hp_inside[i, Symbol("y$j")] for j in 1:4]
    df_hp_inside[i, :z] = deuflhard_4d_composite(point)
end

sort!(df_hp_inside, :z)

# Focus on minimizers
value_mask_hp = df_hp_inside.z .< VALUE_TOLERANCE
df_hp_minimizers = df_hp_inside[value_mask_hp, :]

println("\nHigh-precision minimizers found: $(nrow(df_hp_minimizers))")

# Step 4: Quality verification
grad_norms, high_quality_count = verify_critical_point_quality(
    deuflhard_4d_composite,
    df_hp_minimizers,
    predicted_minima_4d,
    grad_tol=1e-12,
    dist_tol=1e-6
)

# Step 5: Compare with expected minima
if nrow(df_hp_minimizers) > 0 && nrow(predicted_minima_4d) > 0
    println("\n=== HIGH-PRECISION COMPARISON WITH EXPECTED MINIMA ===")
    
    # Compute distances with high precision
    distances_hp = Float64[]
    closest_indices_hp = Int[]
    
    for i in 1:nrow(df_hp_minimizers)
        found_point = [df_hp_minimizers[i, Symbol("y$j")] for j in 1:4]
        min_dist = Inf
        closest_idx = 1
        
        for j in 1:nrow(predicted_minima_4d)
            expected_point = [predicted_minima_4d[j, Symbol("x$j")] for j in 1:4]
            dist = norm(found_point - expected_point)
            if dist < min_dist
                min_dist = dist
                closest_idx = j
            end
        end
        
        push!(distances_hp, min_dist)
        push!(closest_indices_hp, closest_idx)
    end
    
    # Display top minimizers with enhanced precision
    println("\nTop 10 High-Precision Minimizers:")
    n_show = min(10, nrow(df_hp_minimizers))
    
    hp_summary = DataFrame(
        Index = 1:n_show,
        x1 = [round(df_hp_minimizers[i, :y1], digits=6) for i in 1:n_show],
        x2 = [round(df_hp_minimizers[i, :y2], digits=6) for i in 1:n_show],
        x3 = [round(df_hp_minimizers[i, :y3], digits=6) for i in 1:n_show],
        x4 = [round(df_hp_minimizers[i, :y4], digits=6) for i in 1:n_show],
        Function_Value = [@sprintf("%.3e", df_hp_minimizers[i, :z]) for i in 1:n_show],
        Gradient_Norm = [@sprintf("%.3e", df_hp_minimizers[i, :gradient_norm_refined]) for i in 1:n_show],
        Distance_to_Expected = [@sprintf("%.3e", distances_hp[i]) for i in 1:n_show],
        Converged = df_hp_minimizers.converged[1:n_show]
    )
    
    println(hp_summary)
    
    # Statistics
    ultra_close = sum(distances_hp .< 1e-6)
    very_close = sum(distances_hp .< 1e-4)
    close = sum(distances_hp .< 0.01)
    
    println("\n=== HIGH-PRECISION STATISTICS ===")
    println("Distance to expected minima:")
    println("  • < 1e-6: $ultra_close points (ultra-high precision)")
    println("  • < 1e-4: $very_close points (very high precision)")
    println("  • < 0.01: $close points (high precision)")
    println("  • < 0.1: $(sum(distances_hp .< 0.1)) points (standard precision)")
    
    println("\nGradient norms:")
    println("  • < 1e-14: $(sum(grad_norms .< 1e-14)) points")
    println("  • < 1e-12: $(sum(grad_norms .< 1e-12)) points")
    println("  • < 1e-10: $(sum(grad_norms .< 1e-10)) points")
    
    # Compare with standard analysis
    if @isdefined distances_to_expected_minima
        improvement_factor = mean(distances_to_expected_minima) / mean(distances_hp)
        println("\nImprovement over standard analysis:")
        println("  • Average distance improvement factor: $(round(improvement_factor, digits=2))x")
        println("  • Standard avg distance: $(round(mean(distances_to_expected_minima), digits=6))")
        println("  • High-precision avg distance: $(round(mean(distances_hp), digits=6))")
    end
end

println("\n=== HIGH-PRECISION ANALYSIS COMPLETE ===")