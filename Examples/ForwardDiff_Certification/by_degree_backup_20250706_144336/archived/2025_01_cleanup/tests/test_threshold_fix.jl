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
println("QUICK TEST: Threshold Fix Validation")
println("="^80)

# Test just degree 2 on one subdomain to verify threshold fix
subdomains = generate_16_subdivisions_orthant()
test_subdomain = subdomains[11]  # "1010" 

println("Testing subdomain: $(test_subdomain.label)")

# Run analysis with degree 2
include("examples/degree_convergence_analysis_enhanced.jl")

# Test just one degree
println("\nTesting with threshold 0.2:")
summary_df, dist_df = run_enhanced_analysis([2], 16, threshold=0.2)

println("\n" * "="^80)
println("RESULTS SUMMARY:")
println("="^80)
println("Expected: Recovery > 0 for some subdomains (specifically 1010)")
println("Threshold used: 0.2")
println("Check output above for non-zero recovery rates.")