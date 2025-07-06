# Verify ALL theoretical minimizers including the ones mentioned
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using TheoreticalPoints
using Common4DDeuflhard: deuflhard_4d_composite
using Globtim: Deuflhard
using ForwardDiff
using LinearAlgebra

# First, let's check the 2D points
println("Loading 2D critical points in (+,-) orthant...")
println("="^70)

critical_2d, critical_2d_types = load_2d_critical_points_orthant()

println("2D critical points in (+,-) orthant [0,∞) × (-∞,0]:")
for (i, (pt, ptype)) in enumerate(zip(critical_2d, critical_2d_types))
    println("  Point $i: [$(pt[1]), $(pt[2])] - $ptype")
end

# Check specific points mentioned
check_points_2d = [
    [0.917350578608475, -0.50703077282823],
    [1.01624596361443, -0.256625076922483]
]

println("\nChecking specific 2D points:")
for pt in check_points_2d
    # Check if it's a minimizer using Hessian
    hess = ForwardDiff.hessian(Deuflhard, pt)
    eigenvals = eigvals(hess)
    is_min = all(eigenvals .> 1e-6)
    println("  $(pt): eigenvalues = $eigenvals, is minimizer = $is_min")
end

# Now generate 4D tensor products
println("\n4D Tensor Products:")
println("="^70)

theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points_orthant()

# Count types
type_counts = Dict{String, Int}()
for t in theoretical_types
    type_counts[t] = get(type_counts, t, 0) + 1
end

println("Point type distribution:")
for (ptype, count) in sort(collect(type_counts))
    println("  $ptype: $count points")
end

# Show all minimizers
min_indices = findall(t -> t == "min+min", theoretical_types)
println("\nAll theoretical minimizers (min+min):")
println("-"^70)
for (i, idx) in enumerate(min_indices)
    point = theoretical_points[idx]
    f_value = deuflhard_4d_composite(point)
    println("Minimizer $i: $(point)")
    println("  f(x) = $f_value")
end

# Check if specific 4D points would be minimizers
println("\nChecking specific 4D tensor products:")
test_4d_points = [
    [0.917350578608475, -0.50703077282823, 0.917350578608475, -0.50703077282823],
    [1.01624596361443, -0.256625076922483, 1.01624596361443, -0.256625076922483],
    [0.74115190368376, -0.741151903683748, 0.74115190368376, -0.741151903683748]
]

for pt in test_4d_points
    f_val = deuflhard_4d_composite(pt)
    println("\nPoint: $(pt)")
    println("  f(x) = $f_val")
    
    # Check if it's in our list
    found = false
    for (i, tpt) in enumerate(theoretical_points)
        if norm(tpt - pt) < 1e-10
            found = true
            println("  Found in list at index $i with type: $(theoretical_types[i])")
            break
        end
    end
    if !found
        println("  NOT found in theoretical points list!")
    end
end