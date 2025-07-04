# Demo Script: Enhanced BFGS and Ultra-Precision Features
#
# This script demonstrates the key enhancements from the step1-5 implementations
# on a simple 2D example for quick execution.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using ForwardDiff
using Printf
using PrettyTables

# Include enhanced components
redirect_stdout(devnull) do
    include("step1_bfgs_enhanced.jl")
    include("step4_ultra_precision.jl")
end

println("=== Enhanced Features Demonstration ===\n")

# Use simple 2D Deuflhard for quick demo
f = Deuflhard
println("Function: 2D Deuflhard")
println("Expected minimum: f(±0.7412, ∓0.7412) ≈ -0.87107\n")

# Step 1: Get critical points
println("1. Finding critical points...")
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, 8, verbose=false)
@polyvar x[1:2]
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
solutions = solve_polynomial_system(x, 2, actual_degree, pol.coeffs)
df_raw = process_crit_pts(solutions, f, TR)
println("   Found $(nrow(df_raw)) critical points\n")

# Step 2: Enhanced BFGS refinement
println("2. Enhanced BFGS refinement with hyperparameter tracking...")
points = [[df_raw[i, :x1], df_raw[i, :x2]] for i in 1:min(5, nrow(df_raw))]
values = df_raw.z[1:min(5, nrow(df_raw))]
labels = ["point_$i" for i in 1:length(points)]

config = BFGSConfig(
    standard_tolerance = 1e-10,
    high_precision_tolerance = 1e-14,
    max_iterations = 100,
    show_trace = false
)

results = enhanced_bfgs_refinement(points, values, labels, f, config, expected_minimum = [0.7412, -0.7412])  # Known minimum for 2D Deuflhard

# Display formatted results
println("\nBFGS Results:")
data = Matrix{Any}(undef, length(results), 5)
for (i, r) in enumerate(results)
    data[i, :] = [
        r.orthant_label,
        Printf.@sprintf("%.6e", r.initial_value),
        Printf.@sprintf("%.6e", r.refined_value),
        r.iterations_used,
        Printf.@sprintf("%.3e", r.final_grad_norm)
    ]
end

pretty_table(
    data,
    header = ["Point", "Initial", "Refined", "Iters", "Grad Norm"],
    alignment = [:l, :r, :r, :c, :r]
)

# Step 3: Ultra-precision for best result
best_idx = argmin([r.refined_value for r in results])
best = results[best_idx]

println("\n3. Ultra-precision refinement of best point...")
println("   Initial: $(Printf.@sprintf("%.10e", best.refined_value))")

ultra_config = UltraPrecisionConfig(
    max_precision_stages = 2,
    stage_tolerance_factors = [1.0, 0.01]
)

ultra_results, histories = ultra_precision_refinement(
    [best.refined_point],
    [best.refined_value],
    f,
    -0.87107,  # Target (known minimum)
    ultra_config,
    labels = ["best"],
    expected_minimum = [0.7412, -0.7412]  # Known minimum for 2D Deuflhard
)

if length(ultra_results) > 0
    final = ultra_results[1]
    println("   Final: $(Printf.@sprintf("%.15e", final.refined_value))")
    println("   Target error: $(Printf.@sprintf("%.3e", abs(final.refined_value - (-0.87107))))")
end

println("\n=== Key Enhancements Demonstrated ===")
println("✓ Structured BFGS configuration and results")
println("✓ Hyperparameter tracking for reproducibility")
println("✓ Multi-stage ultra-precision refinement")
println("✓ Publication-quality formatted tables")
println("✓ Comprehensive error metrics and validation")