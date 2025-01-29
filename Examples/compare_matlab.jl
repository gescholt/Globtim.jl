using LinearAlgebra

"""
    comp_matlab(f::Function, df::DataFrame, TR::test_input, matlab_df::DataFrame;
               tol_dist=0.025, verbose=true) -> Tuple{DataFrame, DataFrame, DataFrame}

Compare critical points found by Julia's optimization routine with those found by MATLAB.

# Arguments
- `f::Function`: The objective function being minimized
- `df::DataFrame`: DataFrame containing the optimization results from Julia
- `TR::test_input`: Test input parameters used for the optimization
- `matlab_df::DataFrame`: DataFrame containing the critical points found by MATLAB
- `tol_dist::Float64=0.025`: Tolerance distance for considering points as matching
- `verbose::Bool=true`: Whether to print comparison summary

# Returns
A tuple of three DataFrames:
- First DataFrame: Complete optimization results
- Second DataFrame: Minimizer points from Julia
- Third DataFrame: Extended comparison results containing both Julia and MATLAB points

# Extended DataFrame Columns
- `x1, x2, ...`: Coordinates of the critical points
- `value`: Function value at the critical point
- `captured`: Boolean indicating if the point was found during optimization
- `matlab_match`: Boolean indicating if the point matches a MATLAB result

# Details
The function performs the following operations:
1. Analyzes critical points from Julia optimization results
2. Matches Julia-found points with MATLAB results using the tolerance distance
3. Adds any MATLAB points not found by Julia to the comparison
4. If verbose=true, prints a summary showing:
   - Number of matching points between Julia and MATLAB
   - Number of points found only by Julia
   - Number of points found only by MATLAB

# Example
```julia
f(x) = x[1]^2 + x[2]^2
julia_results = DataFrame(x1=[0.0], x2=[0.0], value=[0.0])
matlab_results = DataFrame(x1=[0.001], x2=[0.001])
TR = test_input(dims=2)

df, df_min, comparison = comp_matlab(f, julia_results, TR, matlab_results)
Notes

The number of dimensions is automatically determined from the input DataFrame columns
Column names in the MATLAB DataFrame are automatically renamed to match Julia convention
Points are considered matching if their Euclidean distance is less than tol_dist
"""
function comp_matlab(f::Function, df::DataFrame, TR::test_input, matlab_df::DataFrame;
    tol_dist=0.025, verbose=true)
    df, df_min = analyze_critical_points(f, df, TR; tol_dist=tol_dist, verbose=verbose)

    n_dims = count(col -> startswith(string(col), "x"), names(df))
    if size(matlab_df, 2) != n_dims
        error("MATLAB DataFrame must contain exactly $n_dims columns for the coordinates")
    end

    col_names = [Symbol("x$i") for i in 1:n_dims]
    rename!(matlab_df, col_names)

    min_cols = [:value, :captured, :matlab_match]
    for i in 1:n_dims
        pushfirst!(min_cols, Symbol("x$i"))
    end
    df_ext = DataFrame([name => Float64[] for name in min_cols[1:end-2]])
    df_ext[!, :captured] = Bool[]
    df_ext[!, :matlab_match] = Bool[]

    for i in 1:nrow(df_min)
        current_point = [df_min[i, Symbol("x$j")] for j in 1:n_dims]
        matlab_match = false
        for j in 1:nrow(matlab_df)
            matlab_point = [matlab_df[j, Symbol("x$k")] for k in 1:n_dims]
            if norm(current_point - matlab_point) < tol_dist
                matlab_match = true
                break
            end
        end

        new_row = Dict{Symbol,Any}()
        for j in 1:n_dims
            new_row[Symbol("x$j")] = current_point[j]
        end
        new_row[:value] = df_min[i, :value]
        new_row[:captured] = df_min[i, :captured]
        new_row[:matlab_match] = matlab_match
        push!(df_ext, new_row)
    end

    for i in 1:nrow(matlab_df)
        matlab_point = [matlab_df[i, Symbol("x$j")] for j in 1:n_dims]
        is_new = true
        for j in 1:nrow(df_ext)
            current_point = [df_ext[j, Symbol("x$k")] for k in 1:n_dims]
            if norm(matlab_point - current_point) < tol_dist
                is_new = false
                break
            end
        end

        if is_new
            min_value = f(matlab_point)
            is_captured = any(
                norm([df[k, Symbol("x$j")] - matlab_point[j] for j in 1:n_dims]) < tol_dist
                for k in 1:nrow(df)
            )

            new_row = Dict{Symbol,Any}()
            for j in 1:n_dims
                new_row[Symbol("x$j")] = matlab_point[j]
            end
            new_row[:value] = min_value
            new_row[:captured] = is_captured
            new_row[:matlab_match] = true
            push!(df_ext, new_row)
        end
    end

    if verbose
        n_matches = count(df_ext.matlab_match)
        n_julia_only = count(.!df_ext.matlab_match)
        n_matlab_total = nrow(matlab_df)

        println("\nComparison Summary:")
        println("Matching points: $n_matches")
        println("Globtim-only points: $n_julia_only")
        println("Chebfun2-only points: $(n_matlab_total - n_matches)")
    end

    return df, df_min, df_ext
end



"""
    plot_optimization_comparison(df_ext::DataFrame, 
                              TR::test_input;
                              figure_size::Tuple{Int,Int}=(1000, 600),
                              z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
                              num_levels::Int=30) -> Figure

Create a level set plot comparing optimization results from Globtim and Chebfun2.

# Arguments
- `df_ext::DataFrame`: Extended comparison DataFrame from comp_matlab function
- `TR::test_input`: Test input parameters containing objective function, center and scale information
- `figure_size::Tuple{Int,Int}=(1000, 600)`: Size of the output figure in pixels
- `z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing`: Optional limits for z-axis
- `num_levels::Int=30`: Number of contour levels to plot

# Returns
- `Figure`: The generated figure object

# Point Categories
- White circles (black boundary): All Chebfun2 critical points
- Blue diamonds (black boundary): Points both captured by Julia and matching MATLAB
- Green diamonds: Points captured by Julia but not matching MATLAB
- Red circles: Points only found by MATLAB (not captured by Julia)
"""
function plot_optimization_comparison(
    df_ext::DataFrame,
    TR::test_input;
    figure_size::Tuple{Int,Int}=(1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
    num_levels::Int=30
)
    # Create figure
    fig = Figure(size=figure_size)
    ax = Axis(fig[1, 1], title="Optimization Results Comparison")

    # Calculate bounds based on TR
    radius = TR.sample_range
    center = TR.center
    x_range = (center[1] - radius, center[1] + radius)
    y_range = (center[2] - radius, center[2] + radius)

    # Prepare grid for contour plot
    resolution = 100
    x_unique = range(x_range[1], x_range[2], length=resolution)
    y_unique = range(y_range[1], y_range[2], length=resolution)
    Z = [TR.objective([x, y]) for y in y_unique, x in x_unique]

    # Calculate z_limits if not provided
    if isnothing(z_limits)
        z_values = df_ext.value
        z_limits = (minimum(z_values)*1.01, maximum(Z))
    end

    # Create contour plot
    chosen_colormap = :inferno
    contourf!(ax, x_unique, y_unique, Z,
        colormap=chosen_colormap,
        levels=num_levels)

    # Plot points with different styles based on categories

    # 1. All points as basic Chebfun2 critical points (white circles with black boundary)
    scatter!(ax, df_ext.x1, df_ext.x2,
        markersize=10,
        color=:white,
        strokecolor=:black,
        strokewidth=1,
        label="Chebfun2 critical points")

    # 2. Points captured by Julia and matching MATLAB (blue diamonds with black boundary)
    both_idx = df_ext.captured .& df_ext.matlab_match
    if any(both_idx)
        scatter!(ax, df_ext.x1[both_idx], df_ext.x2[both_idx],
            color=:blue,
            marker=:diamond,
            markersize=15,
            strokecolor=:black,
            strokewidth=1,
            label="Globtim & Chebfun")
    end

    # 3. Points only captured by Julia (green diamonds)
    julia_only_idx = df_ext.captured .& .!df_ext.matlab_match
    if any(julia_only_idx)
        scatter!(ax, df_ext.x1[julia_only_idx], df_ext.x2[julia_only_idx],
            color=:green,
            marker=:diamond,
            markersize=15,
            label="Globtim only")
    end

    # 4. Points only found by MATLAB (red circles)
    matlab_only_idx = .!df_ext.captured .& df_ext.matlab_match
    if any(matlab_only_idx)
        scatter!(ax, df_ext.x1[matlab_only_idx], df_ext.x2[matlab_only_idx],
            color=:red,
            markersize=10,
            label="Chebfun2 only")
    end

    # Add legend
    # Legend(fig[1, 2], ax, "Critical Points",tellwidth=true)

    # Add colorbar
    # Colorbar(fig[1, 3],
    #     limits=z_limits,
    #     colormap=chosen_colormap,
    #     label="Objective Value")

    # Set axis labels
    ax.xlabel = "x₁"
    ax.ylabel = "x₂"

    return fig
end

"""
    comp_min_cheb(df_min_cheb::DataFrame, df_matlab::DataFrame;
                 tol_dist::Float64=0.025, verbose::Bool=true) -> DataFrame

Compare critical points found in df_min_cheb with those from MATLAB/Chebfun2.

# Arguments
- `df_min_cheb::DataFrame`: DataFrame with columns x1, x2, value, captured
- `df_matlab::DataFrame`: DataFrame with columns x1, x2
- `tol_dist::Float64=0.025`: Tolerance distance for considering points as matching
- `verbose::Bool=true`: Whether to print comparison summary

# Returns
DataFrame with columns:
- `x1, x2`: Coordinates of the critical points
- `value`: Function value at the critical point
- `captured`: Original captured status from df_min_cheb
- `matlab_match`: Boolean indicating if the point matches a MATLAB/Chebfun2 result
"""
function comp_min_cheb(df_min_cheb::DataFrame, df_matlab::DataFrame;
    tol_dist::Float64=0.025, verbose::Bool=true)

    # Initialize result DataFrame
    df_comp = DataFrame(
        x1=Float64[],
        x2=Float64[],
        value=Float64[],
        captured=Bool[],
        matlab_match=Bool[]
    )

    # Process each point in df_min_cheb
    for i in 1:nrow(df_min_cheb)
        point = [df_min_cheb[i, "x1"], df_min_cheb[i, "x2"]]

        # Check if point matches any MATLAB/Chebfun2 point
        matlab_match = any(1:nrow(df_matlab)) do j
            matlab_point = [df_matlab[j, "x1"], df_matlab[j, "x2"]]
            norm(point - matlab_point) < tol_dist
        end

        # Add point to comparison DataFrame
        push!(df_comp,
            (x1=point[1],
                x2=point[2],
                value=df_min_cheb[i, "value"],
                captured=df_min_cheb[i, "captured"],
                matlab_match=matlab_match))
    end

    if verbose
        n_total = nrow(df_min_cheb)
        n_captured = count(df_comp.captured)
        n_matlab_match = count(df_comp.matlab_match)
        n_both = count(df_comp.captured .& df_comp.matlab_match)

        println("\nComparison Summary:")
        println("Total points analyzed: $n_total")
        println("Points captured with Optim step: $n_captured")
        println("Points matching Chebfun2: $n_matlab_match")
        println("Points both captured and matching: $n_both")
    end

    return df_comp
end

function plot_critical_points_comparison(
    df_comp::DataFrame,
    pol::ApproxPoly,
    TR::test_input;
    figure_size::Tuple{Int,Int}=(1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
    num_levels::Int=30,
    chebyshev_levels::Bool=false
)
    # Create figure
    fig = Figure(size=figure_size)
    ax = Axis(fig[1, 1], title="Critical Points Comparison")

    # Get coordinates from polynomial approximation
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    # Verify we're working with 2D data
    if size(coords)[2] != 2
        error("Only 2D problems are supported")
    end

    # Calculate z_limits if not provided
    if isnothing(z_limits)
        z_values = df_comp.value
        z_limits = (minimum(z_values), maximum(z_coords))
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
    contourf!(ax, x_unique, y_unique, Z,
        colormap=chosen_colormap,
        levels=levels)

    # Plot points by category
    # Both captured and matlab_match
    both_mask = df_comp.captured .& df_comp.matlab_match
    if any(both_mask)
        scatter!(ax, df_comp[both_mask, :x1], df_comp[both_mask, :x2],
            color=:green, markersize=10, strokecolor=:black, strokewidth=1,
            label="Globtim & Chebfun2")
    end

    # Only captured
    only_captured = df_comp.captured .& .!df_comp.matlab_match
    if any(only_captured)
        scatter!(ax, df_comp[only_captured, :x1], df_comp[only_captured, :x2],
            color=:blue, markersize=10, strokecolor=:black, strokewidth=1,
            label="Only Globtim")
    end

    # Only matlab_match
    only_matlab = .!df_comp.captured .& df_comp.matlab_match
    # if any(only_matlab)
    #     scatter!(ax, df_comp[only_matlab, :x1], df_comp[only_matlab, :x2],
    #         color=:red, markersize=10, strokecolor=:black, strokewidth=1,
    #         label="Only Chebfun2")
    # end

    # Add legend and colorbar
    Legend(fig[1, 2], ax, "Critical Points",
        tellwidth=true)
    Colorbar(fig[1, 3],
        limits=z_limits,
        colormap=chosen_colormap,
        label="Objective Value")

    # Set axis labels
    ax.xlabel = "x₁"
    ax.ylabel = "x₂"

    return fig
end

"""
    merge_matlab_points(df_cheb::DataFrame, df_matlab::DataFrame; 
                            tol_dist::Float64=0.025) -> DataFrame

Merge optimization points from Julia and Chebfun2 results, categorizing them based on source and proximity.

# Arguments
- `df_cheb::DataFrame`: DataFrame with Julia points (must contain x1, x2, z columns)
- `df_matlab::DataFrame`: DataFrame with Chebfun2 [MATLAB] points (must contain x1, x2 columns)
- `tol_dist::Float64=0.025`: Distance threshold for considering points as matching

# Returns
DataFrame with columns:
- `x1, x2`: Point coordinates
- `value`: Function value at point (z from Julia)
- `source`: String indicating point origin ("Julia", "Chebfun2", or "both")
"""
function merge_optimization_points(df_cheb::DataFrame, df_matlab::DataFrame;
    tol_dist::Float64=0.025)
    # Initialize combined DataFrame with consistent column names
    combined_df = DataFrame(x1=Float64[], x2=Float64[], value=Float64[], source=String[])

    # Process Chebfun2 points
    for i in 1:nrow(df_cheb)
        cheb_point = [df_cheb[i, "x1"], df_cheb[i, "x2"]]

        # Check if point matches any MATLAB point
        matches_matlab = any(1:nrow(df_matlab)) do j
            matlab_point = [df_matlab[j, "x1"], df_matlab[j, "x2"]]
            norm(cheb_point - matlab_point) < tol_dist
        end

        push!(combined_df,
            (x1=cheb_point[1],
                x2=cheb_point[2],
                value=df_cheb[i, "z"],
                source=matches_matlab ? "both" : "Julia"))
    end

    # Add MATLAB points that don't match any Chebfun2 point
    for i in 1:nrow(df_matlab)
        matlab_point = [df_matlab[i, "x1"], df_matlab[i, "x2"]]

        # Check if point is new
        is_new = !any(1:nrow(combined_df)) do j
            existing_point = [combined_df[j, :x1], combined_df[j, :x2]]
            norm(matlab_point - existing_point) < tol_dist
        end

        if is_new
            # For new MATLAB points, we take the z-value from the nearest Chebfun2 point
            nearest_idx = argmin([norm(matlab_point - [df_cheb[j, "x1"], df_cheb[j, "x2"]])
                                  for j in 1:nrow(df_cheb)])
            value = df_cheb[nearest_idx, "z"]

            push!(combined_df,
                (x1=matlab_point[1],
                    x2=matlab_point[2],
                    value=value,
                    source="Chebfun2"))
        end
    end

    return combined_df
end

"""
    plot_optimization_comparison(combined_df::DataFrame,
                              pol::ApproxPoly,
                              TR::test_input;
                              figure_size::Tuple{Int,Int}=(1000, 600),
                              z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
                              num_levels::Int=30,
                              chebyshev_levels::Bool=false) -> Figure

Create a level set plot comparing optimization results using polynomial approximation data.

# Arguments
- `combined_df::DataFrame`: DataFrame from merge_optimization_points
- `pol::ApproxPoly`: Polynomial approximation data
- `TR::test_input`: Test input parameters
- `figure_size::Tuple{Int,Int}=(1000, 600)`: Size of the output figure
- `z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing`: Optional limits for z-axis
- `num_levels::Int=30`: Number of contour levels
- `chebyshev_levels::Bool=false`: Whether to use Chebyshev nodes for contour levels

# Point Categories
- Green circles: Points found by both methods
- Blue circles: Points found only by Chebfun2
- White circles: Points found only by MATLAB
"""
function plot_matlab_comparison(
    combined_df::DataFrame,
    pol::ApproxPoly,
    TR::test_input;
    figure_size::Tuple{Int,Int}=(1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
    num_levels::Int=30,
    chebyshev_levels::Bool=false
)
    # Create figure
    fig = Figure(size=figure_size)
    ax = Axis(fig[1, 1], title="")

    # Get coordinates from polynomial approximation
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    # Verify we're working with 2D data
    if size(coords)[2] != 2
        error("Only 2D problems are supported")
    end

    # Calculate z_limits if not provided
    if isnothing(z_limits)
        z_values = combined_df.value
        z_limits = (minimum(z_values), maximum(z_coords))
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
    contourf!(ax, x_unique, y_unique, Z,
        colormap=chosen_colormap,
        levels=levels)

    for (category, color) in [("both", :green), ("Julia", :blue), ("Chebfun2", :white)]
        mask = combined_df.source .== category
        if any(mask)
            scatter!(ax, combined_df[mask, :x1], combined_df[mask, :x2],
                markersize=10,
                color=color,
                strokecolor=:black,
                strokewidth=1,
                label=category == "both" ? "Captured by both" :
                      category == "Julia" ? "Julia only" : "Chebfun2 only")
        end
    end

    # Add legend and colorbar
    # Legend(fig[1, 2], ax, "Critical Points",
    #     tellwidth=true)
    # Colorbar(fig[1, 3],
    #     limits=z_limits,
    #     colormap=chosen_colormap,
    #     label="Objective Value")

    # Set axis labels
    ax.xlabel = "x₁"
    ax.ylabel = "x₂"

    return fig
end