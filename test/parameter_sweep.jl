function run_parameter_sweep(Error_distance, model::ODESystem, outputs, sample_configs)
    # Create a wrapper function that properly handles keyword arguments
    error_fn = let model = model, outputs = outputs
        function (p; kwargs...)
            Error_distance(p, measured_data=outputs)
        end
    end

    results = []
    for (sample_range, N_samples) in sample_configs
        TR = create_test_input(error_fn,
            n=3,
            tolerance=1.e-3,
            center=P_TRUE + [0.05, 0.0, 0.0],
            sample_range=sample_range,
            reduce_samples=1.0,
            model=model,
            outputs=outputs)

        Pol = Constructor(TR, 2, GN=N_samples, basis=:legendre)
        res = compute_critical_points(TR, Pol, P_TRUE, error_fn)
        sort!(res.dataframe, :eval_distance)
        sort!(res.dataframe, :point_distance)
        push!(results, (reduce_samples=1.0,
            sample_range=sample_range,
            result=res))
    end
    return results
end