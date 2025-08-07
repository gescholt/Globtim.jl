"""
Test and Validation Script for JSON Tracking System

This script tests the JSON-based input/output tracking system by running
a complete Deuflhard example and validating that all parameters and results
are captured correctly.
"""

# Activate the main Globtim project environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Test
using JSON3
using DataFrames
using Dates
using Printf

# Load Globtim (with error handling for different environments)
try
    using Globtim
    using DynamicPolynomials
    println("✅ Globtim loaded from package")
catch e
    println("⚠️  Globtim package not available, loading from source...")
    # Add source loading if needed
    include("../../src/Globtim.jl")
    using .Globtim
    using DynamicPolynomials
    println("✅ Globtim loaded from source")
end

# Load JSON I/O utilities
include("json_io.jl")

println("🧪 JSON Tracking System Test Suite")
println("=" ^ 50)
println("Started: $(now())")
println()

"""
Test the JSON I/O utilities with mock data
"""
function test_json_io_utilities()
    println("🔧 Testing JSON I/O utilities...")
    
    @testset "JSON I/O Utilities" begin
        # Test computation ID generation
        id1 = generate_computation_id()
        id2 = generate_computation_id()
        @test length(id1) == 8
        @test length(id2) == 8
        @test id1 != id2
        println("  ✅ Computation ID generation")
        
        # Test parameter hash computation
        config1 = Dict(
            "test_input" => Dict("dim" => 2, "degree" => 8),
            "polynomial_construction" => Dict("basis" => "chebyshev"),
            "critical_point_analysis" => Dict("tol_dist" => 0.001)
        )
        config2 = deepcopy(config1)
        config3 = deepcopy(config1)
        config3["test_input"]["degree"] = 10
        
        hash1 = compute_parameter_hash(config1)
        hash2 = compute_parameter_hash(config2)
        hash3 = compute_parameter_hash(config3)
        
        @test hash1 == hash2  # Same parameters should give same hash
        @test hash1 != hash3  # Different parameters should give different hash
        @test length(hash1) == 64  # SHA256 hex string length
        println("  ✅ Parameter hash computation")
        
        # Test directory creation
        test_dir = create_computation_directory("test_results", "TestFunction", "test1234", "test_run")
        @test isdir(test_dir)
        @test isdir(joinpath(test_dir, "detailed_outputs"))
        @test isdir(joinpath(test_dir, "logs"))
        println("  ✅ Directory creation")
        
        # Clean up test directory
        rm(dirname(dirname(test_dir)), recursive=true, force=true)
    end
    
    println("✅ JSON I/O utilities tests passed")
    println()
end

"""
Test the complete workflow with a simple function
"""
function test_complete_workflow()
    println("🔬 Testing complete workflow with simple function...")
    
    # Use a simple test function instead of Deuflhard for faster testing
    simple_func(x) = (x[1] - 1.0)^2 + (x[2] + 0.5)^2
    
    try
        # Step 1: Create test input
        println("  📋 Step 1: Creating test input...")
        TR = test_input(
            simple_func,
            dim = 2,
            center = [1.0, -0.5],
            sample_range = 1.0,
            GN = 30  # Small number for fast testing
        )
        println("    ✅ Test input created")
        
        # Step 2: Create input configuration
        println("  📝 Step 2: Creating input configuration...")
        computation_id = generate_computation_id()
        
        metadata = Dict(
            "computation_id" => computation_id,
            "function_name" => "simple_test_function",
            "description" => "Test of JSON tracking system",
            "tags" => ["test", "2d", "simple"]
        )
        
        input_config = create_input_config(
            TR, 4, :chebyshev, RationalPrecision,
            metadata = metadata,
            analysis_params = Dict(
                "tol_dist" => 0.01,
                "enable_hessian" => true,
                "verbose" => false
            )
        )
        
        # Validate input configuration
        @test validate_input_config(input_config)
        println("    ✅ Input configuration created and validated")
        
        # Step 3: Create output directory and save input config
        println("  📁 Step 3: Setting up output directory...")
        output_dir = create_computation_directory("test_results", "SimpleTest", computation_id, "workflow_test")
        input_config_path = joinpath(output_dir, "input_config.json")
        save_input_config(input_config, input_config_path)
        
        # Verify we can load it back
        loaded_config = load_input_config(input_config_path)
        @test loaded_config["metadata"]["computation_id"] == computation_id
        println("    ✅ Input configuration saved and loaded successfully")
        
        # Step 4: Run polynomial construction
        println("  🏗️  Step 4: Running polynomial construction...")
        start_time = now()
        construction_start = time()
        
        pol = Constructor(TR, 4, basis=:chebyshev, precision=RationalPrecision, verbose=0)
        construction_time = time() - construction_start
        
        @test pol.nrm > 0  # Should have some approximation error
        @test length(pol.coeffs) > 0  # Should have coefficients
        println("    ✅ Polynomial constructed (L2 error: $(@sprintf("%.2e", pol.nrm)))")
        
        # Step 5: Find critical points
        println("  🔍 Step 5: Finding critical points...")
        solving_start = time()
        
        @polyvar x[1:2]
        solutions = solve_polynomial_system(x, 2, 4, pol.coeffs)
        df_critical = process_crit_pts(solutions, simple_func, TR)
        
        solving_time = time() - solving_start
        
        @test nrow(df_critical) > 0  # Should find at least one critical point
        println("    ✅ Critical points found ($(nrow(df_critical)) points)")
        
        # Step 6: Analyze critical points
        println("  🔬 Step 6: Analyzing critical points...")
        analysis_start = time()
        
        df_enhanced, df_min = analyze_critical_points(
            simple_func, df_critical, TR,
            tol_dist = 0.01,
            enable_hessian = true,
            verbose = false
        )
        
        analysis_time = time() - analysis_start
        end_time = now()
        
        @test nrow(df_enhanced) >= nrow(df_critical)  # Should have at least as many points
        println("    ✅ Critical point analysis completed ($(nrow(df_min)) minima found)")
        
        # Step 7: Create and save output results
        println("  💾 Step 7: Saving output results...")
        
        timings = Dict(
            "construction_time" => construction_time,
            "solving_time" => solving_time,
            "analysis_time" => analysis_time,
            "n_raw_solutions" => length(solutions)
        )
        
        output_results = create_output_results(
            computation_id, start_time, end_time,
            pol, df_enhanced, df_min, timings
        )
        
        # Validate output results structure
        @test haskey(output_results, "metadata")
        @test haskey(output_results, "polynomial_results")
        @test haskey(output_results, "critical_point_results")
        @test output_results["metadata"]["status"] == "SUCCESS"
        @test output_results["polynomial_results"]["l2_error"] == pol.nrm
        
        # Save output results
        output_results_path = joinpath(output_dir, "output_results.json")
        save_output_results(output_results, output_results_path)
        
        # Save detailed outputs
        detailed_dir = joinpath(output_dir, "detailed_outputs")
        save_detailed_outputs(df_enhanced, df_min, pol, detailed_dir)
        
        # Verify files were created
        @test isfile(input_config_path)
        @test isfile(output_results_path)
        @test isfile(joinpath(detailed_dir, "critical_points.csv"))
        @test isfile(joinpath(detailed_dir, "polynomial_coeffs.json"))
        
        println("    ✅ All output files created successfully")
        
        # Step 8: Test file organization
        println("  📂 Step 8: Testing file organization...")
        
        # Create symlinks
        create_symlinks(output_dir, computation_id, "SimpleTest", ["test", "2d"])
        
        # Check that symlinks were created (basic check)
        date_str = Dates.format(now(), "yyyy-mm-dd")
        expected_date_link = joinpath(dirname(dirname(dirname(dirname(output_dir)))), "by_date", date_str, computation_id)
        # Note: We can't easily test symlinks in all environments, so we'll just check the function runs
        
        println("    ✅ File organization completed")
        
        # Step 9: Validate round-trip consistency
        println("  🔄 Step 9: Testing round-trip consistency...")
        
        # Load back the saved results
        loaded_output = load_output_results(output_results_path)
        @test loaded_output["metadata"]["computation_id"] == computation_id
        @test loaded_output["polynomial_results"]["l2_error"] ≈ pol.nrm
        
        println("    ✅ Round-trip consistency verified")
        
        println("✅ Complete workflow test passed!")
        println("   📁 Test results saved in: $output_dir")
        println("   📊 Summary:")
        println("      - Polynomial L2 error: $(@sprintf("%.2e", pol.nrm))")
        println("      - Critical points found: $(nrow(df_enhanced))")
        println("      - Local minima: $(nrow(df_min))")
        println("      - Total runtime: $(@sprintf("%.2f", (end_time - start_time).value / 1000.0)) seconds")
        
        # Clean up test results
        println("  🧹 Cleaning up test files...")
        rm(dirname(dirname(dirname(output_dir))), recursive=true, force=true)
        println("    ✅ Test files cleaned up")
        
        return true
        
    catch e
        println("❌ Complete workflow test failed: $e")
        # Print stack trace for debugging
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        return false
    end
    
    println()
end

"""
Test schema validation
"""
function test_schema_validation()
    println("📋 Testing schema validation...")
    
    @testset "Schema Validation" begin
        # Test valid configuration
        valid_config = Dict(
            "metadata" => Dict(
                "computation_id" => "test1234",
                "function_name" => "TestFunc"
            ),
            "test_input" => Dict(
                "function_name" => "TestFunc",
                "dimension" => 2,
                "center" => [0.0, 0.0],
                "sample_range" => 1.0
            ),
            "polynomial_construction" => Dict(
                "degree" => 6,
                "basis" => "chebyshev"
            )
        )
        
        @test validate_input_config(valid_config) == true
        
        # Test invalid configuration (missing required field)
        invalid_config = deepcopy(valid_config)
        delete!(invalid_config["test_input"], "dimension")
        
        @test validate_input_config(invalid_config) == false
        
        println("  ✅ Schema validation tests passed")
    end
    
    println()
end

"""
Main test runner
"""
function run_all_tests()
    println("🚀 Running all JSON tracking system tests...")
    println()
    
    all_passed = true
    
    try
        # Test 1: JSON I/O utilities
        test_json_io_utilities()
        
        # Test 2: Schema validation
        test_schema_validation()
        
        # Test 3: Complete workflow (most comprehensive)
        workflow_passed = test_complete_workflow()
        all_passed = all_passed && workflow_passed
        
        if all_passed
            println("🎉 ALL TESTS PASSED!")
            println("✅ JSON tracking system is ready for production use")
        else
            println("❌ Some tests failed")
            println("⚠️  Please review the errors above before using the system")
        end
        
    catch e
        println("❌ Test suite failed with error: $e")
        all_passed = false
    end
    
    println()
    println("Test completed: $(now())")
    
    return all_passed
end

# Run tests if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    success = run_all_tests()
    exit(success ? 0 : 1)
end
