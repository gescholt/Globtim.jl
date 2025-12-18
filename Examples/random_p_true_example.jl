#!/usr/bin/env julia
# Example: Using Random p_true Generation for Parameter Recovery
#
# This script demonstrates how to use generate_random_interior_point
# to create random true parameters for parameter recovery experiments.

using Pkg
Pkg.activate(dirname(@__DIR__))

using Globtim
using Random
using Statistics

println("="^80)
println("RANDOM P_TRUE GENERATION EXAMPLES")
println("="^80)
println()

# Example 1: Basic Usage
println("Example 1: Basic 4D Parameter Generation")
println("-" * "="^79)

center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8
dim = 4

Random.seed!(42)  # For reproducibility
p_true = generate_random_interior_point(center, domain_size, dim)

println("Center:       $center")
println("Domain size:  $domain_size")
println("Generated p_true: $p_true")
println()

# Verify it's in bounds
margin = 0.1  # default
interior_factor = 1.0 - margin
bounds_lower = center .- interior_factor .* domain_size
bounds_upper = center .+ interior_factor .* domain_size

println("Expected bounds (with margin=$margin):")
println("  Lower: $bounds_lower")
println("  Upper: $bounds_upper")
println("  In bounds: ", all(bounds_lower .<= p_true .<= bounds_upper))
println()

# Example 2: Different Margins
println("Example 2: Effect of Different Margins")
println("-" * "="^79)

margins = [0.0, 0.1, 0.2, 0.3]
println("Center: $center, Domain size: $domain_size")
println()

for margin in margins
    Random.seed!(100)  # Same seed to show margin effect
    p = generate_random_interior_point(center, domain_size, dim, margin=margin)

    max_deviation = maximum(abs.(p .- center))
    expected_max = (1.0 - margin) * domain_size

    println("Margin $margin:")
    println("  p_true: $p")
    println("  Max deviation from center: $(round(max_deviation, digits=3))")
    println("  Expected max: $(round(expected_max, digits=3))")
    println()
end

# Example 3: Per-Dimension Domain Sizes
println("Example 3: Per-Dimension Domain Sizes")
println("-" * "="^79)

center = [1.0, 1.0, 1.0, 1.0]
domain_sizes = [0.8, 0.6, 0.9, 0.7]  # Different size per dimension

Random.seed!(123)
p_true = generate_random_interior_point(center, domain_sizes, dim)

println("Center:        $center")
println("Domain sizes:  $domain_sizes")
println("Generated p_true: $p_true")
println()

for i in 1:dim
    deviation = abs(p_true[i] - center[i])
    max_dev = (1.0 - 0.1) * domain_sizes[i]
    println("  Dimension $i: $(p_true[i]) (deviation: $(round(deviation, digits=3)), max: $(round(max_dev, digits=3)))")
end
println()

# Example 4: Reproducibility with Seeds
println("Example 4: Reproducibility with Seeds")
println("-" * "="^79)

seed = 999
center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

println("Using seed=$seed, generating 3 times:")
for i in 1:3
    Random.seed!(seed)
    p = generate_random_interior_point(center, domain_size, 4)
    println("  Attempt $i: $p")
end
println("  ✓ All identical (reproducible)")
println()

println("Using different seeds:")
for seed_val in [100, 200, 300]
    Random.seed!(seed_val)
    p = generate_random_interior_point(center, domain_size, 4)
    println("  Seed $seed_val: $p")
end
println()

# Example 5: Statistical Distribution
println("Example 5: Statistical Distribution (1000 samples)")
println("-" * "="^79)

center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

Random.seed!(2024)
samples = [generate_random_interior_point(center, domain_size, 4) for _ in 1:1000]

# Calculate statistics per dimension
println("Center: $center")
println("Domain size: $domain_size")
println("Margin: 0.1 (default)")
println()

for i in 1:4
    values = [s[i] for s in samples]
    μ = mean(values)
    σ = std(values)
    min_val = minimum(values)
    max_val = maximum(values)

    println("Dimension $i statistics:")
    println("  Mean:     $(round(μ, digits=4)) (expected: $(center[i]))")
    println("  Std dev:  $(round(σ, digits=4))")
    println("  Range:    [$(round(min_val, digits=4)), $(round(max_val, digits=4))]")
    println("  Expected: [$(center[i] - 0.9*domain_size), $(center[i] + 0.9*domain_size)]")
    println()
end

# Example 6: Parameter Recovery Setup
println("Example 6: Complete Parameter Recovery Setup")
println("-" * "="^79)

# This shows how you would use it in a real parameter recovery experiment

# Define domain for parameter search
p_center = [1.0, 1.0, 1.0, 1.0]  # Center of search domain
domain_size = 0.8                 # ±0.8 around center
dim = 4

# Generate random true parameters
Random.seed!(2024)
p_true = generate_random_interior_point(p_center, domain_size, dim)

println("Parameter Recovery Experiment Setup:")
println("  Search domain center: $p_center")
println("  Search domain size:   $domain_size")
println("  Generated p_true:     $p_true")
println()
println("Domain bounds: [$(p_center .- domain_size), $(p_center .+ domain_size)]")
println("p_true in domain: ", all(abs.(p_true .- p_center) .<= domain_size))
println()

# Next steps would be:
# 1. Create error function with p_true
# 2. Sample the domain around p_center
# 3. Build polynomial approximation
# 4. Find critical points
# 5. Verify we can recover p_true

println("""
Next steps in parameter recovery workflow:
  1. Create error function: make_error_distance(..., p_true, ...)
  2. Sample domain: test_input(..., center=p_center, sample_range=domain_size)
  3. Build polynomial: Constructor(TR, (:one_d_for_all, degree))
  4. Find critical points: solve_polynomial_system(...)
  5. Verify recovery: check if any critical point ≈ p_true
""")

println("="^80)
println("✓ Examples complete!")
println("="^80)
