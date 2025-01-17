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
        println("Julia-only points: $n_julia_only")
        println("MATLAB-only points: $(n_matlab_total - n_matches)")
    end

    return df, df_min, df_ext
end