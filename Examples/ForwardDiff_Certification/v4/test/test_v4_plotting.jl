#!/usr/bin/env julia

# Test V4 plotting functionality

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add path to parent directory for imports
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Run the v4 analysis with plotting enabled
println("\n" * "="^80)
println("🧪 TESTING V4 PLOTTING INTEGRATION")
println("="^80)

# Change to v4 directory to ensure relative paths work
cd(joinpath(@__DIR__, ".."))

# Test with minimal degrees and grid for speed
println("\n📊 Running V4 analysis with plotting...")
include("run_v4_analysis.jl")

# Run with plotting enabled and explicit output directory
output_dir = joinpath(@__DIR__, "../outputs/test_plots_$(Dates.format(Dates.now(), "HH-MM"))")
mkpath(output_dir)

subdomain_tables = run_v4_analysis(
    [3, 4],  # Just two degrees for testing
    10,      # Smaller grid for speed
    output_dir = output_dir,
    plot_results = true
)

# Verify outputs
println("\n✅ Test Results:")
println("   - Generated $(length(subdomain_tables)) subdomain tables")
println("   - Output directory: $output_dir")

# List generated files
if isdir(output_dir)
    files = readdir(output_dir)
    println("\n📁 Generated files:")
    for file in files
        println("   - $file")
    end
else
    println("\n❌ Output directory not created!")
end

println("\n✅ V4 plotting test completed!")