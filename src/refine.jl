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
            converged = Optim.converged(res)

            # Print green checkmark if converged
            if verbose
                println(converged ? "Optimization has converged: $green_check" : "Optimization has converged: $red_cross")
            end

            # Update df results
            for j in 1:n_dims
                df[i, Symbol("y$j")] = minimizer[j]
            end
            df[i, :steps] = steps
            df[i, :converged] = converged

            # Check if minimizer is close to starting point
            distance = norm([df[i, Symbol("x$j")] - minimizer[j] for j in 1:n_dims])
            df[i, :close] = distance < tol_dist

            # Check if minimizer is within bounds
            within_bounds = all(abs.(minimizer .- TR.center[1:n_dims]) .<= TR.sample_range)

            !within_bounds && continue  # Skip if outside bounds

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