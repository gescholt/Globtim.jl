# Polynomial Sparsification Demo
# This example demonstrates the new sparsification features in Globtim

using Globtim
using DynamicPolynomials
using Printf

# Define a test function
f = x -> 1/(1 + 25*x[1]^2)  # Runge function

# Create polynomial approximation
println("1. Creating polynomial approximation...")
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
pol = Constructor(TR, 20, basis=:chebyshev)
println("   Polynomial degree: 20")
println("   Approximation L2-norm error: $(pol.nrm)")
println("   Number of coefficients: $(length(pol.coeffs))")

# Analyze sparsification options
println("\n2. Analyzing sparsification tradeoffs...")
thresholds = [1e-2, 1e-3, 1e-4, 1e-5, 1e-6]
results = analyze_sparsification_tradeoff(pol, thresholds=thresholds)

println("\n   Threshold | Non-zero | Sparsity | L2 Ratio")
println("   ---------|----------|----------|----------")
for res in results
    @printf("   %.0e   |    %2d    |  %5.1f%%  |  %6.2f%%\n", 
            res.threshold, res.new_nnz, 
            (1-res.sparsity)*100, res.l2_ratio*100)
end

# Choose a threshold and sparsify
println("\n3. Sparsifying with threshold 1e-4...")
sparse_result = sparsify_polynomial(pol, 1e-4, mode=:relative)
println("   Removed $(length(sparse_result.zeroed_indices)) coefficients")
println("   L2-norm preservation: $(round(sparse_result.l2_ratio*100, digits=2))%")

# Convert to exact monomial form
println("\n4. Converting to exact monomial basis...")
@polyvar x
mono_poly = to_exact_monomial_basis(sparse_result.polynomial, variables=[x])
println("   Monomial polynomial has $(length(monomials(mono_poly))) terms")

# Verify approximation quality
println("\n5. Verifying approximation quality...")
domain = BoxDomain(1, 1.0)
original_mono = to_exact_monomial_basis(pol, variables=[x])
quality = verify_truncation_quality(original_mono, mono_poly, domain)
println("   L2-norm ratio (sparse/original): $(round(quality.l2_ratio*100, digits=2))%")

# Test polynomial evaluation
println("\n6. Testing polynomial evaluation...")
test_points = [-0.5, 0.0, 0.5]
println("   x     | f(x)    | p(x)    | Error")
println("   ------|---------|---------|--------")
for pt in test_points
    f_val = f([pt])
    p_val = mono_poly(pt)
    error = abs(f_val - p_val)
    @printf("   %5.2f | %7.4f | %7.4f | %.2e\n", pt, f_val, p_val, error)
end

# Summary
println("\n7. Summary:")
println("   - Original polynomial: $(length(pol.coeffs)) coefficients")
println("   - Sparse polynomial: $(sparse_result.new_nnz) non-zero coefficients")
println("   - Sparsity achieved: $(round((1-sparse_result.sparsity)*100))%")
println("   - L2-norm preserved: $(round(sparse_result.l2_ratio*100, digits=1))%")
println("   - Memory reduction: $(round((1-sparse_result.new_nnz/length(pol.coeffs))*100))%")