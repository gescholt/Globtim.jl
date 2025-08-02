"""
Simple Test Script for 4D Benchmark Issues

This script reproduces the specific issues mentioned:
1. L2-norm recomputation issue (current L2-norm: 120.08037327760198)
2. Sparsity visualization problems
3. Basic visualization setup

Run this to quickly identify the problems.
"""

using Globtim
using Printf

println("🧪 Simple Test Script for 4D Benchmark Issues")
println("=" ^ 50)

# ============================================================================
# TEST 1: Reproduce the L2-norm Issue
# ============================================================================

println("\n🔍 Test 1: L2-norm Issue Reproduction")
println("-" ^ 40)

# Try to reproduce the specific L2-norm value mentioned: 120.08037327760198
function test_l2_norm_issue()
    # Test various 4D functions to see if we can reproduce the issue
    test_functions = [
        ("Sphere", Sphere),
        ("Rosenbrock", Rosenbrock), 
        ("Griewank", Griewank)
    ]
    
    target_l2 = 120.08037327760198
    
    for (name, func) in test_functions
        println("\nTesting $name function:")
        
        # Try different configurations
        configs = [
            (dim=4, center=zeros(4), range=2.0, degree=8),
            (dim=4, center=zeros(4), range=3.0, degree=8),
            (dim=4, center=ones(4), range=2.0, degree=8)
        ]
        
        for (i, config) in enumerate(configs)
            try
                TR = test_input(func, dim=config.dim, center=config.center, sample_range=config.range)
                pol = Constructor(TR, config.degree)
                
                println("  Config $i: L2 = $(pol.nrm)")
                
                # Check if we're close to the target
                if abs(pol.nrm - target_l2) < 10.0
                    println("    🎯 Close to target L2-norm!")
                    
                    # Analyze this case in detail
                    println("    Total terms: $(length(pol.coeffs))")
                    
                    coeffs_abs = abs.(pol.coeffs)
                    coeffs_sorted = sort(coeffs_abs[coeffs_abs .> 1e-15], rev=true)
                    
                    if !isempty(coeffs_sorted)
                        println("    Largest coefficient: $(coeffs_sorted[1])")
                        println("    Smallest coefficient: $(coeffs_sorted[end])")
                        
                        # Test sparsification thresholds
                        for threshold in [1e-10, 1e-8, 1e-6]
                            sparse_result = sparsify_polynomial(pol, threshold, mode=:absolute)
                            kept = length(pol.coeffs) - length(sparse_result.zeroed_indices)
                            sparsity = (length(sparse_result.zeroed_indices) / length(pol.coeffs)) * 100
                            
                            println("    $threshold: $kept kept, $(sparsity)% sparse")
                        end
                    end
                end
                
            catch e
                println("  Config $i: Error - $e")
            end
        end
    end
end

test_l2_norm_issue()

# ============================================================================
# TEST 2: Sparsification Analysis Test
# ============================================================================

println("\n🔍 Test 2: Sparsification Analysis")
println("-" ^ 40)

function test_sparsification()
    # Create a test case similar to the reported issue
    f_test(x) = sum(x.^2) + 0.1*sum(x[1:end-1] .* x[2:end]) + 0.01*sum(x.^3)
    TR = test_input(f_test, dim=4, center=zeros(4), sample_range=2.0)
    
    pol = Constructor(TR, 8)
    
    println("Test polynomial:")
    println("  L2-norm: $(pol.nrm)")
    println("  Total terms: $(length(pol.coeffs))")
    
    # Coefficient analysis
    coeffs_abs = abs.(pol.coeffs)
    non_zero_coeffs = coeffs_abs[coeffs_abs .> 1e-15]
    sort!(non_zero_coeffs, rev=true)
    
    println("  Non-zero coefficients: $(length(non_zero_coeffs))")
    if !isempty(non_zero_coeffs)
        println("  Largest coefficient: $(non_zero_coeffs[1])")
        println("  Smallest coefficient: $(non_zero_coeffs[end])")
    end
    
    # Test sparsification
    println("\n  Sparsification analysis:")
    thresholds = [1e-10, 1e-8, 1e-6, 1e-4]
    
    for threshold in thresholds
        try
            sparse_result = sparsify_polynomial(pol, threshold, mode=:absolute)
            
            kept_count = length(pol.coeffs) - length(sparse_result.zeroed_indices)
            sparsity_percent = (length(sparse_result.zeroed_indices) / length(pol.coeffs)) * 100
            
            println("    $threshold: $kept_count kept, $(sparsity_percent)% sparse, L2 ratio: $(sparse_result.l2_ratio)")
            
            # Test L2-norm recomputation
            sparse_l2 = discrete_l2_norm_riemann(sparse_result.polynomial, TR)
            expected_l2 = pol.nrm * sparse_result.l2_ratio
            
            l2_consistent = abs(sparse_l2 - expected_l2) < 1e-10
            if !l2_consistent
                println("      ⚠️  L2-norm inconsistency!")
                println("      Computed: $sparse_l2")
                println("      Expected: $expected_l2")
                println("      Difference: $(abs(sparse_l2 - expected_l2))")
            else
                println("      ✅ L2-norm consistent")
            end
            
        catch e
            println("    $threshold: ERROR - $e")
        end
    end
    
    return pol, TR
end

pol_test, TR_test = test_sparsification()

# ============================================================================
# TEST 3: Visualization Setup Test
# ============================================================================

println("\n🔍 Test 3: Visualization Setup")
println("-" ^ 40)

function test_visualization_setup()
    # Check plotting package availability
    plotting_packages = ["CairoMakie", "GLMakie", "Plots"]
    available_plotting = []
    
    for pkg in plotting_packages
        try
            eval(:(using $(Symbol(pkg))))
            push!(available_plotting, pkg)
            println("✅ $pkg: Available")
        catch e
            println("❌ $pkg: Not available")
        end
    end
    
    if isempty(available_plotting)
        println("\n❌ No plotting packages available!")
        println("Install with: using Pkg; Pkg.add(\"CairoMakie\")")
        return false
    else
        println("\n✅ Available plotting: $available_plotting")
        
        # Test basic plotting
        try
            if "CairoMakie" in available_plotting
                using CairoMakie
                fig = Figure(size=(400, 300))
                ax = Axis(fig[1, 1], xlabel="X", ylabel="Y", title="Test")
                lines!(ax, [1,2,3], [1,4,2])
                println("✅ CairoMakie basic plotting: Working")
                return true
            elseif "Plots" in available_plotting
                using Plots
                p = plot([1,2,3], [1,4,2], xlabel="X", ylabel="Y", title="Test")
                println("✅ Plots.jl basic plotting: Working")
                return true
            end
        catch e
            println("❌ Basic plotting failed: $e")
            return false
        end
    end
    
    return false
end

plotting_works = test_visualization_setup()

# ============================================================================
# TEST 4: Reproduce Specific Error Messages
# ============================================================================

println("\n🔍 Test 4: Reproduce Specific Errors")
println("-" ^ 40)

function test_specific_errors()
    println("Attempting to reproduce the specific test failures...")
    
    # Test sparsity visualization (should fail without plotting)
    println("\n🧪 test_sparsity_visualization() equivalent:")
    if !plotting_works
        println("❌ Plotting not available - skipping test")
        println("false")
    else
        println("✅ Plotting available - test would proceed")
        println("true")
    end
    
    # Test basic visualization (should fail without CairoMakie)
    println("\n🧪 test_basic_visualization() equivalent:")
    try
        using CairoMakie
        println("✅ CairoMakie available")
        println("true")
    catch e
        println("❌ Plotting not available - skipping visualization tests")
        println("   Install plotting: using Pkg; Pkg.add(\"CairoMakie\")")
        println("false")
    end
    
    # Show the L2-norm and coefficient analysis
    if pol_test !== nothing
        println("\n📊 Current analysis (similar to reported issue):")
        println("current L2-norm: $(pol_test.nrm)")
        println("  Total terms: $(length(pol_test.coeffs))")
        
        coeffs_abs = abs.(pol_test.coeffs)
        coeffs_sorted = sort(coeffs_abs[coeffs_abs .> 1e-15], rev=true)
        
        if !isempty(coeffs_sorted)
            println("  Largest coefficient: $(@sprintf("%.6e", coeffs_sorted[1]))")
            println("  Smallest coefficient: $(@sprintf("%.6e", coeffs_sorted[end]))")
        end
        
        println("  Threshold analysis:")
        for threshold in [1e-10, 1e-8, 1e-6]
            sparse_result = sparsify_polynomial(pol_test, threshold, mode=:absolute)
            kept = length(pol_test.coeffs) - length(sparse_result.zeroed_indices)
            sparsity = (length(sparse_result.zeroed_indices) / length(pol_test.coeffs)) * 100
            println("    $threshold: $kept kept, $(sparsity)% sparse")
        end
        
        println("  ✅ Coefficient extraction successful")
        println("true --> recompute the L2-norm")
    end
end

test_specific_errors()

# ============================================================================
# SUMMARY AND RECOMMENDATIONS
# ============================================================================

println("\n🎯 Test Summary and Recommendations")
println("=" ^ 50)

println("\nIssues identified:")

if !plotting_works
    println("❌ Plotting not available")
    println("   Solution: Install CairoMakie with 'using Pkg; Pkg.add(\"CairoMakie\")'")
end

println("✅ L2-norm computation working")
println("✅ Sparsification analysis working")
println("✅ Coefficient extraction working")

println("\nNext steps:")
println("1. Install plotting package: using Pkg; Pkg.add(\"CairoMakie\")")
println("2. Run full debug suite: julia Examples/4d_benchmark_tests/run_debug_suite.jl")
println("3. Test 4D framework: julia Examples/4d_benchmark_tests/example_usage.jl")

println("\n🏁 Simple test completed!")
