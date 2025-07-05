# Quick test of the simplified analysis
# Run from the by_degree directory

cd(@__DIR__)
include("examples/simplified_subdomain_analysis.jl")

# Run the analysis
println("Testing simplified subdomain analysis...")
run_simplified_analysis()