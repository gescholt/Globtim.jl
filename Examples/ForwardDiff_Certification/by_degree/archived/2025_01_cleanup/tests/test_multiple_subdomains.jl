using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Globtim, DynamicPolynomials
using Common4DDeuflhard
using SubdomainManagement
using Printf

println("Testing polynomial approximation in multiple subdomains")
println("="^80)

# Generate subdomains
subdivisions = generate_16_subdivisions_orthant()

# Test a few different subdomains at degree 4
test_subdomains = ["0000", "0101", "1010", "1111"]
degree = 4

println("\nTesting degree $degree approximation in selected subdomains:")
println("-"^80)

for label in test_subdomains
    subdomain = subdivisions[findfirst(s -> s.label == label, subdivisions)]
    
    println("\nSubdomain $label:")
    println("  Center: [$(join([@sprintf("%.2f", c) for c in subdomain.center], ", "))]")
    println("  Bounds: [$(join(["[$(@sprintf("%.1f", b[1])), $(@sprintf("%.1f", b[2]))]" for b in subdomain.bounds], " × "))]")
    
    # Create polynomial approximation
    f = deuflhard_4d_composite
    TR = test_input(f, dim=4, center=subdomain.center, sample_range=subdomain.range, tolerance=0.01)
    pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
    
    println("  L²-norm: $(@sprintf("%.6e", pol.nrm))")
    
    # Find critical points
    @polyvar x[1:4]
    crit_pts = solve_polynomial_system(x, 4, pol.degree, pol.coeffs)
    
    println("  Critical points found: $(length(crit_pts))")
    
    # Check how many are actually in this subdomain
    in_subdomain = 0
    for pt in crit_pts
        in_bounds = true
        for (i, coord) in enumerate(pt)
            if coord < subdomain.bounds[i][1] || coord > subdomain.bounds[i][2]
                in_bounds = false
                break
            end
        end
        if in_bounds
            in_subdomain += 1
        end
    end
    
    println("  Points within subdomain bounds: $in_subdomain")
    
    # Show first few critical points
    if !isempty(crit_pts)
        println("  First critical point: [$(join([@sprintf("%.3f", x) for x in crit_pts[1]], ", "))]")
    end
end

println("\n" * "="^80)
println("CONCLUSION:")
println("Polynomial approximation finds critical points in each subdomain,")
println("even though theoretical points only exist in subdomain 1010.")
println("="^80)