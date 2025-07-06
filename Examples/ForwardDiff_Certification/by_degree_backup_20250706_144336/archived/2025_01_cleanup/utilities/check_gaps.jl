using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using SubdomainManagement, Common4DDeuflhard, AnalysisUtilities, Printf
using Globtim

# Test parameters
subdivisions = generate_16_subdivisions_orthant()
f = deuflhard_4d_composite
degrees = [2, 3, 4, 5, 6]

println("Checking for gaps in L²-norm data...")
println("=" ^ 80)

# Test first 4 subdomains
for subdomain in subdivisions[1:4]
    println("\nSubdomain $(subdomain.label):")
    for degree in degrees
        result = analyze_single_degree(
            f, degree, subdomain.center, subdomain.range,
            [], [],  # No theoretical points needed for L²-norm
            gn=16, tolerance_target=0.01
        )
        
        if result !== nothing && result.l2_norm > 0
            println("  Degree $degree: L²-norm = $(Printf.@sprintf("%.3e", result.l2_norm))")
        else
            println("  Degree $degree: MISSING or ZERO")
        end
    end
end

println("\n" * "=" * 80)
println("If you see 'MISSING' entries, those are the gaps in the plot.")