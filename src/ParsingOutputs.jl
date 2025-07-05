"""
    process_crit_pts(
        real_pts::Vector{<:AbstractVector},
        f::Function,
        TR::test_input;
        skip_filtering::Bool = false,
        kwargs...
    )::DataFrame

Process critical points in n-dimensional space and return a DataFrame.
Points are automatically filtered to the [-1,1]^n hypercube (unless skip_filtering is true)
and transformed according to the test_input parameters.

# Arguments
- `real_pts`: Vector of points in n-dimensional space
- `f`: Function to evaluate at each point
- `TR`: test_input struct containing dimension, center, and sample range information
- `skip_filtering`: If true, skips the [-1,1] bounds filtering (default: false)
- `kwargs...`: Additional arguments for future extensions

# Returns
- DataFrame with columns x1, x2, ..., xn (for n dimensions) and z (function values)
"""
function process_crit_pts(
    real_pts::Vector{<:AbstractVector},
    f::Function,
    TR::test_input;
    skip_filtering::Bool=false,
    kwargs...
)::DataFrame
    # Validate input dimensions
    if !all(p -> length(p) == TR.dim, real_pts)
        error("All points must have the same dimension as TR.dim ($(TR.dim))")
    end

    # Apply filtering only if skip_filtering is false
    filtered_points = real_pts
    if !skip_filtering
        # Filter points in [-1,1]^n hypercube
        filtered_points = filter(p -> all(-1 .<= p .<= 1), real_pts)

        # Handle case where all points were filtered out
        if isempty(filtered_points) && !isempty(real_pts)
            # Find the maximum absolute value
            max_abs_val = maximum(abs.(reduce(vcat, real_pts)))

            # If the points are not too far outside, use them anyway
            if max_abs_val < 10.0
                filtered_points = real_pts
            end
        end
    end

    # Handle case with no valid points
    if isempty(filtered_points)
        result = Dict(Symbol("x$i") => Float64[] for i = 1:TR.dim)
        result[:z] = Float64[]
        return DataFrame(result)
    end

    # Transform points using test_input parameters with support for per-coordinate scaling
    center_vec = Vector(TR.center)

    # Create points_to_process based on sample_range type
    points_to_process = if isa(TR.sample_range, Number)
        # Scalar scaling
        [TR.sample_range .* p .+ center_vec for p in filtered_points]
    else
        # Vector scaling - apply per-coordinate scaling
        [
            [TR.sample_range[i] * p[i] + center_vec[i] for i in 1:TR.dim]
            for p in filtered_points
        ]
    end

    # Evaluate function at transformed points
    z = [f(p) for p in points_to_process]

    # Create DataFrame
    return DataFrame(
        merge(
            Dict(
                Symbol("x$i") => [p[i] for p in points_to_process]
                for i = 1:TR.dim
            ),
            Dict(:z => z),
        )
    )
end

# Update msolve_parser function to handle vector sample_range
function msolve_parser(
    file_path::String,
    f::Function,
    TR::test_input;
    skip_filtering::Bool=false
)::DataFrame
    total_time = @elapsed begin
        println("\n=== Starting MSolve Parser (dimension: $(TR.dim)) ===")

        if !isfile(file_path)
            error("File not found: $file_path")
        end

        try
            process_time = @elapsed points = process_output_file(file_path, dim=TR.dim)
            println("Processed $(length(points)) points ($(round(process_time, digits=3))s)")

            if !all(p -> length(p) == TR.dim, points)
                invalid_points = filter(p -> length(p) != TR.dim, points)
                error("Found points with incorrect dimension: $invalid_points")
            end

            # Apply filtering
            filtered_points = points
            if !skip_filtering
                filtered_points = filter(p -> all(-1 .<= p .<= 1), points)

                # If all points were filtered out but there were points to begin with,
                # consider using them anyway if they're not too far outside
                if isempty(filtered_points) && !isempty(points)
                    println("Warning: All points were filtered out.")

                    # Find the maximum absolute value to understand how far outside bounds
                    max_abs_val = maximum(abs.(reduce(vcat, points)))

                    # If the points are not too far outside, use them anyway
                    if max_abs_val < 10.0
                        println("Points are not too far outside bounds, using them anyway")
                        filtered_points = points
                    end
                end
            end

            if isempty(filtered_points)
                println("No valid points found after filtering")
                return DataFrame(Dict(Symbol("x$i") => Float64[] for i = 1:TR.dim))
            end

            # Convert center to vector if it's not already
            center_vec = Vector(TR.center)

            # Transform points based on sample_range type
            points_to_process = if isa(TR.sample_range, Number)
                # Scalar sample_range
                [TR.sample_range .* p .+ center_vec for p in filtered_points]
            else
                # Vector sample_range - apply per-coordinate scaling
                [
                    [TR.sample_range[i] * p[i] + center_vec[i] for i in 1:TR.dim]
                    for p in filtered_points
                ]
            end

            z = [f(p) for p in points_to_process]

            df = DataFrame(
                merge(
                    Dict(
                        Symbol("x$i") => [p[i] for p in points_to_process] for
                        i = 1:TR.dim
                    ),
                    Dict(:z => z),
                ),
            )

            return df
        catch e
            println("Error in msolve_parser: ", e)
            println("Stack trace:")
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
            rethrow(e)
        finally
            # Clean up the output file after processing
            isfile(file_path) && rm(file_path)
        end
    end
    println("Total execution time: $(round(total_time, digits=3))s")
end