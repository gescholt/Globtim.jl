# ================================================================================
# 4D Deuflhard - BFGS Refinement Demo (Subset of Orthants)
# ================================================================================
# 
# This demonstrates BFGS refinement on a subset of orthants for faster execution

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
import DataFrames: combine, groupby

# ================================================================================
# SIMPLIFIED CONFIGURATION 
# ================================================================================

# Domain parameters - very reduced for speed
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        
const SAMPLE_RANGE_4D = 0.5                    
const POLYNOMIAL_DEGREE = 4                    # Very low degree
const SAMPLES_PER_DIM = 20                    # Number of samples per dimension
const L2_TOLERANCE = 0.0007                    # L²-norm tolerance
const DISTANCE_TOLERANCE = 0.05                

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# DEMO WITH SELECTED ORTHANTS
# ================================================================================

println("\n" * "="^80)
println("4D DEUFLHARD - BFGS REFINEMENT DEMO")
println("="^80)

# Just analyze 4 representative orthants for demo
demo_orthants = [
    ([-1, 1, -1, 1], "(-,+,-,+)"),  # Contains global minimum
    ([1, -1, 1, -1], "(+,-,+,-)"),  # Opposite of global minimum
    ([-1, -1, 1, 1], "(-,-,+,+)"),  # Mixed
    ([1, 1, -1, -1], "(+,+,-,-)"),  # Another mixed
]

println("\nAnalyzing 4 representative orthants (for demonstration)")
println("This shows BFGS refinement improving critical point accuracy\n")

all_critical_points = Vector{Vector{Float64}}()
all_function_values = Float64[]
all_orthant_labels = String[]

for (idx, (signs, label)) in enumerate(demo_orthants)
    println("="^60)
    println("Orthant $idx/4: $label")
    println("="^60)
    
    # Create orthant-specific domain
    orthant_shift = 0.2 * SAMPLE_RANGE_4D
    orthant_center = CENTER_4D .+ orthant_shift .* signs
    orthant_range = 0.4 * SAMPLE_RANGE_4D
    
    TR = test_input(deuflhard_4d_composite, dim=4, 
                   center=orthant_center, sample_range=orthant_range,
                   tolerance=L2_TOLERANCE)
    
    # Polynomial approximation
    pol = Constructor(TR, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
    println("  L²-norm: $(round(pol.nrm, digits=4))")
    
    # Solve system
    @polyvar x[1:4]
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, 
                                      basis=:chebyshev)
    println("  Raw solutions: $(length(solutions))")
    
    # Process critical points
    df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR)
    
    # Quick filtering
    valid_points = 0
    for i in 1:nrow(df_crit)
        point = [df_crit[i, Symbol("x$j")] for j in 1:4]
        
        # Check if point is in the orthant's domain
        in_domain = all(abs.(point .- orthant_center) .<= orthant_range * 1.1)
        
        if in_domain
            push!(all_critical_points, point)
            push!(all_function_values, df_crit[i, :z])
            push!(all_orthant_labels, label)
            valid_points += 1
        end
    end
    
    println("  Valid critical points: $valid_points")
    
    # Show best point in this orthant
    if valid_points > 0
        orthant_mask = all_orthant_labels .== label
        orthant_values = all_function_values[orthant_mask]
        best_idx = argmin(orthant_values)
        best_value = orthant_values[best_idx]
        println("  Best function value: $(Printf.@sprintf("%.3e", best_value))")
    end
end

# ================================================================================
# COMBINE AND ANALYZE RESULTS
# ================================================================================

println("\n" * "="^80)
println("COMBINED RESULTS (RAW)")
println("="^80)

n_total = length(all_critical_points)
println("Total critical points found: $n_total")

# Remove duplicates (simple version)
unique_points = Vector{Vector{Float64}}()
unique_values = Float64[]
unique_labels = String[]

for i in 1:n_total
    is_duplicate = false
    for j in 1:length(unique_points)
        if norm(all_critical_points[i] - unique_points[j]) < DISTANCE_TOLERANCE
            if all_function_values[i] < unique_values[j]
                # Replace with better value
                unique_points[j] = all_critical_points[i]
                unique_values[j] = all_function_values[i]
                unique_labels[j] = all_orthant_labels[i]
            end
            is_duplicate = true
            break
        end
    end
    
    if !is_duplicate
        push!(unique_points, all_critical_points[i])
        push!(unique_values, all_function_values[i])
        push!(unique_labels, all_orthant_labels[i])
    end
end

println("Unique critical points: $(length(unique_points))")

# Sort by function value
sort_idx = sortperm(unique_values)

# Display top 5 raw points
println("\nTop 5 Raw Critical Points:")
println("="^60)
n_show = min(5, length(unique_points))

for i in 1:n_show
    idx = sort_idx[i]
    point = unique_points[idx]
    value = unique_values[idx]
    label = unique_labels[idx]
    
    println("\n$i. Orthant: $label")
    println("   Point: [$(join([@sprintf("%.4f", x) for x in point], ", "))]")
    println("   Value: $(Printf.@sprintf("%.6f", value))")
end

# ================================================================================
# BFGS REFINEMENT
# ================================================================================

println("\n" * "="^80)
println("BFGS REFINEMENT")
println("="^80)

# Refine top 5 points with BFGS
println("\nRefining top critical points with BFGS optimization...")
refined_points = []
n_refine = min(5, length(unique_points))

for i in 1:n_refine
    idx = sort_idx[i]
    initial_point = unique_points[idx]
    initial_value = unique_values[idx]
    orthant_label = unique_labels[idx]
    
    println("\n" * "-"^60)
    println("Refining point $i from orthant $orthant_label")
    println("Initial: [$(join([@sprintf("%.4f", x) for x in initial_point], ", "))]")
    println("Initial value: $(Printf.@sprintf("%.6f", initial_value))")
    
    # Run BFGS optimization
    result = Optim.optimize(deuflhard_4d_composite, initial_point, Optim.BFGS(), 
                           Optim.Options(iterations=100, g_tol=1e-8, show_trace=false))
    
    if Optim.converged(result)
        refined_point = Optim.minimizer(result)
        refined_value = Optim.minimum(result)
        iterations = Optim.iterations(result)
        
        # Calculate improvement
        point_improvement = norm(refined_point - initial_point)
        value_improvement = abs(refined_value - initial_value)
        
        push!(refined_points, (
            initial_point, refined_point, 
            initial_value, refined_value,
            orthant_label, iterations,
            point_improvement, value_improvement,
            Optim.converged(result)
        ))
        
        println("\nRefined: [$(join([@sprintf("%.4f", x) for x in refined_point], ", "))]")
        println("Refined value: $(Printf.@sprintf("%.6f", refined_value))")
        println("BFGS iterations: $iterations")
        println("Position change: $(Printf.@sprintf("%.3e", point_improvement))")
        println("Value improvement: $(Printf.@sprintf("%.3e", value_improvement))")
        
        # Check gradient norm at solution
        grad = ForwardDiff.gradient(deuflhard_4d_composite, refined_point)
        grad_norm = norm(grad)
        println("Gradient norm at solution: $(Printf.@sprintf("%.3e", grad_norm))")
    else
        println("BFGS did not converge!")
    end
end

# ================================================================================
# VALIDATION AGAINST EXPECTED
# ================================================================================

println("\n" * "="^80)
println("VALIDATION CHECK")
println("="^80)

# Check if we found the expected global minimum
expected_global = [-0.7412, 0.7412, -0.7412, 0.7412]
expected_value = deuflhard_4d_composite(expected_global)

println("\nExpected global minimum:")
println("  Point: [$(join([@sprintf("%.4f", x) for x in expected_global], ", "))]")
println("  Value: $(Printf.@sprintf("%.6f", expected_value))")

# Find closest refined point
global min_dist_refined = Inf
global closest_refined = nothing
for rp in refined_points
    _, refined_pt, _, refined_val, label, _, _, _, _ = rp
    dist = norm(refined_pt - expected_global)
    if dist < min_dist_refined
        global min_dist_refined = dist
        global closest_refined = rp
    end
end

if min_dist_refined < DISTANCE_TOLERANCE && closest_refined !== nothing
    _, refined_pt, initial_val, refined_val, label, iters, pos_change, val_change, _ = closest_refined
    println("\n✓ Expected global minimum FOUND after BFGS!")
    println("  Found in orthant: $label")
    println("  Final distance: $(Printf.@sprintf("%.3e", min_dist_refined))")
    println("  Final value: $(Printf.@sprintf("%.6f", refined_val))")
    println("  Value error: $(Printf.@sprintf("%.3e", abs(refined_val - expected_value)))")
    println("\n  BFGS improvement:")
    println("    Position correction: $(Printf.@sprintf("%.3e", pos_change))")
    println("    Value improvement: $(Printf.@sprintf("%.3e", val_change))")
    println("    Iterations: $iters")
else
    println("\n✗ Expected global minimum NOT found in these 4 orthants")
    if closest_refined !== nothing
        println("  Closest refined distance: $(Printf.@sprintf("%.3e", min_dist_refined))")
    end
end

# ================================================================================
# SUMMARY
# ================================================================================

println("\n" * "="^80)
println("SUMMARY: IMPORTANCE OF BFGS REFINEMENT")
println("="^80)

if length(refined_points) > 0
    # Calculate average improvements
    global total_position_improvement = 0.0
    global total_value_improvement = 0.0
    
    for rp in refined_points
        _, _, _, _, _, _, pos_imp, val_imp, _ = rp
        global total_position_improvement += pos_imp
        global total_value_improvement += val_imp
    end
    
    avg_pos_imp = total_position_improvement / length(refined_points)
    avg_val_imp = total_value_improvement / length(refined_points)
    
    println("\nBFGS refinement statistics:")
    println("  Points refined: $(length(refined_points))")
    println("  Average position correction: $(Printf.@sprintf("%.3e", avg_pos_imp))")
    println("  Average value improvement: $(Printf.@sprintf("%.3e", avg_val_imp))")
    
    # Compare best values
    best_refined_val = minimum([rp[4] for rp in refined_points])
    best_raw_val = minimum(unique_values)
    
    println("\nBest function values:")
    println("  Raw polynomial solver: $(Printf.@sprintf("%.6f", best_raw_val))")
    println("  After BFGS refinement: $(Printf.@sprintf("%.6f", best_refined_val))")
    println("  Total improvement: $(Printf.@sprintf("%.3e", best_raw_val - best_refined_val))")
end

println("\nKey findings:")
println("- Raw polynomial solver provides approximate critical points")
println("- BFGS refinement is essential for accurate minima location")
println("- Position errors can be reduced by orders of magnitude")
println("- Function values become much more accurate after refinement")

println("\n" * "="^80)
println("DEMO COMPLETE")
println("="^80)