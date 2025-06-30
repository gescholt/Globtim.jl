# Quick verification script to check if the expected 1e-27 minimum is correct

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim

# Define the 4D composite function
function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# Test the expected global minimum point
println("=== Verifying Expected Minima Values ===\n")

# Expected global minimum from tensor products
point_global = [-0.7412, 0.7412, -0.7412, 0.7412]
f_global = deuflhard_4d_composite(point_global)

println("Expected global minimum point: $point_global")
println("Function value at this point: $f_global")
println("Scientific notation: $(Printf.@sprintf("%.3e", f_global))")

# Let's also check the 2D components
f_2d_1 = Deuflhard([-0.7412, 0.7412])
f_2d_2 = Deuflhard([-0.7412, 0.7412])
println("\n2D components:")
println("Deuflhard([-0.7412, 0.7412]) = $f_2d_1")
println("Sum of 2D components = $(f_2d_1 + f_2d_2)")

# Check a few more expected minima
println("\n=== Checking Other Expected Minima ===")
test_points = [
    ([0.0, 0.0, 0.0, 0.0], "Center point"),
    ([-0.7412, 0.7412, 0.0, 0.0], "Mixed min-center"),
    ([0.0, 0.0, -0.7412, 0.7412], "Center-min mixed"),
    ([0.7412, -0.7412, 0.7412, -0.7412], "Alternative pattern")
]

for (point, desc) in test_points
    f_val = deuflhard_4d_composite(point)
    println("$desc: f($point) = $(Printf.@sprintf("%.6e", f_val))")
end

# Verify gradient at expected minimum
using ForwardDiff
grad = ForwardDiff.gradient(deuflhard_4d_composite, point_global)
grad_norm = LinearAlgebra.norm(grad)
println("\n=== Gradient Verification ===")
println("Gradient at expected global min: $grad")
println("Gradient norm: $(Printf.@sprintf("%.3e", grad_norm))")

# Check if this is actually a minimum by examining the Hessian
H = ForwardDiff.hessian(deuflhard_4d_composite, point_global)
eigenvals = LinearAlgebra.eigvals(H)
println("\n=== Hessian Analysis ===")
println("Eigenvalues: $eigenvals")
println("All positive? $(all(eigenvals .> 0))")
println("Min eigenvalue: $(minimum(eigenvals))")

# Conclusion
println("\n=== CONCLUSION ===")
if abs(f_global) < 1e-20
    println("✓ The expected global minimum value appears to be correct (very close to 0)")
    println("  The 1e-27 value is plausible for this function.")
else
    println("⚠ The expected global minimum value seems different from 1e-27")
    println("  Actual value: $(Printf.@sprintf("%.6e", f_global))")
end

if grad_norm < 1e-10
    println("✓ The point appears to be a critical point (small gradient)")
else
    println("⚠ The gradient is large, may not be a critical point")
end

if all(eigenvals .> 0)
    println("✓ The point is confirmed to be a local minimum (positive definite Hessian)")
else
    println("⚠ The point may not be a minimum")
end