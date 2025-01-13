function compare_tensor_points(df_approx::DataFrame, df_double::DataFrame; tol_dist=0.025)
    n_dims = count(col -> startswith(col, "x"), names(df_approx))
    if count(col -> startswith(col, "x"), names(df_double)) != n_dims
        error("Dimension mismatch between dataframes")
    end

    if !("captured" in names(df_double))
        df_double[!, "captured"] = falses(nrow(df_double))
    end

    for i = 1:nrow(df_double)
        point_double = [df_double[i, "x$j"] for j = 1:n_dims]

        df_double[i, "captured"] = any(
            norm([df_approx[k, "y$j"] - point_double[j] for j = 1:n_dims]) < tol_dist
            for k = 1:nrow(df_approx)
        )
    end

    return df_double
end

function create_tensor_points(df1::DataFrame, df2::DataFrame)
    n_dims1 = count(col -> startswith(col, "x"), names(df1))
    n_dims2 = count(col -> startswith(col, "x"), names(df2))
    n_dims_total = n_dims1 + n_dims2

    df_double = DataFrame(Dict("x$i" => Float64[] for i = 1:n_dims_total))

    for i = 1:nrow(df1), j = 1:nrow(df2)
        new_row = Dict{String,Float64}()

        for k = 1:n_dims1
            new_row["x$k"] = df1[i, "x$k"]
        end

        for k = 1:n_dims2
            new_row["x$(k+n_dims1)"] = df2[j, "x$k"]
        end

        push!(df_double, new_row)
    end

    return df_double
end