using Optim, LinearAlgebra, DataFrames

function analyze_critical_points(f::Function, df::DataFrame, TR::test_input; tol_dist=0.025, verbose=true)
    n_dims = count(col -> startswith(string(col), "x"), names(df))  # Count x-columns

    # ANSI escape codes for colored output
    green_check = "\e[32m✓\e[0m"
    red_cross = "\e[31m✗\e[0m"

    # Initialize result columns
    for i in 1:n_dims
        df[!, Symbol("y$i")] = zeros(nrow(df))
    end
    df[!, :close] = falses(nrow(df))
    df[!, :steps] = zeros(nrow(df))
    df[!, :converged] = falses(nrow(df))

    # Create df_min for collecting unique minimizers
    min_cols = [:value, :captured]
    for i in 1:n_dims
        pushfirst!(min_cols, Symbol("x$i"))
    end
    df_min = DataFrame([name => Float64[] for name in min_cols[1:end-1]])
    df_min[!, :captured] = Bool[]

    for i in 1:nrow(df)
        try
            verbose && println("Processing point $i of $(nrow(df))")

            # Extract starting point
            x0 = [df[i, Symbol("x$j")] for j in 1:n_dims]

            # Optimization
            res = Optim.optimize(f, x0, BFGS(), Optim.Options(show_trace=false))
            minimizer = Optim.minimizer(res)
            min_value = Optim.minimum(res)
            steps = res.iterations
            optim_converged = Optim.converged(res)

            # Check if minimizer is within bounds
            within_bounds = all(abs.(minimizer .- TR.center[1:n_dims]) .<= TR.sample_range)

            # Only mark as converged if both optimization converged AND within bounds
            converged = optim_converged && within_bounds

            # Print status with appropriate symbol
            if verbose
                println(converged ? "Optimization has converged within bounds: $green_check" :
                        "Optimization status: $red_cross" *
                        (optim_converged ? " (outside bounds)" : " (did not converge)"))
            end

            # Update df results
            for j in 1:n_dims
                df[i, Symbol("y$j")] = minimizer[j]
            end
            df[i, :steps] = steps
            df[i, :converged] = converged  # Updated to use new converged status

            # Check if minimizer is close to starting point
            distance = norm([df[i, Symbol("x$j")] - minimizer[j] for j in 1:n_dims])
            df[i, :close] = distance < tol_dist

            # Skip adding to df_min if outside bounds
            !within_bounds && continue

            # Check if the minimizer is new
            is_new = true
            for j in 1:nrow(df_min)
                if norm([df_min[j, Symbol("x$k")] - minimizer[k] for k in 1:n_dims]) < tol_dist
                    is_new = false
                    break
                end
            end

            # Add new unique minimizer
            if is_new
                # Check if minimizer is captured by any initial point
                is_captured = any(
                    norm([df[k, Symbol("x$j")] - minimizer[j] for j in 1:n_dims]) < tol_dist
                    for k in 1:nrow(df)
                )

                # Create new row for df_min
                new_row = Dict{Symbol,Any}()
                for j in 1:n_dims
                    new_row[Symbol("x$j")] = minimizer[j]
                end
                new_row[:value] = min_value
                new_row[:captured] = is_captured

                push!(df_min, new_row)
            end

        catch e
            verbose && println("Error processing point $i: $e")
            # Handle errors in df
            for j in 1:n_dims
                df[i, Symbol("y$j")] = NaN
            end
            df[i, :close] = false
            df[i, :steps] = -1
            df[i, :converged] = false
        end
    end

    return df, df_min
end

"""
Counts how many dimensions the problem has by counting columns that start with "x" in the DataFrame. Then it filters the DataFrame to keep only the rows where optimization converged successfully (where df.converged is true).
For each of these successful cases, it:

Takes the starting point (the x-coordinates: x1, x2, etc.)
Takes where that point ended up after optimization (the y-coordinates: y1, y2, etc.)
Calculates the Euclidean distance between these two points
Stores this distance in an array

Finally, it returns a named tuple containing:

The largest distance any point moved
The average distance points moved
All individual distances
How many points converged successfully
"""
function analyze_convergence_distances(df::DataFrame)
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Only look at converged points
    converged_points = df[df.converged, :]

    # Check for empty converged points first
    if isempty(converged_points)
        return (
            maximum=0.0,
            average=0.0,
            distances=Float64[],
            n_converged=0
        )
    end

    distances = Float64[]

    # For each converged point, compute distance between start and end
    for row in eachrow(converged_points)
        start_point = [row[Symbol("x$j")] for j in 1:n_dims]
        end_point = [row[Symbol("y$j")] for j in 1:n_dims]

        distance = norm(end_point - start_point)
        push!(distances, distance)
    end

    return (
        maximum=maximum(distances),
        average=mean(distances),
        distances=distances,
        n_converged=length(distances)
    )
end

function analyze_captured_distances(df::DataFrame)
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Only look at converged points
    converged_points = df[df.captured, :]
    distances = Float64[]

    # For each converged point, compute distance between start and end
    for row in eachrow(converged_points)
        start_point = [row[Symbol("x$j")] for j in 1:n_dims]
        end_point = [row[Symbol("y$j")] for j in 1:n_dims]

        distance = norm(end_point - start_point)
        push!(distances, distance)
    end

    return (
        maximum=maximum(distances),
        average=mean(distances),
        distances=distances,
        n_converged=length(distances)
    )
end


"""
This function analyze_degrees performs polynomial approximation analysis across different polynomial degrees. Here's what it does:
The function takes three arguments:

TR: A structure containing the objective function and other problem parameters
start_degree: The lowest polynomial degree to analyze
end_degree: The highest polynomial degree to analyze
An optional step parameter (defaulting to 2) that determines the increment between degrees
"""
# function analyze_degrees(TR, x, start_degree::Int, end_degree::Int, previous_results=nothing; step::Int=2, tol_dist::Float64=0.1)
#     # Initialize storage for results
#     results = Dict{Int,NamedTuple{(:df, :df_min, :convergence_stats, :discrete_l2),
#         Tuple{DataFrame,DataFrame,NamedTuple,Float64}}}()

#     for d in start_degree:step:end_degree
#         if isnothing(previous_results)
#             # Construct polynomial approximation
#             pol_cheb = Constructor(TR, d, basis=:chebyshev)
#             df_cheb = solve_and_parse(pol_cheb, x, TR.objective, TR)
#             discrete_l2 = pol_cheb.nrm
#         else
#             # Reuse previous results
#             df_cheb = previous_results[d].df
#             discrete_l2 = previous_results[d].discrete_l2
#         end

#         # Analyze critical points with new tolerance
#         df_cheb, df_min_cheb = analyze_critical_points(TR.objective, df_cheb, TR, tol_dist=tol_dist)

#         # Analyze convergence distances
#         conv_stats = analyze_convergence_distances(df_cheb)

#         # Store results
#         results[d] = (
#             df=df_cheb,
#             df_min=df_min_cheb,
#             convergence_stats=conv_stats,
#             discrete_l2=discrete_l2
#         )
#     end

#     return results
# end

function analyze_degrees(TR, x, start_degree::Int, end_degree::Int, previous_results=nothing; step::Int=2, tol_dist::Float64=0.1)
    # Initialize storage for results
    results = Dict{Int,NamedTuple{(:df, :df_min, :convergence_stats, :discrete_l2),
        Tuple{DataFrame,DataFrame,NamedTuple,Float64}}}()

    for d in start_degree:step:end_degree
        if isnothing(previous_results)
            # Fresh computation
            pol_cheb = Constructor(TR, d, basis=:chebyshev)
            df_cheb = solve_and_parse(pol_cheb, x, TR.objective, TR)
            discrete_l2 = pol_cheb.nrm
        else
            # Reuse previous polynomial results, only reanalyze critical points
            df_cheb = previous_results[d].df
            discrete_l2 = previous_results[d].discrete_l2
        end

        # Analyze critical points with new tolerance
        df_cheb, df_min_cheb = analyze_critical_points(TR.objective, df_cheb, TR, tol_dist=tol_dist)
        conv_stats = analyze_convergence_distances(df_cheb)

        results[d] = (
            df=df_cheb,
            df_min=df_min_cheb,
            convergence_stats=conv_stats,
            discrete_l2=discrete_l2
        )
    end

    return results
end

"""
Applies a mask to the dataframe based on the hypercube defined in the test input TR. The mask is a boolean array where each element corresponds to a row in the dataframe. If the point is within the hypercube, the mask value is true; otherwise, it is false. We have the `use_y` to run this check on the y-coordinates (optimized points) instead of the x-coordinates (raw critical points).
"""
function points_in_hypercube(df::DataFrame, TR; use_y::Bool=false)
    # Count dimensions based on whether we're checking x or y columns
    prefix = use_y ? "y" : "x"
    n_dims = count(col -> startswith(string(col), prefix), names(df))

    # Create boolean array for results
    in_cube = trues(nrow(df))

    # Check each point
    for i in 1:nrow(df)
        for j in 1:n_dims
            coord = df[i, Symbol("$(prefix)$j")]
            # Skip NaN coordinates when checking y values
            if use_y && isnan(coord)
                in_cube[i] = false
                break
            end
            if abs(coord - TR.center[j]) > TR.sample_range
                in_cube[i] = false
                break
            end
        end
    end
    return in_cube
end

function points_in_range(df::DataFrame, TR, value_range::Float64)
    # Count x-columns to determine dimensionality
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Create boolean array for results
    in_range = falses(nrow(df))

    # Reference value (minimum found so far)
    min_val = minimum(df.z)

    # Check each point's function evaluation
    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:n_dims]
        val = TR.objective(point)
        if abs(val - min_val) ≤ value_range
            in_range[i] = true
        end
    end

    return in_range
end

function compute_min_distances(df, df_check)
    # Initialize array to store minimum distances
    min_distances = Float64[]

    # For each row in df, find distance to closest point in df_check
    for i in 1:nrow(df)
        point = Array(df[i, :])  # Convert row to array
        min_dist = Inf

        # Compare with each point in df_check
        for j in 1:nrow(df_check)
            check_point = Array(df_check[j, :])
            dist = norm(point - check_point)  # Euclidean distance
            min_dist = min(min_dist, dist)
        end

        push!(min_distances, min_dist)
    end

    return min_distances
end

function analyze_captured_distances(df, df_check)
    if isempty(df)  # Check if dataframe is empty
        return (max_dist=0.0, mean_dist=0.0, num_points=0)
    end
    distances = compute_min_distances(df, df_check)
    return (
        maximum=maximum(distances),
        average=mean(distances)
    )
end

function analyze_captured_distances(df, df_check)
    if isempty(df)  # Check if dataframe is empty
        return (max_dist=0.0, mean_dist=0.0, num_points=0)
    end
    distances = compute_min_distances(df, df_check)
    return (
        maximum=maximum(distances),
        average=sum(distances) / length(distances)
    )
end

function analyze_captured_distances(df, df_check)
    if isempty(df)
        return (max_dist=0.0, mean_dist=0.0, num_points=0)
    end
    distances = compute_min_distances(df, df_check)
    return (
        maximum=maximum(distances),
        average=mean(distances)
    )
end

function analyze_converged_points(
    df_filtered::DataFrame,
    TR::test_input,
    results::Dict{Int,NamedTuple{(:df, :df_min, :convergence_stats, :discrete_l2),
        Tuple{DataFrame,DataFrame,NamedTuple,Float64}}},
    start_degree::Int,
    end_degree::Int,
    step::Int=1)

    degrees = start_degree:step:end_degree
    n_dims = count(col -> startswith(string(col), "x"), names(df_filtered))

    # Filter for converged points first
    df_converged = df_filtered[df_filtered.converged, :]

    # Filter for points where y is in domain and not NaN
    valid_points = trues(nrow(df_converged))
    for i in 1:nrow(df_converged)
        # Check if y coordinates are NaN
        y_coords = [df_converged[i, Symbol("y$j")] for j in 1:n_dims]
        if any(isnan.(y_coords))
            valid_points[i] = false
            continue
        end

        # Check if y coordinates are in domain
        for j in 1:n_dims
            if abs(df_converged[i, Symbol("y$j")] - TR.center[j]) > TR.sample_range
                valid_points[i] = false
                break
            end
        end
    end

    df_valid = df_converged[valid_points, :]
    n_valid_points = nrow(df_valid)

    # Initialize distance matrix
    point_distances = zeros(Float64, n_valid_points, length(degrees))

    # Calculate distances
    for (i, row) in enumerate(eachrow(df_valid))
        y_coords = [row[Symbol("y$j")] for j in 1:n_dims]

        for (d_idx, d) in enumerate(degrees)
            raw_points = results[d].df
            min_dist = Inf

            for raw_row in eachrow(raw_points)
                point = [raw_row[Symbol("x$j")] for j in 1:n_dims]
                dist = norm(y_coords - point)
                min_dist = min(min_dist, dist)
            end
            point_distances[i, d_idx] = min_dist
        end
    end

    # Calculate statistics
    stats = Dict{String,Any}()

    # Per-degree statistics
    stats["max_distances"] = [maximum(point_distances[:, i]) for i in 1:length(degrees)]
    stats["min_distances"] = [minimum(point_distances[:, i]) for i in 1:length(degrees)]
    stats["avg_distances"] = [mean(point_distances[:, i]) for i in 1:length(degrees)]

    # Overall statistics
    stats["overall_max"] = maximum(stats["max_distances"])
    stats["overall_min"] = minimum(stats["min_distances"])
    stats["overall_avg"] = mean(stats["avg_distances"])

    # Additional metadata
    stats["n_total_points"] = nrow(df_filtered)
    stats["n_converged"] = nrow(df_converged)
    stats["n_valid"] = n_valid_points
    stats["degrees"] = collect(degrees)

    return stats
end
