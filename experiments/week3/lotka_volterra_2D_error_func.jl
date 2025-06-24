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
    d = (:fully_custom, EllipseSupport([0, 0], [1, 1], 700)),
    GN = 1200,
    time_interval = T[0.0, 1.0],
    p_true = T[0.2, 0.4],
    ic = T[0.3, 0.6],
    num_points = 20,
    sample_range = 0.25,
    p_center = [0.1, 0.0] + T[0.2, 0.4],
    distance = L2_norm,
    model_func = define_lotka_volterra_2D_model_v2,
    basis = :chebyshev,
    precision = RationalPrecision,
    my_eps = 0.02,
    fine_step = 0.002,
)
config = merge(
    config,
    Dict(
        :plot_range => [-(config.sample_range+config.my_eps):config.fine_step:(config.sample_range+config.my_eps), -(config.sample_range+config.my_eps):config.fine_step:(config.sample_range+config.my_eps)]
    )
)

model, params, states, outputs = config.model_func()

error_func = make_error_distance(
    model, outputs, config.ic, config.p_true, config.time_interval, config.num_points, config.distance)

@polyvar(x[1:config.n]); # Define polynomial ring 
TR = test_input(
    error_func,
    dim=config.n,
    center=config.p_center,
    GN=config.GN,
    sample_range=config.sample_range);

pol_cheb = Constructor(
    TR, config.d, basis=config.basis, precision=config.precision, verbose=true)
real_pts_cheb, (wd_in_std_basis, _sys, _nsols) = solve_polynomial_system(
    x, config.n, config.d, pol_cheb.coeffs;
    basis=pol_cheb.basis, return_system=true)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

fig = Globtim.plot_polyapprox_levelset_2D(
    pol_cheb, TR, df_cheb, x, wd_in_std_basis, config.p_true, config.plot_range, config.distance;
    xlabel = "Parameter 1", ylabel = "Parameter 2",
    colorbar = true, colorbar_label = "Loss Value",
    num_levels=200
)

@info "" df_cheb

display(fig)

id = "id11"

Makie.save(
    joinpath(@__DIR__, "images", "$(id)_lotka_volterra_2D_error_func1.png"), 
    fig;
    px_per_unit=1.5
)

open(joinpath(@__DIR__, "images", "$(id)_lotka_volterra_2D_error_func1.txt"), "w") do io
    println(
        io,
        "config = ", config,
        "\n\n"
    )
    println(io, "Condition number of the Vandermonde system: ", pol_cheb.cond_vandermonde)
    println(io, "L2 norm (error of approximation): ", pol_cheb.nrm)
    println(io, "Polynomial system:")
    println(io, "   Number of sols: ", _nsols)
    println(io, "   Bezout bound: ", map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys), " which is ", prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys)))
    println(io, "Critical points found:\n", df_cheb)
    println(io, "\n(before optimization) Best critical points:\n", df_cheb[findmin(map(p -> abs(sum((p .- config.p_true).^2)), zip([getproperty(df_cheb, Symbol(:x, i)) for i in 1:config.n]...)))[2], :])
    println(io, Globtim._TO)
end

println(Globtim._TO)
