# debug_subdomain_assignment.jl - Debug script to analyze subdomain assignment issues
# 
# This script loads theoretical critical points and analyzes how they're assigned to subdomains
# to understand why we're seeing 9 subdomains each with 1 minimum instead of 9 minima total.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared utilities
include("../src/Common4DDeuflhard.jl")
include("../src/SubdomainManagement.jl")
include("../src/TheoreticalPoints.jl")
using .Common4DDeuflhard
using .SubdomainManagement: Subdomain, generate_16_subdivisions_orthant, assign_point_to_unique_subdomain, is_point_in_subdomain
using .TheoreticalPoints

using LinearAlgebra
using Printf

println("=" ^ 80)
println("SUBDOMAIN ASSIGNMENT DEBUG ANALYSIS")
println("=" ^ 80)

# 1. Generate the 16 subdomains
println("\n1. GENERATING SUBDOMAINS FOR (+,-,+,-) ORTHANT")
println("-"^40)
subdomains = generate_16_subdivisions_orthant()

println("Generated $(length(subdomains)) subdomains")
println("\nSubdomain bounds:")
for subdomain in subdomains
    println("  $(subdomain.label): ", subdomain.bounds)
end

# 2. Load theoretical critical points for the orthant
println("\n2. LOADING THEORETICAL CRITICAL POINTS")
println("-"^40)
theoretical_points, theoretical_values, theoretical_types, theoretical_4d_types = load_theoretical_4d_points_orthant()

println("Total theoretical points: $(length(theoretical_points))")

# Count by type
min_count = sum(theoretical_4d_types .== "min")
max_count = sum(theoretical_4d_types .== "max")
saddle_count = sum(theoretical_4d_types .== "saddle")

println("  Minima: $min_count")
println("  Maxima: $max_count")
println("  Saddles: $saddle_count")

# 3. Show all theoretical minimizers
println("\n3. THEORETICAL MINIMIZERS")
println("-"^40)
min_indices = findall(theoretical_4d_types .== "min")
println("Found $(length(min_indices)) theoretical minimizers:")

for (i, idx) in enumerate(min_indices)
    pt = theoretical_points[idx]
    val = theoretical_values[idx]
    type_label = theoretical_types[idx]
    println("  Min $i: [$(join([@sprintf("%.4f", x) for x in pt], ", "))] f=$(Printf.@sprintf("%.6f", val)) type=$type_label")
end

# 4. Assign each point to a subdomain using both methods
println("\n4. SUBDOMAIN ASSIGNMENT ANALYSIS")
println("-"^40)

# Method 1: Using is_point_in_subdomain with tolerance
println("\nMethod 1: is_point_in_subdomain (tolerance=0.0)")
assignment_count = zeros(Int, length(subdomains))
min_assignment_count = zeros(Int, length(subdomains))

for (pt_idx, point) in enumerate(theoretical_points)
    is_min = theoretical_4d_types[pt_idx] == "min"
    assigned = false
    
    for (sd_idx, subdomain) in enumerate(subdomains)
        if is_point_in_subdomain(point, subdomain, tolerance=0.0)
            assignment_count[sd_idx] += 1
            if is_min
                min_assignment_count[sd_idx] += 1
            end
            assigned = true
        end
    end
    
    if !assigned && is_min
        println("WARNING: Minimizer not assigned to any subdomain!")
        println("  Point: [$(join([@sprintf("%.4f", x) for x in point], ", "))]")
    end
end

println("\nSubdomain assignment counts (Method 1):")
for (sd_idx, subdomain) in enumerate(subdomains)
    if assignment_count[sd_idx] > 0
        println("  $(subdomain.label): $(assignment_count[sd_idx]) points ($(min_assignment_count[sd_idx]) minima)")
    end
end

# Method 2: Using assign_point_to_unique_subdomain
println("\nMethod 2: assign_point_to_unique_subdomain")
unique_assignment_count = zeros(Int, length(subdomains))
unique_min_assignment_count = zeros(Int, length(subdomains))
unassigned_minima = []

for (pt_idx, point) in enumerate(theoretical_points)
    is_min = theoretical_4d_types[pt_idx] == "min"
    assigned_subdomain = assign_point_to_unique_subdomain(point, subdomains)
    
    if assigned_subdomain !== nothing
        sd_idx = findfirst(sd -> sd.label == assigned_subdomain.label, subdomains)
        unique_assignment_count[sd_idx] += 1
        if is_min
            unique_min_assignment_count[sd_idx] += 1
        end
    elseif is_min
        push!(unassigned_minima, (point, theoretical_types[pt_idx]))
    end
end

println("\nSubdomain assignment counts (Method 2):")
for (sd_idx, subdomain) in enumerate(subdomains)
    if unique_assignment_count[sd_idx] > 0
        println("  $(subdomain.label): $(unique_assignment_count[sd_idx]) points ($(unique_min_assignment_count[sd_idx]) minima)")
    end
end

if !isempty(unassigned_minima)
    println("\nWARNING: $(length(unassigned_minima)) minimizers not assigned to any subdomain!")
    for (pt, type_label) in unassigned_minima
        println("  [$(join([@sprintf("%.4f", x) for x in pt], ", "))] type=$type_label")
    end
end

# 5. Detailed analysis of minimizer positions
println("\n5. DETAILED MINIMIZER POSITION ANALYSIS")
println("-"^40)

# Check if minimizers are on subdomain boundaries
boundary_tolerance = 1e-10
on_boundary_count = 0

for (i, idx) in enumerate(min_indices)
    pt = theoretical_points[idx]
    type_label = theoretical_types[idx]
    
    println("\nMinimizer $i: $type_label")
    println("  Coordinates: [$(join([@sprintf("%.6f", x) for x in pt], ", "))]")
    
    # Check each subdomain
    candidate_subdomains = String[]
    for subdomain in subdomains
        # Check if point is inside subdomain
        inside = true
        on_boundary = false
        
        for (dim, coord) in enumerate(pt)
            lower, upper = subdomain.bounds[dim]
            if coord < lower || coord > upper
                inside = false
                break
            end
            # Check if on boundary
            if abs(coord - lower) < boundary_tolerance || abs(coord - upper) < boundary_tolerance
                on_boundary = true
            end
        end
        
        if inside
            push!(candidate_subdomains, subdomain.label)
            if on_boundary
                on_boundary_count += 1
            end
        end
    end
    
    println("  Can be assigned to: [$(join(candidate_subdomains, ", "))]")
    assigned = assign_point_to_unique_subdomain(pt, subdomains)
    if assigned !== nothing
        println("  Uniquely assigned to: $(assigned.label)")
    else
        println("  WARNING: Not assigned to any subdomain!")
    end
end

println("\nMinimizers on subdomain boundaries: $on_boundary_count")

# 6. Check subdomain coverage
println("\n6. SUBDOMAIN COVERAGE CHECK")
println("-"^40)

# Check if all subdomains that should have minimizers actually do
expected_subdomains_with_minima = Set{String}()
for (idx, point) in enumerate(theoretical_points)
    if theoretical_4d_types[idx] == "min"
        assigned = assign_point_to_unique_subdomain(point, subdomains)
        if assigned !== nothing
            push!(expected_subdomains_with_minima, assigned.label)
        end
    end
end

println("Subdomains that should contain minimizers: $(length(expected_subdomains_with_minima))")
println("Labels: $(sort(collect(expected_subdomains_with_minima)))")

# 7. Visualize the 2D projections
println("\n7. 2D PROJECTION ANALYSIS")
println("-"^40)

# Project to (x1,x2) and (x3,x4) planes
println("\nProjection to (x1,x2) plane:")
x12_positions = Set{Tuple{Float64,Float64}}()
for idx in min_indices
    pt = theoretical_points[idx]
    push!(x12_positions, (pt[1], pt[2]))
end
println("Unique (x1,x2) positions: $(length(x12_positions))")
for (x1, x2) in sort(collect(x12_positions))
    println("  ($(Printf.@sprintf("%.4f", x1)), $(Printf.@sprintf("%.4f", x2)))")
end

println("\nProjection to (x3,x4) plane:")
x34_positions = Set{Tuple{Float64,Float64}}()
for idx in min_indices
    pt = theoretical_points[idx]
    push!(x34_positions, (pt[3], pt[4]))
end
println("Unique (x3,x4) positions: $(length(x34_positions))")
for (x3, x4) in sort(collect(x34_positions))
    println("  ($(Printf.@sprintf("%.4f", x3)), $(Printf.@sprintf("%.4f", x4)))")
end

println("\n" * "=" * 80)
println("ANALYSIS COMPLETE")
println("=" * 80)