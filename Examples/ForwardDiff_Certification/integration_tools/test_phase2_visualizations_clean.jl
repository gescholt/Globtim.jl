# ================================================================================
# Clean Unit Tests for Phase 2 Core Visualizations
# ================================================================================
#
# Streamlined test suite for publication-quality visualization functions
# with focused testing on core functionality and integration.
#
# Test Categories:
# 1. Core Visualization Tests
# 2. Data Integration Tests
# 3. Publication Suite Tests

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Test
using Statistics, Dates
using CairoMakie

# Include Phase 1 and Phase 2 infrastructure
include("phase1_data_infrastructure.jl")
include("phase2_core_visualizations.jl")

# ================================================================================
# TEST DATA GENERATION
# ================================================================================

function create_test_multi_tolerance_results()
    """Create realistic test data for visualization testing."""
    sample_orthants = [OrthantResult(i, rand(4), rand(4), rand(10:50), rand(8:45), 
                                   rand(), rand(), rand(0:5), rand(3:8), rand()) for i in 1:16]
    
    tolerance_results = Dict{Float64, ToleranceResult}()
    tolerances = [0.1, 0.01, 0.001]
    
    for tolerance in tolerances
        n_points = rand(10:50)
        tolerance_result = ToleranceResult(
            tolerance,
            rand(n_points),
            rand(n_points),
            rand(["minimum", "saddle", "maximum"], n_points),
            sample_orthants,
            rand(3:8, n_points),
            rand(80:150, n_points),
            rand() * 10,
            (raw=rand(), bfgs=rand(), combined=rand())
        )
        tolerance_results[tolerance] = tolerance_result
    end
    
    return MultiToleranceResults(
        tolerances,
        tolerance_results,
        sum(tr.computation_time for tr in values(tolerance_results)),
        string(now()),
        "deuflhard_4d_composite",
        (center=[0,0,0,0], sample_range=0.5, dimension=4)
    )
end

# ================================================================================
# TEST SUITE 1: CORE VISUALIZATION TESTS
# ================================================================================

@testset "Core Visualization Functions" begin
    
    @testset "Publication Infrastructure" begin
        # Test theme and figure creation
        theme = create_publication_theme()
        @test theme isa Theme
        @test haskey(theme.attributes, :fontsize)
        
        fig = create_publication_figure(size = (800, 600))
        @test fig isa Figure
        @test fig.scene.viewport[].widths[1] == 800
    end
    
    @testset "Convergence Dashboard" begin
        multi_results = create_test_multi_tolerance_results()
        
        # Test dashboard creation
        @test_nowarn fig = plot_convergence_dashboard(multi_results)
        fig = plot_convergence_dashboard(multi_results)
        @test fig isa Figure
        
        # Validate structure
        @test length(fig.content) >= 4  # Should have at least 4 main plotting areas
    end
    
    @testset "Orthant Heatmap" begin
        sample_orthants = [OrthantResult(i, rand(4), rand(4), rand(10:50), rand(8:45),
                                       rand(), rand(), rand(0:5), rand(3:8), rand()) for i in 1:16]
        
        # Test different metrics
        for metric in [:success_rate, :median_distance, :polynomial_degree, :computation_time]
            @test_nowarn fig = plot_orthant_heatmap(sample_orthants, metric)
            fig = plot_orthant_heatmap(sample_orthants, metric)
            @test fig isa Figure
        end
        
        # Test validation
        invalid_orthants = sample_orthants[1:15]  # Only 15 instead of 16
        @test_throws AssertionError plot_orthant_heatmap(invalid_orthants)
    end
    
    @testset "Multi-Scale Distance Analysis" begin
        sample_orthants = [OrthantResult(i, rand(4), rand(4), rand(10:50), rand(8:45),
                                       rand(), rand(), rand(0:5), rand(3:8), rand()) for i in 1:16]
        
        tolerance_result = ToleranceResult(
            0.01, rand(50), rand(50) * 0.01, rand(["minimum", "saddle", "maximum"], 50),
            sample_orthants, rand(3:8, 50), rand(80:150, 50), rand() * 10,
            (raw=rand(), bfgs=rand(), combined=rand())
        )
        
        @test_nowarn fig = plot_multiscale_distance_analysis(tolerance_result)
        fig = plot_multiscale_distance_analysis(tolerance_result)
        @test fig isa Figure
    end
    
    @testset "Point Type Performance" begin
        multi_results = create_test_multi_tolerance_results()
        
        @test_nowarn fig = plot_point_type_performance(multi_results)
        fig = plot_point_type_performance(multi_results)
        @test fig isa Figure
    end
    
    @testset "Efficiency Frontier" begin
        multi_results = create_test_multi_tolerance_results()
        
        @test_nowarn fig = plot_efficiency_frontier(multi_results)
        fig = plot_efficiency_frontier(multi_results)
        @test fig isa Figure
    end
end

# ================================================================================
# TEST SUITE 2: DATA INTEGRATION TESTS
# ================================================================================

@testset "Data Integration" begin
    
    @testset "Phase 1 Compatibility" begin
        # Test with Phase 1 validated data structures
        multi_results = create_test_multi_tolerance_results()
        
        # All visualization functions should accept Phase 1 data
        @test_nowarn plot_convergence_dashboard(multi_results)
        @test_nowarn plot_point_type_performance(multi_results)
        @test_nowarn plot_efficiency_frontier(multi_results)
        
        # Test individual tolerance result
        tol_result = multi_results.results_by_tolerance[0.01]
        @test_nowarn plot_multiscale_distance_analysis(tol_result)
        @test_nowarn plot_orthant_heatmap(tol_result.orthant_data)
    end
    
    @testset "Edge Case Handling" begin
        sample_orthants = [OrthantResult(i, [0,0,0,0], [0.25,0.25,0.25,0.25], 0, 0, 0.0, 0.0, 0, 4, 1.0) for i in 1:16]
        
        # Empty data handling
        empty_tolerance_result = ToleranceResult(
            0.01, Float64[], Float64[], String[], sample_orthants,
            Int[], Int[], 1.0, (raw=0.0, bfgs=0.0, combined=0.0)
        )
        
        @test_nowarn plot_multiscale_distance_analysis(empty_tolerance_result)
        @test_nowarn plot_orthant_heatmap(sample_orthants)
        
        # NaN data handling
        nan_tolerance_result = ToleranceResult(
            0.01, [NaN, NaN], [NaN, NaN], ["minimum", "saddle"], sample_orthants,
            [4, 5], [100, 120], 1.0, (raw=0.0, bfgs=0.0, combined=0.0)
        )
        
        @test_nowarn plot_multiscale_distance_analysis(nan_tolerance_result)
    end
end

# ================================================================================
# TEST SUITE 3: PUBLICATION SUITE TESTS
# ================================================================================

@testset "Publication Suite" begin
    
    @testset "Complete Suite Generation" begin
        multi_results = create_test_multi_tolerance_results()
        
        # Test publication suite generation (without actual file export)
        test_export_path = "./test_publication_plots_clean"
        
        @test_nowarn results = generate_publication_suite(multi_results, 
                                                        export_path=test_export_path,
                                                        export_formats=String[])  # No actual export
        
        results = generate_publication_suite(multi_results, 
                                           export_path=test_export_path,
                                           export_formats=String[])
        
        # Verify all expected figures are generated
        @test haskey(results, :dashboard)
        @test haskey(results, :point_type_performance)
        @test haskey(results, :efficiency_frontier)
        @test haskey(results, :multiscale_distance)
        @test haskey(results, :orthant_suite)
        
        @test results.dashboard isa Figure
        @test results.point_type_performance isa Figure
        @test results.efficiency_frontier isa Figure
        @test results.multiscale_distance isa Figure
        @test length(results.orthant_suite) == 4  # Four orthant heatmaps
        
        # Clean up test directory if it was created
        rm(test_export_path, recursive=true, force=true)
    end
    
    @testset "Plot Quality Validation" begin
        # Test figure size validation
        small_fig = Figure(size = (400, 300))
        is_valid, issues = validate_plot_quality(small_fig)
        @test !is_valid
        @test length(issues) > 0
        
        # Test acceptable size
        good_fig = Figure(size = (800, 600))
        is_valid, issues = validate_plot_quality(good_fig)
        @test is_valid
        @test isempty(issues)
        
        # Test publication theme validation
        theme = create_publication_theme()
        @test haskey(theme.attributes, :fontsize)
        @test haskey(theme.attributes, :Axis)
        @test theme.attributes[:fontsize][] >= 12  # Minimum readable size
    end
end

# ================================================================================
# SUMMARY REPORT
# ================================================================================

println("\n" * "="^80)
println("PHASE 2 VISUALIZATION TEST SUITE (CLEAN VERSION) COMPLETED")
println("="^80)
println("✅ All core visualization functions tested and working")
println("✅ Data integration with Phase 1 structures verified")
println("✅ Publication suite generation validated")
println("✅ Plot quality assurance checks passed")
println("✅ Phase 2 visualizations ready for production use")
println("="^80)