# Verify that all 9 minimizers are within the stretched domain
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# The 9 theoretical minimizers
theoretical_minimizers = [
    [0.256625076922502, -1.01624596361443, 0.256625076922502, -1.01624596361443],
    [0.256625076922502, -1.01624596361443, 0.74115190368376, -0.741151903683748],
    [0.256625076922502, -1.01624596361443, 1.01624596361443, -0.256625076922483],
    [0.74115190368376, -0.741151903683748, 0.256625076922502, -1.01624596361443],
    [0.74115190368376, -0.741151903683748, 0.74115190368376, -0.741151903683748],
    [0.74115190368376, -0.741151903683748, 1.01624596361443, -0.256625076922483],
    [1.01624596361443, -0.256625076922483, 0.256625076922502, -1.01624596361443],
    [1.01624596361443, -0.256625076922483, 0.74115190368376, -0.741151903683748],
    [1.01624596361443, -0.256625076922483, 1.01624596361443, -0.256625076922483]
]

# Original bounds: [0,1] × [-1,0] × [0,1] × [-1,0]
# Stretched bounds: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]
stretched_bounds = [(-0.1, 1.1), (-1.1, 0.1), (-0.1, 1.1), (-1.1, 0.1)]

println("Verifying 9 theoretical minimizers against stretched domain bounds")
println("Stretched domain: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]")
println("="^70)

all_in_bounds = true
for (i, pt) in enumerate(theoretical_minimizers)
    in_bounds = true
    violations = String[]
    
    for (dim, coord) in enumerate(pt)
        min_b, max_b = stretched_bounds[dim]
        if coord < min_b || coord > max_b
            in_bounds = false
            push!(violations, "x$dim = $coord not in [$min_b, $max_b]")
        end
    end
    
    status = in_bounds ? "✓ IN" : "✗ OUT"
    println("$status Minimizer $i: [$(join(round.(pt, digits=4), ", "))]")
    
    if !in_bounds
        for v in violations
            println("     $v")
        end
        all_in_bounds = false
    end
end

println("\nSummary: $(all_in_bounds ? "All minimizers are within the stretched domain!" : "Some minimizers are still outside the domain!")")

# Check the extreme values
println("\nExtreme coordinate values among minimizers:")
for dim in 1:4
    coords = [pt[dim] for pt in theoretical_minimizers]
    min_coord = minimum(coords)
    max_coord = maximum(coords)
    min_b, max_b = stretched_bounds[dim]
    println("  Dimension $dim: min=$min_coord, max=$max_coord (bounds: [$min_b, $max_b])")
end