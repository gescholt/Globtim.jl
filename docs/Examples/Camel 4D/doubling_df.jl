using CSV
using DataFrames
using IterTools

# Load the dataframe from the CSV file
"""
Computes the 4-dimensional set of critical points from the 2D critical points of a function f
F(x_1, x_2, x_3, x_4) = f(x_1,x_2)+ f(x_3,x_4).

"""
df_ori = CSV.read("data/camel_d6.csv", DataFrame)
n = nrow(df_ori)

select!(df_ori, :x, :y)

function double_dataframe(df::DataFrame)
    n = nrow(df)
    pairs = collect(product(1:n, 1:n))

    x1 = vec([df.x[j[1]] for j in pairs])
    y1 = vec([df.y[j[1]] for j in pairs])
    x2 = vec([df.x[j[2]] for j in pairs])
    y2 = vec([df.y[j[2]] for j in pairs])

    return DataFrame(x1 = x1, x2 = y1, x3 = x2, x4 = y2)
end

df_doubled = double_dataframe(df_ori)

CSV.write("data/4d_camel_d6.csv", df)
