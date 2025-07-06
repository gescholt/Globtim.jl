# ================================================================================
# Run 2D vs 4D Critical Point Analysis - Display Only (No File Saving)
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using LinearAlgebra
using DataFrames
using PrettyTables
using Printf

# ================================================================================
# LOAD MODULES ONCE TO AVOID CONFLICTS
# ================================================================================

include("shared/SubdomainManagement.jl")
using .SubdomainManagement

# ================================================================================
# 2D STRUCTURES AND FUNCTIONS
# ================================================================================

struct Subdomain2D
    label::String
    center::Vector{Float64}
    bounds::Vector{Tuple{Float64,Float64}}
end

struct CriticalPoint2D
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

function generate_4_subdivisions_2d_orthant()
    subdivisions = Subdomain2D[]
    orthant_bounds = [(-0.1, 1.1), (-1.1, 0.1)]
    
    for i in 0:3
        binary_repr = string(i, base=2, pad=2)
        center = Float64[]
        bounds = Tuple{Float64,Float64}[]
        
        for (dim, bit_char) in enumerate(binary_repr)
            min_val, max_val = orthant_bounds[dim]
            mid_val = (min_val + max_val) / 2
            
            if bit_char == '0'
                push!(center, (min_val + mid_val) / 2)
                push!(bounds, (min_val, mid_val))
            else
                push!(center, (mid_val + max_val) / 2)
                push!(bounds, (mid_val, max_val))
            end
        end
        
        push!(subdivisions, Subdomain2D(binary_repr, center, bounds))
    end
    
    return subdivisions
end

function assign_point_to_unique_subdomain_2d(point::Vector{Float64}, subdomains::Vector{Subdomain2D})
    candidates = Subdomain2D[]
    
    for subdomain in subdomains
        contains_point = true
        for (dim, coord) in enumerate(point)
            lower, upper = subdomain.bounds[dim]
            if coord < lower || coord > upper
                contains_point = false
                break
            end
        end
        if contains_point
            push!(candidates, subdomain)
        end
    end
    
    if length(candidates) == 0
        return nothing
    elseif length(candidates) == 1
        return candidates[1]
    else
        sort!(candidates, by = s -> s.label)
        return candidates[1]
    end
end

function get_2d_critical_points()
    return [
        CriticalPoint2D([0.126217280731679, -0.126217280731682], "saddle", false),
        CriticalPoint2D([0.459896075906281, -0.459896075906281], "saddle", false),
        CriticalPoint2D([0.507030772828217, -0.917350578608486], "min", true),
        CriticalPoint2D([0.74115190368376, -0.741151903683748], "min", true),
        CriticalPoint2D([0.917350578608475, -0.50703077282823], "min", true)
    ]
end

# ================================================================================
# 4D STRUCTURES
# ================================================================================

struct CriticalPointInfo
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

function generate_all_critical_points_4d()
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),
        ([0.459896075906281, -0.459896075906281], "saddle"),
        ([0.507030772828217, -0.917350578608486], "min"),
        ([0.74115190368376, -0.741151903683748], "min"),
        ([0.917350578608475, -0.50703077282823], "min")
    ]
    
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
# MAIN ANALYSIS FUNCTION
# ================================================================================

function run_complete_analysis()
    println("="^80)
    println("2D vs 4D CRITICAL POINT ANALYSIS")
    println("="^80)
    
    # ================================================================================
    # 2D ANALYSIS
    # ================================================================================
    
    println("\n📊 2D ANALYSIS: (+,-) ORTHANT")
    println("-"^50)
    
    critical_points_2d = get_2d_critical_points()
    subdomains_2d = generate_4_subdivisions_2d_orthant()
    
    println("Domain: [-0.1,1.1] × [-1.1,0.1]")
    println("Total points: $(length(critical_points_2d))")
    
    # Type breakdown
    type_counts_2d = Dict{String,Int}()
    for p in critical_points_2d
        type_counts_2d[p.type] = get(type_counts_2d, p.type, 0) + 1
    end
    
    println("\\nType breakdown:")
    for (type, count) in sort(collect(type_counts_2d))
        is_min = (type == "min") ? " ← MINIMIZERS" : ""
        println("  $type: $count$is_min")
    end
    
    # Assign points to subdomains
    assignments_2d = Dict{Int, Union{Subdomain2D, Nothing}}()
    for (i, point) in enumerate(critical_points_2d)
        assignments_2d[i] = assign_point_to_unique_subdomain_2d(point.point, subdomains_2d)
    end
    
    # Count by subdomain
    subdomain_data_2d = []
    for subdomain in subdomains_2d
        assigned_points = [critical_points_2d[i] for (i, assigned_sub) in assignments_2d 
                          if assigned_sub !== nothing && assigned_sub.label == subdomain.label]
        
        if length(assigned_points) > 0
            saddle_count = count(p -> p.type == "saddle", assigned_points)
            min_count = count(p -> p.type == "min", assigned_points)
            
            push!(subdomain_data_2d, (
                subdomain = subdomain.label,
                total_points = length(assigned_points),
                saddle_points = saddle_count,
                min_points = min_count
            ))
        end
    end
    
    println("\\n2D Subdomain Distribution:")
    if !isempty(subdomain_data_2d)
        df_2d = DataFrame(subdomain_data_2d)
        pretty_table(df_2d, header=["Subdomain", "Total", "Saddles", "Mins"], crop=:none, alignment=:c)
    end
    
    # ================================================================================
    # 4D ANALYSIS
    # ================================================================================
    
    println("\\n📊 4D ANALYSIS: (+,-,+,-) ORTHANT")
    println("-"^50)
    
    critical_points_4d = generate_all_critical_points_4d()
    subdomains_4d = generate_16_subdivisions_orthant()
    
    println("Domain: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]")
    println("Total points: $(length(critical_points_4d)) (5×5 tensor product)")
    
    # Type breakdown
    type_counts_4d = Dict{String,Int}()
    for p in critical_points_4d
        type_counts_4d[p.type] = get(type_counts_4d, p.type, 0) + 1
    end
    
    println("\\nType breakdown:")
    for (type, count) in sort(collect(type_counts_4d))
        is_min = (type == "min+min") ? " ← MINIMIZERS" : ""
        println("  $type: $count$is_min")
    end
    
    # Assign points to subdomains
    assignments_4d = Dict{Int, Union{Subdomain, Nothing}}()
    for (i, point) in enumerate(critical_points_4d)
        assignments_4d[i] = assign_point_to_unique_subdomain(point.point, subdomains_4d)
    end
    
    # Count by subdomain (non-empty only)
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
    
    println("\\n4D Subdomain Distribution (non-empty only):")
    data_4d = []
    for (label, count) in sort(collect(subdomain_counts_4d))
        min_count = get(minimizer_counts_4d, label, 0)
        push!(data_4d, (label, count, min_count))
    end
    
    if !isempty(data_4d)
        df_4d = DataFrame(data_4d, [:subdomain, :total, :minimizers])
        pretty_table(df_4d, header=["Subdomain", "Total", "Minimizers"], crop=:none, alignment=:c)
    end
    
    # ================================================================================
    # CONSISTENCY VERIFICATION
    # ================================================================================
    
    println("\\n🔍 CONSISTENCY VERIFICATION")
    println("-"^50)
    
    # Tensor product verification
    min_2d = sum(p.is_minimizer for p in critical_points_2d)
    saddle_2d = sum(!p.is_minimizer for p in critical_points_2d)
    
    expected_min_min = min_2d * min_2d
    expected_min_saddle = min_2d * saddle_2d
    expected_saddle_min = saddle_2d * min_2d
    expected_saddle_saddle = saddle_2d * saddle_2d
    
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
    pretty_table(df_verification, header=["Type", "Expected", "Actual", "Match"], crop=:none, alignment=:c)
    
    # ================================================================================
    # FINAL SUMMARY
    # ================================================================================
    
    println("\\n🎯 FINAL SUMMARY")
    println("-"^50)
    
    # Consistency checks
    total_2d = length(critical_points_2d)
    total_4d = length(critical_points_4d)
    expected_4d = total_2d * total_2d
    
    min_2d_count = sum(p.is_minimizer for p in critical_points_2d)
    min_4d_count = sum(p.is_minimizer for p in critical_points_4d)
    expected_min_4d = min_2d_count * min_2d_count
    
    assigned_2d = sum(assignments_2d[i] !== nothing for i in 1:length(critical_points_2d))
    assigned_4d = sum(assignments_4d[i] !== nothing for i in 1:length(critical_points_4d))
    
    check1 = total_4d == expected_4d
    check2 = min_4d_count == expected_min_4d
    check3 = assigned_2d == total_2d && assigned_4d == total_4d
    
    println("✅ Total points: 2D=$total_2d, 4D=$total_4d, Expected 4D=$expected_4d $(check1 ? "✅" : "❌")")
    println("✅ Minimizers: 2D=$min_2d_count, 4D=$min_4d_count, Expected 4D=$expected_min_4d $(check2 ? "✅" : "❌")")
    println("✅ Unique assignment: 2D=$assigned_2d/$total_2d, 4D=$assigned_4d/$total_4d $(check3 ? "✅" : "❌")")
    
    all_checks_pass = check1 && check2 && check3
    if all_checks_pass
        println("\\n🎉 ALL CONSISTENCY CHECKS PASSED!")
        println("   • 2D and 4D analyses are mathematically consistent")
        println("   • Tensor product structure is correctly implemented")
        println("   • Subdomain assignment works correctly in both dimensions")
    else
        println("\\n❌ SOME CONSISTENCY CHECKS FAILED!")
    end
    
    println("\\n" * "="^80)
end

# ================================================================================
# RUN THE ANALYSIS
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    run_complete_analysis()
end