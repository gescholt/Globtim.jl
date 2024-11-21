using Revise
include("setup.jl")
include("model_parameters.jl")
include("lotka_volterra_model.jl")
include("parameter_sweep.jl")

@info "Lotka-Volterra Tests"

# First define the model and outputs
model, params, states, outputs = define_lotka_volterra_model()
Error_distance = make_error_distance(model, outputs)
Error_distance([0.1, 0.22, 0.3], measured_data=outputs)

# Then define Error_distance with captured model and outputs
results_1 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_1);
results_2 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_2);
results_3 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_3);
results_4 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_4);
results_5 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_5);

# To analyze all results:
for (i, res) in enumerate(results_1)
    println("\n=== Configuration $i ===")
    println("Grid points (GN): $(sample_configs[i][2])")  # Get GN from sample_configs
    println("Sample range: $(res.sample_range)")
    println("Number of samples: $(nrow(res.result.dataframe))")
    println("Reduce samples factor: $(res.reduce_samples)")
    df = res.result.dataframe
    println("\nSorted dataframe by eval_distance:")
    println(first(df, 5))  # Only print first 10 rows
    println("\n" * "="^50)  # Separator line
end