# ================================================================================
# Example A: Full Domain Analysis
# ================================================================================
# 
# Analyze polynomial approximation on the entire [-1,1]^4 domain with degree sweep.
# This example demonstrates L²-norm convergence and critical point recovery rates
# as polynomial degree increases from 2 to 12.
#
# Expected outputs:
# - L²-norm convergence plot
# - Critical point recovery rates plot
# - Summary statistics table
# - CSV export of all results
#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

# Load shared utilities
using Common4DDeuflhard
using TheoreticalPoints
using AnalysisUtilities
using PlottingUtilities
using TableGeneration

# Standard packages
using Printf, Dates
using CairoMakie

# ================================================================================
# PARAMETERS
# ================================================================================

const DEGREE_MIN = 2                    # Starting polynomial degree
const DEGREE_MAX = 4                    # Maximum polynomial degree (capped at 4 for fast testing)
const L2_TOLERANCE = 1e-3               # Target L²-norm for convergence
const MAX_RUNTIME_PER_DEGREE = 180     # 3 minute timeout per degree

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_full_domain_analysis()
    @info "Starting Full Domain Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" degree_range="$DEGREE_MIN:$DEGREE_MAX" L2_tolerance=L2_TOLERANCE GN=GN_FIXED
    
    # Load theoretical points for validation
    @info "Loading theoretical critical points..."
    theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points()
    @info "Loaded $(length(theoretical_points)) theoretical points"
    
    # Count point types
    n_min_min = count(t -> t == "min+min", theoretical_types)
    @info "Point type distribution" total=length(theoretical_points) min_min=n_min_min
    
    # Initialize results storage
    results = DegreeAnalysisResult[]
    analysis_start_time = time()
    
    # Degree sweep
    @info "Beginning degree sweep analysis..."
    for degree in DEGREE_MIN:DEGREE_MAX
        @info "Analyzing degree $degree..."
        
        # Check if we should stop early
        if !isempty(results) && results[end].converged
            @info "Convergence achieved at previous degree, continuing to verify stability..."
        end
        
        # Run analysis for this degree
        result = analyze_single_degree(
            deuflhard_4d_composite, 
            degree,
            [0.0, 0.0, 0.0, 0.0],  # Center at origin
            ORIGINAL_DOMAIN_RANGE,   # Full [-1,1]^4 domain
            theoretical_points,
            theoretical_types,
            gn = GN_FIXED,
            tolerance_target = L2_TOLERANCE
        )
        
        push!(results, result)
        
        # Progress report
        @info "Degree $degree complete" L2_norm=@sprintf("%.2e", result.l2_norm) n_found=result.n_computed_points success_rate=@sprintf("%.1f%%", result.success_rate*100) runtime=@sprintf("%.1f", result.runtime_seconds)
        
        # Check timeout
        if result.runtime_seconds > MAX_RUNTIME_PER_DEGREE
            @warn "Degree $degree exceeded maximum runtime, stopping analysis" max_runtime=MAX_RUNTIME_PER_DEGREE
            break
        end
    end
    
    total_runtime = time() - analysis_start_time
    @info "Degree sweep complete" degrees_tested=length(results) total_runtime=@sprintf("%.1f", total_runtime)
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "full_domain_$(Dates.format(now(), "yyyy-mm-dd_HH-MM"))")
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Generate plots
    @info "Generating convergence plots..."
    
    # L²-norm convergence plot
    fig_l2 = plot_l2_convergence(
        results,
        title = "Full Domain L²-Norm Convergence",
        tolerance_line = L2_TOLERANCE,
        save_path = joinpath(output_dir, "l2_convergence.png")
    )
    @info "L²-norm plot saved"
    
    # Recovery rates plot
    fig_recovery = plot_recovery_rates(
        results,
        title = "Critical Point Recovery Rates",
        save_path = joinpath(output_dir, "recovery_rates.png")
    )
    @info "Recovery rates plot saved"
    
    # Generate summary table
    @info "\nSummary Statistics:"
    generate_degree_summary_table(results, title="Full Domain Degree Analysis")
    
    # Export to CSV
    csv_path = joinpath(output_dir, "full_domain_results.csv")
    export_results_to_csv(results, csv_path)
    
    # Final analysis
    @info "\nAnalysis Insights:"
    
    # Find convergence degree
    converged_degrees = [r.degree for r in results if r.converged]
    if !isempty(converged_degrees)
        @info "L²-norm convergence achieved" first_degree=minimum(converged_degrees) target=L2_TOLERANCE
    else
        @warn "L²-norm convergence not achieved" best_l2=@sprintf("%.2e", minimum([r.l2_norm for r in results])) target=L2_TOLERANCE
    end
    
    # Find best recovery degree
    best_recovery_idx = argmax([r.success_rate for r in results])
    best_recovery = results[best_recovery_idx]
    @info "Best critical point recovery" degree=best_recovery.degree success_rate=@sprintf("%.1f%%", best_recovery.success_rate*100)
    
    # Min+min performance
    best_minmin_idx = argmax([r.min_min_success_rate for r in results])
    best_minmin = results[best_minmin_idx]
    @info "Best min+min recovery" degree=best_minmin.degree min_min_rate=@sprintf("%.1f%%", best_minmin.min_min_success_rate*100)
    
    @info "Full domain analysis complete!" output_directory=output_dir
    
    return results, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    results, output_dir = run_full_domain_analysis()
end