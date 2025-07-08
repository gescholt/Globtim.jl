"""
Test script to verify critical point table generation and plotting.
This script tests the new functionality without running the full analysis.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using DataFrames, CSV
using CairoMakie

# Include necessary modules
include("src/CriticalPointTables.jl")
include("src/TheoreticalPoints.jl")
include("src/SubdomainManagement.jl")
using .CriticalPointTables
using .TheoreticalPoints: load_theoretical_4d_points_orthant
using .SubdomainManagement: generate_16_subdivisions_orthant

println("🧪 Testing Critical Point Table Generation")
println("="^60)

# Load theoretical data
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
subdomains = generate_16_subdivisions_orthant()

println("✓ Loaded $(length(theoretical_points)) theoretical points")
println("✓ Generated $(length(subdomains)) subdomains")

# Create mock computed points data for testing
# Simulate results for degrees 2, 3, 4
test_degrees = [2, 3, 4]
all_critical_points_with_labels = Dict{Int, DataFrame}()

# For degree 2: Few points recovered
all_critical_points_with_labels[2] = DataFrame(
    x1 = [0.5, -0.5, 0.5],
    x2 = [0.5, 0.5, -0.5],
    x3 = [0.5, 0.5, 0.5],
    x4 = [0.5, 0.5, 0.5],
    subdomain = ["1111", "0111", "1011"],
    type = ["min", "min", "saddle"]
)

# For degree 3: More points recovered
all_critical_points_with_labels[3] = DataFrame(
    x1 = [0.5, -0.5, 0.5, -0.5, 0.0],
    x2 = [0.5, 0.5, -0.5, -0.5, 0.0],
    x3 = [0.5, 0.5, 0.5, -0.5, 0.0],
    x4 = [0.5, 0.5, 0.5, -0.5, 0.0],
    subdomain = ["1111", "0111", "1011", "0001", "0000"],
    type = ["min", "min", "saddle", "min", "saddle"]
)

# For degree 4: Even more points
all_critical_points_with_labels[4] = DataFrame(
    x1 = [0.5, -0.5, 0.5, -0.5, 0.0, 0.25, -0.25],
    x2 = [0.5, 0.5, -0.5, -0.5, 0.0, 0.25, -0.25],
    x3 = [0.5, 0.5, 0.5, -0.5, 0.0, 0.25, -0.25],
    x4 = [0.5, 0.5, 0.5, -0.5, 0.0, 0.25, -0.25],
    subdomain = ["1111", "0111", "1011", "0001", "0000", "1111", "0001"],
    type = ["min", "min", "saddle", "min", "saddle", "min", "saddle"]
)

# Generate tables
println("\n📋 Generating subdomain tables...")
subdomain_tables = generate_subdomain_critical_point_tables(
    theoretical_points, 
    theoretical_types,
    all_critical_points_with_labels,
    test_degrees,
    subdomains,
    tolerance = 0.0
)

println("✓ Generated tables for $(length(subdomain_tables)) subdomains")

# Display sample table
if !isempty(subdomain_tables)
    first_label = sort(collect(keys(subdomain_tables)))[1]
    println("\n📊 Sample table for subdomain $first_label:")
    display(subdomain_tables[first_label])
end

# Export tables
test_output_dir = joinpath(@__DIR__, "test_outputs", "critical_point_tables")
export_tables_to_csv(subdomain_tables, test_output_dir)

# Generate summary
summary_table = create_summary_table(subdomain_tables, test_degrees)
println("\n📈 Summary Table:")
display(summary_table)

# Test plotting with table data
println("\n🎨 Testing plot generation with table data...")

# Create a mock distance matrix (not used when tables provided)
n_theory = length(theoretical_points)
distance_matrix = fill(Inf, n_theory, length(test_degrees))

# Load plotting functions
include("examples/analyze_critical_point_distance_matrix.jl")

# Create plot using table data
plot_output = joinpath(test_output_dir, "test_subdomain_evolution.png")
plot_subdomain_distance_evolution(
    distance_matrix, 
    test_degrees, 
    CSV.read(joinpath(@__DIR__, "data/4d_all_critical_points_orthant.csv"), DataFrame),
    all_critical_points_with_labels,
    output_file = plot_output,
    subdomain_tables = subdomain_tables
)

println("\n✅ Test completed successfully!")
println("   Tables saved to: $(basename(test_output_dir))")
println("   Plot saved to: $(basename(plot_output))")