function sample_data(model::ModelingToolkit.ODESystem,
    measured_data::Vector{ModelingToolkit.Equation},
    time_interval::Vector{T},
    p_true::Vector{T},
    u0::Vector{T},
    num_points::Int;
    uneven_sampling=false,
    uneven_sampling_times=Vector{T}(),
    solver=Vern9(), inject_noise=false, mean_noise=0,
    stddev_noise=1, abstol=1e-14, reltol=1e-14) where {T<:Number}
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
    problem = ODEProblem(ModelingToolkit.complete(model), u0, time_interval, Dict(ModelingToolkit.parameters(model) .=> p_true))
    solution_true = ModelingToolkit.solve(problem, solver,
        saveat=sampling_times;
        abstol, reltol)
    data_sample = DataStructures.OrderedDict{Any,Vector{T}}(Num(v.lhs) => solution_true[Num(v.rhs)]
                                             for v in measured_data)
    if inject_noise
        for (key, sample) in data_sample
            data_sample[key] = sample + randn(num_points) .* stddev_noise .+ mean_noise
        end
    end
    data_sample["t"] = sampling_times
    return data_sample
end

""" We should be careful that the Y_true is hard coded in the function. """
function make_error_distance(model, outputs)
    function Error_distance(p_test::Vector{Float64};
        Y_true=[0.11, 0.11376181935472697, 0.11774652882518055, 0.12197777166050001, 0.1264826249688384],
        measured_data=outputs,
        time_interval=[0.0, 1.0],
        datasize=5)

        try
            if datasize != length(Y_true)
                return NaN
            end

            data_sample = sample_data(model, measured_data, time_interval, p_test, ic, datasize)

            # Check for empty or invalid data_sample
            if isempty(data_sample) || !haskey(data_sample, first(keys(data_sample)))
                return NaN
            end

            Y_test = data_sample[first(keys(data_sample))]

            # Check for NaN or Inf in either vector
            if any(isnan.(Y_test)) || any(isinf.(Y_test)) || any(isnan.(Y_true)) || any(isinf.(Y_true))
                return NaN
            end

            return 100 * norm(Y_true - Y_test, 1)
        catch e
            return NaN
        end
    end
end

function process_real_solutions(real_pts, TR, p_true, Error_distance, sample_range, N_samples; bounds=(-1, 1))
    # Translate and scale back the solutions
    real_sol = [TR.sample_range * point .+ TR.center for point in real_pts]

    # Filter solutions within bounds
    lower_bound, upper_bound = bounds
    filtered_real_solutions = [point for point in real_sol
                               if all(x -> lower_bound <= x <= upper_bound, point)]

    # Create the DataFrame with solutions and metrics
    df = DataFrame(
        critical_point=filtered_real_solutions,
        point_distance=map(point -> norm(point .- p_true), filtered_real_solutions),
        eval_distance=map(point -> Error_distance(point), filtered_real_solutions), 
        sample_range=sample_range,
        N_samples=N_samples
    )
    sort!(df, :point_distance)
    return df
end