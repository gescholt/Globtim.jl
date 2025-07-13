# polynomial_display_example.jl
# Example usage of polynomial display utilities

# Load required packages
using Globtim
using ExactCoefficients
using DynamicPolynomials

# Include display utilities
include("polynomial_display_utils.jl")

# Create a simple 2D polynomial example
function create_example_polynomial()
    # Define test function (Deuflhard)
    f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)
    
    # Create test input
    TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)
    
    # Create polynomial approximation of degree 5
    pol = Globtim.Constructor(TR, 5, basis=:chebyshev)
    
    return pol
end

# Example 1: Basic display comparison
println("EXAMPLE 1: Basic Polynomial Display")
println("-"^70)
pol = create_example_polynomial()
display_polynomial_comparison(pol, max_terms=15)

# Example 2: Truncation analysis
println("\n\n")
println("EXAMPLE 2: Truncation Effect Analysis")
println("-"^70)

# Try different thresholds
thresholds = [1e-4, 1e-6, 1e-8]
for thresh in thresholds
    stats = analyze_truncation_effect(pol, thresh)
end

# Example 3: Show just tensorized form
println("\n\n")
println("EXAMPLE 3: Tensorized Form Only")
println("-"^70)
display_tensorized_form(pol)

# Example 4: Higher degree polynomial
println("\n\n")
println("EXAMPLE 4: Higher Degree Polynomial (degree 10)")
println("-"^70)
f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)
TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)
pol_high = Globtim.Constructor(TR, 10, basis=:chebyshev)

println("Tensorized form statistics:")
println("   Total coefficients: $(length(pol_high.coeffs))")
println("   Non-zero coefficients: $(count(!iszero, pol_high.coeffs))")

# Convert and count monomials
poly_mono = convert_to_monomial_exact(pol_high)
println("\nMonomial form statistics:")
println("   Total monomials: $(count_monomial_support(poly_mono))")

# Example 5: Specific term inspection
println("\n\n")
println("EXAMPLE 5: Inspecting Specific Terms")
println("-"^70)

# Find the largest coefficients in tensorized form
coeffs_abs = abs.(pol.coeffs)
sorted_indices = sortperm(coeffs_abs, rev=true)

println("Top 5 largest coefficients in tensorized form:")
for i in 1:min(5, length(sorted_indices))
    idx = sorted_indices[i]
    if !iszero(pol.coeffs[idx])
        multi_idx = pol.support[idx]
        term_str = format_tensorized_term(pol.coeffs[idx], multi_idx, pol.basis)
        println("   $term_str")
    end
end