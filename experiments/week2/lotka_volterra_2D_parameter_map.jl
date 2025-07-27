#

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
using Makie

#

Revise.includet(joinpath(@__DIR__, "../../Examples/systems/DynamicalSystems.jl"))
using .DynamicalSystems

const T = Float64

#####
#####
# SHORT TIME INTERVAL

time_interval = T[0.0, 1.0]
p_true = T[0.2, 0.4]
ic = T[0.3, 0.6]
num_points = 20
model, params, states, outputs = define_lotka_volterra_2D_model_v2()
error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points)

if false
    plot_range = -0.5:0.05:0.5
    params = vcat(
        [[p_true[1] + e1, p_true[2] + e2] for e1 in plot_range for e2 in plot_range],
        [p_true],
    )
    fig = plot_model_outputs(
        model,
        outputs,
        ic,
        params,
        time_interval,
        num_points;
        ground_truth = length(params),
        plot_title = "Lotka-Volterra Model Outputs $(p_true) ± $plot_range",
    )

    save(joinpath(@__DIR__, "lotka_volterra_2D_parameter_map.png"), fig)
end

if false
    time_interval = T[0.0, 1.0]
    p_true = T[0.2, 0.4]
    ic = T[0.3, 0.6]
    num_points = 20
    model, params, states, outputs = define_lotka_volterra_2D_model_v2()
    error_func = make_error_distance(
        model,
        outputs,
        ic,
        p_true,
        time_interval,
        num_points,
        log_L2_norm,
    )

    plot_range = -0.5:0.02:0.5
    fig = plot_error_function_2D(
        error_func,
        model,
        outputs,
        ic,
        p_true,
        plot_range,
        time_interval,
        num_points;
        ground_truth = length(params),
        plot_title = "Lotka-Volterra Error Function $(p_true) ± $plot_range",
    )

    save(joinpath(@__DIR__, "lotka_volterra_2D_error_func_002.png"), fig)

    time_interval = T[0.0, 1.0]
    p_true = T[0.2, 0.4]
    ic = T[0.3, 0.6]
    num_points = 20
    model, params, states, outputs = define_lotka_volterra_2D_model_v2()
    error_func = make_error_distance(
        model,
        outputs,
        ic,
        p_true,
        time_interval,
        num_points,
        log_L2_norm,
    )

    plot_range = -0.5:0.03:0.5
    fig = plot_error_function_2D(
        error_func,
        model,
        outputs,
        ic,
        p_true,
        plot_range,
        time_interval,
        num_points;
        ground_truth = length(params),
        plot_title = "Lotka-Volterra Error Function $(p_true) ± $plot_range",
    )

    save(joinpath(@__DIR__, "lotka_volterra_2D_error_func_003.png"), fig)
end

#####
#####
# LONGER TIME INTERVAL

if false
    time_interval = T[0.0, 10.0]
    p_true = T[0.9, 0.001]
    ic = T[0.3, 0.6]
    num_points = 20
    model, params, states, outputs = define_lotka_volterra_2D_model_v2()
    error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points)

    data_sample_true = sample_data(model, outputs, time_interval, p_true, ic, num_points)
    # Y_true = data_sample_true[first(keys(data_sample_true))]

    plot_range = -0.5:0.05:0.5
    params = vcat(
        [[p_true[1] + e1, p_true[2] + e2] for e1 in plot_range for e2 in plot_range],
        [p_true],
    )
    fig = plot_model_outputs(
        model,
        outputs,
        ic,
        params,
        time_interval,
        num_points;
        ground_truth = length(params),
        yaxis = log10,
        plot_title = "Lotka-Volterra Model Outputs $(p_true) ± $plot_range",
    )

    save(joinpath(@__DIR__, "lotka_volterra_2D_parameter_map_longer_time.png"), fig)
end

if true
    time_interval = T[0.0, 10.0]
    p_true = T[0.9, 0.1]
    ic = T[10.0, 10.0]
    num_points = 20
    model, params, states, outputs = define_lotka_volterra_2D_model_v2()
    error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points)

    data_sample_true = sample_data(model, outputs, time_interval, p_true, ic, num_points)
    # Y_true = data_sample_true[first(keys(data_sample_true))]

    plot_range = -0.5:0.05:0.5
    params = vcat(
        [[p_true[1] + e1, p_true[2] + e2] for e1 in plot_range for e2 in plot_range],
        [p_true],
    )
    fig = plot_model_outputs(
        model,
        outputs,
        ic,
        params,
        time_interval,
        num_points;
        ground_truth = length(params),
        yaxis = log10,
        plot_title = "Lotka-Volterra Model Outputs $(p_true) ± $plot_range",
    )

    save(joinpath(@__DIR__, "lotka_volterra_2D_parameter_map_longer_time_2.png"), fig)
end
