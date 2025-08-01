# Valley Walking Module Documentation

This directory contains a modularized implementation of valley walking algorithms for polynomial approximation of objective functions.

## Module Structure

### Core Modules

1. **`valley_walking_utils.jl`**
   - Core valley walking algorithm implementation
   - `enhanced_valley_walk()`: Main function combining valley walking and gradient descent
   - Helper functions for valley steps, gradient steps, and projection
   - Result analysis utilities

2. **`polynomial_degree_optimization.jl`**
   - Functions for testing different polynomial degrees
   - `test_polynomial_degrees()`: Systematic testing with performance metrics
   - `select_best_configuration()`: Automatic selection based on multiple criteria
   - Domain expansion utilities

3. **`valley_walking_visualization.jl`**
   - GLMakie-based visualization functions
   - `plot_valley_paths_2d()`: Main visualization showing paths on level sets
   - Eigenvalue evolution plots
   - Step type distribution charts

4. **`valley_walking_tables.jl`**
   - Tabular display functions for analysis
   - Polynomial comparison tables
   - Convergence analysis tables
   - Critical points tables
   - Valley walking summary statistics

5. **`test_functions.jl`**
   - Collection of objective functions
   - Analytical test functions (Rosenbrock, Himmelblau, Beale)
   - Function information registry
   - Utility functions for evaluation

### Main Scripts

- **`walk_along_valley_refactored.jl`**: Main refactored script using the modular components
- **`walk_along_valley.jl`**: Original monolithic implementation (for reference)

## Usage Example

```julia
# Include necessary modules
include("test_functions.jl")
include("valley_walking_utils.jl")
include("polynomial_degree_optimization.jl")
include("valley_walking_tables.jl")
include("valley_walking_visualization.jl")

# Select objective function
func_info = get_test_function_info(:rosenbrock_2d)
objective_func = func_info.func

# Configure polynomial approximation
base_config = (
    n = 2,
    p_true = [[1.0, 1.0]],
    sample_range = 1.5,
    basis = :chebyshev,
    precision = Globtim.RationalPrecision,
    p_center = [1.0, 1.0]
)

# Test polynomial degrees
degree_configs = create_degree_test_configs(min_degree=4, max_degree=14)
test_results = test_polynomial_degrees(objective_func, base_config, degree_configs)

# Display results
display_polynomial_comparison_table(test_results)

# Select best configuration and perform valley walking
best_config, _ = select_best_configuration(test_results)
```

## Key Features

### Modular Design
- Each module focuses on a specific aspect of the algorithm
- Easy to extend with new objective functions or visualization types
- Clear separation of concerns

### Comprehensive Analysis
- Automatic polynomial degree optimization
- Convergence analysis to true minima
- Step type tracking (valley vs gradient)
- Performance timing

### Flexible Visualization
- 2D level set plots with paths
- Function value evolution
- Eigenvalue tracking
- Customizable plot parameters

### Tabular Output
- Results displayed in formatted tables
- Export to text files for documentation
- Summary statistics

## ODE-Based Objective Functions

For ODE-based parameter estimation problems (like Lotka-Volterra), the objective function should:

1. Take a parameter vector as input
2. Solve the ODE with those parameters
3. Compare the solution to reference data
4. Return an error metric (e.g., L2 distance)

Example structure:
```julia
function create_ode_error_function(true_params, initial_conditions, time_span)
    function error_func(params)
        # Solve ODE with given parameters
        # Compare to reference solution
        # Return error metric
    end
    return error_func
end
```

## Performance Considerations

- Use appropriate sample sizes for polynomial degree
- Monitor condition numbers to avoid ill-conditioning
- Adjust valley walking parameters based on function characteristics
- Consider domain expansion for better approximation

## Future Extensions

1. 3D visualization support
2. Parallel evaluation of multiple starting points
3. Adaptive step size selection
4. Integration with more ODE solvers
5. Support for constrained optimization