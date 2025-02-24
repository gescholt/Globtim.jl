function define_lotka_volterra_model()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b c
    D = Differential(t)
    params = [a, b, c]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + b * x1 * x2,
            D(x2) ~ b * x1 * x2 + c * x2],
        t, states, params)
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end

function sample_data(model::ModelingToolkit.ODESystem,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval::Vector{T},
    p_true::Vector{T},
    u0::Vector{T},
    num_points::Int;
    kwargs...) where {T<:Number}

    N = length(p_true)
    return sample_data(model, measured_data, time_interval, SVector{N,T}(p_true), u0, num_points; kwargs...)
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
function sample_data(model::ModelingToolkit.ODESystem,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval::Vector{T},
    p_true::SVector{N,T}, 
    u0::Vector{T},
    num_points::Int;
    uneven_sampling=false,
    uneven_sampling_times=Vector{T}(),
    solver=Vern9(),
    inject_noise=false,
    mean_noise=zero(T),
    stddev_noise=one(T),
    abstol=convert(T, 1e-14),
    reltol=convert(T, 1e-14)) where {N,T<:Number}

    @assert length(time_interval) == 2 "Time interval must be [start_time, end_time]"
    @assert N == length(parameters(model)) "Parameter vector length mismatch"

    if uneven_sampling
        if length(uneven_sampling_times) == 0
            error("No uneven sampling times provided")
        end
        if length(uneven_sampling_times) != num_points
            error("Uneven sampling times must be of length num_points")
        end
        sampling_times = uneven_sampling_times
    else
        sampling_times = range(time_interval[1], time_interval[2], length=num_points)
    end

    problem = ODEProblem(ModelingToolkit.complete(model), u0, time_interval,
        Dict(ModelingToolkit.parameters(model) .=> p_true))

    solution_true = ModelingToolkit.solve(problem, solver,
        saveat=sampling_times;
        abstol, reltol)

    data_sample = DataStructures.OrderedDict{Any,Vector{T}}(Num(v.lhs) => solution_true[Num(v.rhs)] for v in measured_data)

    # println("data_sample: ", data_sample)

    if inject_noise
        for (key, sample) in data_sample
            data_sample[key] = sample + randn(num_points) .* stddev_noise .+ mean_noise
        end
    end

    data_sample["t"] = sampling_times
    return data_sample
end

"""
    make_error_distance(model::ModelingToolkit.ODESystem, 
                       outputs::Vector{ModelingToolkit.Equation},
                       p_true::SVector{N,Float64}) where {N<:Integer}

Construct an L¹-norm error function comparing model predictions against reference data.

Arguments:
- `model`: ModelingToolkit ODESystem
- `outputs`: Vector of measurement equations
- `p_true`: SVector of true parameter values

Returns:
    Function that computes L¹-norm error between predictions and reference data
"""
function make_error_distance(model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    p_true::Vector{Float64},
    numpoints::Int=5)
    N = length(p_true)
    return make_error_distance(model, outputs, SVector{N,Float64}(p_true), numpoints)
end


function make_error_distance(model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    p_true::SVector{N,T},
    numpoints::Int=5
) where {N}

    @assert N == length(parameters(model)) "Parameter vector length mismatch"

    # Generate reference solution once during function creation
    data_sample_true = sample_data(model, outputs, [0.0, 1.0], p_true, ic, numpoints)
    Y_true = data_sample_true[first(keys(data_sample_true))]

    function Error_distance(p_test::Union{SVector{N,T}, Vector{T}};
        measured_data=outputs,
        time_interval=[0.0, 1.0],
        datasize=numpoints)

        try
            if datasize != length(Y_true)
                println("case 1")
                return NaN
            end

            data_sample_test = sample_data(model, measured_data, time_interval, p_test, ic, datasize)

            if isempty(data_sample_test) || !haskey(data_sample_test, first(keys(data_sample_test)))
                println("case 2")
                return NaN
            end

            Y_test = data_sample_test[first(keys(data_sample_test))]

            if any(isnan.(Y_test)) || any(isinf.(Y_test)) || any(isnan.(Y_true)) || any(isinf.(Y_true))
                println("case 3")
                return NaN
            end

            return 100 * norm(Y_true - Y_test, 1)
        catch e
            println("case 4")
            return NaN
        end
    end

    return Error_distance
end

using CairoMakie
using StaticArrays
using ModelingToolkit

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
function plot_time_series_comparison(model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    p_true::Union{Vector{T},SVector{N,T}},
    p_test::Union{Vector{T},SVector{N,T}},
    numpoints::Int=100;
    time_interval::Vector{T}=[0.0, 1.0],
    plot_title::String="Time Series Comparison",
    figure_size=(800, 500)) where {N,T<:Number}

    # Convert Vector to SVector if needed
    if p_true isa Vector
        p_true = SVector{length(p_true),T}(p_true)
    end
    if p_test isa Vector
        p_test = SVector{length(p_test),T}(p_test)
    end

    # Generate data for both parameter sets
    data_true = sample_data(model, outputs, time_interval, p_true, ic, numpoints)
    data_test = sample_data(model, outputs, time_interval, p_test, ic, numpoints)

    # Extract time points
    t = data_true["t"]

    # Create figure and axis
    fig = Figure(size=figure_size)
    ax = Axis(fig[1, 1],
        title=plot_title,
        xlabel="Time",
        ylabel="Value")

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
            lines!(ax, t, values_true,
                label="True - $(key)",
                color=colors[1],
                linewidth=2)

            # Plot test values
            lines!(ax, t, values_test,
                label="Test - $(key)",
                color=colors[2],
                linewidth=2,
                linestyle=:dash)
        end
    end

    # Calculate and display error
    error = norm(data_true[first(keys(data_true))] - data_test[first(keys(data_test))], 1)
    error_text = "L¹ Error: $(round(error, digits=2))"

    # Add error text in the bottom right
    text!(ax, time_interval[2], y_min,
        text=error_text,
        align=(:right, :bottom),
        offset=(0, 10))

    # Add legend
    axislegend(ax, position=:lt)  # top-left position

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
function plot_parameter_result(model::ModelingToolkit.ODESystem,
    outputs::Vector{ModelingToolkit.Equation},
    p_true::Union{Vector{T},SVector{N,T}},
    p_test::Union{Vector{T},SVector{N,T}};
    kwargs...) where {N,T<:Number}
    fig = plot_time_series_comparison(model, outputs, p_true, p_test; kwargs...)
    display(fig)
    return fig
end