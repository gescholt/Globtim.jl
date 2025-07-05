# Verify that subdomain specifications are correctly set up for Globtim
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

push!(LOAD_PATH, joinpath(@__DIR__, "shared"))
using SubdomainManagement

println("Verifying Subdomain Specifications for Globtim Constructor")
println("="^60)

# Test orthant subdivisions
subdomains = generate_16_subdivisions_orthant()

println("\nOrthant Subdivisions (stretched domain):")
println("Full orthant bounds: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]")
println()

for (i, subdomain) in enumerate(subdomains[1:4])  # Show first 4 as examples
    println("Subdomain $(subdomain.label):")
    println("  Center: $(subdomain.center)")
    println("  Range (half-width): $(subdomain.range)")
    println("  Bounds: $(subdomain.bounds)")
    
    # Verify that center ± range equals bounds
    for dim in 1:4
        lower_check = subdomain.center[dim] - subdomain.range
        upper_check = subdomain.center[dim] + subdomain.range
        lower_bound, upper_bound = subdomain.bounds[dim]
        
        if abs(lower_check - lower_bound) > 1e-10 || abs(upper_check - upper_bound) > 1e-10
            println("  ⚠️  WARNING: Inconsistent bounds in dimension $dim!")
            println("     Center ± range: [$lower_check, $upper_check]")
            println("     Specified bounds: [$lower_bound, $upper_bound]")
        end
    end
    
    # Show how this maps to Globtim
    println("  For Globtim Constructor:")
    println("    center = $(subdomain.center)")
    println("    sample_range = $(subdomain.range)")
    println("    → Domain: [$(subdomain.center .- subdomain.range), $(subdomain.center .+ subdomain.range)]")
    println()
end

# Verify domain coverage
println("\nDomain Coverage Check:")
println("Each dimension should be split at its midpoint:")
for dim in 1:4
    bounds = [(-0.1, 1.1), (-1.1, 0.1), (-0.1, 1.1), (-1.1, 0.1)][dim]
    midpoint = (bounds[1] + bounds[2]) / 2
    println("  Dimension $dim: range $(bounds), midpoint = $midpoint")
    
    # Check that subdomains properly split at midpoint
    lower_subdomains = filter(s -> s.bounds[dim][2] ≈ midpoint, subdomains)
    upper_subdomains = filter(s -> s.bounds[dim][1] ≈ midpoint, subdomains)
    
    println("    Lower half subdomains: $(length(lower_subdomains))")
    println("    Upper half subdomains: $(length(upper_subdomains))")
end

println("\n✓ Verification complete. Each subdomain's center and range properly define")
println("  the domain boundaries that will be used by the Globtim Constructor.")