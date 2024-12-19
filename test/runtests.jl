include("setup.jl")
@info "Lotka-Volterra Tests"

"""
We need to work in high precision to avoid numerical errors --> bigint = true
[]: Need to add the msolve polynomial solver, may be quicker than Homotopy solver
[]: Need to parallelize this.
[]: Return the center of the cel in which the critical point was computed. 
"""

# First define the model and outputs
model, params, states, outputs = define_lotka_volterra_model()
Err_dist = make_error_distance(model, outputs, P_TRUE)
# Error_distance([0.1, 0.22, 0.3], measured_data=outputs)

# Then define Error_distance with captured model and outputs
results_1 = run_parameter_sweep(Err_dist, 4, model, outputs, sample_configs_1, method="msolve");
# results_2 = run_parameter_sweep(Err_dist, 4, model, outputs, sample_configs_2, method="msolve");
# results_2 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_2);
# results_3 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_3);
# results_4 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_4);
# results_5 = run_parameter_sweep(Error_distance, model, outputs, sample_configs_5);

println(results_1)

# To analyze all results:
# for (i, res) in enumerate(results_3)
#     println("\n=== Configuration $i ===")
#     println("Grid points (GN): $(sample_configs[i][2])")  # Get GN from sample_configs
#     println("Sample range: $(res.sample_range)")
#     println("Degree of approximant: $(res.degree)")
#     println("Number of critical points of approximant: $(nrow(res.result.dataframe))")
#     df = res.result.dataframe
#     println("\nSorted dataframe by eval_distance:")
#     println(first(df, 5))  # Only print first 10 rows
#     println("\n" * "="^50)  # Separator line
# end