# ================================================================================
# Example B: Subdivided Fixed Degree Analysis
# ================================================================================
# 
# Apply the same polynomial degree to all 16 spatial subdomains of [-1,1]^4.
# This example reveals which regions of the domain are harder to approximate
# and helps identify spatial patterns in approximation difficulty.
#
# Expected outputs:
# - Combined L²-norm plot for all 16 subdomains
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
using PlottingUtilities
using TableGeneration

# Standard packages
using Printf, Dates, Statistics
using CairoMakie
using DataFrames, CSV

# ================================================================================
# PARAMETERS
# ================================================================================

const FIXED_DEGREES = [2, 3, 4]         # Degrees to test across all subdomains (capped at 4 for fast testing)
const MAX_RUNTIME_PER_SUBDOMAIN = 60   # 1 minute timeout per subdomain
const L2_TOLERANCE_REFERENCE = 1e-2    # Reference line for plots

# ================================================================================
# SUBDOMAIN ANALYSIS
# ================================================================================

function analyze_subdomain_at_degree(subdomain::Subdomain, degree::Int)
    """Analyze a single subdomain at a fixed degree."""
    
    # Load theoretical points for this subdomain
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain(subdomain)
    
    if isempty(theoretical_points)
        @warn "No theoretical points in subdomain $(subdomain.label), skipping"
        return nothing
    end
    
    @info "Analyzing subdomain $(subdomain.label)" degree=degree n_theoretical=length(theoretical_points)
    
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
    @info "Starting Fixed Degree Subdivision Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" fixed_degrees=FIXED_DEGREES GN=GN_FIXED
    
    # Generate 16 subdomains
    subdivisions = generate_16_subdivisions()
    @info "Generated $(length(subdivisions)) subdomains"
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "subdivided_fixed_$(Dates.format(now(), "yyyy-mm-dd_HH-MM"))")
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
        
        # Generate plots for this degree
        if !isempty(degree_results)
            # Convert to format expected by plotting function
            results_vector = Dict(label => [result] for (label, result) in degree_results)
            
            fig = plot_subdivision_convergence(
                results_vector,
                title = "L²-Norm Distribution: Degree $degree",
                tolerance_line = L2_TOLERANCE_REFERENCE,
                save_path = joinpath(output_dir, "l2_distribution_degree_$(degree).png")
            )
            @info "Saved L²-norm distribution plot for degree $degree"
        end
    end
    
    # Comparative analysis across degrees
    @info "\nGenerating comparative analysis..."
    
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
            generate_subdivision_summary_table(results_for_table, title="Degree $degree Subdivision Analysis")
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
        csv_path = joinpath(output_dir, "fixed_degree_results.csv")
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
    
    @info "Fixed degree subdivision analysis complete!" output_directory=output_dir
    
    return all_results, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    all_results, output_dir = run_fixed_degree_subdivision_analysis()
end