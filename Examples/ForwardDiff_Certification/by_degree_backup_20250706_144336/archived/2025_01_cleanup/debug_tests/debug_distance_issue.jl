using Pkg; Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using CSV, DataFrames
using LinearAlgebra
using DynamicPolynomials
using Statistics

include("shared/SubdomainManagement.jl")
using .SubdomainManagement

# Define the 4D Deuflhard composite function
function deuflhard_4d_composite(x)
    x1, x2, x3, x4 = x
    
    # Compute Deuflhard for (x1, x2) and (x3, x4)
    d1 = (x1^2 + x2^2 - 1)^2 / 4 + (x1 - 0.6)^2 + (x2 - 0.4)^2
    d2 = (x3^2 + x4^2 - 1)^2 / 4 + (x3 - 0.6)^2 + (x4 - 0.4)^2
    
    # Composite function
    return d1 + d2
end

# Load the true minimizers
true_minimizers = []
csv_data = CSV.read(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"), DataFrame)
for row in eachrow(csv_data)
    if row.is_minimizer
        push!(true_minimizers, [row.x1, row.x2, row.x3, row.x4])
    end
end

println("Number of true minimizers: ", length(true_minimizers))
println("\nTrue minimizer locations:")
for (i, pt) in enumerate(true_minimizers)
    println("  $i: ", pt)
end

# Generate subdomains and check coverage
subdomains = generate_16_subdivisions_orthant()
println("\n\nSubdomain bounds:")
for subdomain in subdomains
    println("\nSubdomain $(subdomain.label):")
    println("  Center: ", subdomain.center)
    println("  Bounds: ", subdomain.bounds)
end

# Check which true minimizers are in which subdomains
println("\n\nTrue minimizers in subdomains:")
for (i, true_min) in enumerate(true_minimizers)
    assigned_subdomain = assign_point_to_unique_subdomain(true_min, subdomains)
    if assigned_subdomain !== nothing
        println("  Minimizer $i at $true_min -> Subdomain $(assigned_subdomain.label)")
    else
        println("  Minimizer $i at $true_min -> NOT IN ANY SUBDOMAIN!")
    end
end

# Now let's analyze a specific subdomain with degree 10
degree = 10
gn = 30
subdomain = subdomains[1]  # First subdomain

println("\n\nAnalyzing subdomain $(subdomain.label) with degree $degree:")
println("  Center: ", subdomain.center)
println("  Range: ", subdomain.range)
println("  Bounds: ", subdomain.bounds)

# Construct approximant
TR = test_input(
    deuflhard_4d_composite,
    dim = 4,
    center = subdomain.center,
    sample_range = subdomain.range,
    GN = gn
)

pol = Constructor(TR, degree, verbose=0)
println("\n  L2 norm: ", pol.nrm)
println("  Actual degree: ", pol.degree isa Tuple ? pol.degree[2] : pol.degree)

# Find critical points
@polyvar x[1:4]
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree

df_crit = process_crit_pts(
    solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
    deuflhard_4d_composite,
    TR
)

println("\n  Total critical points found: ", nrow(df_crit))

# Analyze all critical points
all_crit_points = []
points_in_subdomain = []
points_outside = []

for row in eachrow(df_crit)
    pt = [row[Symbol("x$i")] for i in 1:4]
    push!(all_crit_points, pt)
    
    if is_point_in_subdomain(pt, subdomain)
        push!(points_in_subdomain, pt)
    else
        push!(points_outside, pt)
    end
end

println("  Critical points in subdomain: ", length(points_in_subdomain))
println("  Critical points outside subdomain: ", length(points_outside))

# Calculate distances for ALL critical points
println("\n\nDistance analysis for ALL critical points:")
all_min_distances = Float64[]
for crit_pt in all_crit_points
    distances_to_true = [norm(crit_pt - true_min) for true_min in true_minimizers]
    min_dist = minimum(distances_to_true)
    push!(all_min_distances, min_dist)
end

if !isempty(all_min_distances)
    println("  Min distance: ", minimum(all_min_distances))
    println("  Max distance: ", maximum(all_min_distances))
    println("  Mean distance: ", mean(all_min_distances))
    println("  Distances > 1.0: ", count(d -> d > 1.0, all_min_distances))
end

# Now for points in subdomain only
println("\n\nDistance analysis for points IN SUBDOMAIN only:")
subdomain_min_distances = Float64[]
for crit_pt in points_in_subdomain
    distances_to_true = [norm(crit_pt - true_min) for true_min in true_minimizers]
    min_dist = minimum(distances_to_true)
    push!(subdomain_min_distances, min_dist)
end

if !isempty(subdomain_min_distances)
    println("  Min distance: ", minimum(subdomain_min_distances))
    println("  Max distance: ", maximum(subdomain_min_distances))
    println("  Mean distance: ", mean(subdomain_min_distances))
    println("  Distances > 1.0: ", count(d -> d > 1.0, subdomain_min_distances))
end

# Show some points with large distances
println("\n\nPoints with large distances (> 1.0):")
for (i, crit_pt) in enumerate(all_crit_points)
    if all_min_distances[i] > 1.0
        in_subdomain = crit_pt in points_in_subdomain
        println("  Point: ", crit_pt)
        println("    Distance to nearest true min: ", all_min_distances[i])
        println("    In subdomain: ", in_subdomain)
        if !in_subdomain
            # Check which subdomain it would belong to
            assigned = assign_point_to_unique_subdomain(crit_pt, subdomains)
            if assigned !== nothing
                println("    Would belong to subdomain: ", assigned.label)
            else
                println("    Not in any subdomain!")
            end
        end
    end
end