# ================================================================================
# Phase 2: Core Visualizations for Publication-Quality Convergence Analysis
# ================================================================================
#
# This file implements core visualization functions for systematic convergence
# analysis using the validated data structures from Phase 1. All plots are
# designed for publication quality with CairoMakie backend.
#
# Key Features:
# - Publication-ready static plots with 300+ DPI export capability
# - Comprehensive convergence dashboard with 4-panel layout
# - 16-orthant spatial heatmap analysis for 4D domain visualization
# - Multi-scale distance analysis with progressive zoom levels
# - Automated plot quality validation and styling framework
# - Integration with Phase 1 validated data structures

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))

# Core visualization packages
using CairoMakie
CairoMakie.activate!(type = "png")

# Data handling and analysis
using Statistics, LinearAlgebra, Printf
using DataFrames, Colors

# Include Phase 1 infrastructure
include("phase1_data_infrastructure.jl")

# ================================================================================
# PUBLICATION-QUALITY STYLING FRAMEWORK
# ================================================================================

"""
    create_publication_theme()

Create consistent styling theme for all publication plots.
Ensures professional appearance with appropriate fonts, colors, and sizing.
"""
function create_publication_theme()
    return Theme(
        fontsize = 14,
        Axis = (
            titlesize = 16,
            xlabelsize = 14,
            ylabelsize = 14,
            xticklabelsize = 12,
            yticklabelsize = 12,
            spinewidth = 1.5,
            xtickwidth = 1.0,
            ytickwidth = 1.0
        ),
        Legend = (
            titlesize = 14,
            labelsize = 12,
            framewidth = 1.0
        ),
        Colorbar = (
            labelsize = 12,
            ticklabelsize = 11
        ),
        figure_padding = (10, 10, 10, 10)
    )
end

"""
    create_publication_figure(; size = (1200, 800), dpi = 300)

Create publication-ready figure with proper sizing and DPI settings.
"""
function create_publication_figure(; size = (1200, 800), dpi = 300)
    set_theme!(create_publication_theme())
    fig = Figure(size = size, backgroundcolor = :white)
    return fig
end

"""
    save_publication_plot(fig::Figure, filename::String; dpi = 300)

Save publication plot with high DPI and proper formatting.
"""
function save_publication_plot(fig::Figure, filename::String; dpi = 300)
    save(filename, fig, px_per_unit = dpi/72)  # Convert DPI to px_per_unit
    @info "Publication plot saved: $filename ($(dpi) DPI)"
end

# Define color schemes for different plot types
const TOLERANCE_COLORMAP = :viridis
const POINT_TYPE_COLORS = Dict(
    "minimum" => :blue,
    "maximum" => :red, 
    "saddle" => :green,
    "degenerate" => :orange,
    "unknown" => :gray
)

const DISTANCE_TOLERANCE = 0.1  # Success threshold for distance comparisons

# ================================================================================
# CORE VISUALIZATION FUNCTIONS
# ================================================================================

"""
    plot_convergence_dashboard(results::MultiToleranceResults)

Create comprehensive 4-panel convergence dashboard showing key metrics vs tolerance.

# Arguments
- `results::MultiToleranceResults`: Validated multi-tolerance analysis results from Phase 1

# Returns
- `Figure`: Publication-ready 4-panel dashboard figure

# Panels
1. Success Rate Evolution: BFGS success rate vs L²-tolerance
2. Computational Requirements: Total sample count vs tolerance  
3. Polynomial Degree Adaptation: Average degree requirements vs tolerance
4. Approximation Quality: Median distance quality vs tolerance
"""
function plot_convergence_dashboard(results::MultiToleranceResults)
    @info "Generating convergence dashboard..." n_tolerances=length(results.tolerance_sequence)
    
    fig = create_publication_figure(size = (1400, 1000))
    
    # Extract tolerance sequence and corresponding data
    tolerances = results.tolerance_sequence
    
    # Extract metrics across all tolerance levels
    success_rates = [results.results_by_tolerance[tol].success_rates.bfgs * 100 for tol in tolerances]
    avg_degrees = [mean(results.results_by_tolerance[tol].polynomial_degrees) for tol in tolerances] 
    total_samples = [sum(results.results_by_tolerance[tol].sample_counts) for tol in tolerances]
    median_distances = [median(results.results_by_tolerance[tol].bfgs_distances) for tol in tolerances]
    
    # Panel 1: Success Rate Evolution
    ax1 = Axis(fig[1,1],
        title = "Success Rate Evolution",
        xlabel = "L²-norm Tolerance", 
        ylabel = "BFGS Success Rate (%)",
        xscale = log10
    )
    lines!(ax1, tolerances, success_rates, linewidth = 3, color = :blue)
    scatter!(ax1, tolerances, success_rates, marker = :circle, markersize = 8, color = :blue)
    ylims!(ax1, 0, 100)
    
    # Panel 2: Computational Requirements  
    ax2 = Axis(fig[1,2],
        title = "Computational Requirements",
        xlabel = "L²-norm Tolerance",
        ylabel = "Total Sample Count",
        xscale = log10, yscale = log10
    )
    lines!(ax2, tolerances, total_samples, linewidth = 3, color = :red)
    scatter!(ax2, tolerances, total_samples, marker = :rect, markersize = 8, color = :red)
    
    # Panel 3: Polynomial Degree Adaptation
    ax3 = Axis(fig[2,1],
        title = "Polynomial Degree Adaptation", 
        xlabel = "L²-norm Tolerance",
        ylabel = "Average Polynomial Degree",
        xscale = log10
    )
    lines!(ax3, tolerances, avg_degrees, linewidth = 3, color = :green)
    scatter!(ax3, tolerances, avg_degrees, marker = :diamond, markersize = 8, color = :green)
    
    # Panel 4: Approximation Quality
    ax4 = Axis(fig[2,2],
        title = "Approximation Quality",
        xlabel = "L²-norm Tolerance", 
        ylabel = "Median Log₁₀(Distance)",
        xscale = log10
    )
    lines!(ax4, tolerances, log10.(median_distances), linewidth = 3, color = :purple)
    scatter!(ax4, tolerances, log10.(median_distances), marker = :cross, markersize = 8, color = :purple)
    
    # Add reference lines where appropriate
    hlines!(ax1, [90], color = :gray, linestyle = :dash, alpha = 0.7, label = "90% Target")
    hlines!(ax4, [log10(DISTANCE_TOLERANCE)], color = :gray, linestyle = :dash, alpha = 0.7, 
            label = "Distance Tolerance")
    
    # Add figure title
    fig[0, :] = Label(fig, "4D Deuflhard Convergence Analysis Dashboard", fontsize = 18, font = :bold)
    
    @info "Convergence dashboard generated successfully"
    return fig
end

"""
    plot_orthant_heatmap(orthant_data::Vector{OrthantResult}, metric::Symbol = :success_rate)

Create 4×4 heatmap visualization of 16-orthant performance for 4D spatial analysis.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Orthant analysis results (must have exactly 16 entries)
- `metric::Symbol`: Metric to visualize (:success_rate, :median_distance, :polynomial_degree, :computation_time)

# Returns
- `Figure`: Publication-ready orthant heatmap figure
"""
function plot_orthant_heatmap(orthant_data::Vector{OrthantResult}, metric::Symbol = :success_rate)
    @assert length(orthant_data) == 16 "Must have exactly 16 orthant results for 4D analysis"
    
    @info "Generating orthant heatmap for metric: $metric"
    
    fig = create_publication_figure(size = (800, 700))
    
    # Extract metric values and reshape to 4×4 grid
    metric_values = [getfield(result, metric) for result in orthant_data]
    orthant_matrix = reshape(metric_values, 4, 4)
    
    # Create axis with appropriate titles and labels
    metric_title = replace(string(metric), "_" => " ") |> titlecase
    ax = Axis(fig[1,1],
        title = "4D Orthant Analysis: $metric_title",
        xlabel = "Orthant Grid Column",
        ylabel = "Orthant Grid Row",
        aspect = 1
    )
    
    # Create heatmap
    hm = heatmap!(ax, orthant_matrix, colormap = TOLERANCE_COLORMAP)
    
    # Add text annotations with metric values
    for i in 1:4, j in 1:4
        value = orthant_matrix[i, j]
        # Format value appropriately based on metric type
        if metric == :success_rate
            text_val = @sprintf("%.1f%%", value * 100)
        elseif metric == :median_distance
            text_val = @sprintf("%.2e", value)
        elseif metric == :polynomial_degree
            text_val = @sprintf("%.0f", value)
        elseif metric == :computation_time
            text_val = @sprintf("%.1fs", value)
        else
            text_val = @sprintf("%.3f", value)
        end
        
        text!(ax, j, i, text = text_val, align = (:center, :center),
              color = value > median(metric_values) ? :white : :black,
              fontsize = 10, font = :bold)
    end
    
    # Add colorbar with appropriate label
    colorbar_label = metric == :success_rate ? "Success Rate" :
                    metric == :median_distance ? "Median Distance" :
                    metric == :polynomial_degree ? "Polynomial Degree" :
                    metric == :computation_time ? "Computation Time (s)" :
                    string(metric)
    
    Colorbar(fig[1,2], hm, label = colorbar_label)
    
    @info "Orthant heatmap generated successfully" metric=metric
    return fig
end

"""
    plot_orthant_analysis_suite(orthant_data::Vector{OrthantResult})

Generate complete suite of orthant heatmaps for all key metrics.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Orthant analysis results

# Returns
- `Vector{Figure}`: Collection of heatmap figures for different metrics
"""
function plot_orthant_analysis_suite(orthant_data::Vector{OrthantResult})
    @info "Generating complete orthant analysis suite..."
    
    metrics = [:success_rate, :median_distance, :polynomial_degree, :computation_time]
    figures = Figure[]
    
    for metric in metrics
        fig = plot_orthant_heatmap(orthant_data, metric)
        push!(figures, fig)
    end
    
    @info "Orthant analysis suite completed" n_figures=length(figures)
    return figures
end

"""
    plot_multiscale_distance_analysis(tolerance_result::ToleranceResult)

Create multi-scale distance analysis with progressive zoom from failures to ultra-precision.

# Arguments
- `tolerance_result::ToleranceResult`: Single tolerance level results

# Returns
- `Figure`: Publication-ready multi-scale distance analysis figure
"""
function plot_multiscale_distance_analysis(tolerance_result::ToleranceResult)
    @info "Generating multi-scale distance analysis..." n_points=length(tolerance_result.bfgs_distances)
    
    fig = create_publication_figure(size = (1500, 500))
    
    distances = tolerance_result.bfgs_distances
    point_types = tolerance_result.point_types
    
    if isempty(distances)
        @warn "No distance data available for multi-scale analysis"
        # Create empty figure with warning message
        ax = Axis(fig[1,1], title = "No Data Available")
        text!(ax, 0.5, 0.5, text = "No distance data available", align = (:center, :center))
        return fig
    end
    
    # Remove NaN values for visualization
    valid_indices = findall(!isnan, distances)
    valid_distances = distances[valid_indices]
    valid_types = point_types[valid_indices]
    
    if isempty(valid_distances)
        @warn "No valid distance data (all NaN) for multi-scale analysis"
        ax = Axis(fig[1,1], title = "No Valid Data")
        text!(ax, 0.5, 0.5, text = "All distance values are NaN", align = (:center, :center))
        return fig
    end
    
    # Scale 1: Full range overview
    ax1 = Axis(fig[1,1],
        title = "Full Distance Range",
        xlabel = "Point Index",
        ylabel = "Log₁₀(Distance)",
        yscale = log10
    )
    
    # Color points by type
    colors = [get(POINT_TYPE_COLORS, ptype, :gray) for ptype in valid_types]
    scatter!(ax1, 1:length(valid_distances), valid_distances,
             color = colors, markersize = 6, alpha = 0.7)
    
    # Add tolerance reference line
    if DISTANCE_TOLERANCE < maximum(valid_distances)
        hlines!(ax1, [DISTANCE_TOLERANCE], color = :red, linestyle = :dash, 
                linewidth = 2, label = "Success Threshold")
    end
    
    # Scale 2: Success region zoom (points below tolerance)
    success_mask = valid_distances .< DISTANCE_TOLERANCE
    success_distances = valid_distances[success_mask]
    success_types = valid_types[success_mask]
    
    ax2 = Axis(fig[1,2],
        title = "Success Region (< $(DISTANCE_TOLERANCE))",
        xlabel = "Successful Point Index", 
        ylabel = "Log₁₀(Distance)",
        yscale = log10
    )
    
    if !isempty(success_distances)
        success_colors = [get(POINT_TYPE_COLORS, ptype, :gray) for ptype in success_types]
        scatter!(ax2, 1:length(success_distances), success_distances,
                 color = success_colors, markersize = 8, alpha = 0.8)
    else
        text!(ax2, 0.5, 0.5, text = "No successful points", align = (:center, :center))
    end
    
    # Scale 3: Ultra-precision zoom (points with very high accuracy)
    ultra_threshold = 1e-8
    ultra_mask = valid_distances .< ultra_threshold
    ultra_distances = valid_distances[ultra_mask]
    ultra_types = valid_types[ultra_mask]
    
    ax3 = Axis(fig[1,3],
        title = "Ultra-Precision (< 1e-8)",
        xlabel = "Ultra-Precise Point Index",
        ylabel = "Log₁₀(Distance)", 
        yscale = log10
    )
    
    if !isempty(ultra_distances)
        ultra_colors = [get(POINT_TYPE_COLORS, ptype, :gray) for ptype in ultra_types]
        scatter!(ax3, 1:length(ultra_distances), ultra_distances,
                 color = ultra_colors, markersize = 10)
    else
        text!(ax3, 0.5, 0.5, text = "No ultra-precise points", align = (:center, :center))
    end
    
    # Add shared legend
    legend_elements = [MarkerElement(color = color, marker = :circle, markersize = 12) 
                      for (type, color) in POINT_TYPE_COLORS if type in valid_types]
    legend_labels = [titlecase(type) for type in keys(POINT_TYPE_COLORS) if type in valid_types]
    
    if !isempty(legend_elements)
        Legend(fig[1,4], legend_elements, legend_labels, "Point Types", 
               framevisible = true, backgroundcolor = :white)
    end
    
    # Add overall title
    fig[0, :] = Label(fig, "Multi-Scale Distance Analysis: L²-tolerance = $(tolerance_result.tolerance)", 
                     fontsize = 16, font = :bold)
    
    @info "Multi-scale distance analysis completed" n_valid_points=length(valid_distances) n_success=length(success_distances) n_ultra=length(ultra_distances)
    return fig
end

"""
    plot_point_type_performance(results::MultiToleranceResults)

Create point type stratified analysis showing convergence behavior across different critical point types.

# Arguments  
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `Figure`: Publication-ready point type performance comparison figure
"""
function plot_point_type_performance(results::MultiToleranceResults)
    @info "Generating point type performance analysis..."
    
    fig = create_publication_figure(size = (1200, 800))
    
    tolerances = results.tolerance_sequence
    
    # Get all unique point types across all tolerance levels
    all_point_types = Set{String}()
    for tol in tolerances
        union!(all_point_types, results.results_by_tolerance[tol].point_types)
    end
    
    # Filter out unknown types and sort
    point_types = sort(collect(filter(t -> t != "unknown", all_point_types)))
    
    if isempty(point_types)
        @warn "No valid point types found for performance analysis"
        ax = Axis(fig[1,1], title = "No Valid Point Types")
        text!(ax, 0.5, 0.5, text = "No valid point types found", align = (:center, :center))
        return fig
    end
    
    # Create subplot layout
    n_types = length(point_types)
    n_cols = min(3, n_types)
    n_rows = ceil(Int, n_types / n_cols)
    
    for (i, ptype) in enumerate(point_types)
        row = div(i-1, n_cols) + 1
        col = mod(i-1, n_cols) + 1
        
        ax = Axis(fig[row, col],
            title = "$(titlecase(ptype)) Points",
            xlabel = "L²-norm Tolerance",
            ylabel = "Success Rate (%)",
            xscale = log10
        )
        
        # Extract success rates for this point type across tolerances
        success_rates = Float64[]
        point_counts = Int[]
        
        for tol in tolerances
            tol_result = results.results_by_tolerance[tol]
            type_mask = tol_result.point_types .== ptype
            
            if any(type_mask)
                type_distances = tol_result.bfgs_distances[type_mask]
                # Remove NaN values for success rate calculation
                valid_distances = filter(!isnan, type_distances)
                
                if !isempty(valid_distances)
                    success_rate = sum(valid_distances .< DISTANCE_TOLERANCE) / length(valid_distances) * 100
                    push!(success_rates, success_rate)
                    push!(point_counts, length(valid_distances))
                else
                    push!(success_rates, 0.0)
                    push!(point_counts, 0)
                end
            else
                push!(success_rates, 0.0)
                push!(point_counts, 0)
            end
        end
        
        # Plot success rate evolution
        color = get(POINT_TYPE_COLORS, ptype, :blue)
        lines!(ax, tolerances, success_rates, linewidth = 3, color = color)
        scatter!(ax, tolerances, success_rates, marker = :circle, markersize = 8, color = color)
        
        # Set limits and add reference line
        ylims!(ax, 0, 100)
        hlines!(ax, [90], color = :gray, linestyle = :dash, alpha = 0.5)
        
        # Add point count annotations
        for (j, (tol, count)) in enumerate(zip(tolerances, point_counts))
            if count > 0
                text!(ax, tol, success_rates[j] + 5, text = "n=$count", 
                     fontsize = 8, align = (:center, :bottom))
            end
        end
    end
    
    # Add overall title
    fig[0, :] = Label(fig, "Point Type Performance Analysis", fontsize = 18, font = :bold)
    
    @info "Point type performance analysis completed" n_types=length(point_types)
    return fig
end

"""
    plot_efficiency_frontier(results::MultiToleranceResults)

Create efficiency frontier analysis showing accuracy vs computational cost trade-offs.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns  
- `Figure`: Publication-ready efficiency frontier figure
"""
function plot_efficiency_frontier(results::MultiToleranceResults)
    @info "Generating efficiency frontier analysis..."
    
    fig = create_publication_figure(size = (900, 700))
    
    tolerances = results.tolerance_sequence
    
    # Extract cost and quality metrics
    total_samples = [sum(results.results_by_tolerance[tol].sample_counts) for tol in tolerances]
    computation_times = [results.results_by_tolerance[tol].computation_time for tol in tolerances]
    
    # Quality metrics (lower is better for distances)
    median_distances = Float64[]
    for tol in tolerances
        distances = results.results_by_tolerance[tol].bfgs_distances
        valid_distances = filter(!isnan, distances)
        if !isempty(valid_distances)
            push!(median_distances, median(valid_distances))
        else
            push!(median_distances, NaN)
        end
    end
    
    # Remove entries with NaN distances
    valid_indices = findall(!isnan, median_distances)
    if isempty(valid_indices)
        @warn "No valid distance data for efficiency frontier"
        ax = Axis(fig[1,1], title = "No Valid Data")
        text!(ax, 0.5, 0.5, text = "No valid distance data available", align = (:center, :center))
        return fig
    end
    
    valid_tolerances = tolerances[valid_indices]
    valid_samples = total_samples[valid_indices] 
    valid_distances = median_distances[valid_indices]
    valid_times = computation_times[valid_indices]
    
    # Main efficiency plot: Sample count vs Distance quality
    ax = Axis(fig[1,1],
        title = "Efficiency Frontier: Accuracy vs Computational Cost",
        xlabel = "Total Sample Count",
        ylabel = "Median Log₁₀(Distance)",
        xscale = log10
    )
    
    # Color points by tolerance level
    tolerance_colors = log10.(valid_tolerances)
    scatter!(ax, valid_samples, log10.(valid_distances),
             color = tolerance_colors, colormap = :plasma, markersize = 15,
             strokewidth = 1, strokecolor = :black)
    
    # Connect points to show progression
    lines!(ax, valid_samples, log10.(valid_distances), 
           color = :gray, alpha = 0.6, linewidth = 2)
    
    # Add tolerance labels
    for (i, tol) in enumerate(valid_tolerances)
        text!(ax, valid_samples[i], log10(valid_distances[i]),
              text = string(tol), offset = (8, 8), fontsize = 10,
              color = :black, font = :bold)
    end
    
    # Add reference lines
    hlines!(ax, [log10(DISTANCE_TOLERANCE)], color = :red, linestyle = :dash,
            label = "Distance Tolerance", linewidth = 2)
    
    # Add colorbar for tolerance values
    Colorbar(fig[1,2], limits = extrema(tolerance_colors), 
             colormap = :plasma, label = "Log₁₀(L²-tolerance)")
    
    @info "Efficiency frontier analysis completed" n_points=length(valid_indices)
    return fig
end

# ================================================================================
# INTEGRATED VISUALIZATION SUITE
# ================================================================================

"""
    generate_publication_suite(results::MultiToleranceResults; 
                               export_path::String = "./publication_plots",
                               export_formats::Vector{String} = ["png"])

Generate complete publication-ready visualization suite.

# Arguments
- `results::MultiToleranceResults`: Validated multi-tolerance analysis results
- `export_path::String`: Directory for saving plots  
- `export_formats::Vector{String}`: File formats for export (["png", "pdf", "svg"])

# Returns
- `NamedTuple`: Collection of all generated figures
"""
function generate_publication_suite(results::MultiToleranceResults;
                                   export_path::String = "./publication_plots", 
                                   export_formats::Vector{String} = ["png"])
    @info "Generating complete publication visualization suite..." export_path=export_path
    
    # Create export directory
    mkpath(export_path)
    
    # Generate all visualizations
    @info "Creating convergence dashboard..."
    dashboard_fig = plot_convergence_dashboard(results)
    
    @info "Creating point type performance analysis..."
    point_type_fig = plot_point_type_performance(results)
    
    @info "Creating efficiency frontier analysis..."
    efficiency_fig = plot_efficiency_frontier(results)
    
    # Generate orthant analysis for tightest tolerance
    tightest_tolerance = minimum(results.tolerance_sequence)
    @info "Creating orthant analysis suite for tolerance $tightest_tolerance..."
    orthant_figs = plot_orthant_analysis_suite(results.results_by_tolerance[tightest_tolerance].orthant_data)
    
    # Generate multi-scale distance analysis for tightest tolerance
    @info "Creating multi-scale distance analysis..."
    multiscale_fig = plot_multiscale_distance_analysis(results.results_by_tolerance[tightest_tolerance])
    
    # Export all figures
    figures = [
        ("convergence_dashboard", dashboard_fig),
        ("point_type_performance", point_type_fig), 
        ("efficiency_frontier", efficiency_fig),
        ("multiscale_distance_analysis", multiscale_fig)
    ]
    
    # Add orthant figures
    orthant_metrics = [:success_rate, :median_distance, :polynomial_degree, :computation_time]
    for (i, metric) in enumerate(orthant_metrics)
        push!(figures, ("orthant_$(metric)_heatmap", orthant_figs[i]))
    end
    
    # Export in requested formats
    for format in export_formats
        @info "Exporting figures in $format format..."
        for (name, fig) in figures
            filename = joinpath(export_path, "$(name).$(format)")
            if format == "png"
                save_publication_plot(fig, filename, dpi = 300)
            else
                save(filename, fig)
                @info "Plot saved: $filename"
            end
        end
    end
    
    @info "Publication suite generation completed" n_figures=length(figures) export_path=export_path
    
    return (
        dashboard = dashboard_fig,
        point_type_performance = point_type_fig,
        efficiency_frontier = efficiency_fig,
        multiscale_distance = multiscale_fig,
        orthant_suite = orthant_figs
    )
end

"""
    validate_plot_quality(fig::Figure)

Validate plot meets publication quality standards.

# Arguments
- `fig::Figure`: Figure to validate

# Returns
- `Bool`: True if plot meets quality standards
- `Vector{String}`: List of quality issues (empty if no issues)
"""
function validate_plot_quality(fig::Figure)
    issues = String[]
    
    # Check figure size
    if fig.scene.viewport[].widths[1] < 600 || fig.scene.viewport[].widths[2] < 400
        push!(issues, "Figure size too small for publication (minimum 600x400)")
    end
    
    # Additional quality checks can be added here
    # - Font size validation
    # - Color accessibility
    # - Legend presence
    # - Axis label completeness
    
    is_valid = isempty(issues)
    
    if is_valid
        @info "Plot quality validation passed"
    else
        @warn "Plot quality issues detected" issues=issues
    end
    
    return is_valid, issues
end

# Export main functions
export plot_convergence_dashboard, plot_orthant_heatmap, plot_orthant_analysis_suite
export plot_multiscale_distance_analysis, plot_point_type_performance, plot_efficiency_frontier
export generate_publication_suite, validate_plot_quality
export create_publication_figure, save_publication_plot, create_publication_theme