using Pkg
using Revise 
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using GLMakie
using CairoMakie
CairoMakie.activate!()  # Activate Cairo backend


# Constants and Parameters
const n, a, b = 2, 10, 1
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder
f = HolderTable # Objective function

SMPL = 240 # Number of samples
center = [0.0, 0.0]
TR = test_input(f,
dim=n,
center=[0.0, 0.0],
GN=SMPL,
sample_range=scale_factor,
tolerance=tol_l2,
)

@polyvar(x[1:n]); # Define polynomial ring 

d = 20
# Initial Degree 
pol_cheb = Constructor(TR, d, basis=:chebyshev);
df_cheb = solve_and_parse(pol_cheb, x, f, TR)
df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=.325)
sort!(df_cheb, :close, rev=true)

fig5 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb, chebyshev_levels=true, num_levels=30)

pol_lege = Constructor(TR, d, basis=:legendre);
df_lege = solve_and_parse(pol_lege, x, f, TR, basis=:legendre)
df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=.325)
sort!(df_lege, :z, rev=true)
fig6 = plot_polyapprox_levelset(pol_lege, TR, df_lege, df_min_lege, chebyshev_levels=true, num_levels=30)

display(fig5)
display(fig6)
# include("../compare_matlab.jl")
# using CSV

# df_matlab = CSV.read("data/valid_points_trefethen_3_8.csv", DataFrame, delim=",")

# df_cheb2, df_min2, df_ext = comp_matlab(f, df_cheb, TR, df_matlab)

# fig7 = plot_comparison_levelset(pol_cheb, TR, df_ext)

