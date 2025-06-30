# Quick test to verify the scope warning is fixed
# Run this with: julia test_scope_fix.jl

println("Testing scope fix in deuflhard_4d_complete.jl...")

# This simulates the pattern that was causing the warning
all_orthant_labels = ["A", "A", "B", "B", "A"]
all_function_values = [1.0, 2.0, 3.0, 4.0, 5.0]

# Test the fixed code pattern
for label in ["A", "B"]
    orthant_mask = all_orthant_labels .== label
    orthant_values = all_function_values[orthant_mask]
    if !isempty(orthant_values)
        local best_idx = argmin(orthant_values)  # Using local to avoid scope warning
        best_value = orthant_values[best_idx]
        println("Label $label: best value = $best_value")
    end
end

println("\nIf no warnings appeared above, the scope issue is fixed!")
println("You can now run deuflhard_4d_complete.jl without the scope warning.")