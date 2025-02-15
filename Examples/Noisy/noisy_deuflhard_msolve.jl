using Pkg
using Revise
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using Distributions
using Optim
using GLMakie
using CairoMakie
CairoMakie.activate!

#  We now perturb the evaluation of these polynomial objective functions with random noise. For that we perturb each evaluation of $f$ by $rand(-1000..1000)/10000$ in Maple. We repeat the same iterative procedure on the degree using the same number of Chebyshev nodes as in the previous experiment. 

# Constants and Parameters
const n, a, b = 2, 11, 10
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder

function noisy_Deuflhard(
    xx::AbstractVector;
    mean::Float64 = 0.0,
    stddev::Float64 = 5.0,
)::Float64
    noise = rand(Normal(mean, stddev))
    return Deuflhard(xx) + noise
end
f = noisy_Deuflhard # Objective function

d = 8 # Initial Degree 
SMPL = 120 # Number of samples
center = [0.0, 0.0]
TR = test_input(
    f,
    dim = n,
    center = [0.0, 0.0],
    GN = SMPL,
    sample_range = scale_factor,
    tolerance = tol_l2,
)
pol_cheb = Constructor(TR, d, basis = :chebyshev);
# pol_lege = Constructor(TR, d, basis=:legendre);

@polyvar(x[1:n]); # Define polynomial ring 

df_cheb = solve_and_parse(pol_cheb, x, f, TR)
sort!(df_cheb, :z, rev = true)
# df_lege = solve_and_parse(pol_lege, x, f, TR, basis=:legendre)
# sort!(df_lege, :z, rev=true)

df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist = 0.01)
# df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=0.01)

include("../compare_matlab.jl")
using CSV
df_matlab = CSV.read("data/matlab_critical_points/valid_points_deuflhard.csv", DataFrame)
df_merge_cheb = merge_optimization_points(df_cheb, df_matlab, tol_dist = 0.01)
# df_merge_lege = merge_optimization_points(df_lege, df_matlab, tol_dist=0.01)

# fig_1 = plot_matlab_comparison(df_merge_cheb, pol_cheb, TR, chebyshev_levels=true, num_levels=60)
# fig_2 = plot_matlab_comparison(df_merge_lege, pol_lege, TR, chebyshev_levels=false, num_levels=60)
# fig_3 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb, chebyshev_levels=true, num_levels=60)
# fig_4 = plot_polyapprox_levelset(pol_lege, TR, df_lege, df_min_lege, chebyshev_levels=true, num_levels=60)

fig_5 = plot_talk(pol_cheb, TR, df_cheb, df_min_cheb)
save("noisy_deuflhard_chebyshev_deg8_msolve.pdf", fig_5)

# save("deuflhard_11_10_legendre_deg8_msolve_julia_matlab_tol_dist1e-3.pdf", fig_2)
# save("deuflhard_11_10_chebyshev_deg20_msolve_julia_matlab_tol_dist1e-3.pdf", fig_3)


# fig1 = plot_polyapprox_rotate(pol_cheb, TR, df_cheb, df_min_cheb)
# fig2 = plot_polyapprox_rotate(pol_lege, TR, df_lege, df_min_lege)
# fig3 = plot_polyapprox_animate2(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig3)
# fig4 = plot_polyapprox_animate2(pol_lege, TR, df_lege, df_min_lege);
# display(fig4)
# fig = plot_polyapprox_flyover(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig)
# fig5 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig5)
# it would be cool to put `analyze_critical_points` inside the `plot_polyapprox_rotate` function. 
# GLMakie.closeall()
