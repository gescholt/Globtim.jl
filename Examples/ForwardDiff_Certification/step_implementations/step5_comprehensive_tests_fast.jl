# Step 5: Comprehensive Testing Suite (Fast Version)
#
# This is a streamlined version of step5 that runs faster and avoids warnings

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Test
using Globtim
using Statistics, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
using PrettyTables, Printf

# Suppress output when loading dependencies
original_stdout = stdout
original_stderr = stderr

# Load dependencies silently
redirect_stdout(devnull) do
    redirect_stderr(devnull) do
        if !@isdefined(BFGSConfig)
            include("step1_bfgs_enhanced.jl")
        end
        
        if !@isdefined(UltraPrecisionConfig)
            include("step4_ultra_precision.jl")
        end
    end
end

# Test data
test_points = [
    [-0.7412, 0.7412, -0.7412, 0.7412],  # Near global minimum
    [0.0, 0.0, 0.0, 0.0],                # Origin
    [0.5, -0.5, 0.5, -0.5]               # Random point
]
test_values = [deuflhard_4d_composite(p) for p in test_points]

# Run tests silently and collect results
test_results = Test.DefaultTestSet("Fast Tests")
Test.push_testset(test_results)

try
    # 1. Mathematical Foundation
    @testset "Mathematical Foundation" begin
        point = test_points[1]
        val = deuflhard_4d_composite(point)
        expected = Deuflhard([point[1], point[2]]) + Deuflhard([point[3], point[4]])
        @test isapprox(val, expected, rtol=1e-12)
        
        grad = ForwardDiff.gradient(deuflhard_4d_composite, point)
        @test length(grad) == 4
        @test all(isfinite.(grad))
        
        hess = ForwardDiff.hessian(deuflhard_4d_composite, point)
        @test isapprox(hess, hess', rtol=1e-10)
    end
    
    # 2. BFGS Enhancement
    @testset "BFGS Enhancement" begin
        config = BFGSConfig(
            standard_tolerance = 1e-8,
            high_precision_tolerance = 1e-12,
            show_trace = false,
            max_iterations = 50
        )
        
        # Suppress output during BFGS
        results = redirect_stdout(devnull) do
            enhanced_bfgs_refinement(
                [test_points[1]], 
                [test_values[1]], 
                ["test"],
                deuflhard_4d_composite, 
                config
            )
        end
        
        @test length(results) == 1
        @test results[1].converged
        @test results[1].refined_value <= results[1].initial_value
        @test results[1].final_grad_norm < 1e-6
    end
    
    # 3. Ultra-Precision
    @testset "Ultra-Precision" begin
        config = UltraPrecisionConfig(
            max_precision_stages = 1,
            stage_tolerance_factors = [1.0],
            use_nelder_mead_final = false
        )
        
        # Suppress output during ultra-precision
        results, histories = redirect_stdout(devnull) do
            ultra_precision_refinement(
                [test_points[1]],
                [test_values[1]],
                deuflhard_4d_composite,
                1e-15,
                config,
                labels = ["test"]
            )
        end
        
        @test length(results) == 1
        @test results[1].refined_value < 1e-10
        @test length(histories[1]) >= 1
    end
    
    # 4. Integration
    @testset "Integration" begin
        TR = test_input(
            deuflhard_4d_composite, 
            dim=4,
            center=[0.0, 0.0, 0.0, 0.0], 
            sample_range=0.1,
            tolerance=0.01
        )
        pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)
        
        @test pol.nrm <= 0.01
        actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
        @test actual_degree >= 4
    end
    
    # 5. Performance
    @testset "Performance" begin
        elapsed = @elapsed begin
            point = test_points[1]
            for _ in 1:100
                val = deuflhard_4d_composite(point)
                grad = ForwardDiff.gradient(deuflhard_4d_composite, point)
            end
        end
        
        @test elapsed < 1.0
    end
finally
    Test.pop_testset()
end

# Extract results
n_tests = test_results.n_passed + test_results.n_failed

# Print minimal summary table
println("\n╔════════════════════════════════════════╗")
println("║    FAST TEST SUITE SUMMARY             ║")
println("╠════════════════════════════════════════╣")
println("║ Total tests:    $(lpad(n_tests, 3))                    ║")
println("║ Passed:         $(lpad(test_results.n_passed, 3))                    ║")
println("║ Failed:         $(lpad(test_results.n_failed, 3))                    ║")
println("╚════════════════════════════════════════╝")

if test_results.n_failed == 0
    println("✓ All tests passed")
else
    println("✗ $(test_results.n_failed) tests failed")
end