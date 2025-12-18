# quick_subdivision_demo.jl
# Quick interactive exploration of adaptive subdivision
#
# Run with: julia --project=. examples/quick_subdivision_demo.jl

using Globtim

println("=" ^ 60)
println("Adaptive Subdivision Demo")
println("=" ^ 60)

#==============================================================================#
#                           TEST FUNCTIONS                                      #
#==============================================================================#

# Simple sphere (should converge quickly)
sphere(x) = sum(x.^2)

# Rosenbrock (challenging narrow valley)
rosenbrock(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2

# Rastrigin (many local minima)
rastrigin(x) = 10 * length(x) + sum(x.^2 .- 10 .* cos.(2π .* x))

# Anisotropic function (varies more in x than y)
anisotropic(x) = sin(5 * x[1]) + 0.1 * sin(x[2])

#==============================================================================#
#                        QUICK TESTS                                            #
#==============================================================================#

function run_test(name::String, f::Function, bounds; degree=4, tolerance=1e-3, max_depth=5)
    println("\n--- $name ---")
    println("Bounds: $bounds")
    println("Degree: $degree, Tolerance: $tolerance, Max depth: $max_depth")

    t = @elapsed begin
        tree = adaptive_refine(f, bounds, degree,
                              l2_tolerance=tolerance,
                              max_depth=max_depth,
                              parallel=false,  # Sequential for reproducibility
                              verbose=false)
    end

    println("Time: $(round(t, digits=3)) s")
    println("Leaves: $(n_leaves(tree)) ($(length(tree.converged_leaves)) converged)")
    println("Max depth: $(get_max_depth(tree))")
    println("Total L2 error: $(round(total_error(tree), sigdigits=4))")

    # Show error distribution
    leaf_ids = vcat(tree.converged_leaves, tree.active_leaves)
    errors = [tree.subdomains[i].l2_error for i in leaf_ids]
    println("Error range: $(round(minimum(errors), sigdigits=3)) - $(round(maximum(errors), sigdigits=3))")

    return tree
end

# Test 1: Simple sphere (2D)
bounds_2d = [(-1.0, 1.0), (-1.0, 1.0)]
tree_sphere = run_test("Sphere (2D)", sphere, bounds_2d, degree=4, tolerance=0.01)

# Test 2: Rosenbrock (2D) - should need more subdivisions
tree_rosen = run_test("Rosenbrock (2D)", rosenbrock, bounds_2d, degree=6, tolerance=0.5, max_depth=4)

# Test 3: Anisotropic function - should subdivide more along x
tree_aniso = run_test("Anisotropic (2D)", anisotropic, bounds_2d, degree=4, tolerance=0.01)

# Test 4: 3D sphere
bounds_3d = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
tree_3d = run_test("Sphere (3D)", sphere, bounds_3d, degree=4, tolerance=0.05, max_depth=3)

#==============================================================================#
#                      DETAILED SUBDIVISION ANALYSIS                            #
#==============================================================================#

println("\n" * "=" ^ 60)
println("Detailed Subdivision Analysis: Rosenbrock")
println("=" ^ 60)

# Run with verbose output
println("\nTwo-phase refinement:")
tree_detailed = two_phase_refine(rosenbrock, bounds_2d, 6,
                                  coarse_tolerance=1.0,
                                  fine_tolerance=0.2,
                                  balance_threshold=5.0,
                                  max_depth=5,
                                  parallel=false,
                                  verbose=true)

# Show leaf geometry
println("\nLeaf subdomain details:")
println("-" ^ 50)
leaf_ids = vcat(tree_detailed.converged_leaves, tree_detailed.active_leaves)
for (i, id) in enumerate(leaf_ids[1:min(10, length(leaf_ids))])
    sd = tree_detailed.subdomains[id]
    bounds = get_bounds(sd)
    println("Leaf $i: depth=$(sd.depth), error=$(round(sd.l2_error, sigdigits=3))")
    println("  center=$(round.(sd.center, sigdigits=3))")
    println("  widths=$(round.(2 .* sd.half_widths, sigdigits=3))")
end

if length(leaf_ids) > 10
    println("... and $(length(leaf_ids) - 10) more leaves")
end

println("\n" * "=" ^ 60)
println("Done!")
println("=" ^ 60)
