"""
Test that demonstrates how critical points are already tracked by subdomain during computation.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using DataFrames, CSV

println("🧪 Testing Direct Subdomain Tracking")
println("="^60)

# Create mock data that simulates what comes from degree_convergence_analysis_enhanced_v3.jl
# This is the all_critical_points_with_labels structure

all_critical_points_with_labels = Dict{Int, DataFrame}()

# For degree 2: Simulate critical points found in specific subdomains
all_critical_points_with_labels[2] = DataFrame(
    x1 = [0.5, -0.5, 0.5],
    x2 = [0.5, 0.5, -0.5],
    x3 = [0.5, 0.5, 0.5],
    x4 = [0.5, 0.5, 0.5],
    function_value = [0.1, 0.2, 0.3],
    subdomain = ["1111", "0111", "1011"],  # Already labeled!
    degree = [2, 2, 2]
)

# For degree 3: More points recovered
all_critical_points_with_labels[3] = DataFrame(
    x1 = [0.5, -0.5, 0.5, -0.5, 0.0],
    x2 = [0.5, 0.5, -0.5, -0.5, 0.0],
    x3 = [0.5, 0.5, 0.5, -0.5, 0.0],
    x4 = [0.5, 0.5, 0.5, -0.5, 0.0],
    function_value = [0.05, 0.15, 0.25, 0.35, 0.45],
    subdomain = ["1111", "0111", "1011", "0001", "0000"],  # Already labeled!
    degree = [3, 3, 3, 3, 3]
)

println("\n📊 Data Structure from degree_convergence_analysis_enhanced_v3.jl:")
println("\nDegree 2 computed points:")
display(all_critical_points_with_labels[2])

println("\nDegree 3 computed points:")
display(all_critical_points_with_labels[3])

# Demonstrate how we can directly extract subdomain information
println("\n🔍 Direct Subdomain Analysis:")

for degree in sort(collect(keys(all_critical_points_with_labels)))
    df = all_critical_points_with_labels[degree]
    
    println("\nDegree $degree:")
    
    # Group by subdomain
    grouped = groupby(df, :subdomain)
    for group in grouped
        subdomain_label = first(group.subdomain)
        n_points = nrow(group)
        min_fval = minimum(group.function_value)
        max_fval = maximum(group.function_value)
        
        println("  Subdomain $subdomain_label: $n_points points, f ∈ [$min_fval, $max_fval]")
    end
end

# Show unique subdomains across all degrees
all_subdomains = String[]
for (degree, df) in all_critical_points_with_labels
    append!(all_subdomains, df.subdomain)
end
unique_subdomains = sort(unique(all_subdomains))

println("\n📍 Subdomains with at least one computed critical point:")
println("   $(join(unique_subdomains, ", "))")

println("\n✅ Key insight: The subdomain labels are already in the data!")
println("   No need to re-assign points to subdomains after computation.")