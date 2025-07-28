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
    d = (:one_d_for_all, 12),
    GN = 300,
    time_interval = T[0.0, 1.0],
    p_true = T[0.3, 0.1],
    ic = T[0.3],
    num_points = 20,
    sample_range = 0.5,
    distance = L2_norm,
    model_func = define_simple_2D_model_locally_identifiable_square,
    basis = :chebyshev,
    precision = RationalPrecision
)
config = merge(config, (; p_center = [0.35, 0.35]))

model, params, states, outputs = config.model_func()

error_func = make_error_distance(
    model,
    outputs,
    config.ic,
    config.p_true,
    config.time_interval,
    config.num_points,
    config.distance
)

@polyvar(x[1:config.n]); # Define polynomial ring
TR = test_input(
    error_func,
    dim = config.n,
    center = config.p_center,
    GN = config.GN,
    sample_range = config.sample_range
);

pol_cheb = Constructor(
    TR,
    config.d,
    basis = config.basis,
    precision = config.precision,
    verbose = true
)
real_pts_cheb, (wd_in_std_basis, _sys, _nsols) = solve_polynomial_system(
    x,
    config.n,
    config.d,
    pol_cheb.coeffs;
    basis = pol_cheb.basis,
    return_system = true
)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

@info "" df_cheb

id = "id22"

open(joinpath(@__DIR__, "images", "$(id)_lotka_volterra_2D_error_func1.txt"), "w") do io
    println(io, "config = ", config, "\n\n")
    println(io, "Condition number of the Vandermonde system: ", pol_cheb.cond_vandermonde)
    println(io, "L2 norm (error of approximation): ", pol_cheb.nrm)
    println(io, "Polynomial system:")
    println(io, "   Number of sols: ", _nsols)
    println(
        io,
        "   Bezout bound: ",
        map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys),
        " which is ",
        prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys))
    )
    println(io, "Critical points found:\n", df_cheb)
    if !isempty(df_cheb)
        println(io, "Number of critical points: ", nrow(df_cheb))
    else
        println(io, "No critical points found.")
    end
    println(io, Globtim._TO)
end

println(Globtim._TO)

if true
    plot_range = -0.5:0.002:0.5
    fig = plot_error_function_2D(
        error_func,
        model,
        outputs,
        config.ic,
        config.p_true,
        plot_range,
        config.time_interval,
        config.num_points;
        ground_truth = length(params),
        plot_title = "Locally Identifiable model Error Function $(config.p_true) ± $plot_range"
    )

    display(fig)

    Makie.save(
        joinpath(@__DIR__, "images", "$(id)_locally_ident_2D_error_func.png"),
        fig,
        px_per_unit = 1.5
    )
end
