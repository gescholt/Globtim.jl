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

function make_error_distance(model, outputs)
    function Error_distance(p_test::Vector{Float64};
        Y_true=[0.11, 0.11376181935472697, 0.11774652882518055, 0.12197777166050001, 0.1264826249688384],
        measured_data=outputs,  # Default to captured outputs
        time_interval=[0.0, 1.0],
        datasize=5)

        if datasize != length(Y_true)
            error("The length of the test parameters must be equal to the length of the true parameters")
        end
        data_sample = sample_data(model, measured_data, time_interval, p_test, ic, datasize)
        Y_test = data_sample[first(keys(data_sample))]
        return 100 * norm(Y_true - Y_test, 1)
    end
    return Error_distance
end

function process_real_solutions(real_pts, TR, p_true, Error_distance; bounds=(-1, 1))
    # Translate and scale back the solutions
    real_sol = [TR.sample_range * point .+ TR.center for point in real_pts]

    # Filter solutions within bounds
    lower_bound, upper_bound = bounds
    filtered_real_solutions = [point for point in real_sol
                               if all(x -> lower_bound <= x <= upper_bound, point)]

    # Create the DataFrame with solutions and metrics
    df = DataFrame(
        critical_point=real_sol,
        point_distance=map(point -> norm(point .- p_true), real_sol),
        eval_distance=map(point -> Error_distance(point), real_sol)
    )
    sort!(df, :point_distance)

    # Create the matrix of coordinates if there are valid solutions
    coords = if length(filtered_real_solutions) > 0
        real_solutions_matrix = hcat(filtered_real_solutions...)
        (
            x=real_solutions_matrix[1, :],
            y=real_solutions_matrix[2, :],
            z=real_solutions_matrix[3, :]
        )
    else
        (x=Float64[], y=Float64[], z=Float64[])
    end

    return (
        dataframe=df,
        filtered_solutions=filtered_real_solutions,
        coordinates=coords
    )
end


function compute_critical_points(TR, Pol, p_true, Error_distance)
    # Define polynomial variables
    @polyvar(x[1:TR.dim])

    # Generate polynomial and its gradient
    pol = main_nd(x, TR.dim, Pol.degree, Pol.coeffs)
    grad = differentiate.(pol, x)

    # Solve the system
    sys = HomotopyContinuation.System(grad)
    Real_sol_lstsq = HomotopyContinuation.solve(sys)

    # Get real points
    real_pts = real_solutions(Real_sol_lstsq;
        only_real=true,
        multiple_results=false)

    # Process solutions and get DataFrame
    results = process_real_solutions(real_pts, TR, p_true, Error_distance)
    df = results.dataframe

    # Sort by both metrics
    sort!(df, [:point_distance, :eval_distance])

    return (
        dataframe=df,
        filtered_solutions=results.filtered_solutions,
        coordinates=results.coordinates,
        polynomial=pol,
        gradient=grad
    )
end

export sample_data, Error_distance, compute_critical_points