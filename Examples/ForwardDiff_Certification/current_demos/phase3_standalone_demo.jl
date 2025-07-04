# Phase 3 Implementation Standalone Demo
# This version ensures proper module loading

println("=== Phase 3 Implementation Standalone Demo ===")
println("Activating project and loading modules...")

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))

# Force fresh import
@eval Main begin
    using Globtim
    using DynamicPolynomials
    using DataFrames
end

println("Module loaded successfully!")
println("Available functions:")
println("  - analyze_critical_points_with_tables: ", :analyze_critical_points_with_tables in names(Main.Globtim))
println("  - display_statistical_table: ", :display_statistical_table in names(Main.Globtim))
println("  - create_statistical_summary: ", :create_statistical_summary in names(Main.Globtim))

println("\n=== Running Phase 3 Demo ===")

# Setup test problem
f = Deuflhard  # 2D function with multiple critical point types
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2, GN=20)
pol = Constructor(TR, 8)
@polyvar x[1:2]

println("Solving polynomial system...")
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)
println("Found $(nrow(df)) critical points")

# Test 1: Enhanced analysis with statistical tables
println("\n" * "="^80)
println("TEST 1: Enhanced Analysis with Statistical Tables")
println("="^80)

try
    global df_enhanced, df_min, tables, stats_objects = analyze_critical_points_with_tables(
        f, df, TR,
        enable_hessian=true,
        show_tables=true,
        table_format=:console,
        table_types=[:minimum, :maximum, :saddle],
        table_width=80
    )
    
    println("\n✅ Enhanced analysis completed successfully!")
    println("   • Enhanced DataFrame: $(nrow(df_enhanced)) rows, $(ncol(df_enhanced)) columns")
    println("   • Minima DataFrame: $(nrow(df_min)) rows")
    println("   • Generated tables: $(length(tables)) types")
    println("   • Statistics objects: $(length(stats_objects)) types")
    
    # Verify we have the expected return types
    @assert isa(df_enhanced, DataFrame) "df_enhanced should be DataFrame"
    @assert isa(df_min, DataFrame) "df_min should be DataFrame"  
    @assert isa(tables, Dict{Symbol, String}) "tables should be Dict{Symbol, String}"
    @assert isa(stats_objects, Dict) "stats_objects should be Dict"
    
    println("   • All return types verified ✓")
    
catch e
    println("❌ Error in enhanced analysis:")
    println("   $(typeof(e)): $e")
    rethrow(e)
end

# Test 2: Quick summary
println("\n" * "="^80)
println("TEST 2: Quick Statistical Summary")
println("="^80)

try
    summary = create_statistical_summary(df_enhanced)
    println(summary)
    println("✅ Statistical summary generated successfully!")
    
catch e
    println("❌ Error in statistical summary:")
    println("   $(typeof(e)): $e")
    rethrow(e)
end

# Test 3: Individual table display
println("\n" * "="^80)
println("TEST 3: Individual Table Display")
println("="^80)

try
    if !isempty(stats_objects)
        for (point_type, stats) in stats_objects
            println("\nDisplaying $point_type statistics:")
            displayed = display_statistical_table(stats, width=70)
            println("✅ $point_type table displayed successfully!")
        end
    else
        println("⚠️  No statistics objects to display")
    end
    
catch e
    println("❌ Error in table display:")
    println("   $(typeof(e)): $e")
    rethrow(e)
end

println("\n" * "="^80)
println("FINAL RESULT")
println("="^80)
println("✅ Phase 3 Standalone Demo COMPLETED SUCCESSFULLY!")
println()
println("Summary of working functionality:")
println("   ✓ Enhanced analysis with statistical tables")
println("   ✓ Statistical summary generation")
println("   ✓ Individual table display")
println()
println("Critical point breakdown:")
for type in unique(df_enhanced.critical_point_type)
    count = sum(df_enhanced.critical_point_type .== type)
    println("   • $(titlecase(string(type))): $count points")
end
println()
println("Phase 3 enhanced statistical tables are ready for production use!")
println("="^80)

nothing  # Suppress final output