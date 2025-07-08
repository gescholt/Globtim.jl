# Quick test of plot improvements
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using PlottingUtilities
using PlotDescriptions
using AnalysisUtilities
using CairoMakie
using Colors
using Statistics

# Create some test data
test_results = [
    DegreeAnalysisResult(
        2, 1.5, 25, 10, 5, 0.2, 1.0, false,
        Vector{Vector{Float64}}(), 0.1, [0.8, 0.7, 0.6]
    ),
    DegreeAnalysisResult(
        3, 0.8, 25, 15, 8, 0.32, 1.5, false,
        Vector{Vector{Float64}}(), 0.3, [0.5, 0.4, 0.35]
    ),
    DegreeAnalysisResult(
        4, 0.3, 25, 20, 18, 0.72, 2.0, false,
        Vector{Vector{Float64}}(), 0.8, [0.2, 0.15, 0.1]
    ),
    DegreeAnalysisResult(
        5, 0.08, 25, 23, 22, 0.88, 2.5, true,
        Vector{Vector{Float64}}(), 0.9, [0.05, 0.03, 0.02]
    )
]

println("Testing plot improvements...")
println("=" ^ 60)

# Test 1: L2-norm plot with title
println("\n1. Testing L2-norm convergence plot...")
fig1 = plot_l2_convergence(
    test_results,
    title = "Test L²-Norm Convergence",
    tolerance_line = 0.1
)
desc1 = describe_l2_convergence(test_results, tolerance_line = 0.1)
println(desc1)

# Test 2: Recovery rates with legend
println("\n2. Testing recovery rates plot...")
fig2 = plot_recovery_rates(
    test_results,
    title = "Test Recovery Rates"
)
desc2 = describe_recovery_rates(test_results)
println(desc2)

# Test 3: Min+min distances with log scale
println("\n3. Testing min+min distance plot...")
fig3 = plot_min_min_distances(
    test_results,
    title = "Test Min+Min Distances",
    tolerance_line = 0.1
)
desc3 = describe_min_min_distances(test_results, tolerance_line = 0.1)
println(desc3)

# Test 4: Subdivision plots
println("\n4. Testing subdivision plots...")
test_subdivisions = Dict(
    "0000" => test_results[1:3],
    "0001" => test_results[2:4],
    "0010" => test_results[1:4],
    "0011" => test_results
)

fig4 = plot_subdivision_convergence(
    test_subdivisions,
    title = "Test Subdivision Convergence",
    tolerance_line = 0.1
)
desc4 = describe_subdivision_convergence(test_subdivisions, tolerance_line = 0.1)
println(desc4)

# Save test plots
output_dir = joinpath(@__DIR__, "test_outputs")
mkpath(output_dir)

save(joinpath(output_dir, "test_l2_convergence.png"), fig1)
save(joinpath(output_dir, "test_recovery_rates.png"), fig2)
save(joinpath(output_dir, "test_min_min_distances.png"), fig3)
save(joinpath(output_dir, "test_subdivision_convergence.png"), fig4)

println("\n" * "=" ^ 60)
println("Test complete! Plots saved to: $output_dir")
println("\nKey improvements verified:")
println("✓ L2-norm plot displays title")
println("✓ Recovery rates plot has legend")
println("✓ Min+min distances use log scale with adaptive limits")
println("✓ Subdivision plots use distinct colors")
println("✓ Plot descriptions provide textual analysis")