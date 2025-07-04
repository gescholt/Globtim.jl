# Hessian Visualization Demonstration
#
# This example showcases the comprehensive visualization capabilities
# of Phase 2 Hessian analysis, including all plotting functions.

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials
using DataFrames

# Optional visualization (comment out if not needed)
# using CairoMakie

println("=== Hessian Visualization Demo ===\n")

# Setup problem with multiple critical point types
f = tref_3d  # 3D function with diverse critical points
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0], sample_range=0.12, GN=25)
pol = Constructor(TR, 10)
@polyvar x[1:3]

println("Solving polynomial system...")
solutions = solve_polynomial_system(x, 3, 10, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

println("Performing Phase 2 analysis...")
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    enable_hessian=true,
    hessian_tol_zero=1e-8,
    verbose=false
)

println("Critical points analyzed: $(nrow(df_enhanced))")
println("Classification summary:")
classification_counts = combine(groupby(df_enhanced, :critical_point_type), nrow => :count)
for row in eachrow(classification_counts)
    percentage = round(100 * row.count / nrow(df_enhanced), digits=1)
    println("  • $(row.critical_point_type): $(row.count) points ($(percentage)%)")
end

# Text-based visualization for demonstration
println("\n" * "="^60)
println("VISUALIZATION DEMONSTRATIONS")
println("="^60)

# 1. Hessian Norm Analysis
println("\n1. HESSIAN NORM ANALYSIS")
println("-"^30)

valid_norms = filter(!isnan, df_enhanced.hessian_norm)
if !isempty(valid_norms)
    println("Statistics:")
    println("  Count: $(length(valid_norms))")
    println("  Range: [$(round(minimum(valid_norms), digits=3)), $(round(maximum(valid_norms), digits=3))]")
    println("  Mean ± Std: $(round(mean(valid_norms), digits=3)) ± $(round(std(valid_norms), digits=3))")
    println("  Median: $(round(median(valid_norms), digits=3))")
    
    # Distribution by critical point type
    for point_type in [:minimum, :saddle, :maximum]
        type_mask = df_enhanced.critical_point_type .== point_type
        type_norms = filter(!isnan, df_enhanced.hessian_norm[type_mask])
        if !isempty(type_norms)
            println("  $(uppercase(string(point_type))) ($(length(type_norms)) points):")
            println("    Mean: $(round(mean(type_norms), digits=3))")
            println("    Range: [$(round(minimum(type_norms), digits=3)), $(round(maximum(type_norms), digits=3))]")
        end
    end
end

# 2. Condition Number Quality Assessment
println("\n2. CONDITION NUMBER ANALYSIS")
println("-"^30)

valid_conditions = filter(x -> isfinite(x) && x > 0, df_enhanced.hessian_condition_number)
if !isempty(valid_conditions)
    # Quality classification
    excellent = sum(valid_conditions .< 1e3)
    good = sum(1e3 .<= valid_conditions .< 1e6) 
    fair = sum(1e6 .<= valid_conditions .< 1e9)
    poor = sum(1e9 .<= valid_conditions .< 1e12)
    critical = sum(valid_conditions .>= 1e12)
    
    total = length(valid_conditions)
    println("Condition number quality breakdown:")
    println("  • Excellent (< 1e3):     $excellent ($(round(100*excellent/total, digits=1))%)")
    println("  • Good (1e3-1e6):        $good ($(round(100*good/total, digits=1))%)")
    println("  • Fair (1e6-1e9):        $fair ($(round(100*fair/total, digits=1))%)")
    println("  • Poor (1e9-1e12):       $poor ($(round(100*poor/total, digits=1))%)")
    println("  • Critical (≥ 1e12):     $critical ($(round(100*critical/total, digits=1))%)")
    
    # Overall assessment
    well_conditioned = excellent + good
    overall_quality = if well_conditioned/total > 0.8
        "EXCELLENT"
    elseif well_conditioned/total > 0.6
        "GOOD"
    elseif well_conditioned/total > 0.4
        "FAIR"
    else
        "POOR"
    end
    println("  Overall numerical quality: $overall_quality")
end

# 3. Critical Eigenvalue Analysis
println("\n3. CRITICAL EIGENVALUE ANALYSIS")
println("-"^30)

# Minima eigenvalue validation
minima_mask = df_enhanced.critical_point_type .== :minimum
minima_eigenvals = filter(!isnan, df_enhanced.smallest_positive_eigenval[minima_mask])
if !isempty(minima_eigenvals)
    println("MINIMA validation (smallest positive eigenvalues):")
    println("  Count: $(length(minima_eigenvals))")
    println("  Range: [$(round(minimum(minima_eigenvals), digits=6)), $(round(maximum(minima_eigenvals), digits=6))]")
    println("  Mean: $(round(mean(minima_eigenvals), digits=6))")
    
    # Check if all are positive (validation)
    all_positive = all(λ -> λ > 1e-12, minima_eigenvals)
    println("  All positive: $(all_positive ? "✓ VALID" : "✗ INVALID")")
end

# Maxima eigenvalue validation
maxima_mask = df_enhanced.critical_point_type .== :maximum
maxima_eigenvals = filter(!isnan, df_enhanced.largest_negative_eigenval[maxima_mask])
if !isempty(maxima_eigenvals)
    println("\nMAXIMA validation (largest negative eigenvalues):")
    println("  Count: $(length(maxima_eigenvals))")
    println("  Range: [$(round(minimum(maxima_eigenvals), digits=6)), $(round(maximum(maxima_eigenvals), digits=6))]")
    println("  Mean: $(round(mean(maxima_eigenvals), digits=6))")
    
    # Check if all are negative (validation)
    all_negative = all(λ -> λ < -1e-12, maxima_eigenvals)
    println("  All negative: $(all_negative ? "✓ VALID" : "✗ INVALID")")
end

# 4. Eigenvalue Distribution Statistics
println("\n4. EIGENVALUE DISTRIBUTION STATISTICS")
println("-"^30)

for point_type in [:minimum, :saddle, :maximum]
    type_mask = df_enhanced.critical_point_type .== point_type
    type_count = sum(type_mask)
    
    if type_count > 0
        println("\n$(uppercase(string(point_type))) points ($type_count total):")
        
        # Min/max eigenvalues
        min_eigenvals = filter(!isnan, df_enhanced.hessian_eigenvalue_min[type_mask])
        max_eigenvals = filter(!isnan, df_enhanced.hessian_eigenvalue_max[type_mask])
        
        if !isempty(min_eigenvals)
            println("  Min eigenvalues: [$(round(minimum(min_eigenvals), digits=4)), $(round(maximum(min_eigenvals), digits=4))]")
        end
        if !isempty(max_eigenvals)
            println("  Max eigenvalues: [$(round(minimum(max_eigenvals), digits=4)), $(round(maximum(max_eigenvals), digits=4))]")
        end
        
        # Determinant and trace
        determinants = filter(!isnan, df_enhanced.hessian_determinant[type_mask])
        traces = filter(!isnan, df_enhanced.hessian_trace[type_mask])
        
        if !isempty(determinants)
            det_positive = sum(determinants .> 0)
            println("  Determinants: $(det_positive)/$(length(determinants)) positive ($(round(100*det_positive/length(determinants), digits=1))%)")
        end
        
        if !isempty(traces)
            trace_positive = sum(traces .> 0)
            println("  Traces: $(trace_positive)/$(length(traces)) positive ($(round(100*trace_positive/length(traces), digits=1))%)")
        end
    end
end

# Demonstration of visualization function calls
println("\n" * "="^60)
println("VISUALIZATION FUNCTION CALLS")
println("="^60)

println("\nTo generate actual plots, uncomment CairoMakie and run:")
println()
println("# using CairoMakie")
println()
println("# 1. Hessian norm analysis")
println("fig1 = plot_hessian_norms(df_enhanced)")
println("display(fig1)")
println()
println("# 2. Condition number analysis")  
println("fig2 = plot_condition_numbers(df_enhanced)")
println("display(fig2)")
println()
println("# 3. Critical eigenvalue analysis")
println("fig3 = plot_critical_eigenvalues(df_enhanced)")
println("display(fig3)")
println()
println("# Save plots")
println("save(\"hessian_norms.png\", fig1)")
println("save(\"condition_numbers.png\", fig2)")
println("save(\"critical_eigenvalues.png\", fig3)")

# Optional: Actually generate plots if CairoMakie is available
# Uncomment this section to generate real visualizations

"""
# Uncomment this section to generate Phase 2 visualizations

println("\\n=== Generating Actual Plots ===")
using CairoMakie

# Hessian norm analysis
println("Generating Hessian norm plot...")
fig1 = plot_hessian_norms(df_enhanced)
display(fig1)

# Condition number analysis  
println("Generating condition number plot...")
fig2 = plot_condition_numbers(df_enhanced)
display(fig2)

# Critical eigenvalue analysis
println("Generating critical eigenvalue plot...")
fig3 = plot_critical_eigenvalues(df_enhanced)
display(fig3)

println("Phase 2 visualizations generated!")

# Optional: Save plots
# save("hessian_norms.png", fig1)
# save("condition_numbers.png", fig2)
# save("critical_eigenvalues.png", fig3)
"""

println("\n" * "="^60)
println("HESSIAN VISUALIZATION DEMO COMPLETE")
println("="^60)
println("This demonstration shows:")
println("  • Hessian norm analysis by critical point type")
println("  • Condition number quality assessment")
println("  • Critical eigenvalue validation")
println("  • Eigenvalue distribution statistics")
println("  • Ready-to-use visualization function calls")
println("\nTo generate actual plots:")
println("  1. Uncomment the CairoMakie import")
println("  2. Uncomment the visualization section")
println("  3. Run the script")

nothing  # Suppress final output