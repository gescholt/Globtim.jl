"""
Simple test to verify critical point table generation works correctly.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using DataFrames, CSV

# Test 1: Load modules in correct order
println("Test 1: Loading modules...")

# First load SubdomainManagement (as done in analyze_critical_point_distance_matrix.jl)
include("src/SubdomainManagement.jl")
using .SubdomainManagement: generate_16_subdivisions_orthant, Subdomain

# Then load other modules
include("src/TheoreticalPoints.jl")
include("src/CriticalPointTables.jl")

using .TheoreticalPoints: load_theoretical_4d_points_orthant
using .CriticalPointTables: generate_subdomain_critical_point_tables

println("✓ Modules loaded successfully")

# Test 2: Generate tables with minimal data
println("\nTest 2: Generating tables...")

theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
subdomains = generate_16_subdivisions_orthant()

# Create minimal test data
test_degrees = [2, 3]
all_critical_points_with_labels = Dict{Int, DataFrame}()

all_critical_points_with_labels[2] = DataFrame(
    x1 = [0.5],
    x2 = [0.5],
    x3 = [0.5],
    x4 = [0.5],
    subdomain = ["1111"],
    type = ["min"]
)

all_critical_points_with_labels[3] = DataFrame(
    x1 = [0.5, -0.5],
    x2 = [0.5, 0.5],
    x3 = [0.5, 0.5],
    x4 = [0.5, 0.5],
    subdomain = ["1111", "0111"],
    type = ["min", "min"]
)

# Generate tables
subdomain_tables = generate_subdomain_critical_point_tables(
    theoretical_points, 
    theoretical_types,
    all_critical_points_with_labels,
    test_degrees,
    subdomains,
    tolerance = 0.0
)

println("✓ Generated tables for $(length(subdomain_tables)) subdomains")

# Test 3: Display a sample table
if !isempty(subdomain_tables)
    first_label = sort(collect(keys(subdomain_tables)))[1]
    println("\nTest 3: Sample table for subdomain $first_label:")
    display(subdomain_tables[first_label])
end

println("\n✅ All tests passed!")