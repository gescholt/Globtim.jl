using Pkg
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
using Makie
using GLMakie

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

reset_timer!(Globtim._TO)

const T = Float64

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging

config = (
    n = 2,
    d = (:one_d_for_all, 10),
    GN = 50,
    time_interval = T[0.0, 1.0],
    p_true = T[0.2, 0.4],
    ic = T[0.3, 0.6],
    num_points = 20,
    sample_range = 0.25,
    p_center = p_true + T[0.2, 0.4],
    distance = log_L2_norm,
    model_func = define_lotka_volterra_2D_model_v2,
)

n = 2
d = (:one_d_for_all, 10)
GN = 50
time_interval = T[0.0, 1.0]
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
sample_range = 0.25
p_center = p_true + [0.10, 0.0]
distance = log_L2_norm
model, params, states, outputs = define_lotka_volterra_2D_model_v2()

error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, num_points,
    distance)

@polyvar(x[1:n]); # Define polynomial ring 
TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=GN,
    sample_range=sample_range);

pol_cheb = Constructor(
    TR, d, basis=:chebyshev, precision=RationalPrecision, verbose=true)
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

plot_range = [-0.3:0.002:0.3, -0.3:0.002:0.3]

fig = Globtim.plot_polyapprox_levelset_2D(
    pol_cheb, TR, df_cheb, p_true, plot_range, distance;
    xlabel = "Parameter 1", ylabel = "Parameter 2",
    colorbar = true, colorbar_label = "Loss Value"
)

@info "" df_cheb

display(fig)

Makie.save(
    joinpath(@__DIR__, "images", "lotka_volterra_2D_error_func1.png"), 
    fig;
    px_per_unit=1.5
)

println("########################################")
println("Lotka-Volterra 2D model with Chebyshev basis")
println("Configuration:")
println("n = ", n)
println("d = ", d)
println("GN = ", GN)
println("sample_range = ", sample_range)
println("p_true = ", p_true)
println("p_center = ", p_center)
println("Distance function: ", distance)
println("Condition number of the polynomial system: ", pol_cheb.cond_vandermonde)
println("L2 norm (error of approximation): ", pol_cheb.nrm)
println("Critical points found:\n", df_cheb)
println("\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:n]...)))[2], :])
# println("\n(after optimization)  Best critical points:\n", df_min_cheb)

println(Globtim._TO)

#=

=#
