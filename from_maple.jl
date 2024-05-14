# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, AlgebraicSolving, HomotopyContinuation, JSON, Plots


# Constants and Parameters
const d1, d2, ds = 2, 30, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters

## In this file, we take least squares approximants generated in Maple. 
## They come with rational coefficients, which are transformed to BigFloat.
## The goal is to compare the points computed by msolve with the outputs 
## of homotopy continuation. 

@polyvar(x, y) # Define polynomial ring 

using DelimitedFiles

for (i, d) in enumerate(d1:ds:d2)
    ## Read and parse the files
    local file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
    local file_path_pol = expanduser("data/pol_rat_msolve_d$(d)_C_$(a)_$b.txt")
    # Read points msolve
    data_pts = read(file_path_pts, String)
    trimmed_content = strip(data_pts, ['[', ']']) #trim brackets
    rows = split(trimmed_content, "], [") #split into two arrays
    # Collect the two arrays of msolve points
    data_array = [parse.(Float64, split(strip(row, ['[', ']']), ", ")) for row in rows]
    
    # Collect the polynomial
    data_pol = read(file_path_pol, String)
    # Read the polynomial approximant 
    polynomial = eval(Meta.parse(data_pol))
    # It is in BigFloat, supposedely that works with HomotopyContinuation
    # print(typeof(polynomial))
    P1 = differentiate(polynomial, x) 
    P2 = differentiate(polynomial, y)

    homoto = RR_xy_solve(n, P1, P2) # Compute Homotpy Continuation
    # Define the condition for filtering
    condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1

    # Filter points using the filter function
    filtered_points = filter(condition, homoto)
    h_x = [x[1] for x in filtered_points] # for plotting
    h_y = [x[2] for x in filtered_points]
    # println("Homotopy real solutions at degree d=", homoto)
    println("Number of real solutions homotopy:", length(homoto))
    println("Number of real solutions msolve:", length(data_array[1]))
    # Plot the data
    plt1 = scatter(data_array[1], data_array[2], seriestype=:scatter, label="x vs y", xlabel="x", ylabel="y", color=:red, marker=(:diamond, 8))
    scatter!(h_x, h_y, seriestype=:scatter, label="x vs y", xlabel="x", ylabel="y", marker=(:circle, 4), markerstrokecolor=:blue, markerstrokewidth=1.5)
    display(plt1)
    
end