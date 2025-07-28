"""
    plot_polyapprox_3d(
        pol::ApproxPoly,
        TR::test_input,
        df::DataFrame,
        df_min::DataFrame;
        figure_size::Tuple{Int,Int} = (1000, 800),
        z_limits::Union{Nothing,Tuple{Float64,Float64}} = nothing,
        show_captured::Bool = true,
        alpha_surface::Float64 = 0.7,
        rotate::Bool = false,
        filename::String = "function_3d_rotation.mp4"
    )

Creates a 3D visualization of a polynomial approximation with critical points.
Similar in usage to cairo_plot_polyapprox_levelset but renders a 3D surface.

# Returns
- `fig`: The GLMakie figure object
"""
function Globtim.plot_polyapprox_3d(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 800),
    z_limits::Union{Nothing, Tuple{Float64, Float64}} = nothing,
    show_captured::Bool = true,
    alpha_surface::Float64 = 0.7,
    rotate::Bool = false,
    filename::String = "function_3d_rotation.mp4",
    fade::Bool = false,
    z_cut = 0.25
)
    # Type-stable coordinate transformation using multiple dispatch
    coords = transform_coordinates(pol.scale_factor, pol.grid, TR.center)

    z_coords = pol.z

    if size(coords)[2] == 2
        # Create figure
        fig = Figure(size = figure_size)
        ax = Axis3(
            fig[1, 1],
            # title = "",
            xlabel = "x₁",
            ylabel = "x₂",
            zlabel = ""
        )

        # Calculate z_limits if not provided
        if isnothing(z_limits)
            z_values = Float64[]
            append!(z_values, df.z)
            append!(z_values, df_min.value)
            append!(z_values, z_coords)
            z_limits = (minimum(z_values), maximum(z_values))
        end

        # Prepare surface data
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        # Calculate threshold for the fade effect (last 10% of z range)
        z_threshold = z_limits[2] - z_cut * (z_limits[2] - z_limits[1])

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                # Apply z-limits to clip the surface
                if !isnothing(z_limits) && (z < z_limits[1] || z > z_limits[2])
                    # Set points outside the range to NaN to make them invisible
                    Z[j, i] = NaN
                else
                    Z[j, i] = z
                end
            end
        end

        # For fade effect, we'll create two surfaces:
        # 1. Main surface for z < z_threshold with normal alpha
        # 2. Faded surface for z >= z_threshold with decreasing alpha
        if fade
            # Create two separate Z matrices
            Z_lower = copy(Z)
            Z_upper = copy(Z)

            # Mask the matrices to separate lower and upper parts
            for i in 1:size(Z, 1)
                for j in 1:size(Z, 2)
                    if !isnan(Z[i, j])
                        if Z[i, j] >= z_threshold
                            Z_lower[i, j] = NaN
                        else
                            Z_upper[i, j] = NaN
                        end
                    end
                end
            end

            # Plot the lower (non-faded) surface with normal alpha
            surf_lower = surface!(
                ax,
                x_unique,
                y_unique,
                Z_lower,
                colormap = :viridis,
                transparency = true,
                alpha = alpha_surface,
                colorrange = z_limits
            )

            # Plot the upper (faded) part with gradually decreasing alpha
            for fade_level in 1:10
                # Calculate alpha for this level
                fade_alpha = alpha_surface * (1.0 - (fade_level - 1) / 10 * 0.9)

                # Calculate z range for this level
                z_min = z_threshold + (fade_level - 1) / 10 * (z_limits[2] - z_threshold)
                z_max = z_threshold + fade_level / 10 * (z_limits[2] - z_threshold)

                # Create a Z matrix for this level
                Z_level = copy(Z)
                for i in 1:size(Z, 1)
                    for j in 1:size(Z, 2)
                        if isnan(Z[i, j]) || Z[i, j] < z_min || Z[i, j] >= z_max
                            Z_level[i, j] = NaN
                        end
                    end
                end

                # Plot this level
                surf_level = surface!(
                    ax,
                    x_unique,
                    y_unique,
                    Z_level,
                    colormap = :viridis,
                    transparency = true,
                    alpha = fade_alpha,
                    colorrange = z_limits
                )
            end
        else
            # Plot the entire surface with uniform alpha
            surf = surface!(
                ax,
                x_unique,
                y_unique,
                Z,
                colormap = :viridis,
                transparency = true,
                alpha = alpha_surface,
                colorrange = z_limits
            )
        end

        # Set initial camera position
        ax.azimuth[] = 3π / 4
        ax.elevation[] = π / 6

        # Plot points from df with appropriate colors
        if :close in propertynames(df)
            # Points close to critical levels
            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    df.z[close_idx],
                    markersize = 10,
                    color = :green,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Near"
                )
            end

            # Points not close to critical levels
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize = 8,
                    color = :white,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Far"
                )
            end
        else
            # All points if there's no close/far distinction
            scatter!(
                ax,
                df.x1,
                df.x2,
                df.z,
                markersize = 20,
                color = :orange,
                label = "All Points"
            )
        end

        # Plot minima points from df_min
        if !isempty(df_min)
            # Plot uncaptured critical points
            uncaptured_idx = .!df_min.captured
            if any(uncaptured_idx)
                scatter!(
                    ax,
                    df_min.x1[uncaptured_idx],
                    df_min.x2[uncaptured_idx],
                    df_min.value[uncaptured_idx],
                    markersize = 40,
                    marker = :diamond,
                    color = :red,
                    label = "Uncaptured"
                )
            end

            # Plot captured critical points if show_captured is true
            if show_captured
                captured_idx = df_min.captured
                if any(captured_idx)
                    scatter!(
                        ax,
                        df_min.x1[captured_idx],
                        df_min.x2[captured_idx],
                        df_min.value[captured_idx],
                        markersize = 40,
                        marker = :diamond,
                        color = :blue,
                        label = "Captured"
                    )
                end
            end
        end

        # Optional: Create animation if requested
        if rotate
            @info "Recording animation to $(filename)..."
            record(fig, filename, 1:240; framerate = 30) do frame
                ax.azimuth[] = 3π / 4 + 2π * frame / 240
                ax.elevation[] = π / 6 + π / 12 * sin(2π * frame / 240)
            end
            @info "Animation saved to $(filename)!"
        end

        display(fig)
        return fig
    else
        @warn "Function only works with 2D grid data"
        return nothing
    end
end
