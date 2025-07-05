using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Globtim, DynamicPolynomials
using Common4DDeuflhard
using SubdomainManagement
using Printf

println("Quick test: L²-norm for all 16 subdomains at degree 3")
println("="^80)

# Generate subdomains
subdivisions = generate_16_subdivisions_orthant()
f = deuflhard_4d_composite
degree = 3

results = Dict{String, Float64}()

for subdomain in subdivisions
    # Create polynomial approximation
    TR = test_input(f, dim=4, center=subdomain.center, sample_range=subdomain.range, tolerance=0.01)
    pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
    
    results[subdomain.label] = pol.nrm
    println("Subdomain $(subdomain.label): L²-norm = $(@sprintf("%.6e", pol.nrm))")
end

println("\n" * "="^80)
println("Summary: We have L²-norm data for all 16 subdomains!")
println("Each subdomain can be analyzed independently.")
println("="^80)