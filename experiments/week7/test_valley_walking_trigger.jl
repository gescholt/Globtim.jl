"""
Test script to trigger actual valley walking behavior.
We need a function with a true valley (rank-deficient Hessian) where gradient is small.
"""

using Pkg; Pkg.activate(@__DIR__)

using LinearAlgebra
using ForwardDiff
using Printf

include("valley_walking_utils.jl")

# Create a function with a true rank-deficient valley
# This is a narrow parabolic valley: very flat along x direction when y ≈ 0
function narrow_valley(x)
    return x[2]^2 + 0.01 * (x[1] - x[2]^2)^2
end

# Alternative: A function that's exactly rank-deficient at certain points
function rank_deficient_function(x)
    # This has a valley along the curve x[2] = x[1]^2
    return (x[2] - x[1]^2)^2 + 0.001 * x[1]^2
end

println("="^80)
println("TESTING VALLEY WALKING TRIGGER")
println("="^80)

# Test 1: Narrow valley function
println("\n1. NARROW VALLEY FUNCTION")
println("-"^60)

# Start at a point in the valley but not at minimum
x0 = [2.0, 0.01]  # Near the valley floor

g0 = ForwardDiff.gradient(narrow_valley, x0)
H0 = ForwardDiff.hessian(narrow_valley, x0)
λ0, V0 = eigen(H0)

println("Starting point: $(x0)")
println("f(x0) = $(narrow_valley(x0))")
println("||gradient|| = $(norm(g0))")
println("Gradient = $(g0)")
println("Eigenvalues = $(λ0)")
println("Min |eigenvalue| = $(minimum(abs.(λ0)))")

# Run with parameters that should trigger valley walking
points, eigenvals, f_vals, step_types = enhanced_valley_walk(
    narrow_valley, x0;
    n_steps = 30,
    step_size = 0.1,
    ε_null = 0.01,  # Higher threshold to catch near-zero eigenvalues
    gradient_step_size = 0.05,
    rank_deficiency_threshold = 0.1,  # Higher threshold
    gradient_norm_tolerance = 1.0,     # Higher tolerance
    verbose = true
)

n_valley = count(s -> s == "valley", step_types)
n_gradient = count(s -> s == "gradient", step_types)

println("\nSummary:")
println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
println("  Final point: $(round.(points[end], digits=4))")
println("  Final f: $(round(f_vals[end], digits=6))")

# Test 2: Rank-deficient function
println("\n\n2. RANK-DEFICIENT FUNCTION")
println("-"^60)

# Start exactly on the valley x[2] = x[1]^2
x0 = [1.0, 1.0]  # On the valley

g0 = ForwardDiff.gradient(rank_deficient_function, x0)
H0 = ForwardDiff.hessian(rank_deficient_function, x0)
λ0, V0 = eigen(H0)

println("Starting point: $(x0)")
println("f(x0) = $(rank_deficient_function(x0))")
println("||gradient|| = $(norm(g0))")
println("Gradient = $(g0)")
println("Eigenvalues = $(λ0)")
println("Min |eigenvalue| = $(minimum(abs.(λ0)))")
println("\nEigenvector for smallest eigenvalue:")
println("  v = $(V0[:, argmin(abs.(λ0))])")

# Run with very permissive parameters
points, eigenvals, f_vals, step_types = enhanced_valley_walk(
    rank_deficient_function, x0;
    n_steps = 30,
    step_size = 0.1,
    ε_null = 1e-6,
    gradient_step_size = 0.05,
    rank_deficiency_threshold = 0.5,  # Very permissive
    gradient_norm_tolerance = 10.0,   # Very high tolerance
    verbose = true
)

n_valley = count(s -> s == "valley", step_types)
n_gradient = count(s -> s == "gradient", step_types)

println("\nSummary:")
println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
println("  Final point: $(round.(points[end], digits=4))")
println("  Final f: $(round(f_vals[end], digits=6))")

# Test 3: Force valley walking by starting at a constructed point
println("\n\n3. FORCED VALLEY WALKING TEST")
println("-"^60)

# Use a simple quadratic with a designed valley
valley_test(x) = 100*(x[2] - x[1])^2 + x[1]^2

# Start at a point designed to have small gradient and rank-deficient Hessian
x0 = [0.001, 0.001]

g0 = ForwardDiff.gradient(valley_test, x0)
H0 = ForwardDiff.hessian(valley_test, x0)
λ0, V0 = eigen(H0)

println("Starting point: $(x0)")
println("f(x0) = $(valley_test(x0))")
println("||gradient|| = $(norm(g0))")
println("Gradient = $(g0)")
println("Eigenvalues = $(λ0)")
println("Min |eigenvalue| = $(minimum(abs.(λ0)))")

# Run with parameters specifically designed to trigger valley walking
points, eigenvals, f_vals, step_types = enhanced_valley_walk(
    valley_test, x0;
    n_steps = 20,
    step_size = 0.01,
    ε_null = 1e-6,
    gradient_step_size = 0.001,
    rank_deficiency_threshold = 10.0,  # Very high to force valley detection
    gradient_norm_tolerance = 1.0,     # Gradient norm is ~0.2, so this should pass
    verbose = true
)

n_valley = count(s -> s == "valley", step_types)
n_gradient = count(s -> s == "gradient", step_types)

println("\nSummary:")
println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
println("  Final point: $(round.(points[end], digits=4))")
println("  Final f: $(round(f_vals[end], digits=6))")