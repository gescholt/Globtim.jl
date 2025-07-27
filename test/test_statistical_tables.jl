# Tests for Phase 3 Statistical Tables
#
# Comprehensive test suite for the enhanced statistical table system

using Test
using DataFrames
using Statistics
using Globtim

@testset "Statistical Tables Tests" begin

    @testset "RobustStatistics Computation" begin
        # Test with normal data
        values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        stats = Globtim.compute_robust_statistics(values)

        @test stats.count == 10
        @test stats.mean ≈ 5.5
        @test stats.median ≈ 5.5
        @test stats.q1 ≈ 3.25
        @test stats.q3 ≈ 7.75
        @test stats.min == 1.0
        @test stats.max == 10.0
        @test stats.outlier_count == 0  # No outliers in this regular sequence

        # Test with outliers
        values_with_outliers = [1.0, 2.0, 3.0, 4.0, 5.0, 100.0]  # 100.0 is outlier
        stats_outliers = Globtim.compute_robust_statistics(values_with_outliers)

        @test stats_outliers.count == 6
        @test stats_outliers.outlier_count >= 1  # Should detect the outlier
        @test stats_outliers.outlier_percentage > 0

        # Test with empty data
        empty_stats = Globtim.compute_robust_statistics(Float64[])
        @test empty_stats.count == 0
        @test isnan(empty_stats.mean)
    end

    @testset "Condition Number Analysis" begin
        # Test with good condition numbers
        good_conditions = [1.0, 10.0, 100.0, 500.0]  # All excellent
        analysis = Globtim.compute_condition_number_analysis(good_conditions)

        @test analysis.total_count == 4
        @test analysis.excellent_count == 4
        @test analysis.good_count == 0
        @test analysis.overall_quality == "EXCELLENT"
        @test analysis.well_conditioned_percentage == 100.0

        # Test with mixed quality
        mixed_conditions = [10.0, 1e4, 1e7, 1e10, 1e13]  # Mix of qualities
        mixed_analysis = Globtim.compute_condition_number_analysis(mixed_conditions)

        @test mixed_analysis.total_count == 5
        @test mixed_analysis.excellent_count == 1  # 10.0
        @test mixed_analysis.good_count == 1       # 1e4
        @test mixed_analysis.fair_count == 1       # 1e7
        @test mixed_analysis.poor_count == 1       # 1e10
        @test mixed_analysis.critical_count == 1   # 1e13
        @test mixed_analysis.overall_quality in ["POOR", "FAIR"]

        # Test with empty data
        empty_analysis = Globtim.compute_condition_number_analysis(Float64[])
        @test empty_analysis.total_count == 0
        @test empty_analysis.overall_quality == "NO_DATA"
    end

    @testset "Mathematical Validation" begin
        # Create test DataFrame for minima
        minima_data = DataFrame(
            critical_point_type = [:minimum, :minimum, :minimum],
            smallest_positive_eigenval = [0.1, 0.5, 0.01],
            hessian_determinant = [0.05, 0.25, 0.001],
        )

        validation = Globtim.perform_mathematical_validation(minima_data, :minimum)
        @test validation.eigenvalue_signs_correct === true
        @test validation.positive_eigenvalue_count == 3
        @test validation.negative_eigenvalue_count == 0
        @test validation.determinant_positive === true

        # Create test DataFrame for maxima
        maxima_data = DataFrame(
            critical_point_type = [:maximum, :maximum],
            largest_negative_eigenval = [-0.1, -0.5],
            hessian_determinant = [0.05, 0.25],
        )

        max_validation = Globtim.perform_mathematical_validation(maxima_data, :maximum)
        @test max_validation.eigenvalue_signs_correct === true
        @test max_validation.negative_eigenvalue_count == 2

        # Create test DataFrame for saddles
        saddle_data = DataFrame(
            critical_point_type = [:saddle, :saddle],
            hessian_eigenvalue_min = [-0.1, -0.3],
            hessian_eigenvalue_max = [0.2, 0.4],
        )

        saddle_validation = Globtim.perform_mathematical_validation(saddle_data, :saddle)
        @test saddle_validation.mixed_eigenvalue_signs === true
    end

    @testset "Statistical Table Creation" begin
        # Create comprehensive test DataFrame
        test_df = DataFrame(
            critical_point_type = [:minimum, :minimum, :maximum, :saddle, :saddle],
            hessian_norm = [1.5, 2.3, 3.1, 1.8, 2.7],
            hessian_condition_number = [100.0, 500.0, 1e4, 1e7, 1e10],
            smallest_positive_eigenval = [0.1, 0.2, NaN, NaN, NaN],
            largest_negative_eigenval = [NaN, NaN, -0.3, NaN, NaN],
            hessian_eigenvalue_min = [-0.1, 0.05, -0.8, -0.2, -0.4],
            hessian_eigenvalue_max = [0.5, 0.8, -0.1, 0.3, 0.6],
            hessian_determinant = [0.05, 0.04, -0.08, -0.06, -0.24],
        )

        # Test statistics computation for minima
        minima_stats = Globtim.compute_type_specific_statistics(test_df, :minimum)
        @test minima_stats.point_type == :minimum
        @test minima_stats.hessian_stats.count == 2
        @test minima_stats.condition_analysis.total_count == 2
        @test !ismissing(minima_stats.validation_results.eigenvalue_signs_correct)

        # Test statistics computation for maxima
        maxima_stats = Globtim.compute_type_specific_statistics(test_df, :maximum)
        @test maxima_stats.point_type == :maximum
        @test maxima_stats.hessian_stats.count == 1

        # Test statistics computation for saddles
        saddle_stats = Globtim.compute_type_specific_statistics(test_df, :saddle)
        @test saddle_stats.point_type == :saddle
        @test saddle_stats.hessian_stats.count == 2

        # Test with empty type
        empty_stats = Globtim.compute_type_specific_statistics(test_df, :degenerate)
        @test empty_stats.hessian_stats.count == 0
    end

    @testset "Table Rendering" begin
        # Create test statistical table
        test_stats = Globtim.RobustStatistics(
            5,
            2.5,
            1.0,
            2.0,
            1.0,
            4.0,
            1.5,
            3.5,
            2.0,
            1,
            20.0,
            3.0,
        )
        test_condition = Globtim.ConditionNumberAnalysis(
            5,
            3,
            2,
            0,
            0,
            0,
            100.0,
            "EXCELLENT",
            ["All conditions excellent"],
        )
        test_validation = Globtim.ValidationResults(
            true,
            5,
            0,
            missing,
            true,
            missing,
            Dict{String,Any}(),
        )

        comprehensive_table = Globtim.ComprehensiveStatsTable(
            :minimum,
            test_stats,
            test_condition,
            test_validation,
            missing,
            :console,
        )

        # Test table rendering
        rendered_table = Globtim.render_console_table(comprehensive_table, width = 80)
        @test isa(rendered_table, String)
        @test length(rendered_table) > 100  # Should be substantial content
        @test contains(rendered_table, "MINIMUM STATISTICS")
        @test contains(rendered_table, "CONDITION NUMBER QUALITY")
        @test contains(rendered_table, "MATHEMATICAL VALIDATION")
        @test contains(rendered_table, "5")  # Count should appear
        @test contains(rendered_table, "2.5")  # Mean should appear
        @test contains(rendered_table, "EXCELLENT")  # Quality should appear
        @test contains(rendered_table, "✓")  # Validation checkmark should appear

        # Test border characters are present
        @test contains(rendered_table, "┌")
        @test contains(rendered_table, "└")
        @test contains(rendered_table, "│")
        @test contains(rendered_table, "─")
    end

    @testset "Comparative Table Rendering" begin
        # Create multiple statistical tables for comparison
        stats1 = Globtim.ComprehensiveStatsTable(
            :minimum,
            Globtim.RobustStatistics(
                3,
                2.0,
                0.5,
                2.0,
                1.5,
                2.5,
                1.75,
                2.25,
                0.5,
                0,
                0.0,
                1.0,
            ),
            Globtim.ConditionNumberAnalysis(3, 3, 0, 0, 0, 0, 100.0, "EXCELLENT", String[]),
            Globtim.ValidationResults(
                true,
                3,
                0,
                missing,
                true,
                missing,
                Dict{String,Any}(),
            ),
            missing,
            :console,
        )

        stats2 = Globtim.ComprehensiveStatsTable(
            :maximum,
            Globtim.RobustStatistics(
                2,
                3.0,
                1.0,
                3.0,
                2.0,
                4.0,
                2.5,
                3.5,
                1.0,
                0,
                0.0,
                2.0,
            ),
            Globtim.ConditionNumberAnalysis(2, 1, 1, 0, 0, 0, 100.0, "EXCELLENT", String[]),
            Globtim.ValidationResults(
                true,
                0,
                2,
                missing,
                missing,
                true,
                Dict{String,Any}(),
            ),
            missing,
            :console,
        )

        stats_list = [stats1, stats2]
        comparative_table = Globtim.render_comparative_table(stats_list, width = 100)

        @test isa(comparative_table, String)
        @test contains(comparative_table, "COMPARATIVE ANALYSIS")
        @test contains(comparative_table, "Minimum")
        @test contains(comparative_table, "Maximum")
        @test contains(comparative_table, "SUMMARY")
        @test contains(comparative_table, "Total critical points")
    end

    @testset "Helper Functions" begin
        # Test formatting functions
        @test Globtim.format_validation_key("eigenvalue_signs_correct") ==
              "Eigenvalue signs correct"
        @test Globtim.format_validation_value(true) == "✓ YES"
        @test Globtim.format_validation_value(false) == "✗ NO"
        @test Globtim.format_validation_value(missing) == "N/A"

        # Test border creation
        border_top = Globtim.create_table_border(50, :top)
        @test startswith(border_top, "┌")
        @test endswith(border_top, "┐")
        @test length(border_top) == 50

        border_bottom = Globtim.create_table_border(50, :bottom)
        @test startswith(border_bottom, "└")
        @test endswith(border_bottom, "┘")

        # Test row formatting
        row = Globtim.format_table_row("Test Label", "Test Value", 50)
        @test startswith(row, "│")
        @test endswith(row, "│")
        @test contains(row, "Test Label")
        @test contains(row, "Test Value")

        # Test center text
        centered = Globtim.center_text("│", "TITLE", 20, "│")
        @test startswith(centered, "│")
        @test endswith(centered, "│")
        @test contains(centered, "TITLE")
        @test length(centered) == 20  # Should match the specified width
    end

    @testset "Edge Cases and Error Handling" begin
        # Test with very wide table request
        wide_stats = Globtim.ComprehensiveStatsTable(
            :minimum,
            Globtim.RobustStatistics(
                1,
                1.0,
                0.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                0.0,
                0,
                0.0,
                0.0,
            ),
            Globtim.ConditionNumberAnalysis(1, 1, 0, 0, 0, 0, 100.0, "EXCELLENT", String[]),
            Globtim.ValidationResults(
                missing,
                missing,
                missing,
                missing,
                missing,
                missing,
                Dict{String,Any}(),
            ),
            missing,
            :console,
        )

        wide_table = Globtim.render_console_table(wide_stats, width = 200)
        @test isa(wide_table, String)
        @test length(wide_table) > 0

        # Test with very narrow table request
        narrow_table = Globtim.render_console_table(wide_stats, width = 30)
        @test isa(narrow_table, String)
        @test length(narrow_table) > 0

        # Test with missing validation data
        no_validation_stats = Globtim.ComprehensiveStatsTable(
            :saddle,
            Globtim.RobustStatistics(
                1,
                1.0,
                0.0,
                1.0,
                1.0,
                1.0,
                1.0,
                1.0,
                0.0,
                0,
                0.0,
                0.0,
            ),
            Globtim.ConditionNumberAnalysis(0, 0, 0, 0, 0, 0, 0.0, "NO_DATA", String[]),
            Globtim.ValidationResults(
                missing,
                missing,
                missing,
                missing,
                missing,
                missing,
                Dict{String,Any}(),
            ),
            missing,
            :console,
        )

        no_val_table = Globtim.render_console_table(no_validation_stats, width = 80)
        @test isa(no_val_table, String)
        @test contains(no_val_table, "SADDLE STATISTICS")

        # Test empty comparative table
        empty_comparative =
            Globtim.render_comparative_table(Globtim.ComprehensiveStatsTable[], width = 80)
        @test contains(empty_comparative, "No data available")
    end
end

println("Statistical Tables test suite completed successfully!")
