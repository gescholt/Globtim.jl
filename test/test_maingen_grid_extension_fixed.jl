# Test suite for MainGenerate grid extension
# Build tests incrementally to ensure no breaking changes

using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "MainGenerate Current Behavior Tests" begin
    
    @testset "Basic Float64 functionality" begin
        # Simple 1D polynomial that we know the answer for
        f_simple = x -> x[1]^2
        
        # Test with standard parameters
        n = 1  # dimension
        d = (:one_d_for_all, 4)  # degree 4
        delta = 0.1
        alpha = 0.99
        scale_factor = 1.0
        scl = 1.0
        
        # Call MainGenerate directly
        pol = Globtim.MainGenerate(f_simple, n, d, delta, alpha, scale_factor, scl)
        
        # Basic checks
        @test isa(pol, ApproxPoly)
        # Check that polynomial was created with correct parameters
        @test pol.degree == d
        @test length(pol.coeffs) >= 5  # at least degree 4 + 1 coefficients
        
        # The approximation error should be small
        # For a polynomial, the L2 norm error should be near machine precision
        @test pol.nrm < 1e-10
    end
    
    @testset "2D polynomial approximation" begin
        # f(x,y) = x^2 + y^2
        f_2d = x -> x[1]^2 + x[2]^2
        
        n = 2
        d = (:one_d_for_all, 3)  # degree 3
        delta = 0.1
        alpha = 0.99
        scale_factor = 1.0
        scl = 1.0
        
        pol = Globtim.MainGenerate(f_2d, n, d, delta, alpha, scale_factor, scl, verbose=0)
        
        @test isa(pol, ApproxPoly)
        @test pol.degree == d
        @test pol.nrm < 1e-10
    end
    
    @testset "Chebyshev basis (default)" begin
        f = x -> exp(-sum(x.^2))
        
        n = 2
        d = (:one_d_for_all, 8)
        
        pol_cheb = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, basis=:chebyshev)
        
        @test pol_cheb.basis == :chebyshev
        @test pol_cheb.grid isa Matrix  # Should have stored the grid
        
        # Check grid points are Chebyshev nodes
        N = pol_cheb.N
        # We can't easily check the exact values without knowing the grid generation details
        @test size(pol_cheb.grid, 2) == n  # Grid should have n dimensions
    end
    
    @testset "Legendre basis" begin
        f = x -> exp(-sum(x.^2))
        
        n = 2
        d = (:one_d_for_all, 8)
        
        pol_leg = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, basis=:legendre)
        
        @test pol_leg.basis == :legendre
        @test pol_leg.grid isa Matrix
        
        # Legendre nodes are different from Chebyshev
        pol_cheb = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, basis=:chebyshev)
        # Can't compare exact grid values without knowing implementation details
        # But we can verify they both created grids
        @test size(pol_leg.grid) == size(pol_cheb.grid)
    end
    
    @testset "Different degree specifications" begin
        f = x -> x[1]^2 * x[2]
        n = 2
        
        # Test :one_d_for_all
        d1 = (:one_d_for_all, 4)
        pol1 = Globtim.MainGenerate(f, n, d1, 0.1, 0.99, 1.0, 1.0)
        @test pol1.degree == d1
        
        # Test :one_d_per_dim
        d2 = (:one_d_per_dim, [3, 5])
        pol2 = Globtim.MainGenerate(f, n, d2, 0.1, 0.99, 1.0, 1.0)
        @test pol2.degree == d2
    end
    
    @testset "Scale factor handling" begin
        f = x -> sum(x.^2)
        n = 2
        d = (:one_d_for_all, 4)
        
        # Scalar scale factor
        scale_scalar = 2.0
        pol_scalar = Globtim.MainGenerate(f, n, d, 0.1, 0.99, scale_scalar, 1.0)
        @test pol_scalar.scale_factor == scale_scalar
        
        # Vector scale factor
        scale_vec = [2.0, 3.0]
        pol_vec = Globtim.MainGenerate(f, n, d, 0.1, 0.99, scale_vec, 1.0)
        @test pol_vec.scale_factor == scale_vec
        
        # The norms should be different due to scaling
        @test !isapprox(pol_scalar.nrm, pol_vec.nrm)
    end
    
    @testset "Grid generation and storage" begin
        f = x -> prod(x)
        n = 3
        d = (:one_d_for_all, 3)
        
        # Test with specific GN
        GN_specified = 15
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=GN_specified)
        
        @test pol.N == GN_specified
        @test size(pol.grid, 1) == GN_specified^n  # Total grid points
        @test size(pol.grid, 2) == n  # Dimension
    end
end

@testset "MainGenerate Edge Cases" begin
    
    @testset "High dimension handling" begin
        # Test dimension > 3 uses generate_grid_small_n
        f = x -> sum(x.^2)
        n = 4
        d = (:one_d_for_all, 2)
        
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 0.5)  # scl < 1 for smaller grid
        
        @test isa(pol, ApproxPoly)
        # Test successful creation for high dimensions
    end
    
    @testset "Precision types" begin
        f = x -> x[1]^3
        n = 1
        d = (:one_d_for_all, 3)
        
        # Test with different precision types
        for prec in [FloatPrecision, RationalPrecision]
            pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, precision=prec)
            @test pol.precision == prec
            
            if prec == RationalPrecision
                @test eltype(pol.coeffs) <: Rational
            else
                @test eltype(pol.coeffs) <: AbstractFloat
            end
        end
    end
    
    @testset "Center parameter" begin
        f = x -> (x[1] - 1)^2 + (x[2] - 1)^2  # Centered at (1,1)
        n = 2
        d = (:one_d_for_all, 4)
        center = [1.0, 1.0]
        
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, center=center)
        
        # The approximation should still be good
        @test pol.nrm < 1e-10
    end
    
    @testset "Condition number monitoring" begin
        # Create a potentially ill-conditioned problem
        f = x -> exp(10 * sum(x))  # Rapidly varying function
        n = 2
        d = (:one_d_for_all, 15)  # High degree
        
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, verbose=0)
        
        # Check that condition number was computed and stored
        @test hasfield(typeof(pol), :cond_vandermonde)
        @test pol.cond_vandermonde > 0
        @test isfinite(pol.cond_vandermonde)
    end
end

@testset "Grid-based MainGenerate Design Tests" begin
    # These tests define the expected behavior for grid-based input
    # They will initially fail/error until implementation
    
    @testset "Grid input detection" begin
        # Define what we expect the API to look like
        f = x -> x[1]^2 + x[2]^2
        n = 2
        
        # Generate a grid manually
        nx, ny = 10, 15  # Anisotropic
        grid_x = cos.((2 .* (0:nx-1) .+ 1) .* π ./ (2 * nx))
        grid_y = cos.((2 .* (0:ny-1) .+ 1) .* π ./ (2 * ny))
        
        # Create grid in expected format
        grid = Matrix{Float64}(undef, nx * ny, 2)
        idx = 1
        for i in 1:nx, j in 1:ny
            grid[idx, 1] = grid_x[i]
            grid[idx, 2] = grid_y[j]
            idx += 1
        end
        
        # This should work after implementation
        # pol = MainGenerate(f, n, grid, 0.1, 0.99, 1.0, 1.0)
        
        # Expected behavior:
        # - Detect that d is a Matrix
        # - Extract grid information
        # - Infer appropriate polynomial degree
        # - Use provided grid instead of generating one
    end
    
    @testset "Anisotropic grid polynomial construction" begin
        # Test case for anisotropic grids
        f = x -> x[1]^4 + x[2]^2  # Different behavior in each dimension
        n = 2
        
        # More points in x direction due to higher degree
        grid_points = [20, 10]
        
        # This is what we want to support
        # grid = generate_anisotropic_grid(grid_points, basis=:chebyshev)
        # pol = MainGenerate(f, n, grid, 0.1, 0.99, 1.0, 1.0)
        
        # Expected:
        # - Support Matrix{SVector} or similar grid format
        # - Correctly handle non-square grids
        # - Maintain approximation quality
    end
end

# Helper function to test the future grid-based interface
function test_grid_maingen_interface()
    println("Testing future grid-based MainGenerate interface...")
    
    # This function documents the expected interface
    # It will be used for testing once implementation is ready
    
    f = x -> exp(-(x[1]^2 + 100*x[2]^2))  # Highly anisotropic function
    n = 2
    
    # Generate anisotropic grid
    nx, ny = 30, 10  # More points in x due to slower variation
    grid = generate_anisotropic_grid([nx, ny], basis=:chebyshev)
    
    # Future interface:
    # pol = MainGenerate(f, n, grid, 0.1, 0.99, 1.0, 1.0)
    
    # What we expect:
    # 1. pol.grid == convert_grid_format(grid)
    # 2. pol.N reflects the grid structure
    # 3. pol.nrm is computed correctly
    # 4. Polynomial evaluation works as expected
    
    println("Interface test defined - ready for implementation")
end

# Run this to see the expected interface
# test_grid_maingen_interface()