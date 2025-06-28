# Orthant Clarification Demo
# Demonstrates the correct number of orthants in 4D space

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using LinearAlgebra, Printf

println("\n" * "="^80)
println("ORTHANT CLARIFICATION IN 4D SPACE")
println("="^80)

println("\nIn n-dimensional space, the number of orthants = 2^n")
println("- 2D: 2^2 = 4 quadrants")
println("- 3D: 2^3 = 8 octants")
println("- 4D: 2^4 = 16 orthants (correct!)")
println("\nNOT 4^2 = 16 (coincidentally same number, but wrong reasoning)")

# Generate all 16 orthant sign patterns
println("\n" * "="^80)
println("ALL 16 ORTHANTS IN 4D")
println("="^80)

orthants = []
for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
    push!(orthants, [s1, s2, s3, s4])
end

println("\nAll 16 orthant sign patterns:")
for (i, signs) in enumerate(orthants)
    sign_str = join([s > 0 ? "+" : "-" for s in signs], "")
    println("Orthant $(lpad(i, 2)): ($sign_str)")
end

# Visual grouping to show structure
println("\n" * "="^80)
println("ORTHANT STRUCTURE")
println("="^80)

println("\nGrouped by first two coordinates:")
for s1 in [-1, 1], s2 in [-1, 1]
    prefix = (s1 > 0 ? "+" : "-") * (s2 > 0 ? "+" : "-")
    println("\nOrthants starting with ($prefix**):")
    for s3 in [-1, 1], s4 in [-1, 1]
        suffix = (s3 > 0 ? "+" : "-") * (s4 > 0 ? "+" : "-")
        full = prefix * suffix
        println("  ($full)")
    end
end

# Example function to show orthant membership
println("\n" * "="^80)
println("EXAMPLE: DETERMINING ORTHANT MEMBERSHIP")
println("="^80)

function get_orthant(point::Vector{Float64})
    signs = [x >= 0 ? 1 : -1 for x in point]
    sign_str = join([s > 0 ? "+" : "-" for s in signs], "")
    return "($sign_str)", signs
end

test_points = [
    [1.0, 2.0, 3.0, 4.0],
    [-1.0, 2.0, -3.0, 4.0],
    [0.5, -0.5, 0.5, -0.5],
    [-0.7412, 0.7412, -0.7412, 0.7412]
]

println("\nTest points and their orthants:")
for point in test_points
    orthant_str, signs = get_orthant(point)
    println("Point [$(join([@sprintf("%.4f", x) for x in point], ", "))] → Orthant $orthant_str")
end

# Memory usage consideration
println("\n" * "="^80)
println("COMPUTATIONAL CONSIDERATIONS")
println("="^80)

println("\nFor higher dimensions:")
for n in [2, 3, 4, 5, 6, 8, 10]
    n_orthants = 2^n
    println("- $(n)D: $(n_orthants) orthants")
end

println("\nThis exponential growth is why orthant decomposition")
println("becomes computationally expensive in high dimensions!")

# Domain decomposition visualization
println("\n" * "="^80)
println("DOMAIN DECOMPOSITION STRATEGY")
println("="^80)

println("\nFor a 4D domain centered at origin with range R:")
println("Each orthant gets:")
println("- Center shifted by: 0.3R × [±1, ±1, ±1, ±1]")
println("- Local range: 0.6R (creates overlap at boundaries)")

# Show overlap calculation
R = 1.0
shift = 0.3 * R
local_range = 0.6 * R

println("\nExample for R = $R:")
println("- Orthant (+,+,+,+) domain: center at [0.3, 0.3, 0.3, 0.3], range 0.6")
println("  Covers: [-0.3, 0.9] × [-0.3, 0.9] × [-0.3, 0.9] × [-0.3, 0.9]")
println("- Orthant (-,+,+,+) domain: center at [-0.3, 0.3, 0.3, 0.3], range 0.6")
println("  Covers: [-0.9, 0.3] × [-0.3, 0.9] × [-0.3, 0.9] × [-0.3, 0.9]")
println("- Overlap in x1: [-0.3, 0.3] (ensures boundary points aren't missed)")

println("\n" * "="^80)
println("SUMMARY")
println("="^80)
println("\n✓ 4D space has 2^4 = 16 orthants (not 4^2)")
println("✓ Each orthant is defined by sign pattern of 4 coordinates")
println("✓ Orthant decomposition helps manage computational complexity")
println("✓ Overlapping domains ensure no critical points are missed")