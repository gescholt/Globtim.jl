# Examples

This page provides complete working examples demonstrating various features of Globtim.jl.

## Example 1: Basic Usage

Finding all minima of the Deuflhard function:

```julia
using Globtim, DynamicPolynomials, DataFrames

# Define the problem
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Polynomial approximation
pol = Constructor(TR, 8)
println("Approximation error: ", pol.nrm)

# Find critical points
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Refine and classify
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Display results
println("\\nUnique minima found:")
for i in 1:nrow(df_min)
    x1, x2 = df_min[i, :x1], df_min[i, :x2]
    val = df_min[i, :value]
    println("  Minimum $i: ($x1, $x2) with f = $val")
end
```

## Example 2: Custom Function

Optimizing a user-defined function:

```julia
# Define custom objective
function my_function(x)
    return (x[1]^2 - 1)^2 + (x[2]^2 - 1)^2 + 0.1*sin(10*x[1]*x[2])
end

# Set up problem
TR = test_input(my_function, dim=2, center=[0.0, 0.0], sample_range=2.0)

# Higher degree for complex function
pol = Constructor(TR, 10)

# Standard workflow
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 10, pol.coeffs)
df = process_crit_pts(solutions, my_function, TR)
df_enhanced, df_min = analyze_critical_points(my_function, df, TR)

# Analyze critical point types
types = unique(df_enhanced.critical_point_type)
for t in types
    count = sum(df_enhanced.critical_point_type .== t)
    println("$t: $count points")
end
```

## Example 3: Statistical Analysis

Generating comprehensive reports:

```julia
# Run analysis with tables
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_types=[:minimum, :saddle, :maximum]
)

# Access statistics
println("\\nStatistical Summary:")
println("Average condition number: ", mean(df_enhanced.hessian_condition_number))
println("Max gradient norm: ", maximum(df_enhanced.gradient_norm))
println("Convergence rate: ", sum(df_enhanced.converged) / nrow(df_enhanced))

# Export results
write_tables_to_csv(tables, "deuflhard_results.csv")
write_tables_to_markdown(tables, "deuflhard_results.md")
```

## Example 4: High-Dimensional Problem

Handling higher dimensions:

```julia
# 3D Rastringin function
f = Rastringin
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0], sample_range=5.12)

# Use moderate degree for 3D
pol = Constructor(TR, 6)

# Find critical points
@polyvar x[1:3]
solutions = solve_polynomial_system(x, 3, 6, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Refine without Hessian for speed
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    enable_hessian=false,  # Faster for high dimensions
    verbose=true
)

println("Found $(nrow(df_min)) local minima in 3D")
```

## Example 5: Domain Exploration

Testing different domain sizes:

```julia
f = HolderTable  # Has 4 global minima

# Try different domain sizes
for r in [8.0, 10.0, 12.0]
    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=r)
    pol = Constructor(TR, 8)

    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
    df = process_crit_pts(solutions, f, TR)
    df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)

    println("Domain ±$r: found $(nrow(df_min)) minima")
end
```

## Example 6: Visualization

Creating plots (requires CairoMakie):

```julia
using CairoMakie

# Run standard analysis
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Create visualizations
fig1 = plot_hessian_norms(df_enhanced)
save("hessian_norms.png", fig1)

fig2 = plot_condition_numbers(df_enhanced)
save("condition_numbers.png", fig2)

fig3 = plot_critical_eigenvalues(df_enhanced)
save("critical_eigenvalues.png", fig3)

fig4 = plot_all_eigenvalues(f, df_enhanced, sort_by=:magnitude)
save("all_eigenvalues.png", fig4)
```

## Example 7: Comparing Polynomial Degrees

Analyzing approximation quality:

```julia
f = Branin
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=15.0)

results = DataFrame(
    degree = Int[],
    l2_error = Float64[],
    n_critical = Int[],
    n_minima = Int[]
)

for deg in [4, 6, 8, 10]
    pol = Constructor(TR, deg)
    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, 2, deg, pol.coeffs)
    df = process_crit_pts(solutions, f, TR)
    df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)

    push!(results, (deg, pol.nrm, nrow(df), nrow(df_min)))
end

println(results)
```

## Example 8: Basin Analysis

Understanding convergence basins:

```julia
# Function with interesting basin structure
f(x) = (x[1]^2 + x[2]^2 - 1)^2 + 0.1*(x[1]^2 + x[2]^2)

TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=2.0)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Analyze basins
println("\\nBasin Analysis:")
for i in 1:nrow(df_min)
    basin_size = df_min[i, :basin_points]
    avg_steps = df_min[i, :average_convergence_steps]
    coverage = df_min[i, :region_coverage_count]

    println("Minimum $i:")
    println("  Basin size: $basin_size points")
    println("  Average convergence: $avg_steps steps")
    println("  Spatial coverage: $coverage regions")
end
```
