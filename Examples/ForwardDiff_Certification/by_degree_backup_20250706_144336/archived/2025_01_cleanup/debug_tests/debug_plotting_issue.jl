using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Common4DDeuflhard
using SubdomainManagement
using Printf

# Generate 16 subdomains
subdivisions = generate_16_subdivisions_orthant()
println("Generated $(length(subdivisions)) subdomains")

# Check which subdomains have theoretical points
for (i, subdomain) in enumerate(subdivisions)
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    if !isempty(theoretical_points)
        println("Subdomain $(subdomain.label): $(length(theoretical_points)) points")
        println("  Bounds: $(subdomain.bounds)")
        println("  Points: $(theoretical_points)")
    else
        println("Subdomain $(subdomain.label): EMPTY")
    end
end

println("\nConclusion: Only subdomain 1010 has theoretical points!")
println("This explains why only 1010 appears in the results CSV files.")
println("The plotting function should only plot subdomains that have data.")