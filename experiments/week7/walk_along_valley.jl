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
    d = (:one_d_for_all, 30),
    GN = 200,
    time_interval = T[0.0, 1.0],
    p_true = [T[1., 1.]],
    ic = T[100., 100.],
    num_points = 100,
    sample_range = 0.2,
    distance = L2_norm,
    model_func = define_lotka_volterra_2D_model_v3,
    basis = :chebyshev,
    precision = RationalPrecision,
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
    config.distance
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

@info "" df_cheb

id = "$(chopsuffix(basename(@__FILE__), ".jl"))_$(round(Int, config.time_interval[2]))"
filename = "$(id)_$(config.model_func)_$(config.distance)"
@info "Saving results to file: $(filename)"

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
    println(io, Globtim._TO)
end

println(Globtim._TO)

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

    DynamicalSystems.plot_model_outputs(
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
        joinpath(@__DIR__, "images", "2D-$(filename).png"),
        fig,
        px_per_unit = 1.5
    )
end

if true
figure_size = (800, 600)
fig = Figure(size = figure_size)
ax = Axis(fig[1, 1],
    xlabel = "Parameter 1",
    ylabel = "error_func",
    title = "error_func, walk along valley (parameter 2 := 1.0)",
)

p1_delta = 0.0:0.001:0.00
p2 = 0.9:0.001:1.265
for (i, delta) in enumerate(p1_delta)
    values = error_func.([[p, 1.0+delta] for p in p2])
    lines!(ax, p2, values,
        color=:blue,
        alpha = (length(p1_delta) - i + 1) / length(p1_delta),
    )
    values = error_func.([[p, 1.0-delta] for p in p2])
    lines!(ax, p2, values,
        color=:blue,
        alpha = (length(p1_delta) - i + 1) / length(p1_delta),
    )
end
scatter!(
    ax,
    df_cheb.x1,
    error_func.([[df_cheb.x1[i], 1.0] for i in 1:nrow(df_cheb)]),
    markersize = 10,
    color = :blue,
    marker = :diamond,
    label = "Critical Points of w_d",
)
tp = scatter!(
    ax,
    [config.p_true[1][1]],
    [error_func(config.p_true[1])],
    markersize = 10,
    color = :green,
    marker = :diamond,
    label = "True Parameter",
)

ax = Axis(fig[1, 2],
    xlabel = "Parameter 1",
    ylabel = "w_d",
    title = "w_d, walk along valley (parameter 2 := 1.0)",
)
pullback(x) = (1 / pol_cheb.scale_factor) * (x .- TR.center)
poly_func(poly) =
    p -> (
        cfs = DynamicPolynomials.coefficients(DynamicPolynomials.subs(poly, x => p));
        isempty(cfs) ? 0.0 : cfs[1]
    )
for (i, delta) in enumerate(p1_delta)
    values = poly_func(wd_in_std_basis).(([(pullback([p, 1.0+delta])) for p in p2]))
    lines!(ax, p2, values,
        color=:blue,
        alpha = (length(p1_delta) - i + 1) / length(p1_delta),
    )
    values = poly_func(wd_in_std_basis).(([pullback([p, 1.0-delta]) for p in p2]))
    lines!(ax, p2, values,
        color=:blue,
        alpha = (length(p1_delta) - i + 1) / length(p1_delta),
    )
end
cp = scatter!(
    ax,
    df_cheb.x1,
    poly_func(wd_in_std_basis).((pullback.([[df_cheb.x1[i], 1.0] for i in 1:nrow(df_cheb)]))),
    markersize = 10,
    color = :blue,
    marker = :diamond,
    label = "Critical Points of w_d",
)
Legend(fig[2, 1], [tp, cp], ["True Parameter", "Critical Points of w_d"],
    orientation = :horizontal, fontsize = 12,
    tellheight = false,
    framevisible = false
)

display(fig)

Makie.save(
    joinpath(@__DIR__, "images", "valley_$(filename).png"),
    fig,
    px_per_unit = 1.5
)
end
