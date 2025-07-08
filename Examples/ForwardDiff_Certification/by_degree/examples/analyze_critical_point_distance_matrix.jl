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

# Import subdomain management functions at the module level
include("../src/SubdomainManagement.jl")
using .SubdomainManagement: generate_16_subdivisions_orthant, is_point_in_subdomain

"""
    create_critical_point_distance_matrix(computed_points_by_degree, degrees)

Create a matrix showing distances from each theoretical critical point to 
the nearest computed point for each polynomial degree.

# Arguments
- `computed_points_by_degree`: Dict mapping degree to all computed critical points
- `degrees`: Vector of polynomial degrees

# Returns
- `distance_matrix`: (n_critical_points × |degrees|) matrix of distances
- `results_df`: DataFrame with critical point info and distances
"""
function create_critical_point_distance_matrix(
    computed_points_by_degree::Dict{Int, Vector{Vector{Float64}}},
    degrees::Vector{Int}
)
    # Load all theoretical critical points
    println("\n📊 Creating Critical Point Distance Matrix...")
    df_theory = CSV.read(joinpath(@__DIR__, "../data/4d_all_critical_points_orthant.csv"), DataFrame)
    
    n_points = nrow(df_theory)
    n_degrees = length(degrees)
    
    # Initialize distance matrix
    distance_matrix = zeros(n_points, n_degrees)
    
    # Determine dimensionality from df_theory columns
    dim_cols = [col for col in names(df_theory) if startswith(String(col), "x")]
    n_dims = length(dim_cols)
    
    # Compute distances for each theoretical point and degree
    for (i, row) in enumerate(eachrow(df_theory))
        theoretical_point = [row[Symbol("x$i")] for i in 1:n_dims]
        
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

"""
    plot_subdomain_distance_evolution(distance_matrix, degrees, df_theory, 
                                    all_critical_points_with_labels;
                                    output_file="subdomain_distance_evolution.png",
                                    subdomain_tables=nothing)

Create a plot showing average distance evolution for each subdomain that contains
theoretical critical points, grouped by subdomain.

# Implementation Note (Plan B)
This function uses a clean two-step workflow:
1. Data Preparation: All subdomain data is prepared upfront into a clean structure
2. Plotting: The prepared data is then plotted without complex logic

This avoids variable reuse and ensures all subdomains with valid data are plotted.

# Arguments
- `distance_matrix`: (n_critical_points × |degrees|) matrix of distances
- `degrees`: Vector of polynomial degrees
- `df_theory`: DataFrame with theoretical critical point information
- `all_critical_points_with_labels`: Dict mapping degree to DataFrame with computed points and subdomain labels
- `output_file`: Where to save the plot
- `subdomain_tables`: Optional pre-computed tables from CriticalPointTablesV2
"""
function plot_subdomain_distance_evolution(distance_matrix::Matrix{Float64},
                                         degrees::Vector{Int},
                                         df_theory::DataFrame,
                                         all_critical_points_with_labels::Dict{Int, DataFrame};
                                         output_file::String = "subdomain_distance_evolution.png",
                                         subdomain_tables::Union{Dict{String, DataFrame}, Nothing} = nothing)
    
    # Generate subdomains
    subdomains = generate_16_subdivisions_orthant()
    
    # Assign theoretical critical points to subdomains
    subdomain_assignments = Dict{String, Vector{Int}}()
    for subdomain in subdomains
        subdomain_assignments[subdomain.label] = Int[]
    end
    
    # Determine dimensionality from df_theory columns
    dim_cols = [col for col in names(df_theory) if startswith(String(col), "x")]
    n_dims = length(dim_cols)
    
    for (idx, row) in enumerate(eachrow(df_theory))
        theoretical_point = [row[Symbol("x$i")] for i in 1:n_dims]
        for subdomain in subdomains
            if is_point_in_subdomain(theoretical_point, subdomain, tolerance=0.0)
                push!(subdomain_assignments[subdomain.label], idx)
                break
            end
        end
    end
    
    # Filter out subdomains with no theoretical critical points
    active_subdomains = [(label, indices) for (label, indices) in subdomain_assignments if !isempty(indices)]
    sort!(active_subdomains, by=x->x[1])  # Sort by label for consistent ordering
    
    println("\n📊 Subdomains with theoretical critical points:")
    for (label, indices) in active_subdomains
        n_min = sum(df_theory.type_4d[indices] .== "min")
        n_saddle = sum(df_theory.type_4d[indices] .== "saddle")
        println("   $label: $(length(indices)) points ($n_min min, $n_saddle saddle)")
    end
    
    # Compute average distances for each subdomain across degrees
    # PLAN B: Clean workflow with clear data preparation
    # Step 1: Prepare all plotting data in a clean structure
    plotting_data = []
    
    if subdomain_tables !== nothing
        # Use pre-computed table data
        println("\n📊 Using pre-computed subdomain tables for distance data")
        println("   Found $(length(subdomain_tables)) subdomain tables")
        
        # Process each subdomain table to extract plotting data
        for (subdomain_label, table) in subdomain_tables
            # Skip empty tables
            if isempty(table)
                continue
            end
            
            # Compute average distances for this subdomain across all degrees
            avg_distances = Float64[]
            
            for degree in degrees
                col_name = Symbol("degree_$degree")
                
                # Check if this degree column exists (using String comparison fix)
                if String(col_name) in names(table)
                    # Extract distances from the table
                    distances = table[!, col_name]
                    
                    # Debug output for key subdomains
                    if subdomain_label in ["1010", "1000", "1110"] && degree == degrees[1]
                        println("   Debug $subdomain_label degree $degree:")
                        println("     Raw distances: $distances")
                        println("     NaN count: $(sum(isnan.(distances)))")
                    end
                    
                    # Filter out NaN values to get finite distances
                    finite_distances = filter(!isnan, distances)
                    
                    if isempty(finite_distances)
                        # No valid distances for this degree
                        push!(avg_distances, NaN)
                    else
                        # Compute and store the average
                        avg_dist = mean(finite_distances)
                        push!(avg_distances, avg_dist)
                    end
                else
                    # Column doesn't exist for this degree
                    push!(avg_distances, NaN)
                end
            end
            
            # Skip this subdomain if all averages are NaN
            if all(isnan.(avg_distances))
                continue
            end
            
            # Count the types of critical points in this subdomain
            n_min = count(x -> x == "min", table.type)
            n_saddle = count(x -> x == "saddle", table.type)
            
            # Store all data needed for plotting this subdomain
            push!(plotting_data, (
                label = subdomain_label,
                avg_distances = avg_distances,
                n_min = n_min,
                n_saddle = n_saddle
            ))
        end
        
        # Sort by label for consistent ordering
        sort!(plotting_data, by=x->x.label)
        
        println("   Prepared plotting data for $(length(plotting_data)) subdomains")
    else
        # Original computation from distance matrix
        # Process each subdomain that has theoretical critical points
        for (subdomain_label, theory_indices) in active_subdomains
            avg_distances = Float64[]
            
            for (j, degree) in enumerate(degrees)
                # Get distances for theoretical points in this subdomain
                subdomain_distances = distance_matrix[theory_indices, j]
                
                # Compute average (excluding Inf values)
                finite_distances = filter(!isinf, subdomain_distances)
                if isempty(finite_distances)
                    push!(avg_distances, NaN)
                else
                    push!(avg_distances, mean(finite_distances))
                end
            end
            
            # Skip if all averages are NaN
            if all(isnan.(avg_distances))
                continue
            end
            
            # Count point types for this subdomain
            n_min = sum(df_theory.type_4d[theory_indices] .== "min")
            n_saddle = sum(df_theory.type_4d[theory_indices] .== "saddle")
            
            # Store plotting data
            push!(plotting_data, (
                label = subdomain_label,
                avg_distances = avg_distances,
                n_min = n_min,
                n_saddle = n_saddle
            ))
        end
        
        # Sort by label for consistent ordering
        sort!(plotting_data, by=x->x.label)
        
        println("   Prepared plotting data for $(length(plotting_data)) subdomains")
    end
    
    # Create the plot
    fig = Figure(size=(1000, 700))
    ax = Axis(fig[1, 1],
              xlabel = "Polynomial Degree",
              ylabel = "Average Distance to Nearest Computed Point",
              yscale = log10)
    
    # Color palette for subdomains
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray,
              :olive, :cyan, :magenta, :yellow, :teal, :navy, :maroon, :lime]
    
    # PLAN B: Plot using the clean data structure
    # Step 2: Plot each subdomain's average distance evolution
    println("\n📊 Plotting subdomain distance evolution:")
    println("   Subdomains with data: $(length(plotting_data))")
    
    # Plot each subdomain
    for (i, data) in enumerate(plotting_data)
        # Get color (cycle if more than 16 subdomains)
        color = colors[mod(i-1, length(colors)) + 1]
        
        # Create label with point counts
        label = "$(data.label) ($(data.n_min) min, $(data.n_saddle) sad)"
        
        # Extract valid (non-NaN) data points for plotting
        valid_mask = .!isnan.(data.avg_distances)
        valid_degrees = degrees[valid_mask]
        valid_distances = data.avg_distances[valid_mask]
        
        # Skip if no valid data points
        if isempty(valid_degrees)
            continue
        end
        
        # Plot line and scatter points
        lines!(ax, valid_degrees, valid_distances,
               color = color,
               linewidth = 2.5,
               label = label)
        scatter!(ax, valid_degrees, valid_distances,
                 color = color,
                 markersize = 8)
    end
    
    println("   Successfully plotted $(length(plotting_data)) subdomains")
    
    # Add legend only if there are subdomains plotted
    if !isempty(plotting_data)
        n_active = length(plotting_data)
        ncols = n_active > 8 ? 2 : 1
        Legend(fig[1, 2], ax, framevisible=true, tellwidth=true, 
               labelsize=12, nbanks=ncols)
    else
        println("⚠️  No subdomains had valid data to plot")
        # Add text to explain
        text!(ax, 0.5, 0.5, text = "No valid subdomain data available", 
              align = (:center, :center), fontsize = 20, color = :gray)
    end
    
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
    
    println("\n✅ Subdomain distance evolution plot saved to: $output_file")
end