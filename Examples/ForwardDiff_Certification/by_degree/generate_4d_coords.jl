# ================================================================================
# CRITICAL 4D COORDINATE GENERATION FROM 2D DEUFLHARD DATA
# ================================================================================
# 
# **IMPORTANT**: This file generates 4D critical points from 2D tensor products
# and filters for minimizers in the (+,-,+,-) orthant domain.
#
# Purpose:
# - Read 2D critical points from CSV
# - Generate all 4D tensor product combinations (5×5 = 25 points)
# - Filter for domain [0,1.1] × [-1.1,0] × [0,1.1] × [-1.1,0]
# - Extract minimizers (min+min combinations only)
#
# Output: 4D minimizer coordinates for subdomain analysis
# ================================================================================

using CSV
using DataFrames

df_2d = CSV.read("points_deufl/2d_coords.csv", DataFrame)
points_4d = []

for i in 1:nrow(df_2d)
    for j in 1:nrow(df_2d)
        label1 = df_2d.label[i]
        label2 = df_2d.label[j]
        
        combined_label = "$(label1)+$(label2)"
        is_minimizer = (label1 == "min" && label2 == "min")
        
        push!(points_4d, (
            x1 = df_2d.x[i], x2 = df_2d.y[i], x3 = df_2d.x[j], x4 = df_2d.y[j],
            combined_label = combined_label,
            is_minimizer = is_minimizer
        ))
    end
end

df_4d_full = DataFrame(
    x1 = [p.x1 for p in points_4d],
    x2 = [p.x2 for p in points_4d],
    x3 = [p.x3 for p in points_4d],
    x4 = [p.x4 for p in points_4d],
    combined_label = [p.combined_label for p in points_4d],
    is_minimizer = [p.is_minimizer for p in points_4d]
)

function domain_mask(df)
    return (df.x1 .>= 0.0) .& (df.x1 .<= 1.1) .& 
           (df.x2 .>= -1.1) .& (df.x2 .<= 0.0) .&
           (df.x3 .>= 0.0) .& (df.x3 .<= 1.1) .& 
           (df.x4 .>= -1.1) .& (df.x4 .<= 0.0)
end

mask = domain_mask(df_4d_full)


df_min_min = df_4d_full[df_4d_full.is_minimizer, :]
mask_min_min_domain = domain_mask(df_min_min)

println(df_min_min[mask_min_min_domain, :])

# SAVE CRITICAL RESULTS
# CSV.write("points_deufl/4d_coords_full.csv", df_4d_full)
# CSV.write("points_deufl/4d_min_min_pairs.csv", df_min_min)
CSV.write("points_deufl/4d_min_min_domain.csv", df_min_min[mask_min_min_domain, :])
