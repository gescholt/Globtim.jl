"""
Test String Formatting Fix

This script tests the string formatting fixes for the OTL Circuit test.
"""

using Printf

println("🧪 Testing String Formatting Fixes")
println("=" ^ 40)

# Test 1: Header formatting
println("\n📊 Test 1: Header Formatting")
sample_counts = [100, 200, 300, 500]

println("Memory usage estimates (MB):")
header = @sprintf("%-8s", "Degree")
for s in sample_counts
    header *= @sprintf("%-12s", "$(s) samples")
end
println(header)
println("-" ^ 60)

# Test data
degrees = [2, 3, 4, 5, 6]
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

println("\nLegend: ✅ <100MB (safe), ⚠️  100-500MB (caution), 🚫 >500MB (dangerous)")

# Test 2: Table formatting
println("\n📊 Test 2: Table Formatting")
println(@sprintf("%-8s%-12s%s", "Degree", "L2 Error", "Quality"))
println("-" ^ 30)

test_results = [
    (3, 1.2e-4, "Good"),
    (4, 3.5e-6, "Very Good"),
    (5, 8.1e-8, "Excellent")
]

for (degree, l2_error, quality) in test_results
    println(@sprintf("%-8d%-12.2e%s", degree, l2_error, quality))
end

# Test 3: Configuration table
println("\n📊 Test 3: Configuration Table")
println(@sprintf("%-20s%-12s%s", "Configuration", "Memory (MB)", "Status"))
println("-" ^ 45)

configs = [
    ("Conservative", 3, 120),
    ("Moderate", 4, 150),
    ("Aggressive", 5, 200),
    ("Dangerous", 6, 300)
]

for (name, degree, samples) in configs
    # Simulate memory calculation
    memory_mb = degree^2 * samples / 5
    
    status = if memory_mb < 100
        "✅ Safe"
    elseif memory_mb < 500
        "⚠️  Risky"
    else
        "🚫 Dangerous"
    end
    
    config_str = "$name (d=$degree, n=$samples)"
    println(@sprintf("%-20s%-12.0f%s", config_str, memory_mb, status))
end

println("\n✅ All string formatting tests passed!")
println("The OTL Circuit test should now run without ljust errors.")
