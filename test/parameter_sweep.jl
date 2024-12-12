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
function run_parameter_sweep(Error_distance, d::Int, model::ODESystem, outputs, sample_configs)
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
        @polyvar(x[1:TR.dim])  # Use TR.dim instead of n
        real_pts_lege = solve_polynomial_system(x, TR.dim, Pol.degree, Pol.coeffs; basis=:legendre, bigint=true)
        rl = process_real_solutions(real_pts_lege, TR, center, Error_distance, sample_range, N_samples)

        for row in eachrow(rl)
            push!(all_results, Dict(pairs(row)))
        end
    end

    return DataFrame(all_results)
end