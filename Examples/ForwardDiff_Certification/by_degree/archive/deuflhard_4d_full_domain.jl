# ================================================================================
# 4D Deuflhard - Full Domain Degree Convergence Analysis
# ================================================================================
# 
# Systematic degree sweep analysis on full [-1,1]^4 domain inspired by 
# Trefethen and Triple Graph notebook convergence patterns
#
# Objectives:
# - Replicate notebook L²-norm vs degree convergence plots for 4D case
# - Track local minimizer capture rates across polynomial degrees
# - Identify optimal degree/accuracy/computational cost tradeoffs
# - Validate tensor product critical point recovery in full domain
#
# Key Features:
# - Full domain analysis (no orthant subdivision)
# - Degree sweep from 2 to 10
# - Tight L²-norm tolerance (5e-5) for high-accuracy approximation
# - Comprehensive visualization suite
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
using GLMakie  # Interactive plotting backend

# ================================================================================
# PARAMETERS - FULL DOMAIN CONVERGENCE ANALYSIS
# ================================================================================

# Domain and approximation parameters
const DOMAIN_CENTER_4D = [0.0, 0.0, 0.0, 0.0]    # Center of [-1,1]^4 hypercube
const DOMAIN_RANGE_4D = 1.0                       # Half-width of domain ([-1,1]^4)
const L2_TOLERANCE_TIGHT = 5e-3                   # Tight L²-norm tolerance (from notebooks)
const DEGREE_MIN = 2                              # Starting polynomial degree  
const DEGREE_MAX = 10                            # Maximum degree to test
const DISTANCE_TOLERANCE = 0.05                   # Success threshold for critical point recovery

# Computational parameters
const SAMPLE_SCALING = 1.0                        # Automatic sampling scale factor
const BFGS_TOLERANCE = 1e-8                       # Local optimization tolerance
const MAX_RUNTIME_PER_DEGREE = 100               # Timeout per degree (100 seconds)

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
# THEORETICAL CRITICAL POINTS (TENSOR PRODUCTS)
# ================================================================================

"""
    load_theoretical_4d_points()

Load 2D Deuflhard critical points and generate all 4D tensor products.

# Returns
- `Tuple{Vector{Vector{Float64}}, Vector{Float64}, Vector{String}}`: 
  (theoretical_points_4d, theoretical_values_4d, theoretical_types)

# Description
Loads 2D critical points from CSV, classifies them using Hessian analysis,
then generates all N×N tensor product combinations for 4D reference points.
"""
function load_theoretical_4d_points()
    # Load 2D critical points from CSV
    csv_path = joinpath(@__DIR__, "../../../data/matlab_critical_points/valid_points_deuflhard.csv")
    
    if !isfile(csv_path)
        error("Critical points CSV file not found at: $csv_path")
    end
    
    csv_data = CSV.read(csv_path, DataFrame)
    critical_2d = [[row.x, row.y] for row in eachrow(csv_data)]
    
    @info "Loaded $(length(critical_2d)) 2D critical points from CSV"
    
    # Generate all N×N tensor products for 4D
    n_2d = length(critical_2d)
    theoretical_points_4d = Vector{Vector{Float64}}()
    theoretical_values_4d = Float64[]
    theoretical_types = String[]
    
    # Classify 2D points first
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
    
    # Generate 4D tensor products
    for (i, pt1) in enumerate(critical_2d)
        for (j, pt2) in enumerate(critical_2d)
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            value_4d = deuflhard_4d_composite(point_4d)
            type_4d = "$(critical_2d_types[i])+$(critical_2d_types[j])"
            
            push!(theoretical_points_4d, point_4d)
            push!(theoretical_values_4d, value_4d)
            push!(theoretical_types, type_4d)
        end
    end
    
    @info "Generated $(length(theoretical_points_4d)) theoretical 4D critical points ($(n_2d)×$(n_2d) tensor products)"
    
    return theoretical_points_4d, theoretical_values_4d, theoretical_types
end

# ================================================================================
# DEGREE ANALYSIS FUNCTIONS
# ================================================================================

"""
    analyze_single_degree(degree::Int, theoretical_points, theoretical_values, theoretical_types)

Analyze polynomial approximation and critical point recovery for a single degree.

# Arguments
- `degree`: Polynomial degree to test
- `theoretical_points`: Reference 4D critical points for validation
- `theoretical_values`: Function values at theoretical points
- `theoretical_types`: Classification of theoretical points (min+min, etc.)

# Returns
- `NamedTuple`: Comprehensive metrics including L²-norm, success rates, runtime

# Description
Constructs polynomial approximation at specified degree, solves for critical points,
and computes distance-based success metrics against theoretical reference points.
"""
function analyze_single_degree(degree::Int, theoretical_points, theoretical_values, theoretical_types)
    @info "Analyzing degree $degree"
    
    start_time = time()
    
    try
        # Create polynomial approximation on full domain
        TR = test_input(deuflhard_4d_composite, dim=4,
                       center=DOMAIN_CENTER_4D, sample_range=DOMAIN_RANGE_4D,
                       GN=20, reduce_samples=SAMPLE_SCALING)
        
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Handle both Tuple and Int degree types (from CLAUDE.md)
        actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
        
        # Solve polynomial system
        @polyvar x[1:4]
        solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
        df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR)
        
        # Extract critical points
        computed_points = Vector{Vector{Float64}}()
        computed_values = Float64[]
        
        if nrow(df_crit) > 0
            for i in 1:nrow(df_crit)
                point = [df_crit[i, Symbol("x$j")] for j in 1:4]
                # Filter points within domain
                if all(abs.(point) .<= DOMAIN_RANGE_4D * 1.1)  # Small tolerance for boundary
                    push!(computed_points, point)
                    push!(computed_values, df_crit[i, :z])
                end
            end
        end
        
        # Compute distances to theoretical points
        n_theoretical = length(theoretical_points)
        n_computed = length(computed_points)
        
        closest_distances = Float64[]
        if n_computed > 0
            for theoretical_pt in theoretical_points
                min_dist = minimum([norm(theoretical_pt - computed_pt) for computed_pt in computed_points])
                push!(closest_distances, min_dist)
            end
        else
            closest_distances = fill(Inf, n_theoretical)
        end
        
        # Success metrics
        successful_recoveries = sum(closest_distances .< DISTANCE_TOLERANCE)
        success_rate = successful_recoveries / n_theoretical
        
        # Min+min specific analysis
        min_min_indices = findall(x -> x == "min+min", theoretical_types)
        min_min_distances = closest_distances[min_min_indices]
        min_min_successes = sum(min_min_distances .< DISTANCE_TOLERANCE)
        min_min_success_rate = length(min_min_indices) > 0 ? min_min_successes / length(min_min_indices) : 0.0
        
        # Timing
        runtime = time() - start_time
        
        # Results summary
        results = (
            degree = actual_degree,
            l2_norm = pol.nrm,
            n_samples = try; pol.n_samples; catch; "unknown"; end,
            n_computed_points = n_computed,
            n_successful_recoveries = successful_recoveries,
            success_rate = success_rate,
            min_min_successes = min_min_successes,
            min_min_success_rate = min_min_success_rate,
            median_distance = n_computed > 0 ? median(closest_distances) : Inf,
            runtime_seconds = runtime,
            computed_points = computed_points,
            closest_distances = closest_distances
        )
        
        @info "Degree $degree completed" l2_norm=@sprintf("%.2e", pol.nrm) n_points=n_computed success_rate=@sprintf("%.1f%%", 100*success_rate) min_min_rate=@sprintf("%.1f%%", 100*min_min_success_rate) runtime=@sprintf("%.1f", runtime)
        
        return results
        
    catch e
        @error "Degree $degree analysis failed" exception=e
        # Return failure results
        return (
            degree = degree,
            l2_norm = Inf,
            n_samples = 0,
            n_computed_points = 0,
            n_successful_recoveries = 0,
            success_rate = 0.0,
            min_min_successes = 0,
            min_min_success_rate = 0.0,
            median_distance = Inf,
            runtime_seconds = time() - start_time,
            computed_points = Vector{Vector{Float64}}(),
            closest_distances = Float64[]
        )
    end
end

"""
    perform_degree_sweep(theoretical_points, theoretical_values, theoretical_types)

Perform full degree convergence analysis from DEGREE_MIN to DEGREE_MAX.

# Arguments
- `theoretical_points`: Reference 4D critical points for validation
- `theoretical_values`: Function values at theoretical points  
- `theoretical_types`: Classification of theoretical points

# Returns
- `Dict{Int, NamedTuple}`: Analysis results indexed by polynomial degree

# Description
Executes degree sweep analysis with early termination for excessive runtimes.
Provides comprehensive convergence tracking across polynomial degrees.
"""
function perform_degree_sweep(theoretical_points, theoretical_values, theoretical_types)
    @info "Starting 4D Deuflhard degree convergence analysis" domain="[-1,1]^4" degree_range="$DEGREE_MIN:$DEGREE_MAX" l2_tolerance=L2_TOLERANCE_TIGHT n_theoretical=length(theoretical_points)
    
    degree_results = Dict{Int, NamedTuple}()
    
    for degree in DEGREE_MIN:DEGREE_MAX
        result = analyze_single_degree(degree, theoretical_points, theoretical_values, theoretical_types)
        degree_results[degree] = result
        
        # Early termination if runtime becomes excessive
        if result.runtime_seconds > MAX_RUNTIME_PER_DEGREE
            @warn "Degree $degree exceeded maximum runtime, stopping analysis" max_runtime=MAX_RUNTIME_PER_DEGREE actual_runtime=result.runtime_seconds
            break
        end
        
        # Early termination if L²-norm tolerance is achieved
        if result.l2_norm <= L2_TOLERANCE_TIGHT
            @info "L²-norm tolerance achieved, stopping analysis" degree=degree l2_norm=result.l2_norm tolerance=L2_TOLERANCE_TIGHT
            break
        end
    end
    
    return degree_results
end

# ================================================================================
# VISUALIZATION FUNCTIONS (INSPIRED BY NOTEBOOKS)
# ================================================================================

"""
    plot_l2_convergence(degree_results)

Plot L²-norm vs degree convergence (replicates DeJong notebook pattern).
"""
function plot_l2_convergence(degree_results)
    degrees = sort(collect(keys(degree_results)))
    l2_norms = [degree_results[d].l2_norm for d in degrees]
    
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = "L²-Norm Convergence: 4D Deuflhard Full Domain",
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10
    )
    
    # Signature Globtim style: purple scatterlines (matching DeJong notebook)
    scatterlines!(ax, degrees, l2_norms, color = :purple, markersize = 8, linewidth = 2)
    hlines!(ax, [L2_TOLERANCE_TIGHT], color = :red, linestyle = :dash, linewidth = 2)
    
    # Add grid for better readability (matching notebook style)
    ax.xgridvisible = true
    ax.ygridvisible = true
    
    return fig
end

"""
    plot_recovery_rates(degree_results)

Plot critical point recovery rates vs degree (inspired by notebook patterns).
"""
function plot_recovery_rates(degree_results)
    degrees = sort(collect(keys(degree_results)))
    success_rates = [degree_results[d].success_rate * 100 for d in degrees]
    min_min_rates = [degree_results[d].min_min_success_rate * 100 for d in degrees]
    
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = "Critical Point Recovery Rates: 4D Deuflhard",
        xlabel = "Polynomial Degree",
        ylabel = "Success Rate (%)"
    )
    
    scatterlines!(ax, degrees, success_rates, color = :blue, markersize = 8, linewidth = 2)
    scatterlines!(ax, degrees, min_min_rates, color = :red, markersize = 8, linewidth = 2)
    
    hlines!(ax, [90], color = :gray, linestyle = :dash, alpha = 0.7)
    
    return fig
end

"""
    plot_computational_scaling(degree_results)

Plot runtime and sample count scaling vs degree.
"""
function plot_computational_scaling(degree_results)
    degrees = sort(collect(keys(degree_results)))
    runtimes = [degree_results[d].runtime_seconds for d in degrees]
    n_samples = [degree_results[d].n_samples for d in degrees if degree_results[d].n_samples != "unknown"]
    
    fig = Figure(size = (800, 400))
    
    # Runtime scaling
    ax1 = Axis(fig[1, 1],
        title = "Computational Scaling: Runtime",
        xlabel = "Polynomial Degree",
        ylabel = "Runtime (seconds)"
    )
    
    scatterlines!(ax1, degrees, runtimes, color = :orange, markersize = 8, linewidth = 2)
    
    # Sample count scaling (if available)
    if length(n_samples) > 0
        sample_degrees = degrees[1:length(n_samples)]
        ax2 = Axis(fig[1, 2],
            title = "Computational Scaling: Sample Count",
            xlabel = "Polynomial Degree",
            ylabel = "Number of Samples"
        )
        
        scatterlines!(ax2, sample_degrees, n_samples, color = :green, markersize = 8, linewidth = 2)
    end
    
    return fig
end

"""
    generate_convergence_summary_table(degree_results, theoretical_points, theoretical_types)

Generate comprehensive summary table of convergence results.

# Arguments
- `degree_results`: Dictionary of analysis results by degree
- `theoretical_points`: Reference critical points for validation  
- `theoretical_types`: Classification of theoretical points
"""
function generate_convergence_summary_table(degree_results, theoretical_points, theoretical_types)
    degrees = sort(collect(keys(degree_results)))
    
    # Prepare table data
    table_data = Matrix{Any}(undef, length(degrees), 8)
    
    for (i, degree) in enumerate(degrees)
        result = degree_results[degree]
        table_data[i, :] = [
            degree,
            @sprintf("%.2e", result.l2_norm),
            result.n_computed_points,
            @sprintf("%d/%d", result.n_successful_recoveries, length(theoretical_points)),
            @sprintf("%.1f%%", result.success_rate * 100),
            @sprintf("%d/%d", result.min_min_successes, sum(theoretical_types .== "min+min")),
            @sprintf("%.1f%%", result.min_min_success_rate * 100),
            @sprintf("%.1f", result.runtime_seconds)
        ]
    end
    
    headers = ["Degree", "L²-Norm", "Points Found", "Recoveries", "Success %", 
               "Min+Min Rec.", "Min+Min %", "Runtime(s)"]
    
    pretty_table(
        table_data,
        header = headers,
        alignment = [:c, :r, :c, :c, :r, :c, :r, :r],
        title = "4D Deuflhard Degree Convergence Analysis Summary"
    )
end

# ================================================================================
# MAIN EXECUTION
# ================================================================================

@info "Starting 4D Deuflhard Full Domain Degree Convergence Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")

# Load theoretical reference points
theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points()

# Perform degree sweep analysis
degree_results = perform_degree_sweep(theoretical_points, theoretical_values, theoretical_types)

# Generate visualizations
@info "Generating convergence visualization suite"

# Create output directory
output_dir = joinpath(@__DIR__, "outputs", "full_domain_$(Dates.format(now(), "yyyy-mm-dd_HH-MM"))")
mkpath(output_dir)
@info "Created output directory" path=output_dir

# Display convergence plots in windows
try
    @info "Displaying L²-norm convergence plot"
    fig1 = plot_l2_convergence(degree_results)
    display(fig1)
    
    @info "Displaying recovery rates plot"
    fig2 = plot_recovery_rates(degree_results)
    display(fig2)
    
    @info "All plots displayed successfully"
    
catch e
    @warn "Plotting failed: $e"
end

# Generate summary table
@info "Generating convergence analysis summary"

generate_convergence_summary_table(degree_results, theoretical_points, theoretical_types)

# ================================================================================
# ANALYSIS SUMMARY AND INSIGHTS
# ================================================================================

@info "Generating convergence analysis insights"

degrees = sort(collect(keys(degree_results)))
successful_degrees = [d for d in degrees if degree_results[d].l2_norm <= L2_TOLERANCE_TIGHT]
high_success_degrees = [d for d in degrees if degree_results[d].success_rate >= 0.8]

if !isempty(successful_degrees)
    @info "L²-norm tolerance achieved" tolerance=L2_TOLERANCE_TIGHT first_degree=minimum(successful_degrees)
else
    @warn "L²-norm tolerance not achieved in tested range" tolerance=L2_TOLERANCE_TIGHT degree_range="$DEGREE_MIN:$DEGREE_MAX"
end

if !isempty(high_success_degrees)
    @info "High success rate achieved" threshold="80%" first_degree=minimum(high_success_degrees)
else
    @warn "High success rate not achieved in tested range" threshold="80%" degree_range="$DEGREE_MIN:$DEGREE_MAX"
end

best_degree = degrees[argmin([degree_results[d].l2_norm for d in degrees])]
@info "Best approximation quality" degree=best_degree l2_norm=@sprintf("%.2e", degree_results[best_degree].l2_norm)

total_runtime = sum([degree_results[d].runtime_seconds for d in degrees])
@info "Analysis complete" total_runtime=@sprintf("%.1f", total_runtime) output_directory=output_dir