#!/usr/bin/env julia
# 2D Deuflhard Test for HPC Workflow Validation
# Based on Examples/Notebooks/Deuflhard.ipynb
# Purpose: Validate SLURM job submission and output collection

# Issue #53 Fix: Ensure package dependencies are properly instantiated
using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))  # Activate main globtim project
Pkg.instantiate()  # Fix for "Package StaticArrays is required but does not seem to be installed"

# Core imports - minimal dependencies for HPC
using Globtim
using DynamicPolynomials
using DataFrames
using TimerOutputs
using Dates
using LinearAlgebra

# Get output directory from command line or use default
results_dir = length(ARGS) > 0 ? ARGS[1] : joinpath(@__DIR__, "results_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")
mkdir(results_dir)

# Initialize timer for performance tracking
const to = TimerOutput()

println("="^60)
println("2D Deuflhard HPC Workflow Test")
println("Start time: $(now())")
println("Results directory: $results_dir")
println("Julia threads: $(Threads.nthreads())")
println("="^60)

# Test parameters - kept small for validation
const n = 2  # Dimension
const d = 8  # Polynomial degree
const SMPL = 25  # Number of samples (reduced for quick testing)
const center = [0.0, 0.0]
const sample_range = [1.2, 1.5]

# Deuflhard function (embedded to avoid dependency issues)
function Deuflhard(x::AbstractVector)
    a, b = 8, 5
    n = length(x)
    return sum(i -> (exp(-1/abs(x[i])) + exp(-1/abs(x[i] - 1/b)) + 
                     exp(-1/abs(x[i] - 2/b)) + exp(-1/abs(x[i] - 3/b)) + 
                     exp(-1/abs(x[i] - 4/b)))^a, 1:n)
end

println("\nStarting computation...")

# Main computation with timing
@timeit to "test_input" begin
    TR = test_input(Deuflhard,
                    dim=n,
                    center=center,
                    GN=SMPL,
                    sample_range=sample_range)
end

# Test both Chebyshev and Legendre bases
results = Dict()

for basis in [:chebyshev, :legendre]
    println("\nProcessing $basis basis...")
    
    @timeit to "constructor_$basis" begin
        pol = Constructor(TR, d, basis=basis)
        results[basis] = Dict(
            "L2_norm" => pol.nrm,
            "condition_number" => pol.cond_vandermonde,
            "basis" => string(basis)
        )
    end
    
    # Solve polynomial system
    @polyvar(x[1:n])
    
    @timeit to "solve_$basis" begin
        real_pts = solve_polynomial_system(
            x, n, d, pol.coeffs;
            basis=pol.basis,
            precision=pol.precision
        )
    end
    
    # Process critical points
    @timeit to "process_$basis" begin
        df = process_crit_pts(real_pts, Deuflhard, TR)
        results[basis]["num_critical_points"] = nrow(df)
        results[basis]["critical_points"] = df
    end
    
    # Save intermediate results
    output_file = joinpath(results_dir, "$(basis)_results.txt")
    open(output_file, "w") do io
        println(io, "Basis: $basis")
        println(io, "L2 norm: $(results[basis]["L2_norm"])")
        println(io, "Condition number: $(results[basis]["condition_number"])")
        println(io, "Number of critical points: $(results[basis]["num_critical_points"])")
        println(io, "\nCritical points:")
        println(io, df)
    end
    
    println("✓ $basis results saved to: $output_file")
end

# Save timing information
timing_file = joinpath(results_dir, "timing_report.txt")
open(timing_file, "w") do io
    print(io, to)
end

# Create summary report
summary_file = joinpath(results_dir, "summary.json")
open(summary_file, "w") do io
    # Manual JSON creation to avoid dependency
    println(io, "{")
    println(io, "  \"timestamp\": \"$(now())\",")
    println(io, "  \"julia_version\": \"$(VERSION)\",")
    println(io, "  \"threads\": $(Threads.nthreads()),")
    println(io, "  \"samples\": $SMPL,")
    println(io, "  \"degree\": $d,")
    println(io, "  \"dimension\": $n,")
    println(io, "  \"chebyshev_critical_points\": $(results[:chebyshev]["num_critical_points"]),")
    println(io, "  \"legendre_critical_points\": $(results[:legendre]["num_critical_points"]),")
    println(io, "  \"chebyshev_condition\": $(results[:chebyshev]["condition_number"]),")
    println(io, "  \"legendre_condition\": $(results[:legendre]["condition_number"])")
    println(io, "}")
end

println("\n" * "="^60)
println("Test completed successfully!")
println("End time: $(now())")
println("\nResults summary:")
println("  Chebyshev: $(results[:chebyshev]["num_critical_points"]) critical points, cond=$(round(results[:chebyshev]["condition_number"], digits=2))")
println("  Legendre: $(results[:legendre]["num_critical_points"]) critical points, cond=$(round(results[:legendre]["condition_number"], digits=2))")
println("\nAll results saved to: $results_dir")
println("="^60)

# Exit with success
exit(0)