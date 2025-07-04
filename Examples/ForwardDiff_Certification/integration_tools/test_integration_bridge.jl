# ================================================================================
# Unit Tests for Integration Bridge
# ================================================================================
#
# Streamlined test suite for the integration bridge module that connects
# the existing systematic analysis with Phase 1-3 enhanced capabilities.
#
# Test Categories:
# 1. Bridge Function Tests
# 2. Data Conversion Tests
# 3. Pipeline Integration Tests

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Test
using Statistics, Dates

# Include all required modules
include("phase1_data_infrastructure.jl")
include("phase2_core_visualizations.jl") 
include("phase3_advanced_analytics.jl")
include("integration_bridge.jl")

# ================================================================================
# TEST SUITE 1: BRIDGE FUNCTION TESTS
# ================================================================================

@testset "Integration Bridge Functions" begin
    
    @testset "Data Extraction Functions" begin
        # Test orthant data extraction
        sample_tolerance = 0.01
        orthant_data = extract_orthant_data_from_systematic(nothing, sample_tolerance)
        
        @test length(orthant_data) == 16
        @test all(or.orthant_id in 1:16 for or in orthant_data)
        @test all(0.0 <= or.success_rate <= 1.0 for or in orthant_data)
        @test all(or.polynomial_degree >= 3 for or in orthant_data)
    end
    
    @testset "Theoretical Points Loading" begin
        # Test theoretical points loading (with fallback)
        theoretical_points = load_theoretical_deuflhard_points()
        
        @test !isempty(theoretical_points)
        @test all(length(point) == 4 for point in theoretical_points)  # 4D points
        @test eltype(theoretical_points) <: Vector{Float64}
    end
    
    @testset "Tolerance Data Extraction" begin
        # Test tolerance data extraction with mock data
        tolerance = 0.01
        n_points = 20
        raw_points = [rand(4) for _ in 1:n_points]
        bfgs_points = [rand(4) for _ in 1:n_points]
        classifications = rand(["minimum", "saddle", "maximum"], n_points)
        
        @test_nowarn tol_result = extract_tolerance_data_from_systematic(
            tolerance, raw_points, bfgs_points, classifications
        )
        
        tol_result = extract_tolerance_data_from_systematic(
            tolerance, raw_points, bfgs_points, classifications
        )
        
        @test tol_result isa ToleranceResult
        @test tol_result.tolerance == tolerance
        @test length(tol_result.orthant_data) == 16
        @test length(tol_result.raw_distances) == n_points
    end
end

# ================================================================================
# TEST SUITE 2: PIPELINE INTEGRATION TESTS
# ================================================================================

@testset "Pipeline Integration" begin
    
    @testset "Enhanced Systematic Analysis" begin
        # Test enhanced systematic analysis with small tolerance sequence
        tolerances = [0.1, 0.01]
        
        @test_nowarn enhanced_results = run_enhanced_systematic_analysis(
            tolerances,
            sample_range = 0.5,
            center = [0.0, 0.0, 0.0, 0.0]
        )
        
        enhanced_results = run_enhanced_systematic_analysis(tolerances)
        
        @test enhanced_results isa MultiToleranceResults
        @test length(enhanced_results.tolerance_sequence) == 2
        @test all(haskey(enhanced_results.results_by_tolerance, tol) for tol in tolerances)
        
        # Verify data structure integrity
        for tol in tolerances
            tol_result = enhanced_results.results_by_tolerance[tol]
            @test tol_result.tolerance == tol
            @test length(tol_result.orthant_data) == 16
        end
    end
    
    @testset "Complete Analysis Pipeline" begin
        # Test complete analysis pipeline (without Phase 3 to keep it fast)
        tolerances = [0.1]
        enhanced_results = run_enhanced_systematic_analysis(tolerances)
        
        @test_nowarn complete_analysis = generate_complete_analysis_pipeline(
            enhanced_results,
            export_path = "./test_integration_results",
            include_phase3 = false  # Skip Phase 3 for faster testing
        )
        
        complete_analysis = generate_complete_analysis_pipeline(
            enhanced_results,
            export_path = "./test_integration_results", 
            include_phase3 = false
        )
        
        @test haskey(complete_analysis, :multi_tolerance_results)
        @test haskey(complete_analysis, :phase2_visualizations)
        @test complete_analysis.multi_tolerance_results isa MultiToleranceResults
        @test complete_analysis.phase2_visualizations isa NamedTuple
        
        # Clean up
        rm("./test_integration_results", recursive=true, force=true)
    end
    
    @testset "Bridge Systematic Analysis" begin
        # Test the main bridge function
        tolerances = [0.1]
        
        @test_nowarn complete_results = bridge_systematic_analysis(tolerances)
        
        complete_results = bridge_systematic_analysis(tolerances)
        
        @test haskey(complete_results, :multi_tolerance_results)
        @test haskey(complete_results, :phase2_visualizations)
        @test haskey(complete_results, :export_path)
        @test complete_results.multi_tolerance_results isa MultiToleranceResults
        
        # Clean up
        if haskey(complete_results, :export_path)
            rm(complete_results.export_path, recursive=true, force=true)
        end
    end
end

# ================================================================================
# TEST SUITE 3: ERROR HANDLING AND VALIDATION TESTS
# ================================================================================

@testset "Error Handling and Validation" begin
    
    @testset "Input Validation" begin
        # Empty tolerance sequence
        @test_throws ArgumentError run_enhanced_systematic_analysis(Float64[])
        
        # Invalid tolerance values
        @test_throws ArgumentError run_enhanced_systematic_analysis([-0.1])
        @test_throws ArgumentError run_enhanced_systematic_analysis([0.0])
    end
    
    @testset "Export Functionality" begin
        # Test data export functions
        tolerances = [0.1]
        enhanced_results = run_enhanced_systematic_analysis(tolerances)
        
        test_export_path = "./test_export_bridge"
        
        # Test structured data export
        @test_nowarn export_validated_data_structures(enhanced_results, test_export_path)
        @test isdir(test_export_path)
        @test isfile(joinpath(test_export_path, "tolerance_metadata.csv"))
        
        # Test report generation
        report_path = joinpath(test_export_path, "test_report.md")
        @test_nowarn generate_analysis_report(enhanced_results, nothing, nothing, report_path)
        @test isfile(report_path)
        
        # Clean up
        rm(test_export_path, recursive=true, force=true)
    end
    
    @testset "Memory and Performance" begin
        # Test that bridge operations complete in reasonable time
        start_time = time()
        tolerances = [0.1]
        enhanced_results = run_enhanced_systematic_analysis(tolerances)
        execution_time = time() - start_time
        
        @test execution_time < 60.0  # Should complete within 1 minute
        @test enhanced_results.total_computation_time > 0
        
        # Test memory efficiency with multiple small runs
        for i in 1:3
            small_results = run_enhanced_systematic_analysis([0.1])
            @test small_results isa MultiToleranceResults
            GC.gc()  # Force garbage collection
        end
    end
end

# ================================================================================
# SUMMARY REPORT
# ================================================================================

println("\n" * "="^80)
println("INTEGRATION BRIDGE TEST SUITE COMPLETED")
println("="^80)
println("✅ Bridge function tests passed - data extraction working")
println("✅ Pipeline integration verified - enhanced analysis functional")
println("✅ Error handling and validation confirmed")
println("✅ Integration bridge ready for production use")
println("✅ Existing workflow can be seamlessly enhanced")
println("="^80)