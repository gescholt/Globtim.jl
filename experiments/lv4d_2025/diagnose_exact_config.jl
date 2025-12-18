#!/usr/bin/env julia
"""
Test with EXACT experiment configuration to reproduce 1000x slowdown.
"""

using Pkg
Pkg.activate(".")

using ModelingToolkit
using OrdinaryDiffEq
using StaticArrays
using Statistics

include("../../Examples/systems/DynamicalSystems.jl")
using .DynamicalSystems

println("="^80)
println("EXACT CONFIGURATION TEST - Issue #203")
println("="^80)

# EXACT experiment configuration
ic = [1.0, 2.0, 1.0, 1.0]
time_interval = [0.0, 10.0]
num_points = 25
eval_timeout = 5.0

p_center = [0.8, 0.6, 0.5, 0.3]
domain_size = 0.4
p_true = p_center .+ (rand(4) .- 0.5) .* (domain_size * 0.8)

println("\nConfiguration:")
println("  Model: Daisy Ex3 4D")
println("  Time interval: $time_interval")
println("  Time points: $num_points")
println("  Timeout: $(eval_timeout)s")
println("  p_true: $p_true")

# Setup EXACT model (Daisy Ex3, not LV4D!)
println("\nSetting up Daisy Ex3 4D model...")
model, params, states, outputs = define_daisy_ex3_model_4D()

# Test 1: WITHOUT timeout
println("\n" * "="^80)
println("TEST 1: WITHOUT timeout wrapper")
println("="^80)

error_func_no_timeout = make_error_distance(
    model, outputs, ic, p_true,
    time_interval, num_points, L2_norm, first, nothing;
    return_inf_on_error = true,
    eval_timeout = nothing  # NO TIMEOUT
)

println("\nTiming 10 evaluations...")
times_no_timeout = Float64[]
for i in 1:10
    p_test = SVector{4, Float64}(
        p_center[1] + 0.01*i,
        p_center[2] + 0.001*i,
        p_center[3] + 0.01*i,
        p_center[4] + 0.001*i
    )
    t = @elapsed val = error_func_no_timeout(p_test)
    push!(times_no_timeout, t)
    if i <= 5
        println("  Eval $i: $(round(t*1000, digits=1))ms")
    end
end

mean_no_timeout = mean(times_no_timeout[2:end]) * 1000  # Skip first (compilation)
println("  → Mean (excluding first): $(round(mean_no_timeout, digits=1))ms")
println("  → Throughput: $(round(1000/mean_no_timeout, digits=1)) pts/sec")

# Test 2: WITH timeout (as in experiment)
println("\n" * "="^80)
println("TEST 2: WITH timeout wrapper (eval_timeout=5.0s)")
println("="^80)

error_func_with_timeout = make_error_distance(
    model, outputs, ic, p_true,
    time_interval, num_points, L2_norm, first, nothing;
    return_inf_on_error = true,
    eval_timeout = eval_timeout  # WITH TIMEOUT
)

println("\nTiming 10 evaluations...")
times_with_timeout = Float64[]
for i in 1:10
    p_test = SVector{4, Float64}(
        p_center[1] + 0.01*i,
        p_center[2] + 0.001*i,
        p_center[3] + 0.01*i,
        p_center[4] + 0.001*i
    )
    t = @elapsed val = error_func_with_timeout(p_test)
    push!(times_with_timeout, t)
    if i <= 5
        println("  Eval $i: $(round(t*1000, digits=1))ms")
    end
end

mean_with_timeout = mean(times_with_timeout[2:end]) * 1000
println("  → Mean (excluding first): $(round(mean_with_timeout, digits=1))ms")
println("  → Throughput: $(round(1000/mean_with_timeout, digits=1)) pts/sec")

# Analysis
println("\n" * "="^80)
println("ANALYSIS")
println("="^80)

timeout_overhead = mean_with_timeout / mean_no_timeout

println("\nPerformance:")
println("  Without timeout: $(round(mean_no_timeout, digits=1))ms → $(round(1000/mean_no_timeout, digits=1)) pts/sec")
println("  With timeout:    $(round(mean_with_timeout, digits=1))ms → $(round(1000/mean_with_timeout, digits=1)) pts/sec")
println("  Timeout overhead: $(round(timeout_overhead, digits=2))x")

println("\nComparison to experiment:")
println("  Experiment observed: 9.7 pts/sec (103ms per point)")
println("  This test (no timeout): $(round(1000/mean_no_timeout, digits=1)) pts/sec")
println("  This test (with timeout): $(round(1000/mean_with_timeout, digits=1)) pts/sec")

if mean_with_timeout > 80
    println("\n⚠️  REPRODUCED! Timeout wrapper causes massive slowdown!")
    println("   Likely issue: @async + timedwait overhead in DynamicalSystems.jl:518-554")
else
    println("\n✅ Still fast - slowdown not yet reproduced.")
    println("   Need to investigate other factors...")
end

println("\n" * "="^80)
