# ================================================================================
# Verify Critical Point Assignment to Subdomains
# ================================================================================
# 
# This script isolates and verifies the procedure for assigning the 25 theoretical
# critical points to the 16 subdomains of the (+,-,+,-) orthant.
#
# Key checks:
# 1. Each critical point assigned to exactly one subdomain
# 2. Verify min+min count is exactly 9
# 3. Debug any assignment issues
#
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared utilities
include("shared/Common4DDeuflhard.jl")
include("shared/SubdomainManagement.jl")
using .SubdomainManagement

using LinearAlgebra
using DataFrames
using PrettyTables
using Printf

# ================================================================================
# GENERATE THEORETICAL CRITICAL POINTS
# ================================================================================

"""
Information about a theoretical critical point.
"""
struct CriticalPointInfo
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

"""
Generate all 25 critical points (5×5 tensor product) with classification.
"""
function generate_all_critical_points()
    # All 5 critical points in 2D (+,-) orthant [x>0, y<0]
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),   # Near origin
        ([0.459896075906281, -0.459896075906281], "saddle"),   # Central saddle
        ([0.507030772828217, -0.917350578608486], "min"),      # Minimizer 1
        ([0.74115190368376, -0.741151903683748], "min"),       # Minimizer 2  
        ([0.917350578608475, -0.50703077282823], "min")        # Minimizer 3
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
# ASSIGNMENT VERIFICATION
# ================================================================================

"""
Verify critical point assignment to subdomains.
"""
function verify_assignment()
    println("="^80)
    println("CRITICAL POINT ASSIGNMENT VERIFICATION")
    println("="^80)
    
    # Generate theoretical points
    theoretical_points = generate_all_critical_points()
    subdomains = generate_16_subdivisions_orthant()
    
    println("\n📊 THEORETICAL CRITICAL POINTS")
    println("Total: $(length(theoretical_points)) points")
    
    # Count by type
    type_counts = Dict{String,Int}()
    for p in theoretical_points
        type_counts[p.type] = get(type_counts, p.type, 0) + 1
    end
    
    println("\nType breakdown:")
    for (type, count) in sort(collect(type_counts))
        is_min = (type == "min+min") ? " ← MINIMIZERS" : ""
        println("  $type: $count$is_min")
    end
    
    # ================================================================================
    # ASSIGNMENT CHECK
    # ================================================================================
    
    println("\n📍 ASSIGNMENT TO SUBDOMAINS")
    println("Full orthant domain: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]")
    
    # Track assignments
    assignment_count = zeros(Int, length(theoretical_points))
    subdomain_assignments = Dict{String, Vector{Int}}()
    
    for (i, subdomain) in enumerate(subdomains)
        subdomain_assignments[subdomain.label] = Int[]
        
        for (j, point) in enumerate(theoretical_points)
            if is_point_in_subdomain(point.point, subdomain)
                assignment_count[j] += 1
                push!(subdomain_assignments[subdomain.label], j)
            end
        end
    end
    
    # ================================================================================
    # VERIFY SINGLE ASSIGNMENT
    # ================================================================================
    
    println("\n🔍 ASSIGNMENT VERIFICATION")
    
    # Check each point is assigned to exactly one subdomain
    unassigned = findall(x -> x == 0, assignment_count)
    multiply_assigned = findall(x -> x > 1, assignment_count)
    
    if !isempty(unassigned)
        println("❌ UNASSIGNED POINTS:")
        for idx in unassigned
            pt = theoretical_points[idx]
            println("  Point $idx: $(pt.point) ($(pt.type))")
        end
    end
    
    if !isempty(multiply_assigned)
        println("❌ MULTIPLY ASSIGNED POINTS:")
        for idx in multiply_assigned
            pt = theoretical_points[idx]
            println("  Point $idx: $(pt.point) ($(pt.type)) - assigned $(assignment_count[idx]) times")
            
            # Show which subdomains claim this point
            claiming_subdomains = String[]
            for (label, assignments) in subdomain_assignments
                if idx in assignments
                    push!(claiming_subdomains, label)
                end
            end
            println("    Claimed by: $(join(claiming_subdomains, ", "))")
        end
    end
    
    if isempty(unassigned) && isempty(multiply_assigned)
        println("✅ All points assigned to exactly one subdomain")
    end
    
    # ================================================================================
    # DETAILED SUBDOMAIN ANALYSIS
    # ================================================================================
    
    println("\n📋 DETAILED SUBDOMAIN ASSIGNMENTS")
    
    subdomain_data = []
    total_min_min = 0
    
    for subdomain in subdomains
        assigned_indices = subdomain_assignments[subdomain.label]
        assigned_points = [theoretical_points[i] for i in assigned_indices]
        
        # Count by type
        type_counts_sub = Dict{String,Int}()
        for p in assigned_points
            type_counts_sub[p.type] = get(type_counts_sub, p.type, 0) + 1
        end
        
        # Count minimizers
        minimizers = count(p -> p.is_minimizer, assigned_points)
        total_min_min += minimizers
        
        if length(assigned_points) > 0
            push!(subdomain_data, (
                subdomain = subdomain.label,
                total_points = length(assigned_points),
                minimizers = minimizers,
                saddle_saddle = get(type_counts_sub, "saddle+saddle", 0),
                saddle_min = get(type_counts_sub, "saddle+min", 0),
                min_saddle = get(type_counts_sub, "min+saddle", 0),
                min_min = get(type_counts_sub, "min+min", 0)
            ))
        end
    end
    
    # Show table
    if !isempty(subdomain_data)
        df = DataFrame(subdomain_data)
        pretty_table(df, 
                    header=["Subdomain", "Total", "Minimizers", "S+S", "S+M", "M+S", "M+M"],
                    crop=:none, alignment=:c)
    end
    
    # ================================================================================
    # VERIFY MIN+MIN COUNT
    # ================================================================================
    
    println("\n🎯 MIN+MIN VERIFICATION")
    println("Expected min+min points: 9 (3×3 from 2D)")
    println("Actual min+min points assigned: $total_min_min")
    
    if total_min_min != 9
        println("❌ MISMATCH! Expected 9 min+min points, found $total_min_min")
        
        # Show all min+min points
        println("\nAll min+min points:")
        for (i, point) in enumerate(theoretical_points)
            if point.is_minimizer
                assigned_to = ""
                for (label, assignments) in subdomain_assignments
                    if i in assignments
                        assigned_to = label
                        break
                    end
                end
                println("  Point $i: $(point.point) → $assigned_to")
            end
        end
    else
        println("✅ Correct number of min+min points")
    end
    
    # ================================================================================
    # SUMMARY
    # ================================================================================
    
    println("\n📊 SUMMARY")
    println("Total theoretical points: $(length(theoretical_points))")
    println("Points assigned: $(sum(assignment_count .> 0))")
    println("Points unassigned: $(length(unassigned))")
    println("Points multiply assigned: $(length(multiply_assigned))")
    println("Min+min points found: $total_min_min / 9")
    
    return theoretical_points, subdomains, subdomain_assignments
end

# ================================================================================
# DETAILED POINT INSPECTION
# ================================================================================

"""
Show detailed information about each critical point.
"""
function inspect_critical_points()
    theoretical_points = generate_all_critical_points()
    subdomains = generate_16_subdivisions_orthant()
    
    println("\n🔍 DETAILED POINT INSPECTION")
    println("="^80)
    
    for (i, point) in enumerate(theoretical_points)
        println(@sprintf("Point %2d: [%6.3f, %6.3f, %6.3f, %6.3f] (%s)", 
                i, point.point[1], point.point[2], point.point[3], point.point[4], point.type))
        
        # Check which subdomains contain this point
        containing_subdomains = String[]
        for subdomain in subdomains
            if is_point_in_subdomain(point.point, subdomain)
                push!(containing_subdomains, subdomain.label)
            end
        end
        
        if length(containing_subdomains) == 0
            println("  ❌ Not in any subdomain!")
        elseif length(containing_subdomains) == 1
            println("  ✅ In subdomain: $(containing_subdomains[1])")
        else
            println("  ❌ In multiple subdomains: $(join(containing_subdomains, ", "))")
        end
        println()
    end
end

# ================================================================================
# RUN VERIFICATION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    theoretical_points, subdomains, assignments = verify_assignment()
    inspect_critical_points()
end