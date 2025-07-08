#!/usr/bin/env julia

# Wrapper function for interactive use of V4 analysis
# This provides a convenient function interface to run_v4_analysis.jl

"""
    run_v4_analysis(; degrees=[3,4], GN=20, output_dir=nothing)

Run enhanced V4 analysis with BFGS refinement using a function interface.

# Keyword Arguments
- `degrees`: Vector of polynomial degrees (default: [3,4])
- `GN`: Grid resolution (default: 20)
- `output_dir`: Output directory (auto-generated with timestamp if nothing)

# Returns
Named tuple with:
- `subdomain_tables`: V4 tables for each subdomain
- `refinement_metrics`: BFGS refinement effectiveness metrics
- `all_min_refined_points`: Refined points by degree
- `function_value_error_summary`: Summary table of function value errors

# Examples
```julia
# First, include this wrapper
include("run_v4_analysis_wrapper.jl")

# Default run
results = run_v4_analysis()

# Higher degrees with custom grid
results = run_v4_analysis(degrees=[3,4,5,6], GN=30)

# Custom output directory
results = run_v4_analysis(degrees=[3,4,5], GN=25, output_dir="outputs/my_analysis")

# Access results
results.subdomain_tables["0000"]  # View specific subdomain
results.refinement_metrics        # View refinement effectiveness
```
"""
function run_v4_analysis(; degrees=[3,4], GN=20, output_dir=nothing)
    # Save original ARGS
    original_args = copy(ARGS)
    
    try
        # Clear and set ARGS for the script
        empty!(ARGS)
        
        # Add degrees argument
        push!(ARGS, join(degrees, ","))
        
        # Add GN argument
        push!(ARGS, string(GN))
        
        # Add output directory if specified
        if output_dir !== nothing
            push!(ARGS, output_dir)
        end
        
        # Include and run the main script
        result = include(joinpath(@__DIR__, "run_v4_analysis.jl"))
        
        return result
        
    finally
        # Restore original ARGS
        empty!(ARGS)
        append!(ARGS, original_args)
    end
end

# Also provide the old function name for compatibility
const run_v4_enhanced = run_v4_analysis

# Print usage information when loaded
println("\n✅ V4 Analysis Wrapper Loaded!")
println("\nUsage:")
println("  results = run_v4_analysis()                    # Default: degrees [3,4], GN=20")
println("  results = run_v4_analysis(degrees=[3,4,5,6])   # Custom degrees")
println("  results = run_v4_analysis(degrees=[3,4,5], GN=30)  # Custom degrees and grid")
println("  results = run_v4_enhanced(...)                 # Alias for compatibility")
println("\nThe function returns:")
println("  - results.subdomain_tables   # V4 tables by subdomain")
println("  - results.refinement_metrics # BFGS refinement summary")
println("  - results.all_min_refined_points # Refined points by degree")
println("  - results.function_value_error_summary # Function value error summary table")