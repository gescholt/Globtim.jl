# Test improved visualizations with multiple line styles
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using PlottingUtilities
using PlotDescriptions
using AnalysisUtilities
using CairoMakie
using Statistics

# Create test data for 8 subdomains (to demonstrate color and style variations)
function create_test_subdomain_data(n_subdomains=8)
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    
    for i in 1:n_subdomains
        label = string(i-1, base=2, pad=4)  # Binary labels like "0000", "0001", etc.
        
        # Create varying results for each subdomain
        subdomain_results = DegreeAnalysisResult[]
        
        for degree in 2:6
            # Add some variation between subdomains
            base_l2 = 10.0 * 0.3^(degree-2)
            l2_variation = base_l2 * (1 + 0.3 * sin(i + degree))
            
            base_rate = 0.1 + 0.15 * (degree - 2)
            rate_variation = base_rate * (1 + 0.2 * cos(i * degree))
            
            # Some subdomains have no min+min points
            has_minmin = (i % 3) != 0
            minmin_rate = has_minmin ? rate_variation * 1.2 : -1.0
            minmin_dists = has_minmin ? [l2_variation * rand() for _ in 1:3] : Float64[]
            
            push!(subdomain_results, DegreeAnalysisResult(
                degree, l2_variation, 25, 
                round(Int, 25 * rate_variation), 
                round(Int, 25 * rate_variation * 0.9),
                rate_variation, 
                2.0 * degree, 
                l2_variation < 0.1,
                Vector{Vector{Float64}}(), 
                minmin_rate, 
                minmin_dists
            ))
        end
        
        all_results[label] = subdomain_results
    end
    
    return all_results
end

println("Testing improved subdivision visualizations...")
println("=" ^ 60)

# Create test data
test_data = create_test_subdomain_data(8)

# Test 1: L2-norm convergence with varied line styles
println("\n1. Testing L2-norm convergence with varied line styles...")
fig1 = plot_subdivision_convergence(
    test_data,
    title = "Test: L²-Norm Convergence with Multiple Subdomains",
    tolerance_line = 0.1
)

# Test 2: Recovery rates with varied line styles
println("\n2. Testing recovery rates with varied line styles...")
fig2 = plot_subdivision_recovery_rates(
    test_data,
    title = "Test: Recovery Rates with Multiple Subdomains"
)

# Test 3: Min+min distances with varied line styles  
println("\n3. Testing min+min distances with varied line styles...")
fig3 = plot_subdivision_min_min_distances(
    test_data,
    title = "Test: Min+Min Distances with Multiple Subdomains",
    tolerance_line = 0.1
)

# Save test plots
output_dir = joinpath(@__DIR__, "test_outputs_improved")
mkpath(output_dir)

save(joinpath(output_dir, "improved_l2_convergence.png"), fig1)
save(joinpath(output_dir, "improved_recovery_rates.png"), fig2) 
save(joinpath(output_dir, "improved_min_min_distances.png"), fig3)

println("\n" * "=" ^ 60)
println("Test complete! Plots saved to: $output_dir")
println("\nVisualization improvements:")
println("✓ Individual subdomain trajectories visible with different colors/styles")
println("✓ 6 colors × 4 line styles = 24 unique combinations")
println("✓ Bold black line shows overall average")
println("✓ Thin transparent lines for individual subdomains")
println("✓ Updated annotations describe the visualization approach")

# Generate descriptions
println("\nPlot descriptions:")
println("\nL2-norm convergence:")
println(describe_subdivision_convergence(test_data, tolerance_line = 0.1))
println("\nRecovery rates:")
println(describe_subdivision_recovery_rates(test_data))
println("\nMin+min distances:")
println(describe_subdivision_min_min_distances(test_data, tolerance_line = 0.1))