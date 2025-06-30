# Test Phase 1 Enhanced Statistics Implementation
# Based on Ratstrigin_3.ipynb

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials, DataFrames
using ProgressLogging
using StaticArrays

println("=== Testing Phase 1 Enhanced Statistics ===")

# Constants and Parameters (from Ratstrigin_3.ipynb)
const n, a, b = 3, 1, 1
const scale_factor = a / b
f = Rastringin  
rand_center = [0.0, 0.0, 0.0]
d = 10 # initial degree 
SMPL = 40 # Number of samples

println("Setting up test input...")
TR = test_input(f, 
                dim = n,
                center=rand_center,
                GN=SMPL, 
                sample_range=scale_factor 
                )

println("TR: $TR")

println("Constructing polynomial approximation...")
pol_cheb = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)
@polyvar(x[1:n]) # Define polynomial ring 

println("Solving polynomial system...")
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis,
    precision=pol_cheb.precision,
    normalized=pol_cheb.normalized,
)

println("Found $(length(real_pts_cheb)) critical points")

println("Processing critical points...")
df_cheb = process_crit_pts(real_pts_cheb, f, TR)

println("DataFrame before enhanced analysis:")
println("Columns: $(names(df_cheb))")
println("Size: $(size(df_cheb))")

println("\n=== Running Enhanced Analysis (Phase 1) ===")
# This should now include enhanced statistics
tol_dist = 0.05
df_cheb_enhanced, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=tol_dist, verbose=true)

println("\n=== Results ===")
println("Enhanced DataFrame columns: $(names(df_cheb_enhanced))")
println("Enhanced DataFrame size: $(size(df_cheb_enhanced))")

if nrow(df_min_cheb) > 0
    println("Minimizers DataFrame columns: $(names(df_min_cheb))")
    println("Minimizers DataFrame size: $(size(df_min_cheb))")
    
    println("\n=== Sample Enhanced Statistics ===")
    println("First 5 rows of enhanced critical points:")
    println(first(df_cheb_enhanced, 5))
    
    println("\n=== Enhanced Statistics Column Documentation ===")
    println("Critical Points DataFrame Columns:")
    println("  x1, x2, x3        - Original critical point coordinates")
    println("  z                 - Function value at critical point")
    println("  y1, y2, y3        - BFGS optimized coordinates from critical point")
    println("  close             - Whether optimized point is close to starting point (tol_dist=$tol_dist)")
    println("  steps             - Number of BFGS optimization iterations")
    println("  converged         - Whether BFGS converged within domain bounds")
    println("  region_id         - Spatial region ID (domain divided into cubic regions)")
    println("  function_value_cluster - Cluster ID based on function value similarity")
    println("  nearest_neighbor_dist  - Distance to nearest other critical point")
    println("  gradient_norm     - ||∇f(x)|| at critical point (should be ~0)")
    
    println("\nUnique Minimizers DataFrame Columns:")
    println("  x1, x2, x3              - Coordinates of unique minimizer")
    println("  value                   - Function value at minimizer")
    println("  captured                - Whether minimizer was captured by a critical point")
    println("  basin_points            - Number of critical points converging to this minimizer")
    println("  average_convergence_steps - Average BFGS steps for points reaching this minimizer")
    println("  region_coverage_count   - Number of different spatial regions feeding this minimizer")
    println("  gradient_norm_at_min    - ||∇f(x)|| at minimizer (should be very close to 0)")

    println("\nUnique minimizers with enhanced data:")
    println(df_min_cheb)
    
else
    println("No unique minimizers found")
end

println("\n=== Phase 1 Implementation Test Complete ===")