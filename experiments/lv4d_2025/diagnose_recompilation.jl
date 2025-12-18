#!/usr/bin/env julia
"""
Diagnostic script to test if ModelingToolkit recompilation is causing 1900x slowdown.

Tests:
1. Repeated evaluations with same vs different parameters
2. Method compilation tracking
3. Parameter mutation vs remake() performance
"""

using Pkg
Pkg.activate(".")

using ModelingToolkit
using OrdinaryDiffEq
using StaticArrays
using BenchmarkTools
using Profile
using InteractiveUtils

include("../../Examples/systems/DynamicalSystems.jl")
using .DynamicalSystems

println("="^80)
println("RECOMPILATION DIAGNOSTIC - Issue #203")
println("="^80)

# Setup: Create LV4D model
println("\n[1/5] Setting up Lotka-Volterra 4D model...")
model, parameters, states, measured = define_constrained_lotka_volterra_4D()

# Reference parameters
p_true = [0.5, 0.1, 1.5, 0.1]
initial_conditions = [1.2, 1.0, 3.0, 1.0]
time_interval = [0.0, 5.0]
numpoints = 5

println("  ✓ Model defined")
println("  ✓ Parameters: $p_true")
println("  ✓ Initial conditions: $initial_conditions")

# Create error distance function
println("\n[2/5] Creating objective function...")
f = make_error_distance(
    model, measured, initial_conditions, p_true,
    time_interval, numpoints, L2_norm
)
println("  ✓ Objective function created")
println("  ✓ Function type: $(typeof(f))")

# Test 1: Repeated evaluation with SAME parameters
println("\n[3/5] TEST 1: Repeated evaluation with SAME parameters")
println("  (If compilation is the issue, first eval should be slow, rest fast)")

p_test = SVector{4, Float64}(0.6, 0.12, 1.6, 0.12)

# First evaluation (may include compilation)
print("  Evaluation 1 (cold): ")
t1 = @elapsed val1 = f(p_test)
println("$(round(t1*1000, digits=1))ms")

# Subsequent evaluations (should be fast if compiled)
times_same = Float64[]
for i in 2:10
    t = @elapsed val = f(p_test)
    push!(times_same, t)
    if i <= 5  # Print first few
        println("  Evaluation $i: $(round(t*1000, digits=1))ms")
    end
end

mean_same = mean(times_same) * 1000
println("  → Mean (eval 2-10): $(round(mean_same, digits=1))ms")

# Test 2: Repeated evaluation with DIFFERENT parameters
println("\n[4/5] TEST 2: Repeated evaluation with DIFFERENT parameters")
println("  (If recompilation happens, all evals should be slow)")

times_different = Float64[]
for i in 1:10
    # Generate slightly different parameters each time
    p_test_varied = SVector{4, Float64}(
        0.5 + 0.01*i,
        0.1 + 0.001*i,
        1.5 + 0.01*i,
        0.1 + 0.001*i
    )
    t = @elapsed val = f(p_test_varied)
    push!(times_different, t)
    if i <= 5
        println("  Evaluation $i: $(round(t*1000, digits=1))ms")
    end
end

mean_different = mean(times_different) * 1000
println("  → Mean: $(round(mean_different, digits=1))ms")

# Analysis
println("\n[5/5] ANALYSIS")
println("="^80)

ratio = mean_different / mean_same
println("Performance comparison:")
println("  Same parameters (cached):      $(round(mean_same, digits=1))ms")
println("  Different parameters (varied): $(round(mean_different, digits=1))ms")
println("  Slowdown ratio: $(round(ratio, digits=2))x")

if ratio > 2.0
    println("\n⚠️  CRITICAL: Different parameters are $(round(ratio, digits=1))x slower!")
    println("   This suggests ModelingToolkit is recompiling on each evaluation.")
    println("\n   Root cause: Likely mutating problem.p.tunable triggers:")
    println("   - ODE function re-specialization")
    println("   - Jacobian reconstruction")
    println("   - Method cache invalidation")
elseif ratio > 1.2
    println("\n⚠️  MODERATE: Different parameters are $(round(ratio, digits=1))x slower.")
    println("   Some overhead from parameter changes, but not catastrophic.")
else
    println("\n✅ GOOD: No significant slowdown from parameter variation.")
    println("   Recompilation is NOT the bottleneck.")
end

# Method compilation tracking
println("\n" * "="^80)
println("METHOD COMPILATION TRACKING")
println("="^80)

println("\nTracking method recompilation...")
println("(Running 20 evaluations with varied parameters)")

# Clear method caches if possible
# Note: Julia doesn't provide direct cache clearing, but we can track invalidations

method_count_before = length(methods(f))
p_test_track = SVector{4, Float64}(0.55, 0.11, 1.55, 0.11)

# Force compilation
f(p_test_track)

# Track subsequent compilations
for i in 1:20
    p_varied = SVector{4, Float64}(
        0.5 + 0.05*rand(),
        0.1 + 0.005*rand(),
        1.5 + 0.05*rand(),
        0.1 + 0.005*rand()
    )
    f(p_varied)
end

method_count_after = length(methods(f))

println("  Methods before: $method_count_before")
println("  Methods after:  $method_count_after")
println("  New methods compiled: $(method_count_after - method_count_before)")

# Test 3: Compare problem mutation strategies
println("\n" * "="^80)
println("PARAMETER UPDATE STRATEGY TEST")
println("="^80)

println("\nComparing: problem.p.tunable .= p vs remake(problem, p=p)")
println("(This requires direct access to ODEProblem...)")

# Create problem directly to test
problem = ODEProblem(
    ModelingToolkit.complete(model),
    merge(
        Dict(ModelingToolkit.unknowns(model) .=> initial_conditions),
        Dict(ModelingToolkit.parameters(model) .=> p_true)
    ),
    time_interval
)

solver = Vern9()
sampling_times = range(time_interval[1], time_interval[2], length=numpoints)

println("\nStrategy 1: Mutate problem.p.tunable")
times_mutate = Float64[]
for i in 1:5
    p_test_local = [0.5 + 0.01*i, 0.1 + 0.001*i, 1.5 + 0.01*i, 0.1 + 0.001*i]
    t = @elapsed begin
        problem.p.tunable .= p_test_local
        sol = ModelingToolkit.solve(problem, solver, saveat=sampling_times;
                                      abstol=1e-10, reltol=1e-10, verbose=false)
    end
    push!(times_mutate, t)
    println("  Evaluation $i: $(round(t*1000, digits=1))ms")
end

println("\nStrategy 2: Use remake()")
times_remake = Float64[]
for i in 1:5
    p_test_local = [0.5 + 0.01*i, 0.1 + 0.001*i, 1.5 + 0.01*i, 0.1 + 0.001*i]
    t = @elapsed begin
        prob_new = remake(problem, p=Dict(ModelingToolkit.parameters(model) .=> p_test_local))
        sol = ModelingToolkit.solve(prob_new, solver, saveat=sampling_times;
                                      abstol=1e-10, reltol=1e-10, verbose=false)
    end
    push!(times_remake, t)
    println("  Evaluation $i: $(round(t*1000, digits=1))ms")
end

mean_mutate = mean(times_mutate) * 1000
mean_remake = mean(times_remake) * 1000

println("\nComparison:")
println("  Mutate strategy: $(round(mean_mutate, digits=1))ms")
println("  Remake strategy: $(round(mean_remake, digits=1))ms")
println("  Speedup: $(round(mean_mutate/mean_remake, digits=2))x")

# Final recommendations
println("\n" * "="^80)
println("RECOMMENDATIONS")
println("="^80)

if ratio > 2.0
    println("\n🎯 PRIMARY ISSUE: Recompilation on parameter changes")
    println("\nProposed fixes:")
    println("  1. Use remake() instead of mutating problem.p.tunable")
    println("  2. Pre-compile ODE function with SciMLBase.ODEFunction")
    println("  3. Use DiffEqBase.DAEProblem with pre-built Jacobian")
    println("  4. Cache multiple compiled problems for parameter ranges")
    println("\nExpected speedup: $(round(ratio, digits=1))x (close to 1900x observed!)")
else
    println("\n✅ Recompilation is NOT the primary bottleneck")
    println("   Continue investigating other hypotheses:")
    println("   - ODE solver failures")
    println("   - Memory/GC pressure")
    println("   - Grid parameter ranges")
end

println("\n" * "="^80)
