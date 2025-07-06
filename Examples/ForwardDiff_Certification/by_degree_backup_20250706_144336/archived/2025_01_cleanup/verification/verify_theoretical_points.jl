# Verify that theoretical minimizers evaluate to small values
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Define the 4D Deuflhard composite function
function deuflhard_4d_composite(x::Vector{T}) where T
    x1, x2, x3, x4 = x
    term1 = exp(5*(x1 - 0.2*x2^2 - x3^3 - x4^2))
    term2 = exp(5*(-x1 + 0.2*x2^2 + x3^3 - x4^2))
    term3 = exp(x2^2 + x3^2 + x4^2)
    return term1 + term2 + term3
end

# Define the 9 theoretical minimizers
theoretical_minimizers = [
    [0.0, 0.0, 0.0, 0.0],          # Central minimizer
    [0.0, -1.0, 0.0, 0.0],         # Face centers
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, -1.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, -1.0],
    [0.0, 0.0, 0.0, 1.0],
    [-1.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 0.0]
]

println("Verifying theoretical minimizers for 4D Deuflhard composite function")
println("="^70)
println()

# Evaluate function at each theoretical minimizer
for (i, point) in enumerate(theoretical_minimizers)
    f_value = deuflhard_4d_composite(point)
    println("Point $i: $(point)")
    println("  f(x) = $f_value")
    println("  f(x) ≈ $(round(f_value, sigdigits=6))")
    println()
end

# Also check some statistics
f_values = [deuflhard_4d_composite(p) for p in theoretical_minimizers]
println("Summary Statistics:")
println("  Minimum f value: $(minimum(f_values))")
println("  Maximum f value: $(maximum(f_values))")
println("  Average f value: $(sum(f_values)/length(f_values))")
println()

# Check if all values are reasonably small (e.g., < 10)
threshold = 10.0
all_small = all(f -> f < threshold, f_values)
println("All function values < $threshold: $all_small")

# Find the actual minimum value
min_val = minimum(f_values)
min_idx = argmin(f_values)
println("\nSmallest function value: $min_val at point $(theoretical_minimizers[min_idx])")