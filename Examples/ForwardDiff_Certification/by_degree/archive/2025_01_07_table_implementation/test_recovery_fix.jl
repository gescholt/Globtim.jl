# Test script to verify the recovery statistics fix

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

include("examples/degree_convergence_analysis_enhanced_v3.jl")

println("🧪 Testing recovery fix with degree 4...")

# Run analysis for just degree 4 to test
summary_df, distance_data = run_enhanced_analysis_v2(
    [4],  # Just test degree 4
    16,   # GN = 16
    output_dir = joinpath(@__DIR__, "outputs", "test_recovery_fix"),
    threshold = 0.1,
    analyze_global = false
)

# Read the recovery CSV
recovery_df = CSV.read(joinpath(@__DIR__, "outputs", "test_recovery_fix", "recovery_degree_4.csv"), DataFrame)

println("\n📊 Recovery results for degree 4:")
println(recovery_df)

# Check statistics
n_subdomains_with_minimizer = sum(recovery_df.has_minimizer)
n_found = sum(recovery_df.found_minimizer)
n_correct_accuracy = sum((recovery_df.has_minimizer .& recovery_df.found_minimizer .& (recovery_df.accuracy .== 100.0)) .|
                        (recovery_df.has_minimizer .& .!recovery_df.found_minimizer .& (recovery_df.accuracy .== 0.0)) .|
                        (.!recovery_df.has_minimizer .& (recovery_df.computed_points .== 0) .& (recovery_df.accuracy .== 100.0)) .|
                        (.!recovery_df.has_minimizer .& (recovery_df.computed_points .> 0) .& (recovery_df.accuracy .== 0.0)))

println("\n✅ Summary:")
println("  Subdomains with minimizers: $n_subdomains_with_minimizer")
println("  Minimizers found: $n_found")
println("  Correct accuracy calculations: $n_correct_accuracy / 16")

# Show some specific examples
println("\n📍 Examples of subdomains with minimizers:")
for row in eachrow(recovery_df)
    if row.has_minimizer
        status = row.found_minimizer ? "✓ Found" : "✗ Not found"
        dist_str = isnan(row.min_distance) ? "N/A" : @sprintf("%.4f", row.min_distance)
        println("  $(row.subdomain): $status (dist=$dist_str, accuracy=$(row.accuracy)%)")
    end
end