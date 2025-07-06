# Verify theoretical points from the proper loading function
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using TheoreticalPoints
using Common4DDeuflhard: deuflhard_4d_composite

println("Loading theoretical 4D points for (+,-,+,-) orthant...")
println("="^70)

# Load theoretical points using the proper function
theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points_orthant()

println("Total theoretical points found: $(length(theoretical_points))")
println()

# Check how many are minimizers
min_indices = findall(t -> t == "min+min", theoretical_types)
println("Number of theoretical minimizers (min+min): $(length(min_indices))")
println()

if !isempty(min_indices)
    println("Theoretical minimizers and their function values:")
    println("-"^70)
    for (i, idx) in enumerate(min_indices)
        point = theoretical_points[idx]
        f_value = deuflhard_4d_composite(point)
        println("Minimizer $i: $(point)")
        println("  f(x) = $f_value")
        println("  Theoretical value: $(theoretical_values[idx])")
        println()
    end
end

# Compare with the hardcoded 9 points
hardcoded_minimizers = [
    [0.0, 0.0, 0.0, 0.0],          # Central minimizer
    [0.0, -1.0, 0.0, 0.0],         # Face centers
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, -1.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, -1.0],
    [0.0, 0.0, 0.0, 1.0],
    [-1.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 0.0]
]

println("\nHardcoded points analysis:")
println("-"^70)
println("Checking which hardcoded points are in the (+,-,+,-) orthant:")
for (i, point) in enumerate(hardcoded_minimizers)
    in_orthant = point[1] >= 0 && point[2] <= 0 && point[3] >= 0 && point[4] <= 0
    f_val = deuflhard_4d_composite(point)
    status = in_orthant ? "✓ IN" : "✗ OUT"
    println("$status Point $i: $(point) -> f = $(round(f_val, sigdigits=4))")
end