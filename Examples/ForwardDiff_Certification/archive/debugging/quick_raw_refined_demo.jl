# Quick demo showing raw vs refined critical points

using Pkg; using Revise
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim, DynamicPolynomials, DataFrames, Printf, LinearAlgebra, Optim

# Simple 4D function with known minimum
f(x) = sum((x .- [0.5, -0.5, 0.5, -0.5]).^2) + 0.1*sum(x.^4)
expected = [0.5, -0.5, 0.5, -0.5]

println("Expected minimum: $expected")
println("\nConstructing polynomial approximation...")

# Use low degree and high tolerance for speed
TR = test_input(f, dim=4, center=[0.0, 0.0, 0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, (:one_d_for_all, 4), basis=:chebyshev, verbose=false)

println("Degree: $(pol.degree[2]), L2-norm: $(Printf.@sprintf("%.2e", pol.nrm))")

# Solve
@polyvar x[1:4]
solutions = solve_polynomial_system(x, 4, pol.degree[2], pol.coeffs, basis=:chebyshev)
df = process_crit_pts(solutions, f, TR)

println("\nRaw critical points found: $(nrow(df))")

# Find closest to expected
best_idx = 1
best_dist = Inf
for i in 1:nrow(df)
    pt = [df[i, Symbol("x$j")] for j in 1:4]
    d = norm(pt - expected)
    if d < best_dist
        best_dist = d
        best_idx = i
    end
end

raw_pt = [df[best_idx, Symbol("x$j")] for j in 1:4]
raw_val = df[best_idx, :z]

# Refine with BFGS
result = Optim.optimize(f, raw_pt, Optim.BFGS())
ref_pt = Optim.minimizer(result)
ref_val = Optim.minimum(result)

println("\n" * "="^60)
println("COMPARISON:")
println("="^60)
println("Raw:     $([Printf.@sprintf("%.4f", x) for x in raw_pt])")
println("         f = $(Printf.@sprintf("%.6f", raw_val)), dist = $(Printf.@sprintf("%.3e", norm(raw_pt - expected)))")
println("\nRefined: $([Printf.@sprintf("%.4f", x) for x in ref_pt])")
println("         f = $(Printf.@sprintf("%.6f", ref_val)), dist = $(Printf.@sprintf("%.3e", norm(ref_pt - expected)))")
println("\nImprovement: $(Printf.@sprintf("%.0f", norm(raw_pt - expected) / norm(ref_pt - expected)))x closer")