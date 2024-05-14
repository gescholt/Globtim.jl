# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, AlgebraicSolving, HomotopyContinuation, JSON


# Constants and Parameters
const d1, d2, ds = 3, 8, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters

## In this file, we take least squares approximants generated in Maple. 
## They come with rational coefficients, which are transformed to BigFloat.
## The goal is to compare the points computed by msolve with the outputs 
## of homotopy continuation. 

@polyvar(x, y) # Define polynomial ring 


for (i, d) in enumerate(d1:ds:d2)
    local file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
    local file_path_pol = expanduser("data/pol_rat_msolve_d$(d)_C_$(a)_$b.txt")

    # Read and parse the JSON files
    data_pts = read(file_path_pts, String)
    trimmed_content = strip(data_pts, ['[', ']']) #trim brackets
    rows = split(trimmed_content, "], [") #split into two arrays
    # Collect the two arrays of msolve points
    data_array = [parse.(Float64, split(strip(row, ['[', ']']), ", ")) for row in rows]
    # Collect the polynomial
    data_pol = read(file_path_pol, String)

    # Read the polynomial approximant 
    polynomial_expr = Meta.parse(data_pol)
    polynomial = eval(polynomial_expr) 
    # It is in BigFloat, supposedely that works with HomotopyContinuation
    # print(typeof(polynomial))
    P1 = differentiate(polynomial, x) 
    P2 = differentiate(polynomial, y)

    homoto = RR_xy_solve(n, P1, P2)

    # println("Homotopy real solutions at degree d=", homoto)
    println("Number of real solutions homotopy:", length(homoto))
    println("Number of real solutions msolve:", length(data_array[1]))

    using DelimitedFiles

end