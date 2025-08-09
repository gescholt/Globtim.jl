#!/usr/bin/env julia

"""
Simple Function Evaluation Test (No Globtim Dependencies)
Tests basic function evaluation and output collection workflow
"""

using Dates
using Printf

println("=== Function Evaluation Test ===")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
println()

# Define a simple test function (similar to Deuflhard structure)
function simple_test_function(x::Vector{Float64})
    """
    Simple 2D test function for evaluation
    f(x,y) = (x-1)^2 + (y-1)^2 + sin(x*y)
    """
    if length(x) != 2
        error("Function requires exactly 2 dimensions")
    end
    
    x1, x2 = x[1], x[2]
    return (x1 - 1.0)^2 + (x2 - 1.0)^2 + sin(x1 * x2)
end

# Define evaluation points
test_points = [
    [0.0, 0.0],
    [0.5, 0.5],
    [1.0, 1.0],
    [1.5, 1.5],
    [-0.5, 0.5],
    [0.0, 1.0],
    [2.0, 0.0],
    [-1.0, -1.0],
    [0.25, 0.75],
    [1.25, 0.25]
]

println("🧮 Evaluating simple_test_function at $(length(test_points)) points:")
println()

# Evaluate function at all test points
results = []
for (i, point) in enumerate(test_points)
    try
        value = simple_test_function(point)
        push!(results, (point, value))
        @printf("  Point %2d: f([%6.3f, %6.3f]) = %12.6f\n", i, point[1], point[2], value)
    catch e
        println("  Point $i: ERROR at $point - $e")
        push!(results, (point, NaN))
    end
end

println()
println("✅ Function evaluation completed")

# Create results directory
results_dir = "results"
if !isdir(results_dir)
    mkdir(results_dir)
    println("✅ Created results directory: $results_dir")
end

# Save results to CSV file
csv_filename = joinpath(results_dir, "function_evaluation_results.csv")
open(csv_filename, "w") do f
    println(f, "point_id,x1,x2,function_value,timestamp")
    for (i, (point, value)) in enumerate(results)
        println(f, "$i,$(point[1]),$(point[2]),$value,$(now())")
    end
end
println("✅ Results saved to: $csv_filename")

# Save detailed summary
summary_filename = joinpath(results_dir, "function_evaluation_summary.txt")
open(summary_filename, "w") do f
    println(f, "Function Evaluation Test Summary")
    println(f, "================================")
    println(f, "")
    println(f, "Test Details:")
    println(f, "- Function: simple_test_function(x) = (x1-1)^2 + (x2-1)^2 + sin(x1*x2)")
    println(f, "- Evaluation points: $(length(test_points))")
    println(f, "- Julia version: $(VERSION)")
    println(f, "- Hostname: $(gethostname())")
    println(f, "- SLURM Job ID: $(get(ENV, "SLURM_JOB_ID", "not_set"))")
    println(f, "- Timestamp: $(now())")
    println(f, "")
    println(f, "Results:")
    for (i, (point, value)) in enumerate(results)
        @printf(f, "  Point %2d: f([%6.3f, %6.3f]) = %12.6f\n", i, point[1], point[2], value)
    end
    println(f, "")
    println(f, "Statistics:")
    valid_values = [v for (p, v) in results if !isnan(v)]
    if length(valid_values) > 0
        println(f, "- Valid evaluations: $(length(valid_values))/$(length(results))")
        println(f, "- Minimum value: $(minimum(valid_values))")
        println(f, "- Maximum value: $(maximum(valid_values))")
        println(f, "- Mean value: $(sum(valid_values)/length(valid_values))")
    end
end
println("✅ Summary saved to: $summary_filename")

println()
println("📁 Output files created:")
println("  - $csv_filename")
println("  - $summary_filename")

println()
println("=== Test Complete ===")
println("End Time: ", now())
