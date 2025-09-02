#!/usr/bin/env julia
# Enhanced 4D Model Experiment with Critical Points DataFrame Output
# This script runs the complete GlobTim pipeline and saves critical points

using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))

using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates
using JSON

# Get parameters from environment or use defaults
samples_per_dim = parse(Int, get(ENV, "SAMPLES_PER_DIM", "10"))
degree = parse(Int, get(ENV, "DEGREE", "12"))
results_dir = length(ARGS) > 0 ? ARGS[1] : joinpath(@__DIR__, "results_4d_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")

mkpath(results_dir)

# Timer for performance tracking
to = TimerOutput()

println("\n" * "="^70)
println("4D Model Experiment - Enhanced with Critical Points Tracking")
println("="^70)
println("Configuration:")
println("  Dimension: 4")
println("  Degree: $degree")
println("  Samples per dimension: $samples_per_dim")
println("  Total grid points: $(samples_per_dim^4)")
println("  Results directory: $results_dir")
println("="^70)

# Define the 4D test function (example: modified Rosenbrock-like function)
function error_func_4d(p::AbstractVector)
    # 4D test function with multiple local minima
    x, y, z, w = p
    
    # Rosenbrock-like with additional terms for 4D
    term1 = 100 * (y - x^2)^2 + (1 - x)^2
    term2 = 100 * (z - y^2)^2 + (1 - y)^2
    term3 = 100 * (w - z^2)^2 + (1 - z)^2
    
    # Add some oscillation for more interesting critical points
    oscillation = 5 * sin(2π * x) * cos(2π * y) * sin(2π * z) * cos(2π * w)
    
    return term1 + term2 + term3 + oscillation
end

# Configuration
n = 4
p_center = [0.25, 0.25, 0.45, 0.55]
sample_range = 0.2  # Slightly larger range for 4D
GN = samples_per_dim^n

println("\nStep 1: Generating sample points and evaluating function...")
@timeit to "test_input" begin
    TR = test_input(
        error_func_4d,
        dim = n,
        center = p_center,
        GN = GN,
        sample_range = sample_range
    )
end
println("✓ Generated $(length(TR.sample_pts)) sample points")

println("\nStep 2: Constructing polynomial approximation...")
@timeit to "constructor" begin
    pol = Constructor(
        TR,
        (:one_d_for_all, degree),
        basis = :chebyshev,
        precision = Float64Precision,
        verbose = true
    )
end
println("✓ Polynomial approximation complete")
println("  Condition number: $(pol.cond_vandermonde)")
println("  L2 norm (error): $(pol.nrm)")

# Save approximation info
approx_info = Dict(
    "dimension" => n,
    "degree" => degree,
    "samples_per_dim" => samples_per_dim,
    "total_samples" => GN,
    "condition_number" => pol.cond_vandermonde,
    "L2_norm" => pol.nrm,
    "basis" => "chebyshev",
    "center" => p_center,
    "sample_range" => sample_range
)

open(joinpath(results_dir, "approximation_info.json"), "w") do io
    JSON.print(io, approx_info, 2)
end

println("\nStep 3: Finding critical points of the approximant...")
@polyvar(x[1:n])

@timeit to "solve_polynomial" begin
    real_pts, (system, nsols) = solve_polynomial_system(
        x,
        n,
        (:one_d_for_all, degree),
        pol.coeffs;
        basis = :chebyshev,
        return_system = true
    )
end
println("✓ Polynomial system solved")
println("  Total solutions: $nsols")
println("  Real solutions: $(length(real_pts))")

println("\nStep 4: Optimizing on critical points...")
@timeit to "process_critical_points" begin
    df_critical = process_crit_pts(real_pts, error_func_4d, TR)
end

# Add timing information to DataFrame
df_critical[!, :computation_time] .= time(to["process_critical_points"])

println("✓ Critical points processed")
println("  Number of critical points: $(nrow(df_critical))")

# Display summary statistics
if nrow(df_critical) > 0
    println("\nCritical Points Summary:")
    println("  Best value found: $(minimum(df_critical.val))")
    println("  Worst value found: $(maximum(df_critical.val))")
    println("  Mean value: $(mean(df_critical.val))")
    
    # Find the global minimum
    best_idx = argmin(df_critical.val)
    best_point = df_critical[best_idx, :]
    println("\nBest critical point:")
    println("  Location: [$(join(round.(best_point.x, digits=6), ", "))]")
    println("  Value: $(best_point.val)")
    println("  Gradient norm: $(best_point.grad_norm)")
end

# Save critical points DataFrame
csv_file = joinpath(results_dir, "critical_points.csv")
CSV.write(csv_file, df_critical)
println("\n✓ Critical points saved to: $csv_file")

# Save detailed timing report
timing_file = joinpath(results_dir, "timing_report.txt")
open(timing_file, "w") do io
    print(io, to)
end
println("✓ Timing report saved to: $timing_file")

# Create summary report
summary_file = joinpath(results_dir, "summary.txt")
open(summary_file, "w") do io
    println(io, "4D Model Experiment Summary")
    println(io, "="^50)
    println(io, "Generated: $(Dates.now())")
    println(io, "")
    println(io, "Configuration:")
    println(io, "  Dimension: $n")
    println(io, "  Polynomial degree: $degree")
    println(io, "  Samples per dimension: $samples_per_dim")
    println(io, "  Total grid points: $GN")
    println(io, "  Sample range: $sample_range")
    println(io, "  Center point: $p_center")
    println(io, "")
    println(io, "Approximation Quality:")
    println(io, "  Condition number: $(pol.cond_vandermonde)")
    println(io, "  L2 norm (error): $(pol.nrm)")
    println(io, "")
    println(io, "Critical Points Results:")
    println(io, "  Total polynomial solutions: $nsols")
    println(io, "  Real solutions found: $(length(real_pts))")
    println(io, "  Critical points after optimization: $(nrow(df_critical))")
    
    if nrow(df_critical) > 0
        println(io, "  Best value: $(minimum(df_critical.val))")
        println(io, "  Worst value: $(maximum(df_critical.val))")
        best_idx = argmin(df_critical.val)
        best_point = df_critical[best_idx, :]
        println(io, "  Best point location: [$(join(round.(best_point.x, digits=6), ", "))]")
    end
    
    println(io, "")
    println(io, "Timing Breakdown:")
    println(io, to)
end
println("✓ Summary saved to: $summary_file")

# Also save DataFrame as JSON for easier parsing
json_file = joinpath(results_dir, "critical_points.json")
open(json_file, "w") do io
    # Convert DataFrame to dictionary for JSON serialization
    dict_array = [Dict(names(df_critical) .=> values(row)) for row in eachrow(df_critical)]
    JSON.print(io, dict_array, 2)
end
println("✓ Critical points JSON saved to: $json_file")

println("\n" * "="^70)
println("Experiment completed successfully!")
println("Results saved in: $results_dir")
println("="^70)

# Return the DataFrame for potential further processing
df_critical