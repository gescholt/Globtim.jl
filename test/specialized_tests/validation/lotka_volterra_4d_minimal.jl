#!/usr/bin/env julia
#=
Lotka-Volterra 4D Minimal Example
Following standard notebook patterns for critical point computation
=#

using Globtim
using StaticArrays

# Constants and Parameters (following notebook patterns)
const n = 4                                    # Dimension
const d = 6                                    # Polynomial degree
const SMPL = 12                               # Samples per dimension
const params_4d = [1.2, 1.1, 1.05, 0.95]    # Lotka-Volterra parameters
const center = [0.0, 0.0, 0.0, 0.0]          # Sampling center

# Define objective function
f = lotka_volterra_4d

println("Lotka-Volterra 4D: dim=$n, degree=$d, samples=$SMPL, total=$(SMPL^n) points")

# Step 1: Grid Generation and Sampling
println("Step 1: Grid generation...")
TR = TestInput(f,
    dim = n,
    center = center,
    GN = SMPL,
    sample_range = 2.0,
    params = params_4d
)

# Step 2: Polynomial Approximation
println("Step 2: Chebyshev polynomial construction...")
pol_cheb = Constructor(TR, d, basis = :chebyshev)
println("L2 norm: $(pol_cheb.nrm)")

# Step 3: Critical Point Solving (HomotopyContinuation)
println("Step 3: Critical point solving...")
@polyvar(x[1:n])

real_pts = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis = pol_cheb.basis,
    precision = pol_cheb.precision,
    normalized = false,
    power_of_two_denom = pol_cheb.power_of_two_denom
)
println("Real critical points found: $(length(real_pts))")

# Step 4: Process Critical Points
println("Step 4: Processing critical points...")
df = process_crit_pts(real_pts, f, TR)
println("Points in bounds: $(nrow(df))")

# Step 5: Analyze Critical Points (with optimization)
println("Step 5: Analyzing critical points...")
df_analyzed, df_min = analyze_critical_points(f, df, TR, tol_dist = 0.1)
println("Total critical points: $(nrow(df_analyzed)), Minimizers: $(nrow(df_min))")

# Summary
println(
    "Quality: $(pol_cheb.nrm < 1e-3 ? "Excellent" : pol_cheb.nrm < 0.1 ? "Good" : "Poor"), Critical points: $(nrow(df)), Minimizers: $(nrow(df_min))"
)

if nrow(df_min) > 0
    best_min = df_min[argmin(df_min.value), :]
    println(
        "Best minimum: [$(round(best_min.x1, digits=3)), $(round(best_min.x2, digits=3)), $(round(best_min.x3, digits=3)), $(round(best_min.x4, digits=3))] = $(round(best_min.value, digits=6))"
    )
end
