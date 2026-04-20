"""
    process_crit_pts(
        real_pts::Vector{<:AbstractVector},
        f::Function,
        TR::TestInput;
        skip_filtering::Bool = false,
        kwargs...
    )::DataFrame

Process critical points in n-dimensional space and return a DataFrame.
Points are automatically filtered to the [-1,1]^n hypercube (unless skip_filtering is true)
and transformed according to the TestInput parameters.

# Arguments
- `real_pts`: Vector of points in n-dimensional space
- `f`: Function to evaluate at each point
- `TR`: TestInput struct containing dimension, center, and sample range information
- `skip_filtering`: If true, skips the [-1,1] bounds filtering (default: false)
- `kwargs...`: Additional arguments for future extensions

# Returns
- DataFrame with columns x1, x2, ..., xn (for n dimensions) and z (function values)
"""
function process_crit_pts(
    real_pts::Vector{<:AbstractVector},
    f::Function,
    TR::TestInput;
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
        result = Dict(Symbol("x$i") => Float64[] for i in 1:(TR.dim))
        result[:z] = Float64[]
        return DataFrame(result)
    end

    # Transform points using TestInput parameters with support for per-coordinate scaling
    center_vec = Vector(TR.center)

    # Create points_to_process based on sample_range type
    points_to_process = if isa(TR.sample_range, Number)
        # Scalar scaling
        [TR.sample_range .* p .+ center_vec for p in filtered_points]
    else
        # Vector scaling - apply per-coordinate scaling
        [
            [TR.sample_range[i] * p[i] + center_vec[i] for i in 1:(TR.dim)] for
            p in filtered_points
        ]
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
            Dict(Symbol("x$i") => [p[i] for p in points_to_process] for i in 1:(TR.dim)),
            Dict(:z => z),
        ),
    )
end

# ── msolve output parsing (N-dimensional) ─────────────────────────────────────

"""
    parse_msolve_rational(s::AbstractString) -> Float64

Parse a single msolve rational number string to Float64.

msolve outputs coordinates as either:
- Plain integers: `123`, `-456`
- Rational fractions: `numerator / 2^exponent`  (e.g. `-12031136 / 2^139`)

Uses BigFloat intermediate to avoid precision loss for large numerators.
"""
function parse_msolve_rational(s::AbstractString)::Float64
    s = strip(s)
    if contains(s, '/')
        parts = split(s, '/')
        num = parse(BigFloat, strip(parts[1]))
        den_str = strip(parts[2])
        den = if startswith(den_str, "2^")
            BigFloat(2)^parse(Int, den_str[3:end])
        else
            parse(BigFloat, den_str)
        end
        return Float64(num / den)
    else
        return parse(Float64, s)
    end
end

"""
    parse_msolve_output(content::AbstractString, n::Int) -> Vector{Vector{Float64}}

Parse raw msolve output into solution points (N-dimensional).

# msolve v0.9.4 output format

For systems over QQ, msolve outputs real solutions as isolating intervals:
```
[0, [1,
[[[lo₁, hi₁], [lo₂, hi₂], ...], [[lo₁, hi₁], [lo₂, hi₂], ...], ...]
]]:
```

Each solution is a list of N coordinate intervals `[lo, hi]` where lo and hi
are rational numbers in the form `integer` or `integer / 2^exponent`.
The midpoint `(lo + hi) / 2` is taken as the coordinate value.

Special output cases:
- `[-1]:` — no solutions in algebraic closure
- `[1, nvars, -1, []]:` — infinitely many solutions

# Arguments
- `content`: Raw msolve output file content
- `n`: Expected number of variables (dimension)

# Returns
- `Vector{Vector{Float64}}`: Solution midpoints in the normalized domain
"""
function parse_msolve_output(content::AbstractString, n::Int)::Vector{Vector{Float64}}
    content = strip(rstrip(strip(content), ':'))

    # Check for no-solution cases
    if contains(content, "[-1]")
        @debug "msolve: no solutions in algebraic closure"
        return Vector{Float64}[]
    end
    if occursin(r"\[1,\s*\d+,\s*-1,\s*\[\]\]", content)
        error("msolve: infinitely many solutions (positive-dimensional ideal)")
    end

    # Find the solution data after the header [0, [1, ...]
    start_idx = findfirst("[0, [1,", content)
    if start_idx === nothing
        error(
            "Unexpected msolve output format — missing '[0, [1,' header.\n" *
            "Content preview: $(first(content, min(300, length(content))))",
        )
    end

    # Extract everything after "[0, [1,"
    inner = content[(start_idx[end]+1):end]

    # Strategy: walk the string character-by-character tracking bracket depth
    # to split into individual solution blocks. Each solution is
    # [[lo1, hi1], [lo2, hi2], ..., [loN, hiN]] at the top-level list.
    #
    # The outer structure is [ sol1, sol2, ... ] where each sol is [[...], ...].
    # We need to find each sol block.

    points = Vector{Float64}[]

    # Find the outermost [ that contains all solutions
    outer_start = findfirst('[', inner)
    outer_start === nothing && return points

    # Parse solution blocks by tracking bracket depth
    depth = 0
    sol_start = 0
    i = outer_start
    while i <= lastindex(inner)
        c = inner[i]
        if c == '['
            depth += 1
            # depth 2 = start of a solution block [[lo1,hi1], ...]
            if depth == 2
                sol_start = i
            end
        elseif c == ']'
            depth -= 1
            # depth 1 = end of a solution block
            if depth == 1 && sol_start > 0
                sol_block = inner[sol_start:i]
                pt = _parse_solution_block(sol_block, n)
                if pt !== nothing
                    push!(points, pt)
                end
                sol_start = 0
            end
            # depth 0 = end of outer list
            depth <= 0 && break
        end
        i = nextind(inner, i)
    end

    return points
end

"""
    parse_msolve_output_with_intervals(content::AbstractString, n::Int)
        -> Tuple{Vector{Vector{Float64}}, Vector{Vector{Tuple{Float64,Float64}}}}

Parse raw msolve output into solution midpoints AND isolating intervals.

Returns `(points, intervals)` where:
- `points[i]::Vector{Float64}`: midpoints for solution i
- `intervals[i]::Vector{Tuple{Float64,Float64}}`: `(lo, hi)` per coordinate for solution i

See [`parse_msolve_output`](@ref) for format details.
"""
function parse_msolve_output_with_intervals(
    content::AbstractString,
    n::Int,
)::Tuple{Vector{Vector{Float64}},Vector{Vector{Tuple{Float64,Float64}}}}
    content = strip(rstrip(strip(content), ':'))

    if contains(content, "[-1]")
        @debug "msolve: no solutions in algebraic closure"
        return (Vector{Float64}[], Vector{Tuple{Float64,Float64}}[])
    end
    if occursin(r"\[1,\s*\d+,\s*-1,\s*\[\]\]", content)
        error("msolve: infinitely many solutions (positive-dimensional ideal)")
    end

    start_idx = findfirst("[0, [1,", content)
    if start_idx === nothing
        error(
            "Unexpected msolve output format — missing '[0, [1,' header.\n" *
            "Content preview: $(first(content, min(300, length(content))))",
        )
    end

    inner = content[(start_idx[end]+1):end]

    points = Vector{Float64}[]
    all_intervals = Vector{Tuple{Float64,Float64}}[]

    outer_start = findfirst('[', inner)
    outer_start === nothing && return (points, all_intervals)

    depth = 0
    sol_start = 0
    i = outer_start
    while i <= lastindex(inner)
        c = inner[i]
        if c == '['
            depth += 1
            if depth == 2
                sol_start = i
            end
        elseif c == ']'
            depth -= 1
            if depth == 1 && sol_start > 0
                sol_block = inner[sol_start:i]
                result = _parse_solution_block_intervals(sol_block, n)
                if result !== nothing
                    push!(points, result[1])
                    push!(all_intervals, result[2])
                end
                sol_start = 0
            end
            depth <= 0 && break
        end
        i = nextind(inner, i)
    end

    return (points, all_intervals)
end

"""
    _parse_solution_block(block::AbstractString, n::Int) -> Union{Vector{Float64}, Nothing}

Parse a single msolve solution block `[[lo1, hi1], [lo2, hi2], ...]` into
coordinate midpoints. Returns `nothing` if parsing fails.
"""
function _parse_solution_block(
    block::AbstractString,
    n::Int,
)::Union{Vector{Float64},Nothing}
    result = _parse_solution_block_intervals(block, n)
    result === nothing && return nothing
    return result[1]  # return midpoints only
end

"""
    _parse_solution_block_intervals(block::AbstractString, n::Int)
        -> Union{Tuple{Vector{Float64}, Vector{Tuple{Float64,Float64}}}, Nothing}

Parse a single msolve solution block `[[lo1, hi1], [lo2, hi2], ...]` into
coordinate midpoints AND isolating intervals.

Returns `(midpoints, intervals)` where:
- `midpoints::Vector{Float64}`: midpoint `(lo+hi)/2` for each coordinate
- `intervals::Vector{Tuple{Float64,Float64}}`: `(lo, hi)` bounds for each coordinate

Returns `nothing` if parsing fails or dimension mismatch.
"""
function _parse_solution_block_intervals(
    block::AbstractString,
    n::Int,
)::Union{Tuple{Vector{Float64},Vector{Tuple{Float64,Float64}}},Nothing}
    coords = Float64[]
    intervals = Tuple{Float64,Float64}[]
    depth = 0
    interval_start = 0

    i = firstindex(block)
    while i <= lastindex(block)
        c = block[i]
        if c == '['
            depth += 1
            if depth == 2
                interval_start = i
            end
        elseif c == ']'
            depth -= 1
            if depth == 1 && interval_start > 0
                interval_str = block[(interval_start+1):(i-1)]
                parts = split(interval_str, ',')
                if length(parts) == 2
                    lo = parse_msolve_rational(parts[1])
                    hi = parse_msolve_rational(parts[2])
                    push!(coords, (lo + hi) / 2.0)
                    push!(intervals, (lo, hi))
                end
                interval_start = 0
            end
        end
        i = nextind(block, i)
    end

    if length(coords) == n
        return (coords, intervals)
    else
        @debug "msolve: solution block has $(length(coords)) coordinates, expected $n — skipping"
        return nothing
    end
end

"""
    msolve_raw_points(file_path::String, n::Int) -> Vector{Vector{Float64}}

Parse an msolve output file and return raw solution points in the normalized
domain (no filtering, no coordinate transform, no function evaluation).

This is the low-level parser that matches HomotopyContinuation's return contract:
a `Vector{Vector{Float64}}` of real solutions.

# Arguments
- `file_path`: Path to msolve output file (will be cleaned up after parsing)
- `n`: Number of variables (dimension)

# Returns
- `Vector{Vector{Float64}}`: Raw solution midpoints
"""
function msolve_raw_points(file_path::String, n::Int)::Vector{Vector{Float64}}
    if !isfile(file_path)
        error("msolve output file not found: $file_path")
    end

    content = read(file_path, String)

    # Clean up output file
    rm(file_path)

    return parse_msolve_output(content, n)
end

"""
    msolve_raw_points_with_intervals(file_path::String, n::Int)
        -> Tuple{Vector{Vector{Float64}}, Vector{Vector{Tuple{Float64,Float64}}}}

Parse an msolve output file and return raw solution midpoints AND isolating intervals.
File is cleaned up after parsing.

See [`parse_msolve_output_with_intervals`](@ref) for return format.
"""
function msolve_raw_points_with_intervals(
    file_path::String,
    n::Int,
)::Tuple{Vector{Vector{Float64}},Vector{Vector{Tuple{Float64,Float64}}}}
    if !isfile(file_path)
        error("msolve output file not found: $file_path")
    end

    content = read(file_path, String)
    rm(file_path)

    return parse_msolve_output_with_intervals(content, n)
end

# ── Certified interval-box overlap (range search) ────────────────────────────

"""
    interval_overlaps_box(
        intervals::Vector{Tuple{Float64,Float64}},
        box::Vector{Tuple{Float64,Float64}}
    ) -> Bool

Check whether an N-dimensional isolating interval overlaps a search box.

Returns `true` if the interval `[lo_i, hi_i]` overlaps with `[box_lo_i, box_hi_i]`
in ALL dimensions (i.e., the hyperrectangles intersect). If any single dimension
has no overlap, the root is certifiably outside the box.

This is a certified rejection test: if it returns `false`, the root is guaranteed
to be outside the box. If it returns `true`, the root might be inside or near the
boundary — its midpoint should be checked for final inclusion.
"""
function interval_overlaps_box(
    intervals::Vector{Tuple{Float64,Float64}},
    box::Vector{Tuple{Float64,Float64}},
)::Bool
    for (iv, bx) in zip(intervals, box)
        iv_lo, iv_hi = iv
        bx_lo, bx_hi = bx
        # No overlap if interval is entirely below or above the box
        if iv_hi < bx_lo || iv_lo > bx_hi
            return false
        end
    end
    return true
end

"""
    interval_certified_inside(
        intervals::Vector{Tuple{Float64,Float64}},
        box::Vector{Tuple{Float64,Float64}}
    ) -> Bool

Check whether an N-dimensional isolating interval is certifiably contained in a box.

Returns `true` only if `[lo_i, hi_i] ⊆ [box_lo_i, box_hi_i]` in ALL dimensions.
This means the root is guaranteed to be inside the box regardless of its exact
position within the isolating interval.
"""
function interval_certified_inside(
    intervals::Vector{Tuple{Float64,Float64}},
    box::Vector{Tuple{Float64,Float64}},
)::Bool
    for (iv, bx) in zip(intervals, box)
        iv_lo, iv_hi = iv
        bx_lo, bx_hi = bx
        if iv_lo < bx_lo || iv_hi > bx_hi
            return false
        end
    end
    return true
end

"""
    filter_solutions_by_box(
        points::Vector{Vector{Float64}},
        intervals::Vector{Vector{Tuple{Float64,Float64}}},
        box::Vector{Tuple{Float64,Float64}}
    ) -> Tuple{Vector{Vector{Float64}}, Vector{Vector{Tuple{Float64,Float64}}}}

Filter solutions using certified interval-box overlap.

Keeps solutions whose isolating interval overlaps the search box. Solutions whose
interval is entirely outside the box in any dimension are certifiably rejected.

Returns `(filtered_points, filtered_intervals)`.
"""
function filter_solutions_by_box(
    points::Vector{Vector{Float64}},
    intervals::Vector{Vector{Tuple{Float64,Float64}}},
    box::Vector{Tuple{Float64,Float64}},
)::Tuple{Vector{Vector{Float64}},Vector{Vector{Tuple{Float64,Float64}}}}
    kept_pts = Vector{Float64}[]
    kept_ivs = Vector{Tuple{Float64,Float64}}[]
    for (pt, iv) in zip(points, intervals)
        if interval_overlaps_box(iv, box)
            push!(kept_pts, pt)
            push!(kept_ivs, iv)
        end
    end
    return (kept_pts, kept_ivs)
end

"""
    msolve_parser(file_path::String, f::Function, TR::TestInput; skip_filtering::Bool=false)::DataFrame

Parse msolve output file and return a DataFrame with transformed critical points
and function values. Supports arbitrary dimension.

# msolve v0.9.4 output format

Each real solution is given as N isolating intervals `[lo, hi]` with rational bounds.
The midpoint is taken as the coordinate value. See [`parse_msolve_output`](@ref) for details.

# Arguments
- `file_path`: Path to msolve output file
- `f`: Function to evaluate at critical points
- `TR`: TestInput struct with dimension, center, and sample range
- `skip_filtering`: If true, skips [-1,1] bounds filtering

# Returns
DataFrame with columns x1, x2, ..., xn and z (function values)
"""
function msolve_parser(
    file_path::String,
    f::Function,
    TR::TestInput;
    skip_filtering::Bool = false,
)::DataFrame
    @debug "Starting msolve parser (dimension: $(TR.dim))"

    if !isfile(file_path)
        error("File not found: $file_path")
    end

    local points::Vector{Vector{Float64}}
    parse_time = @elapsed begin
        content = read(file_path, String)
        points = parse_msolve_output(content, TR.dim)
    end

    # Clean up output file
    isfile(file_path) && rm(file_path)

    @debug "Parsed $(length(points)) points ($(round(parse_time, digits=3))s)"

    # Delegate to process_crit_pts for filtering, transform, and function evaluation
    return process_crit_pts(points, f, TR; skip_filtering = skip_filtering)
end
