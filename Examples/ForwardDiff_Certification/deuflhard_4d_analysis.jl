# ================================================================================
# 4D Deuflhard Critical Point Analysis
# ================================================================================
# 
# PURPOSE:
# This example demonstrates comprehensive analysis of the 4D composite Deuflhard function:
# f(x1,x2,x3,x4) = Deuflhard(x1,x2) + Deuflhard(x3,x4)
# 
# MATHEMATICAL BACKGROUND:
# - The 2D Deuflhard function: f(x,y) = (e^(x²+y²) - 3)² + (x+y-sin(3(x+y)))²
# - The 4D composite is additively separable into two 2D components
# - Critical points of the 4D function should be tensor products of 2D critical points
# - This provides a rigorous test case for polynomial approximation methods
# 
# ANALYSIS WORKFLOW:
# 1) GROUND TRUTH: Load verified 2D Deuflhard critical points from CSV
# 2) THEORETICAL PREDICTION: Generate expected 4D critical points via tensor products
# 3) POLYNOMIAL APPROXIMATION: Use Globtim to find 4D critical points numerically  
# 4) VERIFICATION: Compare found points against theoretical predictions
# 5) SUMMARY: Present results in clean tabular format
# 
# DEBUG NOTES:
# - Each major section has clear markers for easy navigation
# - Function definitions include purpose and parameter descriptions
# - Intermediate results are displayed for verification at each step
# - Distance computations use Euclidean norm in 4D space

# Proper initialization for examples
using Pkg
# using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials
import IterTools

# Explicitly import DataFrames functions to avoid conflicts
import DataFrames: combine, groupby

# ================================================================================
# CONFIGURATION PARAMETERS - ADJUST THESE FOR EXPERIMENTATION
# ================================================================================

# 4D POLYNOMIAL APPROXIMATION PARAMETERS
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        # Domain center point
const SAMPLE_RANGE_4D = 1.2                    # Sampling radius around center
const L2_TOLERANCE = 20.                       # L²-norm tolerance for degree selection
const POLYNOMIAL_DEGREE = 8                  # Polynomial degree to use
const NUM_SAMPLES = 25                        # Number of samples per dimension

# ANALYSIS PARAMETERS
const VALUE_TOLERANCE = 0.1                   # Function value range for local minimizers
const DISTANCE_TOLERANCE = 0.1                # Distance threshold for point matching
const COORDINATE_PAIR_TOLERANCE = 0.05        # Tolerance for coordinate pair matching
const HESSIAN_TOLERANCE = 1e-8                # Tolerance for Hessian eigenvalue analysis
const CLUSTER_TOLERANCE = 0.025               # Distance tolerance for clustering

# OUTPUT PARAMETERS
const MAX_DETAILED_POINTS = 36                 # Max points to show in detailed output
const DECIMAL_PRECISION = 4                   # Decimal places for coordinate display
const FUNCTION_VALUE_PRECISION = 8            # Decimal places for function values
const SCIENTIFIC_NOTATION_THRESHOLD = 1e-6    # Threshold for scientific notation

# FILE PATHS
const CSV_PATH = joinpath(@__DIR__, "../../data/matlab_critical_points/valid_points_deuflhard.csv")

# ================================================================================
# EXECUTION START
# ================================================================================
println("=== 4D Deuflhard Critical Point Analysis ===\n")

# ================================================================================
# STEP 1: GROUND TRUTH DATA LOADING
# ================================================================================
# Purpose: Load verified 2D Deuflhard critical points from MATLAB/CSV data
# This provides the ground truth for validating our 4D tensor product predictions
println("Step 1: Loading 2D Deuflhard critical points from CSV...")
df_2d_critical = CSV.read(CSV_PATH, DataFrame)

println("Number of 2D critical points: $(nrow(df_2d_critical))")

# ================================================================================
# STEP 1.1: CLASSIFY 2D CRITICAL POINTS
# ================================================================================
# Purpose: Use Hessian eigenvalue analysis to classify each 2D critical point
# Classification rules:
# - Minimum: both eigenvalues > 0 (positive definite Hessian)
# - Maximum: both eigenvalues < 0 (negative definite Hessian)  
# - Saddle: mixed signs (indefinite Hessian)
# - Degenerate: eigenvalues near zero (numerical issues)
println("\nClassifying 2D critical points using Hessian analysis...")

function classify_2d_critical_points(df_2d::DataFrame)
    """
    Classify 2D critical points using Hessian eigenvalue analysis
    
    Args:
        df_2d: DataFrame with columns x, y containing critical point coordinates
        
    Returns:
        DataFrame with added classification columns:
        - critical_point_type: :minimum, :maximum, :saddle, or :degenerate
        - function_value: Deuflhard function value at the point
        - hessian_determinant, hessian_trace: Hessian matrix properties
    """
    
    n_points = nrow(df_2d)
    classifications = Symbol[]
    function_values = Float64[]
    hessian_determinants = Float64[]
    hessian_traces = Float64[]
    
    for i in 1:n_points
        point = [df_2d.x[i], df_2d.y[i]]
        
        # Compute function value
        f_val = Deuflhard(point)
        push!(function_values, f_val)
        
        # Compute Hessian using ForwardDiff
        hessian = ForwardDiff.hessian(Deuflhard, point)
        det_h = det(hessian)
        trace_h = tr(hessian)
        
        push!(hessian_determinants, det_h)
        push!(hessian_traces, trace_h)
        
        # Classify based on Hessian eigenvalues
        eigenvals = eigvals(hessian)
        λ1, λ2 = eigenvals[1], eigenvals[2]
        
        tol = HESSIAN_TOLERANCE
        if λ1 > tol && λ2 > tol
            classification = :minimum
        elseif λ1 < -tol && λ2 < -tol
            classification = :maximum
        elseif (λ1 > tol && λ2 < -tol) || (λ1 < -tol && λ2 > tol)
            classification = :saddle
        else
            classification = :degenerate
        end
        
        push!(classifications, classification)
        
        # Classification computed (detailed output suppressed)
    end
    
    # Add classification columns to DataFrame
    df_classified = copy(df_2d)
    df_classified.critical_point_type = classifications
    df_classified.function_value = function_values
    df_classified.hessian_determinant = hessian_determinants
    df_classified.hessian_trace = hessian_traces
    
    return df_classified
end

df_2d_classified = classify_2d_critical_points(df_2d_critical)

# Display classification summary
println("\n2D Critical Point Classification Summary:")
classification_counts_2d = combine(groupby(df_2d_classified, :critical_point_type), nrow => :count)
for row in eachrow(classification_counts_2d)
    println("  • $(row.critical_point_type): $(row.count) points")
end

# Identify the global minimum and local minima
minima_2d = df_2d_classified[df_2d_classified.critical_point_type .== :minimum, :]
if nrow(minima_2d) > 0
    sort!(minima_2d, :function_value)
    println("\n2D Local Minima (sorted by function value):")
    for i in 1:nrow(minima_2d)
        coords = [minima_2d.x[i], minima_2d.y[i]]
        f_val = minima_2d.function_value[i]
        is_global = i == 1 ? " (GLOBAL)" : ""
        coord_str = join([string(round(c, digits=DECIMAL_PRECISION)) for c in coords], ", ")
        # Use scientific notation for very small values to show actual precision
        f_val_str = abs(f_val) < SCIENTIFIC_NOTATION_THRESHOLD ? @sprintf("%.3e", f_val) : string(round(f_val, digits=FUNCTION_VALUE_PRECISION))
        println("  $i. f($coord_str) = $f_val_str$is_global")
    end
end

# ================================================================================
# STEP 2: THEORETICAL PREDICTION VIA TENSOR PRODUCTS
# ================================================================================
# Purpose: Generate expected 4D critical points from 2D critical point combinations
# Mathematical foundation: For additive functions f(x1,x2,x3,x4) = g(x1,x2) + h(x3,x4),
# critical points are tensor products: (a,b,c,d) where (a,b) and (c,d) are critical 
# points of g and h respectively.

function create_4d_tensor_product(df_2d::DataFrame)
    """
    Create tensor product of 2D critical points to generate expected 4D critical points
    
    Args:
        df_2d: DataFrame containing 2D critical points with columns x, y
        
    Returns:
        DataFrame with all combinations (x1,x2,x3,x4) where:
        - (x1,x2) comes from one 2D critical point
        - (x3,x4) comes from another 2D critical point
        
    Note: For n 2D points, this generates n² 4D points
    """
    n = nrow(df_2d)
    pairs = collect(IterTools.product(1:n, 1:n))
    
    # Create 4D points: (x1,x2) from first point, (x3,x4) from second point
    x1 = vec([df_2d.x[j[1]] for j in pairs])
    x2 = vec([df_2d.y[j[1]] for j in pairs])  # Note: y column from CSV becomes x2
    x3 = vec([df_2d.x[j[2]] for j in pairs])
    x4 = vec([df_2d.y[j[2]] for j in pairs])  # Note: y column from CSV becomes x4
    
    return DataFrame(x1=x1, x2=x2, x3=x3, x4=x4)
end

df_4d_expected = create_4d_tensor_product(df_2d_classified)
println("\nTotal expected 4D points: $(nrow(df_4d_expected))")

# Predict 4D critical point types based on 2D types
function predict_4d_types(df_4d::DataFrame, df_2d_classified::DataFrame)
    """Predict 4D critical point types based on 2D tensor product rules"""
    
    predicted_types = Symbol[]
    predicted_function_values = Float64[]
    
    n_2d = nrow(df_2d_classified)
    
    for i in 1:nrow(df_4d)
        # Find which 2D points contributed to this 4D point
        # The tensor product creates combinations in order
        idx1 = ((i-1) ÷ n_2d) + 1
        idx2 = ((i-1) % n_2d) + 1
        
        type1 = df_2d_classified.critical_point_type[idx1]
        type2 = df_2d_classified.critical_point_type[idx2]
        f_val1 = df_2d_classified.function_value[idx1]
        f_val2 = df_2d_classified.function_value[idx2]
        
        # Predict 4D type: 4D minimum only if both 2D parts are minima
        if type1 == :minimum && type2 == :minimum
            predicted_type = :minimum
        elseif type1 == :maximum && type2 == :maximum
            predicted_type = :maximum
        else
            predicted_type = :saddle  # Mixed types create saddle points
        end
        
        predicted_f_val = f_val1 + f_val2  # Function is additive
        
        push!(predicted_types, predicted_type)
        push!(predicted_function_values, predicted_f_val)
    end
    
    # Add predictions to DataFrame
    df_predicted = copy(df_4d)
    df_predicted.predicted_type = predicted_types
    df_predicted.predicted_function_value = predicted_function_values
    
    return df_predicted
end

df_4d_predicted = predict_4d_types(df_4d_expected, df_2d_classified)

# Prediction summary computed

# Show expected 4D minima as table
predicted_minima_4d = df_4d_predicted[df_4d_predicted.predicted_type .== :minimum, :]
if nrow(predicted_minima_4d) > 0
    sort!(predicted_minima_4d, :predicted_function_value)
    println("\n=== Expected 4D Local Minima (from tensor products of 2D minima) ===")
    
    # Create display table for minima
    n_display = min(10, nrow(predicted_minima_4d))
    minima_table = DataFrame(
        Index = 1:n_display,
        x1 = round.(predicted_minima_4d.x1[1:n_display], digits=DECIMAL_PRECISION),
        x2 = round.(predicted_minima_4d.x2[1:n_display], digits=DECIMAL_PRECISION),
        x3 = round.(predicted_minima_4d.x3[1:n_display], digits=DECIMAL_PRECISION),
        x4 = round.(predicted_minima_4d.x4[1:n_display], digits=DECIMAL_PRECISION),
        Function_Value = [abs(f_val) < SCIENTIFIC_NOTATION_THRESHOLD ? 
                         parse(Float64, @sprintf("%.3e", f_val)) : 
                         round(f_val, digits=FUNCTION_VALUE_PRECISION) 
                         for f_val in predicted_minima_4d.predicted_function_value[1:n_display]],
        Type = [i == 1 ? "GLOBAL MIN" : "Local Min" for i in 1:n_display]
    )
    println(minima_table)
end

# Show expected 4D maxima as table
predicted_maxima_4d = df_4d_predicted[df_4d_predicted.predicted_type .== :maximum, :]
if nrow(predicted_maxima_4d) > 0
    sort!(predicted_maxima_4d, :predicted_function_value, rev=true)
    println("\n=== Expected 4D Local Maxima (from tensor products of 2D maxima) ===")
    
    # Create display table for maxima
    n_display = min(10, nrow(predicted_maxima_4d))
    maxima_table = DataFrame(
        Index = 1:n_display,
        x1 = round.(predicted_maxima_4d.x1[1:n_display], digits=DECIMAL_PRECISION),
        x2 = round.(predicted_maxima_4d.x2[1:n_display], digits=DECIMAL_PRECISION),
        x3 = round.(predicted_maxima_4d.x3[1:n_display], digits=DECIMAL_PRECISION),
        x4 = round.(predicted_maxima_4d.x4[1:n_display], digits=DECIMAL_PRECISION),
        Function_Value = [abs(f_val) < SCIENTIFIC_NOTATION_THRESHOLD ? 
                         parse(Float64, @sprintf("%.3e", f_val)) : 
                         round(f_val, digits=FUNCTION_VALUE_PRECISION) 
                         for f_val in predicted_maxima_4d.predicted_function_value[1:n_display]],
        Type = [i == 1 ? "GLOBAL MAX" : "Local Max" for i in 1:n_display]
    )
    println(maxima_table)
end

println("\n=== Step 2: 4D Polynomial Approximation Setup ===")

# Define the composite 4D function
function deuflhard_4d_composite(x::AbstractVector)
    """Composite 4D function: f(x1,x2,x3,x4) = Deuflhard(x1,x2) + Deuflhard(x3,x4)"""
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# STEP 3: 4D POLYNOMIAL APPROXIMATION SETUP
# ================================================================================
# Purpose: Configure and execute polynomial approximation for 4D composite function
# Uses adaptive degree selection based on L²-norm convergence criteria


# Create test input
TR_4d = test_input(deuflhard_4d_composite, 
                   dim=4,
                   center=CENTER_4D,
                   GN=NUM_SAMPLES,
                   sample_range=SAMPLE_RANGE_4D,
                   degree_max=POLYNOMIAL_DEGREE+4)

println("\n=== Phase 1: Polynomial Construction ===")

# Construct polynomial with specified degree
pol_4d = Constructor(TR_4d, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
l2_actual = pol_4d.nrm

if l2_actual >= L2_TOLERANCE
    println("⚠️  Warning: L²-norm $(round(l2_actual, digits=6)) ≥ tolerance $L2_TOLERANCE")
    println("   Consider increasing polynomial degree for better approximation")
else
    println("✓ L²-norm $(round(l2_actual, digits=6)) < tolerance $L2_TOLERANCE")
end

println("Using polynomial degree: $POLYNOMIAL_DEGREE")


# Define polynomial variables and solve
@polyvar(x[1:4])

solutions_4d = solve_polynomial_system(x, 4, POLYNOMIAL_DEGREE, pol_4d.coeffs; basis=:chebyshev)
df_polynomial_4d = process_crit_pts(solutions_4d, deuflhard_4d_composite, TR_4d)

println("Polynomial critical points found: $(nrow(df_polynomial_4d))")

# Sort by function value
sort!(df_polynomial_4d, :z, rev=false)

# Step 3: Enhanced analysis with Phase 2 Hessian classification
println("\n=== Phase 2: BFGS Refinement and Enhanced Analysis ===")
df_refined_4d, df_refined_minima_4d = analyze_critical_points(
    deuflhard_4d_composite, df_polynomial_4d, TR_4d,
    enable_hessian=true,
    hessian_tol_zero=1e-8,
    tol_dist=0.025,
    verbose=false
)


# Filter points inside the domain
function points_in_hypercube(df::DataFrame, TR)
    """Check which points are inside the hypercube domain"""
    n_dims = count(col -> startswith(string(col), "x"), names(df))
    in_cube = trues(nrow(df))
    
    for i in 1:nrow(df)
        for j in 1:n_dims
            if abs(df[i, Symbol("x$j")] - TR.center[j]) > TR.sample_range
                in_cube[i] = false
                break
            end
        end
    end
    
    return in_cube
end

function points_in_range(df::DataFrame, TR, value_range::Float64)
    """Filter points by function value range around minimum"""
    n_dims = count(col -> startswith(string(col), "x"), names(df))
    in_range = falses(nrow(df))
    min_val = minimum(df.z)
    
    for i in 1:nrow(df)
        point = [df[i, Symbol("x$j")] for j in 1:n_dims]
        val = TR.objective(point)
        if abs(val - min_val) ≤ value_range
            in_range[i] = true
        end
    end
    
    return in_range
end

# Filter refined points to domain and identify minimizers
inside_mask = points_in_hypercube(df_refined_4d, TR_4d)
df_refined_inside_4d = df_refined_4d[inside_mask, :]
sort!(df_refined_inside_4d, :z)

# Focus on local minimizers (small function values)
value_mask = points_in_range(df_refined_inside_4d, TR_4d, VALUE_TOLERANCE)
df_final_minimizers_4d = df_refined_inside_4d[value_mask, :]

println("\n=== Step 3: Local Minimizers Analysis ===")
println("Final local minimizers found: $(nrow(df_final_minimizers_4d))")

if nrow(df_final_minimizers_4d) > 0
    min_values = df_final_minimizers_4d.z
    println("Global minimum value: $(round(minimum(min_values), digits=8))")
end

# Step 4: Verify that critical points are pairs of 2D critical points
println("\n=== Step 4: Verification Against Expected Tensor Product ===")

function compute_min_distances_to_expected(df_found::DataFrame, df_expected::DataFrame)
    """Compute minimum distance from each found point to expected points and return closest indices"""
    min_distances = Float64[]
    closest_indices = Int[]
    
    for i in 1:nrow(df_found)
        found_point = [df_found[i, :x1], df_found[i, :x2], df_found[i, :x3], df_found[i, :x4]]
        min_dist = Inf
        closest_idx = 1
        
        for j in 1:nrow(df_expected)
            expected_point = [df_expected[j, :x1], df_expected[j, :x2], df_expected[j, :x3], df_expected[j, :x4]]
            dist = norm(found_point - expected_point)
            if dist < min_dist
                min_dist = dist
                closest_idx = j
            end
        end
        
        push!(min_distances, min_dist)
        push!(closest_indices, closest_idx)
    end
    
    return min_distances, closest_indices
end

# Filter expected points to domain
expected_inside_mask = points_in_hypercube(df_4d_expected, TR_4d)
df_4d_expected_inside = df_4d_expected[expected_inside_mask, :]

# Create enhanced summary table
if nrow(df_final_minimizers_4d) > 0 && nrow(predicted_minima_4d) > 0
    println("\n=== SUMMARY TABLE: Final 4D Local Minimizers (After BFGS Refinement) ===")
    
    # Compute distances to expected minima and closest indices
    distances_to_expected_minima, closest_expected_indices = compute_min_distances_to_expected(df_final_minimizers_4d, predicted_minima_4d)
    
    # Compute actual function values to ensure correctness
    actual_function_values = Float64[]
    for i in 1:nrow(df_final_minimizers_4d)
        point = [df_final_minimizers_4d.x1[i], df_final_minimizers_4d.x2[i], df_final_minimizers_4d.x3[i], df_final_minimizers_4d.x4[i]]
        f_val = deuflhard_4d_composite(point)
        push!(actual_function_values, f_val)
    end
    
    # Create clean summary DataFrame
    summary_df = DataFrame(
        Index = 1:nrow(df_final_minimizers_4d),
        x1 = round.(df_final_minimizers_4d.x1, digits=DECIMAL_PRECISION),
        x2 = round.(df_final_minimizers_4d.x2, digits=DECIMAL_PRECISION), 
        x3 = round.(df_final_minimizers_4d.x3, digits=DECIMAL_PRECISION),
        x4 = round.(df_final_minimizers_4d.x4, digits=DECIMAL_PRECISION),
        Function_Value = [abs(f_val) < SCIENTIFIC_NOTATION_THRESHOLD ? 
                         parse(Float64, @sprintf("%.3e", f_val)) : 
                         round(f_val, digits=FUNCTION_VALUE_PRECISION) for f_val in actual_function_values],
        Distance_to_Expected = round.(distances_to_expected_minima, digits=6),
        Closest_Expected_Index = closest_expected_indices
    )
    
    println("Distance threshold: $DISTANCE_TOLERANCE\n")
    println(summary_df)
    
    # Summary statistics
    close_matches = sum(distances_to_expected_minima .< DISTANCE_TOLERANCE)
    classification_counts = combine(groupby(df_refined_4d, :critical_point_type), nrow => :count)
    
    println("\n=== ANALYSIS SUMMARY ===")
    println("  • Polynomial critical points: $(nrow(df_polynomial_4d))")
    println("  • BFGS-refined critical points: $(nrow(df_refined_4d))")
    for row in eachrow(classification_counts)
        percentage = round(100 * row.count / nrow(df_refined_4d), digits=1)
        println("    - $(row.critical_point_type): $(row.count) points ($(percentage)%)")
    end
    println("  • Final local minimizers: $(nrow(summary_df))")
    println("  • Global minimum value: $(round(minimum(actual_function_values), digits=8))")
    println("  • Close matches to expected (dist < $DISTANCE_TOLERANCE): $close_matches/$(nrow(summary_df))")
    println("  • Average distance to expected: $(round(mean(distances_to_expected_minima), digits=6))")
end

println("\n=== ANALYSIS COMPLETE ===")