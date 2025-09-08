"""
Test runner for post-processing metrics test suite.

Runs all post-processing metrics tests for issue #64 validation.

Author: GlobTim Team
Date: September 2025
"""

using Test

# Test files in order of dependency/complexity
test_files = [
    "test_l2_norm_validation.jl",
    "test_distance_to_minima.jl", 
    "test_optim_integration.jl",
    "test_quality_classification.jl",
    "test_sampling_critical_points.jl", 
    "test_edge_cases.jl",
    "test_real_data_validation.jl"
]

@testset "Post-Processing Metrics Test Suite (Issue #64)" begin
    for test_file in test_files
        @testset "$(test_file)" begin
            include(test_file)
        end
    end
end

println("✅ Post-processing metrics test suite completed successfully!")
println("📊 All core metrics validated:")
println("   • L2-norm accuracy and convergence tracking")
println("   • Distance to true minima computation")  
println("   • Local minimizer distance analysis with Optim.jl")
println("   • Quality classification boundaries and scoring")
println("   • Sampling efficiency and critical point clustering")
println("   • Edge cases and numerical stability") 
println("   • Real 4d_results.json data validation")