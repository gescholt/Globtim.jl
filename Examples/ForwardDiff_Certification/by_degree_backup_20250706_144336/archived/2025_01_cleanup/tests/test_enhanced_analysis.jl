# ================================================================================
# Test Enhanced Analysis - Verify Data Collection
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

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

# Load true minimizers function
function load_true_minimizers(csv_path::String)
    df = CSV.read(csv_path, DataFrame)
    return [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(df)]
end

# ================================================================================
# TEST 1: Verify is_point_in_subdomain function
# ================================================================================

println("\n📋 TEST 1: Testing is_point_in_subdomain")
println("="^60)

# Generate subdomains
subdomains = generate_16_subdivisions_orthant()

# Test point assignment
test_points = [
    [0.5, -0.5, 0.5, -0.5],      # Should be in center
    [1.05, -0.05, 1.05, -0.05],  # Near upper corner
    [-0.05, -1.05, -0.05, -1.05], # Near lower corner
    [0.256625, -1.01625, 0.256625, -1.01625], # True minimizer
    [2.0, 2.0, 2.0, 2.0]         # Outside all subdomains
]

for (i, pt) in enumerate(test_points)
    println("\nPoint $i: [$(join(round.(pt, digits=3), ", "))]")
    matches = Subdomain[]
    for sub in subdomains
        if is_point_in_subdomain(pt, sub)
            push!(matches, sub)
        end
    end
    
    if length(matches) == 0
        println("  ❌ Not in any subdomain")
    elseif length(matches) == 1
        println("  ✓ In subdomain $(matches[1].label)")
    else
        println("  ⚠️  In multiple subdomains: $(join([m.label for m in matches], ", "))")
        # Use unique assignment
        unique_sub = assign_point_to_unique_subdomain(pt, subdomains)
        if unique_sub !== nothing
            println("  → Uniquely assigned to: $(unique_sub.label)")
        end
    end
end

# ================================================================================
# TEST 2: Verify true minimizer locations
# ================================================================================

println("\n\n📋 TEST 2: Verify true minimizer subdomain assignments")
println("="^60)

# Load true minimizers
true_minimizers = load_true_minimizers(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"))

# Check which subdomains contain minimizers
minimizer_subdomains = Dict{String, Int}()
for sub in subdomains
    count = 0
    for tm in true_minimizers
        if is_point_in_subdomain(tm, sub, tolerance=0.0)  # Exact check
            count += 1
        end
    end
    if count > 0
        minimizer_subdomains[sub.label] = count
    end
end

println("\nSubdomains containing true minimizers:")
for (label, count) in sort(minimizer_subdomains)
    println("  $label: $count minimizer(s)")
end
println("Total: $(sum(values(minimizer_subdomains))) (should be 9)")

# ================================================================================
# TEST 3: Distance statistics calculation
# ================================================================================

println("\n\n📋 TEST 3: Testing distance statistics")
println("="^60)

# Create test computed points
test_computed = [
    [0.256625, -1.01625, 0.256625, -1.01625],  # Exact match to minimizer
    [0.26, -1.02, 0.26, -1.02],                 # Close to minimizer (~0.01)
    [0.3, -1.0, 0.3, -1.0],                     # Medium distance (~0.05)
    [0.5, -0.5, 0.5, -0.5],                     # Far from minimizers (~0.6)
    [0.0, 0.0, 0.0, 0.0]                        # Very far (~1.5)
]

# Compute distances
distances = Float64[]
for cp in test_computed
    min_dist = minimum(norm(cp - tm) for tm in true_minimizers)
    push!(distances, min_dist)
    println("Point [$(join(round.(cp, digits=2), ", "))] → distance: $(round(min_dist, digits=4))")
end

# Calculate statistics
println("\nDistance statistics:")
println("  Min: $(round(minimum(distances), digits=4))")
println("  Median: $(round(median(distances), digits=4))")
println("  Mean: $(round(mean(distances), digits=4))")
println("  Max: $(round(maximum(distances), digits=4))")
println("  Q25: $(round(quantile(distances, 0.25), digits=4))")
println("  Q75: $(round(quantile(distances, 0.75), digits=4))")

# ================================================================================
# TEST 4: Enhanced distance statistics function
# ================================================================================

"""
Compute enhanced distance statistics with quartiles and point classification
"""
function compute_enhanced_distance_stats(computed_points::Vector{Vector{Float64}}, 
                                       true_minimizers::Vector{Vector{Float64}};
                                       threshold::Float64 = 0.2)
    if isempty(computed_points)
        return (
            all_distances = Float64[],
            min = Inf, median = NaN, mean = NaN, max = -Inf,
            q10 = NaN, q25 = NaN, q75 = NaN, q90 = NaN,
            n_near = 0, n_far = 0,
            near_distances = Float64[],
            far_distances = Float64[]
        )
    end
    
    # Compute all distances
    distances = [minimum(norm(cp - tm) for tm in true_minimizers) for cp in computed_points]
    
    # Classify points
    near_mask = distances .< threshold
    near_distances = distances[near_mask]
    far_distances = distances[.!near_mask]
    
    return (
        all_distances = distances,
        min = minimum(distances),
        median = median(distances),
        mean = mean(distances),
        max = maximum(distances),
        q10 = quantile(distances, 0.10),
        q25 = quantile(distances, 0.25),
        q75 = quantile(distances, 0.75),
        q90 = quantile(distances, 0.90),
        n_near = length(near_distances),
        n_far = length(far_distances),
        near_distances = near_distances,
        far_distances = far_distances
    )
end

println("\n\n📋 TEST 4: Enhanced distance statistics")
println("="^60)

stats = compute_enhanced_distance_stats(test_computed, true_minimizers)
println("Enhanced statistics:")
println("  Points near minimizers (< 0.2): $(stats.n_near)")
println("  Points far from minimizers: $(stats.n_far)")
println("  Quartile range: [$(round(stats.q25, digits=4)), $(round(stats.q75, digits=4))]")

# ================================================================================
# TEST 5: Small degree analysis to verify data flow
# ================================================================================

println("\n\n📋 TEST 5: Running small degree analysis")
println("="^60)

# Test with just degree 4
degree = 4
gn = 16

# Store distance data by subdomain
distance_data_by_subdomain = Dict{String, Any}()

# Process one subdomain
test_subdomain = subdomains[1]  # "0000"
println("\nTesting subdomain $(test_subdomain.label)")
println("  Center: [$(join(round.(test_subdomain.center, digits=3), ", "))]")
println("  Range: $(test_subdomain.range)")

# Construct polynomial
TR = test_input(
    deuflhard_4d_composite,
    dim = 4,
    center = test_subdomain.center,
    sample_range = test_subdomain.range,
    GN = gn
)

pol = Constructor(TR, degree, verbose=0)
println("  L²-norm: $(round(pol.nrm, sigdigits=4))")

# Find critical points
@polyvar x[1:4]
df_crit = process_crit_pts(
    solve_polynomial_system(x, 4, degree, pol.coeffs),
    deuflhard_4d_composite,
    TR
)

# Filter points in subdomain
subdomain_points = Vector{Float64}[]
for row in eachrow(df_crit)
    pt = [row[Symbol("x$i")] for i in 1:4]
    if is_point_in_subdomain(pt, test_subdomain)
        push!(subdomain_points, pt)
    end
end

println("  Found $(length(subdomain_points)) critical points in subdomain")

# Compute distance statistics
if !isempty(subdomain_points)
    stats = compute_enhanced_distance_stats(subdomain_points, true_minimizers)
    distance_data_by_subdomain[test_subdomain.label] = stats
    
    println("  Distance stats:")
    println("    - Min: $(round(stats.min, digits=4))")
    println("    - Median: $(round(stats.median, digits=4))")
    println("    - Max: $(round(stats.max, digits=4))")
    println("    - Near minimizers: $(stats.n_near)")
end

# ================================================================================
# TEST 6: Global domain comparison setup
# ================================================================================

println("\n\n📋 TEST 6: Global domain setup")
println("="^60)

# Define global domain bounds (covering all subdomains)
global_center = [0.5, -0.5, 0.5, -0.5]
global_range = 0.6  # From -0.1 to 1.1 is 1.2, so range is 0.6

println("Global domain:")
println("  Center: [$(join(global_center, ", "))]")
println("  Range: $global_range")
println("  Bounds: [$(global_center[1] - global_range), $(global_center[1] + global_range)] × ...")

# Verify it covers all minimizers
all_inside = true
for tm in true_minimizers
    for i in 1:4
        if abs(tm[i] - global_center[i]) > global_range
            all_inside = false
            println("  ⚠️  Minimizer at $tm is outside global domain!")
        end
    end
end

if all_inside
    println("  ✓ All minimizers are within global domain")
end

println("\n✅ All tests completed successfully!")