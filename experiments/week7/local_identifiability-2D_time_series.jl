using Pkg; Pkg.activate(@__DIR__)

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
    d = (:one_d_for_all, 14),
    GN = 300,
    time_interval = T[0.0, 1.0],
    p_true = [T[0.3, 0.1], T[0.3, -0.1]],
    ic = T[0.3],
    num_points = 20,
    sample_range = 0.3,
    distance = log_L2_norm,
    model_func = define_simple_2D_model_locally_identifiable_square,
    basis = :chebyshev,
    precision = RationalPrecision,
    my_eps = 0.02,
    fine_step = 0.002,
)
config = merge(
    config,
    (;
        plot_range = [
            -(config.sample_range+config.my_eps):config.fine_step:(config.sample_range+config.my_eps),
            -(config.sample_range+config.my_eps):config.fine_step:(config.sample_range+config.my_eps),
        ],
        p_center = [config.p_true[1][1] + 0.05, config.p_true[1][2] - 0.05],
    ),
)

model, params, states, outputs = config.model_func()

error_func = make_error_distance(
    model,
    outputs,
    config.ic,
    config.p_true[1],
    config.time_interval,
    config.num_points,
    config.distance,
)

@polyvar(x[1:config.n]); # Define polynomial ring
TR = test_input(
    error_func,
    dim = config.n,
    center = config.p_center,
    GN = config.GN,
    sample_range = config.sample_range,
);

pol_cheb = Constructor(
    TR,
    config.d,
    basis = config.basis,
    precision = config.precision,
    verbose = true,
)
real_pts_cheb, (wd_in_std_basis, _sys, _nsols) = solve_polynomial_system(
    x,
    config.n,
    config.d,
    pol_cheb.coeffs;
    basis = pol_cheb.basis,
    return_system = true,
)
df_cheb = process_crit_pts(real_pts_cheb, error_func, TR)

@info "" df_cheb

id = "id_2D_time_series"
filename = "$(id)_$(config.model_func)_$(config.distance)"

open(joinpath(@__DIR__, "images", "$(filename).txt"), "w") do io
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
        prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys)),
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
    params_to_plot = [
        config.p_true[1],
        config.p_true[2],
        [0.249981,  -0.169133],
        [0.248937,   0.167269]
    ]
    fig = plot_model_outputs(
        model, outputs, config.ic, 
        params_to_plot,
        config.time_interval, config.num_points; 
        ground_truth=1,
        yaxis=identity,
        plot_title="$(config.model_func)", 
        param_alpha=0.8
    )

    for params_to_plot_i in params_to_plot
        @info "Error($params_to_plot_i) = $(error_func(params_to_plot_i))"
    end
    for delta in [1e-2, 1e-4, 1e-6, 1e-8, -1e-10]
        @info "Error(p_true ± $delta) = $(error_func(config.p_true[1] .+ rand(2).*delta))"
    end

    display(fig)

    Makie.save(
        joinpath(@__DIR__, "images", "$(filename).png"),
        fig,
        px_per_unit = 1.5,
    )
end

#=
### log L2 norm ###
[ Info: Error([0.3, 0.1]) = -52.0
[ Info: Error([0.3, -0.1]) = -52.0
[ Info: Error([0.249981, -0.169133]) = -7.721011396657498
[ Info: Error([0.248937, 0.167269]) = -8.787352906655608
[ Info: Error(p_true ± 0.01) = -6.265174250552587
[ Info: Error(p_true ± 0.0001) = -13.050909032442767
[ Info: Error(p_true ± 1.0e-6) = -20.167865644175965
[ Info: Error(p_true ± 1.0e-8) = -27.470041301226143
[ Info: Error(p_true ± -1.0e-10) = -33.27346932407395

### L2 norm ###
[ Info: Error([0.3, 0.1]) = 0.0
[ Info: Error([0.3, -0.1]) = 0.0
[ Info: Error([0.249981, -0.169133]) = 0.0047396249036172474
[ Info: Error([0.248937, 0.167269]) = 0.0022633055720136333
[ Info: Error(p_true ± 0.01) = 0.008578687008827838
[ Info: Error(p_true ± 0.0001) = 5.551985414331886e-5
[ Info: Error(p_true ± 1.0e-6) = 5.282405837968955e-7
[ Info: Error(p_true ± 1.0e-8) = 6.654566471458377e-9
[ Info: Error(p_true ± -1.0e-10) = 4.420918408418936e-11
=#
