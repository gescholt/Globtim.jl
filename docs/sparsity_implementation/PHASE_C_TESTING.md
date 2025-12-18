# Phase C: Testing & Validation

**Goal**: Comprehensive test suite for sparsity + local refinement workflow

**Timeline**: 6-8 hours

**Priority**: 🔴 HIGH - Critical for production use, explicitly requested

**Prerequisite**: Complete Option 2 (core re-optimization implementation)

---

## Overview

You specifically requested tests for **sparsity + local refinement**. This phase creates a comprehensive test suite that validates:

1. Sparsity-constrained re-optimization correctness
2. Integration with local refinement (`refining.jl`)
3. High-precision solver accuracy
4. Performance and scalability
5. Edge cases and failure modes

---

## Test File Structure

```
test/
├── test_sparse_refinement.jl          ← MAIN TEST SUITE (user request)
├── test_monomial_vandermonde.jl       ← Unit tests
├── test_sparse_monomial_optimization.jl ← Unit tests
├── test_sparsity_patterns.jl          ← Pattern analysis
├── test_high_precision_ls.jl          ← Solver tests
├── benchmarks/
│   ├── sparse_refinement_benchmarks.jl ← Performance tests
│   └── truncation_vs_reoptimization.jl ← Method comparison
└── manual/
    └── sparse_refinement_examples.jl   ← Interactive examples
```

---

## Test Suite 1: Core Sparse Refinement (test_sparse_refinement.jl)

**Purpose**: Main integration tests for sparsity + local refinement

### Test 1.1: Truncation vs Re-optimization Comparison

```julia
@testset "Truncation vs Re-optimization: Accuracy Comparison" begin
    # Test functions with different characteristics
    test_cases = [
        (name = "Sparse Polynomial",
         f = x -> x[1]^4 + x[1]^2*x[2]^2 + x[2]^4,
         dim = 2,
         degree = 8,
         threshold = 1e-6),

        (name = "Dense Expansion (Runge)",
         f = x -> 1 / (1 + 25*x[1]^2),
         dim = 1,
         degree = 20,
         threshold = 1e-4),

        (name = "Oscillatory",
         f = x -> sin(5π*x[1]) * cos(3π*x[2]),
         dim = 2,
         degree = 12,
         threshold = 1e-5),
    ]

    for tc in test_cases
        @testset "$(tc.name)" begin
            # Create approximation
            TR = test_input(tc.f, dim=tc.dim, center=zeros(tc.dim), sample_range=1.0)
            pol = Constructor(TR, tc.degree, basis=:chebyshev)

            # Method 1: Simple truncation
            result_trunc = to_exact_monomial_basis_sparse(
                pol, threshold=tc.threshold, reoptimize=false
            )

            # Method 2: Re-optimization
            result_reopt = to_exact_monomial_basis_sparse(
                pol, threshold=tc.threshold, reoptimize=true, precision=BigFloat
            )

            # Assertion 1: Re-optimization should preserve L2-norm better
            @test result_reopt.l2_ratio >= result_trunc.l2_ratio

            # Assertion 2: Same sparsity achieved
            @test result_reopt.sparsity_info.new_nnz == result_trunc.sparsity_info.new_nnz

            # Assertion 3: Point-wise error comparison
            test_points = [randn(tc.dim) for _ in 1:100]
            errors_trunc = [abs(tc.f(pt) - result_trunc.polynomial(pt)) for pt in test_points]
            errors_reopt = [abs(tc.f(pt) - result_reopt.polynomial(pt)) for pt in test_points]

            mean_error_trunc = mean(errors_trunc)
            mean_error_reopt = mean(errors_reopt)

            @test mean_error_reopt <= mean_error_trunc * 1.1  # Allow 10% tolerance

            # Log improvement
            improvement = mean_error_trunc / mean_error_reopt
            @info "$(tc.name): Re-optimization improved accuracy by $(round(improvement, digits=2))x"
        end
    end
end
```

### Test 1.2: Local Refinement with Sparsity

```julia
@testset "Local Refinement with Sparse Polynomials" begin
    # Multi-scale function: smooth background + localized features
    f(x) = sin(2π*x[1]) + sin(2π*x[2]) +
           5*exp(-50*((x[1]-0.3)^2 + (x[2]-0.5)^2)) +  # Peak 1
           3*exp(-50*((x[1]+0.5)^2 + (x[2]+0.2)^2))     # Peak 2

    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

    @testset "Global Approximation" begin
        # Global sparse approximation
        pol_global = Constructor(TR, degree=10, basis=:chebyshev)
        sparse_global = to_exact_monomial_basis_sparse(
            pol_global, threshold=1e-5, reoptimize=true
        )

        # Verify global approximation quality
        domain = BoxDomain(2, 1.0)
        l2_error = compute_approximation_error(f, pol_global, TR, n_points=30)

        @test l2_error < 1.0  # Reasonable global accuracy
        @test sparse_global.sparsity_info.new_nnz < 0.7 * length(pol_global.coeffs)
    end

    @testset "Local Refinement Around Critical Points" begin
        # Find critical points using sparse polynomial
        pol_global = Constructor(TR, degree=10, basis=:chebyshev)
        sparse_global = to_exact_monomial_basis_sparse(
            pol_global, threshold=1e-5, reoptimize=true
        )

        # Get critical points (should detect both peaks)
        # Note: This requires sparse polynomials to work with refining.jl
        critical_pts = find_critical_points_sparse(sparse_global, TR)

        # Should find at least the two peaks
        @test length(critical_pts) >= 2

        # Verify peaks are near expected locations
        expected_peaks = [[0.3, 0.5], [-0.5, 0.2]]
        for expected_peak in expected_peaks
            distances = [norm(cp - expected_peak) for cp in critical_pts]
            @test minimum(distances) < 0.2  # Found within 0.2 units
        end
    end

    @testset "Local Polynomial Refinement" begin
        # Create local refinements around each peak
        local_centers = [[0.3, 0.5], [-0.5, 0.2]]
        local_radius = 0.2

        for center in local_centers
            # Local domain
            TR_local = test_input(f, dim=2, center=center, sample_range=local_radius)

            # Local approximation with sparsity
            pol_local = Constructor(TR_local, degree=8, basis=:chebyshev)
            sparse_local = to_exact_monomial_basis_sparse(
                pol_local, threshold=1e-6, reoptimize=true
            )

            # Test: Local approximation should be more accurate near center
            test_points_near = [center + 0.1*randn(2) for _ in 1:20]

            errors_local = [abs(f(pt) - sparse_local.polynomial(pt)) for pt in test_points_near]
            mean_error_local = mean(errors_local)

            # Global approximation for comparison
            pol_global = Constructor(TR, degree=10, basis=:chebyshev)
            sparse_global = to_exact_monomial_basis_sparse(pol_global, threshold=1e-5, reoptimize=true)
            errors_global = [abs(f(pt) - sparse_global.polynomial(pt)) for pt in test_points_near]
            mean_error_global = mean(errors_global)

            # Local should be better
            @test mean_error_local < mean_error_global
            @info "Local refinement near $center: $(round(mean_error_global/mean_error_local, digits=2))x better"
        end
    end
end
```

### Test 1.3: Sparsity Pattern Stability

```julia
@testset "Sparsity Pattern Stability Under Refinement" begin
    # Test that sparsity pattern is consistent across refinement levels
    f(x) = x[1]^3 * x[2] + x[2]^4 + 0.01*x[1]*x[2]  # Known sparse structure

    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

    degrees = [6, 8, 10, 12]
    sparsity_patterns = []
    polynomials = []

    for deg in degrees
        pol = Constructor(TR, deg, basis=:chebyshev)
        sparse_result = to_exact_monomial_basis_sparse(
            pol, threshold=1e-5, reoptimize=true
        )

        pattern = get_monomial_sparsity_pattern(sparse_result.polynomial)
        push!(sparsity_patterns, pattern)
        push!(polynomials, sparse_result.polynomial)
    end

    # Check pattern consistency (up to degree truncation)
    for i in 2:length(sparsity_patterns)
        overlap = compute_pattern_overlap(
            sparsity_patterns[i-1],
            sparsity_patterns[i]
        )

        # At least 80% of lower-degree terms should remain active
        @test overlap > 0.8

        @info "Degree $(degrees[i-1]) → $(degrees[i]): $(round(overlap*100, digits=1))% pattern overlap"
    end

    # Check that important monomials are consistently present
    # e.g., x₁³x₂ and x₂⁴ should always be there
    for (i, poly) in enumerate(polynomials)
        monoms = monomials(poly)
        # Check for x₁³x₂
        has_x1_3_x2 = any(m -> degree(m, 1)==3 && degree(m, 2)==1, monoms)
        # Check for x₂⁴
        has_x2_4 = any(m -> degree(m, 1)==0 && degree(m, 2)==4, monoms)

        @test has_x1_3_x2
        @test has_x2_4
    end
end
```

### Test 1.4: High Precision Re-optimization Accuracy

```julia
@testset "High Precision vs Standard Precision Re-optimization" begin
    # Use function that's ill-conditioned in monomial basis
    f(x) = sum(cos(k*π*x[1]) for k in 1:5)  # Smooth, high oscillation

    TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
    pol = Constructor(TR, 15, basis=:chebyshev)

    threshold = 1e-8

    @testset "Float64 Precision" begin
        result_f64 = to_exact_monomial_basis_sparse(
            pol, threshold=threshold, reoptimize=true, precision=Float64
        )

        @test result_f64.l2_ratio > 0.9  # Should still be reasonable
        @info "Float64 L2-norm preservation: $(round(result_f64.l2_ratio*100, digits=1))%"
    end

    @testset "BigFloat Precision" begin
        result_bigfloat = to_exact_monomial_basis_sparse(
            pol, threshold=threshold, reoptimize=true, precision=BigFloat
        )

        @test result_bigfloat.l2_ratio > 0.95  # Should be excellent
        @info "BigFloat L2-norm preservation: $(round(result_bigfloat.l2_ratio*100, digits=1))%"
    end

    @testset "Precision Comparison" begin
        result_f64 = to_exact_monomial_basis_sparse(
            pol, threshold=threshold, reoptimize=true, precision=Float64
        )
        result_bigfloat = to_exact_monomial_basis_sparse(
            pol, threshold=threshold, reoptimize=true, precision=BigFloat
        )

        # BigFloat should be better or equal
        @test result_bigfloat.l2_ratio >= result_f64.l2_ratio

        improvement = result_bigfloat.l2_ratio / result_f64.l2_ratio
        @info "BigFloat improvement over Float64: $(round((improvement-1)*100, digits=1))%"
    end

    @testset "Condition Number Analysis" begin
        result_bigfloat = to_exact_monomial_basis_sparse(
            pol, threshold=threshold, reoptimize=true, precision=BigFloat
        )

        cond_num = result_bigfloat.optimization_info.condition_number

        @test cond_num > 1e6  # Should be ill-conditioned
        @info "Gram matrix condition number: $(scientific(cond_num))"
        @info "This demonstrates why high precision is necessary"
    end
end
```

### Test 1.5: Adaptive Threshold Selection

```julia
@testset "Adaptive Threshold Selection" begin
    f(x) = x[1]^4 + x[1]^2*x[2]^2 + x[2]^4 + 0.01*sin(10*x[1]*x[2])

    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
    pol = Constructor(TR, 10, basis=:chebyshev)

    max_l2_degradation = 0.01  # Allow 1% L2-norm increase

    @testset "Find Optimal Threshold" begin
        optimal_threshold = find_optimal_sparsity_threshold(
            pol,
            max_l2_degradation = max_l2_degradation,
            reoptimize = true
        )

        @test optimal_threshold > 0
        @test optimal_threshold < 1.0
        @info "Optimal threshold: $(scientific(optimal_threshold))"
    end

    @testset "Verify L2-norm Preservation" begin
        optimal_threshold = find_optimal_sparsity_threshold(
            pol, max_l2_degradation = max_l2_degradation, reoptimize = true
        )

        result = to_exact_monomial_basis_sparse(
            pol, threshold=optimal_threshold, reoptimize=true
        )

        l2_original = compute_l2_norm_vandermonde(pol)
        l2_sparse = compute_l2_norm(result.polynomial, BoxDomain(2, 1.0))

        degradation = abs(l2_sparse - l2_original) / l2_original

        @test degradation <= max_l2_degradation
        @info "Actual L2 degradation: $(round(degradation*100, digits=2))%"
    end

    @testset "Check Sparsity Achieved" begin
        optimal_threshold = find_optimal_sparsity_threshold(
            pol, max_l2_degradation = max_l2_degradation, reoptimize = true
        )

        result = to_exact_monomial_basis_sparse(
            pol, threshold=optimal_threshold, reoptimize=true
        )

        sparsity_ratio = result.sparsity_info.new_nnz / length(pol.coeffs)

        # Should achieve meaningful sparsity
        @test sparsity_ratio < 0.7  # At least 30% reduction
        @info "Sparsity ratio: $(round(sparsity_ratio*100, digits=1))% ($(round((1-sparsity_ratio)*100, digits=1))% reduction)"
    end
end
```

### Test 1.6: Integration with Refining Module

```julia
@testset "Integration with Refining.jl Critical Point Solver" begin
    # Function with known critical points
    f(x) = (x[1]^2 - 1)^2 + (x[2]^2 - 1)^2  # 4 minima at (±1, ±1)

    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.5)

    @testset "Dense Polynomial Critical Points" begin
        pol_dense = Constructor(TR, 10, basis=:chebyshev)
        critical_pts_dense = find_critical_points(pol_dense, TR)

        # Should find 4 minima
        @test length(critical_pts_dense) >= 4

        # Verify locations
        expected_minima = [[-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]]
        for expected_min in expected_minima
            distances = [norm(cp - expected_min) for cp in critical_pts_dense]
            @test minimum(distances) < 0.1
        end
    end

    @testset "Sparse Polynomial Critical Points" begin
        pol = Constructor(TR, 10, basis=:chebyshev)
        sparse_result = to_exact_monomial_basis_sparse(
            pol, threshold=1e-6, reoptimize=true
        )

        # Convert to ApproxPoly format for refining.jl
        # (May need adapter function)
        critical_pts_sparse = find_critical_points_from_monomial(
            sparse_result.polynomial, TR
        )

        # Should find same 4 minima
        @test length(critical_pts_sparse) >= 4

        # Verify locations
        expected_minima = [[-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]]
        for expected_min in expected_minima
            distances = [norm(cp - expected_min) for cp in critical_pts_sparse]
            @test minimum(distances) < 0.1
        end
    end

    @testset "Critical Point Consistency" begin
        # Dense and sparse should find same critical points
        pol = Constructor(TR, 10, basis=:chebyshev)
        sparse_result = to_exact_monomial_basis_sparse(
            pol, threshold=1e-6, reoptimize=true
        )

        critical_pts_dense = find_critical_points(pol, TR)
        critical_pts_sparse = find_critical_points_from_monomial(
            sparse_result.polynomial, TR
        )

        # Should have same number
        @test length(critical_pts_dense) == length(critical_pts_sparse)

        # Each dense point should have corresponding sparse point
        for cp_dense in critical_pts_dense
            min_dist = minimum([norm(cp_dense - cp_sparse) for cp_sparse in critical_pts_sparse])
            @test min_dist < 0.05  # Very close
        end
    end
end
```

### Test 1.7: Performance & Scalability

```julia
@testset "Performance: Sparsity Speedup" begin
    # Test that sparse representations speed up evaluations
    f(x) = sum(x[i]^4 for i in 1:3)  # Naturally sparse

    TR = test_input(f, dim=3, center=zeros(3), sample_range=1.0)
    pol = Constructor(TR, 12, basis=:chebyshev)

    # Dense monomial polynomial
    dense_poly = to_exact_monomial_basis(pol)

    # Sparse monomial polynomial
    sparse_result = to_exact_monomial_basis_sparse(
        pol, threshold=1e-8, reoptimize=true
    )
    sparse_poly = sparse_result.polynomial

    # Benchmark evaluations
    test_points = [randn(3) for _ in 1:10000]

    @testset "Evaluation Time" begin
        time_dense = @elapsed for pt in test_points
            dense_poly(pt...)
        end

        time_sparse = @elapsed for pt in test_points
            sparse_poly(pt...)
        end

        speedup = time_dense / time_sparse

        @test speedup > 1.0  # Sparse should be faster
        @info "Sparse evaluation speedup: $(round(speedup, digits=2))x"
    end

    @testset "Memory Usage" begin
        dense_terms = length(monomials(dense_poly))
        sparse_terms = length(monomials(sparse_poly))

        memory_reduction = 1 - sparse_terms / dense_terms

        @test memory_reduction > 0.3  # At least 30% reduction
        @info "Memory reduction: $(round(memory_reduction*100, digits=1))%"
    end
end
```

---

## Test Suite 2: Unit Tests for Components

### test_monomial_vandermonde.jl

```julia
@testset "Monomial Vandermonde Matrix Construction" begin
    @testset "1D Case" begin
        grid = reshape([-1.0, 0.0, 1.0], 3, 1)
        @polyvar x
        monomials_vec = [x^0, x^1, x^2]

        V = build_monomial_vandermonde(grid, monomials_vec, Float64)

        expected = [
            1.0  -1.0  1.0;
            1.0   0.0  0.0;
            1.0   1.0  1.0
        ]

        @test V ≈ expected
    end

    @testset "2D Case" begin
        grid = [0.0 0.0; 1.0 0.0; 0.0 1.0; 1.0 1.0]
        @polyvar x[1:2]
        monomials_vec = [x[1]^0*x[2]^0, x[1]^1*x[2]^0, x[1]^0*x[2]^1, x[1]^1*x[2]^1]

        V = build_monomial_vandermonde(grid, monomials_vec, Float64)

        expected = [
            1.0  0.0  0.0  0.0;
            1.0  1.0  0.0  0.0;
            1.0  0.0  1.0  0.0;
            1.0  1.0  1.0  1.0
        ]

        @test V ≈ expected
    end

    @testset "High Precision" begin
        grid = reshape([-1.0, 0.0, 1.0], 3, 1)
        @polyvar x
        monomials_vec = [x^0, x^1, x^2]

        V_bigfloat = build_monomial_vandermonde(grid, monomials_vec, BigFloat)

        @test eltype(V_bigfloat) == BigFloat
        @test size(V_bigfloat) == (3, 3)
    end

    @testset "Condition Number Analysis" begin
        # High-degree monomials should be ill-conditioned
        grid = reshape(range(-1, 1, length=20), 20, 1)
        @polyvar x
        monomials_vec = [x^i for i in 0:15]

        V = build_monomial_vandermonde(grid, monomials_vec, Float64)
        cond_num = cond(V)

        @test cond_num > 1e6  # Should be very ill-conditioned
        @info "Monomial Vandermonde condition number: $(scientific(cond_num))"
    end
end
```

### test_sparse_monomial_optimization.jl

```julia
@testset "Sparse Monomial Re-optimization" begin
    @testset "Basic Re-optimization" begin
        # Create simple test case
        f(x) = x[1]^2 + 0.001*x[1]

        TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
        pol = Constructor(TR, 5, basis=:chebyshev)

        # Get monomial polynomial
        mono_poly = to_exact_monomial_basis(pol)

        # Create sparsity pattern (keep x^2, remove x^1)
        terms_list = monomials(mono_poly)
        sparsity_pattern = BitVector([degree(t) != 1 for t in terms_list])

        # Re-optimize
        reopt_result = reoptimize_sparse_monomial(
            pol, mono_poly, sparsity_pattern, BigFloat
        )

        @test reopt_result isa DynamicPolynomials.Polynomial
        @test length(monomials(reopt_result)) < length(terms_list)
    end

    @testset "Solver Options" begin
        f(x) = x[1]^2
        TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
        pol = Constructor(TR, 5, basis=:chebyshev)
        mono_poly = to_exact_monomial_basis(pol)

        sparsity_pattern = BitVector([degree(t) > 0 for t in monomials(mono_poly)])

        for solver in [:lu, :qr, :svd]
            result = reoptimize_sparse_monomial(
                pol, mono_poly, sparsity_pattern, BigFloat, solver=solver
            )

            @test result isa DynamicPolynomials.Polynomial
            @info "Solver $solver completed successfully"
        end
    end
end
```

---

## Benchmark Suite (benchmarks/sparse_refinement_benchmarks.jl)

```julia
using BenchmarkTools
using Globtim

function benchmark_sparse_refinement()
    println("=" ^60)
    println("Sparse Refinement Benchmark Suite")
    println("=" ^60)

    # Test function
    f(x) = 1 / (1 + 25*x[1]^2)

    for degree in [10, 15, 20]
        println("\nDegree $degree:")
        println("-" ^40)

        TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
        pol = Constructor(TR, degree, basis=:chebyshev)

        # Benchmark simple truncation
        t_trunc = @benchmark to_exact_monomial_basis_sparse(
            $pol, threshold=1e-6, reoptimize=false
        )

        println("Simple truncation: $(BenchmarkTools.prettytime(median(t_trunc.times)))")

        # Benchmark re-optimization (Float64)
        t_reopt_f64 = @benchmark to_exact_monomial_basis_sparse(
            $pol, threshold=1e-6, reoptimize=true, precision=Float64
        )

        println("Re-optimization (Float64): $(BenchmarkTools.prettytime(median(t_reopt_f64.times)))")

        # Benchmark re-optimization (BigFloat)
        t_reopt_bf = @benchmark to_exact_monomial_basis_sparse(
            $pol, threshold=1e-6, reoptimize=true, precision=BigFloat
        )

        println("Re-optimization (BigFloat): $(BenchmarkTools.prettytime(median(t_reopt_bf.times)))")

        println("Overhead: $(round(median(t_reopt_bf.times) / median(t_trunc.times), digits=1))x")
    end
end

benchmark_sparse_refinement()
```

---

## Success Criteria

### Correctness
- [ ] All truncation vs re-optimization tests pass
- [ ] Re-optimization always preserves L2-norm better than truncation
- [ ] High precision solver handles ill-conditioned problems
- [ ] Sparsity patterns stable across degrees

### Integration
- [ ] Sparse polynomials work with `find_critical_points()`
- [ ] Local refinement workflow validated
- [ ] Critical points found consistently

### Performance
- [ ] Sparse evaluation faster than dense
- [ ] Re-optimization completes in reasonable time
- [ ] Memory usage reduced with sparsity

### Coverage
- [ ] 1D and 2D test cases
- [ ] Polynomial and smooth functions
- [ ] Edge cases handled

---

## Running the Tests

```bash
# Run main test suite
julia --project=. test/test_sparse_refinement.jl

# Run unit tests
julia --project=. test/test_monomial_vandermonde.jl
julia --project=. test/test_sparse_monomial_optimization.jl

# Run benchmarks
julia --project=. test/benchmarks/sparse_refinement_benchmarks.jl

# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'
```

---

## Documentation Requirements

For each test:
- [ ] Docstring explaining purpose
- [ ] Comments explaining key assertions
- [ ] @info messages showing results
- [ ] Clear test names

Example:
```julia
@testset "Re-optimization improves accuracy on ill-conditioned problems" begin
    # Purpose: Verify that high-precision re-optimization preserves
    # approximation quality even when monomial basis is ill-conditioned

    # Test implementation...

    @info "Improvement: $(improvement)x better accuracy"
end
```

---

## Next Steps After Phase C

1. Run tests on HPC cluster (larger problems)
2. Add stress tests (very high degree, very high dimension)
3. Create continuous integration pipeline
4. Performance profiling and optimization
5. Document common failure modes and solutions
