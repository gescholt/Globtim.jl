"""
    run_parameter_sweep(Error_distance, model::ODESystem, outputs, sample_configs)
Run parameter sweeps across different configurations, comparing critical points at a fixed degree.
# Arguments
- `Error_distance`: Error distance function
- `model::ODESystem`: ODE system model
- `outputs`: Model outputs
- `sample_configs`: Vector of tuples (sample_range, N_samples, center) with different configurations
# Returns
- `DataFrame`: Results of parameter sweeps across all configurations
"""
function run_parameter_sweep(Error_distance, d::Int, model::ODESystem, outputs, sample_configs; method::String="homotopy")
    all_results = DataFrame()  # Start with empty DataFrame
    for (sample_range, N_samples, center) in sample_configs
        error_fn = let model = model, outputs = outputs
            function (p; kwargs...)
                Error_distance(p .+ center, measured_data=outputs)
            end
        end
        TR = test_input(error_fn,
            dim=3,
            tolerance=1.e-3,
            center=center,
            sample_range=sample_range,
            reduce_samples=1.0,
            model=model,
            outputs=outputs,
            GN=N_samples)
        Pol = Constructor(TR, d, basis=:legendre)
        @polyvar(x[1:TR.dim])
        println("Size of the grid: ", size(Pol.grid))
        if method == "msolve"
            println("Starting msolve computation...")
            process = msolve_polynomial_system(Pol, x, n=TR.dim, basis=:legendre)
            start_time = time()
            while !process_exited(process)
                elapsed = round(time() - start_time, digits=1)
                println("MSolve still running... ($(elapsed)s elapsed)")
                sleep(5)
            end
            println("MSolve computation completed in $(round(time() - start_time, digits=1))s")
            println("Parsing results...")
            # Get results for this configuration
            results_df = msolve_parser("outputs.ms", error_fn, TR)
            # Add center as a single column containing the array
            results_df[!, :center] .= Ref(center)  # Using Ref to store the array in each row
            # Append to main results
            if isempty(all_results)
                all_results = results_df
            else
                append!(all_results, results_df)
            end
        elseif method == "homotopy"
            # ... homotopy code ...
        else
            error("Invalid method: $method. Must be either 'homotopy' or 'msolve'")
        end
    end
    return all_results, Pol.grid
end


"""
Generate the coordinates for one dimension. For N divisions, we want N points equally spaced. The centers will be at -1 + (1/N) + 2(i-1)/N for i in 1:N.
"""
function hypercube_centers(n::Int, N::Int)
    single_dim = [-1 + 1 / N + 2 * (i - 1) / N for i in 1:N]
    centers = collect(Iterators.product(fill(single_dim, n)...))
    return reduce(hcat, [collect(x) for x in centers])'
end
"""
Given a set of initial conditions, sample the given model for time series data.
"""
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
"""
Construct the error function for a given model with a prescribed initial condition. Evaluate the distance along the L1 norm of the time series difference between `observed` and `true` data.
"""
function make_error_distance(model, outputs, p_true::Vector{Float64})
    # Generate Y_true once during function creation
    data_sample_true = sample_data(model, outputs, [0.0, 1.0], p_true, ic, 5)
    Y_true = data_sample_true[first(keys(data_sample_true))]
    function Error_distance(p_test::Vector{Float64};
        measured_data=outputs,
        time_interval=[0.0, 1.0],
        datasize=5)
        try
            if datasize != length(Y_true)
                return NaN
            end
            data_sample_test = sample_data(model, measured_data, time_interval, p_test, ic, datasize)
            # Check for empty or invalid data_sample
            if isempty(data_sample_test) || !haskey(data_sample_test, first(keys(data_sample_test)))
                return NaN
            end
            Y_test = data_sample_test[first(keys(data_sample_test))]
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
""""
We take the outputs of homotopy continuation or msolve and process them to filter out solutions that lie within the specified bounds. The solutions are then translated and scaled back using the provided transformation. Finally, we create a DataFrame containing the critical points, their distances from the true parameters, the evaluation distances using the error function, the sample range, and the number of samples. The DataFrame is sorted by the point distances before being returned.
"""
function process_real_solutions(real_pts, TR, p_true, Error_distance, sample_range, N_samples; bounds=(-1, 1))
    # First, handle the case where real_pts is nothing
    if real_pts === nothing
        println("Warning: No real points found (nothing returned)")
        return DataFrame(
            critical_point=Vector{Vector{Float64}}(),
            point_distance=Float64[],
            eval_distance=Float64[],
            sample_range=sample_range,
            N_samples=N_samples,
            center=Vector{typeof(TR.center)}()
        )
    end
    # Now we know real_pts is not nothing, we can safely check if it's empty
    if isempty(real_pts)
        println("Warning: No real points found (empty array)")
        return DataFrame(
            critical_point=Vector{Vector{Float64}}(),
            point_distance=Float64[],
            eval_distance=Float64[],
            sample_range=sample_range,
            N_samples=N_samples,
            center=Vector{typeof(TR.center)}()
        )
    end
    # Translate and scale back the solutions
    real_sol = [TR.sample_range * point .+ TR.center for point in real_pts]
    println("Un-Filtered Real Solutions: ", real_sol)
    # Filter solutions within bounds
    lower_bound, upper_bound = bounds
    filtered_real_solutions = [point for point in real_sol
                               if all(x -> lower_bound <= x <= upper_bound, point)]
    println("Filtered Real Solutions: ", filtered_real_solutions)
    # Create the DataFrame with solutions and metrics
    df = DataFrame(
        critical_point=filtered_real_solutions,
        point_distance=map(point -> norm(point .- p_true), filtered_real_solutions),
        eval_distance=map(point -> Error_distance(point), filtered_real_solutions),
        sample_range=sample_range,
        N_samples=N_samples,
        center=fill(TR.center, length(filtered_real_solutions))
    )
    sort!(df, :point_distance)
    return df
end