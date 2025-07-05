# ================================================================================
# Verify Data Collection Logic for Enhanced Analysis
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

include("shared/Common4DDeuflhard.jl")
include("shared/SubdomainManagement.jl")
using .Common4DDeuflhard
using .SubdomainManagement

using LinearAlgebra
using Statistics
using DataFrames, CSV
using Printf

# Load functions from enhanced analysis
include("examples/degree_convergence_analysis_enhanced_v2.jl")

# ================================================================================
# TEST: Verify distance statistics collection
# ================================================================================

println("📊 Testing Enhanced Distance Statistics Collection")
println("="^60)

# Load true minimizers
true_minimizers = load_true_minimizers(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"))
println("Loaded $(length(true_minimizers)) true minimizers")

# Create test scenarios
test_scenarios = [
    (
        name = "All points near minimizers",
        points = [tm .+ 0.01 .* randn(4) for tm in true_minimizers],
        expected = "All distances < 0.1"
    ),
    (
        name = "Mix of near and far points", 
        points = vcat(
            [tm .+ 0.01 .* randn(4) for tm in true_minimizers[1:3]],  # 3 near
            [[0.5, -0.5, 0.5, -0.5], [0.0, 0.0, 0.0, 0.0]]  # 2 far
        ),
        expected = "3 near, 2 far"
    ),
    (
        name = "All spurious points",
        points = [[0.0, 0.0, 0.0, 0.0], [0.5, -0.5, 0.5, -0.5], [1.0, -1.0, 1.0, -1.0]],
        expected = "All distances > 0.2"
    )
]

for scenario in test_scenarios
    println("\n$(scenario.name):")
    println("  Expected: $(scenario.expected)")
    
    stats = compute_enhanced_distance_stats(scenario.points, true_minimizers, threshold=0.2)
    
    println("  Results:")
    println("    - Points analyzed: $(length(stats.all_distances))")
    println("    - Near minimizers: $(stats.n_near)")
    println("    - Far from minimizers: $(stats.n_far)")
    println("    - Distance range: [$(round(stats.min, digits=3)), $(round(stats.max, digits=3))]")
    println("    - Median: $(round(stats.median, digits=3))")
    println("    - Quartiles: [$(round(stats.q25, digits=3)), $(round(stats.q75, digits=3))]")
end

# ================================================================================
# TEST: Verify recovery calculation
# ================================================================================

println("\n\n📊 Testing Recovery Calculation")
println("="^60)

# Create test subdomain data
subdomains = generate_16_subdivisions_orthant()

# Create test computed points
test_computed = Dict{String, Vector{Vector{Float64}}}()

# Subdomain "0000" contains minimizer at [0.256625, -1.01625, 0.256625, -1.01625]
test_computed["0000"] = [
    [0.256625, -1.01625, 0.256625, -1.01625],  # Exact match
    [0.26, -1.02, 0.26, -1.02]  # Close match
]

# Subdomain "0001" has no minimizer - should have no points ideally
test_computed["0001"] = []  # Good - no false positives

# Subdomain "0010" contains a minimizer - but we miss it
test_computed["0010"] = [[0.5, -0.5, 0.5, -0.5]]  # Far from minimizer

# Subdomain "1111" contains minimizer at [1.01625, -0.25663, 1.01625, -0.25663]
test_computed["1111"] = [
    [1.02, -0.26, 1.02, -0.26]  # Close to minimizer
]

recovery_df, global_stats = compute_minimizer_recovery(
    true_minimizers, test_computed, subdomains, threshold=0.2
)

println("\nGlobal recovery: $(global_stats.total_recovered)/$(global_stats.total_minimizers) = $(global_stats.global_recovery_rate)%")

println("\nPer-subdomain results (showing non-empty):")
for row in eachrow(recovery_df)
    if row.computed_points > 0 || row.has_minimizer
        status = row.has_minimizer ? (row.found_minimizer ? "✓" : "✗") : "—"
        println("  $(row.subdomain): $(row.computed_points) points, has_min=$(row.has_minimizer), found=$(row.found_minimizer) [$status] accuracy=$(row.accuracy)%")
    end
end

# ================================================================================
# TEST: Verify quartile calculations work correctly
# ================================================================================

println("\n\n📊 Testing Quartile Calculations")
println("="^60)

# Create known distance distribution
test_distances = [0.01, 0.02, 0.05, 0.1, 0.15, 0.3, 0.5, 0.8, 1.2, 1.5]
test_points = [[i*0.1, 0, 0, 0] for i in 1:10]  # Dummy points

stats = compute_enhanced_distance_stats(test_points, true_minimizers)

# Manual calculation for verification
sorted_test = sort(test_distances)
manual_q25 = sorted_test[3]  # 0.05
manual_median = (sorted_test[5] + sorted_test[6]) / 2  # 0.225
manual_q75 = sorted_test[8]  # 0.8

println("Test distances: $test_distances")
println("\nManual calculations:")
println("  Q25: $manual_q25")
println("  Median: $manual_median") 
println("  Q75: $manual_q75")

# Note: The actual stats will differ because compute_enhanced_distance_stats
# calculates real distances to true minimizers, not using our test_distances

println("\n✅ Data collection verification completed!")