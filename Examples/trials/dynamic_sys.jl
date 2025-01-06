using Pkg
Pkg.activate("/home/user/Globtim.jl/Examples")
using ModelingToolkit
using OrdinaryDiffEq
using DataStructures
using LinearAlgebra
using StaticArrays
using SharedArrays


const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[0.11, 0.22, 0.33]
ic = T[0.11, 0.15]
num_points = 6
include("model_eval.jl")
model, params, states, outputs = define_lotka_volterra_model()
error_func = make_error_distance(model, outputs, p_true, num_points)

""" 
Test
"""

p_test = SVector(0.55, 0.048, -0.73)  # Example test parameters
error_value = error_func(p_test)
error_func([.1, .2, .3])

"""
Globtim
"""

p_center = p_true + [0.1, 0.0, 0.0]

n = 3
d = 12
Pkg.develop(path="/home/user/Globtim.jl")
using Globtim
using DynamicPolynomials
@polyvar(x[1:n]); # Define polynomial ring 

TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=15,
    sample_range=1//8
);

# Chebyshev 
pol_cheb = Constructor(TR, d, basis=:chebyshev);
@time msolve_polynomial_system(pol_cheb, x; n=3, basis=:chebyshev, bigint=true);
df_cheb = msolve_parser("outputs.ms", error_func, TR)

using HomotopyContinuation, ProgressLogging
@time real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis=:chebyshev, bigint=true)
df_cheb_2 = process_critical_points(real_pts_cheb, error_func, TR.sample_range, n, TR = TR)
# this has not been translated to the new position yet (center)


# Legendre
pol_lege = Constructor(TR, d, basis=:legendre);
msolve_polynomial_system(pol_lege, x; n=3, basis=:legendre, bigint=true);
df_lege = msolve_parser("outputs.ms", error_func, TR)


## The homotopy Continuation version too.

using GLMakie

include("Visual.jl")
# """What do we want to achieve here?"""


# Generate grid and evaluate 
grid = generate_grid(3, 20)  # 3D space with 50 points per dimension
values = map(error_func, grid)
# Prepare level set data for specific level
level_set = prepare_level_set_data(grid, values, 1.0, tolerance=0.2)

plot_level_set(to_makie_format(level_set))