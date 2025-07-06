using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Globtim, DynamicPolynomials
using Common4DDeuflhard
using SubdomainManagement
using Printf

println("Testing FIXED degree 3 for all 16 subdomains (no auto-increase)")
println("="^80)

# Generate subdomains
subdivisions = generate_16_subdivisions_orthant()
f = deuflhard_4d_composite
degree = 3

results = Dict{String, Float64}()

for subdomain in subdivisions
    # Create test input with very high tolerance to prevent auto-increase
    TR = test_input(f, dim=4, center=subdomain.center, sample_range=subdomain.range, tolerance=10.0)
    
    # Force specific degree
    pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
    
    results[subdomain.label] = pol.nrm
    println("Subdomain $(subdomain.label): L²-norm = $(@sprintf("%.6e", pol.nrm))")
end

# Show that we have different L²-norms
println("\nUnique L²-norm values: $(length(unique(values(results))))")
println("Range: [$(minimum(values(results))), $(maximum(values(results)))]")

println("\n" * "="^80)
println("SUCCESS: All 16 subdomains have L²-norm data!")
println("The plotting function should show 16 distinct curves.")
println("="^80)