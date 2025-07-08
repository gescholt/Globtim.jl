#!/usr/bin/env julia

# Check distribution of computed critical points across subdomains

println("Checking which subdomains have computed critical points...\n")

# Simulate what run_all_examples.jl does for degree 3
degrees = [3, 4]

# Create mock data structure similar to all_critical_points_with_labels
# This would normally come from the computation
println("Based on the output 'Subdomains with computed critical points by degree:'")
println("Degree 3: 0000, 0001, 0010, 0011, 0100, 0101, 0110, 0111, 1000, 1001, 1010, 1011, 1100, 1101, 1110, 1111")
println("Degree 4: 0000, 0001, 0010, 0011, 0100, 0101, 0110, 0111, 1000, 1001, 1010, 1011, 1100, 1101, 1110, 1111")

println("\nALL 16 subdomains have computed points!")

println("\nBut theoretical points exist only in these 9 subdomains:")
theory_subdomains = ["0000", "0010", "0011", "1000", "1010", "1011", "1100", "1110", "1111"]
for sd in theory_subdomains
    println("  - $sd")
end

println("\n❗ The issue is:")
println("- subdomain_tables only creates entries for the 9 subdomains with theoretical points")
println("- Of those 9, only 3 (0000, 0010, 0011) are getting valid distance values")
println("- The other 6 subdomains have tables but all distances are NaN")

println("\n🔍 This suggests that for subdomains like 1010 (which has 9 theoretical points):")
println("   The computed points might be too far away from theoretical points")
println("   OR there's an issue with the distance calculation")