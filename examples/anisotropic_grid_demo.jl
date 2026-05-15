# Anisotropic Grid Demonstration
# This example shows how to use anisotropic grids for efficient L2 norm computation

using Globtim
using Printf

println("="^60)
println("Anisotropic Grid Demonstration")
println("="^60)

# Example 1: Basic anisotropic grid generation
println("\n1. Basic Anisotropic Grid Generation")
println("-"^40)

# Create a 2D anisotropic grid with different resolution in each dimension
grid_2d = generate_anisotropic_grid([10, 5], basis = :chebyshev)
println("Created 2D grid with size: ", size(grid_2d))
println("Grid has $(length(grid_2d)) total points")

# Example 2: Function with different scales in each direction
println("\n2. Multiscale Function Example")
println("-"^40)

# Function that varies rapidly in x, slowly in y
f_multiscale = x -> exp(-50 * x[1]^2 - 2 * x[2]^2)
println("Testing function: f(x,y) = exp(-50x² - 2y²)")

# Compare isotropic vs anisotropic grids with similar total points
n_iso = 12
l2_iso = compute_l2_norm_quadrature(f_multiscale, [n_iso, n_iso], :chebyshev)
total_iso = (n_iso + 1)^2
println("\nIsotropic grid ($n_iso×$n_iso, $total_iso points):")
println("  L2 norm = $(@sprintf("%.8f", l2_iso))")

# Smart anisotropic: more points where function varies rapidly
nx_aniso = 20
ny_aniso = 7
l2_aniso = compute_l2_norm_quadrature(f_multiscale, [nx_aniso, ny_aniso], :chebyshev)
total_aniso = (nx_aniso + 1) * (ny_aniso + 1)
println("\nAnisotropic grid ($nx_aniso×$ny_aniso, $total_aniso points):")
println("  L2 norm = $(@sprintf("%.8f", l2_aniso))")

# High-accuracy reference
l2_ref = compute_l2_norm_quadrature(f_multiscale, [100, 100], :chebyshev)
println("\nReference L2 norm (100×100): $(@sprintf("%.8f", l2_ref))")

error_iso = abs(l2_iso - l2_ref)
error_aniso = abs(l2_aniso - l2_ref)
println("\nErrors:")
println("  Isotropic:   $(@sprintf("%.2e", error_iso))")
println("  Anisotropic: $(@sprintf("%.2e", error_aniso))")
println("  Improvement factor: $(@sprintf("%.2f", error_iso/error_aniso))×")

# Example 3: High-dimensional anisotropic grids
println("\n3. High-Dimensional Example (4D)")
println("-"^40)

# 4D function with different decay rates
f_4d = x -> exp(-sum(i * x[i]^2 for i in 1:4))
println("Testing function: f(x) = exp(-x₁² - 2x₂² - 3x₃² - 4x₄²)")

# Anisotropic grid: more points where function varies less rapidly
grid_sizes = [12, 10, 8, 6]
l2_4d = compute_l2_norm_quadrature(f_4d, grid_sizes, :chebyshev)
total_4d = prod(s + 1 for s in grid_sizes)
println("\nAnisotropic 4D grid $(join(grid_sizes, "×")), $total_4d total points:")
println("  L2 norm = $(@sprintf("%.8f", l2_4d))")

# Example 4: Comparing quadrature and Riemann methods
println("\n4. Quadrature vs Riemann Methods")
println("-"^40)

f_test = x -> exp(-(x[1]^2 + x[2]^2))
grid_spec = [20, 15]

# Generate grid for Riemann method
grid = generate_anisotropic_grid(grid_spec, basis = :chebyshev)

# Compute using both methods
t1 = @elapsed l2_quad = compute_l2_norm_quadrature(f_test, grid_spec, :chebyshev)
t2 = @elapsed l2_riemann = discrete_l2_norm_riemann(f_test, grid)

println("Grid: $(grid_spec[1])×$(grid_spec[2])")
println(
    "Quadrature L2 norm: $(@sprintf("%.8f", l2_quad)) (time: $(@sprintf("%.3f", t1*1000)) ms)"
)
println(
    "Riemann L2 norm:    $(@sprintf("%.8f", l2_riemann)) (time: $(@sprintf("%.3f", t2*1000)) ms)"
)
println("Relative difference: $(@sprintf("%.2e", abs(l2_quad - l2_riemann)/l2_quad))")

# Example 5: Optimal grid selection
println("\n5. Grid Optimization Strategy")
println("-"^40)

# Function with known directional derivatives
f_opt = x -> sin(10 * x[1]) * exp(-x[2]^2)
println("Testing function: f(x,y) = sin(10x) * exp(-y²)")

# Estimate optimal grid ratio based on function characteristics
# High frequency in x → need more points
# Smooth decay in y → need fewer points

configurations = [
    ([20, 20], "Isotropic"),
    ([30, 13], "Anisotropic 30×13"),
    ([40, 10], "Anisotropic 40×10"),
    ([50, 8], "Anisotropic 50×8")
]

println("\nTesting different configurations (~400 total points each):")
l2_ref_opt = compute_l2_norm_quadrature(f_opt, [200, 200], :chebyshev)

for (grid_size, name) in configurations
    l2 = compute_l2_norm_quadrature(f_opt, grid_size, :chebyshev)
    error = abs(l2 - l2_ref_opt)
    total = prod(s + 1 for s in grid_size)
    println("  $name ($total points): error = $(@sprintf("%.2e", error))")
end

# Example 6: Different polynomial bases
println("\n6. Different Polynomial Bases")
println("-"^40)

f_smooth = x -> exp(-(x[1]^2 + x[2]^2))
grid_spec_bases = [25, 15]

for basis in [:chebyshev, :legendre, :uniform]
    l2 = compute_l2_norm_quadrature(f_smooth, grid_spec_bases, basis)
    println("$basis basis: L2 norm = $(@sprintf("%.8f", l2))")
end

println("\n" * "="^60)
println("Key Takeaways:")
println("- Anisotropic grids allocate points based on function behavior")
println("- More efficient than isotropic grids for multiscale functions")
println("- Both quadrature and Riemann methods support anisotropic grids")
println("- Choose grid sizes based on directional variation rates")
println("="^60)

# Example 7: Integration with Polynomial Approximation
println("\n7. Polynomial Approximation with Anisotropic Grids")
println("-"^40)

# Function with different scales
f_poly = x -> exp(-100 * x[1]^2 - x[2]^2)
TR = TestInput(f_poly, dim = 2, center = [0.0, 0.0], sample_range = 1.0)

# Traditional isotropic approximation
println("\nIsotropic polynomial approximation:")
pol_iso = Constructor(TR, 8, verbose = 0)
println("  Grid points: $(pol_iso.N)")
println("  L2 norm error: $(@sprintf("%.6f", pol_iso.nrm))")
println("  Condition number: $(@sprintf("%.2e", pol_iso.cond_vandermonde))")

# Anisotropic grid approximation
println("\nAnisotropic polynomial approximation:")
grid_aniso = generate_anisotropic_grid([15, 6], basis = :chebyshev)
grid_matrix = convert_to_matrix_grid(vec(grid_aniso))
pol_aniso = Constructor(TR, 0, grid = grid_matrix, verbose = 0)
println("  Grid points: $(pol_aniso.N)")
println("  L2 norm error: $(@sprintf("%.6f", pol_aniso.nrm))")
println("  Condition number: $(@sprintf("%.2e", pol_aniso.cond_vandermonde))")

# Demonstrate automatic detection
println("\nAutomatic anisotropic detection:")
test_grid = [
    -0.8660 -0.5000
    0.0000 -0.5000
    0.8660 -0.5000
    -0.8660 0.5000
    0.0000 0.5000
    0.8660 0.5000
]
pol_detect = MainGenerate(f_poly, 2, test_grid, 0.1, 0.99, 1.0, 1.0, verbose = 1)

println("\n" * "="^60)
println("NEW: Lambda Vandermonde Integration")
println("- Automatic detection of anisotropic grids")
println("- Optimized dimension-wise polynomial evaluation")
println("- Full integration with Constructor and MainGenerate")
println("- Maintains type stability and performance")
println("="^60)
