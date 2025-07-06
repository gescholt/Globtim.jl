# ================================================================================
# Example B: Subdivided Fixed Degree Analysis - ALL SUBDOMAINS
# ================================================================================
# 
# Modified version that analyzes ALL 16 subdomains, not just those with theoretical points.
# This will generate L²-norm data for every subdomain to show convergence behavior.
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
using TableGeneration

# Standard packages
using Printf, Dates, Statistics
using CairoMakie
using DataFrames, CSV
using Globtim, DynamicPolynomials

# ================================================================================
# PARAMETERS
# ================================================================================

const FIXED_DEGREES = [2, 3, 4, 5, 6]  # Test degrees up to 6
const MAX_RUNTIME_PER_SUBDOMAIN = 60   # 1 minute timeout per subdomain
const L2_TOLERANCE_REFERENCE = 1e-2    # Reference line for plots

# ================================================================================
# MODIFIED SUBDOMAIN ANALYSIS - Runs on ALL subdomains
# ================================================================================

function analyze_subdomain_at_degree_all(subdomain::Subdomain, degree::Int)
    """Analyze a single subdomain at a fixed degree - works for ALL subdomains."""
    
    @info "Analyzing subdomain $(subdomain.label)" degree=degree center=subdomain.center
    
    # Create polynomial approximation WITHOUT requiring theoretical points
    f = deuflhard_4d_composite
    
    # Create test input
    TR = test_input(f, dim=4, center=subdomain.center, sample_range=subdomain.range, tolerance=L2_TOLERANCE_REFERENCE)
    
    # Construct polynomial
    pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
    
    # Get L2 norm
    l2_norm = pol.nrm
    
    # Find critical points
    @polyvar x[1:4]
    crit_pts = solve_polynomial_system(x, 4, pol.degree, pol.coeffs)
    
    # For subdomains with theoretical points, check recovery
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    if !isempty(theoretical_points)
        # Calculate success rates
        success_rate = length(crit_pts) > 0 ? count_matched_points(crit_pts, theoretical_points) / length(theoretical_points) : 0.0
        min_min_indices = findall(t -> t == "min+min", theoretical_types)
        min_min_success = length(min_min_indices) > 0 ? 
            count_matched_points(crit_pts, theoretical_points[min_min_indices]) / length(min_min_indices) : 0.0
    else
        # No theoretical points - set rates to NaN or -1 to indicate no validation possible
        success_rate = -1.0
        min_min_success = -1.0
    end
    
    # Create result
    result = DegreeAnalysisResult(
        degree,                              # degree
        l2_norm,                             # l2_norm
        length(theoretical_points),          # n_theoretical_points
        length(crit_pts),                    # n_computed_points
        0,                                   # n_successful_recoveries (would need to compute)
        success_rate,                        # success_rate
        0.0,                                 # runtime_seconds
        l2_norm < L2_TOLERANCE_REFERENCE,    # converged
        crit_pts,                            # computed_points
        min_min_success,                     # min_min_success_rate
        Float64[]                            # min_min_distances (would need to compute)
    )
    
    return result
end

function count_matched_points(computed::Vector{Vector{Float64}}, theoretical::Vector{Vector{Float64}}; tol=0.01)
    """Count how many theoretical points are matched by computed points."""
    matched = 0
    for th_pt in theoretical
        for comp_pt in computed
            if norm(comp_pt - th_pt) < tol
                matched += 1
                break
            end
        end
    end
    return matched
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_fixed_degree_subdivision_analysis_all()
    @info "Starting Fixed Degree Subdivision Analysis - ALL SUBDOMAINS" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" domain="[0,1]×[-1,0]×[0,1]×[-1,0]" fixed_degrees=FIXED_DEGREES
    
    # Generate 16 subdomains within the (+,-,+,-) orthant
    subdivisions = generate_16_subdivisions_orthant()
    @info "Generated $(length(subdivisions)) subdomains in (+,-,+,-) orthant"
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "all_domains_" * Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Analyze each degree
    all_results = Dict{Int, Dict{String, DegreeAnalysisResult}}()
    
    for degree in FIXED_DEGREES
        @info "\nAnalyzing degree $degree across ALL subdomains..."
        degree_start_time = time()
        
        degree_results = Dict{String, DegreeAnalysisResult}()
        
        for subdomain in subdivisions
            # Run analysis on EVERY subdomain
            result = analyze_subdomain_at_degree_all(subdomain, degree)
            
            if result !== nothing
                degree_results[subdomain.label] = result
                @info "Subdomain $(subdomain.label) complete" L2_norm=@sprintf("%.2e", result.l2_norm)
            end
        end
        
        all_results[degree] = degree_results
        
        degree_runtime = time() - degree_start_time
        @info "Degree $degree analysis complete" n_subdomains=length(degree_results) runtime=@sprintf("%.1f", degree_runtime)
    end
    
    # Create combined results for plotting
    @info "\nPreparing data for plotting..."
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
    
    @info "Data preparation complete" n_subdomains=length(combined_results)
    
    # Generate the combined plots
    if !isempty(enhanced_combined_results)
        # L²-norm convergence plot - should now show 16 curves!
        fig = plot_l2_convergence_dual_scale(
            enhanced_combined_results,
            title = "L²-Norm Convergence: ALL 16 Subdomains",
            tolerance_line = L2_TOLERANCE_REFERENCE,
            save_plots = true,
            plots_directory = output_dir
        )
        @info "Saved L²-norm convergence plot with $(length(enhanced_combined_results)) curves"
    end
    
    # Export results to CSV
    csv_rows = []
    for (degree, degree_results) in all_results
        for (label, result) in degree_results
            push!(csv_rows, (
                degree = degree,
                subdomain = label,
                l2_norm = result.l2_norm,
                n_computed_points = result.n_computed_points,
                n_theoretical_points = result.n_theoretical_points,
                has_theoretical = result.n_theoretical_points > 0,
                converged = result.converged
            ))
        end
    end
    
    if !isempty(csv_rows)
        df = DataFrame(csv_rows)
        csv_path = joinpath(output_dir, "all_subdomains_results.csv")
        CSV.write(csv_path, df)
        @info "Results exported to CSV" path=csv_path n_rows=nrow(df)
        
        # Show summary
        println("\nSubdomain Summary:")
        for label in sort(unique(df.subdomain))
            subdomain_data = filter(row -> row.subdomain == label, df)
            has_theoretical = first(subdomain_data).has_theoretical
            l2_values = subdomain_data.l2_norm
            println("  $label: L² range [$(minimum(l2_values)), $(maximum(l2_values))], theoretical points: $has_theoretical")
        end
    end
    
    @info "\nAnalysis complete!" output_directory=output_dir
    
    return all_results, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    all_results, output_dir = run_fixed_degree_subdivision_analysis_all()
end