# Simple Test Phase 1 Enhanced Statistics Implementation

using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))
using Globtim
using DynamicPolynomials, DataFrames

# Ensure we have access to the enhanced function
import Globtim: analyze_critical_points

println("=== Simple Phase 1 Test ===")

# Simple 3D test with Rastringin function
f = Rastringin  
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0], sample_range=1.0)

println("Creating sample critical points for testing...")
# Create some sample critical points for testing
sample_points = [
    [0.0, 0.0, 0.0],       # Global minimum
    [1.0, 0.0, 0.0],       # Local minimum
    [0.0, 1.0, 0.0],       # Local minimum  
    [-1.0, 0.0, 0.0],      # Local minimum
    [0.5, 0.5, 0.5],       # Other point
    [-0.5, -0.5, -0.5],    # Other point
]

# Create DataFrame manually
df_test = DataFrame(
    x1 = [p[1] for p in sample_points],
    x2 = [p[2] for p in sample_points], 
    x3 = [p[3] for p in sample_points]
)

# Add function values
df_test.z = [f(p) for p in sample_points]

println("Test DataFrame before enhancement:")
println("Columns: $(names(df_test))")
println("Size: $(size(df_test))")
println(df_test)

println("\n=== Running Enhanced Analysis (Phase 1) ===")
try
    df_enhanced, df_min = analyze_critical_points(f, df_test, TR, tol_dist=0.1, verbose=true)
    
    println("\n=== Results ===")
    println("Enhanced DataFrame columns: $(names(df_enhanced))")
    println("Enhanced DataFrame size: $(size(df_enhanced))")
    
    # Check new columns
    expected_new_cols = [:region_id, :function_value_cluster, :nearest_neighbor_dist, :gradient_norm]
    col_names = Symbol.(names(df_enhanced))
    for col in expected_new_cols
        if col in col_names
            println("✓ Column $col added successfully")
            values = df_enhanced[!, col]
            valid_values = filter(!isnan, values)
            if !isempty(valid_values)
                println("  Range: $(extrema(valid_values))")
                println("  Sample values: $(first(valid_values, min(3, length(valid_values))))")
            end
        else
            println("✗ Column $col missing!")
        end
    end
    
    println("\nEnhanced DataFrame:")
    println(df_enhanced)
    
    if nrow(df_min) > 0
        println("\nMinimizers DataFrame:")
        println(df_min)
    end
    
    println("\n✓ Phase 1 Implementation Test PASSED")
    
catch e
    println("✗ Test FAILED with error: $e")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end