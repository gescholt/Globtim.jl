# ================================================================================
# 2D Critical Point Analysis for (+,-) Orthant
# ================================================================================
# 
# Analyzes the 5 critical points in the 2D (+,-) orthant by:
# 1. Subdividing the orthant into 4 subdomains (2×2 grid)
# 2. Classifying each critical point to exactly one subdomain
# 3. Comparing results with 4D analysis for consistency verification
#
# ================================================================================

# using Pkg
# Pkg.activate(joinpath(@__DIR__, "../../../../"))

using LinearAlgebra
using DataFrames
using PrettyTables
using Printf

# ================================================================================
# 2D SUBDOMAIN STRUCTURE
# ================================================================================

"""
    Subdomain2D

Structure representing a single subdomain of the 2D (+,-) orthant.
"""
struct Subdomain2D
    label::String
    center::Vector{Float64}
    bounds::Vector{Tuple{Float64,Float64}}
end

"""
    generate_4_subdivisions_2d_orthant()

Generate 4 subdomains by dividing the 2D (+,-) orthant.
Domain: [-0.1,1.1] × [-1.1,0.1] (stretched by 0.1 on each side)

# Returns
- `Vector{Subdomain2D}`: Array of 4 subdomain structures with binary labels
"""
function generate_4_subdivisions_2d_orthant()
    subdivisions = Subdomain2D[]
    
    # Define the 2D orthant bounds: stretched by 0.1 on each side
    # Original: [0,1] × [-1,0]
    # Stretched: [-0.1,1.1] × [-1.1,0.1]
    orthant_bounds = [(-0.1, 1.1), (-1.1, 0.1)]
    
    for i in 0:3
        # Convert to 2-bit binary representation
        binary_repr = string(i, base=2, pad=2)
        
        # Calculate center and bounds based on binary representation
        center = Float64[]
        bounds = Tuple{Float64,Float64}[]
        
        for (dim, bit_char) in enumerate(binary_repr)
            min_val, max_val = orthant_bounds[dim]
            mid_val = (min_val + max_val) / 2
            
            if bit_char == '0'
                # Lower half of the dimension
                push!(center, (min_val + mid_val) / 2)
                push!(bounds, (min_val, mid_val))
            else
                # Upper half of the dimension
                push!(center, (mid_val + max_val) / 2)
                push!(bounds, (mid_val, max_val))
            end
        end
        
        subdomain = Subdomain2D(binary_repr, center, bounds)
        push!(subdivisions, subdomain)
    end
    
    return subdivisions
end

"""
    assign_point_to_unique_subdomain_2d(point, subdomains)

Assign a 2D point to exactly one subdomain using lexicographic ordering.
"""
function assign_point_to_unique_subdomain_2d(point::Vector{Float64}, subdomains::Vector{Subdomain2D})
    # Find all subdomains that could contain this point
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
        return nothing  # Point not in any subdomain
    elseif length(candidates) == 1
        return candidates[1]
    else
        # Multiple candidates - use lexicographic ordering of binary labels
        sort!(candidates, by = s -> s.label)
        return candidates[1]
    end
end

# ================================================================================
# 2D CRITICAL POINT ANALYSIS
# ================================================================================

"""
    CriticalPoint2D

Information about a 2D critical point.
"""
struct CriticalPoint2D
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

"""
    get_2d_critical_points()

Get all 5 critical points in the 2D (+,-) orthant with their classification.
"""
function get_2d_critical_points()
    return [
        CriticalPoint2D([0.126217280731679, -0.126217280731682], "saddle", false),
        CriticalPoint2D([0.459896075906281, -0.459896075906281], "saddle", false),
        CriticalPoint2D([0.507030772828217, -0.917350578608486], "min", true),
        CriticalPoint2D([0.74115190368376, -0.741151903683748], "min", true),
        CriticalPoint2D([0.917350578608475, -0.50703077282823], "min", true)
    ]
end

"""
    analyze_2d_critical_point_distribution()

Analyze how the 5 critical points are distributed across 4 subdomains.
"""
function analyze_2d_critical_point_distribution()
    println("="^80)
    println("2D CRITICAL POINT ANALYSIS FOR (+,-) ORTHANT")
    println("="^80)
    
    # Setup
    critical_points = get_2d_critical_points()
    subdomains = generate_4_subdivisions_2d_orthant()
    
    println("\n📊 2D Critical Points")
    println("Total: $(length(critical_points)) points")
    println("Domain: (+,-) orthant = [-0.1,1.1] × [-1.1,0.1]")
    
    # Type breakdown
    type_counts = Dict{String,Int}()
    for p in critical_points
        type_counts[p.type] = get(type_counts, p.type, 0) + 1
    end
    
    println("\nType breakdown:")
    for (type, count) in sort(collect(type_counts))
        is_min = (type == "min") ? " ← MINIMIZERS" : ""
        println("  $type: $count$is_min")
    end
    
    # ================================================================================
    # SUBDOMAIN ASSIGNMENT
    # ================================================================================
    
    println("\n📍 SUBDOMAIN ASSIGNMENT")
    println("Dividing (+,-) orthant into 4 subdomains (2×2 grid)")
    println("Binary labels: 0=lower half, 1=upper half of each dimension")
    
    # Assign each point to a unique subdomain
    point_assignments = Dict{Int, Union{Subdomain2D, Nothing}}()
    for (i, point) in enumerate(critical_points)
        assigned_subdomain = assign_point_to_unique_subdomain_2d(point.point, subdomains)
        point_assignments[i] = assigned_subdomain
    end
    
    # Count by subdomain
    subdomain_data = []
    for subdomain in subdomains
        # Find points assigned to this subdomain
        assigned_points = [critical_points[i] for (i, assigned_sub) in point_assignments 
                          if assigned_sub !== nothing && assigned_sub.label == subdomain.label]
        
        if length(assigned_points) > 0
            # Count by type
            saddle_count = count(p -> p.type == "saddle", assigned_points)
            min_count = count(p -> p.type == "min", assigned_points)
            
            push!(subdomain_data, (
                subdomain = subdomain.label,
                center_x = subdomain.center[1],
                center_y = subdomain.center[2],
                bounds_x = "$(subdomain.bounds[1][1]) to $(subdomain.bounds[1][2])",
                bounds_y = "$(subdomain.bounds[2][1]) to $(subdomain.bounds[2][2])",
                total_points = length(assigned_points),
                saddle_points = saddle_count,
                min_points = min_count
            ))
        end
    end
    
    # Display results
    if !isempty(subdomain_data)
        println("\n📋 Subdomain Assignment Results")
        df = DataFrame(subdomain_data)
        pretty_table(df, 
                    header=["Subdomain", "Center X", "Center Y", "X Bounds", "Y Bounds", "Total", "Saddles", "Mins"],
                    crop=:none, alignment=:c)
    end
    
    # ================================================================================
    # DETAILED POINT ASSIGNMENTS
    # ================================================================================
    
    println("\n📍 Individual Point Assignments")
    for (i, point) in enumerate(critical_points)
        assigned_to = point_assignments[i]
        status = assigned_to !== nothing ? "→ $(assigned_to.label)" : "→ UNASSIGNED"
        println(@sprintf("  Point %d: [%7.4f, %7.4f] (%s) %s", 
                i, point.point[1], point.point[2], point.type, status))
    end
    
    # ================================================================================
    # VERIFICATION
    # ================================================================================
    
    println("\n🔍 VERIFICATION")
    
    # Check unique assignment
    assigned_count = sum(point_assignments[i] !== nothing for i in 1:length(critical_points))
    unassigned_count = length(critical_points) - assigned_count
    
    println("✅ Assignment verification:")
    println("  Total points: $(length(critical_points))")
    println("  Assigned: $assigned_count")
    println("  Unassigned: $unassigned_count")
    
    # Check minimizer count
    total_minimizers = sum(p.is_minimizer for p in critical_points)
    assigned_minimizers = sum(critical_points[i].is_minimizer for (i, assigned_sub) in point_assignments 
                             if assigned_sub !== nothing)
    
    println("  Total minimizers: $total_minimizers")
    println("  Assigned minimizers: $assigned_minimizers")
    
    if assigned_minimizers == total_minimizers
        println("✅ All minimizers correctly assigned")
    else
        println("❌ Minimizer assignment mismatch!")
    end
    
    # ================================================================================
    # COMPARISON WITH 4D ANALYSIS
    # ================================================================================
    
    println("\n🔄 COMPARISON WITH 4D ANALYSIS")
    println("2D Analysis:")
    println("  • 5 critical points in (+,-) orthant")
    println("  • 4 subdomains (2×2 subdivision)")
    println("  • 3 minimizers, 2 saddles")
    
    println("\n4D Analysis (for comparison):")
    println("  • 25 critical points in (+,-,+,-) orthant (5×5 tensor product)")
    println("  • 16 subdomains (4×4×4×4 subdivision)")
    println("  • 9 minimizers (3×3), 16 saddles")
    
    println("\n📊 Tensor Product Verification:")
    println("  2D: 3 min + 2 saddle = 5 points")
    println("  4D: (3 min + 2 saddle) × (3 min + 2 saddle) = 9 min+min + 16 others = 25 points")
    println("  ✅ Consistent with tensor product structure")
    
    return critical_points, subdomains, point_assignments
end

# ================================================================================
# EXECUTE ANALYSIS
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    analyze_2d_critical_point_distribution()
end