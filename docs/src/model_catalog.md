# Model Catalog

Complete list of all 29 parameter estimation benchmark models supplied by
[DynamicObjectives.jl](https://github.com/gescholt/DynamicObjectives.jl). See
[ODE Parameter Estimation](ode_parameter_estimation.md) for installation and the
shape of these objectives.

## Summary Table

| # | Model Name | Function | Params | States | Outputs | Difficulty | Type | Notes |
|---|------------|----------|--------|--------|---------|------------|------|-------|
| 1 | LV 2D v1 | `define_lotka_volterra_2D_model()` | 2 | 2 | 1 | EASY | Predator-prey | c=1 |
| 2 | LV 2D v2 | `define_lotka_volterra_2D_model_v2()` | 2 | 2 | 1 | EASY | Predator-prey | c=0.1 |
| 3 | LV 2D v3 | `define_lotka_volterra_2D_model_v3()` | 2 | 2 | 1 | EASY | Predator-prey | c=0.5 |
| 4 | LV 2D v3 (2 out) | `define_lotka_volterra_2D_model_v3_two_outputs()` | 2 | 2 | 2 | EASY | Predator-prey | Full observability |
| 5 | LV 2D SciML | `define_lotka_volterra_2D_sciml_benchmark()` | 2 | 2 | 2 | EASY | Predator-prey | SciML benchmark formulation |
| 6 | LV 3D v1 | `define_lotka_volterra_3D_model()` | 3 | 2 | 1 | MEDIUM | Predator-prey | Globally identifiable |
| 7 | LV 3D locally id | `define_lotka_volterra_3D_model_locally_identifiable()` | 3 | 2 | 1 | MEDIUM | Identifiability | a², b² params, multiple minimizers |
| 8 | LV 3D v2 | `define_lotka_volterra_3D_model_v2()` | 3 | 2 | 1 | MEDIUM | Predator-prey | Standard form |
| 9 | DAISY Ex3 (input) | `define_daisy_ex3_model_4D()` | 4 | 4 | 2 | MEDIUM | Linear | Time-dependent input |
| 10 | DAISY Ex3 (no input) | `define_daisy_ex3_model_4D_no_input()` | 4 | 3 | 2 | MEDIUM | Linear | Benchmark |
| 11 | LV 4D Constrained | `define_constrained_lotka_volterra_4D()` | 4 | 4 | 4 | MEDIUM-HARD | Competition | Skew-symmetric |
| 12 | LV 4D Simple | `define_lotka_volterra_4D_simple()` | 4 | 2 | 1 | MEDIUM | Predator-prey | NOT identifiable (negative result) |
| 13 | Goodwin 4D | `define_goodwin_oscillator_4D()` | 4 | 3 | 2 | HARD | Oscillator | Hill function feedback loop |
| 14 | FitzHugh-Nagumo | `define_fitzhugh_nagumo_3D_model()` | 3 | 2 | 1 | HARD | Neuronal | Oscillatory, may need timeout |
| 15 | Simple 1D (a²) | `define_simple_1D_model_locally_identifiable()` | 1 | 1 | 1 | MEDIUM-HARD | Identifiability test | Locally identifiable |
| 16 | Simple 2D (a*b) | `define_simple_2D_model_locally_identifiable()` | 2 | 1 | 1 | HARD | Identifiability test | Locally identifiable |
| 17 | Simple 2D (b²) | `define_simple_2D_model_locally_identifiable_square()` | 2 | 1 | 1 | HARD | Identifiability test | Locally identifiable |
| 18 | LV 4D Generalized | `define_generalized_lotka_volterra_4D()` | 20 | 4 | 4 | VERY HARD | Competition | Full interaction matrix |
| 19 | FHN (2 out) | `define_fitzhugh_nagumo_3D_model_two_outputs()` | 3 | 2 | 2 | MEDIUM | Neuronal | Full observability (V, R) |
| 20 | Lorenz | `define_lorenz_3D_model()` | 3 | 3 | 2 | HARD | Chaotic | Sensitive to IC, chaotic regime |
| 21 | Rossler | `define_rossler_3D_model()` | 3 | 3 | 2 | HARD | Chaotic | Period-doubling, spiral chaos |
| 22 | Goodwin 3D | `define_goodwin_oscillator_3D()` | 3 | 3 | 2 | MEDIUM | Oscillator | Reduced Goodwin (k5 fixed) |
| 23 | Goodwin 3D (product obs) | `define_goodwin_3d_product_obs_model()` | 3 | 3 | 1 | HARD | Oscillator | y1 = x1*x3, curved level sets |
| 24 | Rosenzweig-MacArthur | `define_rosenzweig_macarthur_3d_model()` | 3 | 2 | 1 | MEDIUM | Predator-prey | Holling type II response |
| 25 | Goodwin 3D locally id | `define_goodwin_3d_locally_id_model()` | 3 | 3 | 2 | HARD | Identifiability | k1², k4² — 4 equivalent minima |
| 26 | FHN 3D locally id | `define_fhn_3d_locally_id_model()` | 3 | 2 | 2 | HARD | Identifiability | g² — 2 equivalent minima |
| 27 | LV2D reparam 3D | `define_lv2d_reparam_3d_model()` | 3 | 2 | 1 | MEDIUM | Predator-prey | Nonlinear reparameterization |
| 28 | Coupled LV2D 3D | `define_coupled_lv2d_3d_model()` | 3 | 4 | 2 | MEDIUM-HARD | Predator-prey | Shared param + diffusive coupling |
| 29 | LV 3D symmetric | `define_lv_3d_symmetric_model()` | 3 | 2 | 1 | HARD | Identifiability | (a,b) permutation — 2 minima |

## Grouped by Difficulty

### EASY (5 models)

Good for initial validation of optimizer setup:
- `define_lotka_volterra_2D_model()`
- `define_lotka_volterra_2D_model_v2()`
- `define_lotka_volterra_2D_model_v3()`
- `define_lotka_volterra_2D_model_v3_two_outputs()`
- `define_lotka_volterra_2D_sciml_benchmark()`

### MEDIUM (10 models)

Standard benchmarks for parameter estimation:
- `define_lotka_volterra_3D_model()`
- `define_lotka_volterra_3D_model_locally_identifiable()`
- `define_lotka_volterra_3D_model_v2()`
- `define_lotka_volterra_4D_simple()`
- `define_daisy_ex3_model_4D()`
- `define_daisy_ex3_model_4D_no_input()`
- `define_fitzhugh_nagumo_3D_model_two_outputs()`
- `define_goodwin_oscillator_3D()`
- `define_rosenzweig_macarthur_3d_model()`
- `define_lv2d_reparam_3d_model()`

### MEDIUM-HARD (3 models)

Challenging problems with structure:
- `define_constrained_lotka_volterra_4D()`
- `define_simple_1D_model_locally_identifiable()`
- `define_coupled_lv2d_3d_model()`

### HARD (10 models)

Advanced problems requiring robust optimization:
- `define_fitzhugh_nagumo_3D_model()` (oscillatory dynamics)
- `define_goodwin_oscillator_4D()` (Hill function feedback loop)
- `define_simple_2D_model_locally_identifiable()` (non-identifiable)
- `define_simple_2D_model_locally_identifiable_square()` (non-identifiable)
- `define_lorenz_3D_model()` (chaotic, sensitive to IC)
- `define_rossler_3D_model()` (period-doubling, spiral chaos)
- `define_goodwin_3d_product_obs_model()` (product observation)
- `define_goodwin_3d_locally_id_model()` (4 equivalent minima)
- `define_fhn_3d_locally_id_model()` (2 equivalent minima)
- `define_lv_3d_symmetric_model()` (permutation symmetry, 2 minima)

### VERY HARD (1 model)

Ultimate stress test:
- `define_generalized_lotka_volterra_4D()` (20 dimensions!)

## Grouped by Parameter Count

### 1 Parameter
- `define_simple_1D_model_locally_identifiable()`

### 2 Parameters
- `define_lotka_volterra_2D_model()`
- `define_lotka_volterra_2D_model_v2()`
- `define_lotka_volterra_2D_model_v3()`
- `define_lotka_volterra_2D_model_v3_two_outputs()`
- `define_lotka_volterra_2D_sciml_benchmark()`
- `define_simple_2D_model_locally_identifiable()`
- `define_simple_2D_model_locally_identifiable_square()`

### 3 Parameters
- `define_lotka_volterra_3D_model()`
- `define_lotka_volterra_3D_model_locally_identifiable()`
- `define_lotka_volterra_3D_model_v2()`
- `define_fitzhugh_nagumo_3D_model()`
- `define_fitzhugh_nagumo_3D_model_two_outputs()`
- `define_lorenz_3D_model()`
- `define_rossler_3D_model()`
- `define_goodwin_oscillator_3D()`
- `define_goodwin_3d_product_obs_model()`
- `define_rosenzweig_macarthur_3d_model()`
- `define_goodwin_3d_locally_id_model()`
- `define_fhn_3d_locally_id_model()`
- `define_lv2d_reparam_3d_model()`
- `define_coupled_lv2d_3d_model()`
- `define_lv_3d_symmetric_model()`

### 4 Parameters
- `define_daisy_ex3_model_4D()`
- `define_daisy_ex3_model_4D_no_input()`
- `define_constrained_lotka_volterra_4D()`
- `define_lotka_volterra_4D_simple()`
- `define_goodwin_oscillator_4D()`

### 20 Parameters
- `define_generalized_lotka_volterra_4D()`

## Grouped by System Type

### Predator-Prey Dynamics (9 models)

Lotka-Volterra models with oscillatory or equilibrium behavior:
- All LV 2D models (5 total)
- All LV 3D models (3 total: v1, locally id, v2)
- `define_rosenzweig_macarthur_3d_model()` (Holling type II)

### Competition Models (2 models)

Multi-species competition with interaction matrices:
- `define_generalized_lotka_volterra_4D()` (full 4x4 interaction)
- `define_constrained_lotka_volterra_4D()` (perturbed structure)

### Linear Benchmark (2 models)

DAISY suite linear systems:
- `define_daisy_ex3_model_4D()`
- `define_daisy_ex3_model_4D_no_input()`

### Neuronal Models (3 models)

Excitable FitzHugh-Nagumo systems:
- `define_fitzhugh_nagumo_3D_model()` (1 output)
- `define_fitzhugh_nagumo_3D_model_two_outputs()` (2 outputs)
- `define_fhn_3d_locally_id_model()` (g² parameterization)

### Oscillator Models (4 models)

Goodwin oscillator variants:
- `define_goodwin_oscillator_4D()` (4 params)
- `define_goodwin_oscillator_3D()` (3 params, k5 fixed)
- `define_goodwin_3d_product_obs_model()` (product observation)
- `define_goodwin_3d_locally_id_model()` (squared params)

### Chaotic Systems (2 models)

Systems with sensitive dependence on initial conditions:
- `define_lorenz_3D_model()` (Lorenz attractor)
- `define_rossler_3D_model()` (Rossler attractor)

### Reparameterized / Coupled Models (3 models)

Constructed 3D landscapes from LV2D building blocks:
- `define_lv2d_reparam_3d_model()` (nonlinear reparam)
- `define_coupled_lv2d_3d_model()` (diffusive coupling)
- `define_lv_3d_symmetric_model()` (symmetric polynomials)

### Identifiability Tests (6 models)

Systems with multiple equivalent parameter sets:
- `define_simple_1D_model_locally_identifiable()` — ±a gives same output
- `define_simple_2D_model_locally_identifiable()` — only a*b and a+b observable
- `define_simple_2D_model_locally_identifiable_square()` — ±b gives same output
- `define_goodwin_3d_locally_id_model()` — (±k1, k2, ±k4), 4 minima
- `define_fhn_3d_locally_id_model()` — (±g, a, b), 2 minima
- `define_lv_3d_symmetric_model()` — (a,b,c) ↔ (b,a,c), 2 minima

## Special Characteristics

### Requires Timeout

Models that may need `eval_timeout` parameter:
- `define_generalized_lotka_volterra_4D()` (high-dimensional, stiff)
- `define_fitzhugh_nagumo_3D_model()` (oscillatory, limit cycles)
- `define_lorenz_3D_model()` (chaotic, may diverge)
- `define_rossler_3D_model()` (chaotic, period-doubling)

### Partial Observability

Models where not all states are measured (harder estimation):
- All LV 2D v1/v2/v3 single-output variants
- All LV 3D models
- FitzHugh-Nagumo (1 output variant)
- Simple 1D/2D identifiability models
- `define_goodwin_3d_product_obs_model()` (1 product output)
- `define_rosenzweig_macarthur_3d_model()` (1 output)
- `define_lv2d_reparam_3d_model()` (1 output)
- `define_lv_3d_symmetric_model()` (1 output)

### Full Observability

All states are measured:
- `define_lotka_volterra_2D_model_v3_two_outputs()`
- `define_lotka_volterra_2D_sciml_benchmark()`
- `define_generalized_lotka_volterra_4D()`
- `define_constrained_lotka_volterra_4D()`
- Both DAISY models
- `define_fitzhugh_nagumo_3D_model_two_outputs()`
- `define_fhn_3d_locally_id_model()`
- `define_goodwin_oscillator_3D()` (2 of 3 states)
- `define_goodwin_3d_locally_id_model()` (2 of 3 states)

### Non-Identifiable / Locally Identifiable

Multiple parameter sets produce identical outputs (test optimizer behavior):
- `define_simple_1D_model_locally_identifiable()` — ±a gives same output
- `define_simple_2D_model_locally_identifiable()` — (a,b) and (a',b') same if a*b and a+b match
- `define_simple_2D_model_locally_identifiable_square()` — ±b gives same output
- `define_goodwin_3d_locally_id_model()` — (±k1, k2, ±k4), 4 discrete minima
- `define_fhn_3d_locally_id_model()` — (±g, a, b), 2 discrete minima
- `define_lv_3d_symmetric_model()` — (a,b) ↔ (b,a) permutation, 2 discrete minima

## Recommended Testing Sequence

### Sequence 1: Progressive Difficulty

1. `define_lotka_volterra_2D_model_v3_two_outputs()` (2P, EASY, full obs)
2. `define_lotka_volterra_3D_model_v2()` (3P, MEDIUM)
3. `define_constrained_lotka_volterra_4D()` (4P, MEDIUM-HARD)
4. `define_fitzhugh_nagumo_3D_model()` (3P, HARD, oscillatory)
5. `define_generalized_lotka_volterra_4D()` (20P, VERY HARD)

### Sequence 2: Observability Study

1. `define_lotka_volterra_2D_model_v3()` (1 output, partial)
2. `define_lotka_volterra_2D_model_v3_two_outputs()` (2 outputs, full)

Compare convergence speed and accuracy.

### Sequence 3: Identifiability Study

1. `define_simple_1D_model_locally_identifiable()` (1P, ±a symmetry)
2. `define_simple_2D_model_locally_identifiable_square()` (2P, ±b symmetry)
3. `define_lv_3d_symmetric_model()` (3P, permutation symmetry)
4. `define_goodwin_3d_locally_id_model()` (3P, 4 discrete minima)
5. `define_fhn_3d_locally_id_model()` (3P, 2 discrete minima)

Check if optimizer finds correct invariants and all equivalent minima.

### Sequence 4: Scalability Study

1. `define_lotka_volterra_2D_model()` (2P)
2. `define_lotka_volterra_3D_model()` (3P)
3. `define_daisy_ex3_model_4D_no_input()` (4P)
4. `define_generalized_lotka_volterra_4D()` (20P)

Track how performance degrades with dimension.

### Sequence 5: Chaotic / Nonlinear Systems

1. `define_goodwin_oscillator_3D()` (3P, Hill function)
2. `define_lorenz_3D_model()` (3P, chaotic attractor)
3. `define_rossler_3D_model()` (3P, period-doubling)

Test robustness against sensitive dynamics.

## Quick Reference: Function Signatures

All model definition functions return:

```julia
(model, parameters, states, measured_quantities)
```

Where:
- `model`: ModelingToolkit ODESystem
- `parameters`: Vector of symbolic parameters
- `states`: Vector of symbolic state variables
- `measured_quantities`: Vector of measurement equations

## Usage Example

```julia
using DynamicObjectives

# Select a model (e.g., #4 from table)
model, params, states, outputs = define_lotka_volterra_2D_model_v3_two_outputs()

# Set up problem
p_true = [1.0, 0.5]
ic = [1.0, 0.5]
bounds = [(0.0, 3.0), (0.0, 2.0)]
time_interval = [0.0, 20.0]
numpoints = 30

# Create objective
error_func = make_error_distance(
    model, outputs, ic, p_true, time_interval, numpoints,
    L2_norm, first, nothing;
    return_inf_on_error = true,
    eval_timeout = nothing  # Not needed for easy problems
)

# Verify setup
@assert error_func(p_true) < 1e-6

# Run optimizer on error_func with bounds
```

## See Also

- [ODE Parameter Estimation](ode_parameter_estimation.md) — overview, installation, distance metrics
- [Glued Objectives](glued_objectives.md) — building higher-dimensional problems with known critical-point sets out of these models
- [Getting Started](getting_started.md) — feeding one of these objectives through the Globtim workflow
