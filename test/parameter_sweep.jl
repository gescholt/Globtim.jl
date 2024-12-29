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