#!/usr/bin/env julia

# Generate publication-ready function value error tables
# Run this from the v4 directory

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames
using CSV
using Printf
using Dates

println("\n" * "="^80)
println("📊 GENERATING PUBLICATION TABLES FOR FUNCTION VALUE ERRORS")
println("="^80)

# Parse command line arguments
degrees = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ",")) : [3, 4, 5, 6, 7, 8]
GN = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20

println("\nParameters:")
println("  Degrees: $degrees")
println("  GN: $GN")

# Load required modules
println("\n📚 Loading modules...")

# Core modules
include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

include("scripts/core/run_analysis_with_refinement.jl")
using .Main: run_enhanced_analysis_with_refinement

include("src/PublicationTablesSimple.jl")
using .PublicationTablesSimple

println("✅ Modules loaded")

# Step 1: Load theoretical points
println("\n📊 Loading theoretical points...")
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
println("   Loaded $(length(theoretical_points)) theoretical points")
println("   - Minima: $(count(t -> t == "min", theoretical_types))")
println("   - Saddle points: $(count(t -> t == "saddle", theoretical_types))")

# Step 2: Run analysis to get computed points (with quiet mode)
println("\n📊 Running analysis to get computed critical points...")
println("   (Suppressing verbose output)")

# Redirect stdout temporarily to suppress output
original_stdout = stdout
io = IOBuffer()
redirect_stdout(io)

try
    global analysis_results = run_enhanced_analysis_with_refinement(
        degrees, GN,
        analyze_global=false,
        threshold=0.1,
        tol_dist=0.05
    )
finally
    redirect_stdout(original_stdout)
end

all_critical_points_with_labels = analysis_results.all_critical_points

println("✅ Analysis complete")

# Step 3: Generate publication tables
println("\n📊 Generating publication tables...")

min_table, saddle_table = generate_function_value_error_tables_simple(
    all_critical_points_with_labels,
    theoretical_points,
    theoretical_types,
    degrees,
    deuflhard_4d_composite
)

# Step 4: Display tables
print_publication_tables_simple(min_table, saddle_table)

# Step 5: Save tables as CSV
timestamp = Dates.format(Dates.now(), "HH-MM")
output_dir = "outputs/tables_$timestamp"
mkpath(output_dir)

CSV.write(joinpath(output_dir, "minima_errors.csv"), min_table)
CSV.write(joinpath(output_dir, "saddle_errors.csv"), saddle_table)

println("\n📁 Tables saved to: $output_dir")

# Step 6: Create LaTeX versions (optional)
println("\n📝 Creating LaTeX versions...")

function to_latex(df::DataFrame, caption::String)
    io = IOBuffer()
    println(io, "\\begin{table}[h]")
    println(io, "\\centering")
    println(io, "\\caption{$caption}")
    println(io, "\\begin{tabular}{l" * repeat("r", ncol(df)-1) * "}")
    println(io, "\\hline")
    
    # Header
    header = join(names(df), " & ")
    header = replace(header, "Point_ID" => "Point ID")
    header = replace(header, r"Degree_(\d+)" => s"Degree \1")
    println(io, header, " \\\\")
    println(io, "\\hline")
    
    # Data rows
    for i in 1:nrow(df)-3
        row = join([df[i, col] for col in names(df)], " & ")
        println(io, row, " \\\\")
    end
    
    # Summary rows
    println(io, "\\hline")
    for i in nrow(df)-1:nrow(df)
        row = join([df[i, col] for col in names(df)], " & ")
        println(io, row, " \\\\")
    end
    
    println(io, "\\hline")
    println(io, "\\end{tabular}")
    println(io, "\\end{table}")
    
    return String(take!(io))
end

# Save LaTeX versions
open(joinpath(output_dir, "minima_errors.tex"), "w") do f
    write(f, to_latex(min_table, "Relative errors in function values for local minima"))
end

open(joinpath(output_dir, "saddle_errors.tex"), "w") do f
    write(f, to_latex(saddle_table, "Relative errors in function values for saddle points"))
end

println("✅ LaTeX tables saved")

println("\n✅ All done!")