"""
Verify that the table generation fix works correctly.
"""

println("Testing table generation fix...")

# Test the module loading sequence as it happens in run_all_examples.jl
include("examples/analyze_critical_point_distance_matrix.jl")  # This loads SubdomainManagement

# Now load CriticalPointTables
include("src/CriticalPointTables.jl")
using .CriticalPointTables

# Load TheoreticalPoints
include("src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant
using .SubdomainManagement: generate_16_subdivisions_orthant

# Create minimal test
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
subdomains = generate_16_subdivisions_orthant()

# Minimal test data
test_degrees = [2]
all_critical_points_with_labels = Dict{Int, DataFrame}()
all_critical_points_with_labels[2] = DataFrame(
    x1 = [0.5], x2 = [0.5], x3 = [0.5], x4 = [0.5],
    subdomain = ["1111"], type = ["min"]
)

# Test table generation
subdomain_tables = generate_subdomain_critical_point_tables(
    theoretical_points, 
    theoretical_types,
    all_critical_points_with_labels,
    test_degrees,
    subdomains,
    tolerance = 0.0,
    is_point_in_subdomain_func = SubdomainManagement.is_point_in_subdomain
)

println("✅ Table generation successful!")
println("Generated tables for $(length(subdomain_tables)) subdomains")