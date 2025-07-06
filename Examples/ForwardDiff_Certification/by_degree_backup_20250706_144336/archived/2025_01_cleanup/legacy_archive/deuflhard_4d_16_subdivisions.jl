# ================================================================================
# 4D Deuflhard - 16 Subdivisions Adaptive Degree Convergence Analysis
# ================================================================================
# 
# Comprehensive spatial analysis dividing [-1,1]^4 domain into 16 subdomains
# with adaptive degree convergence analysis and combined visualization
#
# Objectives:
# - Analyze convergence patterns across 16 spatial subdomains
# - Compare L²-norm convergence rates between different regions
# - Identify which subdomains are harder to approximate
# - Generate combined visualization showing all 16 convergence curves
#
# Key Features:
# - 16 subdomain analysis (2^4 hypercube divisions)
# - Adaptive degree termination per subdomain
# - Combined L²-norm convergence visualization
# - Spatial convergence pattern analysis
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
using CairoMakie  # File-based plotting backend

# ================================================================================
# PARAMETERS - 16 SUBDIVISION ANALYSIS
# ================================================================================

# Domain and approximation parameters
const ORIGINAL_DOMAIN_RANGE = 1.0                 # Original [-1,1]^4 domain
const SUBDOMAIN_RANGE = 0.5                       # Each subdomain has range 0.5
const L2_TOLERANCE_TIGHT = 1e-1                   # Relaxed L²-norm target (0.1) for faster convergence
const DEGREE_MIN = 2                              # Starting polynomial degree  
const DEGREE_MAX = 10                             # Maximum degree per subdomain
const DISTANCE_TOLERANCE = 0.05                   # Success threshold for critical point recovery

# Computational parameters
const SAMPLE_SCALING = 1.0                        # Automatic sampling scale factor
const MAX_RUNTIME_PER_SUBDOMAIN = 60             # Timeout per subdomain (1 minute)
const MAX_RUNTIME_PER_DEGREE = 20                # Timeout per degree (20 seconds)

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION (SAME AS FULL DOMAIN)
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

# Returns
- `Vector{Subdomain}`: Array of 16 subdomain structures with labels and centers

# Description
Creates binary subdivision of 4D hypercube where each dimension is split at 0.
Labels use binary encoding: "0000" = all negative quadrants, "1111" = all positive.
"""
function generate_16_subdivisions()
    subdivisions = Subdomain[]
    
    for i in 0:15
        # Convert to 4-bit binary representation
        binary_repr = string(i, base=2, pad=4)
        
        # Calculate center based on binary representation
        center = Float64[]
        bounds = Tuple{Float64,Float64}[]
        
        for (dim, bit_char) in enumerate(binary_repr)
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

# Arguments
- `subdomain`: Subdomain structure defining spatial bounds

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types) within subdomain

# Description
Filters the full set of 4D theoretical points to include only those within
the subdomain's spatial bounds.
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
# SINGLE SUBDOMAIN ANALYSIS
# ================================================================================

"""
    analyze_subdomain_single_degree(degree::Int, subdomain::Subdomain, theoretical_points, theoretical_values, theoretical_types)

Analyze polynomial approximation for single degree within a specific subdomain.

# Arguments
- `degree`: Polynomial degree to test
- `subdomain`: Subdomain structure defining spatial region
- `theoretical_points`: Reference critical points within subdomain
- `theoretical_values`: Function values at theoretical points
- `theoretical_types`: Classification of theoretical points

# Returns
- `NamedTuple`: Comprehensive metrics for the subdomain at specified degree
"""
function analyze_subdomain_single_degree(degree::Int, subdomain::Subdomain, theoretical_points, theoretical_values, theoretical_types)
    @info "Analyzing subdomain $(subdomain.label), degree $degree"
    
    start_time = time()
    
    try
        # Create polynomial approximation on subdomain
        TR = test_input(deuflhard_4d_composite, dim=4,
                       center=subdomain.center, sample_range=subdomain.range,
                       GN=5, reduce_samples=SAMPLE_SCALING)
        
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
            l2_norm = pol.nrm,
            n_samples = try; pol.n_samples; catch; "unknown"; end,
            n_theoretical_points = n_theoretical,
            n_computed_points = n_computed,
            n_successful_recoveries = successful_recoveries,
            success_rate = success_rate,
            median_distance = n_computed > 0 && n_theoretical > 0 ? median(closest_distances) : Inf,
            runtime_seconds = runtime,
            computed_points = computed_points,
            closest_distances = closest_distances
        )
        
        @info "Subdomain $(subdomain.label), degree $degree completed" l2_norm=@sprintf("%.2e", pol.nrm) n_points=n_computed success_rate=@sprintf("%.1f%%", 100*success_rate) runtime=@sprintf("%.1f", runtime)
        
        return results
        
    catch e
        @error "Subdomain $(subdomain.label), degree $degree analysis failed" exception=e
        return (
            subdomain_label = subdomain.label,
            degree = degree,
            l2_norm = Inf,
            n_samples = 0,
            n_theoretical_points = length(theoretical_points),
            n_computed_points = 0,
            n_successful_recoveries = 0,
            success_rate = 0.0,
            median_distance = Inf,
            runtime_seconds = time() - start_time,
            computed_points = Vector{Vector{Float64}}(),
            closest_distances = Float64[]
        )
    end
end

"""
    analyze_single_subdomain(subdomain::Subdomain)

Perform adaptive degree sweep analysis for a single subdomain.

# Arguments
- `subdomain`: Subdomain structure defining spatial region

# Returns
- `Dict{Int, NamedTuple}`: Analysis results indexed by degree for this subdomain

# Description
Executes degree sweep with early termination when L²-norm tolerance is achieved
or maximum degree/runtime is reached.
"""
function analyze_single_subdomain(subdomain::Subdomain)
    @info "Starting analysis for subdomain $(subdomain.label)" center=subdomain.center bounds=subdomain.bounds
    
    # Load theoretical points for this subdomain
    theoretical_points, theoretical_values, theoretical_types = load_theoretical_points_for_subdomain(subdomain)
    
    if isempty(theoretical_points)
        @warn "No theoretical points found in subdomain $(subdomain.label), skipping"
        return Dict{Int, NamedTuple}()
    end
    
    subdomain_results = Dict{Int, NamedTuple}()
    subdomain_start_time = time()
    
    for degree in DEGREE_MIN:DEGREE_MAX
        # Check subdomain timeout
        if time() - subdomain_start_time > MAX_RUNTIME_PER_SUBDOMAIN
            @warn "Subdomain $(subdomain.label) exceeded maximum runtime, stopping" max_runtime=MAX_RUNTIME_PER_SUBDOMAIN
            break
        end
        
        result = analyze_subdomain_single_degree(degree, subdomain, theoretical_points, theoretical_values, theoretical_types)
        subdomain_results[degree] = result
        
        # Early termination if degree timeout
        if result.runtime_seconds > MAX_RUNTIME_PER_DEGREE
            @warn "Subdomain $(subdomain.label), degree $degree exceeded runtime, stopping degree sweep" max_runtime=MAX_RUNTIME_PER_DEGREE
            break
        end
        
        # Early termination if L²-norm tolerance achieved
        if result.l2_norm <= L2_TOLERANCE_TIGHT
            @info "Subdomain $(subdomain.label) achieved L²-norm tolerance, stopping" degree=degree l2_norm=result.l2_norm tolerance=L2_TOLERANCE_TIGHT
            break
        end
    end
    
    total_runtime = time() - subdomain_start_time
    @info "Subdomain $(subdomain.label) analysis complete" degrees_tested=length(subdomain_results) total_runtime=@sprintf("%.1f", total_runtime)
    
    return subdomain_results
end

# ================================================================================
# COMBINED VISUALIZATION
# ================================================================================

"""
    plot_combined_l2_convergence(all_subdivision_results::Dict)

Create combined L²-norm convergence plot showing all 16 subdomains.

# Arguments
- `all_subdivision_results`: Dictionary mapping subdomain labels to degree results

# Returns
- `Figure`: Combined plot with 16 convergence curves
"""
function plot_combined_l2_convergence(all_subdivision_results::Dict)
    @info "Starting combined L²-norm plot generation"
    
    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1],
        title = "L²-Norm Convergence: 16 Subdomains of 4D Deuflhard",
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10
    )
    
    # Color palette for 16 subdomains
    colors = [:red, :blue, :green, :orange, :purple, :cyan, :magenta, :yellow,
              :darkred, :darkblue, :darkgreen, :darkorange, :darkmagenta, :darkcyan, :brown, :pink]
    
    # Collect all data to determine appropriate ranges
    all_degrees = Int[]
    all_l2_norms = Float64[]
    
    # Plot each subdomain's convergence curve
    plotted_count = 0
    for (i, label) in enumerate(sort(collect(keys(all_subdivision_results))))
        results = all_subdivision_results[label]
        @info "Processing subdomain $label" has_data=!isempty(results)
        
        if !isempty(results)
            degrees = sort(collect(keys(results)))
            l2_norms = [results[d].l2_norm for d in degrees]
            
            @info "Subdomain $label data" degrees=degrees l2_norms=l2_norms
            
            # Filter out infinite values
            valid_indices = findall(isfinite.(l2_norms))
            if !isempty(valid_indices)
                valid_degrees = degrees[valid_indices]
                valid_l2_norms = l2_norms[valid_indices]
                
                @info "Valid data for subdomain $label" degrees=valid_degrees l2_norms=valid_l2_norms
                
                # Collect for range calculation
                append!(all_degrees, valid_degrees)
                append!(all_l2_norms, valid_l2_norms)
                
                scatterlines!(ax, valid_degrees, valid_l2_norms, 
                            color = colors[min(i, length(colors))], markersize = 6, linewidth = 1.5)
                plotted_count += 1
            else
                @warn "No valid data for subdomain $label (all L²-norms are infinite)"
            end
        end
    end
    
    @info "Plotting summary" total_plotted=plotted_count total_degrees=length(all_degrees) total_l2_norms=length(all_l2_norms)
    
    # Set appropriate axis limits based on actual data
    if !isempty(all_degrees) && !isempty(all_l2_norms)
        degree_min, degree_max = extrema(all_degrees)
        l2_min, l2_max = extrema(all_l2_norms)
        
        @info "Setting axis limits" degree_range=(degree_min, degree_max) l2_range=(l2_min, l2_max)
        
        # X-axis: degree range with small padding
        xlims!(ax, degree_min - 0.2, degree_max + 0.2)
        
        # Y-axis: Handle log scale carefully
        if l2_min > 0 && l2_max > 0
            # Safe to use log scale
            log_min = log10(l2_min)
            log_max = log10(l2_max)
            log_range = log_max - log_min
            padding = max(0.1, log_range * 0.1)  # At least 0.1 decades padding
            
            ylims!(ax, 10^(log_min - padding), 10^(log_max + padding))
        else
            @warn "Invalid L²-norm values for log scale" l2_min=l2_min l2_max=l2_max
            # Fall back to linear scale
            ax.yscale = identity
            ylims!(ax, l2_min - 0.1 * abs(l2_max - l2_min), l2_max + 0.1 * abs(l2_max - l2_min))
        end
    else
        @warn "No valid data for axis scaling" degrees_count=length(all_degrees) l2_norms_count=length(all_l2_norms)
        # Set default ranges
        xlims!(ax, 1.8, 4.2)
        ylims!(ax, 1e-6, 1e0)
    end
    
    # Add tolerance reference line (only if within visible range)
    if !isempty(all_l2_norms)
        l2_min, l2_max = extrema(all_l2_norms)
        if L2_TOLERANCE_TIGHT >= l2_min * 0.1 && L2_TOLERANCE_TIGHT <= l2_max * 10
            hlines!(ax, [L2_TOLERANCE_TIGHT], color = :black, linestyle = :dash, linewidth = 2)
        end
    end
    
    # Add grid
    ax.xgridvisible = true
    ax.ygridvisible = true
    
    # Remove legend to avoid GLMakie text rendering issues
    # Legend would go here but causes text_quads errors
    
    # Add interactive features
    # Enable zoom and pan
    ax.xzoomlock = false
    ax.yzoomlock = false
    ax.xpanlock = false
    ax.ypanlock = false
    
    # Remove interactive text to avoid rendering issues
    
    @info "Plot generation complete" plotted_subdivisions=plotted_count
    return fig
end

"""
    generate_subdivision_summary_table(all_subdivision_results::Dict)

Generate comprehensive summary table for all 16 subdivisions.
"""
function generate_subdivision_summary_table(all_subdivision_results::Dict)
    # Collect summary data
    table_data = Vector{Vector{Any}}()
    
    for label in sort(collect(keys(all_subdivision_results)))
        results = all_subdivision_results[label]
        if !isempty(results)
            degrees = sort(collect(keys(results)))
            best_degree = degrees[argmin([results[d].l2_norm for d in degrees])]
            best_result = results[best_degree]
            
            convergence_achieved = any([results[d].l2_norm <= L2_TOLERANCE_TIGHT for d in degrees])
            first_convergence_degree = convergence_achieved ? 
                minimum([d for d in degrees if results[d].l2_norm <= L2_TOLERANCE_TIGHT]) : "None"
            
            total_runtime = sum([results[d].runtime_seconds for d in degrees])
            
            push!(table_data, [
                label,
                length(degrees),
                @sprintf("%.2e", best_result.l2_norm),
                best_degree,
                string(first_convergence_degree),
                best_result.n_theoretical_points,
                @sprintf("%.1f%%", best_result.success_rate * 100),
                @sprintf("%.1f", total_runtime)
            ])
        else
            push!(table_data, [label, 0, "N/A", "N/A", "N/A", 0, "N/A", "0.0"])
        end
    end
    
    headers = ["Subdomain", "Degrees", "Best L²-Norm", "Best Degree", "Converged@", 
               "Theory Pts", "Success %", "Runtime(s)"]
    
    # Convert to matrix format for pretty_table
    if !isempty(table_data)
        # Create matrix directly without transpose
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
            alignment = [:c, :c, :r, :c, :c, :c, :r, :r],
            title = "16 Subdivision Analysis Summary"
        )
    else
        println("No subdivision data to display")
    end
end

# ================================================================================
# MAIN EXECUTION
# ================================================================================

@info "Starting 4D Deuflhard 16-Subdivision Adaptive Degree Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")

# Generate 16 subdomains
subdivisions = generate_16_subdivisions()

# Analyze each subdomain
@info "Beginning subdivision analysis" n_subdivisions=length(subdivisions) degree_range="$DEGREE_MIN:$DEGREE_MAX"

all_subdivision_results = Dict{String, Dict{Int, NamedTuple}}()

for subdomain in subdivisions
    subdivision_results = analyze_single_subdomain(subdomain)
    all_subdivision_results[subdomain.label] = subdivision_results
end

# Create output directory
output_dir = joinpath(@__DIR__, "outputs", "subdivisions_$(Dates.format(now(), "yyyy-mm-dd_HH-MM"))")
mkpath(output_dir)
@info "Created output directory" path=output_dir

# Generate combined visualization
@info "Generating combined L²-norm convergence plot"
try
    # Check if we have any data to plot
    non_empty_results = [label for (label, results) in all_subdivision_results if !isempty(results)]
    @info "Subdivisions with data" count=length(non_empty_results) labels=non_empty_results
    
    if !isempty(non_empty_results)
        fig_combined = plot_combined_l2_convergence(all_subdivision_results)
        
        # Save plot to file instead of displaying
        plot_path = joinpath(output_dir, "combined_l2_convergence_16_subdivisions.png")
        save(plot_path, fig_combined)
        @info "Combined L²-norm plot saved successfully" path=plot_path
    else
        @warn "No subdivision data available for plotting"
    end
catch e
    @warn "Combined plotting failed: $e"
    @warn "Full error details:" exception=(e, catch_backtrace())
end

# Generate summary table
@info "Generating subdivision analysis summary"
generate_subdivision_summary_table(all_subdivision_results)

# ================================================================================
# ANALYSIS INSIGHTS
# ================================================================================

@info "Generating subdivision analysis insights"

# Count successful analyses
successful_subdivisions = [label for (label, results) in all_subdivision_results if !isempty(results)]
converged_subdivisions = String[]

for (label, results) in all_subdivision_results
    if !isempty(results)
        if any([results[d].l2_norm <= L2_TOLERANCE_TIGHT for d in keys(results)])
            push!(converged_subdivisions, label)
        end
    end
end

@info "Subdivision analysis summary" total_subdivisions=16 successful_analyses=length(successful_subdivisions) converged_subdivisions=length(converged_subdivisions)

if !isempty(converged_subdivisions)
    @info "Converged subdivisions" labels=converged_subdivisions
else
    @warn "No subdivisions achieved L²-norm tolerance" tolerance=L2_TOLERANCE_TIGHT
end

# Find best performing subdivision
if !isempty(successful_subdivisions)
    local best_subdivision = ""
    local best_l2_norm = Inf
    
    for (label, results) in all_subdivision_results
        if !isempty(results)
            degrees = collect(keys(results))
            min_l2 = minimum([results[d].l2_norm for d in degrees])
            if min_l2 < best_l2_norm
                best_l2_norm = min_l2
                best_subdivision = label
            end
        end
    end
    
    @info "Best performing subdivision" label=best_subdivision l2_norm=@sprintf("%.2e", best_l2_norm)
end

total_runtime = sum([sum([results[d].runtime_seconds for d in keys(results)]) 
                    for (label, results) in all_subdivision_results if !isempty(results)])
@info "16-subdivision analysis complete" total_runtime=@sprintf("%.1f", total_runtime) output_directory=output_dir