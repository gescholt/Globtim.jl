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
# using GLMakie

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

# Create a local timer if _TO is not accessible
if !@isdefined(_TO)
    const _TO = TimerOutputs.TimerOutput()
end
reset_timer!(_TO)

const T = Float64

using DynamicPolynomials
using HomotopyContinuation, ProgressLogging

config = (
    n = 2,
    d = (:one_d_for_all, 30),
    GN = 200,
    time_interval = T[0.0, 1.0],
    p_true = [T[1., 1.]],
    ic = T[100., 100.],
    num_points = 100,
    sample_range = 0.2,
    distance = log_L2_norm,
    aggregate_distances = sum,
    model_func = define_lotka_volterra_2D_model_v3_two_outputs,
    basis = :chebyshev,
    precision = Globtim.RationalPrecision,
    my_eps = 0.02,
    fine_step = 0.002,
    coarse_step = 0.02,
)
config = merge(
    config,
    (;
        plot_range = [
            (-(config.sample_range + config.my_eps)):config.fine_step:(config.sample_range + config.my_eps),
            (-(config.sample_range + config.my_eps)):config.fine_step:(config.sample_range + config.my_eps),
        ],
        plot_range_coarse = [
            (-(config.sample_range + config.my_eps)):config.coarse_step:(config.sample_range + config.my_eps),
            (-(config.sample_range + config.my_eps)):config.coarse_step:(config.sample_range + config.my_eps),
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
    config.aggregate_distances
)
# coeff = error_func_([1.0, 1.1]) / error_func_([1.1, 1.0])
# error_func = x -> error_func_([x[1], 1.0 + (x[2] - 1.0) / coeff])


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

@info "" sort(df_cheb, [:z])

id = "$(chopsuffix(basename(@__FILE__), ".jl"))"
filename = "$(id)_$(config.model_func)_$(config.distance)_$(config.aggregate_distances)"

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
        prod(map(eq -> HomotopyContinuation.ModelKit.degree(eq), _sys))
    )
    println(io, "Critical points found:\n", df_cheb)
    if !isempty(df_cheb)
        println(io, "Number of critical points: ", nrow(df_cheb))
    else
        println(io, "No critical points found.")
    end
    println(io, _TO)
end

println(_TO)

if true
    params_to_plot = [config.p_true[1],]
    params_to_plot = vcat(params_to_plot, 
    [
        [config.p_true[1][1] .+ e1, config.p_true[1][2] + e2] 
        for e1 in config.plot_range_coarse[1] for e2 in config.plot_range_coarse[2]
    ])

    figure_size = (1200, 1000)
    fig = Figure(size = figure_size)
    Globtim.plot_error_function_2D_with_critical_points(
        fig[1, 1:2],
        pol_cheb,
        TR,
        df_cheb,
        x,
        wd_in_std_basis,
        config.p_true,
        config.plot_range,
        config.distance;
        xlabel = "Parameter 1",
        ylabel = "Parameter 2",
        colorbar = true,
        colorbar_label = "Loss Value",
        num_levels = 200,
        model_func = config.model_func,
        critical_point_threshold_for_hessian = Inf,
    )

    DynamicalSystems.plot_model_outputs_several(
        fig[2, 1:2],
        config,
        model, outputs, config.ic, 
        params_to_plot,
        config.time_interval, config.num_points; 
        ground_truth=1,
        yaxis=identity,
        plot_title="$(config.model_func)", 
        param_alpha=0.1,
    )

    display(fig)

    Makie.save(
        joinpath(@__DIR__, "images", "$(filename).png"),
        fig,
        px_per_unit = 1.5
    )
end
