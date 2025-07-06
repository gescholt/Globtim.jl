# ================================================================================
# Example B: Subdivided Fixed Degree Analysis (+,-,+,-) Orthant
# ================================================================================
# 
# Apply the same polynomial degree to all 16 spatial subdomains of the (+,-,+,-) orthant.
# Domain: [0,1] × [-1,0] × [0,1] × [-1,0] divided into 16 subdomains.
# This example reveals which regions of the orthant are harder to approximate.
#
# Expected outputs:
# - Combined L²-norm plot for all 16 subdomains
# - Recovery rate plots (all critical points and min+min only)
# - Spatial difficulty analysis
# - Summary table by subdomain
# - CSV export with detailed results
#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

# Load shared utilities
using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints
using AnalysisUtilities
using EnhancedAnalysisUtilities
using EnhancedPlottingUtilities
using PlottingUtilities  # Keep for legacy functions
using TableGeneration
using PlotDescriptions

# Standard packages
using Printf, Dates, Statistics
using CairoMakie
using DataFrames, CSV

# ================================================================================
# PARAMETERS
# ================================================================================

const FIXED_DEGREES = [2, 3, 4, 5, 6]  # Test degrees up to 6
const MAX_RUNTIME_PER_SUBDOMAIN = 60   # 1 minute timeout per subdomain
const L2_TOLERANCE_REFERENCE = 1e-2    # Reference line for plots

# ================================================================================
# SUBDOMAIN ANALYSIS
# ================================================================================

function analyze_subdomain_at_degree(subdomain::Subdomain, degree::Int)
    """Analyze a single subdomain at a fixed degree."""
    
    # Load theoretical points for this subdomain within the orthant
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    # Note: We analyze ALL subdomains, even those without theoretical points
    # This gives us L²-norm convergence data for the entire orthant
    if isempty(theoretical_points)
        @info "No theoretical points in subdomain $(subdomain.label), analyzing anyway" degree=degree
        # Create empty arrays for analysis
        theoretical_points = Vector{Vector{Float64}}()
        theoretical_types = String[]
    else
        @info "Analyzing subdomain $(subdomain.label)" degree=degree n_theoretical=length(theoretical_points)
    end
    
    # Run analysis
    result = analyze_single_degree(
        deuflhard_4d_composite,
        degree,
        subdomain.center,
        subdomain.range,
        theoretical_points,
        theoretical_types,
        gn = GN_FIXED,
        tolerance_target = L2_TOLERANCE_REFERENCE
    )
    
    return result
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_fixed_degree_subdivision_analysis()
    @info "Starting Fixed Degree Subdivision Analysis (+,-,+,-) Orthant" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" domain="[0,1]×[-1,0]×[0,1]×[-1,0]" fixed_degrees=FIXED_DEGREES GN=GN_FIXED
    
    # Generate 16 subdomains within the (+,-,+,-) orthant
    subdivisions = generate_16_subdivisions_orthant()
    @info "Generated $(length(subdivisions)) subdomains in (+,-,+,-) orthant"
    
    # Create shared output directory with HH-MM timestamp
    output_dir = joinpath(@__DIR__, "../outputs", Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Analyze each degree
    all_results = Dict{Int, Dict{String, DegreeAnalysisResult}}()
    
    for degree in FIXED_DEGREES
        @info "\nAnalyzing degree $degree across all subdomains..."
        degree_start_time = time()
        
        degree_results = Dict{String, DegreeAnalysisResult}()
        
        for subdomain in subdivisions
            # Run analysis with timeout protection
            subdomain_start_time = time()
            
            result = analyze_subdomain_at_degree(subdomain, degree)
            
            if result !== nothing
                degree_results[subdomain.label] = result
                
                # Progress report
                @info "Subdomain $(subdomain.label) complete" L2_norm=@sprintf("%.2e", result.l2_norm) success_rate=@sprintf("%.1f%%", result.success_rate*100)
                
                # Check timeout
                if result.runtime_seconds > MAX_RUNTIME_PER_SUBDOMAIN
                    @warn "Subdomain $(subdomain.label) exceeded timeout" runtime=result.runtime_seconds
                end
            end
        end
        
        all_results[degree] = degree_results
        
        degree_runtime = time() - degree_start_time
        @info "Degree $degree analysis complete" n_subdomains=length(degree_results) runtime=@sprintf("%.1f", degree_runtime)
        
        # Store results for combined plotting later
        @info "Stored results for degree $degree"
    end
    
    # Comparative analysis across degrees
    @info "\nGenerating comparative analysis..."
    
    # Create combined plot showing all degrees together
    combined_results = Dict{String, Vector{DegreeAnalysisResult}}()
    enhanced_combined_results = Dict{String, Vector{EnhancedDegreeAnalysisResult}}()
    
    for (degree, degree_results) in all_results
        for (label, result) in degree_results
            if !haskey(combined_results, label)
                combined_results[label] = DegreeAnalysisResult[]
                enhanced_combined_results[label] = EnhancedDegreeAnalysisResult[]
            end
            push!(combined_results[label], result)
            
            # Convert to enhanced format
            subdomain = subdivisions[findfirst(s -> s.label == label, subdivisions)]
            theoretical_points, theoretical_values, theoretical_types = 
                load_theoretical_points_for_subdomain_orthant(subdomain)
            
            enhanced = convert_to_enhanced(
                result,
                theoretical_points,
                findall(t -> t == "min+min", theoretical_types),
                label
            )
            push!(enhanced_combined_results[label], enhanced)
        end
    end
    
    # Generate the combined plots
    if !isempty(enhanced_combined_results)
        # L²-norm convergence plot with dual scale
        fig = plot_l2_convergence_dual_scale(
            enhanced_combined_results,
            title = "L²-Norm Convergence: (+,-,+,-) Orthant Subdivisions",
            tolerance_line = L2_TOLERANCE_REFERENCE,
            save_plots = true,
            plots_directory = output_dir
        )
        @info "Saved combined L²-norm convergence plot"
        
        # Generate and display plot description
        l2_desc = describe_subdivision_convergence(combined_results, tolerance_line = L2_TOLERANCE_REFERENCE)
        println("\n" * l2_desc)
        
        # Critical point recovery histogram
        fig_recovery = plot_critical_point_recovery_histogram(
            enhanced_combined_results,
            title = "Critical Point Recovery: (+,-,+,-) Orthant Subdivisions",
            save_plots = true,
            plots_directory = output_dir
        )
        @info "Saved critical point recovery histogram"
        
        # Generate and display plot description
        recovery_desc = describe_subdivision_recovery_rates(combined_results)
        println("\n" * recovery_desc)
        
        # Min+min distance plot with dual scale
        fig_min_min = plot_min_min_distances_dual_scale(
            enhanced_combined_results,
            title = "Min+Min Distance: Fixed Degree Subdivisions",
            tolerance_line = 0.001,
            save_plots = true,
            plots_directory = output_dir
        )
        @info "Saved min+min distance plots"
        
        # Min+min capture methods histogram
        fig_capture = plot_min_min_capture_methods(
            enhanced_combined_results,
            title = "Min+Min Capture Methods: Fixed Degree Subdivisions",
            save_plots = true,
            plots_directory = output_dir
        )
        @info "Saved min+min capture methods histogram"
        
        # Generate and display plot description
        min_min_desc = describe_subdivision_min_min_distances(combined_results)
        println("\n" * min_min_desc)
    end
    
    # Collect statistics for each degree
    for degree in FIXED_DEGREES
        if haskey(all_results, degree)
            degree_results = all_results[degree]
            if !isempty(degree_results)
                l2_norms = [r.l2_norm for r in values(degree_results) if isfinite(r.l2_norm)]
                
                if !isempty(l2_norms)
                    @info "Degree $degree statistics" 
                    @info "  L²-norm range" min=@sprintf("%.2e", minimum(l2_norms)) max=@sprintf("%.2e", maximum(l2_norms)) median=@sprintf("%.2e", median(l2_norms))
                    
                    # Find easiest and hardest subdomains
                    sorted_by_l2 = sort(collect(degree_results), by=x->x[2].l2_norm)
                    easiest = first(sorted_by_l2)
                    hardest = last(sorted_by_l2)
                    
                    @info "  Easiest subdomain" label=easiest[1] l2_norm=@sprintf("%.2e", easiest[2].l2_norm)
                    @info "  Hardest subdomain" label=hardest[1] l2_norm=@sprintf("%.2e", hardest[2].l2_norm)
                end
            end
        end
    end
    
    # Generate summary tables for each degree
    for degree in FIXED_DEGREES
        if haskey(all_results, degree)
            @info "\nSummary for degree $degree:"
            # Convert to expected format
            results_for_table = Dict(label => [result] for (label, result) in all_results[degree])
            generate_subdivision_summary_table(results_for_table, title="Degree $degree Orthant Subdivision Analysis")
        end
    end
    
    # Export all results to CSV
    csv_rows = []
    for (degree, degree_results) in all_results
        for (label, result) in degree_results
            push!(csv_rows, (
                degree = degree,
                subdomain = label,
                l2_norm = result.l2_norm,
                n_computed_points = result.n_computed_points,
                n_theoretical_points = result.n_theoretical_points,
                success_rate = result.success_rate,
                min_min_success_rate = result.min_min_success_rate,
                runtime_seconds = result.runtime_seconds,
                converged = result.converged
            ))
        end
    end
    
    if !isempty(csv_rows)
        df = DataFrame(csv_rows)
        csv_path = joinpath(output_dir, "fixed_subdivision_results.csv")
        CSV.write(csv_path, df)
        @info "Results exported to CSV" path=csv_path n_rows=nrow(df)
    end
    
    # Spatial difficulty analysis
    @info "\nSpatial Difficulty Patterns:"
    
    # Analyze which bit positions correlate with difficulty
    for degree in FIXED_DEGREES
        if haskey(all_results, degree)
            degree_results = all_results[degree]
            
            # Group by number of positive dimensions
            groups = Dict{Int, Vector{Tuple{String, Float64}}}()
            for (label, result) in degree_results
                n_positive = count(c -> c == '1', label)
                if !haskey(groups, n_positive)
                    groups[n_positive] = []
                end
                push!(groups[n_positive], (label, result.l2_norm))
            end
            
            @info "Degree $degree - L²-norm by positive dimensions:"
            for n_pos in sort(collect(keys(groups)))
                l2_values = [l2 for (_, l2) in groups[n_pos] if isfinite(l2)]
                if !isempty(l2_values)
                    @info "  $n_pos positive dims" mean_l2=@sprintf("%.2e", mean(l2_values)) n_subdomains=length(l2_values)
                end
            end
        end
    end
    
    @info "Fixed degree orthant subdivision analysis complete!" output_directory=output_dir
    
    return all_results, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    all_results, output_dir = run_fixed_degree_subdivision_analysis()
end