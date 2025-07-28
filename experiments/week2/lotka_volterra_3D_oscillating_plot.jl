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

reset_timer!(Globtim._TO)

#

const T = Float64
time_interval = T[0.0, 100.0]
p_true = T[0.3, 0.4, 0.5]
ic = T[1.0, 1.0]
num_points = 100
distance = log_L2_norm
model, params, states, outputs = define_lotka_volterra_3D_model_v2()
error_func =
    make_error_distance(model, outputs, ic, p_true, time_interval, num_points, distance)

plot_range = -0.2:0.05:0.2
params = vcat(
    [
        [p_true[1] + e1, p_true[2] + e2, p_true[3] + e3] for e1 in plot_range for
        e2 in plot_range for e3 in plot_range
    ],
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

Makie.save(
    joinpath(@__DIR__, "images", "lotka_volterra_3D_parameter_map_oscillating_02.png"),
    fig;
    px_per_unit = 1.0,
)


plot_range = -0.4:0.05:0.4
params = vcat(
    [
        [p_true[1] + e1, p_true[2] + e2, p_true[3] + e3] for e1 in plot_range for
        e2 in plot_range for e3 in plot_range
    ],
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

Makie.save(
    joinpath(@__DIR__, "images", "lotka_volterra_3D_parameter_map_oscillating_04.png"),
    fig;
    px_per_unit = 1.0,
)
