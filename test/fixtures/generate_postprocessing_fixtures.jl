#!/usr/bin/env julia
"""
Generate Test Fixtures for globtimpostprocessing

This script generates realistic test data using Globtim's Deuflhard_4d function.
The generated files are written directly to globtimpostprocessing/test/fixtures/
to serve as integration test data.

Generated files:
- critical_points_raw_deg_4.csv
- critical_points_raw_deg_6.csv
- experiment_config.json
- results_summary.json
- test_functions.jl

Usage:
    cd globtim/test/fixtures
    julia --project=../.. generate_postprocessing_fixtures.jl

Output location:
    ../../../globtimpostprocessing/test/fixtures/  (relative to this script)
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Globtim
using StaticArrays
using CSV, DataFrames
using JSON3
using Dates

# ============================================================================
# Configuration
# ============================================================================

const OUTPUT_DIR = joinpath(@__DIR__, "..", "..", "..", "globtimpostprocessing", "test", "fixtures")
const n = 4  # Dimension
const SMPL = 10  # Samples per dimension (10^4 = 10,000 points - fast)
const center = [0.0, 0.0, 0.0, 0.0]
const sample_range = 1.2  # Domain: [-1.2, 1.2]^4
const degrees = [4, 6]
const basis = :chebyshev

# Objective function
const f = Deuflhard_4d

println("="^80)
println("Generating Test Fixtures for globtimpostprocessing")
println("="^80)
println()
println("Function:         Deuflhard_4d")
println("Dimension:        $n")
println("Samples/dim:      $SMPL (total: $(SMPL^n) points)")
println("Domain:           [-$sample_range, $sample_range]^$n")
println("Degrees:          $degrees")
println("Basis:            $basis")
println()
println("Output directory: $OUTPUT_DIR")
println()

# Create output directory
mkpath(OUTPUT_DIR)

# ============================================================================
# Step 1: Grid Generation
# ============================================================================

println("Step 1: Grid Generation")
println("-"^80)

TR = TestInput(f,
    dim = n,
    center = center,
    GN = SMPL,
    sample_range = sample_range
)

println("✓ Grid created: $(SMPL^n) points")
println()

# ============================================================================
# Step 2: Run for Each Degree
# ============================================================================

results_summary = Dict{String, Any}()
all_degree_results = []

for d in degrees
    println("Processing Degree $d")
    println("-"^80)

    # Polynomial approximation
    t_start = time()
    pol_cheb = Constructor(TR, d, basis = basis)
    construction_time = time() - t_start

    println("  L2 norm:          $(round(pol_cheb.nrm, digits=8))")
    println("  Construction:     $(round(construction_time, digits=2))s")

    # Critical point solving
    @polyvar(x[1:n])

    t_start = time()
    real_pts = solve_polynomial_system(
        x, n, d, pol_cheb.coeffs;
        basis = pol_cheb.basis,
        precision = pol_cheb.precision,
        normalized = false,
        power_of_two_denom = pol_cheb.power_of_two_denom
    )
    solving_time = time() - t_start

    println("  Critical points:  $(length(real_pts))")
    println("  Solving:          $(round(solving_time, digits=2))s")

    # Process critical points
    df = process_crit_pts(real_pts, f, TR)
    println("  In domain:        $(nrow(df))")

    # Evaluate objective at each point
    objective_values = [f([df[i, Symbol("x$j")] for j in 1:n]) for i in 1:nrow(df)]

    # Create DataFrame in Phase 2 CSV format
    # Phase 2 format: index, p1, p2, ..., objective
    df_export = DataFrame(
        :index => 1:nrow(df),
        [Symbol("p$i") => df[!, Symbol("x$i")] for i in 1:n]...,
        :objective => objective_values
    )

    # Save CSV
    csv_path = joinpath(OUTPUT_DIR, "critical_points_raw_deg_$d.csv")
    CSV.write(csv_path, df_export)

    filesize_kb = round(stat(csv_path).size / 1024, digits=2)
    println("  ✓ Saved CSV:      $(basename(csv_path)) ($(filesize_kb) KB)")

    # Store degree result
    degree_result = Dict(
        "degree" => d,
        "critical_points" => nrow(df),
        "l2_norm" => pol_cheb.nrm,
        "construction_time_s" => construction_time,
        "solving_time_s" => solving_time,
        "basis" => String(basis)
    )

    push!(all_degree_results, degree_result)
    results_summary["degree_$d"] = degree_result

    println()
end

# ============================================================================
# Step 3: Save experiment_config.json
# ============================================================================

println("Creating Metadata Files")
println("-"^80)

config = Dict(
    "function_name" => "Deuflhard_4d",
    "dimension" => n,
    "basis" => String(basis),
    "GN" => SMPL,
    "domain_center" => center,
    "domain_range" => sample_range,
    "degrees" => collect(degrees),
    "total_grid_points" => SMPL^n,
    "description" => "4D Deuflhard test function - composition of two 2D Deuflhard functions",
    "mathematical_form" => "f(p) = Deuflhard(p[1:2]) + Deuflhard(p[3:4])",
    "deuflhard_2d_form" => "(exp(x² + y²) - 3)² + (x + y - sin(3(x + y)))²",
    "generated_at" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")
)

config_path = joinpath(OUTPUT_DIR, "experiment_config.json")
open(config_path, "w") do io
    JSON3.pretty(io, config)
end
println("✓ Saved: $(basename(config_path))")

# ============================================================================
# Step 4: Save results_summary.json
# ============================================================================

summary = Dict(
    "schema_version" => "2.0.0",
    "function" => "Deuflhard_4d",
    "dimension" => n,
    "total_degrees" => length(degrees),
    "degree_results" => all_degree_results,
    "generated_at" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
    "generator_script" => "Globtim/test/fixtures/generate_postprocessing_fixtures.jl"
)

summary_path = joinpath(OUTPUT_DIR, "results_summary.json")
open(summary_path, "w") do io
    JSON3.pretty(io, summary)
end
println("✓ Saved: $(basename(summary_path))")

# ============================================================================
# Step 5: Generate test_functions.jl
# ============================================================================

test_funcs_content = """\"\"\"
Test Objective Functions for globtimpostprocessing Fixtures

These functions reproduce the objective functions used to generate test fixtures.
They match the data in critical_points_raw_deg_*.csv files.

Generated by: Globtim/test/fixtures/generate_postprocessing_fixtures.jl
Generated at: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
\"\"\"

\"\"\"
    deuflhard_4d_fixture(p::Vector{Float64}) -> Float64

4D Deuflhard test function - composition of two 2D Deuflhard functions.
This matches the Globtim function `Deuflhard_4d`.

# Domain
[-1.2, 1.2]^4

# Mathematical Form
```
f(p) = Deuflhard(p[1:2]) + Deuflhard(p[3:4])

where Deuflhard(x,y) = (exp(x² + y²) - 3)² + (x + y - sin(3(x + y)))²
```

# Properties
- Multiple local minima
- Global minimum at approximately (0, 0, 0, 0)
- Well-conditioned for optimization
- Fast to evaluate (no ODE solving)

# Example
```julia
# Evaluate at origin (near global minimum)
f_val = deuflhard_4d_fixture([0.0, 0.0, 0.0, 0.0])

# Use in refinement test
config = ode_refinement_config()
refined = refine_critical_point(deuflhard_4d_fixture, initial_point, config)
```
\"\"\"
function deuflhard_4d_fixture(p::Vector{Float64})::Float64
    return deuflhard_2d(p[1:2]) + deuflhard_2d(p[3:4])
end

\"\"\"
    deuflhard_2d(xx::AbstractVector) -> Float64

2D Deuflhard function component.

# Mathematical Form
```
f(x, y) = (exp(x² + y²) - 3)² + (x + y - sin(3(x + y)))²
```

# Properties
- Global minimum at approximately (0, 0)
- Multiple local minima in domain [-1.2, 1.2]²
- Smooth and differentiable everywhere
\"\"\"
function deuflhard_2d(xx::AbstractVector)::Float64
    term1 = (exp(xx[1]^2 + xx[2]^2) - 3)^2
    term2 = (xx[1] + xx[2] - sin(3 * (xx[1] + xx[2])))^2
    return term1 + term2
end
"""

funcs_path = joinpath(OUTPUT_DIR, "test_functions.jl")
write(funcs_path, test_funcs_content)
println("✓ Saved: $(basename(funcs_path))")

# ============================================================================
# Summary
# ============================================================================

println()
println("="^80)
println("✅ Fixture Generation Complete!")
println("="^80)
println()
println("Files created in: $OUTPUT_DIR")
println()

# List generated files
for file in ["critical_points_raw_deg_4.csv", "critical_points_raw_deg_6.csv",
             "experiment_config.json", "results_summary.json", "test_functions.jl"]
    filepath = joinpath(OUTPUT_DIR, file)
    if isfile(filepath)
        size_kb = round(stat(filepath).size / 1024, digits=2)
        println("  ✓ $file ($(size_kb) KB)")
    end
end

println()
println("Total critical points:")
for deg_result in all_degree_results
    println("  Degree $(deg_result["degree"]): $(deg_result["critical_points"]) points")
end

println()
println("Next steps:")
println("  1. Update globtimpostprocessing tests to use new CSV format")
println("  2. Include test_functions.jl in relevant test files")
println("  3. Run globtimpostprocessing test suite to validate")
