"""
Makie Setup for AdaptivePrecision Development Notebook

Replace the PlotlyJS setup in your notebook with this code block.

Copy and paste this into a notebook cell to replace PlotlyJS with CairoMakie:
"""

# Essential setup for development
using Pkg
Pkg.activate("../../.")  # Activate main project

# Load Revise FIRST for automatic code reloading
try
    using Revise
    println("✅ Revise loaded - automatic code reloading enabled")
catch
    println("⚠️  Revise not available - manual reloading required")
end

# Core packages (always required)
using Globtim
using DynamicPolynomials
using DataFrames
using Statistics
using LinearAlgebra
using Printf

# Optional packages with graceful fallback
const BENCHMARKTOOLS_AVAILABLE = try
    using BenchmarkTools
    println("✅ BenchmarkTools loaded - detailed benchmarking available")
    true
catch
    println("⚠️  BenchmarkTools not available")
    println("   Install with: import Pkg; Pkg.add(\"BenchmarkTools\")")
    println("   Using basic timing fallback")
    false
end

const PROFILEVIEW_AVAILABLE = try
    using ProfileView
    println("✅ ProfileView loaded - interactive profiling available")
    true
catch
    println("⚠️  ProfileView not available - basic profiling only")
    false
end

const MAKIE_AVAILABLE = try
    using CairoMakie  # Use CairoMakie for static plots in notebooks
    println("✅ CairoMakie loaded - high-quality plotting available")
    true
catch
    println("⚠️  CairoMakie not available")
    println("   Install with: import Pkg; Pkg.add(\"CairoMakie\")")
    println("   No plotting capabilities")
    false
end

# Load plotting utilities if CairoMakie is available
if MAKIE_AVAILABLE
    include("../../Examples/plotting_utils.jl")
    println("📊 Plotting utilities loaded")
end

# Load our testing framework
include("../../test/adaptive_precision_4d_framework.jl")

println("\n🚀 Development environment ready!")
println("📋 Framework functions loaded: $(length(TEST_FUNCTIONS_4D)) test functions")
println("⚡ BenchmarkTools available: $BENCHMARKTOOLS_AVAILABLE")
println("🔬 ProfileView available: $PROFILEVIEW_AVAILABLE") 
println("📊 CairoMakie plotting available: $MAKIE_AVAILABLE")

# Quick test to verify everything works
println("\n🧪 Running quick verification test...")
try
    result = quick_test()
    println("✅ Quick test passed!")
    
    # If plotting is available, create a simple test plot
    if MAKIE_AVAILABLE
        println("📊 Testing plotting capabilities...")
        # Create some dummy data for testing
        test_df = DataFrame(
            precision_overhead = [0.8, 1.2, 1.1, 0.9, 1.3],
            float64_norm = [0.1, 0.2, 0.15, 0.12, 0.18],
            adaptive_norm = [0.1, 0.2, 0.15, 0.12, 0.18]
        )
        
        fig = plot_precision_comparison(test_df)
        if fig !== nothing
            println("✅ Plotting test successful!")
            display(fig)  # Display the test plot
        end
    end
    
catch e
    println("⚠️  Verification test failed: $e")
    println("   Framework loaded but some functions may not work properly")
end

println("\n💡 Ready for AdaptivePrecision development!")
println("📋 Available quick functions:")
println("  • help_4d() - Show all available functions")
println("  • quick_test() - Fast verification test")
println("  • compare_precisions() - Full comparison study")
println("  • sparsity_analysis(:sparse) - Coefficient analysis")
if MAKIE_AVAILABLE
    println("  • plot_precision_comparison(df) - Performance plots")
    println("  • plot_scaling_analysis(df) - Scaling behavior plots")
    println("  • plot_sparsity_analysis(df) - Sparsity analysis plots")
end
