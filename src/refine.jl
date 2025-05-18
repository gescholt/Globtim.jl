"""
Applies a mask to the dataframe based on the hypercube defined in the test input TR. 
The mask is a boolean array where each element corresponds to a row in the dataframe. 
If the point is within the hypercube, the mask value is true; otherwise, it is false.
We have the `use_y` to run this check on the y-coordinates (optimized points) instead of 
the x-coordinates (raw critical points).

Now supports per-coordinate scaling factors.
"""
function points_in_hypercube(df::DataFrame, TR; use_y::Bool=false)
    # Count dimensions based on whether we're checking x or y columns
    prefix = use_y ? "y" : "x"
    n_dims = count(col -> startswith(string(col), prefix), names(df))

    # Create boolean array for results
    in_cube = trues(nrow(df))

    # Check each point
    for i = 1:nrow(df)
        for j = 1:n_dims
            coord = df[i, Symbol("$(prefix)$j")]

            # Skip NaN coordinates when checking y values
            if use_y && isnan(coord)
                in_cube[i] = false
                break
            end

            # Handle different sample_range types
            if isa(TR.sample_range, Number)
                # Scalar sample_range
                if abs(coord - TR.center[j]) > TR.sample_range
                    in_cube[i] = false
                    break
                end
            else
                # Vector sample_range
                if abs(coord - TR.center[j]) > TR.sample_range[j]
                    in_cube[i] = false
                    break
                end
            end
        end
    end
    return in_cube
end

"""
Filter points based on function value being within a range of the minimum value.
Now supports per-coordinate scaling.
"""
function points_in_range(df::DataFrame, TR, value_range::Float64)
    # Count x-columns to determine dimensionality
    n_dims = count(col -> startswith(string(col), "x"), names(df))

    # Create boolean array for results
    in_range = falses(nrow(df))

    # Reference value (minimum found so far)
    min_val = minimum(df.z)

    # Check each point's function evaluation
    for i = 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j = 1:n_dims]
        val = TR.objective(point)
        if abs(val - min_val) ≤ value_range
            in_range[i] = true
        end
    end

    return in_range
end

function analyze_critical_points(
    f::Function,
    df::DataFrame,
    TR::test_input;
    tol_dist=0.025,
    verbose=true,
)
    n_dims = count(col -> startswith(string(col), "x"), names(df))  # Count x-columns

    # ANSI escape codes for colored output
    green_check = "\e[32m✓\e[0m"
    red_cross = "\e[31m✗\e[0m"

    # Initialize result columns
    for i = 1:n_dims
        df[!, Symbol("y$i")] = zeros(nrow(df))
    end
    df[!, :close] = falses(nrow(df))
    df[!, :steps] = zeros(nrow(df))
    df[!, :converged] = falses(nrow(df))

    # Create df_min for collecting unique minimizers
    min_cols = [:value, :captured]
    for i = 1:n_dims
        pushfirst!(min_cols, Symbol("x$i"))
    end
    df_min = DataFrame([name => Float64[] for name in min_cols[1:end-1]])
    df_min[!, :captured] = Bool[]

    for i = 1:nrow(df)
        try
            verbose && println("Processing point $i of $(nrow(df))")

            # Extract starting point
            x0 = [df[i, Symbol("x$j")] for j = 1:n_dims]

            # Optimization
            res = Optim.optimize(f, x0, Optim.BFGS(), Optim.Options(show_trace=false))
            minimizer = Optim.minimizer(res)
            min_value = Optim.minimum(res)
            steps = res.iterations
            optim_converged = Optim.converged(res)

            # Check if minimizer is within bounds - handle both scalar and vector scaling
            within_bounds = if isa(TR.sample_range, Number)
                # Scalar sample_range case
                all(abs.(minimizer .- TR.center[1:n_dims]) .<= TR.sample_range)
            else
                # Vector sample_range case
                all(abs.(minimizer[j] - TR.center[j]) <= TR.sample_range[j] for j = 1:n_dims)
            end

            # Only mark as converged if both optimization converged AND within bounds
            converged = optim_converged && within_bounds

            # Print status with appropriate symbol
            if verbose
                println(
                    converged ? "Optimization has converged within bounds: $green_check" :
                    "Optimization status: $red_cross" *
                    (optim_converged ? " (outside bounds)" : " (did not converge)"),
                )
            end

            # Update df results
            for j = 1:n_dims
                df[i, Symbol("y$j")] = minimizer[j]
            end
            df[i, :steps] = steps
            df[i, :converged] = converged  # Updated to use new converged status

            # Check if minimizer is close to starting point
            distance = norm([df[i, Symbol("x$j")] - minimizer[j] for j = 1:n_dims])
            df[i, :close] = distance < tol_dist

            # Skip adding to df_min if outside bounds
            !within_bounds && continue

            # Check if the minimizer is new
            is_new = true
            for j = 1:nrow(df_min)
                if norm([df_min[j, Symbol("x$k")] - minimizer[k] for k = 1:n_dims]) < tol_dist
                    is_new = false
                    break
                end
            end

            # Add new unique minimizer
            if is_new
                # Check if minimizer is captured by any initial point
                is_captured = any(
                    norm([df[k, Symbol("x$j")] - minimizer[j] for j = 1:n_dims]) < tol_dist
                    for k = 1:nrow(df)
                )

                # Create new row for df_min
                new_row = Dict{Symbol,Any}()
                for j = 1:n_dims
                    new_row[Symbol("x$j")] = minimizer[j]
                end
                new_row[:value] = min_value
                new_row[:captured] = is_captured

                push!(df_min, new_row)
            end

        catch e
            verbose && println("Error processing point $i: $e")
            # Handle errors in df
            for j = 1:n_dims
                df[i, Symbol("y$j")] = NaN
            end
            df[i, :close] = false
            df[i, :steps] = -1
            df[i, :converged] = false
        end
    end

    return df, df_min
end