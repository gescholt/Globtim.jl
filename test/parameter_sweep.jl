""" 
We consider different configurations on the number of samples and the sample range.
We then compare the critical points we can compute, in this case at a fixed degree. 
"""

function run_parameter_sweep(Error_distance, model::ODESystem, outputs, sample_configs)
    # Create a wrapper function that properly handles keyword arguments
    error_fn = let model = model, outputs = outputs
        function (p; kwargs...)
            Error_distance(p, measured_data=outputs)
        end
    end

    all_results = []
    for (sample_range, N_samples) in sample_configs
        TR = create_test_input(error_fn,
            n=3,
            tolerance=1.e-3,
            center=P_TRUE + [0.05, 0.1, 0.15],
            sample_range=sample_range,
            reduce_samples=1.0,
            model=model,
            outputs=outputs)

        Pol = Constructor(TR, 3, GN=N_samples, basis=:legendre)
        @polyvar(x[1:n]) # Define polynomial ring with n variables
        real_pts_lege, sys = solve_polynomial_system(x, n, Pol.degree, Pol.coeffs; basis=:legendre, bigint=true)
        rl = process_real_solutions(real_pts_lege, TR, P_TRUE, Error_distance, sample_range, N_samples)
        for row in eachrow(rl)
            push!(all_results, Dict(pairs(row)))
        end 
    end
    return DataFrame(all_results)
end