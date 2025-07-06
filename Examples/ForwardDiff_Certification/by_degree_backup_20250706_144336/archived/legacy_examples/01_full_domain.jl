# ================================================================================
# Example A: (+,-,+,-) Orthant Analysis
# ================================================================================
# 
# Analyze the 4D Deuflhard composite function in the (+,-,+,-) orthant:
# Domain: [0,1] × [-1,0] × [0,1] × [-1,0]
# This reduces the problem to 25 critical points (5×5 tensor product).
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
using EnhancedAnalysisUtilities
using EnhancedPlottingUtilities
using PlottingUtilities  # Keep for legacy functions still in use
using TableGeneration
using PlotDescriptions

# Standard packages
using Printf, Dates
using CairoMakie

# ================================================================================
# PARAMETERS
# ================================================================================

const DEGREE_MIN = 2                    # Starting polynomial degree
const DEGREE_MAX = 6                    # Maximum polynomial degree
const L2_TOLERANCE = 1e-2               # Target L²-norm for convergence
const MAX_RUNTIME_PER_DEGREE = 180     # 3 minute timeout per degree

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_orthant_domain_analysis()
    @info "Starting (+,-,+,-) Orthant Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" dimensions=4 domain="[0,1]×[-1,0]×[0,1]×[-1,0]" degree_range="$DEGREE_MIN:$DEGREE_MAX" GN=GN_FIXED
    
    # Load theoretical points for (+,-,+,-) orthant
    @info "Loading theoretical critical points for (+,-,+,-) orthant..."
    theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points_orthant()
    @info "Loaded $(length(theoretical_points)) theoretical points in orthant"
    
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
            [0.5, -0.5, 0.5, -0.5],  # Center of (+,-,+,-) orthant
            0.5,                      # Half-width in each dimension
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
    
    # Create shared output directory with HH-MM timestamp
    output_dir = joinpath(@__DIR__, "../outputs", Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Generate plots
    @info "Generating convergence plots..."
    
    # Convert results to enhanced format
    enhanced_results = EnhancedDegreeAnalysisResult[]
    for result in results
        enhanced = convert_to_enhanced(
            result,
            theoretical_points,
            findall(t -> t == "min+min", theoretical_types),
            "full_orthant"
        )
        push!(enhanced_results, enhanced)
    end
    
    # L²-norm convergence plot with enhanced function
    fig_l2 = plot_l2_convergence_dual_scale(
        enhanced_results,
        title = "L²-Norm Convergence: (+,-,+,-) Orthant",
        tolerance_line = L2_TOLERANCE,
        save_plots = true,
        plots_directory = output_dir
    )
    @info "L²-norm plot saved"
    
    # Generate and display plot description
    l2_desc = describe_l2_convergence(results, tolerance_line = L2_TOLERANCE)
    println("\n" * l2_desc)
    
    # Critical point recovery histogram with enhanced function
    fig_recovery = plot_critical_point_recovery_histogram(
        enhanced_results,
        title = "Critical Point Recovery: (+,-,+,-) Orthant",
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Critical point recovery histogram saved"
    
    # Generate and display plot description
    recovery_desc = describe_recovery_rates(results)
    println("\n" * recovery_desc)
    
    # Min+min distance plot with enhanced function
    fig_min_min = plot_min_min_distances_dual_scale(
        enhanced_results,
        title = "Min+Min Distance to Closest Critical Point: (+,-,+,-) Orthant",
        tolerance_line = 0.001,  # Standard BFGS tolerance
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Min+min distance plot saved"
    
    # Min+min capture methods histogram
    fig_capture = plot_min_min_capture_methods(
        enhanced_results,
        title = "Min+Min Capture Methods: (+,-,+,-) Orthant",
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Min+min capture methods histogram saved"
    
    # Generate and display plot description
    min_min_desc = describe_min_min_distances(results)
    println("\n" * min_min_desc)
    
    # Generate summary table
    @info "\nSummary Statistics:"
    generate_degree_summary_table(results, title="(+,-,+,-) Orthant Analysis Summary")
    
    # Export to CSV
    csv_path = joinpath(output_dir, "orthant_results.csv")
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
    
    @info "Orthant domain analysis complete!" output_directory=output_dir
    
    return results, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    results, output_dir = run_orthant_domain_analysis()
end