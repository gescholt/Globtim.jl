# ================================================================================
# Example C: Subdivided Adaptive Degree Analysis (+,-,+,-) Orthant
# ================================================================================
# 
# Adaptively increase polynomial degree for each subdomain of the (+,-,+,-) orthant
# until L²-norm tolerance is achieved. Domain: [0,1] × [-1,0] × [0,1] × [-1,0].
# This example identifies which regions need higher degree approximations.
#
# Expected outputs:
# - Degree requirements map (which subdomain needs what degree)
# - Computational cost analysis
# - Convergence progression visualization
# - Recovery rate plots
# - CSV export with adaptive history
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

const DEGREE_MIN = 2                    # Starting polynomial degree
const DEGREE_MAX = 6                    # Maximum polynomial degree
const L2_TOLERANCE_TARGET = 1e-2       # L²-norm convergence target
const MAX_RUNTIME_PER_SUBDOMAIN = 300  # 5 minute timeout per subdomain
const MAX_RUNTIME_PER_DEGREE = 60      # 1 minute timeout per degree

# ================================================================================
# ADAPTIVE ANALYSIS
# ================================================================================

function analyze_subdomain_adaptive(subdomain::Subdomain)
    """Adaptively increase degree until L²-norm tolerance is met."""
    
    # Load theoretical points for this subdomain within the orthant
    theoretical_points, theoretical_values, theoretical_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    if isempty(theoretical_points)
        @warn "No theoretical points in subdomain $(subdomain.label), skipping"
        return DegreeAnalysisResult[]
    end
    
    @info "Starting adaptive analysis for subdomain $(subdomain.label)" n_theoretical=length(theoretical_points) target_l2=L2_TOLERANCE_TARGET
    
    results = DegreeAnalysisResult[]
    subdomain_start_time = time()
    
    for degree in DEGREE_MIN:DEGREE_MAX
        # Check subdomain timeout
        if time() - subdomain_start_time > MAX_RUNTIME_PER_SUBDOMAIN
            @warn "Subdomain $(subdomain.label) exceeded maximum runtime" runtime=time()-subdomain_start_time
            break
        end
        
        @info "Testing degree $degree for subdomain $(subdomain.label)..."
        
        # Run analysis
        result = analyze_single_degree(
            deuflhard_4d_composite,
            degree,
            subdomain.center,
            subdomain.range,
            theoretical_points,
            theoretical_types,
            gn = GN_FIXED,
            tolerance_target = L2_TOLERANCE_TARGET
        )
        
        push!(results, result)
        
        # Progress report
        status = result.converged ? "CONVERGED" : "not converged"
        @info "Degree $degree complete" L2_norm=@sprintf("%.2e", result.l2_norm) status=status runtime=@sprintf("%.1f", result.runtime_seconds)
        
        # Check for convergence
        if result.converged
            @info "Subdomain $(subdomain.label) achieved target!" degree=degree l2_norm=@sprintf("%.2e", result.l2_norm)
            break
        end
        
        # Check degree timeout
        if result.runtime_seconds > MAX_RUNTIME_PER_DEGREE
            @warn "Degree $degree exceeded runtime limit" runtime=result.runtime_seconds
            break
        end
    end
    
    total_runtime = time() - subdomain_start_time
    final_l2 = isempty(results) ? Inf : minimum([r.l2_norm for r in results])
    converged = any([r.converged for r in results])
    
    @info "Subdomain $(subdomain.label) complete" degrees_tested=length(results) converged=converged final_l2=@sprintf("%.2e", final_l2) total_runtime=@sprintf("%.1f", total_runtime)
    
    return results
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_adaptive_subdivision_analysis()
    @info "Starting Adaptive Subdivision Analysis (+,-,+,-) Orthant" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" domain="[0,1]×[-1,0]×[0,1]×[-1,0]" degree_range="$DEGREE_MIN:$DEGREE_MAX" L2_target=L2_TOLERANCE_TARGET GN=GN_FIXED
    
    # Generate 16 subdomains within the (+,-,+,-) orthant
    subdivisions = generate_16_subdivisions_orthant()
    @info "Generated $(length(subdivisions)) subdomains in (+,-,+,-) orthant"
    
    # Create shared output directory with HH-MM timestamp
    output_dir = joinpath(@__DIR__, "../outputs", Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Analyze each subdomain adaptively
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    analysis_start_time = time()
    
    for (i, subdomain) in enumerate(subdivisions)
        @info "\nProcessing subdomain $i/$(length(subdivisions)): $(subdomain.label)"
        
        results = analyze_subdomain_adaptive(subdomain)
        all_results[subdomain.label] = results
    end
    
    total_runtime = time() - analysis_start_time
    @info "\nAdaptive analysis complete" total_runtime=@sprintf("%.1f", total_runtime)
    
    # Convert results to enhanced format
    enhanced_all_results = Dict{String, Vector{EnhancedDegreeAnalysisResult}}()
    
    for (label, results) in all_results
        enhanced_results = EnhancedDegreeAnalysisResult[]
        subdomain = subdivisions[findfirst(s -> s.label == label, subdivisions)]
        
        theoretical_points, theoretical_values, theoretical_types = 
            load_theoretical_points_for_subdomain_orthant(subdomain)
        
        for result in results
            enhanced = convert_to_enhanced(
                result,
                theoretical_points,
                findall(t -> t == "min+min", theoretical_types),
                label
            )
            push!(enhanced_results, enhanced)
        end
        
        enhanced_all_results[label] = enhanced_results
    end
    
    # Generate convergence progression plot
    @info "Generating convergence progression plot..."
    fig = plot_l2_convergence_dual_scale(
        enhanced_all_results,
        title = "Adaptive L²-Norm Convergence: (+,-,+,-) Orthant",
        tolerance_line = L2_TOLERANCE_TARGET,
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Convergence plot saved"
    
    # Generate and display plot description
    l2_desc = describe_subdivision_convergence(all_results, tolerance_line = L2_TOLERANCE_TARGET)
    println("\n" * l2_desc)
    
    # Critical point recovery histogram
    @info "Generating critical point recovery histogram..."
    fig_recovery = plot_critical_point_recovery_histogram(
        enhanced_all_results,
        title = "Adaptive Recovery Rates: (+,-,+,-) Orthant",
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Critical point recovery histogram saved"
    
    # Generate and display plot description
    recovery_desc = describe_subdivision_recovery_rates(all_results)
    println("\n" * recovery_desc)
    
    # Min+min distance plot with dual scale
    @info "Generating min+min distance plots..."
    fig_min_min = plot_min_min_distances_dual_scale(
        enhanced_all_results,
        title = "Min+Min Distance: Adaptive Subdivisions",
        tolerance_line = 0.001,
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Min+min distance plots saved"
    
    # Min+min capture methods histogram
    fig_capture = plot_min_min_capture_methods(
        enhanced_all_results,
        title = "Min+Min Capture Methods: Adaptive Subdivisions",
        save_plots = true,
        plots_directory = output_dir
    )
    @info "Min+min capture methods histogram saved"
    
    # Generate and display plot description
    min_min_desc = describe_subdivision_min_min_distances(all_results)
    println("\n" * min_min_desc)
    
    # Generate degree requirements visualization
    @info "Analyzing degree requirements..."
    
    # Create degree requirements summary
    degree_requirements = Dict{String, Union{Int, String}}()
    convergence_summary = Dict{String, NamedTuple}()
    
    for (label, results) in all_results
        if !isempty(results)
            converged_idx = findfirst([r.converged for r in results])
            if converged_idx !== nothing
                degree_requirements[label] = results[converged_idx].degree
                convergence_summary[label] = (
                    degree = results[converged_idx].degree,
                    l2_norm = results[converged_idx].l2_norm,
                    n_attempts = converged_idx,
                    total_runtime = sum([r.runtime_seconds for r in results])
                )
            else
                # Find best attempt
                best_idx = argmin([r.l2_norm for r in results])
                degree_requirements[label] = "Failed"
                convergence_summary[label] = (
                    degree = results[best_idx].degree,
                    l2_norm = results[best_idx].l2_norm,
                    n_attempts = length(results),
                    total_runtime = sum([r.runtime_seconds for r in results])
                )
            end
        else
            degree_requirements[label] = "No data"
        end
    end
    
    # Print degree requirements map
    @info "\nDegree Requirements by Subdomain:"
    for label in sort(collect(keys(degree_requirements)))
        req = degree_requirements[label]
        if req isa Int
            @info "  $label: degree $req"
        else
            @info "  $label: $req"
        end
    end
    
    # Generate summary statistics
    converged_labels = [label for (label, req) in degree_requirements if req isa Int]
    failed_labels = [label for (label, req) in degree_requirements if req == "Failed"]
    
    @info "\nConvergence Summary:"
    @info "  Converged: $(length(converged_labels))/16 subdomains"
    @info "  Failed: $(length(failed_labels))/16 subdomains"
    
    if !isempty(converged_labels)
        converged_degrees = [degree_requirements[label] for label in converged_labels]
        @info "  Degree range for convergence: $(minimum(converged_degrees))-$(maximum(converged_degrees))"
        @info "  Average degree needed: $(@sprintf("%.1f", mean(converged_degrees)))"
    end
    
    # Computational cost analysis
    @info "\nComputational Cost Analysis:"
    
    total_computations = sum([length(results) for results in values(all_results)])
    @info "  Total degree evaluations: $total_computations"
    
    # Find most and least expensive subdomains
    if !isempty(convergence_summary)
        sorted_by_runtime = sort(collect(convergence_summary), by=x->x[2].total_runtime)
        
        fastest = first(sorted_by_runtime)
        slowest = last(sorted_by_runtime)
        
        @info "  Fastest subdomain: $(fastest[1])" runtime=@sprintf("%.1f", fastest[2].total_runtime) attempts=fastest[2].n_attempts
        @info "  Slowest subdomain: $(slowest[1])" runtime=@sprintf("%.1f", slowest[2].total_runtime) attempts=slowest[2].n_attempts
    end
    
    # Generate summary table
    @info "\nGenerating summary table..."
    generate_subdivision_summary_table(all_results, title="Adaptive Orthant Subdivision Analysis")
    
    # Export detailed results to CSV
    csv_rows = []
    for (label, results) in all_results
        for (i, result) in enumerate(results)
            push!(csv_rows, (
                subdomain = label,
                attempt = i,
                degree = result.degree,
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
        csv_path = joinpath(output_dir, "adaptive_subdivision_results.csv")
        CSV.write(csv_path, df)
        @info "Detailed history exported to CSV" path=csv_path n_rows=nrow(df)
    end
    
    # Spatial patterns analysis
    @info "\nSpatial Patterns in Degree Requirements:"
    
    # Group by number of positive dimensions
    if !isempty(converged_labels)
        groups = Dict{Int, Vector{Int}}()
        for label in converged_labels
            n_positive = count(c -> c == '1', label)
            if !haskey(groups, n_positive)
                groups[n_positive] = Int[]
            end
            push!(groups[n_positive], degree_requirements[label])
        end
        
        for n_pos in sort(collect(keys(groups)))
            degrees = groups[n_pos]
            @info "  $n_pos positive dims" mean_degree=@sprintf("%.1f", mean(degrees)) degree_range="$(minimum(degrees))-$(maximum(degrees))" n_subdomains=length(degrees)
        end
    end
    
    @info "\nAdaptive orthant subdivision analysis complete!" output_directory=output_dir
    
    return all_results, degree_requirements, output_dir
end

# ================================================================================
# EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    all_results, degree_requirements, output_dir = run_adaptive_subdivision_analysis()
end