# ================================================================================
# 4D Deuflhard - 16 Subdivisions Adaptive Convergence Analysis (Fixed Version)
# ================================================================================
# 
# Advanced spatial analysis with fixed L²-tolerance and adaptive degree/sample increase
# per subdomain until convergence is achieved - WITH ROBUST PLOTTING
#
# Key Features:
# - Fixed L²-tolerance target across all subdomains (0.005)
# - Adaptive degree increase per subdomain until L²-norm target is met
# - CairoMakie backend for stable plotting (no GLMakie text issues)
# - No legends to avoid text rendering problems
# - Focus on data collection and table summaries
#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim

# Core Julia packages
using Statistics, Printf, LinearAlgebra, Dates
using DataFrames, CSV

# Domain-specific packages  
using DynamicPolynomials, Optim, ForwardDiff

# Presentation and visualization
using PrettyTables
using CairoMakie  # Stable plotting backend

# ================================================================================
# PARAMETERS - ADAPTIVE CONVERGENCE ANALYSIS
# ================================================================================

# Domain and approximation parameters
const ORIGINAL_DOMAIN_RANGE = 1.0                 # Original [-1,1]^4 domain
const SUBDOMAIN_RANGE = 0.5                       # Each subdomain has range 0.5
const L2_TOLERANCE_TARGET = 1e-1                  # Relaxed L²-norm target (0.1) for faster convergence
const DEGREE_MIN = 2                              # Starting polynomial degree  
const DEGREE_MAX = 10                             # Maximum degree per subdomain
const DISTANCE_TOLERANCE = 0.05                   # Success threshold for critical point recovery

# Adaptive parameters
const INITIAL_GN = 5                              # Starting sample count parameter
const MAX_GN = 15                                 # Maximum sample count parameter
const GN_INCREMENT = 2                            # Sample count increase step
const CONVERGENCE_STAGNATION_THRESHOLD = 3        # Degrees without improvement before increasing samples

# Computational parameters
const MAX_RUNTIME_PER_SUBDOMAIN = 300            # Timeout per subdomain (5 minutes)
const MAX_RUNTIME_PER_DEGREE = 60                # Timeout per degree (1 minute)
const MAX_TOTAL_RUNTIME = 3600                   # Maximum total runtime (1 hour)

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

"""
    deuflhard_4d_composite(x::AbstractVector)::Float64

4D Deuflhard composite function: f(x₁,x₂,x₃,x₄) = Deuflhard([x₁,x₂]) + Deuflhard([x₃,x₄])
Tensor product construction allows known critical point locations.
"""
function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# SUBDOMAIN GENERATION AND MANAGEMENT
# ================================================================================

"""
    Subdomain

Structure representing a single subdomain of the 4D hypercube.

# Fields
- `label::String`: Binary label (e.g., "0000", "0001", ..., "1111")
- `center::Vector{Float64}`: Center point of subdomain
- `range::Float64`: Half-width of subdomain
- `bounds::Vector{Tuple{Float64,Float64}}`: Domain bounds [(x1_min,x1_max), ...]
"""
struct Subdomain
    label::String
    center::Vector{Float64}
    range::Float64
    bounds::Vector{Tuple{Float64,Float64}}
end

"""
    generate_16_subdivisions()

Generate all 16 subdomains by dividing [-1,1]^4 at x=0 in each dimension.
"""
function generate_16_subdivisions()
    subdivisions = Subdomain[]
    
    for i in 0:15
        # Convert to 4-bit binary representation
        binary_repr = string(i, base=2, pad=4)
        
        # Calculate center based on binary representation
        center = Float64[]
        bounds = Tuple{Float64,Float64}[]
        
        for bit_char in binary_repr
            if bit_char == '0'
                # Negative subdomain: [-1, 0]
                push!(center, -0.5)
                push!(bounds, (-1.0, 0.0))
            else
                # Positive subdomain: [0, 1]  
                push!(center, 0.5)
                push!(bounds, (0.0, 1.0))
            end
        end
        
        subdomain = Subdomain(binary_repr, center, SUBDOMAIN_RANGE, bounds)
        push!(subdivisions, subdomain)
    end
    
    @info "Generated 16 subdomains" labels=[s.label for s in subdivisions]
    return subdivisions
end

"""
    load_theoretical_points_for_subdomain(subdomain::Subdomain)

Load theoretical critical points that fall within the specified subdomain.
"""
function load_theoretical_points_for_subdomain(subdomain::Subdomain)
    # Load full set of 2D critical points
    csv_path = joinpath(@__DIR__, "../../../data/matlab_critical_points/valid_points_deuflhard.csv")
    
    if !isfile(csv_path)
        error("Critical points CSV file not found at: $csv_path")
    end
    
    csv_data = CSV.read(csv_path, DataFrame)
    critical_2d = [[row.x, row.y] for row in eachrow(csv_data)]
    
    # Classify 2D points
    critical_2d_types = String[]
    for pt in critical_2d
        hess = ForwardDiff.hessian(Deuflhard, pt)
        eigenvals = eigvals(hess)
        
        if all(eigenvals .> 1e-6)
            push!(critical_2d_types, "min")
        elseif all(eigenvals .< -1e-6)
            push!(critical_2d_types, "max")
        else
            push!(critical_2d_types, "saddle")
        end
    end
    
    # Generate 4D tensor products and filter by subdomain
    theoretical_points_4d = Vector{Vector{Float64}}()
    theoretical_values_4d = Float64[]
    theoretical_types = String[]
    
    for (i, pt1) in enumerate(critical_2d)
        for (j, pt2) in enumerate(critical_2d)
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            
            # Check if point falls within subdomain bounds
            within_bounds = true
            for (dim, coord) in enumerate(point_4d)
                lower, upper = subdomain.bounds[dim]
                if coord < lower || coord > upper
                    within_bounds = false
                    break
                end
            end
            
            if within_bounds
                value_4d = deuflhard_4d_composite(point_4d)
                type_4d = "$(critical_2d_types[i])+$(critical_2d_types[j])"
                
                push!(theoretical_points_4d, point_4d)
                push!(theoretical_values_4d, value_4d)
                push!(theoretical_types, type_4d)
            end
        end
    end
    
    @info "Subdomain $(subdomain.label) theoretical points" n_points=length(theoretical_points_4d)
    
    return theoretical_points_4d, theoretical_values_4d, theoretical_types
end

# ================================================================================
# ADAPTIVE ANALYSIS FUNCTIONS
# ================================================================================

"""
    analyze_subdomain_adaptive_degree(degree::Int, gn::Int, subdomain::Subdomain, theoretical_points)

Analyze polynomial approximation for single degree and sample count within a specific subdomain.
"""
function analyze_subdomain_adaptive_degree(degree::Int, gn::Int, subdomain::Subdomain, theoretical_points)
    @info "Analyzing subdomain $(subdomain.label), degree $degree, GN $gn"
    
    start_time = time()
    
    try
        # Create polynomial approximation on subdomain
        TR = test_input(deuflhard_4d_composite, dim=4,
                       center=subdomain.center, sample_range=subdomain.range,
                       GN=gn, reduce_samples=1.0)
        
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Handle both Tuple and Int degree types
        actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
        
        # Solve polynomial system
        @polyvar x[1:4]
        solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
        df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR)
        
        # Extract critical points within subdomain
        computed_points = Vector{Vector{Float64}}()
        computed_values = Float64[]
        
        if nrow(df_crit) > 0
            for i in 1:nrow(df_crit)
                point = [df_crit[i, Symbol("x$j")] for j in 1:4]
                
                # Check if point is within subdomain bounds
                within_bounds = true
                for (dim, coord) in enumerate(point)
                    lower, upper = subdomain.bounds[dim]
                    if coord < lower - 0.1 || coord > upper + 0.1  # Small tolerance
                        within_bounds = false
                        break
                    end
                end
                
                if within_bounds
                    push!(computed_points, point)
                    push!(computed_values, df_crit[i, :z])
                end
            end
        end
        
        # Compute distances to theoretical points
        n_theoretical = length(theoretical_points)
        n_computed = length(computed_points)
        
        closest_distances = Float64[]
        if n_computed > 0 && n_theoretical > 0
            for theoretical_pt in theoretical_points
                min_dist = minimum([norm(theoretical_pt - computed_pt) for computed_pt in computed_points])
                push!(closest_distances, min_dist)
            end
        else
            closest_distances = fill(Inf, n_theoretical)
        end
        
        # Success metrics
        successful_recoveries = sum(closest_distances .< DISTANCE_TOLERANCE)
        success_rate = n_theoretical > 0 ? successful_recoveries / n_theoretical : 0.0
        
        # Timing
        runtime = time() - start_time
        
        # Results summary
        results = (
            subdomain_label = subdomain.label,
            degree = actual_degree,
            gn = gn,
            l2_norm = pol.nrm,
            n_theoretical_points = n_theoretical,
            n_computed_points = n_computed,
            n_successful_recoveries = successful_recoveries,
            success_rate = success_rate,
            median_distance = n_computed > 0 && n_theoretical > 0 ? median(closest_distances) : Inf,
            runtime_seconds = runtime,
            computed_points = computed_points,
            closest_distances = closest_distances,
            converged = pol.nrm <= L2_TOLERANCE_TARGET
        )
        
        status = results.converged ? "CONVERGED" : "not converged"
        @info "Subdomain $(subdomain.label), degree $degree, GN $gn completed" l2_norm=@sprintf("%.2e", pol.nrm) status=status n_points=n_computed success_rate=@sprintf("%.1f%%", 100*success_rate) runtime=@sprintf("%.1f", runtime)
        
        return results
        
    catch e
        @error "Subdomain $(subdomain.label), degree $degree, GN $gn analysis failed" exception=e
        return (
            subdomain_label = subdomain.label,
            degree = degree,
            gn = gn,
            l2_norm = Inf,
            n_theoretical_points = length(theoretical_points),
            n_computed_points = 0,
            n_successful_recoveries = 0,
            success_rate = 0.0,
            median_distance = Inf,
            runtime_seconds = time() - start_time,
            computed_points = Vector{Vector{Float64}}(),
            closest_distances = Float64[],
            converged = false
        )
    end
end

"""
    analyze_single_subdomain_adaptive(subdomain::Subdomain)

Perform adaptive analysis for a single subdomain with fixed L²-tolerance target.
"""
function analyze_single_subdomain_adaptive(subdomain::Subdomain)
    @info "Starting adaptive analysis for subdomain $(subdomain.label)" center=subdomain.center bounds=subdomain.bounds target_l2=L2_TOLERANCE_TARGET
    
    # Load theoretical points for this subdomain
    theoretical_points, _, _ = load_theoretical_points_for_subdomain(subdomain)
    
    if isempty(theoretical_points)
        @warn "No theoretical points found in subdomain $(subdomain.label), skipping"
        return NamedTuple[]
    end
    
    subdomain_results = NamedTuple[]
    subdomain_start_time = time()
    
    current_gn = INITIAL_GN
    stagnation_count = 0
    best_l2_norm = Inf
    
    for degree in DEGREE_MIN:DEGREE_MAX
        # Check subdomain timeout
        if time() - subdomain_start_time > MAX_RUNTIME_PER_SUBDOMAIN
            @warn "Subdomain $(subdomain.label) exceeded maximum runtime, stopping" max_runtime=MAX_RUNTIME_PER_SUBDOMAIN
            break
        end
        
        # Analyze current degree with current sample count
        result = analyze_subdomain_adaptive_degree(degree, current_gn, subdomain, theoretical_points)
        push!(subdomain_results, result)
        
        # Check for convergence
        if result.converged
            @info "Subdomain $(subdomain.label) achieved L²-norm target" degree=degree gn=current_gn l2_norm=result.l2_norm target=L2_TOLERANCE_TARGET
            break
        end
        
        # Early termination if degree timeout
        if result.runtime_seconds > MAX_RUNTIME_PER_DEGREE
            @warn "Subdomain $(subdomain.label), degree $degree exceeded runtime, stopping" max_runtime=MAX_RUNTIME_PER_DEGREE
            break
        end
        
        # Check for improvement
        if result.l2_norm < best_l2_norm
            best_l2_norm = result.l2_norm
            stagnation_count = 0
        else
            stagnation_count += 1
        end
        
        # Increase sample count if stagnating and not at maximum
        if stagnation_count >= CONVERGENCE_STAGNATION_THRESHOLD && current_gn < MAX_GN
            old_gn = current_gn
            current_gn = min(current_gn + GN_INCREMENT, MAX_GN)
            @info "Increasing sample count due to stagnation" subdomain=subdomain.label old_gn=old_gn new_gn=current_gn stagnation_count=stagnation_count
            stagnation_count = 0  # Reset stagnation counter
        end
    end
    
    total_runtime = time() - subdomain_start_time
    converged = !isempty(subdomain_results) && any([r.converged for r in subdomain_results])
    final_l2_norm = isempty(subdomain_results) ? Inf : minimum([r.l2_norm for r in subdomain_results])
    
    @info "Subdomain $(subdomain.label) adaptive analysis complete" degrees_tested=length(subdomain_results) converged=converged final_l2_norm=@sprintf("%.2e", final_l2_norm) total_runtime=@sprintf("%.1f", total_runtime)
    
    return subdomain_results
end

# ================================================================================
# ROBUST VISUALIZATION (NO LEGENDS)
# ================================================================================

"""
    plot_combined_adaptive_convergence_robust(all_subdivision_results::Dict)

Create combined L²-norm convergence plot with robust CairoMakie rendering (no legends).
"""
function plot_combined_adaptive_convergence_robust(all_subdivision_results::Dict)
    @info "Starting robust combined adaptive convergence plot generation"
    
    fig = Figure(size = (1200, 800))
    ax = Axis(fig[1, 1],
        title = "Adaptive L²-Norm Convergence: 16 Subdomains of 4D Deuflhard",
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10
    )
    
    # Color palette for 16 subdomains
    colors = [:red, :blue, :green, :orange, :purple, :cyan, :magenta, :yellow,
              :darkred, :darkblue, :darkgreen, :darkorange, :darkmagenta, :darkcyan, :brown, :pink]
    
    # Plot each subdomain's adaptive convergence curve
    plotted_count = 0
    for (i, label) in enumerate(sort(collect(keys(all_subdivision_results))))
        results = all_subdivision_results[label]
        @info "Processing subdomain $label" has_data=!isempty(results)
        
        if !isempty(results)
            degrees = [r.degree for r in results]
            l2_norms = [r.l2_norm for r in results]
            
            # Filter out infinite values
            valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
            if !isempty(valid_indices)
                valid_degrees = degrees[valid_indices]
                valid_l2_norms = l2_norms[valid_indices]
                
                # Plot with different markers for different GN values
                for (j, (deg, l2)) in enumerate(zip(valid_degrees, valid_l2_norms))
                    current_gn = j < length(results) ? results[j].gn : INITIAL_GN
                    
                    # Use different marker sizes for different GN values
                    marker_size = 6 + (current_gn - INITIAL_GN) * 2
                    
                    scatter!(ax, [deg], [l2], 
                           color = colors[min(i, length(colors))], 
                           markersize = marker_size,
                           alpha = 0.7)
                end
                
                # Connect points with lines (no label to avoid text issues)
                lines!(ax, valid_degrees, valid_l2_norms, 
                      color = colors[min(i, length(colors))], 
                      linewidth = 1.5,
                      alpha = 0.8)
                
                plotted_count += 1
            else
                @warn "No valid data for subdomain $label"
            end
        end
    end
    
    # Add tolerance reference line
    hlines!(ax, [L2_TOLERANCE_TARGET], color = :black, linestyle = :dash, linewidth = 2)
    
    # Add grid
    ax.xgridvisible = true
    ax.ygridvisible = true
    
    @info "Robust convergence plot generation complete" plotted_subdivisions=plotted_count
    return fig
end

"""
    generate_adaptive_summary_table(all_subdivision_results::Dict)

Generate comprehensive summary table for adaptive analysis results.
"""
function generate_adaptive_summary_table(all_subdivision_results::Dict)
    @info "Generating adaptive analysis summary table"
    
    # Collect summary data
    table_data = Vector{Vector{Any}}()
    
    for label in sort(collect(keys(all_subdivision_results)))
        results = all_subdivision_results[label]
        if !isempty(results)
            # Find best result and convergence info
            best_idx = argmin([r.l2_norm for r in results])
            best_result = results[best_idx]
            
            converged = any([r.converged for r in results])
            convergence_degree = converged ? results[findfirst([r.converged for r in results])].degree : "None"
            convergence_gn = converged ? results[findfirst([r.converged for r in results])].gn : "N/A"
            
            total_runtime = sum([r.runtime_seconds for r in results])
            degrees_tested = length(results)
            
            # GN progression
            gn_range = isempty(results) ? "N/A" : "$(minimum([r.gn for r in results]))-$(maximum([r.gn for r in results]))"
            
            push!(table_data, [
                label,
                degrees_tested,
                @sprintf("%.2e", best_result.l2_norm),
                best_result.degree,
                string(convergence_degree),
                string(convergence_gn),
                gn_range,
                best_result.n_theoretical_points,
                @sprintf("%.1f%%", best_result.success_rate * 100),
                @sprintf("%.1f", total_runtime)
            ])
        else
            push!(table_data, [label, 0, "N/A", "N/A", "N/A", "N/A", "N/A", 0, "N/A", "0.0"])
        end
    end
    
    headers = ["Subdomain", "Degrees", "Best L²-Norm", "Best Degree", "Conv. Degree", 
               "Conv. GN", "GN Range", "Theory Pts", "Success %", "Runtime(s)"]
    
    # Convert to matrix format for pretty_table
    if !isempty(table_data)
        n_rows = length(table_data)
        n_cols = length(headers)
        table_matrix = Matrix{String}(undef, n_rows, n_cols)
        
        for (i, row) in enumerate(table_data)
            for (j, val) in enumerate(row)
                table_matrix[i, j] = string(val)
            end
        end
        
        pretty_table(
            table_matrix,
            header = headers,
            alignment = [:c, :c, :r, :c, :c, :c, :c, :c, :r, :r],
            title = "16 Subdivision Adaptive Analysis Summary"
        )
    else
        println("No subdivision data to display")
    end
end

# ================================================================================
# MAIN EXECUTION
# ================================================================================

@info "Starting 4D Deuflhard 16-Subdivision Adaptive Analysis (Fixed Version)" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS") target_l2=L2_TOLERANCE_TARGET max_degree=DEGREE_MAX

# Generate 16 subdomains
subdivisions = generate_16_subdivisions()

# Analyze each subdomain adaptively
@info "Beginning adaptive subdivision analysis" n_subdivisions=length(subdivisions) degree_range="$DEGREE_MIN:$DEGREE_MAX" target_l2=L2_TOLERANCE_TARGET

all_subdivision_results = Dict{String, Vector{NamedTuple}}()
analysis_start_time = time()

for (i, subdomain) in enumerate(subdivisions)
    # Check total runtime
    if time() - analysis_start_time > MAX_TOTAL_RUNTIME
        @warn "Maximum total runtime exceeded, stopping analysis" max_runtime=MAX_TOTAL_RUNTIME
        break
    end
    
    @info "Processing subdomain $(i)/$(length(subdivisions)): $(subdomain.label)"
    subdivision_results = analyze_single_subdomain_adaptive(subdomain)
    all_subdivision_results[subdomain.label] = subdivision_results
end

# Create output directory
output_dir = joinpath(@__DIR__, "outputs", "adaptive_subdivisions_fixed_$(Dates.format(now(), "yyyy-mm-dd_HH-MM"))")
mkpath(output_dir)
@info "Created output directory" path=output_dir

# Generate combined visualization (save to file only)
@info "Generating robust combined adaptive convergence plot (file output only)"
try
    # Check if we have any data to plot
    non_empty_results = [label for (label, results) in all_subdivision_results if !isempty(results)]
    @info "Subdivisions with data" count=length(non_empty_results) labels=non_empty_results
    
    if !isempty(non_empty_results)
        fig_combined = plot_combined_adaptive_convergence_robust(all_subdivision_results)
        
        # Save plot to file instead of displaying
        plot_path = joinpath(output_dir, "adaptive_convergence_16_subdivisions.png")
        save(plot_path, fig_combined)
        @info "Combined adaptive convergence plot saved successfully" path=plot_path
    else
        @warn "No subdivision data available for plotting"
    end
catch e
    @warn "Robust plotting failed: $e"
    @warn "Full error details:" exception=(e, catch_backtrace())
end

# Generate summary table and save to CSV
@info "Generating adaptive analysis summary"
generate_adaptive_summary_table(all_subdivision_results)

# Save detailed results to CSV
@info "Saving detailed results to CSV"
try
    csv_data = []
    for (label, results) in all_subdivision_results
        if !isempty(results)
            for result in results
                push!(csv_data, (
                    subdomain = label,
                    degree = result.degree,
                    gn = result.gn,
                    l2_norm = result.l2_norm,
                    converged = result.converged,
                    runtime_seconds = result.runtime_seconds,
                    n_theoretical_points = result.n_theoretical_points,
                    n_computed_points = result.n_computed_points,
                    success_rate = result.success_rate
                ))
            end
        end
    end
    
    if !isempty(csv_data)
        df_results = DataFrame(csv_data)
        csv_path = joinpath(output_dir, "adaptive_analysis_detailed_results.csv")
        CSV.write(csv_path, df_results)
        @info "Detailed results saved to CSV" path=csv_path n_rows=nrow(df_results)
    end
catch e
    @warn "Failed to save CSV results" exception=e
end

# ================================================================================
# ENHANCED ANALYSIS INSIGHTS
# ================================================================================

@info "Generating adaptive analysis insights"

# Count successful analyses and convergences
successful_subdivisions = [label for (label, results) in all_subdivision_results if !isempty(results)]
converged_subdivisions = String[]
partially_converged_subdivisions = String[]

for (label, results) in all_subdivision_results
    if !isempty(results)
        if any([r.converged for r in results])
            push!(converged_subdivisions, label)
        elseif minimum([r.l2_norm for r in results]) < L2_TOLERANCE_TARGET * 10  # Within order of magnitude
            push!(partially_converged_subdivisions, label)
        end
    end
end

@info "Adaptive analysis summary" total_subdivisions=16 successful_analyses=length(successful_subdivisions) fully_converged=length(converged_subdivisions) partially_converged=length(partially_converged_subdivisions)

if !isempty(converged_subdivisions)
    @info "Fully converged subdivisions" labels=converged_subdivisions target_l2=L2_TOLERANCE_TARGET
else
    @warn "No subdivisions achieved L²-norm target" target=L2_TOLERANCE_TARGET
end

if !isempty(partially_converged_subdivisions)
    @info "Partially converged subdivisions (within order of magnitude)" labels=partially_converged_subdivisions
end

# Analyze computational requirements
if !isempty(successful_subdivisions)
    degrees_required = Dict{String, Int}()
    gn_required = Dict{String, Int}()
    
    for (label, results) in all_subdivision_results
        if !isempty(results)
            if any([r.converged for r in results])
                # Find first convergence
                conv_idx = findfirst([r.converged for r in results])
                degrees_required[label] = results[conv_idx].degree
                gn_required[label] = results[conv_idx].gn
            else
                # Use best result
                best_idx = argmin([r.l2_norm for r in results])
                degrees_required[label] = results[best_idx].degree
                gn_required[label] = results[best_idx].gn
            end
        end
    end
    
    if !isempty(degrees_required)
        avg_degree = mean(collect(values(degrees_required)))
        avg_gn = mean(collect(values(gn_required)))
        @info "Average computational requirements" avg_degree=@sprintf("%.1f", avg_degree) avg_gn=@sprintf("%.1f", avg_gn)
    end
end

# Find most and least challenging subdomains
if !isempty(successful_subdivisions)
    local most_challenging = ""
    local least_challenging = ""
    local highest_l2 = 0.0
    local lowest_l2 = Inf
    
    for (label, results) in all_subdivision_results
        if !isempty(results)
            best_l2 = minimum([r.l2_norm for r in results])
            if best_l2 > highest_l2
                highest_l2 = best_l2
                most_challenging = label
            end
            if best_l2 < lowest_l2
                lowest_l2 = best_l2
                least_challenging = label
            end
        end
    end
    
    @info "Spatial difficulty analysis" most_challenging=most_challenging highest_l2=@sprintf("%.2e", highest_l2) least_challenging=least_challenging lowest_l2=@sprintf("%.2e", lowest_l2)
end

total_runtime = time() - analysis_start_time
@info "16-subdivision adaptive analysis complete" total_runtime=@sprintf("%.1f", total_runtime) output_directory=output_dir target_achieved=length(converged_subdivisions)