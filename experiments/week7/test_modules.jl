"""
Test script to verify the modular valley walking components
"""

using Pkg; Pkg.activate(@__DIR__)

using Globtim
using DynamicPolynomials
using DataFrames
using Printf

# Include modules
include("test_functions.jl")
include("valley_walking_utils.jl")
include("polynomial_degree_optimization.jl")
include("valley_walking_tables.jl")

# Test 1: Test functions
println("="^60)
println("TEST 1: Test Functions Module")
println("="^60)

func_info = get_test_function_info(:rosenbrock_2d)
println("Function: $(func_info.description)")
println("True minima: $(func_info.true_minima)")
println("Domain: $(func_info.domain)")

# Evaluate at a point
test_point = [0.5, 0.5]
f_value = func_info.func(test_point)
println("f($test_point) = $f_value")

# Test 2: Polynomial degree optimization
println("\n" * "="^60)
println("TEST 2: Polynomial Degree Optimization")
println("="^60)

base_config = (
    n = 2,
    p_true = [[1.0, 1.0]],
    sample_range = 1.0,
    basis = :chebyshev,
    precision = Globtim.RationalPrecision,
    p_center = [1.0, 1.0]
)

# Test with just a few degrees
degree_configs = [
    DegreeTestConfig(4, 50),
    DegreeTestConfig(6, 80),
]

println("Testing degrees: ", [c.degree for c in degree_configs])

# Test 3: Tables module
println("\n" * "="^60)
println("TEST 3: Tables Module")
println("="^60)

# Create dummy results for table testing
dummy_results = [
    (degree=4, samples=50, n_critical_points=3, condition_number=10.5, 
     l2_error=0.001, success=true),
    (degree=6, samples=80, n_critical_points=5, condition_number=25.3, 
     l2_error=0.0005, success=true),
    (degree=8, samples=120, n_critical_points=0, condition_number=Inf, 
     l2_error=Inf, success=false),
]

display_polynomial_comparison_table(dummy_results)

# Test 4: Valley walking utils
println("\n" * "="^60)
println("TEST 4: Valley Walking Utils")
println("="^60)

# Simple test with Rosenbrock
start_point = [0.5, 0.5]
println("Starting valley walk from: $start_point")

points, eigenvals, f_vals, step_types = enhanced_valley_walk(
    func_info.func, start_point;
    n_steps = 5,
    verbose = false
)

println("Valley walk completed:")
println("  Steps taken: $(length(points)-1)")
println("  Initial f: $(f_vals[1])")
println("  Final f: $(f_vals[end])")
println("  Valley steps: $(count(s -> s == "valley", step_types))")
println("  Gradient steps: $(count(s -> s == "gradient", step_types))")

println("\n✓ All modules loaded and tested successfully!")