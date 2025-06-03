#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../globtim"))
Pkg.status()
using Revise
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using ParameterEstimation
using ModelingToolkit
using OrdinaryDiffEq
using StaticArrays
using DataStructures
using LinearAlgebra

#

include(joinpath(@__DIR__, "../systems/model_eval.jl"))

#

const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[.2, .4, 0.6]
ic = T[0.3, .6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_model()
error_func = make_error_distance(model, outputs, p_true, num_points)

# 

p_test = SVector(0.2, .5, .7)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")

#

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 3
d = 12
GN = 100
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);

# Chebyshev 
@time pol_cheb = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
@time real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
@time df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)
# df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist=0.05);


# grid = TR.sample_range * generate_grid(3, 40, basis=:legendre);
# new_grid = map(x -> x + p_center, grid);
# # values = map(error_func, grid); # Prepare level set data for specific level

# fig = create_level_set_visualization(error_func, new_grid, df_cheb, (0., 1000.))
# display(fig)
