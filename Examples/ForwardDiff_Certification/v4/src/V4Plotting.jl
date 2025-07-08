# V4Plotting.jl - Standalone plotting module for V4 analysis

module V4Plotting

using CairoMakie
using DataFrames
using Statistics
using LinearAlgebra
using Printf

export plot_v4_l2_convergence, plot_v4_distance_convergence, 
       plot_critical_point_distance_evolution, create_v4_plots

# ================================================================================
# L2 CONVERGENCE PLOTTING
# ================================================================================

"""
    plot_v4_l2_convergence(degrees, l2_data_by_degree_by_subdomain; 
                          global_l2_by_degree=nothing, output_dir=nothing)

Create L2-norm convergence plot showing average across subdomains with individual traces.

# Arguments
- `degrees`: Vector of polynomial degrees
- `l2_data_by_degree_by_subdomain`: Dict{Int, Dict{String, Float64}} - L2 norms by degree and subdomain
- `global_l2_by_degree`: Optional Dict{Int, Float64} for global domain comparison
- `output_dir`: Directory to save plot (if provided)

# Returns
- `fig`: Makie Figure object
"""
function plot_v4_l2_convergence(degrees::Vector{Int}, 
                               l2_data_by_degree_by_subdomain::Dict{Int, Dict{String, Float64}};
                               global_l2_by_degree::Union{Dict{Int, Float64}, Nothing} = nothing,
                               output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel = "Polynomial Degree", 
              ylabel = "L²-norm of Approximation Error", 
              yscale = log10)
    
    # Sort degrees for consistent plotting
    sorted_degrees = sort(degrees)
    
    # Collect all subdomain labels
    all_subdomains = Set{String}()
    for deg_data in values(l2_data_by_degree_by_subdomain)
        union!(all_subdomains, keys(deg_data))
    end
    subdomain_labels = sort(collect(all_subdomains))
    
    # Plot individual subdomain traces
    for subdomain in subdomain_labels
        l2_values = Float64[]
        valid_degrees = Int[]
        
        for degree in sorted_degrees
            if haskey(l2_data_by_degree_by_subdomain[degree], subdomain)
                push!(l2_values, l2_data_by_degree_by_subdomain[degree][subdomain])
                push!(valid_degrees, degree)
            end
        end
        
        if !isempty(l2_values)
            lines!(ax, valid_degrees, l2_values, 
                   linewidth=0.5, color=(:blue, 0.3), alpha=0.5)
        end
    end
    
    # Calculate and plot average L2-norm
    avg_l2_values = Float64[]
    for degree in sorted_degrees
        deg_values = [v for (k,v) in l2_data_by_degree_by_subdomain[degree]]
        push!(avg_l2_values, mean(deg_values))
    end
    
    lines!(ax, sorted_degrees, avg_l2_values, 
           linewidth=3, color=:blue, label="Average (16 subdomains)")
    scatter!(ax, sorted_degrees, avg_l2_values, 
             markersize=12, color=:blue)
    
    # Add global L2-norm if provided
    if global_l2_by_degree !== nothing
        global_l2s = [global_l2_by_degree[d] for d in sorted_degrees]
        lines!(ax, sorted_degrees, global_l2s, 
               linewidth=3, color=:red, label="Global domain")
        scatter!(ax, sorted_degrees, global_l2s, 
                 markersize=12, color=:red)
    end
    
    # Configure axes
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    axislegend(ax, position=:rt)
    
    # Save if output directory provided
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_l2_convergence.png"), fig)
    end
    
    return fig
end

# ================================================================================
# DISTANCE CONVERGENCE PLOTTING
# ================================================================================

"""
    plot_v4_distance_convergence(degrees, distance_data_by_degree, 
                                subdomain_distance_data_by_degree;
                                threshold=0.1, output_dir=nothing)

Create distance convergence plot with subdomain traces for subdomains containing minimizers.

# Arguments
- `degrees`: Vector of polynomial degrees
- `distance_data_by_degree`: Dict{Int, Vector{Float64}} - All distances by degree
- `subdomain_distance_data_by_degree`: Dict{Int, Dict{String, Vector{Float64}}} - Distances by subdomain
- `threshold`: Recovery threshold to display
- `output_dir`: Directory to save plots (if provided)

# Returns
- `fig`: Main plot figure
- `legend_fig`: Separate legend figure
"""
function plot_v4_distance_convergence(degrees::Vector{Int},
                                    distance_data_by_degree::Dict{Int, Vector{Float64}},
                                    subdomain_distance_data_by_degree::Dict{Int, Dict{String, Vector{Float64}}};
                                    threshold::Float64 = 0.1,
                                    output_dir::Union{String, Nothing} = nothing)
    
    # Main plot
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel = "Polynomial Degree", 
              ylabel = "Distance to Nearest Theoretical Point", 
              yscale = log10)
    
    sorted_degrees = sort(degrees)
    
    # Configure x-axis
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    # Store plot elements for legend
    plot_elements = []
    plot_labels = []
    
    # Identify subdomains with data
    subdomains_with_data = Set{String}()
    for deg_data in values(subdomain_distance_data_by_degree)
        for (label, distances) in deg_data
            if !isempty(distances) && !all(isnan.(distances))
                push!(subdomains_with_data, label)
            end
        end
    end
    
    # Plot individual subdomain traces
    subdomain_line = nothing
    for (idx, subdomain_label) in enumerate(sort(collect(subdomains_with_data)))
        subdomain_means = Float64[]
        valid_degrees = Int[]
        
        for degree in sorted_degrees
            if haskey(subdomain_distance_data_by_degree[degree], subdomain_label)
                distances = subdomain_distance_data_by_degree[degree][subdomain_label]
                if !isempty(distances) && !all(isnan.(distances))
                    valid_dists = filter(!isnan, distances)
                    if !isempty(valid_dists)
                        push!(subdomain_means, mean(valid_dists))
                        push!(valid_degrees, degree)
                    end
                end
            end
        end
        
        if !isempty(subdomain_means)
            line = lines!(ax, valid_degrees, subdomain_means, 
                         linewidth=1.2, color=(:orange, 0.6), alpha=0.8)
            if idx == 1
                subdomain_line = line
            end
        end
    end
    
    # Plot average distance
    avg_distances = Float64[]
    for degree in sorted_degrees
        all_dists = distance_data_by_degree[degree]
        valid_dists = filter(d -> !isnan(d) && !isinf(d), all_dists)
        if !isempty(valid_dists)
            push!(avg_distances, mean(valid_dists))
        else
            push!(avg_distances, NaN)
        end
    end
    
    # Filter out NaN values for plotting
    valid_indices = findall(!isnan, avg_distances)
    if !isempty(valid_indices)
        valid_degrees_avg = sorted_degrees[valid_indices]
        valid_avg_distances = avg_distances[valid_indices]
        
        avg_line = lines!(ax, valid_degrees_avg, valid_avg_distances, 
                         linewidth=4, color=:orange)
        scatter!(ax, valid_degrees_avg, valid_avg_distances, 
                markersize=10, color=:orange)
        push!(plot_elements, avg_line)
        push!(plot_labels, "Average (all points)")
    end
    
    # Add threshold line
    thresh_line = hlines!(ax, [threshold], color=:black, linestyle=:dot, linewidth=2)
    push!(plot_elements, thresh_line)
    push!(plot_labels, "Recovery threshold")
    
    # Add subdomain line to legend if we have one
    if subdomain_line !== nothing
        push!(plot_elements, subdomain_line)
        push!(plot_labels, "Individual subdomains")
    end
    
    # Save main plot
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_distance_convergence.png"), fig)
    end
    
    # Create separate legend
    legend_fig = Figure(size=(300, 200))
    Legend(legend_fig[1, 1], plot_elements, plot_labels, 
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_distance_convergence_legend.png"), legend_fig)
    end
    
    return fig, legend_fig
end

# ================================================================================
# CRITICAL POINT DISTANCE EVOLUTION
# ================================================================================

"""
    plot_critical_point_distance_evolution(subdomain_tables, degrees;
                                         output_dir=nothing, 
                                         plot_all_points=true,
                                         highlight_subdomain=nothing)

Plot how the distance from each theoretical critical point to its nearest 
computed point evolves with polynomial degree.

# Arguments
- `subdomain_tables`: Dict{String, DataFrame} from V4 analysis
- `degrees`: Vector of polynomial degrees
- `output_dir`: Directory to save plot (if provided)
- `plot_all_points`: If true, plot all points; if false, only plot averages by type
- `highlight_subdomain`: Optional subdomain label to highlight

# Returns
- `fig`: Makie Figure object
"""
function plot_critical_point_distance_evolution(subdomain_tables::Dict{String, DataFrame},
                                              degrees::Vector{Int};
                                              output_dir::Union{String, Nothing} = nothing,
                                              plot_all_points::Bool = true,
                                              highlight_subdomain::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(1000, 700))
    ax = Axis(fig[1, 1],
              xlabel = "Polynomial Degree",
              ylabel = "Distance to Nearest Computed Point",
              yscale = log10)
    
    sorted_degrees = sort(degrees)
    
    # Colors for point types
    colors = Dict(
        "min" => :blue,
        "saddle" => :red
    )
    
    if plot_all_points
        # Track which types we've added to legend
        legend_added = Dict("min" => false, "saddle" => false)
        
        # Plot individual critical points
        for (subdomain_label, table) in subdomain_tables
            # Skip AVERAGE rows
            data_rows = table[table.theoretical_point_id .!= "AVERAGE", :]
            
            for row in eachrow(data_rows)
                point_type = row.type
                color = colors[point_type]
                
                # Extract distances for this point
                distances = Float64[]
                valid_degrees = Int[]
                for deg in sorted_degrees
                    col = Symbol("d$deg")
                    if hasproperty(row, col) && !isnan(row[col])
                        push!(distances, row[col])
                        push!(valid_degrees, deg)
                    end
                end
                
                if isempty(distances)
                    continue
                end
                
                # Determine line properties
                alpha = 0.7
                linewidth = 2
                if highlight_subdomain !== nothing
                    if subdomain_label == highlight_subdomain
                        alpha = 1.0
                        linewidth = 3
                    else
                        alpha = 0.3
                        linewidth = 1
                    end
                end
                
                # Add label only for first curve of each type
                if !legend_added[point_type]
                    lines!(ax, valid_degrees, distances,
                           color = color,
                           linewidth = linewidth,
                           alpha = alpha,
                           label = point_type)
                    legend_added[point_type] = true
                else
                    lines!(ax, valid_degrees, distances,
                           color = color,
                           linewidth = linewidth,
                           alpha = alpha)
                end
            end
        end
    else
        # Plot averages by type
        min_distances_by_degree = Dict(deg => Float64[] for deg in sorted_degrees)
        saddle_distances_by_degree = Dict(deg => Float64[] for deg in sorted_degrees)
        
        for (subdomain_label, table) in subdomain_tables
            data_rows = table[table.theoretical_point_id .!= "AVERAGE", :]
            
            for row in eachrow(data_rows)
                for deg in sorted_degrees
                    col = Symbol("d$deg")
                    if hasproperty(row, col) && !isnan(row[col])
                        if row.type == "min"
                            push!(min_distances_by_degree[deg], row[col])
                        else
                            push!(saddle_distances_by_degree[deg], row[col])
                        end
                    end
                end
            end
        end
        
        # Calculate and plot averages
        min_avg_distances = Float64[]
        saddle_avg_distances = Float64[]
        
        for deg in sorted_degrees
            if !isempty(min_distances_by_degree[deg])
                push!(min_avg_distances, mean(min_distances_by_degree[deg]))
            else
                push!(min_avg_distances, NaN)
            end
            
            if !isempty(saddle_distances_by_degree[deg])
                push!(saddle_avg_distances, mean(saddle_distances_by_degree[deg]))
            else
                push!(saddle_avg_distances, NaN)
            end
        end
        
        # Plot averages
        valid_min = findall(!isnan, min_avg_distances)
        if !isempty(valid_min)
            lines!(ax, sorted_degrees[valid_min], min_avg_distances[valid_min],
                   color = :blue, linewidth = 3, label = "min (average)")
            scatter!(ax, sorted_degrees[valid_min], min_avg_distances[valid_min],
                     markersize = 10, color = :blue)
        end
        
        valid_saddle = findall(!isnan, saddle_avg_distances)
        if !isempty(valid_saddle)
            lines!(ax, sorted_degrees[valid_saddle], saddle_avg_distances[valid_saddle],
                   color = :red, linewidth = 3, label = "saddle (average)")
            scatter!(ax, sorted_degrees[valid_saddle], saddle_avg_distances[valid_saddle],
                     markersize = 10, color = :red)
        end
    end
    
    # Add legend
    axislegend(ax, position = :rt, framevisible = true)
    
    # Configure axes
    ax.xticks = sorted_degrees
    ax.xgridvisible = true
    ax.ygridvisible = true
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
    
    # Save if requested
    if output_dir !== nothing
        filename = plot_all_points ? "v4_critical_point_distance_evolution.png" : 
                                   "v4_critical_point_distance_evolution_avg.png"
        save(joinpath(output_dir, filename), fig)
    end
    
    return fig
end

# ================================================================================
# CONVENIENCE FUNCTION
# ================================================================================

"""
    create_v4_plots(subdomain_tables, degrees, l2_data, distance_data;
                   output_dir=nothing, plot_config=Dict())

Create all V4 plots with a single function call.

# Arguments
- `subdomain_tables`: Dict{String, DataFrame} from V4 analysis
- `degrees`: Vector of polynomial degrees  
- `l2_data`: Dict{Int, Dict{String, Float64}} - L2 norms by degree and subdomain
- `distance_data`: Dict{Int, Vector{Float64}} - All distances by degree
- `output_dir`: Directory to save plots
- `plot_config`: Configuration options

# Returns
- Named tuple with all figures
"""
function create_v4_plots(subdomain_tables::Dict{String, DataFrame},
                        degrees::Vector{Int},
                        l2_data::Dict{Int, Dict{String, Float64}},
                        distance_data::Dict{Int, Vector{Float64}};
                        subdomain_distance_data::Union{Dict{Int, Dict{String, Vector{Float64}}}, Nothing} = nothing,
                        output_dir::Union{String, Nothing} = nothing,
                        plot_config::Dict = Dict())
    
    # Default configuration
    config = merge(Dict(
        "threshold" => 0.1,
        "plot_all_points" => true,
        "highlight_subdomain" => nothing
    ), plot_config)
    
    # Create L2 convergence plot
    l2_fig = plot_v4_l2_convergence(degrees, l2_data, output_dir=output_dir)
    
    # Create distance convergence plot if subdomain data available
    dist_fig = nothing
    dist_legend_fig = nothing
    if subdomain_distance_data !== nothing
        dist_fig, dist_legend_fig = plot_v4_distance_convergence(
            degrees, distance_data, subdomain_distance_data,
            threshold=config["threshold"], output_dir=output_dir
        )
    end
    
    # Create critical point evolution plot
    evolution_fig = plot_critical_point_distance_evolution(
        subdomain_tables, degrees,
        output_dir=output_dir,
        plot_all_points=config["plot_all_points"],
        highlight_subdomain=config["highlight_subdomain"]
    )
    
    # Display all plots
    display(l2_fig)
    if dist_fig !== nothing
        display(dist_fig)
        display(dist_legend_fig)
    end
    display(evolution_fig)
    
    return (
        l2_convergence = l2_fig,
        distance_convergence = dist_fig,
        distance_legend = dist_legend_fig,
        critical_point_evolution = evolution_fig
    )
end

end # module