# IMPORTANT: Experiment Naming - RESOLVED

## Previous Issue (RESOLVED)

**This experiment directory was previously MISNAMED.**

Previously called `lotka_volterra_4d_study`, this experiment **does NOT use a Lotka-Volterra model**. The directory has been renamed to `daisy_ex3_4d_study` to accurately reflect the model being used.

## Actual Model Used

The experiments in this directory use the **DAISY Example 3 model** (`define_daisy_ex3_model_4D`), which is defined in the `Dynamic_objectives` package.

### DAISY Example 3 Model Equations

```julia
D(x1) ~ -1 * p1 * x1 + x2 + u0
D(x2) ~ p3 * x1 - p4 * x2 + x3
D(x3) ~ p6 * x1 + 0.2 * x3
D(u0) ~ 1
```

### Model Details

- **Parameters**: p1, p3, p4, p6 (4 parameters)
- **States**: x1, x2, x3, u0 (4 states)
- **Outputs**: y1 ~ x1 + x3, y2 ~ x2
- **True parameter values**: [0.2, 0.3, 0.5, 0.6]
- **Initial conditions**: [1.0, 2.0, 1.0, 1.0]
- **Time interval**: [0, 10]

## Why This Matters

1. **Model selection for trajectory generation**: When generating trajectories from the critical points found in this study, you MUST use `define_daisy_ex3_model_4D`, not a Lotka-Volterra model.

2. **Result interpretation**: The parameter recovery results and critical point analysis are for the DAISY model, not Lotka-Volterra dynamics.

3. **Future experiments**: If you actually want to run a 4D Lotka-Volterra study, you need to:
   - Use existing Lotka-Volterra models from the `Dynamic_objectives` package (e.g., `define_generalized_lotka_volterra_4D` or `define_constrained_lotka_volterra_4D`)
   - Create a new experiment configuration
   - Run the optimization on the cluster with the correct model

## Verification

You can verify the model used by checking the `experiment_config.json` file in any of the experiment result directories:

```bash
cat configs_*/hpc_results/*/experiment_config.json | jq '.model_func'
# Output: "define_daisy_ex3_model_4D"
```

## Best Critical Point Found (as of 2025-10-08)

From experiment 4 (range 1.6), degree 11:

- **Parameters**: [0.0777315, 0.386455, 0.445455, 0.620606]
- **Parameter distance from true**: 0.1607
- **Objective value**: 23323.2

This represents the closest critical point to the true parameters [0.2, 0.3, 0.5, 0.6] found across all polynomial degrees (4-12).

## Resolution

This directory has been renamed to `daisy_ex3_4d_study` to accurately reflect that it uses the DAISY Example 3 model.

---

**Original Issue Date**: October 8, 2025
**Discovered during**: Trajectory analysis implementation
**Resolved**: October 11, 2025 (Issue #141)
