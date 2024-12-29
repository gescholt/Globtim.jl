using Pkg
Pkg.activate("../../.")
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging

# Constants and Parameters
const n, a, b = 2, 5, 1
const scale_factor = a / b   # Scaling factor appears in `main_computation`, maybe it should be a parameter.
const delta, alpha = 0.9,  8 / 10  # Sampling parameters
const tol_l2 = 3e-4            # Define the tolerance for the L2-norm
f = camel # Objective function

center = [0.0, 0.0]

d = 6 # Initial Degree 
# SMPL = calculate_samples(binomial(n + d, d), delta, alpha)#Number of samples is too LinearAlgebra
SMPL = 60
TR = test_input(f,
    dim=n,
    center=[0.0, 0.0],
    GN=SMPL,
    sample_range=scale_factor
)
pol_cheb = Constructor(TR, d, basis=:chebyshev)
pol_lege = Constructor(TR, d, basis=:legendre)

@polyvar(x[1:n]) # Define polynomial ring 

real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis=:chebyshev, bigint=true)
df_cheb = process_critical_points(real_pts_cheb, f, scale_factor)
println(df_cheb)

real_pts_lege = solve_polynomial_system(x, n, d, pol_lege.coeffs; basis=:legendre, bigint=true)
df_lege = process_critical_points(real_pts_lege, f, scale_factor)
println(df_lege)

ms_cheb = msolve_polynomial_system(pol_cheb, x; n=2, basis=:chebyshev, bigint=true)