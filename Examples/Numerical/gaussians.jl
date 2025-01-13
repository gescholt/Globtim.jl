using Pkg
using Revise 
Pkg.activate(".")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using GLMakie


# Constants and Parameters
const n, a, b = 2, 1, 1
const scale_factor = a / b   # Size of domain. 
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 3e-4 # Placeholder

N = 12
params = init_gaussian_params(n, N, .6, 0.2)
# Create a closure that captures params
rand_gaussian_closure = (x) -> rand_gaussian(x, params)
f = rand_gaussian_closure;

d = 20 # Initial Degree 
SMPL = 80 # Number of samples
center = [0.0, 0.0]
TR = test_input(f,
    dim=n,
    center=[0.0, 0.0],
    GN=SMPL,
    sample_range=scale_factor,
    tolerance=tol_l2,
)
pol_cheb = Constructor(TR, d, basis=:chebyshev)
pol_lege = Constructor(TR, d, basis=:legendre);

@polyvar(x[1:n]); # Define polynomial ring 

real_pts_cheb = solve_polynomial_system(x, TR.dim, pol_cheb.degree, pol_cheb.coeffs; basis=:chebyshev, bigint=true)
real_pts_lege = solve_polynomial_system(x, TR.dim, pol_lege.degree, pol_lege.coeffs; basis=:legendre, bigint=true)
df_cheb = process_critical_points(real_pts_cheb, f, TR)
df_lege = process_critical_points(real_pts_lege, f, TR)
df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=1.)
df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=1.)

GLMakie.activate!()

fig1 = plot_polyapprox_rotate(pol_cheb, TR, df_cheb, df_min_cheb)
# fig2 = plot_polyapprox_rotate(pol_lege, TR, df_lege, df_min_lege)
# fig3 = plot_polyapprox_animate2(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig3)

# fig4 = plot_polyapprox_animate2(pol_lege, TR, df_lege, df_min_lege);
# display(fig4)

# fig = plot_polyapprox_flyover(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig)

fig5 = plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb)
display(fig5)

# fig6 = plot_polyapprox_levelset(pol_lege, TR, df_lege, df_min_lege)
# display(fig6)
# it would be cool to put `analyze_critical_points` inside the `plot_polyapprox_rotate` function. 
# GLMakie.closeall()
