module DynamicalSystems

using ModelingToolkit
using StaticArrays
using OrdinaryDiffEq
using DataStructures
using LinearAlgebra

export define_lotka_volterra_model,
    define_lotka_volterra_3D_model,
    define_lotka_volterra_2D_model,
    define_lotka_volterra_2D_model_v2,
    define_lotka_volterra_2D_model_v3,
    define_lotka_volterra_3D_model_v2,
    define_fitzhugh_nagumo_3D_model,
    sample_data,
    make_error_distance,
    plot_time_series_comparison,
    plot_parameter_result,
    plot_model_outputs,
    plot_error_function_2D,
    log_L2_norm,
    L1_norm,
    L2_norm,
    EllipseSupport,
    define_simple_2D_model_locally_identifiable,
    define_simple_2D_model_locally_identifiable_square,
    define_simple_1D_model_locally_identifiable

function define_fitzhugh_nagumo_3D_model()
    @independent_variables t
    @parameters g a b
    @variables V(t) R(t) y1(t)
    D = Differential(t)
    states = [V, R]
    params = [g, a, b]
    outputs = [y1 ~ V]
    @named model = ODESystem(
        [D(V) ~ g * (V - V^3 / 3 + R), D(R) ~ 1 / g * (V - a + b * R)],
        t,
        states,
        params
    )
    return model, params, states, outputs
end

function define_lotka_volterra_3D_model()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b c
    D = Differential(t)
    params = [a, b, c]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + b * x1 * x2, D(x2) ~ b * x1 * x2 + c * x2],
        t,
        states,
        params
    )
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function define_lotka_volterra_3D_model_v2()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b c
    D = Differential(t)
    params = [a, b, c]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + -b * x1 * x2, 
        D(x2) ~ -b * x2 + c * x1 * x2],
        t,
        states,
        params
    )
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

# c := 1
function define_lotka_volterra_2D_model()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b
    D = Differential(t)
    params = [a, b]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + b * x1 * x2, D(x2) ~ b * x1 * x2 + x2],
        t,
        states,
        params
    )
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

# c := 0.5
function define_lotka_volterra_2D_model_v3()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b
    D = Differential(t)
    params = [a, b]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + -b * x1 * x2, 
        D(x2) ~ -b * x2 + 0.5 * x1 * x2],
        t,
        states,
        params
    )
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

# c := 0.1
function define_lotka_volterra_2D_model_v2()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b
    D = Differential(t)
    params = [a, b]
    states = [x1, x2]
    @named model = ODESystem(
        [
            D(x1) ~ a * x1 + b * x1 * x2, 
            D(x2) ~ b * x1 * x2 + 0.1 * x2],
        t,
        states,
        params
    )
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function define_simple_2D_model_locally_identifiable()
    @independent_variables t
    @variables x1(t) y1(t)
    @parameters a b
    D = Differential(t)
    params = [a, b]
    states = [x1]
    @named model = ODESystem([D(x1) ~ a * b * x1 + (a + b)], t, states, params)
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function define_simple_2D_model_locally_identifiable_square()
    @independent_variables t
    @variables x1(t) y1(t)
    @parameters a b
    D = Differential(t)
    params = [a, b]
    states = [x1]
    @named model = ODESystem([D(x1) ~ a * x1 + b^2], t, states, params)
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function define_simple_1D_model_locally_identifiable()
    @independent_variables t
    @variables x1(t) y1(t)
    @parameters a
    D = Differential(t)
    params = [a]
    states = [x1]
    @named model = ODESystem([D(x1) ~ x1 + a^2], t, states, params)
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function sample_data(
    model::ModelingToolkit.ODESystem,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval,
    p_true,
    u0,
    num_points::Int;
    kwargs...
) where {T<:Number}

    N = length(p_true)
    return sample_data(
        model,
        measured_data,
        time_interval,
        SVector{N,T}(p_true),
        u0,
        num_points;
        kwargs...
    )
end

"""
    sample_data(model::ModelingToolkit.ODESystem,
                measured_data::Vector{ModelingToolkit.Equation},
                time_interval::Vector{T},
                p_true::SVector{N,T},
                u0::Vector{T},
                num_points::Int;
                kwargs...) where {N<:Integer,T<:Number}

Generate synthetic time series data from an ODE system with specified parameters.

Arguments:
- `model`: ModelingToolkit ODESystem representing the differential equations
- `measured_data`: Vector of measurement equations
- `time_interval`: [start_time, end_time] for simulation
- `p_true`: SVector of true parameter values
- `u0`: Vector of initial conditions
- `num_points`: Number of time points to sample

Optional kwargs:
- `uneven_sampling`: Boolean for non-uniform time sampling
- `uneven_sampling_times`: Vector of specific sampling times
- `solver`: ODE solver (default: Vern9())
- `inject_noise`: Boolean for adding measurement noise
- `mean_noise`: Mean of Gaussian noise
- `stddev_noise`: Standard deviation of Gaussian noise
- `abstol`: Absolute tolerance for solver
- `reltol`: Relative tolerance for solver

Returns:
    OrderedDict containing time series data for each measured variable
"""
function sample_data(
    problem,
    model,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval::Vector{T},
    p_true,
    u0,
    num_points::Int;
    uneven_sampling = false,
    uneven_sampling_times = Vector{T}(),
    solver = Vern9(),
    inject_noise = false,
    mean_noise = zero(T),
    stddev_noise = one(T),
    abstol = convert(T, 1e-14),
    reltol = convert(T, 1e-14)
) where {T <: Number}

    @assert length(time_interval) == 2 "Time interval must be [start_time, end_time]"

    if uneven_sampling
        if length(uneven_sampling_times) == 0
            error("No uneven sampling times provided")
        end
        if length(uneven_sampling_times) != num_points
            error("Uneven sampling times must be of length num_points")
        end
        sampling_times = uneven_sampling_times
    else
        sampling_times = range(time_interval[1], time_interval[2], length = num_points)
    end

    problem.p.tunable .= p_true
    solution_true =
        ModelingToolkit.solve(problem, solver, saveat = sampling_times; abstol, reltol)

    data_sample = DataStructures.OrderedDict{Any, Vector{T}}(
        Num(v.lhs) => solution_true[Num(v.rhs)] for v in measured_data
    )

    # println("data_sample: ", data_sample)

    if inject_noise
        for (key, sample) in data_sample
            data_sample[key] = sample + randn(num_points) .* stddev_noise .+ mean_noise
        end
    end

    data_sample["t"] = sampling_times
    return data_sample
end

L1_norm(Y_true, Y_test) = 100 * norm(Y_true - Y_test, 1)
L2_norm(Y_true, Y_test) = norm(Y_true - Y_test, 2)
log_L2_norm(Y_true, Y_test) = log2(norm(Y_true - Y_test, 2) + eps(eltype(Y_true)))

"""
    make_error_distance(model::ModelingToolkit.ODESystem,
                       outputs::Vector{ModelingToolkit.Equation},
                       p_true::SVector{N,Float64},
                       distance_function) where {N<:Integer}

Construct an error function comparing model predictions against reference data.

Arguments:
- `model`: ModelingToolkit ODESystem
- `outputs`: Vector of measurement equations
- `initial_conditions`: Vector of initial conditions for the ODE system
- `p_true`: SVector of true parameter values
- `time_interval`: Time interval [start_time, end_time] for simulation
- `numpoints`: Number of time points to sample (default: 5)
- `distance_function`: Function to compute distance (default: L2_norm).
    The function should take two vectors (true and predicted) and return a scalar distance value.

Returns:
    Function that computes error between predictions and reference data
"""
function make_error_distance(
    model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    initial_conditions::Vector{Float64},
    p_true::Vector{T},
    time_interval,
    numpoints::Int = 5,
    distance_function = L2_norm,
    add_noise_in_time_series = nothing
) where {T}
    @assert length(p_true) == length(ModelingToolkit.parameters(model)) "Parameter vector length mismatch"
    @assert length(initial_conditions) == length(ModelingToolkit.unknowns(model)) "Initial conditions length mismatch"
    @assert length(outputs) > 0 "At least one output variable must be specified"
    @assert numpoints > 0 "Number of points must be greater than zero"
    @assert time_interval[2] > time_interval[1] "End time must be greater than start time"

    # Generate reference solution once during function creation
    problem = ODEProblem(
        ModelingToolkit.complete(model),
        merge(
            Dict(ModelingToolkit.unknowns(model) .=> initial_conditions),
            Dict(ModelingToolkit.parameters(model) .=> p_true)
        ),
        time_interval,
    )

    data_sample_true = sample_data(
        problem,
        model,
        outputs,
        time_interval,
        p_true,
        initial_conditions,
        numpoints
    )
    Y_true = data_sample_true[first(keys(data_sample_true))]

    if add_noise_in_time_series !== nothing
        Y_true = add_noise_in_time_series(Y_true)
    end

    function Error_distance(
        p_test::Union{SVector{N,T2},Vector{T2}};
        measured_data=outputs,
        time_interval=time_interval,
        datasize=numpoints
    ) where {T2,N}

        # problem = remake(problem, p = Dict(ModelingToolkit.parameters(model) .=> p_test))
        try
            if datasize != length(Y_true)
                println("case 1")
                return NaN
            end

            data_sample_test = sample_data(
                problem,
                model,
                measured_data,
                time_interval,
                p_test,
                initial_conditions,
                datasize
            )

            if isempty(data_sample_test) ||
               !haskey(data_sample_test, first(keys(data_sample_test)))
                println("case 2")
                return NaN
            end

            Y_test = data_sample_test[first(keys(data_sample_test))]

            if any(isnan.(Y_test)) ||
               any(isinf.(Y_test)) ||
               any(isnan.(Y_true)) ||
               any(isinf.(Y_true))
                println("case 3")
                return NaN
            end

            return distance_function(Y_true, Y_test)
            # return 100 * norm(Y_true - Y_test, 1)
            # return log(norm(Y_true - Y_test, 2) + eps(T))
        catch e
            # So that Ctrl+C works
            if isa(e, InterruptException)
                rethrow(e)
            end
            println("case 4")
            # println("Error in make_error_distance: ", e)
            return NaN
        end
    end

    return Error_distance
end

# using CairoMakie
using GLMakie
using StaticArrays
using ModelingToolkit

function plot_model_outputs(
    fig,
    config,
    model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    ic::Vector{T},
    parameter_values::Vector{A},
    time_interval,
    num_points;
    ground_truth = nothing,
    yaxis = identity,
    plot_title = "Model Outputs",
    figure_size = (800, 500),
    param_alpha = 0.1,
    ax = nothing
) where {T<:Number,A}

    @assert length(parameter_values) > 0 "At least one parameter set must be provided"
    @assert length(ic) == length(ModelingToolkit.unknowns(model)) "Initial conditions length mismatch"

    ax = Axis(
        fig[1, 1],
        title = "$(config.model_func)",
        xlabel = "Time",
        ylabel = "y(t)",
        yscale = identity
    )

    green, blue = nothing, nothing
    # Generate data for each parameter set
    for (idx, p) in enumerate(parameter_values)
        problem = ODEProblem(
            ModelingToolkit.complete(model),
            merge(
                Dict(ModelingToolkit.unknowns(model) .=> ic),
                Dict(ModelingToolkit.parameters(model) .=> p)
            ),
            time_interval,
        )
        data_sample = sample_data(problem, model, outputs, time_interval, p, ic, num_points)

        # Extract time points
        t = data_sample["t"]

        # Plot each output variable
        for (key, values) in data_sample

            if length(values) != num_points
                println(
                    "Skipping parameter set $(idx) - $(key) due to mismatched data length"
                )
                continue
            end

            if key == "t"
                continue  # Skip time array
            end

            if idx == ground_truth
                # Highlight ground truth in a different color
                color = :green
                alpha = 1.0
                linewidth = 3
                # label = "Ground truth: parameters are $(p)"
                style = :solid
                green = lines!(
                    ax,
                    t,
                    values,
                    linewidth = linewidth,
                    color = color,
                    linestyle = style,
                    alpha = alpha
                )
            else
                color = :blue
                alpha = param_alpha
                linewidth = 1
                label = nothing # "Set $(idx) - $(key) - $(p)"
                style = :solid
                blue = lines!(
                    ax,
                    t,
                    values,
                    linewidth = linewidth,
                    color = color,
                    linestyle = style,
                    alpha = alpha
                )
            end
        end
    end

    Legend(
        fig[1, 1],
        [green, blue],
        ["Ground Truth, parameters are $(round.(config.p_true[1], digits=2))", "Parameters from $(round.(minimum(parameter_values), digits=2)) to $(round.(maximum(parameter_values), digits=2))"],
        orientation = :vertical,  # Make legend horizontal for better space usage
        tellwidth = false,         # Don't have legend width affect layout
        tellheight = false,
        halign = :left, valign = :top,
        # patchsize = (30, 20),
    )

    # return fig
end

function plot_error_function_2D(
    error_func,
    model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    ic::Vector{T},
    p_true,
    plot_range,
    time_interval,
    num_points;
    ground_truth = nothing,
    plot_title = "Error Function",
    figure_size = (800, 500)
) where {T <: Number}

    @assert length(ic) == length(ModelingToolkit.unknowns(model)) "Initial conditions length mismatch"

    # Create figure and axis
    fig = Figure(size = figure_size)
    ax = Axis(fig[1, 1], title = plot_title, xlabel = "Parameter 1", ylabel = "Parameter 2")

    errors = [
        [error_func([p_true[1] + e1, p_true[2] + e2]) for e1 in plot_range] for
        e2 in plot_range
    ]
    errors = hcat(errors...)  # Convert to matrix form

    # Plot the error surface
    hm = heatmap!(ax, plot_range, plot_range, errors, colormap = :viridis)
    cbar = Colorbar(fig[1, 2], hm)

    return fig
end

"""
    plot_time_series_comparison(model::ModelingToolkit.ODESystem,
                              outputs::Vector{ModelingToolkit.Equation},
                              p_true::Union{Vector{T}, SVector{N,T}},
                              p_test::Union{Vector{T}, SVector{N,T}},
                              numpoints::Int=100;
                              time_interval::Vector{T}=[0.0, 1.0],
                              plot_title::String="Time Series Comparison",
                              figure_size=(800, 500)) where {N,T<:Number}

Plot comparison between time series generated with true and test parameters using CairoMakie.

Arguments:
- `model`: ModelingToolkit ODESystem
- `outputs`: Vector of measurement equations
- `p_true`: Vector or SVector of true parameter values
- `p_test`: Vector or SVector of test parameter values
- `numpoints`: Number of time points to sample (default: 100)
- `time_interval`: Time interval [start_time, end_time] (default: [0.0, 1.0])
- `plot_title`: Title for the plot (default: "Time Series Comparison")
- `figure_size`: Tuple of (width, height) for the figure (default: (800, 500))

Returns:
    Makie.Figure object containing the comparison plot
"""
function plot_time_series_comparison(
    model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    ic,
    time_interval,
    p_true::Union{Vector{T}, SVector{N, T}},
    p_test::Union{Vector{T}, SVector{N, T}},
    numpoints::Int = 100;
    plot_title::String = "Time Series Comparison",
    figure_size = (800, 500)
) where {N, T <: Number}

    # Convert Vector to SVector if needed
    if p_true isa Vector
        p_true = SVector{length(p_true), T}(p_true)
    end
    if p_test isa Vector
        p_test = SVector{length(p_test), T}(p_test)
    end

    # Generate data for both parameter sets
    problem = ODEProblem(
        ModelingToolkit.complete(model),
        merge(
            Dict(ModelingToolkit.unknowns(model) .=> ic),
            Dict(ModelingToolkit.parameters(model) .=> p_true)
        ),
        time_interval,
    )
    data_true = sample_data(problem, model, outputs, time_interval, p_true, ic, numpoints)

    problem = ODEProblem(
        ModelingToolkit.complete(model),
        merge(
            Dict(ModelingToolkit.unknowns(model) .=> ic),
            Dict(ModelingToolkit.parameters(model) .=> p_test)
        ),
        time_interval,
    )
    data_test = sample_data(problem, model, outputs, time_interval, p_test, ic, numpoints)

    # Extract time points
    t = data_true["t"]

    # Create figure and axis
    fig = Figure(size = figure_size)
    ax = Axis(fig[1, 1], title = plot_title, xlabel = "Time", ylabel = "Value")

    # Define colors for true and test values
    colors = [:royalblue, :crimson]  # You can adjust these colors

    # Track minimum y value for error text placement
    y_min = Inf

    # Plot each output variable
    for (idx, (key, values_true)) in enumerate(data_true)
        if key != "t"  # Skip time array
            values_test = data_test[key]

            # Update minimum y value
            y_min = min(y_min, minimum(values_true), minimum(values_test))

            # Plot true values
            lines!(
                ax,
                t,
                values_true,
                label = "True - $(key)",
                color = colors[1],
                linewidth = 2
            )

            # Plot test values
            lines!(
                ax,
                t,
                values_test,
                label = "Test - $(key)",
                color = colors[2],
                linewidth = 2,
                linestyle = :dash
            )
        end
    end

    # Calculate and display error
    error = norm(data_true[first(keys(data_true))] - data_test[first(keys(data_test))], 1)
    error_text = "L¹ Error: $(round(error, digits=2))"

    # Add error text in the bottom right
    text!(
        ax,
        time_interval[2],
        y_min,
        text = error_text,
        align = (:right, :bottom),
        offset = (0, 10)
    )

    # Add legend
    axislegend(ax, position = :lt)  # top-left position

    return fig
end

# Helper function to quickly visualize a single parameter set against true parameters
"""
    plot_parameter_result(model::ModelingToolkit.ODESystem,
                         outputs::Vector{ModelingToolkit.Equation},
                         p_true::Union{Vector{T}, SVector{N,T}},
                         p_test::Union{Vector{T}, SVector{N,T}};
                         kwargs...) where {N,T<:Number}

Convenience function to quickly plot and display a parameter comparison using CairoMakie.

Takes the same arguments as plot_time_series_comparison plus additional plot options via kwargs.
"""
function plot_parameter_result(
    model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    ic,
    time_interval,
    p_true::Union{Vector{T}, SVector{N, T}},
    p_test::Union{Vector{T}, SVector{N, T}};
    kwargs...
) where {N, T <: Number}
    fig = plot_time_series_comparison(
        model,
        outputs,
        ic,
        time_interval,
        p_true,
        p_test;
        kwargs...
    )
    display(fig)
    return fig
end

end # module DynamicalSystems
