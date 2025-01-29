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
const n, a, b = 2, 3, 8
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder --needs to be replaced by default value. 
f = tref # Objective function

SMPL = 120 # Number of samples
center = [0.0, 0.0]
TR = test_input(f,
dim=n,
center=[0.0, 0.0],
GN=SMPL,
sample_range=scale_factor,
tolerance=tol_l2,
)

@polyvar(x[1:n]); # Define polynomial ring 
d = 36 # Initial Degree 

pol_cheb = Constructor(TR, d, basis=:chebyshev);
df_cheb = solve_and_parse(pol_cheb, x, f, TR)
# df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=.005) 
CSV.write("tref_3_8_deg_36_cheb_pol_crit_pts.txt", df_cheb)
count("true" .== string.(df_min_cheb.captured))

# pol_lege = Constructor(TR, d, basis=:legendre);
# df_lege = solve_and_parse(pol_lege, x, f, TR, basis=:legendre)
# df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=.01)

sort!(df_cheb, :z, rev=true)
# sort!(df_lege, :z, rev=true)

include("../compare_matlab.jl")
using CSV
df_matlab = CSV.read("data/matlab_critical_points/valid_points_trefethen_3_8.csv", DataFrame)

# Here we just plot a comparison between the critical points found by Julia and Matlab.
df_merge = merge_optimization_points(df_cheb, df_matlab, tol_dist=0.025)
# fig_8 = plot_matlab_comparison(df_merge, pol_cheb, TR, chebyshev_levels=true, num_levels=60)
# display(fig_8)
# save("trefethen_1_4_chebyshev_deg32_msolve_julia_matlab_tol_dist25e-3.pdf", fig_8)

# Here we compare the local minimizers returned by Optim in Julia to the critical points found by Chebfun2.
df_min_comp = comp_min_cheb(df_min_cheb, df_matlab; tol_dist=0.025, verbose=true)
# fig_9 = plot_critical_points_comparison(df_min_comp, pol_cheb, TR, chebyshev_levels=true, num_levels=60)
# save("trefethen_1_4_msolve_captured_minimizers_d32_julia_matlab_tol_dist25e-3.pdf", fig_9)

# Now we want to compare `df_min_cheb` with `df_matlab` to see if we can find the same critical points. Plot only the points in `df_min_cheb`, mark them in green if they are both "captured" and "matlab_captured". In blue if they are only "captured" and in red if they are only "matlab_captured". Potentially we need a new function to process the points ?

