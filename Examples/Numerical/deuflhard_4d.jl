using Pkg
using Revise
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using CSV
# using GLMakie
# using CairoMakie

# Load the dataframe from the CSV file
# df_2d = CSV.read("data/camel_d6.csv", DataFrame)

# Constants and Parameters
const n, a, b = 4, 3, 5
const scale_factor = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alpha = 0.1, 2 / 10  # Sampling parameters
const tol_l2 = 1e-0
# The objective function
f = Deuflhard_4d # Objective function

d = 8     # Degree 
SMPL = 10 # Number of samples
center = [0.5, -0.5, 0.5, -0.5]
# center = [0.0, 0.0, 0.0, 0.0]
TR = test_input(f,
    dim=n,
    center=center,
    GN=SMPL,
    sample_range=scale_factor,
    tolerance=tol_l2,
);
pol_cheb = Constructor(TR, d, basis=:chebyshev);
pol_lege = Constructor(TR, d, basis=:legendre);

@polyvar(x[1:n]); # Define polynomial ring 
real_pts_cheb = solve_polynomial_system(x, TR.dim, pol_cheb.degree, pol_cheb.coeffs; basis=:chebyshev, bigint=true)
df_cheb = process_critical_points(real_pts_cheb, f, TR)
df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist= 0.02)


real_pts_lege = solve_polynomial_system(x, TR.dim, pol_lege.degree, pol_lege.coeffs; basis=:legendre, bigint=true)
df_lege = process_critical_points(real_pts_lege, f, TR)
df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=0.02)

# The optimized approximant
sorted_df_cheb = sort(df_min_cheb, :"captured", rev=true)
sorted_df_lege = sort(df_min_lege, :"captured", rev=true)

show(df_min_cheb)
show(df_min_lege)

# Compute the tensored 4d dataframe #
df_2d = CSV.read("data/matlab_critical_points/valid_points_deuflhard.csv", DataFrame)
using IterTools
function double_dataframe(df::DataFrame)
    n = nrow(df)
    pairs = collect(product(1:n, 1:n))

    x1 = vec([df.x[j[1]] for j in pairs])
    y1 = vec([df.y[j[1]] for j in pairs])
    x2 = vec([df.x[j[2]] for j in pairs])
    y2 = vec([df.y[j[2]] for j in pairs])

    return DataFrame(x1=x1, x2=y1, x3=x2, x4=y2)
end
names(df_2d)
df_doubled = double_dataframe(df_2d)

# # process the dataframe
using LinearAlgebra
include("../cmpr.jl")


df_result = compare_tensor_points(df_cheb, df_doubled,tol_dist=0.005)
df_filtered = df_result[df_result.captured.==true, :]
# sort(df_filtered, :"x1", rev=true)

df_lege_result = compare_tensor_points(df_lege, df_doubled,tol_dist=0.001)
df_lege_filtered = df_lege_result[df_lege_result.captured.==true, :]
