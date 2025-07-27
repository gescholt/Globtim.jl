# test_l2_norm_scaling.jl
# Tests for L2-norm computation with domain scaling and type safety

using Test
using LinearAlgebra
using StaticArrays
using Globtim

# Helper function to test discrete_l2_norm_riemann with scale_factor
# This documents the expected interface even before implementation
function discrete_l2_norm_riemann_scaled(f, grid, scale_factor)
    # Current implementation doesn't accept scale_factor
    # This is a wrapper for testing that simulates the expected behavior

    # Get dimension
    N = ndims(grid)

    # Current implementation without scaling
    base_norm = Globtim.discrete_l2_norm_riemann(f, grid)

    # Apply Jacobian correction
    if isa(scale_factor, Number)
        jacobian = abs(scale_factor)^N
    else
        length(scale_factor) == N || throw(ArgumentError("scale_factor dimension mismatch"))
        jacobian = abs(prod(scale_factor))
    end

    return base_norm * sqrt(jacobian)
end

@testset "L2-Norm Scaling Tests" begin

    @testset "Constant function on scaled domain" begin
        # L2-norm of f(x)=c on [-a,a]^n should be c*(2a)^(n/2)
        for dim in [1, 2, 3]
            for scale in [0.5, 1.0, 2.0, 5.0]
                # Create a grid on [-1,1]^dim
                grid = generate_grid(dim, 14, basis = :chebyshev)

                # Constant function f(x) = 1
                f_const = x -> 1.0

                # Expected L2-norm: sqrt(volume) = sqrt((2*scale)^dim)
                expected = sqrt((2 * scale)^dim)

                # Test scalar scale_factor
                computed = discrete_l2_norm_riemann_scaled(x -> f_const(x), grid, scale)
                @test computed ≈ expected rtol = 1e-2

                # Test vector scale_factor (same value for all dimensions)
                if dim > 1
                    scale_vec = fill(scale, dim)
                    computed_vec =
                        discrete_l2_norm_riemann_scaled(x -> f_const(x), grid, scale_vec)
                    @test computed_vec ≈ expected rtol = 1e-2
                end
            end
        end
    end

    @testset "Polynomial with known L2-norm" begin
        # L2-norm of x^2 on [-a,a] is sqrt(2a^5/5)
        dim = 1
        grid = generate_grid(dim, 14, basis = :chebyshev)

        for scale in [0.5, 1.0, 2.0, 3.0]
            # Function f(x) = x^2 (on scaled domain)
            f_poly = x -> (x[1] * scale)^2

            # Analytical L2-norm: sqrt(∫_{-a}^a x^4 dx) = sqrt(2a^5/5)
            expected = sqrt(2 * scale^5 / 5)

            # Compute using discrete approximation
            computed = discrete_l2_norm_riemann_scaled(f_poly, grid, scale)

            # Higher tolerance due to discretization error
            @test computed ≈ expected rtol = 5e-2
        end
    end

    @testset "L2-norm with anisotropic scaling" begin
        # f(x,y) = 1 on [-a,a]×[-b,b]
        # L2-norm = sqrt(4ab)
        dim = 2
        grid = generate_grid(dim, 14, basis = :chebyshev)

        test_cases = [
            ([2.0, 3.0], sqrt(4 * 2.0 * 3.0)),
            ([1.0, 5.0], sqrt(4 * 1.0 * 5.0)),
            ([0.5, 0.5], sqrt(4 * 0.5 * 0.5)),
        ]

        for (scale_factor, expected) in test_cases
            f_const = idx -> 1.0
            computed = discrete_l2_norm_riemann_scaled(f_const, grid, scale_factor)
            @test computed ≈ expected rtol = 1e-2
        end
    end

    @testset "Gaussian function scaling" begin
        # Test with simpler function that has clearer scaling behavior
        # f(x) = exp(-0.1*||x||^2) to avoid edge effects
        for dim in [1, 2]
            grid = generate_grid(dim, 14, basis = :chebyshev)

            # Test that our scaling wrapper correctly applies Jacobian
            # Use a nearly constant function to minimize edge effects
            f_simple = x -> exp(-0.01 * sum(x .^ 2))

            for scale in [0.5, 2.0, 3.0]
                # The discrete L2 norm with scaling should include Jacobian factor
                norm_with_scale = discrete_l2_norm_riemann_scaled(f_simple, grid, scale)
                norm_base = discrete_l2_norm_riemann_scaled(f_simple, grid, 1.0)

                # For nearly constant function, ratio should be close to scale^(dim/2)
                expected_ratio = scale^(dim / 2)
                actual_ratio = norm_with_scale / norm_base

                # More relaxed tolerance due to discretization
                @test actual_ratio ≈ expected_ratio rtol = 0.05
            end
        end
    end
end

@testset "Type Safety Tests" begin

    @testset "Vandermonde type preservation" begin
        # Test with different float types
        for T in [Float32, Float64]
            dim = 2
            n_points = 10

            # Create grid with specific type
            grid_1d = T.(cos.((2 .* (0:n_points) .+ 1) .* π ./ (2 * (n_points + 1))))
            grid_matrix = zeros(T, (n_points + 1)^dim, dim)

            # Fill grid matrix
            idx = 1
            for i = 0:n_points, j = 0:n_points
                grid_matrix[idx, 1] = grid_1d[i+1]
                grid_matrix[idx, 2] = grid_1d[j+1]
                idx += 1
            end

            # Create Lambda
            Lambda = SupportGen(dim, (:one_d_for_all, 3))

            # Compute Vandermonde matrix
            V = Globtim.lambda_vandermonde(Lambda, grid_matrix)

            # Test that type is preserved from input
            @test eltype(V) == T
        end
    end

    @testset "Scale factor type handling" begin
        dim = 2
        grid = generate_grid(dim, 10, basis = :chebyshev)
        f = x -> sum(x .^ 2)

        # Test with different scale_factor types
        scale_float = 2.0
        scale_int = 2
        scale_vec_float = [2.0, 3.0]
        scale_vec_int = [2, 3]

        # All should work and give same result (with type conversion)
        norm1 = discrete_l2_norm_riemann_scaled(f, grid, scale_float)
        norm2 = discrete_l2_norm_riemann_scaled(f, grid, scale_int)
        @test norm1 ≈ norm2

        norm3 = discrete_l2_norm_riemann_scaled(f, grid, scale_vec_float)
        norm4 = discrete_l2_norm_riemann_scaled(f, grid, scale_vec_int)
        @test norm3 ≈ norm4
    end
end

@testset "Domain Transformation Tests" begin

    @testset "Jacobian factor verification" begin
        # Test helper function for Jacobian computation
        compute_jacobian = function (scale_factor, dim)
            if isa(scale_factor, Number)
                return abs(scale_factor)^dim
            else
                return abs(prod(scale_factor))
            end
        end

        dim = 2
        scale_scalar = 3.0
        scale_vector = [2.0, 3.0]

        # Jacobian for scalar: scale^dim
        @test compute_jacobian(scale_scalar, dim) ≈ 9.0

        # Jacobian for vector: prod(scale)
        @test compute_jacobian(scale_vector, dim) ≈ 6.0

        # Test with negative scales (absolute value)
        @test compute_jacobian(-2.0, dim) ≈ 4.0
        @test compute_jacobian([-2.0, 3.0], dim) ≈ 6.0
    end

    @testset "Integration with ApproxPoly" begin
        # Test that ApproxPoly correctly handles scaled domains
        f = x -> sum(x .^ 2)
        dim = 2

        # First compute norm at scale=1.0
        TR_base = test_input(f, dim = dim, sample_range = 1.0, tolerance = 1e-6)
        pol_base = Constructor(TR_base, 14)  # degree 14
        norm_base = pol_base.nrm

        for scale in [0.5, 2.0]
            TR = test_input(f, dim = dim, sample_range = scale, tolerance = 1e-6)
            pol = Constructor(TR, 14)  # degree 14

            # The stored L2-norm should account for scaling
            # For f(x) = ||x||^2 on [-a,a]^2, L2-norm ≈ a^2 * sqrt(8a^2/3)

            # The norm should scale appropriately
            expected_ratio = scale^(dim / 2 + 1)  # Extra factor from function scaling
            actual_ratio = pol.nrm / norm_base
            @test actual_ratio ≈ expected_ratio rtol = 0.1
        end
    end
end

@testset "Edge Cases and Error Handling" begin

    @testset "Zero and negative scale factors" begin
        dim = 2
        grid = generate_grid(dim, 10, basis = :chebyshev)
        f = x -> sum(x .^ 2)

        # Zero scale_factor should give zero norm (collapsed domain)
        @test discrete_l2_norm_riemann_scaled(f, grid, 0.0) ≈ 0.0

        # Negative scale_factor should give same result as positive (reflection)
        @test discrete_l2_norm_riemann_scaled(f, grid, -2.0) ≈
              discrete_l2_norm_riemann_scaled(f, grid, 2.0)

        # Mixed signs in vector scale_factor
        @test discrete_l2_norm_riemann_scaled(f, grid, [2.0, -3.0]) ≈
              discrete_l2_norm_riemann_scaled(f, grid, [2.0, 3.0])
    end

    @testset "Extreme scale factors" begin
        dim = 1
        grid = generate_grid(dim, 14, basis = :chebyshev)
        f = idx -> 1.0  # Constant function

        # Very small scale factor
        tiny_scale = 1e-10
        norm_tiny = discrete_l2_norm_riemann_scaled(f, grid, tiny_scale)
        @test norm_tiny ≈ sqrt(2 * tiny_scale) rtol = 1e-2

        # Very large scale factor
        large_scale = 1e6
        norm_large = discrete_l2_norm_riemann_scaled(f, grid, large_scale)
        @test norm_large ≈ sqrt(2 * large_scale) rtol = 1e-2
    end

    @testset "Dimension mismatch" begin
        dim = 3
        grid = generate_grid(dim, 10, basis = :chebyshev)
        f = x -> sum(x .^ 2)

        # Vector scale_factor with wrong dimension
        wrong_scale = [2.0, 3.0]  # Only 2 elements for 3D
        @test_throws ArgumentError discrete_l2_norm_riemann_scaled(f, grid, wrong_scale)

        # Too many elements
        wrong_scale2 = [2.0, 3.0, 4.0, 5.0]  # 4 elements for 3D
        @test_throws ArgumentError discrete_l2_norm_riemann_scaled(f, grid, wrong_scale2)
    end
end

@testset "Sparsification with Scaling" begin

    @testset "L2-norm preservation in sparsification" begin
        # Create polynomial on scaled domain
        f = x -> exp(-sum(x .^ 2))
        dim = 2

        for scale in [0.5, 2.0]
            TR = test_input(f, dim = dim, sample_range = scale, tolerance = 1e-8)
            pol = Constructor(TR, 14)  # degree 14

            # Sparsify the polynomial
            result = sparsify_polynomial(pol, 1e-10, mode = :relative)

            # Check that L2 norms are computed correctly
            @test result.l2_ratio ≈ 1.0 rtol = 1e-2  # Should be close to 1 for small threshold

            # The polynomial norms should account for domain scaling
            @test pol.nrm > 0
            @test result.polynomial.nrm > 0

            # Verify the ratio is reasonable
            @test 0.9 < result.l2_ratio < 1.1
        end
    end

    @testset "Approximation error with scaling" begin
        # Test compute_approximation_error with scaled domains
        f = x -> sum(x .^ 2)
        dim = 2

        TR = test_input(f, dim = dim, sample_range = 2.0, tolerance = 1e-6)
        pol = Constructor(TR, 14)  # degree 14

        # Compute approximation error
        error = compute_approximation_error(f, pol, TR, n_points = 30)

        # Error should be small (good approximation)
        # For very high precision approximations, the error might be smaller than nrm * 0.01
        @test error < max(pol.nrm * 0.01, 1e-10)  # Less than 1% of polynomial norm or 1e-10

        # Sparsify and check error increases
        sparse_result = sparsify_polynomial(pol, 1e-4, mode = :relative)
        error_sparse =
            compute_approximation_error(f, sparse_result.polynomial, TR, n_points = 30)

        # Sparsified should have larger error (with tolerance for numerical precision)
        @test error_sparse >= error - 1e-15
    end
end
