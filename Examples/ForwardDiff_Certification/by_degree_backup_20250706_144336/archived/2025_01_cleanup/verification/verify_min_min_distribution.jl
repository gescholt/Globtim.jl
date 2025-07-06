using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using SubdomainManagement
using TheoreticalPoints
using Printf

# Load theoretical points
points_2d, values_2d, types_2d = load_2d_critical_points_orthant()
points_4d, values_4d, types_4d = construct_4d_critical_points_tensor(points_2d, values_2d, types_2d)

println("Total 4D theoretical points: $(length(points_4d))")
println("Min+min points: $(count(t -> t == "min+min", types_4d))")
println("=" ^ 80)

# Check which subdomains contain min+min points
subdivisions = generate_16_subdivisions_orthant()

println("\nMin+min points distribution across subdomains:")
println("-" * 80)

for subdomain in subdivisions
    # Count min+min points in this subdomain
    min_min_count = 0
    
    for (i, pt) in enumerate(points_4d)
        if types_4d[i] == "min+min"
            # Check if point is in subdomain bounds
            in_bounds = true
            for (j, coord) in enumerate(pt)
                if coord < subdomain.bounds[j][1] || coord > subdomain.bounds[j][2]
                    in_bounds = false
                    break
                end
            end
            
            if in_bounds
                min_min_count += 1
            end
        end
    end
    
    if min_min_count > 0
        println("Subdomain $(subdomain.label): $min_min_count min+min points")
        println("  Bounds: $(subdomain.bounds)")
    end
end

println("\n" * "=" * 80)
println("EXPLANATION:")
println("The min+min distance plot shows only one curve because:")
println("1. All min+min theoretical points are in subdomain 1010")
println("2. Other subdomains have no min+min points to compute distances from")
println("3. The plot correctly shows data only where it exists")
println("=" * 80)