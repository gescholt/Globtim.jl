"""
Quick test to verify the string formatting fix works
"""

using Printf

println("🧪 Testing String Formatting Fix")
println("=" ^ 40)

# Test the exact code pattern from the fixed script
sample_counts = [100, 200, 300, 500]

println("\nMemory usage estimates (MB):")
header_parts = [@sprintf("%-8s", "Degree")]
for s in sample_counts
    push!(header_parts, @sprintf("%-12s", "$(s) samples"))
end
println(join(header_parts))
println("-" ^ 60)

# Test a few rows
degrees = [2, 3, 4]
for degree in degrees
    row = @sprintf("%-8d", degree)
    
    for samples in sample_counts
        # Simulate memory calculation
        memory_mb = degree^2 * samples / 10
        
        # Color coding
        if memory_mb < 100
            status = "✅"  # Safe
        elseif memory_mb < 500
            status = "⚠️ "  # Caution
        else
            status = "🚫"  # Dangerous
        end
        
        row *= @sprintf("%s%-10.0f", status, memory_mb)
    end
    println(row)
end

println("\n✅ String formatting fix successful!")
println("The OTL Circuit test should now run without errors.")
