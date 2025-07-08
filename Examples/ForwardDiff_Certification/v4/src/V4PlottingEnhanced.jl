# V4PlottingEnhanced.jl - Enhanced plotting module with refined point analysis

module V4PlottingEnhanced

using CairoMakie
using CairoMakie: LineElement, PolyElement
using DataFrames
using Statistics
using LinearAlgebra
using Printf

export plot_v4_l2_convergence, plot_v4_distance_convergence, 
       plot_critical_point_distance_evolution, create_v4_plots,
       plot_refinement_comparison, plot_refinement_effectiveness,
       plot_theoretical_minima_to_refined, plot_refined_to_cheb_distances,
       create_all_v4_plots, plot_minimizer_distance_evolution

# ================================================================================
# L2 CONVERGENCE PLOTTING (with removed axis labels)
# ================================================================================

function plot_v4_l2_convergence(degrees::Vector{Int}, 
                               l2_data_by_degree_by_subdomain::Dict{Int, Dict{String, Float64}};
                               global_l2_by_degree::Union{Dict{Int, Float64}, Nothing} = nothing,
                               output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], yscale = log10)  # Removed xlabel and ylabel
    
    # Sort degrees for consistent plotting
    sorted_degrees = sort(degrees)
    
    # Store plot elements for legend
    plot_elements = []
    plot_labels = []
    
    # Collect all subdomain labels
    all_subdomains = Set{String}()
    for deg_data in values(l2_data_by_degree_by_subdomain)
        union!(all_subdomains, keys(deg_data))
    end
    subdomain_labels = sort(collect(all_subdomains))
    
    # Plot individual subdomain traces
    subdomain_line = nothing
    for (idx, subdomain) in enumerate(subdomain_labels)
        l2_values = Float64[]
        valid_degrees = Int[]
        
        for degree in sorted_degrees
            if haskey(l2_data_by_degree_by_subdomain[degree], subdomain)
                push!(l2_values, l2_data_by_degree_by_subdomain[degree][subdomain])
                push!(valid_degrees, degree)
            end
        end
        
        if !isempty(l2_values)
            line = lines!(ax, valid_degrees, l2_values, 
                         linewidth=0.5, color=(:blue, 0.3), alpha=0.5)
            if idx == 1
                subdomain_line = line
            end
        end
    end
    
    # Calculate and plot average L2-norm
    avg_l2_values = Float64[]
    for degree in sorted_degrees
        deg_values = [v for (k,v) in l2_data_by_degree_by_subdomain[degree]]
        push!(avg_l2_values, mean(deg_values))
    end
    
    avg_line = lines!(ax, sorted_degrees, avg_l2_values, 
                     linewidth=3, color=:blue, label="Average (16 subdomains)")
    scatter!(ax, sorted_degrees, avg_l2_values, 
             markersize=12, color=:blue)
    push!(plot_elements, avg_line)
    push!(plot_labels, "Average (16 subdomains)")
    
    # Add subdomain traces to legend
    if subdomain_line !== nothing
        push!(plot_elements, subdomain_line)
        push!(plot_labels, "Individual subdomains")
    end
    
    # Add global L2-norm if provided
    if global_l2_by_degree !== nothing
        global_l2s = [global_l2_by_degree[d] for d in sorted_degrees]
        global_line = lines!(ax, sorted_degrees, global_l2s, 
                            linewidth=3, color=:red, label="Global domain")
        scatter!(ax, sorted_degrees, global_l2s, 
                 markersize=12, color=:red)
        push!(plot_elements, global_line)
        push!(plot_labels, "Global domain")
    end
    
    # Configure axes
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    # Save main plot
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_l2_convergence.png"), fig)
    end
    
    # Create separate legend
    legend_fig = Figure(size=(300, 200))
    Legend(legend_fig[1, 1], plot_elements, plot_labels, 
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_l2_convergence_legend.png"), legend_fig)
    end
    
    return fig, legend_fig
end

# ================================================================================
# DISTANCE CONVERGENCE PLOTTING (with removed axis labels)
# ================================================================================

function plot_v4_distance_convergence(degrees::Vector{Int},
                                    distance_data_by_degree::Dict{Int, Vector{Float64}},
                                    subdomain_distance_data_by_degree::Dict{Int, Dict{String, Vector{Float64}}};
                                    threshold::Float64 = 0.1,
                                    output_dir::Union{String, Nothing} = nothing)
    
    # Main plot
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], yscale = log10)  # Removed xlabel and ylabel
    
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
# CRITICAL POINT DISTANCE EVOLUTION (with removed axis labels)
# ================================================================================

function plot_critical_point_distance_evolution(subdomain_tables::Dict{String, DataFrame},
                                              degrees::Vector{Int};
                                              output_dir::Union{String, Nothing} = nothing,
                                              plot_all_points::Bool = true,
                                              highlight_subdomain::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(1000, 700))
    ax = Axis(fig[1, 1], yscale = log10)  # Removed xlabel and ylabel
    
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
    
    # Legend removed
    # axislegend(ax, position = :rt, framevisible = true)
    
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
    
    # Create separate legend
    legend_fig = Figure(size=(400, 300))
    legend_elements = []
    legend_labels = []
    
    # Add legend entries for each type
    min_line = LineElement(color = :blue, linewidth = 3)
    saddle_line = LineElement(color = :red, linewidth = 3)
    push!(legend_elements, min_line)
    push!(legend_labels, "min")
    push!(legend_elements, saddle_line)
    push!(legend_labels, "saddle")
    
    Legend(legend_fig[1, 1], legend_elements, legend_labels,
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Critical Point Types")
    
    if output_dir !== nothing
        legend_filename = plot_all_points ? "v4_critical_point_distance_evolution_legend.png" : 
                                          "v4_critical_point_distance_evolution_avg_legend.png"
        save(joinpath(output_dir, legend_filename), legend_fig)
    end
    
    return fig, legend_fig
end

# ================================================================================
# MINIMIZER-FOCUSED DISTANCE EVOLUTION PLOT
# ================================================================================

"""
    plot_minimizer_distance_evolution(subdomain_tables, degrees; output_dir=nothing)

Create a focused plot showing only the 9 minimizers with individual curve labels.
Each minimizer is labeled 1-9 and uses distinct colors for better visibility.
"""
function plot_minimizer_distance_evolution(subdomain_tables::Dict{String, DataFrame},
                                         degrees::Vector{Int};
                                         output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(1200, 800))
    ax = Axis(fig[1, 1], 
             yscale = log10,
             xgridvisible = true,
             ygridvisible = true,
             xgridstyle = :dash,
             ygridstyle = :dash)
    
    sorted_degrees = sort(degrees)
    
    # Define 9 distinct colors for minimizers
    minimizer_colors = [
        :blue, :red, :green, :orange, :purple,
        :brown, :pink, :olive, :cyan
    ]
    
    # Collect all minimizer data
    minimizer_data = []
    
    for (subdomain_label, table) in subdomain_tables
        # Filter for minimizers only (excluding AVERAGE rows)
        min_rows = table[(table.theoretical_point_id .!= "AVERAGE") .& (table.type .== "min"), :]
        
        for row in eachrow(min_rows)
            # Extract distances for this minimizer
            distances = Float64[]
            valid_degrees = Int[]
            
            for deg in sorted_degrees
                col = Symbol("d$deg")
                if hasproperty(row, col) && !isnan(row[col])
                    push!(distances, row[col])
                    push!(valid_degrees, deg)
                end
            end
            
            if !isempty(distances)
                push!(minimizer_data, (
                    subdomain = subdomain_label,
                    point_id = row.theoretical_point_id,
                    degrees = valid_degrees,
                    distances = distances,
                    final_distance = distances[end]  # Last distance for sorting
                ))
            end
        end
    end
    
    # Sort minimizers by their final distance for consistent numbering
    sort!(minimizer_data, by = x -> x.final_distance)
    
    # Plot each minimizer with its label
    for (idx, data) in enumerate(minimizer_data)
        color = minimizer_colors[idx]
        
        # Plot the line
        lines!(ax, data.degrees, data.distances,
               color = color,
               linewidth = 3,
               alpha = 0.9)
        
        # Add markers at data points
        scatter!(ax, data.degrees, data.distances,
                color = color,
                markersize = 10,
                alpha = 0.9)
        
        # Add label at the end of the curve
        last_deg = data.degrees[end]
        last_dist = data.distances[end]
        
        # Position label slightly to the right of the last point
        label_x = last_deg + 0.15
        label_y = last_dist
        
        # Add the label with a background for readability
        text!(ax, label_x, label_y,
              text = string(idx),
              fontsize = 16,
              font = "bold",
              color = color,
              align = (:left, :center))
    end
    
    # Add threshold line
    hlines!(ax, [0.1], color = :black, linestyle = :dot, linewidth = 2)
    
    # Add text label for threshold
    text!(ax, sorted_degrees[1] + 0.1, 0.12,
          text = "Recovery threshold",
          fontsize = 12,
          color = :black)
    
    # Set axis limits with some padding
    xlims!(ax, sorted_degrees[1] - 0.2, sorted_degrees[end] + 0.5)
    
    # Save main plot
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_minimizer_distance_evolution.png"), fig)
    end
    
    # Create information table showing minimizer details
    info_fig = Figure(size=(600, 400))
    
    # Prepare table data
    table_data = DataFrame(
        Label = 1:length(minimizer_data),
        Subdomain = [d.subdomain for d in minimizer_data],
        Point_ID = [d.point_id for d in minimizer_data],
        Final_Distance = [@sprintf("%.2e", d.final_distance) for d in minimizer_data]
    )
    
    # Create simple text display of the table
    ax_info = Axis(info_fig[1, 1], 
                   limits = (0, 10, 0, 10),
                   aspect = 1)
    hidedecorations!(ax_info)
    hidespines!(ax_info)
    
    # Add title
    text!(ax_info, 5, 9.5, 
          text = "Minimizer Information",
          fontsize = 18,
          font = "bold",
          align = (:center, :center))
    
    # Add table headers
    text!(ax_info, 1, 8.5, text = "Label", fontsize = 14, font = "bold")
    text!(ax_info, 3, 8.5, text = "Subdomain", fontsize = 14, font = "bold")
    text!(ax_info, 5.5, 8.5, text = "Point ID", fontsize = 14, font = "bold")
    text!(ax_info, 8, 8.5, text = "Final Dist", fontsize = 14, font = "bold")
    
    # Add table data
    for (i, row) in enumerate(eachrow(table_data))
        y_pos = 8.5 - i * 0.8
        color = minimizer_colors[i]
        
        text!(ax_info, 1, y_pos, text = string(row.Label), 
              fontsize = 12, color = color, font = "bold")
        text!(ax_info, 3, y_pos, text = row.Subdomain, fontsize = 12)
        text!(ax_info, 5.5, y_pos, text = row.Point_ID, fontsize = 12)
        text!(ax_info, 8, y_pos, text = row.Final_Distance, fontsize = 12)
    end
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_minimizer_info_table.png"), info_fig)
    end
    
    return fig, info_fig
end

# ================================================================================
# NEW REFINED POINT PLOTS
# ================================================================================

"""
    plot_refinement_comparison(degrees, theoretical_distances, refined_distances;
                             threshold=0.1, output_dir=nothing)

Plot comparison of distances: theoretical → df_cheb vs df_min_refined → df_cheb
"""
function plot_refinement_comparison(degrees::Vector{Int},
                                  theoretical_distances::Dict{Int, Vector{Float64}},
                                  refined_distances::Dict{Int, Vector{Float64}};
                                  threshold::Float64 = 0.1,
                                  output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(900, 600))
    ax = Axis(fig[1, 1], yscale = log10)  # No axis labels
    
    sorted_degrees = sort(degrees)
    
    # Calculate averages for theoretical → df_cheb
    theo_avg = Float64[]
    for deg in sorted_degrees
        if haskey(theoretical_distances, deg)
            valid_dists = filter(d -> !isnan(d) && !isinf(d), theoretical_distances[deg])
            push!(theo_avg, isempty(valid_dists) ? NaN : mean(valid_dists))
        else
            push!(theo_avg, NaN)
        end
    end
    
    # Calculate averages for df_min_refined → df_cheb
    refined_avg = Float64[]
    for deg in sorted_degrees
        if haskey(refined_distances, deg)
            valid_dists = filter(d -> !isnan(d) && !isinf(d), refined_distances[deg])
            push!(refined_avg, isempty(valid_dists) ? NaN : mean(valid_dists))
        else
            push!(refined_avg, NaN)
        end
    end
    
    # Plot theoretical → df_cheb (blue)
    valid_theo = findall(!isnan, theo_avg)
    if !isempty(valid_theo)
        lines!(ax, sorted_degrees[valid_theo], theo_avg[valid_theo],
               linewidth=4, color=:blue, label="Theoretical → df_cheb")
        scatter!(ax, sorted_degrees[valid_theo], theo_avg[valid_theo],
                 markersize=12, color=:blue)
    end
    
    # Plot df_min_refined → df_cheb (green)
    valid_refined = findall(!isnan, refined_avg)
    if !isempty(valid_refined)
        lines!(ax, sorted_degrees[valid_refined], refined_avg[valid_refined],
               linewidth=4, color=:green, label="df_min_refined → df_cheb")
        scatter!(ax, sorted_degrees[valid_refined], refined_avg[valid_refined],
                 markersize=12, color=:green)
    end
    
    # Add threshold line
    hlines!(ax, [threshold], color=:black, linestyle=:dot, linewidth=2,
            label="Recovery threshold")
    
    # Configure axes
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    # Add legend
    # axislegend(ax, position=:rt)  # Legend removed
    
    # Save if requested
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_refinement_comparison.png"), fig)
    end
    
    # Create separate legend
    legend_fig = Figure(size=(400, 250))
    legend_elements = []
    legend_labels = []
    
    # Add legend entries
    theo_line = LineElement(color = :blue, linewidth = 4)
    refined_line = LineElement(color = :green, linewidth = 4)
    threshold_line = LineElement(color = :black, linewidth = 2, linestyle = :dot)
    
    push!(legend_elements, theo_line)
    push!(legend_labels, "Theoretical → df_cheb")
    push!(legend_elements, refined_line)
    push!(legend_labels, "df_min_refined → df_cheb")
    push!(legend_elements, threshold_line)
    push!(legend_labels, "Recovery threshold")
    
    Legend(legend_fig[1, 1], legend_elements, legend_labels,
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_refinement_comparison_legend.png"), legend_fig)
    end
    
    return fig, legend_fig
end

"""
    plot_theoretical_minima_to_refined(degrees, minima_to_refined_distances;
                                     output_dir=nothing)

Plot distances from theoretical minima to df_min_refined points (BFGS convergence quality)
"""
function plot_theoretical_minima_to_refined(degrees::Vector{Int},
                                          minima_to_refined_distances::Dict{Int, Dict{String, Vector{Float64}}};
                                          output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(900, 600))
    ax = Axis(fig[1, 1], yscale = log10)  # No axis labels
    
    sorted_degrees = sort(degrees)
    
    # Collect all subdomain data
    all_distances_by_degree = Dict(deg => Float64[] for deg in sorted_degrees)
    subdomain_averages = Dict{String, Vector{Float64}}()
    
    # Process each subdomain
    for deg in sorted_degrees
        if haskey(minima_to_refined_distances, deg)
            for (subdomain, distances) in minima_to_refined_distances[deg]
                valid_dists = filter(d -> !isnan(d) && !isinf(d), distances)
                if !isempty(valid_dists)
                    append!(all_distances_by_degree[deg], valid_dists)
                    
                    # Track subdomain averages
                    if !haskey(subdomain_averages, subdomain)
                        subdomain_averages[subdomain] = fill(NaN, length(sorted_degrees))
                    end
                    idx = findfirst(==(deg), sorted_degrees)
                    subdomain_averages[subdomain][idx] = mean(valid_dists)
                end
            end
        end
    end
    
    # Plot individual subdomain traces (light red)
    for (subdomain, avgs) in subdomain_averages
        valid_idx = findall(!isnan, avgs)
        if !isempty(valid_idx)
            lines!(ax, sorted_degrees[valid_idx], avgs[valid_idx],
                   linewidth=1.5, color=(:red, 0.3), alpha=0.6)
        end
    end
    
    # Calculate and plot overall average (dark red)
    overall_avg = Float64[]
    for deg in sorted_degrees
        dists = all_distances_by_degree[deg]
        push!(overall_avg, isempty(dists) ? NaN : mean(dists))
    end
    
    valid_avg = findall(!isnan, overall_avg)
    if !isempty(valid_avg)
        lines!(ax, sorted_degrees[valid_avg], overall_avg[valid_avg],
               linewidth=4, color=:red, label="Average distance")
        scatter!(ax, sorted_degrees[valid_avg], overall_avg[valid_avg],
                 markersize=12, color=:red)
    end
    
    # Configure axes
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    # Add legend
    # axislegend(ax, position=:rt)  # Legend removed
    
    # Save if requested
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_theoretical_minima_to_refined.png"), fig)
    end
    
    # Create separate legend
    legend_fig = Figure(size=(350, 200))
    legend_elements = []
    legend_labels = []
    
    # Add legend entries
    subdomain_line = LineElement(color = (:red, 0.3), linewidth = 1.5)
    avg_line = LineElement(color = :red, linewidth = 4)
    
    push!(legend_elements, subdomain_line)
    push!(legend_labels, "Individual subdomains")
    push!(legend_elements, avg_line)
    push!(legend_labels, "Average distance")
    
    Legend(legend_fig[1, 1], legend_elements, legend_labels,
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_theoretical_minima_to_refined_legend.png"), legend_fig)
    end
    
    return fig, legend_fig
end

"""
    plot_refinement_effectiveness(degrees, refinement_metrics;
                                output_dir=nothing)

Plot refinement effectiveness metrics (improvement ratios, point counts)
"""
function plot_refinement_effectiveness(degrees::Vector{Int},
                                     refinement_metrics::Dict{Int, Any};
                                     output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(1000, 600))
    
    # Create two axes for different metrics
    ax1 = Axis(fig[1, 1], title="Point Counts")
    ax2 = Axis(fig[1, 2], title="Improvement Ratios")
    
    sorted_degrees = sort(degrees)
    
    # Extract metrics
    n_computed = Int[]
    n_refined = Int[]
    improvement_ratios = Float64[]
    
    for deg in sorted_degrees
        if haskey(refinement_metrics, deg)
            push!(n_computed, refinement_metrics[deg].n_computed)
            push!(n_refined, refinement_metrics[deg].n_refined)
            push!(improvement_ratios, refinement_metrics[deg].avg_improvement)
        else
            push!(n_computed, 0)
            push!(n_refined, 0)
            push!(improvement_ratios, NaN)
        end
    end
    
    # Plot point counts
    barplot!(ax1, sorted_degrees .- 0.2, n_computed,
             width=0.35, color=:blue, label="df_cheb")
    barplot!(ax1, sorted_degrees .+ 0.2, n_refined,
             width=0.35, color=:green, label="df_min_refined")
    
    # Plot improvement ratios
    valid_imp = findall(!isnan, improvement_ratios)
    if !isempty(valid_imp)
        barplot!(ax2, sorted_degrees[valid_imp], improvement_ratios[valid_imp],
                 color=:purple, label="Distance improvement")
        
        # Add percentage labels
        for (i, idx) in enumerate(valid_imp)
            text!(ax2, sorted_degrees[idx], improvement_ratios[idx] + 0.02,
                  text="$(round(improvement_ratios[idx]*100, digits=1))%",
                  align=(:center, :bottom), fontsize=12)
        end
    end
    
    # Configure axes
    ax1.xticks = sorted_degrees
    ax2.xticks = sorted_degrees
    ylims!(ax2, 0, maximum(filter(!isnan, improvement_ratios)) * 1.2)
    
    # Legends removed
    # axislegend(ax1, position=:lt)
    # axislegend(ax2, position=:lt)
    
    # Save if requested
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_refinement_effectiveness.png"), fig)
    end
    
    return fig
end

"""
    plot_refined_to_cheb_distances(degrees, refined_to_cheb_distances;
                                  output_dir=nothing)

Plot distances from df_min_refined points to their nearest df_cheb points
"""
function plot_refined_to_cheb_distances(degrees::Vector{Int},
                                      refined_to_cheb_distances::Dict{Int, Vector{Float64}};
                                      output_dir::Union{String, Nothing} = nothing)
    
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], yscale = log10)  # No axis labels
    
    sorted_degrees = sort(degrees)
    
    # Calculate statistics
    means = Float64[]
    medians = Float64[]
    q25s = Float64[]
    q75s = Float64[]
    
    for deg in sorted_degrees
        if haskey(refined_to_cheb_distances, deg)
            dists = filter(d -> !isnan(d) && !isinf(d), refined_to_cheb_distances[deg])
            if !isempty(dists)
                push!(means, mean(dists))
                push!(medians, median(dists))
                push!(q25s, quantile(dists, 0.25))
                push!(q75s, quantile(dists, 0.75))
            else
                push!(means, NaN)
                push!(medians, NaN)
                push!(q25s, NaN)
                push!(q75s, NaN)
            end
        else
            push!(means, NaN)
            push!(medians, NaN)
            push!(q25s, NaN)
            push!(q75s, NaN)
        end
    end
    
    # Plot quartile bands
    valid_idx = findall(i -> !isnan(medians[i]), 1:length(medians))
    if !isempty(valid_idx)
        valid_degrees = sorted_degrees[valid_idx]
        
        # Fill between quartiles
        band!(ax, valid_degrees, q25s[valid_idx], q75s[valid_idx],
              color=(:green, 0.2), label="25th-75th percentile")
        
        # Plot median
        lines!(ax, valid_degrees, medians[valid_idx],
               linewidth=3, color=:green, linestyle=:dash, label="Median")
        
        # Plot mean
        lines!(ax, valid_degrees, means[valid_idx],
               linewidth=3, color=:darkgreen, label="Mean")
        scatter!(ax, valid_degrees, means[valid_idx],
                 markersize=10, color=:darkgreen)
    end
    
    # Configure axes
    ax.xticks = sorted_degrees
    xlims!(ax, minimum(sorted_degrees) - 0.5, maximum(sorted_degrees) + 0.5)
    
    # Add legend
    # axislegend(ax, position=:rt)  # Legend removed
    
    # Save if requested
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_refined_to_cheb_distances.png"), fig)
    end
    
    # Create separate legend
    legend_fig = Figure(size=(350, 250))
    legend_elements = []
    legend_labels = []
    
    # Add legend entries
    band_elem = PolyElement(color = (:green, 0.2), strokewidth = 0)
    median_line = LineElement(color = :green, linewidth = 3, linestyle = :dash)
    mean_line = LineElement(color = :darkgreen, linewidth = 3)
    
    push!(legend_elements, band_elem)
    push!(legend_labels, "25th-75th percentile")
    push!(legend_elements, median_line)
    push!(legend_labels, "Median")
    push!(legend_elements, mean_line)
    push!(legend_labels, "Mean")
    
    Legend(legend_fig[1, 1], legend_elements, legend_labels,
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    if output_dir !== nothing
        save(joinpath(output_dir, "v4_refined_to_cheb_distances_legend.png"), legend_fig)
    end
    
    return fig, legend_fig
end

# ================================================================================
# CONVENIENCE FUNCTIONS
# ================================================================================

"""
    create_all_v4_plots(data_dict; output_dir=nothing, plot_config=Dict())

Create all V4 plots including refined point analysis.
Expected data_dict keys:
- subdomain_tables
- degrees
- l2_data
- distance_data
- subdomain_distance_data
- refined_distance_data
- minima_to_refined_distances
- refinement_metrics
"""
function create_all_v4_plots(data_dict::Dict;
                           output_dir::Union{String, Nothing} = nothing,
                           plot_config::Dict = Dict())
    
    # Default configuration
    config = merge(Dict(
        "threshold" => 0.1,
        "plot_all_points" => true,
        "highlight_subdomain" => nothing
    ), plot_config)
    
    figures = Dict{String, Figure}()
    
    # Original V4 plots (with removed axis labels)
    if haskey(data_dict, "subdomain_tables") && haskey(data_dict, "l2_data")
        fig, legend_fig = plot_v4_l2_convergence(
            data_dict["degrees"], data_dict["l2_data"], 
            output_dir=output_dir
        )
        figures["l2_convergence"] = fig
        figures["l2_convergence_legend"] = legend_fig
    end
    
    if haskey(data_dict, "distance_data") && haskey(data_dict, "subdomain_distance_data")
        fig, legend_fig = plot_v4_distance_convergence(
            data_dict["degrees"], data_dict["distance_data"], 
            data_dict["subdomain_distance_data"],
            threshold=config["threshold"], output_dir=output_dir
        )
        figures["distance_convergence"] = fig
        figures["distance_legend"] = legend_fig
    end
    
    if haskey(data_dict, "subdomain_tables")
        fig, legend_fig = plot_critical_point_distance_evolution(
            data_dict["subdomain_tables"], data_dict["degrees"],
            output_dir=output_dir,
            plot_all_points=config["plot_all_points"],
            highlight_subdomain=config["highlight_subdomain"]
        )
        figures["critical_point_evolution"] = fig
        figures["critical_point_evolution_legend"] = legend_fig
        
        # NEW: Minimizer-focused plot
        fig_min, info_fig = plot_minimizer_distance_evolution(
            data_dict["subdomain_tables"], data_dict["degrees"],
            output_dir=output_dir
        )
        figures["minimizer_evolution"] = fig_min
        figures["minimizer_info"] = info_fig
    end
    
    # New refined point plots
    if haskey(data_dict, "refined_distance_data")
        fig, legend_fig = plot_refinement_comparison(
            data_dict["degrees"], 
            data_dict["distance_data"],
            data_dict["refined_distance_data"],
            threshold=config["threshold"],
            output_dir=output_dir
        )
        figures["refinement_comparison"] = fig
        figures["refinement_comparison_legend"] = legend_fig
    end
    
    if haskey(data_dict, "minima_to_refined_distances")
        fig, legend_fig = plot_theoretical_minima_to_refined(
            data_dict["degrees"],
            data_dict["minima_to_refined_distances"],
            output_dir=output_dir
        )
        figures["theoretical_minima_to_refined"] = fig
        figures["theoretical_minima_to_refined_legend"] = legend_fig
    end
    
    # Removed refinement_effectiveness plot as requested
    
    if haskey(data_dict, "refined_to_cheb_distances")
        fig, legend_fig = plot_refined_to_cheb_distances(
            data_dict["degrees"],
            data_dict["refined_to_cheb_distances"],
            output_dir=output_dir
        )
        figures["refined_to_cheb_distances"] = fig
        figures["refined_to_cheb_distances_legend"] = legend_fig
    end
    
    # Display all figures
    for (name, fig) in figures
        println("\n📊 Displaying: $name")
        display(fig)
    end
    
    return figures
end

# For backward compatibility
create_v4_plots = create_all_v4_plots

end # module