# Test file for new benchmark functions
# This file tests that all new benchmark functions work correctly
# and return expected values at their known global minima

using Test
using Globtim

@testset "Essential Benchmark Functions" begin
    
    @testset "Sphere Function" begin
        # Test at global minimum
        @test Sphere([0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test Sphere([0.0, 0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test Sphere(zeros(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points
        @test Sphere([1.0, 1.0]) ≈ 2.0 atol=1e-10
        @test Sphere([1.0, 2.0, 3.0]) ≈ 14.0 atol=1e-10
    end
    
    @testset "Rosenbrock Function" begin
        # Test at global minimum
        @test Rosenbrock([1.0, 1.0]) ≈ 0.0 atol=1e-10
        @test Rosenbrock(ones(3)) ≈ 0.0 atol=1e-10
        @test Rosenbrock(ones(5)) ≈ 0.0 atol=1e-10
        
        # Test error for insufficient dimensions
        @test_throws ArgumentError Rosenbrock([1.0])
        
        # Test at other points
        @test Rosenbrock([0.0, 0.0]) ≈ 1.0 atol=1e-10
    end
    
    @testset "Griewank Function" begin
        # Test at global minimum
        @test Griewank([0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test Griewank(zeros(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points (should be > 0)
        @test Griewank([1.0, 1.0]) > 0.0
    end
    
    @testset "Schwefel Function" begin
        # Test at approximate global minimum
        global_min = fill(420.9687, 2)
        @test Schwefel(global_min) ≈ 0.0 atol=1e-2
        
        # Test dimension scaling
        @test Schwefel(fill(420.9687, 5)) ≈ 0.0 atol=1e-2
    end
    
    @testset "Levy Function" begin
        # Test at global minimum
        @test Levy([1.0, 1.0]) ≈ 0.0 atol=1e-10
        @test Levy(ones(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points
        @test Levy([0.0, 0.0]) > 0.0
    end
    
    @testset "Zakharov Function" begin
        # Test at global minimum
        @test Zakharov([0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test Zakharov(zeros(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points
        @test Zakharov([1.0, 1.0]) > 0.0
    end
end

@testset "2D Benchmark Functions" begin
    
    @testset "Beale Function" begin
        # Test at global minimum
        @test Beale([3.0, 0.5]) ≈ 0.0 atol=1e-10
        
        # Test dimension check
        @test_throws ArgumentError Beale([1.0])
        @test_throws ArgumentError Beale([1.0, 2.0, 3.0])
    end
    
    @testset "Booth Function" begin
        # Test at global minimum
        @test Booth([1.0, 3.0]) ≈ 0.0 atol=1e-10
        
        # Test dimension check
        @test_throws ArgumentError Booth([1.0])
    end
    
    @testset "Branin Function" begin
        # Test at one global minimum
        @test Branin([π, 2.275]) ≈ 0.397887 atol=1e-4
        @test Branin([-π, 12.275]) ≈ 0.397887 atol=1e-4
        
        # Test dimension check
        @test_throws ArgumentError Branin([1.0])
    end
    
    @testset "Goldstein-Price Function" begin
        # Test at global minimum
        @test GoldsteinPrice([0.0, -1.0]) ≈ 3.0 atol=1e-10
        
        # Test dimension check
        @test_throws ArgumentError GoldsteinPrice([1.0])
    end
    
    @testset "Matyas Function" begin
        # Test at global minimum
        @test Matyas([0.0, 0.0]) ≈ 0.0 atol=1e-10
        
        # Test dimension check
        @test_throws ArgumentError Matyas([1.0])
    end
    
    @testset "McCormick Function" begin
        # Test at approximate global minimum
        @test McCormick([-0.54719, -1.54719]) ≈ -1.9133 atol=1e-3
        
        # Test dimension check
        @test_throws ArgumentError McCormick([1.0])
    end
end

@testset "n-D Benchmark Functions" begin
    
    @testset "Michalewicz Function" begin
        # Test basic functionality
        @test Michalewicz([π/2, π/2]) < 0.0  # Should be negative
        @test Michalewicz([0.0, 0.0]) ≈ 0.0 atol=1e-10
        
        # Test with different steepness parameter
        @test Michalewicz([π/2, π/2], m=5) != Michalewicz([π/2, π/2], m=10)
    end
    
    @testset "Styblinski-Tang Function" begin
        # Test at approximate global minimum
        global_min = fill(-2.903534, 2)
        expected_value = -39.16599 * 2
        @test StyblinskiTang(global_min) ≈ expected_value atol=1e-3
        
        # Test dimension scaling
        global_min_5d = fill(-2.903534, 5)
        expected_value_5d = -39.16599 * 5
        @test StyblinskiTang(global_min_5d) ≈ expected_value_5d atol=1e-3
    end
    
    @testset "Sum of Different Powers Function" begin
        # Test at global minimum
        @test SumOfDifferentPowers([0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test SumOfDifferentPowers(zeros(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points
        @test SumOfDifferentPowers([1.0, 1.0]) > 0.0
    end
    
    @testset "Trid Function" begin
        # Test at known global minima
        @test Trid([2.0, 2.0]) ≈ -2.0 atol=1e-10
        @test Trid([3.0, 4.0, 3.0]) ≈ -6.0 atol=1e-10
        @test Trid([4.0, 6.0, 6.0, 4.0]) ≈ -20.0 atol=1e-10
        
        # Test error for insufficient dimensions
        @test_throws ArgumentError Trid([1.0])
    end
    
    @testset "Rotated Hyper-Ellipsoid Function" begin
        # Test at global minimum
        @test RotatedHyperEllipsoid([0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test RotatedHyperEllipsoid(zeros(5)) ≈ 0.0 atol=1e-10
        
        # Test at other points
        @test RotatedHyperEllipsoid([1.0, 1.0]) > 0.0
    end
    
    @testset "Powell Function" begin
        # Test at global minimum
        @test Powell([0.0, 0.0, 0.0, 0.0]) ≈ 0.0 atol=1e-10
        @test Powell(zeros(8)) ≈ 0.0 atol=1e-10
        
        # Test dimension requirement
        @test_throws ArgumentError Powell([1.0, 2.0, 3.0])  # Not multiple of 4
        @test_throws ArgumentError Powell([1.0, 2.0])       # Not multiple of 4
    end
end

@testset "Function Integration with test_input" begin
    # Test that new functions work with the test_input system
    
    @testset "Sphere with test_input" begin
        TR = test_input(Sphere, dim=3, center=zeros(3), sample_range=5.12)
        @test TR.dim == 3
        @test length(TR.center) == 3
        @test TR.sample_range == 5.12
    end
    
    @testset "Rosenbrock with test_input" begin
        TR = test_input(Rosenbrock, dim=2, center=ones(2), sample_range=2.048)
        @test TR.dim == 2
        @test TR.center == ones(2)
    end
    
    @testset "2D functions with test_input" begin
        TR_beale = test_input(Beale, dim=2, center=[3.0, 0.5], sample_range=4.5)
        @test TR_beale.dim == 2
        
        TR_branin = test_input(Branin, dim=2, center=[π, 2.275], sample_range=7.5)
        @test TR_branin.dim == 2
    end
end

println("All benchmark function tests passed!")
