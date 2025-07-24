using Test
using Globtim
using DynamicPolynomials
using LinearAlgebra

@testset "Exact Polynomial Conversion" begin
    @testset "Basic monomial conversion" begin
        # Test 1D polynomial conversion
        # Use a polynomial that should be exactly representable
        f1d = x -> 2*x[1]^2 + x[1] - 1
        TR1d = test_input(f1d, dim=1, center=[0.0], sample_range=1.0)
        pol1d = Constructor(TR1d, 4, basis=:chebyshev)  # Degree 4 should exactly represent degree 2 polynomial
        
        @polyvar x
        mono_poly1d = to_exact_monomial_basis(pol1d, variables=[x])
        
        @test isa(mono_poly1d, AbstractPolynomial)
        @test length(variables(mono_poly1d)) == 1
        
        # Test evaluation at a few points
        test_points = [-1.0, 0.0, 0.5, 1.0]
        for pt in test_points
            # The polynomial is already in the correct domain [-1,1]
            poly_val = mono_poly1d(pt)
            func_val = f1d([pt])
            @test abs(poly_val - func_val) < 1e-10  # Should be nearly exact for polynomial
        end
    end
    
    @testset "2D polynomial conversion" begin
        # Test 2D polynomial
        f2d = x -> x[1]^2 + x[2]^2
        TR2d = test_input(f2d, dim=2, center=[0.0, 0.0], sample_range=1.0)
        pol2d = Constructor(TR2d, 4, basis=:chebyshev)  # Degree 4 should be sufficient
        
        @polyvar x y
        mono_poly2d = to_exact_monomial_basis(pol2d, variables=[x, y])
        
        @test isa(mono_poly2d, AbstractPolynomial)
        @test length(variables(mono_poly2d)) == 2
        
        # Test evaluation
        test_points = [[-1.0, -1.0], [0.0, 0.0], [0.5, 0.5], [1.0, 0.0]]
        for pt in test_points
            poly_val = mono_poly2d(pt...)
            func_val = f2d(pt)
            @test abs(poly_val - func_val) < 1e-10  # Should be nearly exact
        end
    end
    
    @testset "Legendre basis conversion" begin
        # Test with Legendre basis
        f = x -> sin(π*x[1]/2)
        TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
        pol_leg = Constructor(TR, 15, basis=:legendre)  # Higher degree for better approximation
        
        @polyvar x
        mono_poly_leg = to_exact_monomial_basis(pol_leg, variables=[x])
        
        @test isa(mono_poly_leg, AbstractPolynomial)
        
        # Check approximation quality
        test_points = range(-1, 1, length=20)
        max_error = maximum(abs(mono_poly_leg(pt) - f([pt])) for pt in test_points)
        @test max_error < 0.2  # The conversion maintains reasonable accuracy
    end
    
    @testset "exact_polynomial_coefficients convenience function" begin
        # Test the convenience function with a simple polynomial
        f = x -> 3*x[1]^2 - 1
        @polyvar x
        
        exact_poly = exact_polynomial_coefficients(f, 1, 4, 
                                                  basis=:chebyshev,
                                                  center=[0.0],
                                                  sample_range=1.0)
        
        @test isa(exact_poly, AbstractPolynomial)
        
        # Verify it captures the quadratic exactly  
        test_points = range(-1, 1, length=10)
        for pt in test_points
            @test abs(exact_poly(pt) - f([pt])) < 1e-10
        end
    end
    
    @testset "High-degree polynomial preservation" begin
        # Test with a more complex but still polynomial function
        f = x -> x[1]^2 + 2*x[2]^2 - x[1]*x[2]
        TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
        pol = Constructor(TR, 6, basis=:chebyshev)
        
        @polyvar x y
        mono_poly = to_exact_monomial_basis(pol, variables=[x, y])
        
        # This should be exact for polynomial functions
        test_points = [[0.5, 0.5], [0.3, 0.7], [-0.5, 0.8]]
        for pt in test_points
            poly_val = mono_poly(pt...)
            func_val = f(pt)
            @test abs(poly_val - func_val) < 1e-10
        end
    end
end