# Integration Tests for Phase 3 Enhanced Analysis
#
# Test the complete workflow of enhanced statistical analysis with real data

using Test
using DataFrames
using Globtim
using DynamicPolynomials

@testset "Enhanced Analysis Integration Tests" begin
    
    @testset "End-to-End Workflow Test" begin
        # Set up a simple test problem
        f = x -> x[1]^2 + 2*x[2]^2  # Simple quadratic with known minimum at origin
        TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=0.5, GN=15)
        pol = Constructor(TR, 4)  # Low degree for fast testing
        
        @polyvar x[1:2]
        solutions = solve_polynomial_system(x, 2, 4, pol.coeffs)
        df = process_crit_pts(solutions, f, TR)
        
        # Test enhanced analysis with tables (without display)
        df_enhanced, df_min, tables, stats_objects = analyze_critical_points_with_tables(
            f, df, TR,
            enable_hessian=true,
            show_tables=false,  # Don't print during tests
            table_format=:console,
            table_types=[:minimum, :maximum, :saddle]
        )
        
        # Verify basic structure
        @test isa(df_enhanced, DataFrame)
        @test isa(df_min, DataFrame)
        @test isa(tables, Dict{Symbol, String})
        @test isa(stats_objects, Dict{Symbol, Globtim.ComprehensiveStatsTable})
        
        # Check that Phase 2 columns are present
        @test hasproperty(df_enhanced, :critical_point_type)
        @test hasproperty(df_enhanced, :hessian_norm)
        @test hasproperty(df_enhanced, :hessian_condition_number)
        
        # Verify that we got some critical points
        @test nrow(df_enhanced) > 0
        
        # Check that we have at least one minimum (quadratic should have one)
        minima_count = sum(df_enhanced.critical_point_type .== :minimum)
        @test minima_count >= 1
        
        # Verify tables were generated for types that exist
        for point_type in keys(stats_objects)
            @test haskey(tables, point_type)
            @test isa(tables[point_type], String)
            @test length(tables[point_type]) > 100  # Should have substantial content
            @test contains(tables[point_type], uppercase(string(point_type)))
        end
        
        # Test that statistical objects have correct structure
        for (point_type, stats) in stats_objects
            @test stats.point_type == point_type
            @test stats.hessian_stats.count > 0
            @test isa(stats.condition_analysis, Globtim.ConditionNumberAnalysis)
            @test isa(stats.validation_results, Globtim.ValidationResults)
        end
    end
    
    @testset "Quick Preview Functionality" begin
        # Test quick preview function
        f = x -> sum(x.^2)  # Simple n-dimensional quadratic
        TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=0.3, GN=10)
        pol = Constructor(TR, 3)
        
        @polyvar x[1:2]
        solutions = solve_polynomial_system(x, 2, 3, pol.coeffs)
        df = process_crit_pts(solutions, f, TR)
        
        # Test that quick_table_preview doesn't error
        # (We can't easily test output since it prints to stdout)
        # Suppress info messages during testing
        @test_nowarn begin
            redirect_stderr(devnull) do
                quick_table_preview(f, df, TR, point_types=[:minimum])
            end
        end
    end
    
    @testset "Statistical Summary Generation" begin
        # Create test DataFrame with known critical point types
        test_df = DataFrame(
            critical_point_type = [:minimum, :minimum, :maximum, :saddle, :saddle, :degenerate],
            function_value = [1.0, 1.1, 5.0, 3.0, 3.2, 2.5]
        )
        
        summary = create_statistical_summary(test_df)
        @test isa(summary, String)
        @test contains(summary, "CRITICAL POINT SUMMARY")
        @test contains(summary, "Minimum")
        @test contains(summary, "Maximum") 
        @test contains(summary, "Saddle")
        @test contains(summary, "Degenerate")
        @test contains(summary, "TOTAL")
        @test contains(summary, "6")  # Total count
    end
    
    @testset "Export Functionality" begin
        # Create minimal test data
        test_tables = Dict{Symbol, String}(
            :minimum => "Test minimum table content",
            :maximum => "Test maximum table content"
        )
        
        # Test export without timestamp (easier to test)
        temp_dir = mktempdir()
        base_filename = joinpath(temp_dir, "test_export")
        
        # Suppress info messages during testing
        @test_nowarn begin
            redirect_stderr(devnull) do
                export_analysis_tables(
                    test_tables, base_filename,
                    formats=[:console],
                    include_timestamp=false
                )
            end
        end
        
        # Check files were created
        @test isfile("$(base_filename)_minimum.txt")
        @test isfile("$(base_filename)_maximum.txt")
        
        # Check file contents
        min_content = read("$(base_filename)_minimum.txt", String)
        @test min_content == "Test minimum table content"
        
        max_content = read("$(base_filename)_maximum.txt", String)
        @test max_content == "Test maximum table content"
        
        # Clean up
        rm(temp_dir, recursive=true)
    end
    
    @testset "Display Function" begin
        # Create test statistical table
        test_stats = Globtim.ComprehensiveStatsTable(
            :minimum,
            Globtim.RobustStatistics(3, 2.0, 0.5, 2.0, 1.5, 2.5, 1.75, 2.25, 0.5, 0, 0.0, 1.0),
            Globtim.ConditionNumberAnalysis(3, 3, 0, 0, 0, 0, 100.0, "EXCELLENT", String[]),
            Globtim.ValidationResults(true, 3, 0, missing, true, missing, Dict{String, Any}()),
            missing, :console
        )
        
        # Test display function doesn't error and returns a string
        displayed_table = display_statistical_table(test_stats, width=60)
        @test isa(displayed_table, String)
        @test contains(displayed_table, "MINIMUM STATISTICS")
    end
    
    @testset "Robustness with Different Functions" begin
        # Test with a more complex function
        f_complex = x -> sin(x[1]) * cos(x[2]) + 0.1 * (x[1]^2 + x[2]^2)
        TR_complex = test_input(f_complex, dim=2, center=[0.0, 0.0], sample_range=1.0, GN=12)
        pol_complex = Constructor(TR_complex, 6)
        
        @polyvar x[1:2]
        solutions_complex = solve_polynomial_system(x, 2, 6, pol_complex.coeffs)
        df_complex = process_crit_pts(solutions_complex, f_complex, TR_complex)
        
        # Test that enhanced analysis works with complex functions
        @test_nowarn df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
            f_complex, df_complex, TR_complex,
            enable_hessian=true,
            show_tables=false,
            table_types=[:minimum, :maximum, :saddle]
        )
    end
    
    @testset "Error Handling and Edge Cases" begin
        # Test with empty DataFrame (needs hessian columns for Phase 3)
        empty_df = DataFrame(
            critical_point_type = Symbol[],
            function_value = Float64[],
            hessian_norm = Float64[],
            hessian_condition_number = Float64[]
        )
        
        @test_nowarn stats = compute_type_specific_statistics(empty_df, :minimum)
        @test stats.hessian_stats.count == 0
        
        # Test with DataFrame missing required columns
        incomplete_df = DataFrame(
            some_other_column = [1, 2, 3]
        )
        
        @test_nowarn stats = compute_type_specific_statistics(incomplete_df, :minimum)
        @test stats.hessian_stats.count == 0
        
        # Test with all NaN values
        nan_df = DataFrame(
            critical_point_type = [:minimum, :minimum],
            hessian_norm = [NaN, NaN],
            hessian_condition_number = [NaN, NaN]
        )
        
        @test_nowarn stats = compute_type_specific_statistics(nan_df, :minimum)
        @test stats.hessian_stats.count == 0  # Should handle NaN values
    end
    
    @testset "Performance and Memory" begin
        # Test with larger dataset to ensure reasonable performance
        large_df = DataFrame(
            critical_point_type = repeat([:minimum, :maximum, :saddle], 50),
            hessian_norm = randn(150) .+ 2.0,
            hessian_condition_number = 10.0 .^ (3 * randn(150) .+ 5),
            smallest_positive_eigenval = abs.(randn(150) .+ 0.1),
            largest_negative_eigenval = -abs.(randn(150) .+ 0.1),
            hessian_eigenvalue_min = randn(150),
            hessian_eigenvalue_max = abs.(randn(150)),
            hessian_determinant = randn(150)
        )
        
        # Time the computation (should be reasonably fast)
        start_time = time()
        stats = compute_type_specific_statistics(large_df, :minimum)
        elapsed = time() - start_time
        
        @test elapsed < 1.0  # Should complete in less than 1 second
        @test stats.hessian_stats.count == 50  # Should find 50 minima
        
        # Test table rendering with large dataset
        start_time = time()
        rendered_table = render_console_table(stats, width=80)
        elapsed = time() - start_time
        
        @test elapsed < 0.5  # Rendering should be fast
        @test isa(rendered_table, String)
        @test length(rendered_table) > 100
    end
end

println("Enhanced Analysis Integration test suite completed successfully!")