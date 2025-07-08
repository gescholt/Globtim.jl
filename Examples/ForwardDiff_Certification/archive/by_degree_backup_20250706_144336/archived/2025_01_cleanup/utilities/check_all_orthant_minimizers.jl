# Check ALL minimizers in the (+,-,+,-) orthant without bounds restriction
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using TheoreticalPoints
using Common4DDeuflhard: deuflhard_4d_composite
using Globtim: Deuflhard
using ForwardDiff
using LinearAlgebra
using CSV, DataFrames

# Load ALL 2D critical points
csv_path = joinpath(@__DIR__, "../../../data/matlab_critical_points/valid_points_deuflhard.csv")
csv_data = CSV.read(csv_path, DataFrame)
all_2d_points = [[row.x, row.y] for row in eachrow(csv_data)]

# Filter for (+,-) orthant (x ≥ 0, y ≤ 0) without bounds
orthant_2d_points = filter(pt -> pt[1] >= 0 && pt[2] <= 0, all_2d_points)

println("2D critical points in (+,-) orthant [0,∞) × (-∞,0]:")
println("="^70)

# Classify each point
orthant_2d_minimizers = Vector{Vector{Float64}}()
for pt in orthant_2d_points
    hess = ForwardDiff.hessian(Deuflhard, pt)
    eigenvals = eigvals(hess)
    
    if all(eigenvals .> 1e-6)
        push!(orthant_2d_minimizers, pt)
        println("Minimizer: $(pt)")
        println("  Eigenvalues: $eigenvals")
    else
        ptype = all(eigenvals .< -1e-6) ? "maximum" : "saddle"
        println("$ptype: $(pt)")
        println("  Eigenvalues: $eigenvals")
    end
end

println("\nTotal 2D minimizers in (+,-) orthant: $(length(orthant_2d_minimizers))")

# Generate 4D tensor products from ALL minimizers
println("\n4D Tensor Products (all minimizers):")
println("="^70)

tensor_4d_minimizers = Vector{Vector{Float64}}()
for pt1 in orthant_2d_minimizers
    for pt2 in orthant_2d_minimizers
        # Create 4D point in (+,-,+,-) pattern
        pt4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
        push!(tensor_4d_minimizers, pt4d)
    end
end

println("Total 4D tensor product minimizers: $(length(tensor_4d_minimizers))")

# Evaluate function at each
for (i, pt) in enumerate(tensor_4d_minimizers)
    f_val = deuflhard_4d_composite(pt)
    println("\nMinimizer $i: $(pt)")
    println("  f(x) = $f_val")
end

# Check which ones are in [0,1] × [-1,0] × [0,1] × [-1,0]
println("\nChecking which minimizers are in bounded domain [0,1] × [-1,0] × [0,1] × [-1,0]:")
for (i, pt) in enumerate(tensor_4d_minimizers)
    in_bounds = pt[1] <= 1 && pt[2] >= -1 && pt[3] <= 1 && pt[4] >= -1
    status = in_bounds ? "✓ IN" : "✗ OUT"
    println("$status Minimizer $i: $(pt)")
end