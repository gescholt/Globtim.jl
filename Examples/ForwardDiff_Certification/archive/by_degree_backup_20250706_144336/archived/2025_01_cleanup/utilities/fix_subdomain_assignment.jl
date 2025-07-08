# ================================================================================
# Fix Subdomain Assignment - Ensure Unique Assignment
# ================================================================================
# 
# This script fixes the subdomain assignment to ensure each critical point
# is assigned to exactly one subdomain by using exclusive boundaries.
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
# CORRECTED SUBDOMAIN ASSIGNMENT FUNCTION
# ================================================================================

"""
Corrected function to check if a point is in a subdomain.
Uses exclusive upper bounds to ensure unique assignment.
"""
function is_point_in_subdomain_exclusive(point::Vector{Float64}, subdomain::Subdomain)
    for (dim, coord) in enumerate(point)
        lower, upper = subdomain.bounds[dim]
        
        # Use inclusive lower bound, exclusive upper bound
        # Exception: for the last subdomain in each dimension, use inclusive upper bound
        if dim == 1
            # For x-dimension: check if this is the rightmost subdomain (binary ends with 1)
            is_rightmost = subdomain.label[1] == '1'
        elseif dim == 2
            # For y-dimension: check if this is the topmost subdomain (binary[2] == '1')
            is_topmost = subdomain.label[2] == '1'
        elseif dim == 3
            # For z-dimension: check if this is the rightmost subdomain (binary[3] == '1')
            is_rightmost_z = subdomain.label[3] == '1'
        elseif dim == 4
            # For w-dimension: check if this is the topmost subdomain (binary[4] == '1')
            is_topmost_w = subdomain.label[4] == '1'
        end
        
        # Determine if this is the boundary subdomain for this dimension
        is_boundary = false
        if dim == 1 && subdomain.label[1] == '1'
            is_boundary = true
        elseif dim == 2 && subdomain.label[2] == '1'
            is_boundary = true
        elseif dim == 3 && subdomain.label[3] == '1'
            is_boundary = true
        elseif dim == 4 && subdomain.label[4] == '1'
            is_boundary = true
        end
        
        # Apply boundary conditions
        if is_boundary
            # For boundary subdomains, use inclusive upper bound
            if coord < lower || coord > upper
                return false
            end
        else
            # For non-boundary subdomains, use exclusive upper bound
            if coord < lower || coord >= upper
                return false
            end
        end
    end
    return true
end

"""
Improved version using lexicographic ordering for tie-breaking.
"""
function assign_point_to_unique_subdomain(point::Vector{Float64}, subdomains::Vector{Subdomain})
    # Find all subdomains that could contain this point
    candidates = Subdomain[]
    
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
        return nothing  # Point not in any subdomain
    elseif length(candidates) == 1
        return candidates[1]
    else
        # Multiple candidates - use lexicographic ordering of binary labels
        # Choose the smallest binary label
        sort!(candidates, by = s -> s.label)
        return candidates[1]
    end
end

# ================================================================================
# VERIFICATION WITH CORRECTED ASSIGNMENT
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

"""
Verify corrected assignment.
"""
function verify_corrected_assignment()
    println("="^80)
    println("CORRECTED CRITICAL POINT ASSIGNMENT VERIFICATION")
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
    # CORRECTED ASSIGNMENT
    # ================================================================================
    
    println("\n📍 CORRECTED ASSIGNMENT TO SUBDOMAINS")
    
    # Track assignments using corrected method
    point_assignments = Dict{Int, Union{String, Nothing}}()
    subdomain_assignments = Dict{String, Vector{Int}}()
    
    # Initialize subdomain assignments
    for subdomain in subdomains
        subdomain_assignments[subdomain.label] = Int[]
    end
    
    for (i, point) in enumerate(theoretical_points)
        assigned_subdomain = assign_point_to_unique_subdomain(point.point, subdomains)
        
        if assigned_subdomain !== nothing
            point_assignments[i] = assigned_subdomain.label
            push!(subdomain_assignments[assigned_subdomain.label], i)
        else
            point_assignments[i] = nothing
        end
    end
    
    # ================================================================================
    # VERIFY UNIQUE ASSIGNMENT
    # ================================================================================
    
    println("\n🔍 ASSIGNMENT VERIFICATION")
    
    # Check results
    unassigned = [i for (i, label) in point_assignments if label === nothing]
    assigned = [i for (i, label) in point_assignments if label !== nothing]
    
    println("✅ Unique assignment results:")
    println("  Assigned points: $(length(assigned))")
    println("  Unassigned points: $(length(unassigned))")
    
    if !isempty(unassigned)
        println("❌ UNASSIGNED POINTS:")
        for idx in unassigned
            pt = theoretical_points[idx]
            println("  Point $idx: $(pt.point) ($(pt.type))")
        end
    end
    
    # ================================================================================
    # DETAILED SUBDOMAIN ANALYSIS
    # ================================================================================
    
    println("\n📋 CORRECTED SUBDOMAIN ASSIGNMENTS")
    
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
    else
        println("✅ Correct number of min+min points")
    end
    
    # Show assignments
    println("\nPoint assignments:")
    for (i, point) in enumerate(theoretical_points)
        assigned_to = point_assignments[i]
        status = assigned_to !== nothing ? "→ $assigned_to" : "→ UNASSIGNED"
        println(@sprintf("  Point %2d: [%6.3f, %6.3f, %6.3f, %6.3f] (%s) %s", 
                i, point.point[1], point.point[2], point.point[3], point.point[4], 
                point.type, status))
    end
    
    # ================================================================================
    # SUMMARY
    # ================================================================================
    
    println("\n📊 SUMMARY")
    println("Total theoretical points: $(length(theoretical_points))")
    println("Points assigned: $(length(assigned))")
    println("Points unassigned: $(length(unassigned))")
    println("Min+min points found: $total_min_min / 9")
    
    return theoretical_points, subdomains, point_assignments
end

# ================================================================================
# RUN VERIFICATION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    theoretical_points, subdomains, assignments = verify_corrected_assignment()
end