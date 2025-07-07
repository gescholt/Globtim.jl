# ================================================================================
# Critical Point Distance Matrix Analysis
# ================================================================================
#
# This module creates a distance matrix showing how the distance from each 
# theoretical critical point to its nearest computed point evolves with 
# polynomial degree. This helps identify which critical points are not 
# converging despite improving L2-norm approximations.
#
# ================================================================================

using DataFrames, CSV
using LinearAlgebra
using Statistics
using PrettyTables
using Printf
using CairoMakie

"""
    create_critical_point_distance_matrix(computed_points_by_degree, degrees)

Create a matrix showing distances from each theoretical critical point to 
the nearest computed point for each polynomial degree.

# Arguments
- `computed_points_by_degree`: Dict mapping degree to all computed critical points
- `degrees`: Vector of polynomial degrees

# Returns
- `distance_matrix`: 25×|degrees| matrix of distances
- `results_df`: DataFrame with critical point info and distances
"""
function create_critical_point_distance_matrix(
    computed_points_by_degree::Dict{Int, Vector{Vector{Float64}}},
    degrees::Vector{Int}
)
    # Load all 25 theoretical critical points
    println("\n📊 Creating Critical Point Distance Matrix...")
    df_theory = CSV.read(joinpath(@__DIR__, "../data/4d_all_critical_points_orthant.csv"), DataFrame)
    
    n_points = nrow(df_theory)
    n_degrees = length(degrees)
    
    # Initialize distance matrix
    distance_matrix = zeros(n_points, n_degrees)
    
    # Compute distances for each theoretical point and degree
    for (i, row) in enumerate(eachrow(df_theory))
        theoretical_point = [row.x1, row.x2, row.x3, row.x4]
        
        for (j, degree) in enumerate(degrees)
            computed_points = computed_points_by_degree[degree]
            
            if isempty(computed_points)
                distance_matrix[i, j] = Inf
            else
                # Find minimum distance to any computed point
                min_dist = minimum(norm(theoretical_point - cp) for cp in computed_points)
                distance_matrix[i, j] = min_dist
            end
        end
    end
    
    # Create results DataFrame
    results_df = DataFrame()
    
    # Add critical point info
    results_df.idx = 1:n_points
    results_df.type = df_theory.type_4d
    results_df.x1 = df_theory.x1
    results_df.x2 = df_theory.x2
    results_df.x3 = df_theory.x3
    results_df.x4 = df_theory.x4
    results_df.function_value = df_theory.function_value
    
    # Add distance columns for each degree
    for (j, degree) in enumerate(degrees)
        col_name = Symbol("d_$(degree)")
        results_df[!, col_name] = distance_matrix[:, j]
    end
    
    # Add convergence indicator (is distance decreasing?)
    if length(degrees) > 1
        # Compare first and last degrees
        first_deg_col = Symbol("d_$(degrees[1])")
        last_deg_col = Symbol("d_$(degrees[end])")
        results_df.converging = results_df[!, last_deg_col] .< results_df[!, first_deg_col]
        results_df.distance_reduction = results_df[!, first_deg_col] .- results_df[!, last_deg_col]
    end
    
    return distance_matrix, results_df
end

"""
    display_distance_matrix(distance_matrix, degrees, df_theory; threshold=0.1)

Display the distance matrix in a nice tabular format with highlighting.

# Arguments
- `distance_matrix`: The distance matrix to display
- `degrees`: Vector of polynomial degrees
- `df_theory`: DataFrame with theoretical critical point information
- `threshold`: Distance threshold for "good" recovery (default: 0.1)
"""
function display_distance_matrix(distance_matrix::Matrix{Float64}, 
                                degrees::Vector{Int},
                                df_theory::DataFrame;
                                threshold::Float64 = 0.1)
    
    n_points, n_degrees = size(distance_matrix)
    
    # Create display data
    display_data = Matrix{String}(undef, n_points, n_degrees + 2)
    
    # Fill in point index and type
    for i in 1:n_points
        display_data[i, 1] = string(i)
        display_data[i, 2] = df_theory.type_4d[i]
    end
    
    # Fill in distances with formatting
    for i in 1:n_points
        for j in 1:n_degrees
            dist = distance_matrix[i, j]
            if dist < threshold
                # Good recovery - format in green (when possible)
                display_data[i, j+2] = @sprintf("%.3e✓", dist)
            elseif dist < 1.0
                # Moderate distance
                display_data[i, j+2] = @sprintf("%.3e", dist)
            else
                # Large distance
                display_data[i, j+2] = @sprintf("%.3e!", dist)
            end
        end
    end
    
    # Create header
    header = ["Pt", "Type"]
    for deg in degrees
        push!(header, "d=$deg")
    end
    
    # Display table
    println("\n📊 Distance Matrix: Theoretical Critical Points to Nearest Computed Points")
    println("   (✓ = distance < $threshold, ! = distance > 1.0)")
    println()
    
    pretty_table(display_data, 
                header = header,
                alignment = [:r, :l, fill(:r, n_degrees)...],
                crop = :none)
    
    # Summary statistics
    println("\n📈 Summary Statistics by Degree:")
    for (j, degree) in enumerate(degrees)
        distances = distance_matrix[:, j]
        n_recovered = sum(distances .< threshold)
        n_minima_recovered = sum((distances .< threshold) .& (df_theory.type_4d .== "min"))
        n_saddle_recovered = sum((distances .< threshold) .& (df_theory.type_4d .== "saddle"))
        
        println("   Degree $degree:")
        println("     - Points recovered (< $threshold): $n_recovered/$(n_points) ($(round(100*n_recovered/n_points, digits=1))%)")
        println("     - Minima recovered: $n_minima_recovered/9 ($(round(100*n_minima_recovered/9, digits=1))%)")
        println("     - Saddles recovered: $n_saddle_recovered/16 ($(round(100*n_saddle_recovered/16, digits=1))%)")
        println("     - Min distance: $(minimum(distances))")
        println("     - Median distance: $(median(distances))")
        println("     - Max distance: $(maximum(distances))")
    end
    
    # Identify non-converging points
    if size(distance_matrix, 2) > 1
        println("\n⚠️  Non-converging Critical Points:")
        non_converging = findall(distance_matrix[:, end] .>= distance_matrix[:, 1])
        
        if isempty(non_converging)
            println("   All points show improvement!")
        else
            println("   The following points show no improvement or worsening:")
            for idx in non_converging
                pt_type = df_theory.type_4d[idx]
                first_dist = distance_matrix[idx, 1]
                last_dist = distance_matrix[idx, end]
                change = last_dist - first_dist
                println("     - Point $idx ($pt_type): $(first_dist) → $(last_dist) (change: +$(change))")
            end
            
            # Type breakdown
            non_conv_types = df_theory.type_4d[non_converging]
            n_min_nc = sum(non_conv_types .== "min")
            n_sad_nc = sum(non_conv_types .== "saddle")
            println("\n   Non-converging by type: $n_min_nc minima, $n_sad_nc saddles")
        end
    end
end

"""
    analyze_convergence_patterns(distance_matrix, degrees, df_theory)

Analyze patterns in the convergence behavior of different critical points.

# Returns
- Dictionary with analysis results
"""
function analyze_convergence_patterns(distance_matrix::Matrix{Float64},
                                    degrees::Vector{Int},
                                    df_theory::DataFrame)
    
    analysis = Dict{String, Any}()
    
    # Convergence rates by type
    min_indices = findall(df_theory.type_4d .== "min")
    saddle_indices = findall(df_theory.type_4d .== "saddle")
    
    # Average distances by type and degree
    min_avg_distances = [mean(distance_matrix[min_indices, j]) for j in 1:length(degrees)]
    saddle_avg_distances = [mean(distance_matrix[saddle_indices, j]) for j in 1:length(degrees)]
    
    analysis["min_avg_distances"] = min_avg_distances
    analysis["saddle_avg_distances"] = saddle_avg_distances
    
    # Convergence rate (if we have at least 3 degrees)
    if length(degrees) >= 3
        # Simple linear fit to log distances
        log_degrees = log.(degrees)
        
        # For minima
        valid_min = min_avg_distances .> 0
        if sum(valid_min) >= 2
            X_min = [ones(sum(valid_min)) log_degrees[valid_min]]
            y_min = log.(min_avg_distances[valid_min])
            coef_min = X_min \ y_min
            analysis["min_convergence_rate"] = -coef_min[2]  # Negative of slope
        end
        
        # For saddles
        valid_saddle = saddle_avg_distances .> 0
        if sum(valid_saddle) >= 2
            X_saddle = [ones(sum(valid_saddle)) log_degrees[valid_saddle]]
            y_saddle = log.(saddle_avg_distances[valid_saddle])
            coef_saddle = X_saddle \ y_saddle
            analysis["saddle_convergence_rate"] = -coef_saddle[2]
        end
    end
    
    return analysis
end

"""
    plot_distance_evolution(distance_matrix, degrees, df_theory; 
                          output_file="critical_point_distance_evolution.png")

Create a plot showing how distances evolve for all 25 critical points across
polynomial degrees, with curves colored by point type (min/saddle).

# Arguments
- `distance_matrix`: 25×|degrees| matrix of distances
- `degrees`: Vector of polynomial degrees
- `df_theory`: DataFrame with theoretical critical point information
- `output_file`: Where to save the plot
"""
function plot_distance_evolution(distance_matrix::Matrix{Float64},
                               degrees::Vector{Int},
                               df_theory::DataFrame;
                               output_file::String = "critical_point_distance_evolution.png")
    
    fig = Figure(size=(1000, 700))
    ax = Axis(fig[1, 1],
              xlabel = "Polynomial Degree",
              ylabel = "Distance to Nearest Computed Point",
              yscale = log10)
    
    # Define colors for each type
    # Note: The data only has "min" and "saddle" types, no "max"
    colors = Dict(
        "min" => :blue,
        "saddle" => :red
    )
    
    # Track which types we've added to legend
    legend_added = Dict("min" => false, "saddle" => false)
    
    # Plot each critical point's distance evolution
    for i in 1:size(distance_matrix, 1)
        point_type = df_theory.type_4d[i]
        color = colors[point_type]
        
        # Extract distances for this point across all degrees
        distances = distance_matrix[i, :]
        
        # Skip if all distances are Inf
        if all(isinf.(distances))
            continue
        end
        
        # Add label only for the first curve of each type (for legend)
        if !legend_added[point_type]
            lines!(ax, degrees, distances,
                   color = color,
                   linewidth = 2,
                   alpha = 0.7,
                   label = point_type)
            legend_added[point_type] = true
        else
            lines!(ax, degrees, distances,
                   color = color,
                   linewidth = 2,
                   alpha = 0.7)
        end
    end
    
    # Add legend
    axislegend(ax, position = :rt, framevisible = true)
    
    # Set x-axis ticks to match degrees
    ax.xticks = degrees
    
    # Add grid for better readability
    ax.xgridvisible = true
    ax.ygridvisible = true
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
    
    # Save and display
    save(output_file, fig)
    display(fig)
    
    println("\n✅ Distance evolution plot saved to: $output_file")
end