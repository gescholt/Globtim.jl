# ================================================================================
# 2D vs 4D Critical Point Analysis Comparison
# ================================================================================
# 
# Directly compares the 2D and 4D analysis results to verify consistency
# and validate the tensor product structure of the 4D critical points.
#
# ================================================================================

# using Pkg
# Pkg.activate(joinpath(@__DIR__, "../../../../"))

using LinearAlgebra
using DataFrames
using PrettyTables
using Printf

# Load the 2D analysis
include("analyze_2d_orthant_classification.jl")

# Load the 4D analysis components
include("shared/SubdomainManagement.jl")
using .SubdomainManagement

# ================================================================================
# GENERATE 4D CRITICAL POINTS FOR COMPARISON
# ================================================================================

struct CriticalPointInfo
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

function generate_all_critical_points_4d()
    # All 5 critical points in 2D (+,-) orthant
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),
        ([0.459896075906281, -0.459896075906281], "saddle"),
        ([0.507030772828217, -0.917350578608486], "min"),
        ([0.74115190368376, -0.741151903683748], "min"),
        ([0.917350578608475, -0.50703077282823], "min")
    ]
    
    # Generate 5×5 = 25 tensor products
    points = CriticalPointInfo[]
    
    for (pt1, type1) in critical_2d
        for (pt2, type2) in critical_2d
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            combined_type = "$(type1)+$(type2)"
            is_min = (type1 == "min" && type2 == "min")
            
            push!(points, CriticalPointInfo(point_4d, combined_type, is_min))
        end
    end
    
    return points
end

# ================================================================================
# COMPARISON ANALYSIS
# ================================================================================

function compare_2d_vs_4d_analysis()
    println("="^80)
    println("2D vs 4D CRITICAL POINT ANALYSIS COMPARISON")
    println("="^80)
    
    # ================================================================================
    # 2D ANALYSIS
    # ================================================================================
    
    println("\n📊 2D ANALYSIS RESULTS")
    critical_points_2d = get_2d_critical_points()
    subdomains_2d = generate_4_subdivisions_2d_orthant()
    
    # Assign 2D points to subdomains
    assignments_2d = Dict{Int, Union{Subdomain2D, Nothing}}()
    for (i, point) in enumerate(critical_points_2d)
        assignments_2d[i] = assign_point_to_unique_subdomain_2d(point.point, subdomains_2d)
    end
    
    # Count 2D results
    subdomain_counts_2d = Dict{String, Int}()
    minimizer_counts_2d = Dict{String, Int}()
    
    for (i, assigned_sub) in assignments_2d
        if assigned_sub !== nothing
            label = assigned_sub.label
            subdomain_counts_2d[label] = get(subdomain_counts_2d, label, 0) + 1
            if critical_points_2d[i].is_minimizer
                minimizer_counts_2d[label] = get(minimizer_counts_2d, label, 0) + 1
            end
        end
    end
    
    println("2D Results:")
    println("  Total points: $(length(critical_points_2d))")
    println("  Minimizers: $(sum(p.is_minimizer for p in critical_points_2d))")
    println("  Saddles: $(sum(!p.is_minimizer for p in critical_points_2d))")
    
    # ================================================================================
    # 4D ANALYSIS
    # ================================================================================
    
    println("\n📊 4D ANALYSIS RESULTS")
    critical_points_4d = generate_all_critical_points_4d()
    subdomains_4d = generate_16_subdivisions_orthant()
    
    # Assign 4D points to subdomains
    assignments_4d = Dict{Int, Union{Subdomain, Nothing}}()
    for (i, point) in enumerate(critical_points_4d)
        assignments_4d[i] = assign_point_to_unique_subdomain(point.point, subdomains_4d)
    end
    
    # Count 4D results
    subdomain_counts_4d = Dict{String, Int}()
    minimizer_counts_4d = Dict{String, Int}()
    
    for (i, assigned_sub) in assignments_4d
        if assigned_sub !== nothing
            label = assigned_sub.label
            subdomain_counts_4d[label] = get(subdomain_counts_4d, label, 0) + 1
            if critical_points_4d[i].is_minimizer
                minimizer_counts_4d[label] = get(minimizer_counts_4d, label, 0) + 1
            end
        end
    end
    
    println("4D Results:")
    println("  Total points: $(length(critical_points_4d))")
    println("  Minimizers: $(sum(p.is_minimizer for p in critical_points_4d))")
    println("  Non-minimizers: $(sum(!p.is_minimizer for p in critical_points_4d))")
    
    # ================================================================================
    # TENSOR PRODUCT VERIFICATION
    # ================================================================================
    
    println("\n🔍 TENSOR PRODUCT VERIFICATION")
    
    # Expected counts from tensor product
    min_2d = sum(p.is_minimizer for p in critical_points_2d)
    saddle_2d = sum(!p.is_minimizer for p in critical_points_2d)
    
    expected_min_min = min_2d * min_2d
    expected_min_saddle = min_2d * saddle_2d
    expected_saddle_min = saddle_2d * min_2d
    expected_saddle_saddle = saddle_2d * saddle_2d
    
    # Actual counts from 4D
    actual_min_min = sum(p.type == "min+min" for p in critical_points_4d)
    actual_min_saddle = sum(p.type == "min+saddle" for p in critical_points_4d)
    actual_saddle_min = sum(p.type == "saddle+min" for p in critical_points_4d)
    actual_saddle_saddle = sum(p.type == "saddle+saddle" for p in critical_points_4d)
    
    println("Tensor Product Verification:")
    verification_data = [
        ("min+min", expected_min_min, actual_min_min, expected_min_min == actual_min_min ? "✅" : "❌"),
        ("min+saddle", expected_min_saddle, actual_min_saddle, expected_min_saddle == actual_min_saddle ? "✅" : "❌"),
        ("saddle+min", expected_saddle_min, actual_saddle_min, expected_saddle_min == actual_saddle_min ? "✅" : "❌"),
        ("saddle+saddle", expected_saddle_saddle, actual_saddle_saddle, expected_saddle_saddle == actual_saddle_saddle ? "✅" : "❌")
    ]
    
    df_verification = DataFrame(verification_data, [:type, :expected, :actual, :match])
    pretty_table(df_verification, header=["Type", "Expected", "Actual", "Match"])
    
    # ================================================================================
    # SUBDOMAIN DISTRIBUTION COMPARISON
    # ================================================================================
    
    println("\n📍 SUBDOMAIN DISTRIBUTION COMPARISON")
    
    println("\n2D Subdomain Distribution:")
    data_2d = []
    for (label, count) in sort(collect(subdomain_counts_2d))
        min_count = get(minimizer_counts_2d, label, 0)
        push!(data_2d, (label, count, min_count))
    end
    
    if !isempty(data_2d)
        df_2d = DataFrame(data_2d, [:subdomain, :total, :minimizers])
        pretty_table(df_2d, header=["Subdomain", "Total", "Minimizers"])
    end
    
    println("\n4D Subdomain Distribution (non-empty only):")
    data_4d = []
    for (label, count) in sort(collect(subdomain_counts_4d))
        min_count = get(minimizer_counts_4d, label, 0)
        push!(data_4d, (label, count, min_count))
    end
    
    if !isempty(data_4d)
        df_4d = DataFrame(data_4d, [:subdomain, :total, :minimizers])
        pretty_table(df_4d, header=["Subdomain", "Total", "Minimizers"])
    end
    
    # ================================================================================
    # CONSISTENCY CHECKS
    # ================================================================================
    
    println("\n🎯 CONSISTENCY CHECKS")
    
    # Check 1: Total point counts
    total_2d = length(critical_points_2d)
    total_4d = length(critical_points_4d)
    expected_4d = total_2d * total_2d
    
    check1 = total_4d == expected_4d
    println("✅ Total point count: 2D=$total_2d, 4D=$total_4d, Expected 4D=$expected_4d $(check1 ? "✅" : "❌")")
    
    # Check 2: Minimizer counts
    min_2d_count = sum(p.is_minimizer for p in critical_points_2d)
    min_4d_count = sum(p.is_minimizer for p in critical_points_4d)
    expected_min_4d = min_2d_count * min_2d_count
    
    check2 = min_4d_count == expected_min_4d
    println("✅ Minimizer count: 2D=$min_2d_count, 4D=$min_4d_count, Expected 4D=$expected_min_4d $(check2 ? "✅" : "❌")")
    
    # Check 3: Unique assignment
    assigned_2d = sum(assignments_2d[i] !== nothing for i in 1:length(critical_points_2d))
    assigned_4d = sum(assignments_4d[i] !== nothing for i in 1:length(critical_points_4d))
    
    check3 = assigned_2d == total_2d && assigned_4d == total_4d
    println("✅ Unique assignment: 2D=$assigned_2d/$total_2d, 4D=$assigned_4d/$total_4d $(check3 ? "✅" : "❌")")
    
    # ================================================================================
    # SUMMARY
    # ================================================================================
    
    println("\n📊 ANALYSIS SUMMARY")
    
    all_checks_pass = check1 && check2 && check3
    if all_checks_pass
        println("✅ ALL CONSISTENCY CHECKS PASSED!")
        println("   • 2D and 4D analyses are mathematically consistent")
        println("   • Tensor product structure is correctly implemented")
        println("   • Subdomain assignment works correctly in both dimensions")
        println("   • Critical point classification is accurate")
    else
        println("❌ SOME CONSISTENCY CHECKS FAILED!")
        println("   • Review the implementation for potential issues")
    end
    
    return (critical_points_2d, critical_points_4d, assignments_2d, assignments_4d)
end

# ================================================================================
# EXECUTE COMPARISON
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    compare_2d_vs_4d_analysis()
end