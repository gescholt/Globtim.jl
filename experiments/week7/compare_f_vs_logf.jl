"""
    compare_f_vs_logf.jl

Simple comparison script showing critical points and valley walking paths
for both approaches: approximating f vs approximating log(f).

This creates a single plot showing:
1. Level sets of log(f) as background
2. Critical points from polynomial(f) in red circles (labeled A1, A2, ...)
3. Critical points from polynomial(log(f)) in blue diamonds (labeled B1, B2, ...)
4. Valley walking paths from approach A in red solid lines
5. Valley walking paths from approach B in blue dashed lines
"""

using Pkg; Pkg.activate(@__DIR__)

using Revise
using Globtim
using DynamicPolynomials
using DataFrames
using GLMakie
using Printf

# Include necessary modules
include("test_functions.jl")
include("valley_walking_utils.jl")
include("polynomial_degree_optimization.jl")

println("="^80)
println("COMPARISON: f vs log(f) APPROACHES")
println("="^80)

# Select test function
FUNCTION_NAME = :himmelblau
func_info = get_test_function_info(FUNCTION_NAME)
objective_func = func_info.func

println("Function: $(func_info.description)")

# Configuration
base_config = (
    n = 2,
    p_center = [0.0, 0.0],
    sample_range = 5.0,
    basis = :chebyshev,
    precision = Globtim.Float64Precision,
)

# Create safe log transformation
sample_points = [[x, y] for x in -5:1:5 for y in -5:1:5]
sample_values = [objective_func(p) for p in sample_points]
min_val = minimum(sample_values)

if min_val <= 0
    shift = abs(min_val) + 1.0
    log_objective_func = x -> log10(objective_func(x) + shift)
    println("Shifted function by $shift for log transformation")
else
    log_objective_func = x -> log10(objective_func(x) + 1e-12)
end

# Test single polynomial degree for both approaches - using minimal configuration
degree = 6  # Much smaller degree to avoid hanging
samples = 50  # Fixed small sample size
println("\nUsing polynomial degree $degree with $samples samples for both approaches")

# APPROACH A: Approximate f, find critical points
println("\nAPPROACH A: Approximating f")
println("-"^40)

config_A = merge(base_config, (d = (:one_d_for_all, degree), GN = samples))

println("  Creating test input for approach A...")
TR_A = Globtim.test_input(objective_func, dim=config_A.n, center=config_A.p_center,
                         sample_range=config_A.sample_range, GN=config_A.GN, tolerance=nothing)

println("  Constructing polynomial for approach A (degree=$degree, samples=$samples)...")
global pol_A = nothing
try
    global pol_A = Globtim.Constructor(TR_A, degree, basis=config_A.basis, precision=config_A.precision)
    println("  ✅ Polynomial construction successful!")
catch e
    println("  ❌ Polynomial construction failed: $e")
    error("Cannot proceed without polynomial")
end

println("  Solving polynomial system for approach A...")
@polyvar x[1:config_A.n]
solutions_A = Globtim.solve_polynomial_system(x, config_A.n, degree, pol_A.coeffs;
                                             basis=pol_A.basis, precision=pol_A.precision,
                                             normalized=config_A.basis == :legendre,
                                             power_of_two_denom=pol_A.power_of_two_denom)

println("  Processing critical points for approach A...")
critical_points_A = Globtim.process_crit_pts(solutions_A, objective_func, TR_A)
n_points_A = nrow(critical_points_A)
println("Found $n_points_A critical points from polynomial(f)")

if n_points_A == 0
    error("❌ APPROACH A FAILED: No critical points found from polynomial(f)")
end

# APPROACH B: Approximate log(f), find critical points
println("\nAPPROACH B: Approximating log(f)")
println("-"^40)

config_B = merge(base_config, (d = (:one_d_for_all, degree), GN = samples))

println("  Creating test input for approach B...")
TR_B = Globtim.test_input(log_objective_func, dim=config_B.n, center=config_B.p_center,
                         sample_range=config_B.sample_range, GN=config_B.GN, tolerance=nothing)

println("  Constructing polynomial for approach B (degree=$degree, samples=$samples)...")
global pol_B = nothing
try
    global pol_B = Globtim.Constructor(TR_B, degree, basis=config_B.basis, precision=config_B.precision)
    println("  ✅ Polynomial construction successful!")
catch e
    println("  ❌ Polynomial construction failed: $e")
    error("Cannot proceed without polynomial")
end

println("  Solving polynomial system for approach B...")
solutions_B = Globtim.solve_polynomial_system(x, config_B.n, degree, pol_B.coeffs;
                                             basis=pol_B.basis, precision=pol_B.precision,
                                             normalized=config_B.basis == :legendre,
                                             power_of_two_denom=pol_B.power_of_two_denom)

println("  Processing critical points for approach B...")
critical_points_B = Globtim.process_crit_pts(solutions_B, log_objective_func, TR_B)
n_points_B = nrow(critical_points_B)
println("Found $n_points_B critical points from polynomial(log(f))")

if n_points_B == 0
    error("❌ APPROACH B FAILED: No critical points found from polynomial(log(f))")
end

# Perform valley walking from both sets of critical points
println("\nPerforming valley walking...")

# Valley walking from approach A critical points (walk on f)
valley_results_A = []
for (i, row) in enumerate(eachrow(critical_points_A))
    x0 = [row.x1, row.x2]
    println("  Valley walking A$i from $(round.(x0, digits=3))")
    points, eigenvals, f_vals, step_types = enhanced_valley_walk_no_oscillation(
        objective_func, x0;  # Walk on original f
        n_steps = 50, step_size = 0.02, verbose = false
    )
    push!(valley_results_A, (points = points, start_point = x0, approach = "A"))
end

# Valley walking from approach B critical points (walk on log(f))
valley_results_B = []
for (i, row) in enumerate(eachrow(critical_points_B))
    x0 = [row.x1, row.x2]
    println("  Valley walking B$i from $(round.(x0, digits=3))")
    points, eigenvals, f_vals, step_types = enhanced_valley_walk_no_oscillation(
        log_objective_func, x0;  # Walk on log(f)
        n_steps = 50, step_size = 0.02, verbose = false
    )
    push!(valley_results_B, (points = points, start_point = x0, approach = "B"))
end

println("✅ Approach A: $(length(valley_results_A)) valley walks completed")
println("✅ Approach B: $(length(valley_results_B)) valley walks completed")

# Create visualization
println("\nCreating visualization...")

fig = Figure(size = (1000, 800))
ax = Axis(fig[1, 1], 
         title = "Comparison: f vs log(f) approaches (on log(f) level sets)",
         xlabel = "x₁", ylabel = "x₂")

# Plot level sets of log(f) as background with color gradient
domain_bounds = (-5.0, 5.0, -5.0, 5.0)
x_range = range(domain_bounds[1], domain_bounds[2], length=100)
y_range = range(domain_bounds[3], domain_bounds[4], length=100)
Z_log = [log_objective_func([x, y]) for x in x_range, y in y_range]

# Add filled contour plot for color gradient background
contourf!(ax, x_range, y_range, Z_log, levels = 20, colormap = :viridis)

# Add contour lines for better visibility
contour!(ax, x_range, y_range, Z_log, levels = 15, color = :black, linewidth = 1)

# Plot critical points A (red circles)
if !isempty(critical_points_A)
    scatter!(ax, critical_points_A.x1, critical_points_A.x2, 
            color = :red, markersize = 15, marker = :circle,
            label = "Critical points from polynomial(f)")
    
    for (i, row) in enumerate(eachrow(critical_points_A))
        text!(ax, row.x1, row.x2, text = "A$i", color = :red, fontsize = 12,
              align = (:center, :bottom), offset = (0, 8))
    end
end

# Plot critical points B (blue diamonds)
if !isempty(critical_points_B)
    scatter!(ax, critical_points_B.x1, critical_points_B.x2, 
            color = :blue, markersize = 15, marker = :diamond,
            label = "Critical points from polynomial(log(f))")
    
    for (i, row) in enumerate(eachrow(critical_points_B))
        text!(ax, row.x1, row.x2, text = "B$i", color = :blue, fontsize = 12,
              align = (:center, :top), offset = (0, -8))
    end
end

# Plot valley walking paths A (red solid lines)
for result in valley_results_A
    xs = [p[1] for p in result.points]
    ys = [p[2] for p in result.points]
    lines!(ax, xs, ys, color = (:red, 0.8), linewidth = 2, linestyle = :solid)
    scatter!(ax, [xs[1]], [ys[1]], color = :red, markersize = 6, marker = :star5)
end

# Plot valley walking paths B (blue dashed lines)
for result in valley_results_B
    xs = [p[1] for p in result.points]
    ys = [p[2] for p in result.points]
    lines!(ax, xs, ys, color = (:blue, 0.8), linewidth = 2, linestyle = :dash)
    scatter!(ax, [xs[1]], [ys[1]], color = :blue, markersize = 6, marker = :star5)
end

# Add legend
axislegend(ax, position = :rt)

# Set limits
xlims!(ax, domain_bounds[1], domain_bounds[2])
ylims!(ax, domain_bounds[3], domain_bounds[4])

display(fig)

println("\n" * "="^80)
println("SUMMARY")
println("="^80)
println("Red circles (A1, A2, ...): Critical points from polynomial approximation of f")
println("Blue diamonds (B1, B2, ...): Critical points from polynomial approximation of log(f)")
println("Red solid lines: Valley walking paths on f starting from A points")
println("Blue dashed lines: Valley walking paths on log(f) starting from B points")
println("Background: Level sets of log(f)")
println("\nBoth approaches should find similar critical points but may have different")
println("convergence properties due to the different function landscapes.")
println("="^80)
