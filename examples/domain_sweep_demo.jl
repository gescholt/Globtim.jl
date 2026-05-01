# Domain Sweep Demo
# Demonstrates how domain size affects critical point discovery

using Globtim
using DynamicPolynomials
using DataFrames
using Printf

# Use HolderTable which has 4 symmetric global minima
f = HolderTable

println("Domain Sweep Demo - HolderTable Function")
println("="^50)
println("HolderTable has 4 global minima at approximately (±8.05, ±9.66)")
println()

# Sweep through different domain sizes
domain_ranges = [5.0, 8.0, 10.0, 12.0, 15.0]
degree = 8

println("Testing domain sizes with polynomial degree $degree:")
println()
println("Range    | Critical Pts | Minima | Global Min Value")
println("---------|--------------|--------|------------------")

for r in domain_ranges
    TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=r)
    pol = Constructor(TR, degree)

    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, pol)
    df = process_crit_pts(solutions, f, TR)
    df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=false, verbose=false)

    # Find best minimum value
    best_val = nrow(df_min) > 0 ? minimum(df_min.value) : NaN

    @printf("±%-7.1f |     %4d     |   %3d  |   %10.4f\n",
            r, nrow(df), nrow(df_min), best_val)
end

println()
println("Observations:")
println("   - Too small domain misses global minima (located at ±8.05, ±9.66)")
println("   - Domain ±10 or larger captures all 4 global minima")
println("   - Larger domains require higher polynomial degrees")

# Non-uniform domain example
println("\n" * "="^50)
println("Non-uniform Domain Example")
println("="^50)

TR_rect = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=[8.5, 10.0])
pol_rect = Constructor(TR_rect, degree)

@polyvar x[1:2]
solutions_rect = solve_polynomial_system(x, pol_rect)
df_rect = process_crit_pts(solutions_rect, f, TR_rect)
df_enhanced_rect, df_min_rect = analyze_critical_points(f, df_rect, TR_rect, enable_hessian=false, verbose=false)

println("Rectangular domain: [-8.5, 8.5] × [-10, 10]")
println("Critical points: $(nrow(df_rect))")
println("Local minima: $(nrow(df_min_rect))")

if nrow(df_min_rect) > 0
    println("\nMinima found:")
    for i in 1:min(4, nrow(df_min_rect))
        x1 = round(df_min_rect[i, :x1], digits=3)
        x2 = round(df_min_rect[i, :x2], digits=3)
        val = round(df_min_rect[i, :value], digits=4)
        println("   ($x1, $x2) → f = $val")
    end
end
