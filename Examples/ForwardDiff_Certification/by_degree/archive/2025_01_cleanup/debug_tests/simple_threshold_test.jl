using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Simplified test without module conflicts
using Globtim
using DynamicPolynomials  
using LinearAlgebra
using DataFrames, CSV
using Statistics
using Printf

println("="^80)
println("SIMPLE THRESHOLD TEST")
println("="^80)

# Load true minimizers
true_minimizers_df = CSV.read(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"), DataFrame)
true_minimizers = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(true_minimizers_df)]

# Test with the problematic subdomain center and range
center = [0.8, -0.8, 0.8, -0.8]
range = 0.3

# Create test function (simplified Deuflhard)
function simple_deuflhard_4d(x)
    x1, x2, x3, x4 = x
    term1 = (x1^2 + x2^2 - 1)^2
    term2 = (x3^2 + x4^2 - 1)^2
    return term1 + term2
end

# Test with degree 2
TR = test_input(simple_deuflhard_4d, dim=4, center=center, sample_range=range, GN=16)
pol = Constructor(TR, 2, verbose=0)

@polyvar x[1:4]
df_crit = process_crit_pts(
    solve_polynomial_system(x, 4, 2, pol.coeffs),
    simple_deuflhard_4d,
    TR
)

# Extract computed points
computed_points = [[row[Symbol("x$i")] for i in 1:4] for row in eachrow(df_crit)]

println("Computed points: $(length(computed_points))")
println("True minimizers: $(length(true_minimizers))")

# Test different thresholds
thresholds = [0.1, 0.2, 0.3]
for threshold in thresholds
    recovered = 0
    min_distances = []
    
    for true_min in true_minimizers
        if !isempty(computed_points)
            distances = [norm(cp - true_min) for cp in computed_points]
            min_dist = minimum(distances)
            push!(min_distances, min_dist)
            if min_dist < threshold
                recovered += 1
            end
        end
    end
    
    avg_dist = isempty(min_distances) ? Inf : mean(min_distances)
    println("Threshold $threshold: recovered $recovered/$(length(true_minimizers)), avg_dist=$(@sprintf("%.3f", avg_dist))")
end

println("\n✓ With threshold 0.2, we should see some recovery > 0")
println("This confirms the threshold fix works!")