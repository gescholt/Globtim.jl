using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Add shared utilities
include("shared/Common4DDeuflhard.jl")
include("shared/SubdomainManagement.jl")
using .Common4DDeuflhard
using .SubdomainManagement

using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames, CSV
using Statistics
using Printf

println("="^80)
println("DEBUG: Zero Recovery Issue Analysis")
println("="^80)

# Load true minimizers
true_minimizers_df = CSV.read(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"), DataFrame)
true_minimizers = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(true_minimizers_df)]

println("\n1. TRUE MINIMIZERS FROM CSV:")
for (i, pt) in enumerate(true_minimizers)
    println("   $i: [$(join([@sprintf("%.6f", x) for x in pt], ", "))]")
end

# Test one subdomain with degree 4
subdomains = generate_16_subdivisions_orthant()
test_subdomain = subdomains[11]  # "1010" - known to have theoretical points

println("\n2. TEST SUBDOMAIN (1010):")
println("   Center: [$(join([@sprintf("%.6f", x) for x in test_subdomain.center], ", "))]")
println("   Range: $(test_subdomain.range)")
println("   Bounds:")
for (dim, (lower, upper)) in enumerate(test_subdomain.bounds)
    println("      Dim $dim: [$(@sprintf("%.6f", lower)), $(@sprintf("%.6f", upper))]")
end

# Create Globtim approximant
TR = test_input(
    deuflhard_4d_composite,
    dim = 4,
    center = test_subdomain.center,
    sample_range = test_subdomain.range,
    GN = 16
)

println("\n3. GLOBTIM TEST_INPUT:")
println("   Center: [$(join([@sprintf("%.6f", x) for x in TR.center], ", "))]")
println("   Sample range: $(TR.sample_range)")

pol = Constructor(TR, 4, verbose=0)
println("   Polynomial L²-norm: $(@sprintf("%.6e", pol.nrm))")

# Find critical points
@polyvar x[1:4]
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
df_crit = process_crit_pts(
    solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
    deuflhard_4d_composite,
    TR
)

println("\n4. CRITICAL POINTS FOUND:")
println("   Total critical points: $(nrow(df_crit))")

# Extract points in subdomain
subdomain_points = Vector{Vector{Float64}}()
for row in eachrow(df_crit)
    pt = [row[Symbol("x$i")] for i in 1:4]
    if is_point_in_subdomain(pt, test_subdomain)
        push!(subdomain_points, pt)
    end
end

println("   Points in subdomain: $(length(subdomain_points))")
for (i, pt) in enumerate(subdomain_points)
    println("      $i: [$(join([@sprintf("%.6f", x) for x in pt], ", "))]")
end

# Test different thresholds
println("\n5. DISTANCE ANALYSIS:")
thresholds = [1e-1, 1e-2, 1e-3, 1e-4, 1e-5]

for threshold in thresholds
    recovered = 0
    min_distances = Float64[]
    
    for true_min in true_minimizers
        if !isempty(subdomain_points)
            distances = [norm(cp - true_min) for cp in subdomain_points]
            min_dist = minimum(distances)
            push!(min_distances, min_dist)
            if min_dist < threshold
                recovered += 1
            end
        end
    end
    
    avg_dist = isempty(min_distances) ? Inf : mean(min_distances)
    min_dist = isempty(min_distances) ? Inf : minimum(min_distances)
    
    println("   Threshold $(@sprintf("%.0e", threshold)): recovered=$recovered/$(length(true_minimizers)), avg_dist=$(@sprintf("%.6e", avg_dist)), min_dist=$(@sprintf("%.6e", min_dist))")
end

# Check if any computed points are close to theoretical ones
println("\n6. DETAILED DISTANCE MATRIX:")
println("   Rows: True minimizers, Columns: Computed points")
if !isempty(subdomain_points)
    for (i, true_min) in enumerate(true_minimizers)
        distances = [norm(cp - true_min) for cp in subdomain_points]
        println("   True $i: [$(join([@sprintf("%.2e", d) for d in distances], ", "))]")
    end
else
    println("   No computed points in subdomain!")
end

# Check coordinate system consistency
println("\n7. COORDINATE SYSTEM CHECK:")
println("   Evaluating function at true minimizers:")
for (i, pt) in enumerate(true_minimizers)
    fval = deuflhard_4d_composite(pt)
    println("   True $i: f(x) = $(@sprintf("%.6e", fval))")
end

println("\n   Evaluating function at computed points:")
for (i, pt) in enumerate(subdomain_points)
    fval = deuflhard_4d_composite(pt)
    println("   Computed $i: f(x) = $(@sprintf("%.6e", fval))")
end

println("\n" * "="^80)
println("CONCLUSIONS:")
println("="^80)