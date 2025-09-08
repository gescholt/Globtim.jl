"""
    VisualizationFramework.jl

Extensible visualization framework for GlobTim analysis and plotting capabilities.
Implements Issue #67: Prepare visualization framework for future plotting capabilities.

This module provides:
- Abstract plotting interfaces that work without plotting dependencies
- Data preparation functions for visualization
- Plugin-style architecture for different plot types
- Graceful degradation when plotting packages unavailable
- Integration points for CairoMakie/GLMakie

Design Principles:
- Clean separation between data processing and visualization
- Extensible architecture for adding new plot types
- Optional plotting with graceful degradation
- Integration with existing PostProcessing metrics

Author: GlobTim Team
Date: September 2025
"""
module VisualizationFramework

using LinearAlgebra
using Statistics
using DataFrames

# Optional plotting dependencies with graceful fallback
const PLOTTING_AVAILABLE = try
    using CairoMakie
    using GLMakie
    true
catch
    false
end

export AbstractVisualizationConfig, AbstractPlotData, AbstractPlotRenderer
export L2DegreeAnalysisData, ParameterSpaceData, ConvergenceTrajectoryData
export prepare_l2_degree_plot_data, prepare_parameter_space_data, prepare_convergence_data
export register_plot_renderer!, get_available_renderers, render_plot
export VisualizationRegistry, PlotConfig

# Helper functions for formatting (avoid Printf dependency)
format_scientific(x::Real) = string(round(x, sigdigits=3, base=10))
format_float(x::Real) = string(round(x, digits=3))
format_percent(x::Real) = string(round(x, digits=2))

"""
    AbstractVisualizationConfig

Base type for all visualization configuration objects.
Subtype this to create specific configuration for different plot types.
"""
abstract type AbstractVisualizationConfig end

"""
    AbstractPlotData

Base type for all plot data containers.
Contains preprocessed data ready for visualization.
"""
abstract type AbstractPlotData end

"""
    AbstractPlotRenderer

Base type for all plot rendering implementations.
Implement render_plot method for specific rendering backends.
"""
abstract type AbstractPlotRenderer end

"""
    PlotConfig

General configuration for plot appearance and behavior.
"""
struct PlotConfig <: AbstractVisualizationConfig
    # Figure settings
    figure_size::Tuple{Int,Int}
    title::String
    save_path::Union{String,Nothing}
    
    # Style settings
    color_scheme::Symbol
    line_width::Float64
    marker_size::Float64
    transparency::Float64
    
    # Layout settings
    show_legend::Bool
    legend_position::Symbol
    axis_labels::Bool
    grid::Bool
    
    function PlotConfig(;
        figure_size = (1200, 800),
        title = "",
        save_path = nothing,
        color_scheme = :viridis,
        line_width = 2.0,
        marker_size = 8.0,
        transparency = 0.7,
        show_legend = true,
        legend_position = :rt,
        axis_labels = true,
        grid = true
    )
        new(figure_size, title, save_path, color_scheme, line_width, marker_size,
            transparency, show_legend, legend_position, axis_labels, grid)
    end
end

# =============================================================================
# Specialized Plot Data Types
# =============================================================================

"""
    L2DegreeAnalysisData

Data container for L2-norm vs polynomial degree analysis plots.
"""
struct L2DegreeAnalysisData <: AbstractPlotData
    degrees::Vector{Float64}
    l2_norms::Vector{Float64}
    dimensions::Vector{Int}
    condition_numbers::Vector{Float64}
    sample_counts::Vector{Int}
    metadata::Dict{String,Any}
    
    # Quality thresholds for visualization
    excellent_threshold::Float64
    good_threshold::Float64
    acceptable_threshold::Float64
    
    function L2DegreeAnalysisData(degrees, l2_norms, dimensions, condition_numbers, sample_counts;
                                 metadata = Dict{String,Any}(),
                                 excellent_threshold = 1e-10,
                                 good_threshold = 1e-6,
                                 acceptable_threshold = 1e-3)
        new(degrees, l2_norms, dimensions, condition_numbers, sample_counts, metadata,
            excellent_threshold, good_threshold, acceptable_threshold)
    end
end

"""
    ParameterSpaceData

Data container for parameter space visualization plots.
"""
struct ParameterSpaceData <: AbstractPlotData
    points::Matrix{Float64}  # N x D matrix of parameter points
    function_values::Vector{Float64}
    dimension_labels::Vector{String}
    bounds::Vector{Tuple{Float64,Float64}}  # bounds for each dimension
    metadata::Dict{String,Any}
    
    function ParameterSpaceData(points, function_values;
                               dimension_labels = ["x$i" for i in 1:size(points,2)],
                               bounds = [(minimum(points[:,i]), maximum(points[:,i])) for i in 1:size(points,2)],
                               metadata = Dict{String,Any}())
        new(points, function_values, dimension_labels, bounds, metadata)
    end
end

"""
    ConvergenceTrajectoryData

Data container for convergence trajectory visualization.
"""
struct ConvergenceTrajectoryData <: AbstractPlotData
    trajectories::Dict{String,Matrix{Float64}}  # algorithm_name => positions
    function_values::Dict{String,Vector{Float64}}
    algorithm_names::Vector{String}
    colors::Vector{Symbol}
    metadata::Dict{String,Any}
    
    function ConvergenceTrajectoryData(trajectories, function_values;
                                      algorithm_names = collect(keys(trajectories)),
                                      colors = [:blue, :red, :green, :purple, :orange][1:length(trajectories)],
                                      metadata = Dict{String,Any}())
        new(trajectories, function_values, algorithm_names, colors, metadata)
    end
end

# =============================================================================
# Data Preparation Functions (work without plotting dependencies)
# =============================================================================

"""
    prepare_l2_degree_plot_data(experiment_results::Vector) -> L2DegreeAnalysisData

Prepare data for L2-norm vs polynomial degree plots from experiment results.
Works with results from PostProcessing.ExperimentResults or raw dictionaries.
"""
function prepare_l2_degree_plot_data(experiment_results::Vector)
    degrees = Float64[]
    l2_norms = Float64[]
    dimensions = Int[]
    condition_numbers = Float64[]
    sample_counts = Int[]
    
    for result in experiment_results
        # Handle both PostProcessing.ExperimentResults and raw dictionaries
        metadata = if hasfield(typeof(result), :metadata)
            result.metadata
        else
            result
        end
        
        # Extract required fields
        if haskey(metadata, "degree") && haskey(metadata, "L2_norm")
            push!(degrees, Float64(metadata["degree"]))
            push!(l2_norms, Float64(metadata["L2_norm"]))
            
            # Optional fields with defaults
            push!(dimensions, get(metadata, "dimension", 2))
            push!(condition_numbers, get(metadata, "condition_number", NaN))
            push!(sample_counts, get(metadata, "total_samples", 0))
        end
    end
    
    # Validate data
    if isempty(degrees)
        error("No valid degree/L2_norm data found in experiment results")
    end
    
    # Create analysis metadata
    analysis_metadata = Dict{String,Any}(
        "num_experiments" => length(degrees),
        "degree_range" => (minimum(degrees), maximum(degrees)),
        "l2_norm_range" => (minimum(l2_norms), maximum(l2_norms)),
        "unique_dimensions" => unique(dimensions),
        "mean_condition_number" => mean(filter(!isnan, condition_numbers))
    )
    
    return L2DegreeAnalysisData(degrees, l2_norms, dimensions, condition_numbers, 
                               sample_counts, metadata=analysis_metadata)
end

"""
    prepare_parameter_space_data(points::Matrix{Float64}, function_values::Vector{Float64}) -> ParameterSpaceData

Prepare data for parameter space visualization from raw point data.
"""
function prepare_parameter_space_data(points::Matrix{Float64}, function_values::Vector{Float64};
                                     dimension_labels::Union{Vector{String},Nothing}=nothing)
    if size(points, 1) != length(function_values)
        error("Number of points must match number of function values")
    end
    
    n_dims = size(points, 2)
    
    # Generate default labels if not provided
    if dimension_labels === nothing
        dimension_labels = ["x$i" for i in 1:n_dims]
    end
    
    # Compute bounds for each dimension
    bounds = [(minimum(points[:,i]), maximum(points[:,i])) for i in 1:n_dims]
    
    # Analysis metadata
    metadata = Dict{String,Any}(
        "num_points" => size(points, 1),
        "num_dimensions" => n_dims,
        "function_value_range" => (minimum(function_values), maximum(function_values)),
        "function_value_mean" => mean(function_values),
        "function_value_std" => std(function_values)
    )
    
    return ParameterSpaceData(points, function_values,
                             dimension_labels=dimension_labels,
                             bounds=bounds,
                             metadata=metadata)
end

"""
    prepare_convergence_data(algorithm_trackers::Dict{String, Any}) -> ConvergenceTrajectoryData

Prepare convergence trajectory data from algorithm tracking results.
Compatible with InteractiveVizCore.AlgorithmTracker or similar structures.
"""
function prepare_convergence_data(algorithm_trackers::Dict{String, Any})
    trajectories = Dict{String,Matrix{Float64}}()
    function_values = Dict{String,Vector{Float64}}()
    algorithm_names = String[]
    colors = Symbol[]
    
    default_colors = [:blue, :red, :green, :purple, :orange, :cyan, :magenta, :yellow]
    
    for (i, (name, tracker)) in enumerate(algorithm_trackers)
        push!(algorithm_names, name)
        
        # Extract positions (handle different data structures)
        positions = if hasfield(typeof(tracker), :positions)
            tracker.positions
        elseif haskey(tracker, "positions")
            tracker["positions"]
        else
            error("No position data found for algorithm: $name")
        end
        
        # Convert to matrix format (N_points x N_dims)
        if !isempty(positions)
            trajectory_matrix = hcat(positions...)'  # Transpose to get N_points x N_dims
            trajectories[name] = trajectory_matrix
        end
        
        # Extract function values
        values = if hasfield(typeof(tracker), :function_values)
            tracker.function_values
        elseif haskey(tracker, "function_values")
            tracker["function_values"]
        else
            Float64[]  # No function values available
        end
        function_values[name] = values
        
        # Assign colors
        color = if hasfield(typeof(tracker), :color)
            tracker.color
        else
            default_colors[mod1(i, length(default_colors))]
        end
        push!(colors, color)
    end
    
    metadata = Dict{String,Any}(
        "num_algorithms" => length(algorithm_names),
        "total_points" => sum(size(traj, 1) for traj in values(trajectories))
    )
    
    return ConvergenceTrajectoryData(trajectories, function_values,
                                   algorithm_names=algorithm_names,
                                   colors=colors,
                                   metadata=metadata)
end

# =============================================================================
# Plugin Architecture for Plot Renderers
# =============================================================================

"""
    VisualizationRegistry

Global registry for plot renderers. Allows different backends (CairoMakie, GLMakie, etc.)
to register their rendering implementations.
"""
mutable struct VisualizationRegistry
    renderers::Dict{Type{<:AbstractPlotData}, Vector{AbstractPlotRenderer}}
    default_renderer::Dict{Type{<:AbstractPlotData}, AbstractPlotRenderer}
    
    function VisualizationRegistry()
        new(Dict{Type{<:AbstractPlotData}, Vector{AbstractPlotRenderer}}(),
            Dict{Type{<:AbstractPlotData}, AbstractPlotRenderer}())
    end
end

# Global registry instance
const VISUALIZATION_REGISTRY = VisualizationRegistry()

"""
    register_plot_renderer!(data_type::Type{<:AbstractPlotData}, renderer::AbstractPlotRenderer; 
                           set_default::Bool=false)

Register a plot renderer for a specific data type.
"""
function register_plot_renderer!(data_type::Type{<:AbstractPlotData}, 
                                renderer::AbstractPlotRenderer; 
                                set_default::Bool=false)
    if !haskey(VISUALIZATION_REGISTRY.renderers, data_type)
        VISUALIZATION_REGISTRY.renderers[data_type] = AbstractPlotRenderer[]
    end
    
    push!(VISUALIZATION_REGISTRY.renderers[data_type], renderer)
    
    if set_default || !haskey(VISUALIZATION_REGISTRY.default_renderer, data_type)
        VISUALIZATION_REGISTRY.default_renderer[data_type] = renderer
    end
    
    println("Registered $(typeof(renderer)) for $(data_type)")
end

"""
    get_available_renderers(data_type::Type{<:AbstractPlotData}) -> Vector{AbstractPlotRenderer}

Get all available renderers for a specific data type.
"""
function get_available_renderers(data_type::Type{<:AbstractPlotData})
    return get(VISUALIZATION_REGISTRY.renderers, data_type, AbstractPlotRenderer[])
end

"""
    render_plot(data::AbstractPlotData, config::AbstractVisualizationConfig; 
               renderer::Union{AbstractPlotRenderer,Nothing}=nothing)

Render a plot using the appropriate renderer. Falls back gracefully if no renderer available.
"""
function render_plot(data::AbstractPlotData, config::AbstractVisualizationConfig; 
                    renderer::Union{AbstractPlotRenderer,Nothing}=nothing)
    data_type = typeof(data)
    
    # Determine renderer to use
    if renderer !== nothing
        selected_renderer = renderer
    elseif haskey(VISUALIZATION_REGISTRY.default_renderer, data_type)
        selected_renderer = VISUALIZATION_REGISTRY.default_renderer[data_type]
    else
        # Graceful fallback: print data summary instead of plotting
        return fallback_render(data, config)
    end
    
    try
        return render_plot(selected_renderer, data, config)
    catch e
        println("❌ Plotting failed: $e")
        return fallback_render(data, config)
    end
end

"""
    fallback_render(data::AbstractPlotData, config::AbstractVisualizationConfig)

Fallback rendering that provides textual analysis when plotting is unavailable.
"""
function fallback_render(data::AbstractPlotData, config::AbstractVisualizationConfig)
    println("📊 Plot Visualization (Text Mode - Plotting packages unavailable)")
    println("=" ^ 60)
    println("Plot Type: $(typeof(data))")
    println("Configuration: $(typeof(config))")
    
    if isa(data, L2DegreeAnalysisData)
        render_l2_degree_text(data)
    elseif isa(data, ParameterSpaceData) 
        render_parameter_space_text(data)
    elseif isa(data, ConvergenceTrajectoryData)
        render_convergence_text(data)
    else
        println("Data summary:")
        for field in fieldnames(typeof(data))
            value = getfield(data, field)
            println("  $field: $(summary(value))")
        end
    end
    
    return nothing
end

function render_l2_degree_text(data::L2DegreeAnalysisData)
    println("\n📈 L2-Norm vs Polynomial Degree Analysis")
    println("Experiments: $(length(data.degrees))")
    println("Degree Range: $(minimum(data.degrees)) - $(maximum(data.degrees))")
    println("L2-Norm Range: $(format_scientific(minimum(data.l2_norms))) - $(format_scientific(maximum(data.l2_norms)))")
    
    # Quality distribution
    excellent = sum(data.l2_norms .< data.excellent_threshold)
    good = sum((data.l2_norms .>= data.excellent_threshold) .& (data.l2_norms .< data.good_threshold))
    acceptable = sum((data.l2_norms .>= data.good_threshold) .& (data.l2_norms .< data.acceptable_threshold))
    poor = sum(data.l2_norms .>= data.acceptable_threshold)
    
    println("\nQuality Distribution:")
    println("  🟢 Excellent: $excellent experiments")
    println("  🟡 Good: $good experiments") 
    println("  🟠 Acceptable: $acceptable experiments")
    println("  🔴 Poor: $poor experiments")
    
    # Best results
    best_idx = argmin(data.l2_norms)
    println("\nBest Result:")
    println("  Degree: $(data.degrees[best_idx])")
    println("  L2-Norm: $(format_scientific(data.l2_norms[best_idx]))")
    if !isnan(data.condition_numbers[best_idx])
        println("  Condition Number: $(format_scientific(data.condition_numbers[best_idx]))")
    end
end

function render_parameter_space_text(data::ParameterSpaceData)
    println("\n🎯 Parameter Space Analysis")
    println("Points: $(size(data.points, 1))")
    println("Dimensions: $(size(data.points, 2))")
    println("Function Value Range: $(format_scientific(minimum(data.function_values))) - $(format_scientific(maximum(data.function_values)))")
    
    println("\nDimension Bounds:")
    for i in 1:length(data.dimension_labels)
        label = data.dimension_labels[i]
        bounds = data.bounds[i]
        println("  $label: $(format_float(bounds[1])) to $(format_float(bounds[2]))")
    end
    
    # Find best point
    best_idx = argmin(data.function_values)
    println("\nBest Point:")
    println("  Function Value: $(format_scientific(data.function_values[best_idx]))")
    for i in 1:length(data.dimension_labels)
        println("  $(data.dimension_labels[i]): $(format_float(data.points[best_idx, i]))")
    end
end

function render_convergence_text(data::ConvergenceTrajectoryData)
    println("\n🏃 Convergence Trajectory Analysis")
    println("Algorithms: $(length(data.algorithm_names))")
    
    for name in data.algorithm_names
        if haskey(data.trajectories, name)
            traj = data.trajectories[name]
            println("\n  📊 $name:")
            println("    Trajectory Points: $(size(traj, 1))")
            if size(traj, 1) > 0
                start_pos = traj[1, :]
                end_pos = traj[end, :]
                displacement = norm(end_pos - start_pos)
                println("    Final Displacement: $(format_float(displacement))")
            end
            
            if haskey(data.function_values, name) && !isempty(data.function_values[name])
                values = data.function_values[name]
                println("    Initial Value: $(format_scientific(values[1]))")
                println("    Final Value: $(format_scientific(values[end]))")
                improvement = (values[1] - values[end]) / values[1] * 100
                println("    Improvement: $(format_percent(improvement))%")
            end
        end
    end
end

# =============================================================================
# Stub renderer implementations (filled by extensions)
# =============================================================================

"""
Default stub renderer that will be replaced by actual implementations in extensions.
"""
struct StubRenderer <: AbstractPlotRenderer
    backend_name::String
end

function render_plot(renderer::StubRenderer, data::AbstractPlotData, config::AbstractVisualizationConfig)
    println("⚠️  $(renderer.backend_name) renderer not available - install plotting packages")
    return fallback_render(data, config)
end

# Register default stub renderers
register_plot_renderer!(L2DegreeAnalysisData, StubRenderer("CairoMakie"), set_default=true)
register_plot_renderer!(ParameterSpaceData, StubRenderer("CairoMakie"), set_default=true)
register_plot_renderer!(ConvergenceTrajectoryData, StubRenderer("GLMakie"), set_default=true)

end # module VisualizationFramework