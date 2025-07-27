using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using ModelingToolkit
using OrdinaryDiffEq
using LinearAlgebra
using StaticArrays
using SharedArrays
using DataStructures
using Optim
using CairoMakie
CairoMakie.activate!

const T = Float64
time_interval = T[0.0, 2.0]
p_true = T[0.2, 0.4, 0.6]
ic = T[0.3, 0.6]
num_points = 1000
include("model_eval.jl")
model, params, states, outputs = define_lotka_volterra_model()
error_func = make_error_distance(model, outputs, p_true, num_points)

"""
Test
"""
p_test = SVector(0.2, 0.5, 0.7)
error_value = error_func(p_test)
plot_parameter_result(
    model,
    outputs,
    p_true,
    p_test,
    plot_title = "Lotka-Volterra Model Comparison",
)


## Would it make sense to define the error function as the area between the two curves?

"""
Globtim
"""

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 3
@polyvar(x[1:n]); # Define polynomial ring
p_center = p_true + [0.10, 0.0, 0.0]
d = 10
TR = test_input(error_func, dim = n, center = p_center, GN = 40, sample_range = 0.25);

# Chebyshev
pol_cheb = Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision)
real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis = pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)
df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist = 0.05);


grid = TR.sample_range * generate_grid(3, 40, basis = :legendre);
new_grid = map(x -> x + p_center, grid);
# values = map(error_func, grid); # Prepare level set data for specific level

fig = create_level_set_visualization(error_func, new_grid, df_cheb, (0.0, 1000.0))
display(fig)

# GLMakie.closeall()
