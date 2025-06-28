# ================================================================================
# 4D Deuflhard Critical Point Analysis with Orthant Decomposition
# ================================================================================
# 
# PURPOSE:
# This example demonstrates analysis of the 4D composite Deuflhard function
# using domain decomposition into 16 orthants. Each orthant is analyzed separately
# and results are combined.
#
# ORTHANT STRUCTURE IN 4D:
# - 16 orthants total (2^4)
# - Each orthant defined by sign pattern: (±, ±, ±, ±)
# - Example: (+, +, -, +) means x1>0, x2>0, x3<0, x4>0
#
# WORKFLOW:
# 1) Split domain into 16 orthants
# 2) Analyze each orthant separately with appropriate bounds
# 3) Combine results and remove duplicates at boundaries
# 4) Validate against known critical points

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials
import IterTools
import DataFrames: combine, groupby

# ================================================================================
# CONFIGURATION PARAMETERS - REDUCED FOR FASTER EXECUTION
# ================================================================================

# Domain parameters
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        
const SAMPLE_RANGE_4D = 0.6                    # Further reduced for speed
const L2_TOLERANCE = 100.0                     # Increased tolerance for speed
const POLYNOMIAL_DEGREE = 5                    # Further reduced
const NUM_SAMPLES = 10                         # Minimal samples

# Analysis parameters
const VALUE_TOLERANCE = 1e-3                   # For identifying minima
const DISTANCE_TOLERANCE = 0.02                # For matching points
const DECIMAL_PRECISION = 5
const FUNCTION_VALUE_PRECISION = 6
const SCIENTIFIC_NOTATION_THRESHOLD = 1e-4

# ================================================================================
# ORTHANT STRUCTURE GENERATION
# ================================================================================

"""
Generate all 16 orthant sign patterns for 4D space
Returns array of 16 vectors, each containing ±1 for each dimension
"""
function generate_orthant_signs()
    signs = Vector{Vector{Int}}()
    for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
        push!(signs, [s1, s2, s3, s4])
    end
    return signs
end

"""
Create test_input for a specific orthant
Adjusts center and range to focus on the orthant region
"""
function create_orthant_test_input(f::Function, orthant_signs::Vector{Int}, 
                                  base_center::Vector{Float64}, base_range::Float64)
    # Shift center towards orthant
    orthant_shift = 0.3 * base_range  # Shift amount
    orthant_center = base_center .+ orthant_shift .* orthant_signs
    
    # Use slightly overlapping ranges to catch boundary points
    orthant_range = 0.6 * base_range  # Slightly larger than half to ensure overlap
    
    return test_input(f, dim=4, center=orthant_center, sample_range=orthant_range)
end

"""
Get orthant label string from sign pattern
"""
function orthant_label(signs::Vector{Int})
    chars = [s > 0 ? '+' : '-' for s in signs]
    return "(" * join(chars, ",") * ")"
end

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# ORTHANT ANALYSIS FUNCTION
# ================================================================================

"""
Analyze critical points in a single orthant
Returns DataFrame with critical points found in this orthant
"""
function analyze_orthant(orthant_signs::Vector{Int}, orthant_idx::Int, verbose::Bool=false)
    label = orthant_label(orthant_signs)
    
    if verbose
        println("\n" * "="^60)
        println("Analyzing Orthant $orthant_idx/16: $label")
        println("="^60)
    end
    
    # Create test input for this orthant
    TR_orthant = create_orthant_test_input(deuflhard_4d_composite, orthant_signs, 
                                          CENTER_4D, SAMPLE_RANGE_4D)
    
    # Construct polynomial approximation
    pol_orthant = Constructor(TR_orthant, POLYNOMIAL_DEGREE, 
                             basis=:chebyshev, 
                             verbose=false)
    
    # Get L2 norm
    l2_norm = pol_orthant.nrm
    if verbose
        println("  L²-norm: $(round(l2_norm, digits=4))")
        if l2_norm > L2_TOLERANCE
            println("  ⚠️  Warning: L²-norm exceeds tolerance")
        end
    end
    
    # Solve polynomial system
    @polyvar x[1:4]
    # Use the actual degree from the polynomial, not the requested degree
    actual_degree = pol_orthant.degree isa Tuple ? pol_orthant.degree[2] : pol_orthant.degree
    solutions = solve_polynomial_system(x, 4, actual_degree, pol_orthant.coeffs, 
                                      basis=:chebyshev)
    
    if verbose
        println("  Raw solutions found: $(length(solutions))")
    end
    
    # Process critical points
    df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR_orthant)
    
    # Add orthant information
    df_crit[!, :orthant_idx] = orthant_idx
    df_crit[!, :orthant_label] = label
    
    # Refine with BFGS (simplified version)
    df_refined, _ = analyze_critical_points(
        deuflhard_4d_composite, df_crit, TR_orthant,
        enable_hessian=false,  # Disable for speed
        tol_dist=0.025,
        verbose=false,
        max_iters_in_optim=50  # Reduced iterations
    )
    
    # Filter to points inside the full domain
    inside_mask = points_in_hypercube(df_refined, TR_orthant, use_y=true)
    df_inside = df_refined[inside_mask, :]
    
    if verbose
        println("  Critical points after refinement: $(nrow(df_inside))")
    end
    
    return df_inside
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

println("\n" * "="^80)
println("4D DEUFLHARD ANALYSIS WITH ORTHANT DECOMPOSITION")
println("="^80)

# Generate all orthant signs
orthant_signs = generate_orthant_signs()
println("\nAnalyzing $(length(orthant_signs)) orthants...")

# Analyze each orthant
all_results = DataFrame[]
for (idx, signs) in enumerate(orthant_signs)
    df_orthant = analyze_orthant(signs, idx, true)
    push!(all_results, df_orthant)
end

# Combine results from all orthants
df_combined = vcat(all_results...)
println("\n" * "="^80)
println("COMBINING RESULTS FROM ALL ORTHANTS")
println("="^80)
println("Total critical points found across all orthants: $(nrow(df_combined))")

# ================================================================================
# REMOVE DUPLICATES
# ================================================================================

"""
Remove duplicate critical points based on distance threshold
"""
function remove_duplicates(df::DataFrame, tol::Float64=DISTANCE_TOLERANCE)
    n_dims = 4
    keep_mask = trues(nrow(df))
    
    for i in 1:nrow(df)
        if !keep_mask[i]
            continue
        end
        
        point_i = [df[i, Symbol("y$j")] for j in 1:n_dims]
        
        for j in (i+1):nrow(df)
            if !keep_mask[j]
                continue
            end
            
            point_j = [df[j, Symbol("y$j")] for j in 1:n_dims]
            dist = norm(point_i - point_j)
            
            if dist < tol
                # Keep the one with better function value
                if df[i, :z] <= df[j, :z]
                    keep_mask[j] = false
                else
                    keep_mask[i] = false
                    break
                end
            end
        end
    end
    
    return df[keep_mask, :]
end

df_unique = remove_duplicates(df_combined)
println("Critical points after removing duplicates: $(nrow(df_unique))")

# Update function values for refined points
for i in 1:nrow(df_unique)
    point = [df_unique[i, Symbol("y$j")] for j in 1:4]
    df_unique[i, :z] = deuflhard_4d_composite(point)
end

# Sort by function value
sort!(df_unique, :z)

# ================================================================================
# IDENTIFY MINIMA AND MAXIMA
# ================================================================================

# Find minima
minima_mask = df_unique.z .< VALUE_TOLERANCE
df_minima = df_unique[minima_mask, :]
println("\nLocal minima found: $(nrow(df_minima))")

# Find maxima (if any)
maxima_mask = df_unique.z .> maximum(df_unique.z) - VALUE_TOLERANCE
df_maxima = df_unique[maxima_mask, :]
println("Local maxima found: $(nrow(df_maxima))")

# ================================================================================
# DISPLAY RESULTS
# ================================================================================

println("\n" * "="^80)
println("TOP 10 MINIMA FOUND")
println("="^80)

if nrow(df_minima) > 0
    n_show = min(10, nrow(df_minima))
    minima_display = DataFrame(
        Index = 1:n_show,
        x1 = round.(df_minima.y1[1:n_show], digits=DECIMAL_PRECISION),
        x2 = round.(df_minima.y2[1:n_show], digits=DECIMAL_PRECISION),
        x3 = round.(df_minima.y3[1:n_show], digits=DECIMAL_PRECISION),
        x4 = round.(df_minima.y4[1:n_show], digits=DECIMAL_PRECISION),
        Function_Value = [Printf.@sprintf("%.3e", val) for val in df_minima.z[1:n_show]],
        Orthant = df_minima.orthant_label[1:n_show],
        Type = [i == 1 ? "GLOBAL MIN" : "Local Min" for i in 1:n_show]
    )
    println(minima_display)
else
    println("No minima found below threshold $(VALUE_TOLERANCE)")
end

# ================================================================================
# ORTHANT STATISTICS
# ================================================================================

println("\n" * "="^80)
println("ORTHANT STATISTICS")
println("="^80)

# Count critical points per orthant
orthant_counts = combine(groupby(df_unique, :orthant_idx), nrow => :count)
sort!(orthant_counts, :orthant_idx)

# Create summary table
orthant_summary = DataFrame(
    Orthant = [orthant_label(orthant_signs[i]) for i in 1:16],
    Critical_Points = zeros(Int, 16),
    Minima = zeros(Int, 16)
)

for row in eachrow(orthant_counts)
    orthant_summary[row.orthant_idx, :Critical_Points] = row.count
end

# Count minima per orthant
if nrow(df_minima) > 0
    minima_counts = combine(groupby(df_minima, :orthant_idx), nrow => :minima_count)
    for row in eachrow(minima_counts)
        orthant_summary[row.orthant_idx, :Minima] = row.minima_count
    end
end

println(orthant_summary)

# ================================================================================
# VALIDATION TEST
# ================================================================================

println("\n" * "="^80)
println("VALIDATION: CHECKING KNOWN CRITICAL POINTS")
println("="^80)

# Test some known critical points
test_points = [
    ([0.0, 0.0, 0.0, 0.0], "Origin"),
    ([-0.7412, 0.7412, -0.7412, 0.7412], "Expected global minimum"),
    ([0.7412, -0.7412, 0.7412, -0.7412], "Alternative pattern")
]

for (test_point, desc) in test_points
    # Find closest point in our results
    min_dist = Inf
    closest_idx = 1
    
    for i in 1:nrow(df_unique)
        found_point = [df_unique[i, Symbol("y$j")] for j in 1:4]
        dist = norm(found_point - test_point)
        if dist < min_dist
            min_dist = dist
            closest_idx = i
        end
    end
    
    if min_dist < DISTANCE_TOLERANCE
        f_val = df_unique[closest_idx, :z]
        orthant = df_unique[closest_idx, :orthant_label]
        println("✓ $desc found in orthant $orthant")
        println("  Distance: $(Printf.@sprintf("%.3e", min_dist))")
        println("  Function value: $(Printf.@sprintf("%.3e", f_val))")
    else
        println("✗ $desc NOT found (closest distance: $(Printf.@sprintf("%.3e", min_dist)))")
    end
end

println("\n" * "="^80)
println("ANALYSIS COMPLETE")
println("="^80)