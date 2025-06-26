# Test Phase 2: Hessian Analysis Unit Tests

using Test
using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames

@testset "Phase 2: Hessian Analysis Tests" begin
    
    @testset "compute_hessians" begin
        # Test on simple quadratic function
        f_quad(x) = x[1]^2 + 2*x[2]^2
        points = [0.0 0.0; 1.0 1.0]  # 2 points in 2D
        
        hessians = compute_hessians(f_quad, points)
        
        @test length(hessians) == 2
        @test size(hessians[1]) == (2, 2)
        
        # Expected Hessian for quadratic: [2 0; 0 4]
        @test isapprox(hessians[1], [2.0 0.0; 0.0 4.0], atol=1e-10)
        @test isapprox(hessians[2], [2.0 0.0; 0.0 4.0], atol=1e-10)  # Same for all points
    end
    
    @testset "classify_critical_points" begin
        # Create test Hessian matrices
        H_min = [2.0 0.0; 0.0 3.0]     # Positive definite (minimum)
        H_max = [-2.0 0.0; 0.0 -3.0]   # Negative definite (maximum)
        H_saddle = [2.0 0.0; 0.0 -3.0] # Indefinite (saddle)
        H_degen = [2.0 0.0; 0.0 0.0]   # Singular (degenerate)
        H_nan = [NaN NaN; NaN NaN]     # Error case
        
        hessians = [H_min, H_max, H_saddle, H_degen, H_nan]
        classifications = classify_critical_points(hessians)
        
        @test classifications[1] == :minimum
        @test classifications[2] == :maximum
        @test classifications[3] == :saddle
        @test classifications[4] == :degenerate
        @test classifications[5] == :error
    end
    
    @testset "store_all_eigenvalues" begin
        H1 = [2.0 0.0; 0.0 3.0]
        H2 = [-1.0 0.0; 0.0 -2.0]
        hessians = [H1, H2]
        
        all_eigenvalues = store_all_eigenvalues(hessians)
        
        @test length(all_eigenvalues) == 2
        @test length(all_eigenvalues[1]) == 2
        @test isapprox(sort(all_eigenvalues[1]), [2.0, 3.0], atol=1e-10)
        @test isapprox(sort(all_eigenvalues[2]), [-2.0, -1.0], atol=1e-10)
    end
    
    @testset "extract_critical_eigenvalues" begin
        classifications = [:minimum, :maximum, :saddle, :degenerate]
        all_eigenvalues = [
            [2.0, 3.0],      # minimum
            [-2.0, -1.0],    # maximum
            [-1.0, 2.0],     # saddle
            [0.0, 2.0]       # degenerate
        ]
        
        smallest_pos, largest_neg = extract_critical_eigenvalues(classifications, all_eigenvalues)
        
        @test isapprox(smallest_pos[1], 2.0, atol=1e-10)  # minimum
        @test isnan(smallest_pos[2])                       # maximum
        @test isnan(smallest_pos[3])                       # saddle
        @test isnan(smallest_pos[4])                       # degenerate
        
        @test isnan(largest_neg[1])                        # minimum
        @test isapprox(largest_neg[2], -1.0, atol=1e-10)  # maximum
        @test isnan(largest_neg[3])                        # saddle
        @test isnan(largest_neg[4])                        # degenerate
    end
    
    @testset "compute_hessian_norms" begin
        H1 = [1.0 0.0; 0.0 1.0]  # Identity matrix
        H2 = [2.0 0.0; 0.0 2.0]  # 2*Identity
        hessians = [H1, H2]
        
        norms = compute_hessian_norms(hessians)
        
        @test isapprox(norms[1], sqrt(2), atol=1e-10)  # ||I||_F = √2
        @test isapprox(norms[2], 2*sqrt(2), atol=1e-10)  # ||2I||_F = 2√2
    end
    
    @testset "compute_eigenvalue_stats" begin
        H1 = [2.0 0.0; 0.0 3.0]
        H2 = [-1.0 0.0; 0.0 -2.0]
        hessians = [H1, H2]
        
        stats = compute_eigenvalue_stats(hessians)
        
        @test size(stats) == (2, 5)
        @test isapprox(stats.eigenvalue_min[1], 2.0, atol=1e-10)
        @test isapprox(stats.eigenvalue_max[1], 3.0, atol=1e-10)
        @test isapprox(stats.condition_number[1], 3.0/2.0, atol=1e-10)
        @test isapprox(stats.determinant[1], 6.0, atol=1e-10)
        @test isapprox(stats.trace[1], 5.0, atol=1e-10)
    end
    
    @testset "Integration with analyze_critical_points" begin
        # Test simple quadratic function
        f_quad(x) = (x[1] - 1)^2 + (x[2] + 0.5)^2
        
        # Test with Phase 2 enabled (separate DataFrame)
        TR1 = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
        pol1 = Constructor(TR1, 6)
        @polyvar x[1:2]
        real_pts1 = solve_polynomial_system(x, 2, 6, pol1.coeffs)
        df1 = process_crit_pts(real_pts1, f_quad, TR1)
        
        df_enhanced, df_min = analyze_critical_points(f_quad, df1, TR1, enable_hessian=true, verbose=false)
        
        @test "critical_point_type" in names(df_enhanced)
        @test "hessian_norm" in names(df_enhanced)
        @test "smallest_positive_eigenval" in names(df_enhanced)
        @test "largest_negative_eigenval" in names(df_enhanced)
        @test "hessian_eigenvalue_min" in names(df_enhanced)
        @test "hessian_eigenvalue_max" in names(df_enhanced)
        @test "hessian_condition_number" in names(df_enhanced)
        @test "hessian_determinant" in names(df_enhanced)
        @test "hessian_trace" in names(df_enhanced)
        
        # Should find at least one minimum (the global minimum)
        minima_count = count(df_enhanced.critical_point_type .== :minimum)
        @test minima_count >= 1
        
        # Test with Phase 2 disabled (separate DataFrame)
        TR2 = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
        pol2 = Constructor(TR2, 6)
        real_pts2 = solve_polynomial_system(x, 2, 6, pol2.coeffs)
        df2 = process_crit_pts(real_pts2, f_quad, TR2)
        
        df_phase1, df_min_phase1 = analyze_critical_points(f_quad, df2, TR2, enable_hessian=false, verbose=false)
        
        @test !("critical_point_type" in names(df_phase1))
        @test !("hessian_norm" in names(df_phase1))
        
        # Ensure Phase 1 columns are still there
        @test "region_id" in names(df_phase1)
        @test "function_value_cluster" in names(df_phase1)
        @test "nearest_neighbor_dist" in names(df_phase1)
        @test "gradient_norm" in names(df_phase1)
    end
    
    @testset "Error Handling" begin
        # Test with function that might cause issues
        f_problematic(x) = x[1]^4 - x[1]^2  # Has flat regions
        
        points = [0.0 0.0; 1e-10 1e-10]  # Very close to degenerate points
        
        # Should not throw errors
        hessians = compute_hessians(f_problematic, points)
        @test length(hessians) == 2
        
        all_eigenvalues = store_all_eigenvalues(hessians)
        @test length(all_eigenvalues) == 2
        
        classifications = classify_critical_points(hessians)
        @test length(classifications) == 2
        @test all(c -> c in [:minimum, :maximum, :saddle, :degenerate, :error], classifications)
    end
    
    # Note: Visualization function tests removed from test suite
    # Graphical tests should be run separately in interactive sessions
end

println("All Phase 2 Hessian analysis tests completed!")