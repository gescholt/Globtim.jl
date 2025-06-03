#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../globtim"))
# Pkg.status()
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
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(model, outputs, p_true, num_points)

# 

p_test = SVector(0.2, .5)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")

#

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging
n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
@time TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);

# Chebyshev 
@time pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
@time real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
@time df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

println(df_cheb)
@info "" df_cheb

#=
@time df_cheb, df_min_cheb = analyze_critical_points(error_func, df_cheb, TR, tol_dist=0.05);

println(df_min_cheb)
@info "" df_min_cheb

grid = TR.sample_range * generate_grid(n, GN, basis=:chebyshev);
new_grid = map(x -> x + p_center, grid);
values = map(error_func, grid); # Prepare level set data for specific level

using GLMakie
# fig = Globtim.create_level_set_visualization(error_func, new_grid, df_cheb, (0., 1000.))
fig = Globtim.plot_polyapprox_levelset(pol_cheb, TR, df_cheb, df_min_cheb)
# display(fig)
=#
