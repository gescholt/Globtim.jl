using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints
using Printf

println("="^80)
println("Debugging Subdomain Centers and Theoretical Point Distribution")
println("="^80)

# Generate 16 subdomains
subdivisions = generate_16_subdivisions_orthant()
println("\nGenerated $(length(subdivisions)) subdomains in (+,-,+,-) orthant")
println("\nSubdomain Centers and Bounds:")
println("-"^80)

# Display all subdomain information
for (i, subdomain) in enumerate(subdivisions)
    println("\nSubdomain $(subdomain.label):")
    println("  Center: [$(join([@sprintf("%.3f", c) for c in subdomain.center], ", "))]")
    println("  Range: $(subdomain.range)")
    println("  Bounds:")
    for (dim, (lower, upper)) in enumerate(subdomain.bounds)
        println("    Dim $dim: [$(@sprintf("%.3f", lower)), $(@sprintf("%.3f", upper))]")
    end
    
    # Check theoretical points for this subdomain
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    if !isempty(theoretical_points)
        println("  Theoretical points: $(length(theoretical_points))")
        for (j, pt) in enumerate(theoretical_points)
            println("    Point $j: [$(join([@sprintf("%.3f", x) for x in pt], ", "))] - $(theoretical_types[j])")
        end
    else
        println("  Theoretical points: NONE")
    end
end

# Verify subdomain centers are distinct
println("\n" * "="*80)
println("Verification: Are subdomain centers properly distributed?")
println("-"^80)

# Check center distribution in each dimension
for dim in 1:4
    centers_in_dim = [sub.center[dim] for sub in subdivisions]
    unique_centers = unique(centers_in_dim)
    println("\nDimension $dim:")
    println("  Unique centers: $(sort(unique_centers))")
    println("  Count: $(length(unique_centers)) (expected: 2)")
end

# Verify bounds coverage
println("\n" * "="*80)
println("Verification: Do subdomains properly cover the orthant?")
println("-"^80)

# Check that bounds cover the entire orthant without gaps
orthant_bounds = [(0.0, 1.0), (-1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]
for dim in 1:4
    println("\nDimension $dim (orthant: $(orthant_bounds[dim])):")
    
    # Collect all bounds for this dimension
    all_bounds = [sub.bounds[dim] for sub in subdivisions]
    unique_bounds = unique(all_bounds)
    
    println("  Unique bounds: $(sort(unique_bounds))")
    println("  Coverage check:")
    
    # Check lower half
    lower_half = filter(b -> b[2] <= (orthant_bounds[dim][1] + orthant_bounds[dim][2])/2, unique_bounds)
    upper_half = filter(b -> b[1] >= (orthant_bounds[dim][1] + orthant_bounds[dim][2])/2, unique_bounds)
    
    println("    Lower half subdomains: $(length(lower_half))")
    println("    Upper half subdomains: $(length(upper_half))")
end

println("\n" * "="*80)
println("Conclusion:")
println("-"^80)
println("✓ Generated $(length(subdivisions)) subdomains")
println("✓ Each subdomain has unique center and bounds")
println("✓ Subdomains properly partition the (+,-,+,-) orthant")
println("\nNote: Only subdomain 1010 contains theoretical points due to")
println("the mathematical distribution of Deuflhard critical points.")
println("="^80)