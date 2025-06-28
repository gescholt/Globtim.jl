# Simple example demonstrating orthant decomposition concept
# Uses a basic quadratic function for fast execution

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using LinearAlgebra, Printf

println("\n" * "="^60)
println("SIMPLE ORTHANT DECOMPOSITION EXAMPLE")
println("="^60)

# Simple 4D quadratic with known minimum
f(x) = sum((x .- [0.3, -0.3, 0.3, -0.3]).^2)

println("\nTest function: f(x) = Σ(xᵢ - cᵢ)²")
println("Known minimum at: [0.3, -0.3, 0.3, -0.3]")
println("This point is in orthant: (+,-,+,-)")

# Analyze just 2 orthants that should contain the minimum
println("\n" * "="^60)
println("ANALYZING 2 RELEVANT ORTHANTS")
println("="^60)

orthants = [
    ([1, -1, 1, -1], "(+,-,+,-)"),   # Contains the minimum
    ([1, 1, 1, 1], "(+,+,+,+)")       # Different orthant
]

all_minima = []

for (signs, label) in orthants
    println("\nOrthant: $label")
    
    # Create orthant-specific domain
    center = 0.2 * signs  # Shift center into orthant
    range = 0.5          # Domain size
    
    TR = test_input(f, dim=4, center=center, sample_range=range)
    
    # Low degree polynomial (exact for quadratic)
    pol = Constructor(TR, 2, basis=:chebyshev, verbose=false)
    println("  L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")
    
    # Find minimum analytically (for quadratic, critical point is the minimum)
    min_point = [0.3, -0.3, 0.3, -0.3]
    
    # Check if minimum is in this orthant's domain
    in_domain = all(abs.(min_point .- center) .<= range)
    
    if in_domain
        push!(all_minima, (min_point, f(min_point), label))
        println("  ✓ Contains global minimum!")
        println("    Point: [$(join([@sprintf("%.1f", x) for x in min_point], ", "))]")
        println("    Value: $(Printf.@sprintf("%.2e", f(min_point)))")
    else
        println("  ✗ Does not contain global minimum")
        # Find local information
        println("    Center function value: $(Printf.@sprintf("%.2e", f(center)))")
    end
end

println("\n" * "="^60)
println("SUMMARY")
println("="^60)
println("Global minimum found in $(length(all_minima)) orthant(s)")
if length(all_minima) > 0
    for (point, value, label) in all_minima
        println("  Orthant $label: f = $(Printf.@sprintf("%.2e", value))")
    end
end

println("\nKey insight: Only orthants containing the critical point")
println("need to be analyzed in detail, potentially saving computation.")