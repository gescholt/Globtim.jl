using Pkg; Pkg.activate(@__DIR__)

include("test_functions.jl")

# Test Himmelblau function at its known minima
minima = [[3.0, 2.0], [-2.805118, 3.131312], 
          [-3.779310, -3.283186], [3.584428, -1.848126]]

println("Testing Himmelblau function at known minima:")
println("="^50)

for (i, x) in enumerate(minima)
    f_val = himmelblau(x)
    println("Minimum $i: x = $x")
    println("  f(x) = $f_val")
    println("  log10(f(x) + 1e-10) = $(log10(f_val + 1e-10))")
    println()
end

# Test at a non-minimum point
x_test = [0.0, 0.0]
f_test = himmelblau(x_test)
println("At origin [0, 0]:")
println("  f([0,0]) = $f_test")
println("  log10(f + 1e-10) = $(log10(f_test + 1e-10))")

# Let's also check if there's any issue with the function definition
println("\nFunction definition check:")
x = [3.0, 2.0]
term1 = x[1]^2 + x[2] - 11
term2 = x[1] + x[2]^2 - 7
f_manual = term1^2 + term2^2
println("At [3.0, 2.0]:")
println("  First term: ($x[1])² + $x[2] - 11 = $term1")
println("  Second term: $x[1] + ($x[2])² - 7 = $term2")
println("  f = ($term1)² + ($term2)² = $f_manual")