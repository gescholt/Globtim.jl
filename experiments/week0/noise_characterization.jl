using Pkg
# Pkg.activate(joinpath(@__DIR__, "./../../globtim"))
# Pkg.status()
using Revise
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using Optim
using ModelingToolkit
using OrdinaryDiffEq
using StaticArrays
using DataStructures
using LinearAlgebra
using TimerOutputs
using DynamicPolynomials
using HomotopyContinuation, ProgressLogging

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

#

const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_2D_model()
error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points)

# 

p_test = SVector(0.2, .5)
error_value = error_func(p_test)
@show "" error_value
# _fig1 = plot_parameter_result(model, outputs, p_true, p_test, plot_title="Lotka-Volterra Model Comparison")


n = 2
d = 9
GN = 40
sample_range = 0.25
@polyvar(x[1:n]); # Define polynomial ring 
p_center = p_true + [0.10, 0.0]
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);

# Chebyshev 
pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

# println(df_cheb)
@info "" df_cheb
