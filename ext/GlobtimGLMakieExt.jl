module GlobtimGLMakieExt

using Globtim
using GLMakie
using DataFrames
using StaticArrays  # Required for LevelSetViz.jl
using Parameters    # Required for LevelSetViz.jl

# Include GLMakie-specific plotting functionality
include("../src/graphs_makie.jl")
include("../src/LevelSetViz.jl")

# Include Phase 2 Hessian visualization functions with proper GLMakie scope
function Globtim.plot_hessian_norms(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size = (800, 600))
    ax = GLMakie.Axis(
        fig[1, 1],
        xlabel = "Critical Point Index",
        ylabel = "Hessian L2 Norm",
        title = "L2 Norm of Hessian Matrices",
    )

    # Color by classification if available
    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask = df.critical_point_type .== classification
            GLMakie.scatter!(
                ax,
                findall(mask),
                df.hessian_norm[mask],
                label = string(classification),
                markersize = 8,
            )
        end
        GLMakie.axislegend(ax)
    else
        GLMakie.scatter!(ax, 1:nrow(df), df.hessian_norm, markersize = 8)
    end

    return fig
end

function Globtim.plot_condition_numbers(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size = (800, 600))
    ax = GLMakie.Axis(
        fig[1, 1],
        xlabel = "Critical Point Index",
        ylabel = "Condition Number (log scale)",
        title = "Condition Numbers of Hessian Matrices",
        yscale = GLMakie.log10,
    )

    # Filter out NaN and infinite values
    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)

    if "critical_point_type" in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask =
                (df.critical_point_type .== classification) .&
                [i in valid_indices for i = 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                GLMakie.scatter!(
                    ax,
                    indices,
                    df.hessian_condition_number[indices],
                    label = string(classification),
                    markersize = 8,
                )
            end
        end
        GLMakie.axislegend(ax)
    else
        GLMakie.scatter!(
            ax,
            valid_indices,
            df.hessian_condition_number[valid_indices],
            markersize = 8,
        )
    end

    return fig
end

function Globtim.plot_critical_eigenvalues(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size = (1200, 500))

    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = GLMakie.Axis(
        fig[1, 1],
        xlabel = "Minimum Index",
        ylabel = "Smallest Positive Eigenvalue",
        title = "Smallest Positive Eigenvalues (Minima)",
    )

    minima_mask = df.critical_point_type .== :minimum
    valid_minima =
        findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])

    if !isempty(valid_minima)
        GLMakie.scatter!(
            ax1,
            valid_minima,
            df.smallest_positive_eigenval[minima_mask][valid_minima],
            color = :blue,
            markersize = 10,
        )
        # Add horizontal line at machine epsilon for reference
        GLMakie.hlines!(
            ax1,
            [1e-12],
            color = :red,
            linestyle = :dash,
            label = "Numerical Zero",
        )
        GLMakie.axislegend(ax1)
    end

    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = GLMakie.Axis(
        fig[1, 2],
        xlabel = "Maximum Index",
        ylabel = "Largest Negative Eigenvalue",
        title = "Largest Negative Eigenvalues (Maxima)",
    )

    maxima_mask = df.critical_point_type .== :maximum
    valid_maxima =
        findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])

    if !isempty(valid_maxima)
        GLMakie.scatter!(
            ax2,
            valid_maxima,
            df.largest_negative_eigenval[maxima_mask][valid_maxima],
            color = :red,
            markersize = 10,
        )
        # Add horizontal line at negative machine epsilon for reference
        GLMakie.hlines!(
            ax2,
            [-1e-12],
            color = :red,
            linestyle = :dash,
            label = "Numerical Zero",
        )
        GLMakie.axislegend(ax2)
    end

    return fig
end

function Globtim.plot_all_eigenvalues(
    f::Function,
    df::DataFrames.DataFrame;
    sort_by = :magnitude,
)
    # Extract all eigenvalues using the helper function
    all_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df)

    # Determine dimensionality
    n_points = length(all_eigenvalues)
    if n_points == 0
        @warn "No eigenvalue data available"
        return GLMakie.Figure()
    end

    # Filter out points with NaN eigenvalues
    valid_indices = [i for i = 1:n_points if !any(isnan, all_eigenvalues[i])]
    if isempty(valid_indices)
        @warn "No valid eigenvalue data found"
        return GLMakie.Figure()
    end

    n_dims = length(all_eigenvalues[valid_indices[1]])

    # Separate indices by critical point type
    point_types = [:minimum, :saddle, :maximum]
    type_colors = Dict(:minimum => :darkgreen, :saddle => :darkorange, :maximum => :darkred)

    type_indices = Dict()
    for ptype in point_types
        type_mask = [i for i in valid_indices if df.critical_point_type[i] == ptype]
        if !isempty(type_mask)
            # Apply sorting within each type
            if sort_by == :magnitude
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(abs.(all_eigenvalues[i])), rev = true)
            elseif sort_by == :abs_magnitude
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(abs.(all_eigenvalues[i])), rev = true)
            elseif sort_by == :smallest
                type_indices[ptype] = sort(type_mask, by = i -> minimum(all_eigenvalues[i]))
            elseif sort_by == :largest
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(all_eigenvalues[i]), rev = true)
            elseif sort_by == :spread
                type_indices[ptype] = sort(
                    type_mask,
                    by = i -> maximum(all_eigenvalues[i]) - minimum(all_eigenvalues[i]),
                    rev = true,
                )
            else  # :index
                type_indices[ptype] = type_mask
            end
        end
    end

    # Filter out empty types
    available_types = [
        ptype for ptype in point_types if
        haskey(type_indices, ptype) && !isempty(type_indices[ptype])
    ]
    n_types = length(available_types)

    if n_types == 0
        @warn "No valid critical point types found"
        return GLMakie.Figure()
    end

    # Create figure with subplots for each type
    fig = GLMakie.Figure(size = (1400, 400 * n_types))

    # Determine plot labels based on sort option
    y_label =
        sort_by == :abs_magnitude ? "Eigenvalue Magnitude (Absolute Value)" :
        "Eigenvalue Magnitude"

    # Color scheme for eigenvalues (same for all subplots)
    eigenval_colors = [:red, :blue, :green, :orange, :purple]  # Support up to 5D
    eigenval_labels = ["λ₁ (smallest)", "λ₂ (middle)", "λ₃ (largest)", "λ₄", "λ₅"]

    # Plot eigenvalues vertically aligned with connecting lines
    # No horizontal offset needed - all eigenvalues at same x position

    # Create subplot for each critical point type
    for (subplot_idx, ptype) in enumerate(available_types)
        sorted_indices = type_indices[ptype]
        type_color = type_colors[ptype]

        plot_title =
            sort_by == :abs_magnitude ?
            "$(uppercase(string(ptype))) Points - Eigenvalue Spectrum (Absolute Values)" :
            "$(uppercase(string(ptype))) Points - Complete Eigenvalue Spectrum"

        ax = GLMakie.Axis(
            fig[subplot_idx, 1],
            xlabel = "$(uppercase(string(ptype))) Point Index (sorted by $(sort_by))",
            ylabel = y_label,
            title = plot_title,
            xgridvisible = false,
        )

        for (plot_idx, orig_idx) in enumerate(sorted_indices)
            eigenvals = sort(all_eigenvalues[orig_idx])  # Sort eigenvalues by magnitude

            # Plot all eigenvalues vertically aligned at same x position
            x_pos = plot_idx

            # Convert eigenvalues to plot values
            plot_vals = sort_by == :abs_magnitude ? abs.(eigenvals) : eigenvals

            # Connect eigenvalues with dotted line
            GLMakie.lines!(
                ax,
                fill(x_pos, length(plot_vals)),
                plot_vals,
                color = type_color,
                linestyle = :dot,
                linewidth = 1,
                alpha = 0.7,
            )

            # Plot individual eigenvalues
            for (eig_idx, (eigenval, plot_val)) in enumerate(zip(eigenvals, plot_vals))
                GLMakie.scatter!(
                    ax,
                    [x_pos],
                    [plot_val],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5,
                )
            end
        end

        # Add zero reference line (only for non-absolute plots)
        if sort_by != :abs_magnitude
            GLMakie.hlines!(ax, [0], color = :black, linestyle = :dash, alpha = 0.5)
        end
    end

    # Create eigenvalue legend
    eigenval_legend_elements = [
        GLMakie.MarkerElement(
            color = eigenval_colors[i],
            marker = :circle,
            markersize = 10,
        ) for i = 1:min(n_dims, length(eigenval_colors))
    ]
    eigenval_legend_labels = eigenval_labels[1:min(n_dims, length(eigenval_labels))]

    # Create type color legend
    type_legend_elements = [
        GLMakie.MarkerElement(
            color = :black,
            marker = :circle,
            markersize = 10,
            strokecolor = type_colors[ptype],
            strokewidth = 2,
        ) for ptype in available_types
    ]
    type_legend_labels = ["$(uppercase(string(ptype))) Points" for ptype in available_types]

    # Add legends to the right side
    GLMakie.Legend(
        fig[1:n_types, 2],
        eigenval_legend_elements,
        eigenval_legend_labels,
        "Eigenvalue Order",
        tellheight = false,
        framevisible = true,
    )
    GLMakie.Legend(
        fig[1:n_types, 3],
        type_legend_elements,
        type_legend_labels,
        "Critical Point Type",
        tellheight = false,
        framevisible = true,
    )

    return fig
end

function Globtim.plot_raw_vs_refined_eigenvalues(
    f::Function,
    df_raw::DataFrames.DataFrame,
    df_refined::DataFrames.DataFrame;
    sort_by = :euclidean_distance,
)
    # Match raw to refined points
    matches = Globtim.match_raw_to_refined_points(df_raw, df_refined)

    if isempty(matches)
        @warn "No matching points found between raw and refined datasets"
        return GLMakie.Figure()
    end

    # Extract eigenvalues for both datasets
    raw_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_raw)
    refined_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_refined)

    # Filter matches based on critical point type if available
    if "critical_point_type" in names(df_refined)
        # Group matches by refined point type
        type_groups = Dict()
        for (raw_idx, refined_idx, distance) in matches
            ptype = df_refined.critical_point_type[refined_idx]
            if !haskey(type_groups, ptype)
                type_groups[ptype] = []
            end
            push!(type_groups[ptype], (raw_idx, refined_idx, distance))
        end

        available_types = collect(keys(type_groups))
        n_types = length(available_types)
    else
        # No type information, treat all as single group
        type_groups = Dict(:all => matches)
        available_types = [:all]
        n_types = 1
    end

    if n_types == 0
        @warn "No valid critical point types found in matches"
        return GLMakie.Figure()
    end

    # Create figure with subplots for each type
    fig = GLMakie.Figure(size = (1400, 600 * n_types))

    # Type colors
    type_colors = Dict(
        :minimum => :darkgreen,
        :saddle => :darkorange,
        :maximum => :darkred,
        :all => :darkblue,
    )

    # Eigenvalue colors
    eigenval_colors = [:red, :blue, :green, :orange, :purple]

    # Process each critical point type
    for (subplot_idx, ptype) in enumerate(available_types)
        type_matches = type_groups[ptype]
        type_color = get(type_colors, ptype, :darkblue)

        # Sort matches within type
        if sort_by == :euclidean_distance
            sort!(type_matches, by = x -> x[3])  # Sort by distance
        elseif sort_by == :function_value_diff
            sort!(type_matches, by = x -> abs(df_raw.z[x[1]] - df_refined.z[x[2]]))
        else  # :eigenvalue_change or default
            sort!(type_matches, by = x -> x[3])  # Default to distance
        end

        plot_title = "Raw vs Refined Eigenvalues: $(uppercase(string(ptype))) Points"
        ax = GLMakie.Axis(
            fig[subplot_idx, 1],
            xlabel = "Matched Pair Index (sorted by $(sort_by))",
            ylabel = "Eigenvalue Magnitude",
            title = plot_title,
            xgridvisible = false,
        )

        # Plot each matched pair
        for (pair_idx, (raw_idx, refined_idx, distance)) in enumerate(type_matches)
            x_pos = pair_idx

            # Get eigenvalues (handle NaN cases)
            raw_eigenvals = raw_eigenvalues[raw_idx]
            refined_eigenvals = refined_eigenvalues[refined_idx]

            if any(isnan, raw_eigenvals) || any(isnan, refined_eigenvals)
                continue
            end

            # Sort eigenvalues for consistent ordering
            raw_sorted = sort(raw_eigenvals)
            refined_sorted = sort(refined_eigenvals)

            n_eigenvals = min(length(raw_sorted), length(refined_sorted))

            # Vertical spacing for raw (top) and refined (bottom)
            raw_y_offset = 0.3
            refined_y_offset = -0.3

            # Plot raw eigenvalues (lighter colors, top position)
            for (eig_idx, eigenval) in enumerate(raw_sorted[1:n_eigenvals])
                y_pos = eigenval + raw_y_offset
                GLMakie.scatter!(
                    ax,
                    [x_pos],
                    [y_pos],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5,
                    alpha = 0.6,
                )  # Lighter for raw points
            end

            # Plot refined eigenvalues (darker colors, bottom position)
            for (eig_idx, eigenval) in enumerate(refined_sorted[1:n_eigenvals])
                y_pos = eigenval + refined_y_offset
                GLMakie.scatter!(
                    ax,
                    [x_pos],
                    [y_pos],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5,
                    alpha = 1.0,
                )  # Darker for refined points
            end

            # Connect corresponding eigenvalues with lines
            for eig_idx = 1:n_eigenvals
                raw_y = raw_sorted[eig_idx] + raw_y_offset
                refined_y = refined_sorted[eig_idx] + refined_y_offset

                GLMakie.lines!(
                    ax,
                    [x_pos, x_pos],
                    [raw_y, refined_y],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    linestyle = :solid,
                    linewidth = 1.5,
                    alpha = 0.7,
                )
            end

            # Add distance annotation (small text below)
            if distance > 0
                GLMakie.text!(
                    ax,
                    x_pos,
                    minimum(refined_sorted) + refined_y_offset - 0.1,
                    text = "d=$(round(distance, digits=3))",
                    fontsize = 8,
                    color = :gray,
                    align = (:center, :top),
                )
            end
        end

        # Add zero reference line
        GLMakie.hlines!(ax, [0], color = :black, linestyle = :dash, alpha = 0.5)

        # Add horizontal separator line to distinguish raw from refined
        GLMakie.hlines!(
            ax,
            [0],
            color = type_color,
            linestyle = :solid,
            alpha = 0.3,
            linewidth = 2,
        )
    end

    # Create legends
    n_dims = length(raw_eigenvalues) > 0 ? length(filter(!isnan, raw_eigenvalues[1])) : 3
    eigenval_legend_elements = [
        GLMakie.MarkerElement(
            color = eigenval_colors[i],
            marker = :circle,
            markersize = 10,
        ) for i = 1:min(n_dims, length(eigenval_colors))
    ]
    eigenval_legend_labels = ["λ$i" for i = 1:min(n_dims, length(eigenval_colors))]

    # Raw vs refined legend
    raw_refined_elements = [
        GLMakie.MarkerElement(
            color = :blue,
            marker = :circle,
            markersize = 10,
            alpha = 0.6,
        ),
        GLMakie.MarkerElement(
            color = :blue,
            marker = :circle,
            markersize = 10,
            alpha = 1.0,
        ),
    ]
    raw_refined_labels = ["Raw (polynomial)", "Refined (BFGS)"]

    # Add legends
    GLMakie.Legend(
        fig[1:n_types, 2],
        eigenval_legend_elements,
        eigenval_legend_labels,
        "Eigenvalue Order",
        tellheight = false,
        framevisible = true,
    )
    GLMakie.Legend(
        fig[1:n_types, 3],
        raw_refined_elements,
        raw_refined_labels,
        "Point Type",
        tellheight = false,
        framevisible = true,
    )

    return fig
end

# Export plotting functions that require GLMakie
export plot_polyapprox_3d,
    LevelSetData,
    VisualizationParameters,
    prepare_level_set_data,
    to_makie_format,
    plot_level_set,
    create_level_set_visualization,
    plot_polyapprox_rotate,
    plot_polyapprox_levelset,
    plot_polyapprox_flyover,
    plot_polyapprox_animate,
    plot_polyapprox_animate2,
    plot_hessian_norms,
    plot_condition_numbers,
    plot_critical_eigenvalues,
    plot_all_eigenvalues,
    plot_raw_vs_refined_eigenvalues

end
