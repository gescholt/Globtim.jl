# EnhancedVisualization.jl - Extended plotting functionality with subdomain traces

module EnhancedVisualization

using CairoMakie
using Statistics
using ..MinimizerTracking: SubdomainDistanceData

export plot_distance_with_subdomains

# Import threshold constant
const TRESH = 0.1  # Default value, should match the one used in analysis

"""
    plot_distance_with_subdomains(distance_data, global_data, subdomain_data, output_dir; threshold)

Create enhanced distance plot showing:
- Average distances (existing)
- Individual subdomain traces (new)
- Only for subdomains that contain minimizers

# Arguments
- `distance_data`: Dictionary of EnhancedDistanceStats by degree
- `global_data`: Dictionary of global domain stats by degree
- `subdomain_data`: Dictionary of subdomain distance data by degree
- `output_dir`: Output directory for saving plots
- `threshold`: Recovery threshold (default: 0.1)
"""
function plot_distance_with_subdomains(distance_data::Dict,
                                     global_data::Dict, 
                                     subdomain_data::Dict,
                                     output_dir::String;
                                     threshold::Float64 = TRESH)
    # Main plot figure without legend
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel = "Polynomial Degree", 
              ylabel = "Distance to Nearest True Minimizer", 
              yscale = log10)
    
    degrees = sort(collect(keys(distance_data)))
    
    # Configure x-axis for the specific degrees we have
    ax.xticks = degrees
    xlims!(ax, minimum(degrees) - 0.5, maximum(degrees) + 0.5)
    
    # Store plot elements for legend
    plot_elements = []
    plot_labels = []
    
    # Collect all subdomain labels that have minimizers
    subdomains_with_minimizers = Set{String}()
    for deg_data in values(subdomain_data)
        for (label, sdata) in deg_data
            if sdata.has_minimizers
                push!(subdomains_with_minimizers, label)
            end
        end
    end
    
    # Plot individual subdomain traces first (so they appear behind the averages)
    subdomain_line = nothing
    for (idx, subdomain_label) in enumerate(sort(collect(subdomains_with_minimizers)))
        subdomain_distances = Float64[]
        valid_degrees = Int[]
        
        for degree in degrees
            if haskey(subdomain_data[degree], subdomain_label)
                sdata = subdomain_data[degree][subdomain_label]
                if !isempty(sdata.distances_to_minimizers)
                    # Average distance for this subdomain at this degree
                    push!(subdomain_distances, mean(sdata.distances_to_minimizers))
                    push!(valid_degrees, degree)
                end
            end
        end
        
        # Plot as more visible line if we have data
        if !isempty(subdomain_distances)
            line = lines!(ax, valid_degrees, subdomain_distances, 
                         linewidth=1.2, color=(:orange, 0.6), alpha=0.8)
            # Store only the first subdomain line for legend
            if idx == 1
                subdomain_line = line
            end
        end
    end
    
    # Plot combined subdomains average (make line thicker for emphasis)
    subdomain_means = [distance_data[d].mean for d in degrees]
    
    # Plot average line (no shading)
    avg_line = lines!(ax, degrees, subdomain_means, 
                      linewidth=4, color=:orange)
    scatter!(ax, degrees, subdomain_means, markersize=10, color=:orange)
    push!(plot_elements, avg_line)
    push!(plot_labels, "Average (all subdomains)")
    
    # Global approximant data
    if !isempty(global_data)
        global_means = [global_data[d].mean for d in degrees]
        
        # Plot global approximant (no shading)
        global_line = lines!(ax, degrees, global_means, 
                            linewidth=3, color=:blue)
        scatter!(ax, degrees, global_means, markersize=10, color=:blue)
        push!(plot_elements, global_line)
        push!(plot_labels, "Average (global)")
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
    save(joinpath(output_dir, "distance_convergence_with_subdomains.png"), fig)
    display(fig)
    
    # Create separate legend figure
    legend_fig = Figure(size=(300, 200))
    Legend(legend_fig[1, 1], plot_elements, plot_labels, 
           framevisible=true, padding=(10, 10, 10, 10),
           labelsize=14, titlesize=16, title="Legend")
    
    save(joinpath(output_dir, "distance_convergence_legend.png"), legend_fig)
    display(legend_fig)
end

end # module