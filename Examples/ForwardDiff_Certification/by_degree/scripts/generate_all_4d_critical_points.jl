#!/usr/bin/env julia
# ================================================================================
# Generate ALL 4D Critical Points from 2D Deuflhard Tensor Product
# ================================================================================
# 
# This script generates all 225 critical points (15×15) from the tensor product
# of 2D Deuflhard critical points, including minima, maxima, and saddle points.
#
# Output: CSV file with all 4D critical points in the (+,-,+,-) orthant
# ================================================================================

using CSV
using DataFrames
using Printf

# Read the 2D critical points
println("Reading 2D critical points...")
df_2d = CSV.read(joinpath(@__DIR__, "../data/2d_coords.csv"), DataFrame)
println("Found $(nrow(df_2d)) 2D critical points:")
println("  - $(sum(df_2d.label .== "min")) minima")
println("  - $(sum(df_2d.label .== "max")) maxima")  
println("  - $(sum(df_2d.label .== "saddle")) saddle points")

# Generate all 4D tensor product combinations
println("\nGenerating 4D tensor products...")
points_4d = []

for i in 1:nrow(df_2d)
    for j in 1:nrow(df_2d)
        label1 = df_2d.label[i]
        label2 = df_2d.label[j]
        
        # Determine the combined critical point type
        combined_label = "$(label1)+$(label2)"
        
        # Classify the 4D critical point type based on tensor product
        if label1 == "min" && label2 == "min"
            type_4d = "min"
        elseif label1 == "max" && label2 == "max"
            type_4d = "max"
        else
            type_4d = "saddle"  # All other combinations are saddle points
        end
        
        push!(points_4d, (
            x1 = df_2d.x[i], 
            x2 = df_2d.y[i], 
            x3 = df_2d.x[j], 
            x4 = df_2d.y[j],
            combined_label = combined_label,
            type_4d = type_4d,
            label_12 = label1,  # Critical point type in (x1,x2)
            label_34 = label2   # Critical point type in (x3,x4)
        ))
    end
end

# Create DataFrame
df_4d_all = DataFrame(
    x1 = [p.x1 for p in points_4d],
    x2 = [p.x2 for p in points_4d],
    x3 = [p.x3 for p in points_4d],
    x4 = [p.x4 for p in points_4d],
    combined_label = [p.combined_label for p in points_4d],
    type_4d = [p.type_4d for p in points_4d],
    label_12 = [p.label_12 for p in points_4d],
    label_34 = [p.label_34 for p in points_4d]
)

# Domain filter for (+,-,+,-) orthant: [0,1.1] × [-1.1,0] × [0,1.1] × [-1.1,0]
function in_target_domain(df)
    return (df.x1 .>= 0.0) .& (df.x1 .<= 1.1) .& 
           (df.x2 .>= -1.1) .& (df.x2 .<= 0.0) .&
           (df.x3 .>= 0.0) .& (df.x3 .<= 1.1) .& 
           (df.x4 .>= -1.1) .& (df.x4 .<= 0.0)
end

# Apply domain filter
mask_domain = in_target_domain(df_4d_all)
df_4d_domain = df_4d_all[mask_domain, :]

# Print statistics
println("\n📊 4D Critical Point Statistics:")
println("Total 4D points generated: $(nrow(df_4d_all))")
println("Points in target domain: $(nrow(df_4d_domain))")
println("\nBreakdown by type in domain:")
for type in ["min", "max", "saddle"]
    count = sum(df_4d_domain.type_4d .== type)
    println("  - $type: $count points")
end

# Verify we have the expected 9 minimizers
df_minimizers = df_4d_domain[df_4d_domain.type_4d .== "min", :]
println("\n✓ Found $(nrow(df_minimizers)) minimizers (expected 9)")

# Save all critical points in domain
output_file = joinpath(@__DIR__, "../data/4d_all_critical_points.csv")
CSV.write(output_file, df_4d_domain)
println("\n💾 Saved all $(nrow(df_4d_domain)) critical points to:")
println("   $output_file")

# Also save just the minimizers for comparison
minimizers_file = joinpath(@__DIR__, "../data/4d_minimizers_only.csv")
CSV.write(minimizers_file, df_minimizers)
println("\n💾 Saved $(nrow(df_minimizers)) minimizers to:")
println("   $minimizers_file")

# Display sample of the data
println("\n📋 Sample of critical points (first 10):")
show(first(df_4d_domain, 10), allcols=true)