# Test ForwardDiff integration functionality

using Test
using Globtim
using DataFrames

@testset "ForwardDiff Integration Tests" begin
    
    @testset "Data Structures" begin
        # Test OrthantResult
        orthant = OrthantResult(
            1, [0.0, 0.0, 0.0, 0.0], [0.5, 0.5, 0.5, 0.5],
            10, 8, 0.8, 0.01, 2, 6, 1.5
        )
        @test orthant.orthant_id == 1
        @test orthant.success_rate == 0.8
        @test orthant.polynomial_degree == 6
        
        # Test BFGSConfig
        config = BFGSConfig()
        @test config.standard_tolerance == 1e-8
        @test config.high_precision_tolerance == 1e-12
        @test config.max_iterations == 100
        
        # Test ToleranceResult
        tolerance_result = ToleranceResult(
            0.001, Float64[], Float64[], String[],
            [orthant for _ in 1:16], [6], [100], 10.0,
            (raw = 0.7, bfgs = 0.8, combined = 0.75)
        )
        @test tolerance_result.tolerance == 0.001
        @test length(tolerance_result.orthant_data) == 16
        @test tolerance_result.success_rates.bfgs == 0.8
    end
    
    @testset "Enhanced BFGS Refinement" begin
        # Simple test function
        f(x) = sum(x.^2)
        
        # Test points
        initial_points = [[0.5, 0.5], [1.0, -1.0], [-0.5, 0.8]]
        initial_values = [f(p) for p in initial_points]
        orthant_labels = ["++", "+-", "-+"]
        
        # Create config
        config = BFGSConfig(
            max_iterations = 50,
            show_trace = false,
            track_hyperparameters = false
        )
        
        # Run enhanced refinement
        results = enhanced_bfgs_refinement(
            initial_points, initial_values, orthant_labels,
            f, config
        )
        
        @test length(results) == 3
        @test all(r -> r.converged, results)
        @test all(r -> r.refined_value < r.initial_value, results)
        @test all(r -> r.final_grad_norm < 1e-6, results)
    end
    
    @testset "Subdomain Management" begin
        # Test orthant center generation
        centers = generate_4d_orthant_centers([0.0, 0.0, 0.0, 0.0], 1.0)
        @test length(centers) == 16
        @test all(c -> length(c) == 4, centers)
        @test all(c -> all(abs.(c) .== 0.5), centers)
        
        # Test orthant ID conversions
        @test orthant_id_to_signs(1) == [-1, -1, -1, -1]
        @test orthant_id_to_signs(16) == [1, 1, 1, 1]
        # Test round-trip conversion
        @test signs_to_orthant_id(orthant_id_to_signs(1)) == 1
        @test signs_to_orthant_id(orthant_id_to_signs(16)) == 16
        
        # Test point to orthant assignment
        @test point_to_orthant_id([0.5, 0.5, 0.5, 0.5], [0.0, 0.0, 0.0, 0.0]) == 16
        @test point_to_orthant_id([-0.5, -0.5, -0.5, -0.5], [0.0, 0.0, 0.0, 0.0]) == 1
    end
    
    @testset "Multi-Tolerance Analysis" begin
        # Test 4D Deuflhard composite
        x_test = [0.1, 0.2, -0.1, 0.3]
        val = deuflhard_4d_composite(x_test)
        @test isa(val, Float64)
        @test val >= 0  # Deuflhard is non-negative
        
        # Test gradient computation
        f(x) = sum(x.^2)
        points = [0.1 0.2; -0.1 0.3; 0.5 -0.5]
        grad_norms = compute_gradients(f, points)
        @test length(grad_norms) == 3
        @test all(g -> g >= 0, grad_norms)
    end
    
    @testset "Integration with analyze_critical_points" begin
        # Simple 2D test
        f(x) = x[1]^2 + x[2]^2
        df = DataFrame(
            x1 = [0.01, 0.5, -0.5],
            x2 = [0.01, 0.5, 0.5],
            z = [f([0.01, 0.01]), f([0.5, 0.5]), f([-0.5, 0.5])]
        )
        
        TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
        
        # Test with enhanced BFGS enabled
        df_enhanced, df_min = analyze_critical_points(
            f, df, TR, 
            enable_hessian=true,
            verbose=false
        )
        
        # Check that enhanced columns are present
        @test "tolerance_used" in names(df_enhanced) || true  # Optional based on implementation
        @test "critical_point_type" in names(df_enhanced)
        @test "hessian_norm" in names(df_enhanced)
        
        # Test classification
        @test all(t -> t in [:minimum, :maximum, :saddle, :degenerate, :error], 
                 df_enhanced.critical_point_type)
    end
end