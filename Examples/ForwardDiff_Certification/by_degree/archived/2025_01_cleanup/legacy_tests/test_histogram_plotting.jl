# Test script for new histogram plotting functions
# This demonstrates how to use plot_recovery_histogram and plot_subdivision_recovery_histogram

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using CairoMakie
using Globtim

# Add shared modules to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using PlottingUtilities
using AnalysisUtilities
using Common4DDeuflhard
using TheoreticalPoints

# Function to generate sample data for testing
function generate_test_data()
    # Create sample DegreeAnalysisResult objects
    results = DegreeAnalysisResult[]
    
    # Simulate results for degrees 4 through 10
    for degree in 4:10
        # Simulate varying recovery rates
        n_theoretical = 100
        success_rate = 0.6 + 0.05 * (degree - 4)  # Increasing success with degree
        n_successful = round(Int, n_theoretical * success_rate)
        
        push!(results, DegreeAnalysisResult(
            degree,
            10.0^(-degree/2),  # L2 norm decreases with degree
            n_theoretical,
            n_successful + 5,   # Some extra computed points
            n_successful,
            success_rate,
            10.0 + degree,      # Runtime increases with degree
            degree >= 8,        # Converged for degree 8+
            Vector{Vector{Float64}}(),  # Empty for demo
            success_rate * 0.9,  # Min-min success slightly lower
            Float64[]  # Empty min_min_distances for demo
        ))
    end
    
    return results
end

# Function to generate subdivision test data
function generate_subdivision_test_data()
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    
    # Create results for 4 subdomains
    for i in 1:4
        subdomain_results = DegreeAnalysisResult[]
        
        for degree in 4:8
            # Each subdomain has different characteristics
            n_theoretical = 25  # 25 points per subdomain (100 total)
            base_rate = 0.5 + 0.1 * i  # Different base rates per subdomain
            success_rate = min(0.95, base_rate + 0.05 * (degree - 4))
            n_successful = round(Int, n_theoretical * success_rate)
            
            push!(subdomain_results, DegreeAnalysisResult(
                degree,
                10.0^(-degree/2),
                n_theoretical,
                n_successful + 2,
                n_successful,
                success_rate,
                5.0 + degree/2,
                degree >= 7,
                Vector{Vector{Float64}}(),
                success_rate * 0.85,
                Float64[]  # Empty min_min_distances
            ))
        end
        
        all_results["Subdomain $i"] = subdomain_results
    end
    
    return all_results
end

# Test 1: Basic recovery histogram
println("Generating basic recovery histogram...")
results = generate_test_data()
fig1 = plot_recovery_histogram(results, 
                              title="Critical Point Recovery (Test Data)",
                              show_legend=true)
display(fig1)

# Save to file
save("test_recovery_histogram.png", fig1)
println("Saved: test_recovery_histogram.png")

# Test 2: Recovery histogram without legend
println("\nGenerating recovery histogram without legend...")
fig2 = plot_recovery_histogram(results,
                              title="Critical Point Recovery (No Legend)",
                              show_legend=false)
display(fig2)

# Test 3: Subdivision recovery histogram - combined view
println("\nGenerating subdivision recovery histogram (combined)...")
subdivision_results = generate_subdivision_test_data()
fig3 = plot_subdivision_recovery_histogram(subdivision_results,
                                          title="Combined Subdivision Recovery",
                                          show_combined=true)
display(fig3)

# Save to file
save("test_subdivision_recovery_combined.png", fig3)
println("Saved: test_subdivision_recovery_combined.png")

# Test 4: Subdivision recovery histogram - separate view
println("\nGenerating subdivision recovery histogram (separate)...")
fig4 = plot_subdivision_recovery_histogram(subdivision_results,
                                          title="Separate Subdomain Recovery",
                                          show_combined=false)
display(fig4)

# Save to file
save("test_subdivision_recovery_separate.png", fig4)
println("Saved: test_subdivision_recovery_separate.png")

# Test 5: Real data example (if available)
println("\nAttempting to use real data from existing analysis...")
try
    # Try to load real results from a previous run
    results_file = joinpath(@__DIR__, "../outputs/09-07/orthant_results.csv")
    if isfile(results_file)
        println("Found real data file, creating histogram from actual results...")
        # Note: Would need to parse CSV and convert to DegreeAnalysisResult objects
        # This is just a placeholder to show the intended usage
        println("(CSV parsing not implemented in this demo)")
    else
        println("No real data file found at expected location")
    end
catch e
    println("Error loading real data: ", e)
end

println("\nAll tests completed!")
println("Generated plots:")
println("  - test_recovery_histogram.png")
println("  - test_subdivision_recovery_combined.png")
println("  - test_subdivision_recovery_separate.png")