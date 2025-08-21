"""
Fix for test_input field access issue

The test_input struct has field `GN` (not `N`) for the number of samples.
Use this code to fix any notebook cells that try to access TR.N
"""

# Quick fix function to get the number of samples from test_input
function get_sample_count(TR::test_input)
    return TR.GN
end

# Alternative: create a property accessor that maps N to GN for backward compatibility
# This would go in the main Globtim code, but for now use the function above

println("🔧 test_input field fix loaded")
println("💡 Use get_sample_count(TR) instead of TR.N")
println("   The correct field is TR.GN (Grid Number)")

# Example usage:
# TR = test_input(shubert_4d, dim=4, center=[0.0, 0.0, 0.0, 0.0], GN=100, sample_range=2.0)
# samples = get_sample_count(TR)  # Instead of TR.N
# println("Number of samples: $samples")
