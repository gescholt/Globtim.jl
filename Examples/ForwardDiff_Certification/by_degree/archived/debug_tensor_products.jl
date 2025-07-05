using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

push!(LOAD_PATH, joinpath(@__DIR__, "shared"))
using TheoreticalPoints

# Get 2D points in orthant
pts_2d, types_2d = TheoreticalPoints.load_2d_critical_points_orthant()
println("2D points in (+,-) orthant: ", length(pts_2d))
for (i, (pt, t)) in enumerate(zip(pts_2d, types_2d))
    println("  Point $i: $pt -> $t")
end

# Generate 4D tensor products
pts_4d, vals_4d, types_4d = TheoreticalPoints.generate_4d_tensor_products(pts_2d, types_2d)
println("\n4D tensor products: ", length(pts_4d))

# Count by type
type_counts = Dict{String,Int}()
for t in types_4d
    type_counts[t] = get(type_counts, t, 0) + 1
end

println("\nType distribution in 4D:")
for (t, c) in sort(collect(type_counts))
    println("  $t: $c")
end

# Show min+min points
println("\nMin+min points:")
for (i, (pt, t)) in enumerate(zip(pts_4d, types_4d))
    if t == "min+min"
        println("  4D point: $pt")
    end
end