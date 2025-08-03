"""
Test suite for 4D framework utilities
"""

using Test
using Statistics
include("../src/4d_framework.jl")

@testset "4D Framework Tests" begin
    
    @testset "Basis Construction" begin
        # Test basic basis construction
        domain = [-1.0, 1.0]
        n_total = 100
        W_active = construct_4d_basis(domain, n_total)
        
        @test size(W_active) == (n_total, 4)
        @test all(isfinite.(W_active))
        
        # Test that each column has some non-zero entries
        for j in 1:4
            @test any(W_active[:, j] .!= 0.0)
        end
    end
    
    @testset "Multi-Objective Function" begin
        # Simple test functions
        mechanism_functions = [
            y -> y^2,
            y -> (y - 1)^2,
            y -> abs(y),
            y -> sin(y)^2
        ]
        weights = [1.0, 1.0, 0.5, 0.5]
        
        # Test without coupling
        y_test = [0.5, -0.5, 0.0, π/2]
        result = multi_objective_4d(y_test, mechanism_functions, weights)
        
        expected = 1.0 * (0.5)^2 + 1.0 * (-0.5 - 1)^2 + 0.5 * abs(0.0) + 0.5 * sin(π/2)^2
        @test result ≈ expected
        
        # Test with coupling
        coupling_matrix = [0.0 0.1 0.0 0.0;
                          0.1 0.0 0.0 0.0;
                          0.0 0.0 0.0 0.0;
                          0.0 0.0 0.0 0.0]

        result_coupled = multi_objective_4d(y_test, mechanism_functions, weights, coupling_matrix)
        @test result_coupled != result  # Should be different due to coupling
        @test isfinite(result_coupled)
    end
    
    @testset "Test Problem Creation" begin
        n_params = 50
        domain = [-2.0, 2.0]
        
        # Test simple problem
        simple_prob = create_4d_test_problem(:simple; n_params=n_params, domain=domain)
        
        # Test that it accepts correct input size
        θ_test = randn(n_params)
        result = simple_prob(θ_test)
        @test isa(result, Real)
        @test isfinite(result)
        
        # Test coupled problem
        coupled_prob = create_4d_test_problem(:coupled; n_params=n_params, domain=domain)
        result_coupled = coupled_prob(θ_test)
        @test isa(result_coupled, Real)
        @test isfinite(result_coupled)
        
        # Test complex problem
        complex_prob = create_4d_test_problem(:complex; n_params=n_params, domain=domain)
        result_complex = complex_prob(θ_test)
        @test isa(result_complex, Real)
        @test isfinite(result_complex)
    end
    
    @testset "Validation Function" begin
        # Create a simple test problem
        simple_prob = create_4d_test_problem(:simple; n_params=20, domain=[-1.0, 1.0])
        
        # Validate structure
        stats = validate_4d_structure(simple_prob, 20, [-1.0, 1.0]; n_samples=100)
        
        @test haskey(stats, :mean)
        @test haskey(stats, :std)
        @test haskey(stats, :min)
        @test haskey(stats, :max)
        @test stats[:n_samples] == 100
        @test stats[:n_params] == 20
        
        @test isfinite(stats[:mean])
        @test stats[:std] >= 0
        @test stats[:min] <= stats[:max]
    end
    
    @testset "Helper Functions" begin
        # Test interaction term
        result = interaction_term(1.0, 2.0)
        expected = 1.0 * 2.0 * exp(-0.5 * (1.0^2 + 2.0^2))
        @test result ≈ expected
        
        # Test basis functions
        domain = [0.0, 1.0]
        
        # Fourier basis
        low_freq = fourier_basis_1d(1, domain, :low_freq)
        high_freq = fourier_basis_1d(1, domain, :high_freq)
        @test isfinite(low_freq)
        @test isfinite(high_freq)
        
        # Gaussian RBF
        gauss_weight = gaussian_rbf_weight(0.5, 0.1)
        @test 0 < gauss_weight <= 1
        
        # Boundary basis
        boundary_weight = boundary_basis_weight(1, domain)
        @test isfinite(boundary_weight)
    end
    
    @testset "Error Handling" begin
        # Test wrong input dimensions
        mechanism_functions = [y -> y^2, y -> y^2, y -> y^2, y -> y^2]
        weights = [1.0, 1.0, 1.0, 1.0]
        
        @test_throws AssertionError multi_objective_4d([1.0, 2.0, 3.0], mechanism_functions, weights)  # Wrong y dimension
        @test_throws AssertionError multi_objective_4d([1.0, 2.0, 3.0, 4.0], mechanism_functions[1:3], weights)  # Wrong function count
        @test_throws AssertionError multi_objective_4d([1.0, 2.0, 3.0, 4.0], mechanism_functions, weights[1:3])  # Wrong weight count
        
        # Test unknown problem type
        @test_throws ErrorException create_4d_test_problem(:unknown)
    end
end

# Run the tests if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    println("All tests completed successfully!")
end
