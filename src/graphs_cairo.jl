using CairoMakie
using Distributions
using LinearAlgebra

"""
Plot the discrete L2-norm approximation error attained by the polynomial approximant. 
"""
function plot_discrete_l2(results, start_degree::Int, end_degree::Int, step::Int)
    degrees = start_degree:step:end_degree
    l2_norms = Float64[]

    # Extract L2 norms for each degree
    for d in degrees
        push!(l2_norms, results[d].discrete_l2)
    end

    # Create figure
    fig = Figure(size = (600, 400))

    ax = Axis(fig[1, 1], title = "Discrete L2 Norm", xlabel = "Degree")

    # Plot the curve with points at each degree
    scatterlines!(
        ax,
        degrees,
        l2_norms,
        color = :purple,
        markersize = 8,
        linewidth = 2,
        label = "L2 Norm",
    )

    axislegend(ax)

    return fig
end

"""
We display how many critical points we found, at each degree `d` and, up to a set tolerance tol_dist, we show how many of these points are captured by the Optim routine. 
"""

function capture_histogram(
    results,
    start_degree::Int,
    end_degree::Int,
    step::Int;
    tol_dist::Float64 = 0.001,
    show_legend::Bool = false,
)

    degrees = start_degree:step:end_degree
    total_mins = Int[]
    uncaptured_mins = Int[]

    for d in degrees
        df_min = results[d][2]
        push!(total_mins, nrow(df_min))
        push!(uncaptured_mins, count(.!df_min.captured))
    end

    # Adjust figure size based on whether legend is shown
    fig_width = show_legend ? 1000 : 800
    fig = Figure(size = (fig_width, 600))

    ax = Axis(
        fig[1, 1],
        xlabel = "Polynomial Degree",
        # ylabel="",
        titlesize = 20,
        xlabelsize = 14,
        ylabelsize = 14,
    )

    positions = collect(degrees)

    barplot!(
        ax,
        positions,
        total_mins,
        color = (:forestgreen, 0.8),
        label = "Captured (tol = $(tol_dist))",
    )

    barplot!(
        ax,
        positions,
        uncaptured_mins,
        color = (:firebrick, 0.8),
        label = "Uncaptured",
    )

    ax.xticks = (positions, string.(degrees))
    ax.xticklabelsize = 12
    ax.yticklabelsize = 12

    if show_legend
        Legend(
            fig[1, 2],
            ax,
            framevisible = true,
            backgroundcolor = (:white, 0.9),
            padding = (10, 10, 10, 10),
        )
        colsize!(fig.layout, 1, Relative(0.8))
        colsize!(fig.layout, 2, Relative(0.2))
    end

    return fig
end


"""
Plot summary of convergence distances for a range of degrees --> for each captured "x", compute the distance to "y", the optimized point.
"""
function plot_convergence_analysis(
    results,
    start_degree::Int,
    end_degree::Int,
    step::Int;
    show_legend::Bool = true,
)
    degrees = start_degree:step:end_degree
    max_distances = Float64[]
    avg_distances = Float64[]

    for d in degrees
        df = results[d].df
        stats = analyze_convergence_distances(df)
        push!(max_distances, stats.maximum)
        push!(avg_distances, stats.average)
    end

    fig = Figure(size = (600, 400))

    ax = Axis(
        fig[1, 1],
        # title="Distance to Nearest Critical Point",
        xlabel = "Degree",
    )

    scatterlines!(ax, degrees, max_distances, label = "Maximum", color = :red)
    scatterlines!(ax, degrees, avg_distances, label = "Average", color = :blue)

    if show_legend
        axislegend(ax)
    end

    return fig
end

function compute_min_distances(df, df_check)
    # Initialize array to store minimum distances
    min_distances = Float64[]

    # For each row in df, find distance to closest point in df_check
    for i = 1:nrow(df)
        point = Array(df[i, :])  # Convert row to array
        min_dist = Inf

        # Compare with each point in df_check
        for j = 1:nrow(df_check)
            check_point = Array(df_check[j, :])
            dist = norm(point - check_point)  # Euclidean distance
            min_dist = min(min_dist, dist)
        end

        push!(min_distances, min_dist)
    end

    return min_distances
end

"""
For a specific `d`, we can plot the level set of the function with captured critical points in green and optim points in Blue (or red if not captured).
"""
function cairo_plot_polyapprox_levelset(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int} = (1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}} = nothing,
    chebyshev_levels::Bool = false,
    num_levels::Int = 30,
    show_captured::Bool = true,  # New parameter
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = figure_size)
        ax = Axis(fig[1, 1], title = "")

        # Calculate z_limits if not provided
        if isnothing(z_limits)
            z_values = Float64[]
            append!(z_values, df.z)
            append!(z_values, df_min.value)
            z_limits = (minimum(z_values), maximum(z_values))
        end

        # Calculate levels
        levels = if chebyshev_levels
            k = collect(0:num_levels-1)
            cheb_nodes = -cos.((2k .+ 1) .* π ./ (2 * num_levels))
            z_min, z_max = z_limits
            (z_max - z_min) ./ 2 .* cheb_nodes .+ (z_max + z_min) ./ 2
        else
            num_levels
        end

        # Prepare contour data
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        # Create contour plot
        chosen_colormap = :inferno
        contourf!(ax, x_unique, y_unique, Z, colormap = chosen_colormap, levels = levels)

        # Initialize empty array for legend entries
        legend_entries = []

        # Plot and add legend entries for all point types
        if :close in propertynames(df)
            # Far points
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    markersize = 10,
                    color = :white,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Far",
                )
                push!(legend_entries, "Far")
            end

            # Near points
            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    markersize = 10,
                    color = :green,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Near",
                )
                push!(legend_entries, "Near")
            end
        else
            # All points if no close/far distinction
            scatter!(
                ax,
                df.x1,
                df.x2,
                markersize = 2,
                color = :orange,
                label = "All points",
            )
            push!(legend_entries, "All points")
        end

        # Uncaptured points
        if !isempty(df_min)
            uncaptured_idx = .!df_min.captured
            captured_idx = df_min.captured

            if any(uncaptured_idx)
                scatter!(
                    ax,
                    df_min.x1[uncaptured_idx],
                    df_min.x2[uncaptured_idx],
                    markersize = 15,
                    marker = :diamond,
                    color = :red,
                    label = "Uncaptured",
                )
                push!(legend_entries, "Uncaptured")
            end

            # Only show captured points if show_captured is true
            if show_captured && any(captured_idx)
                scatter!(
                    ax,
                    df_min.x1[captured_idx],
                    df_min.x2[captured_idx],
                    markersize = 15,
                    marker = :diamond,
                    color = :blue,
                    label = "Captured",
                )
                push!(legend_entries, "Captured")
            end
        end
        return fig
    end
end

"""
Plot the outputs of`analyze_converged_points` function. 
"""
function plot_distance_statistics(stats::Dict{String,Any}; show_legend::Bool = true)
    fig = Figure(size = (600, 400))

    ax = Axis(fig[1, 1], xlabel = "Degree")

    # Plot maximum and average distances
    degrees = stats["degrees"]
    scatterlines!(ax, degrees, stats["max_distances"], label = "Maximum", color = :red)
    scatterlines!(ax, degrees, stats["avg_distances"], label = "Average", color = :blue)

    if show_legend
        axislegend(ax)
    end

    return fig
end
# function plot_filtered_y_distances(
#     df_filtered::DataFrame,
#     results::Dict{Int,NamedTuple{(:df, :df_min, :convergence_stats, :discrete_l2),
#         Tuple{DataFrame,DataFrame,NamedTuple,Float64}}},
#     start_degree::Int,
#     end_degree::Int,
#     step::Int=1;
#     use_optimized::Bool=true,  # true for y values (optimized), false for x values (initial)
#     show_legend::Bool=true)

#     degrees = start_degree:step:end_degree
#     n_dims = count(col -> startswith(string(col), "x"), names(df_filtered))
#     n_points = nrow(df_filtered)

#     # ANSI color codes for pretty printing
#     bold = "\e[1m"
#     blue = "\e[34m"
#     green = "\e[32m"
#     reset = "\e[0m"

#     point_type = use_optimized ? "optimized (y)" : "initial (x)"
#     println("\n$(bold)Distance Analysis Summary$(reset)")
#     println("$(blue)▶ $(reset)Analyzing $(bold)$(n_points)$(reset) filtered points in $(bold)$(n_dims)$(reset) dimensions")
#     println("$(blue)▶ $(reset)Using $(bold)$point_type$(reset) points from filtered data")
#     println("$(blue)▶ $(reset)Degree range: $(bold)$start_degree$(reset) to $(bold)$end_degree$(reset) with step $(bold)$step$(reset)")

#     point_distances = zeros(Float64, n_points, length(degrees))

#     for (i, row) in enumerate(eachrow(df_filtered))
#         # Select either y (optimized) or x (initial) values based on flag
#         point_coords::Vector{Float64} = if use_optimized
#             [row[Symbol("y$j")] for j in 1:n_dims]
#         else
#             [row[Symbol("x$j")] for j in 1:n_dims]
#         end

#         for (d_idx, d) in enumerate(degrees)
#             raw_points = results[d].df

#             min_dist::Float64 = Inf
#             for raw_row in eachrow(raw_points)
#                 point::Vector{Float64} = [raw_row[Symbol("x$j")] for j in 1:n_dims]
#                 dist::Float64 = norm(point_coords - point)
#                 min_dist = min(min_dist, dist)
#             end
#             point_distances[i, d_idx] = min_dist
#         end
#     end

#     max_distances::Vector{Float64} = [maximum(point_distances[:, i]) for i in 1:length(degrees)]
#     avg_distances::Vector{Float64} = [sum(point_distances[:, i]) / n_points for i in 1:length(degrees)]
#     min_distances::Vector{Float64} = [minimum(point_distances[:, i]) for i in 1:length(degrees)]
#     overall_avg::Float64 = sum(avg_distances) / length(avg_distances)

#     println("\n$(green)▶ $(reset)Distance Statistics:")
#     println("   $(bold)Overall maximum distance:$(reset) $(round(maximum(max_distances), digits=6))")
#     println("   $(bold)Overall minimum distance:$(reset) $(round(minimum(min_distances), digits=6))")
#     println("   $(bold)Overall average distance:$(reset) $(round(overall_avg, digits=6))")

#     println("\n$(green)▶ $(reset)Per-degree Analysis:")
#     for (i, d) in enumerate(degrees)
#         println("   $(bold)Degree $d:$(reset)")
#         println("      Max distance: $(round(max_distances[i], digits=6))")
#         println("      Min distance: $(round(min_distances[i], digits=6))")
#         println("      Avg distance: $(round(avg_distances[i], digits=6))")
#         println()
#     end

#     fig = Figure(size=(600, 400))

#     point_label = use_optimized ? "Optimized" : "Initial"
#     ax = Axis(fig[1, 1],
#         # title="Distance from Each $point_label Point to Nearest Initial Point",
#         xlabel="Degree",
#         ylabel="")

#     scatterlines!(ax, degrees, max_distances, label="Maximum", color=:red)
#     scatterlines!(ax, degrees, avg_distances, label="Average", color=:blue)

#     if show_legend
#         axislegend(ax)
#     end

#     return fig
# end

function plot_filtered_y_distances(
    df_filtered::DataFrame,
    TR::test_input,  # Added TR parameter
    results::Dict{
        Int,
        NamedTuple{
            (:df, :df_min, :convergence_stats, :discrete_l2),
            Tuple{DataFrame,DataFrame,NamedTuple,Float64},
        },
    },
    start_degree::Int,
    end_degree::Int,
    step::Int = 1;
    use_optimized::Bool = true,
    show_legend::Bool = true,
)

    degrees = start_degree:step:end_degree
    n_dims = count(col -> startswith(string(col), "x"), names(df_filtered))
    first_degree = first(degrees)
    n_points = nrow(results[first_degree].df)

    # Filter points that are in the hypercube
    in_domain = points_in_hypercube(df_filtered, TR, use_y = true)
    df_in_domain = df_filtered[in_domain, :]

    point_distances = zeros(Float64, n_points, length(degrees))

    for (i, row) in enumerate(eachrow(df_in_domain))  # Changed to df_in_domain
        # Select either y (optimized) or x (initial) values based on flag
        point_coords::Vector{Float64} = if use_optimized
            [row[Symbol("y$j")] for j = 1:n_dims]
        else
            [row[Symbol("x$j")] for j = 1:n_dims]
        end

        # Skip points with NaN coordinates
        if any(isnan.(point_coords))
            continue
        end

        println("point_coords: ", point_coords)

        for (d_idx, d) in enumerate(degrees)
            raw_points = results[d].df

            min_dist::Float64 = Inf
            for raw_row in eachrow(raw_points)
                point::Vector{Float64} = [raw_row[Symbol("x$j")] for j = 1:n_dims]
                dist::Float64 = norm(point_coords - point)
                min_dist = min(min_dist, dist)
            end
            point_distances[i, d_idx] = min_dist
        end
    end

    # Filter out NaN values before computing statistics
    valid_distances = [filter(!isnan, point_distances[:, i]) for i = 1:length(degrees)]
    max_distances = [maximum(dists) for dists in valid_distances]
    min_distances = [minimum(dists) for dists in valid_distances]
    avg_distances = [sum(dists) / length(dists) for dists in valid_distances]
    overall_avg = sum(sum.(valid_distances)) / sum(length.(valid_distances))

    max_distances::Vector{Float64} =
        [maximum(point_distances[:, i]) for i = 1:length(degrees)]
    avg_distances::Vector{Float64} =
        [sum(point_distances[:, i]) / n_points for i = 1:length(degrees)]
    min_distances::Vector{Float64} =
        [minimum(point_distances[:, i]) for i = 1:length(degrees)]
    overall_avg::Float64 = sum(avg_distances) / length(avg_distances)

    println("\n$(green)▶ $(reset)Distance Statistics:")
    println(
        "   $(bold)Overall maximum distance:$(reset) $(round(maximum(max_distances), digits=6))",
    )
    println(
        "   $(bold)Overall minimum distance:$(reset) $(round(minimum(min_distances), digits=6))",
    )
    println("   $(bold)Overall average distance:$(reset) $(round(overall_avg, digits=6))")

    println("\n$(green)▶ $(reset)Per-degree Analysis:")
    for (i, d) in enumerate(degrees)
        println("   $(bold)Degree $d:$(reset)")
        println("      Max distance: $(round(max_distances[i], digits=6))")
        println("      Min distance: $(round(min_distances[i], digits=6))")
        println("      Avg distance: $(round(avg_distances[i], digits=6))")
        println()
    end

    fig = Figure(size = (600, 400))

    point_label = use_optimized ? "Optimized" : "Initial"
    ax = Axis(
        fig[1, 1],
        # title="Distance from Each $point_label Point to Nearest Initial Point",
        xlabel = "Degree",
        ylabel = "",
    )

    scatterlines!(ax, degrees, max_distances, label = "Maximum", color = :red)
    scatterlines!(ax, degrees, avg_distances, label = "Average", color = :blue)

    if show_legend
        axislegend(ax)
    end

    return fig
end



function plot_convergence_captured(
    results,
    df_check,
    start_degree::Int,
    end_degree::Int,
    step::Int;
    show_legend::Bool = true,
)
    degrees = start_degree:step:end_degree
    max_distances = Float64[]
    avg_distances = Float64[]

    for d in degrees
        df = results[d].df_min
        stats = analyze_captured_distances(df, df_check)
        push!(max_distances, stats.maximum)
        push!(avg_distances, stats.average)
    end

    fig = Figure(size = (600, 400))

    ax = Axis(
        fig[1, 1],
        # title="Distance to Nearest Critical Point",
        xlabel = "Degree",
        ylabel = "Distance",
    )

    scatterlines!(ax, degrees, max_distances, label = "Maximum", color = :red)
    scatterlines!(ax, degrees, avg_distances, label = "Average", color = :blue)

    if show_legend
        axislegend(ax)
    end

    return fig
end



function create_legend_figure(tol_dist::Float64)
    fig = Figure(size = (300, 100))

    # Create dummy axis with invisible elements for legend
    ax = Axis(fig[1, 1], visible = false)

    barplot!(
        ax,
        [1],
        [1],
        color = (:forestgreen, 0.8),
        label = "Captured (tol = $(tol_dist))",
    )
    barplot!(ax, [1], [1], color = (:firebrick, 0.8), label = "Uncaptured")

    Legend(
        fig[1, 1],
        ax,
        orientation = :horizontal,
        framevisible = true,
        backgroundcolor = (:white, 0.9),
        padding = (10, 10, 10, 10),
    )

    return fig
end






function plot_convergence_captured(
    results,
    df_check,
    start_degree::Int,
    end_degree::Int,
    step::Int;
    show_legend::Bool = true,
)
    degrees = start_degree:step:end_degree
    max_distances = Float64[]
    avg_distances = Float64[]

    for d in degrees
        x_cols = [col for col in names(results[d].df_min) if startswith(string(col), "x")]
        df = results[d].df_min[:, x_cols]

        stats = analyze_captured_distances(df, df_check)
        push!(max_distances, stats.maximum)
        push!(avg_distances, stats.average)
    end

    fig = Figure(size = (600, 400))

    ax = Axis(
        fig[1, 1],
        # title="",
        xlabel = "Degree",
        ylabel = "",
    )

    scatterlines!(ax, degrees, max_distances, label = "Maximum", color = :red)
    scatterlines!(ax, degrees, avg_distances, label = "Average", color = :blue)

    if show_legend
        axislegend(ax)
    end

    return fig
end
