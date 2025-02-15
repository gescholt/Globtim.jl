using Pkg
using Revise
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using GLMakie


# Constants and Parameters
const n, a, b = 2, 5, 1
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder
f = camel # Objective function

d = 12 # Initial Degree 
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
pol_cheb = Constructor(TR, d, basis = :chebyshev)
pol_lege = Constructor(TR, d, basis = :legendre);

@polyvar(x[1:n]); # Define polynomial ring 
df_cheb = solve_and_parse(pol_cheb, x, f, TR)
sort!(df_cheb, :z, rev = true)
df_lege = solve_and_parse(pol_lege, x, f, TR, basis = :legendre)
sort!(df_lege, :z, rev = true)

df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist = 0.003)
df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist = 0.001)

GLMakie.activate!()

# fig1 = plot_polyapprox_rotate(pol_cheb, TR, df_cheb, df_min_cheb)
# fig2 = plot_polyapprox_rotate(pol_lege, TR, df_lege, df_min_lege)
# fig3 = plot_polyapprox_animate2(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig3)

# fig4 = plot_polyapprox_animate2(pol_lege, TR, df_lege, df_min_lege);
# display(fig4)

# fig = plot_polyapprox_flyover(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig)

fig5 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb)
# it would be cool to put `analyze_critical_points` inside the `plot_polyapprox_rotate` function. 
# GLMakie.closeall()
