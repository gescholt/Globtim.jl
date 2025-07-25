# Basic test suite for MainGenerate to understand current behavior
# Focus on small, fast tests

using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "MainGenerate Basic Tests" begin
    
    @testset "Minimal 1D test" begin
        # Very simple function and low degree for speed
        f = x -> x[1]^2
        n = 1
        d = (:one_d_for_all, 2)  # degree 2
        
        # Use explicit small GN for speed
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=5, verbose=0)
        
        @test isa(pol, ApproxPoly)
        @test pol.degree == d
        @test pol.nrm < 1e-8  # Should be near zero for polynomial
        @test pol.basis == :chebyshev  # Default
        @test pol.N == 5
    end
    
    @testset "Minimal 2D test" begin
        f = x -> x[1] + x[2]
        n = 2
        d = (:one_d_for_all, 1)  # degree 1 (linear)
        
        pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=4, verbose=0)
        
        @test isa(pol, ApproxPoly)
        @test pol.nrm < 1e-8
        # Grid size might not be exactly GN^2 due to internal calculations
        @test size(pol.grid, 1) > 0  # Just verify grid was created
        @test size(pol.grid, 2) == 2
    end
    
    @testset "Scale factor types" begin
        f = x -> x[1]
        n = 1
        d = (:one_d_for_all, 1)
        
        # Scalar scale factor
        pol1 = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 2.0, 1.0, GN=3, verbose=0)
        @test pol1.scale_factor == 2.0
        @test isa(pol1.scale_factor, Float64)
        
        # Vector scale factor for 2D
        f2 = x -> x[1] + x[2]
        pol2 = Globtim.MainGenerate(f2, 2, d, 0.1, 0.99, [2.0, 3.0], 1.0, GN=3, verbose=0)
        @test pol2.scale_factor == [2.0, 3.0]
        @test isa(pol2.scale_factor, Vector{Float64})
    end
    
    @testset "Basis selection" begin
        f = x -> x[1]
        n = 1
        d = (:one_d_for_all, 1)
        
        # Chebyshev (default)
        pol_cheb = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=3, basis=:chebyshev, verbose=0)
        @test pol_cheb.basis == :chebyshev
        
        # Legendre
        pol_leg = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=3, basis=:legendre, verbose=0)
        @test pol_leg.basis == :legendre
    end
    
    @testset "Degree formats" begin
        f = x -> sum(x)
        n = 2
        
        # :one_d_for_all format
        d1 = (:one_d_for_all, 2)
        pol1 = Globtim.MainGenerate(f, n, d1, 0.1, 0.99, 1.0, 1.0, GN=3, verbose=0)
        @test pol1.degree == d1
        
        # :one_d_per_dim format
        d2 = (:one_d_per_dim, [1, 2])
        pol2 = Globtim.MainGenerate(f, n, d2, 0.1, 0.99, 1.0, 1.0, GN=3, verbose=0)
        @test pol2.degree == d2
    end
end

@testset "MainGenerate Return Structure" begin
    # Understand what MainGenerate returns
    f = x -> x[1]
    n = 1
    d = (:one_d_for_all, 1)
    
    pol = Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN=3, verbose=0)
    
    # Check all fields exist
    @test hasfield(typeof(pol), :coeffs)
    @test hasfield(typeof(pol), :support)
    @test hasfield(typeof(pol), :degree)
    @test hasfield(typeof(pol), :nrm)
    @test hasfield(typeof(pol), :N)
    @test hasfield(typeof(pol), :scale_factor)
    @test hasfield(typeof(pol), :grid)
    @test hasfield(typeof(pol), :z)
    @test hasfield(typeof(pol), :basis)
    @test hasfield(typeof(pol), :precision)
    @test hasfield(typeof(pol), :normalized)
    @test hasfield(typeof(pol), :power_of_two_denom)
    @test hasfield(typeof(pol), :cond_vandermonde)
    
    # Check types
    @test isa(pol.coeffs, Vector)
    @test isa(pol.nrm, Float64)
    @test isa(pol.N, Int)
    @test isa(pol.grid, Matrix{Float64})
    @test isa(pol.z, Vector{Float64})
    @test isa(pol.basis, Symbol)
end

println("\nAll basic tests completed successfully!")
println("Ready to design grid-based extension tests.")