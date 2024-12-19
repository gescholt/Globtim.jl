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
    all_results = []

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

        Pol = Constructor(TR, d, GN=N_samples, basis=:legendre)
        @polyvar(x[1:TR.dim])

        # Choose solving method and handle process output
        real_pts_lege = if method == "msolve"
            println("Starting msolve computation...")
            process = msolve_polynomial_system(Pol, x, n=TR.dim, basis=:legendre)

            # Print status while waiting
            start_time = time()
            while !process_exited(process)
                elapsed = round(time() - start_time, digits=1)
                println("MSolve still running... ($(elapsed)s elapsed)")
                sleep(5)  # Check every 5 seconds
            end

            println("MSolve computation completed in $(round(time() - start_time, digits=1))s")
            println("Parsing results...")

            msolve_parser("outputs.ms", error_fn, sample_range, TR.dim)
        elseif method == "homotopy"
            result = solve_polynomial_system(x, TR.dim, Pol.degree, Pol.coeffs; basis=:legendre, bigint=true)
            # result isa Base.Process ? wait(result) : result
        else
            error("Invalid method: $method. Must be either 'homotopy' or 'msolve'")
        end

        rl = process_real_solutions(real_pts_lege, TR, center, Error_distance, sample_range, N_samples)

        for row in eachrow(rl)
            push!(all_results, Dict(pairs(row)))
        end
    end

    return DataFrame(all_results)
end
