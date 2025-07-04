# Eigenvalue Distribution Analysis Demonstration
# 
# This example demonstrates comprehensive eigenvalue analysis capabilities
# of Phase 2 Hessian classification, including distribution analysis and
# statistical validation.

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using Statistics

# Explicitly import DataFrames functions to avoid conflicts
import DataFrames: combine, groupby

println("=== Eigenvalue Distribution Analysis Demo ===\n")

# Test with multiple functions to demonstrate different eigenvalue patterns
test_functions = [
    (Deuflhard, "Deuflhard (2D challenging)", 2, [0.0, 0.0]),
    (Rastringin, "Rastringin (3D multi-modal)", 3, [0.0, 0.0, 0.0]),
    (HolderTable, "HolderTable (2D global optimization)", 2, [0.0, 0.0])
]

for (func, name, dim, center) in test_functions
    println("\n" * "="^60)
    println("ANALYZING: $name")
    println("="^60)
    
    # Setup problem
    TR = test_input(func, dim=dim, center=center, sample_range=1.0)
    pol = Constructor(TR, 8)
    
    # Define variables and solve
    if dim == 2
        @polyvar x[1:2]
    else
        @polyvar x[1:3]
    end
    
    solutions = solve_polynomial_system(x, dim, 8, pol.coeffs)
    df = process_crit_pts(solutions, func, TR)
    
    println("Critical points found: $(nrow(df))")
    
    # Phase 2 analysis
    df_enhanced, df_min = analyze_critical_points(
        func, df, TR,
        enable_hessian=true,
        hessian_tol_zero=1e-8,
        verbose=false
    )
    
    # Classification summary
    println("\nCritical Point Classification:")
    classification_counts = combine(groupby(df_enhanced, :critical_point_type), nrow => :count)
    for row in eachrow(classification_counts)
        percentage = round(100 * row.count / nrow(df_enhanced), digits=1)
        println("  • $(row.critical_point_type): $(row.count) points ($(percentage)%)")
    end
    
    # Function to extract all eigenvalues for a given critical point type
    function extract_all_eigenvalues(df, point_type)
        mask = df.critical_point_type .== point_type
        if !any(mask)
            return Float64[]
        end
        
        eigenvalues = Float64[]
        for i in findall(mask)
            min_eig = df.hessian_eigenvalue_min[i]
            max_eig = df.hessian_eigenvalue_max[i]
            
            if !isnan(min_eig) && !isnan(max_eig)
                push!(eigenvalues, min_eig)
                push!(eigenvalues, max_eig)
                
                # For higher dimensions, estimate middle eigenvalues using trace
                if dim >= 3
                    trace_val = df.hessian_trace[i]
                    if !isnan(trace_val)
                        middle_eig = trace_val - min_eig - max_eig
                        push!(eigenvalues, middle_eig)
                    end
                end
            end
        end
        return eigenvalues
    end
    
    # Function to create text-based histogram
    function text_histogram(values, title, bins=10)
        if isempty(values)
            println("$title: No data available")
            return
        end
        
        println("\n$title:")
        println("  Count: $(length(values))")
        println("  Range: [$(round(minimum(values), digits=4)), $(round(maximum(values), digits=4))]")
        println("  Mean ± Std: $(round(mean(values), digits=4)) ± $(round(std(values), digits=4))")
        println("  Median: $(round(median(values), digits=4))")
        
        # Create histogram bins
        min_val, max_val = extrema(values)
        if min_val ≈ max_val
            println("  Distribution: All values approximately equal")
            return
        end
        
        bin_edges = range(min_val, max_val, length=bins+1)
        bin_counts = zeros(Int, bins)
        
        for val in values
            bin_idx = min(bins, max(1, floor(Int, (val - min_val) / (max_val - min_val) * bins) + 1))
            bin_counts[bin_idx] += 1
        end
        
        # Display histogram
        max_count = maximum(bin_counts)
        max_bar_length = 30
        
        println("  Histogram:")
        for i in 1:bins
            left_edge = bin_edges[i]
            right_edge = bin_edges[i+1]
            count = bin_counts[i]
            
            # Create bar visualization
            bar_length = max_count > 0 ? round(Int, count / max_count * max_bar_length) : 0
            bar = "█" ^ bar_length
            
            range_str = "[$(round(left_edge, digits=3)), $(round(right_edge, digits=3)))"
            println("    $(rpad(range_str, 15)) │$bar ($count)")
        end
    end
    
    # Analyze eigenvalues for each critical point type
    println("\n" * "-"^50)
    println("EIGENVALUE DISTRIBUTION ANALYSIS")
    println("-"^50)
    
    for point_type in [:minimum, :saddle, :maximum]
        eigenvals = extract_all_eigenvalues(df_enhanced, point_type)
        text_histogram(eigenvals, "$(uppercase(string(point_type))) EIGENVALUES")
    end
    
    # Mathematical validation
    println("\n" * "-"^50)
    println("MATHEMATICAL VALIDATION")
    println("-"^50)
    
    all_min_eigenvals = extract_all_eigenvalues(df_enhanced, :minimum)
    all_saddle_eigenvals = extract_all_eigenvalues(df_enhanced, :saddle)  
    all_max_eigenvals = extract_all_eigenvalues(df_enhanced, :maximum)
    
    zero_tol = 1e-8
    
    if !isempty(all_min_eigenvals)
        positive_rate = sum(all_min_eigenvals .> zero_tol) / length(all_min_eigenvals)
        status = positive_rate > 0.9 ? "✓ PASS" : "✗ FAIL"
        println("Minima positive eigenvalue rate: $(round(100*positive_rate, digits=1))% $status")
    end
    
    if !isempty(all_max_eigenvals)
        negative_rate = sum(all_max_eigenvals .< -zero_tol) / length(all_max_eigenvals)
        status = negative_rate > 0.9 ? "✓ PASS" : "✗ FAIL"
        println("Maxima negative eigenvalue rate: $(round(100*negative_rate, digits=1))% $status")
    end
    
    if !isempty(all_saddle_eigenvals)
        has_positive = sum(all_saddle_eigenvals .> zero_tol) > 0
        has_negative = sum(all_saddle_eigenvals .< -zero_tol) > 0
        mixed_signs = has_positive && has_negative
        status = mixed_signs ? "✓ PASS" : "✗ FAIL"
        println("Saddle points have mixed signs: $status")
    end
    
    # Condition number analysis
    println("\n" * "-"^30)
    println("NUMERICAL STABILITY")
    println("-"^30)
    
    all_condition_numbers = filter(!isnan, df_enhanced.hessian_condition_number)
    if !isempty(all_condition_numbers)
        excellent = sum(all_condition_numbers .< 1e3)
        good = sum(1e3 .<= all_condition_numbers .< 1e6)
        poor = sum(all_condition_numbers .>= 1e6)
        
        total = length(all_condition_numbers)
        println("Condition number quality:")
        println("  Excellent (< 1e3): $excellent ($(round(100*excellent/total, digits=1))%)")
        println("  Good (1e3-1e6): $good ($(round(100*good/total, digits=1))%)")
        println("  Poor (≥ 1e6): $poor ($(round(100*poor/total, digits=1))%)")
        
        overall_quality = if excellent/total > 0.5
            "EXCELLENT"
        elseif (excellent + good)/total > 0.8
            "GOOD"
        else
            "NEEDS ATTENTION"
        end
        println("  Overall quality: $overall_quality")
    end
end

println("\n" * "="^60)
println("EIGENVALUE ANALYSIS DEMO COMPLETE")
println("="^60)
println("This demonstration shows:")
println("  • Eigenvalue extraction and distribution analysis")
println("  • Text-based histogram visualization")
println("  • Mathematical validation of critical point types")
println("  • Numerical stability assessment")
println("  • Multi-function comparative analysis")

nothing  # Suppress final output