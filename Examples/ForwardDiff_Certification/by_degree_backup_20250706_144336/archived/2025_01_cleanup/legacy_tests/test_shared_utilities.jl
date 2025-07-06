# Test script to verify shared utilities work correctly

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

# Test loading modules
println("Testing module loading...")
using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints
using AnalysisUtilities
using PlottingUtilities
using TableGeneration

println("✓ All modules loaded successfully")

# Test Common4DDeuflhard
println("\nTesting Common4DDeuflhard...")
x_test = [0.5, -0.3, 0.2, 0.7]
val = deuflhard_4d_composite(x_test)
println("  deuflhard_4d_composite($x_test) = $val")
println("  GN_FIXED = $GN_FIXED")

# Test SubdomainManagement
println("\nTesting SubdomainManagement...")
subdivisions = generate_16_subdivisions()
println("  Generated $(length(subdivisions)) subdivisions")
println("  First subdomain: $(subdivisions[1].label) at $(subdivisions[1].center)")
point_in = is_point_in_subdomain([-0.5, -0.5, -0.5, -0.5], subdivisions[1])
println("  Point in subdomain test: $point_in")

# Test TheoreticalPoints
println("\nTesting TheoreticalPoints...")
try
    critical_2d, types_2d = load_2d_critical_points()
    println("  Loaded $(length(critical_2d)) 2D critical points")
    println("  Types: $(unique(types_2d))")
    
    # Test tensor products
    points_4d, values_4d, types_4d = load_theoretical_4d_points()
    println("  Generated $(length(points_4d)) 4D tensor product points")
    println("  Unique 4D types: $(unique(types_4d))")
catch e
    println("  ⚠ Could not load theoretical points (CSV file may be missing)")
    println("  Error: $e")
end

# Test AnalysisUtilities
println("\nTesting AnalysisUtilities...")
# Create dummy result with all 11 fields including min_min_distances
dummy_result = DegreeAnalysisResult(
    4, 0.01, 225, 200, 180, 0.8, 10.5, false,
    Vector{Vector{Float64}}(), 0.85, Float64[]  # Added min_min_distances field
)
println("  Created DegreeAnalysisResult: degree=$(dummy_result.degree), L²-norm=$(dummy_result.l2_norm)")

# Test PlottingUtilities
println("\nTesting PlottingUtilities...")
using CairoMakie
results = [dummy_result]
fig = plot_l2_convergence(results, title="Test Plot")
println("  Created L²-norm convergence plot")

# Test TableGeneration
println("\nTesting TableGeneration...")
println("  Generating summary table:")
generate_degree_summary_table(results)

println("\n✓ All tests completed successfully!")
println("\nShared utilities are ready for use in main examples.")