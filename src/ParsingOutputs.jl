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
    skip_filtering::Bool = false,
    kwargs...,
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
        [[TR.sample_range[i] * p[i] + center_vec[i] for i = 1:TR.dim] for p in filtered_points]
    end

    # Evaluate function at transformed points
    # For 1D functions, we need to handle both scalar and vector function signatures
    z = if TR.dim == 1 && !isempty(points_to_process)
        # Check the function signature by testing with the first point
        first_point = points_to_process[1]

        # Try to determine if function expects scalar or vector input
        local expects_scalar = false
        try
            # Try vector input first
            f(first_point)
        catch e
            if isa(e, MethodError) && applicable(f, first_point[1])
                # Function doesn't accept vector but does accept scalar
                expects_scalar = true
            elseif !isa(e, MethodError)
                # Some other error - rethrow
                rethrow(e)
            else
                # Function doesn't accept either format
                throw(
                    ArgumentError(
                        "Function doesn't accept expected input format. " *
                        "For 1D problems, function should accept either scalar (e.g., x -> sin(x)) " *
                        "or vector input (e.g., x -> sin(x[1])).",
                    ),
                )
            end
        end

        # Now evaluate all points using the determined format
        if expects_scalar
            [f(p[1]) for p in points_to_process]
        else
            [f(p) for p in points_to_process]
        end
    else
        # For multi-dimensional or empty cases, always use vector format
        [f(p) for p in points_to_process]
    end

    # Create DataFrame
    return DataFrame(
        merge(
            Dict(Symbol("x$i") => [p[i] for p in points_to_process] for i = 1:TR.dim),
            Dict(:z => z),
        ),
    )
end

"""
    msolve_parser(file_path::String, f::Function, TR::test_input; skip_filtering::Bool=false)::DataFrame

Parse msolve output file containing critical points in rational number format.

# Msolve Output Format
Msolve produces output in the following structure:
```
[0, [1,
[[[x1, y1], [data]], [[x2, y2], [data]], ...]]]
```

Where coordinates are given as exact rational numbers:
- Simple integers: `123` or `-456`
- Rational fractions: `numerator / 2^exponent` (e.g., `-1203113635169695151124944263156110755035 / 2^139`)

# Parsing Process
1. Extracts the content after `[0, [1,` pattern
2. Uses regex to match coordinate pairs: `[[x, y], [data]]`
3. Parses rational numbers by:
   - Splitting on `/` to separate numerator and denominator
   - Handling `2^n` notation for powers of 2
   - Converting to BigFloat for precision, then to Float64
4. Applies filtering and transformations via `process_crit_pts`

# Arguments
- `file_path`: Path to msolve output file
- `f`: Function to evaluate at critical points
- `TR`: test_input struct with dimension, center, and sample range
- `skip_filtering`: If true, skips [-1,1] bounds filtering

# Returns
DataFrame with columns x1, x2, ..., xn and z (function values)

# Note
Currently only supports 2D problems. Higher dimensions require different parsing logic.
"""
function msolve_parser(
    file_path::String,
    f::Function,
    TR::test_input;
    skip_filtering::Bool = false,
)::DataFrame
    total_time = @elapsed begin
        println("\n=== Starting MSolve Parser (dimension: $(TR.dim)) ===")

        if !isfile(file_path)
            error("File not found: $file_path")
        end

        try
            # Read and parse msolve output file
            process_time = @elapsed begin
                if !isfile(file_path)
                    error("Msolve output file not found: $file_path")
                end

                # Read the file content
                content = read(file_path, String)

                # Parse the solutions from msolve output
                # Msolve outputs in format: [0, [1, [[[x1, y1], [data]], [[x2, y2], [data]], ...]]]:
                points = Vector{Vector{Float64}}()

                # Remove trailing colon and whitespace
                content = strip(rstrip(content, ':'))

                try
                    # Find the innermost list containing the point data
                    # Look for the pattern [0, [1, [...]]]
                    start_idx = findfirst("[0, [1,", content)
                    if start_idx === nothing
                        error("Unexpected msolve output format")
                    end

                    # Extract the content after [0, [1,
                    inner_content = content[start_idx[end]+1:end]

                    # Use a regex that properly captures rational numbers
                    # Match patterns like [[x, y], [data]] where x,y can be:
                    #   - Integers: 123 or -456
                    #   - Rationals: -123/2^45 (with spaces allowed around /)
                    # The pattern (-?\d+\s*/\s*2\^\d+|-?\d+) matches either form
                    coord_pattern =
                        r"\[\[\s*(-?\d+\s*/\s*2\^\d+|-?\d+)\s*,\s*(-?\d+\s*/\s*2\^\d+|-?\d+)\s*\],\s*\[[^\]]*\]\]"

                    for match in eachmatch(coord_pattern, inner_content)
                        x_str = strip(match.captures[1])
                        y_str = strip(match.captures[2])

                        # Parse rational numbers
                        x_val = if contains(x_str, '/')
                            parts = split(x_str, '/')
                            num = parse(BigFloat, strip(parts[1]))
                            den_str = strip(parts[2])
                            # Handle 2^n notation
                            den = if startswith(den_str, "2^")
                                BigFloat(2)^parse(Int, den_str[3:end])
                            else
                                parse(BigFloat, den_str)
                            end
                            Float64(num / den)
                        else
                            parse(Float64, x_str)
                        end

                        y_val = if contains(y_str, '/')
                            parts = split(y_str, '/')
                            num = parse(BigFloat, strip(parts[1]))
                            den_str = strip(parts[2])
                            # Handle 2^n notation
                            den = if startswith(den_str, "2^")
                                BigFloat(2)^parse(Int, den_str[3:end])
                            else
                                parse(BigFloat, den_str)
                            end
                            Float64(num / den)
                        else
                            parse(Float64, y_str)
                        end

                        # For now, only handle 2D case
                        if TR.dim == 2
                            push!(points, [x_val, y_val])
                        else
                            # For higher dimensions, we'd need to parse differently
                            error("msolve parser currently only supports 2D problems")
                        end
                    end
                catch e
                    println("Error parsing msolve output: ", e)
                    println("Content preview: ", first(content, min(200, length(content))))
                    rethrow(e)
                end
            end
            println(
                "Processed $(length(points)) points ($(round(process_time, digits=3))s)",
            )

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
                    [TR.sample_range[i] * p[i] + center_vec[i] for i = 1:TR.dim] for
                    p in filtered_points
                ]
            end

            z = [f(p) for p in points_to_process]

            df = DataFrame(
                merge(
                    Dict(
                        Symbol("x$i") => [p[i] for p in points_to_process] for i = 1:TR.dim
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
