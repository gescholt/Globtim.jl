using Optim
using LinearAlgebra

function analyze_critical_points(f, df_cheb::DataFrame, TR; tol_dist=0.025)
    # Initialize df_cheb columns
    df_cheb.y1 = zeros(nrow(df_cheb))
    df_cheb.y2 = zeros(nrow(df_cheb))
    df_cheb.close = falses(nrow(df_cheb))
    df_cheb.steps = zeros(nrow(df_cheb))
    df_cheb.converged = zeros(nrow(df_cheb))

    # Create df_min for collecting unique minimizers
    df_min = DataFrame(x1=Float64[], x2=Float64[], value=Float64[], captured=Bool[])

    for i in 1:nrow(df_cheb)
        try
            x0 = [df_cheb.x1[i], df_cheb.x2[i]]
            res = Optim.optimize(f, x0, LBFGS(), Optim.Options(show_trace=false))
            minimizer = Optim.minimizer(res)
            min_value = Optim.minimum(res)
            steps = res.iterations
            converged = Optim.converged(res)

            # Update df_cheb
            df_cheb.y1[i] = minimizer[1]
            df_cheb.y2[i] = minimizer[2]
            df_cheb.steps[i] = steps
            df_cheb.converged[i] = min_value

            # Check if minimizer is close to its starting point
            distance = norm([df_cheb.x1[i] - minimizer[1], df_cheb.x2[i] - minimizer[2]])
            df_cheb.close[i] = distance < tol_dist

            # Check if minimizer is within the square
            within_square = abs(minimizer[1] - TR.center[1]) <= TR.sample_range &&
                            abs(minimizer[2] - TR.center[2]) <= TR.sample_range

            if !within_square
                continue  # Skip this minimizer if it's outside the square
            end

            # Check if this minimizer is already in df_min
            is_new = true
            for j in 1:nrow(df_min)
                if norm([df_min.x1[j] - minimizer[1], df_min.x2[j] - minimizer[2]]) < tol_dist
                    is_new = false
                    break
                end
            end

            # If it's a new minimizer within range, add it to df_min
            if is_new
                # Check if it's close to any original point
                is_captured = any(norm([df_cheb.x1[k] - minimizer[1], df_cheb.x2[k] - minimizer[2]]) < tol_dist
                                  for k in 1:nrow(df_cheb))

                push!(df_min, (x1=minimizer[1], x2=minimizer[2],
                    value=min_value, captured=is_captured))
            end

        catch e
            # Set default values for error cases in df_cheb
            df_cheb.y1[i] = NaN
            df_cheb.y2[i] = NaN
            df_cheb.close[i] = false
            df_cheb.steps[i] = -1
            df_cheb.converged[i] = Inf
            continue
        end
    end

    return df_cheb, df_min
end