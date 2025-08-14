#!/usr/bin/env julia

"""
Performance Tracking Demo with BenchmarkTools Integration

Demonstrates comprehensive performance tracking capabilities for HPC workflows.

Usage:
    julia hpc/examples/performance_tracking_demo.jl
"""

# Setup environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Globtim
using Printf

# Load performance tracking infrastructure
include("../infrastructure/performance_tracking.jl")

"""
Demo 1: Basic Constructor Benchmarking
"""
function demo_constructor_benchmarking()
    println("🚀 Demo 1: Constructor Performance Benchmarking")
    println("=" ^ 50)
    
    # Test with Deuflhard function
    TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.4)
    
    # Benchmark different degrees
    degrees_to_test = [6, 8, 10]
    
    for degree in degrees_to_test
        println("\\n📊 Benchmarking degree $degree:")
        perf_data = benchmark_constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, samples=5, seconds=5)
        
        # Extract key metrics
        timing = perf_data["timing_stats"]
        @printf "  Result: %.4f ± %.4f seconds\\n" timing["mean_time"] timing["std_time"]
    end
    
    println("\\n✅ Constructor benchmarking demo complete")
end

"""
Demo 2: Scaling Analysis
"""
function demo_scaling_analysis()
    println("\\n🚀 Demo 2: Performance Scaling Analysis")
    println("=" ^ 50)
    
    # Test scaling with dimension
    dimensions = [2, 3, 4]
    degree = 6
    
    all_performance_data = []
    
    for dim in dimensions
        println("\\n📊 Testing dimension $dim:")
        
        # Create appropriate test input for dimension
        center = zeros(dim)
        TR = test_input(Deuflhard, dim=dim, center=center, sample_range=1.4)
        
        # Benchmark constructor
        perf_data = benchmark_constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, samples=3, seconds=5)
        push!(all_performance_data, perf_data)
        
        timing = perf_data["timing_stats"]
        @printf "  Dimension %d: %.4f ± %.4f seconds\\n" dim timing["mean_time"] timing["std_time"]
    end
    
    # Analyze scaling
    dims = [perf["metadata"]["parameters"]["dimension"] for perf in all_performance_data]
    times = [perf["timing_stats"]["mean_time"] for perf in all_performance_data]
    
    scaling_analysis = analyze_scaling_by_parameter(dims, times, "dimension", "constructor_time")
    
    if haskey(scaling_analysis, "scaling_analysis")
        scaling = scaling_analysis["scaling_analysis"]
        @printf "\\n📈 Scaling Analysis: exponent = %.2f (%s)\\n" scaling["scaling_exponent"] scaling["interpretation"]
    end
    
    println("\\n✅ Scaling analysis demo complete")
    return scaling_analysis
end

"""
Demo 3: Full Workflow Benchmarking
"""
function demo_full_workflow_benchmarking()
    println("\\n🚀 Demo 3: Full Workflow Benchmarking")
    println("=" ^ 50)
    
    # Test with a simple case
    TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.4)
    
    try
        # Benchmark complete workflow
        workflow_perf = benchmark_full_workflow(TR, 6, basis=:chebyshev, precision=Float64Precision)
        
        # Display summary
        if haskey(workflow_perf, "summary")
            summary = workflow_perf["summary"]
            @printf "\\n📊 Workflow Summary:\\n"
            @printf "  Total estimated time: %.4f seconds\\n" summary["total_estimated_time"]
            @printf "  Components benchmarked: %d\\n" summary["workflow_components"]
        end
        
        # Save results
        output_dir = "demo_results/performance_tracking"
        comp_id = "demo_" * string(hash(string(now())))[1:8]
        perf_file = save_performance_results(workflow_perf, output_dir, comp_id)
        
        println("\\n✅ Full workflow benchmarking demo complete")
        return workflow_perf, perf_file
        
    catch e
        println("\\n⚠️  Full workflow benchmarking failed: $e")
        println("    This is expected if solve_polynomial_system has issues")
        return Dict(), ""
    end
end

"""
Demo 4: HPC Integration Pattern
"""
function demo_hpc_integration_pattern()
    println("\\n🚀 Demo 4: HPC Integration Pattern")
    println("=" ^ 50)
    
    # Create configuration for HPC job
    TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.4)
    
    config = create_input_config(
        TR, 8, :chebyshev, Float64,
        metadata=Dict(
            "description" => "performance_tracking_demo",
            "tags" => ["demo", "performance", "hpc"],
            "expected_runtime_minutes" => 10
        )
    )
    
    # Save configuration
    config_dir = "demo_results/hpc_integration"
    config_file = joinpath(config_dir, "demo_config_$(config["metadata"]["computation_id"]).json")
    save_input_config(config, config_file)
    
    println("📋 HPC Integration Workflow:")
    println("  1. Configuration created and saved")
    println("  2. Submit to HPC with performance tracking:")
    println("     python3 submit_with_performance_tracking.py --config $config_file")
    println("  3. Job will include comprehensive benchmarking")
    println("  4. Results will include both computational and performance data")
    println("  5. Aggregate performance across multiple jobs for scaling analysis")
    
    # Show what the HPC job script would include
    println("\\n🔧 HPC Job Script Integration:")
    println("```julia")
    println("# Load performance tracking")
    println("include(\\\"../infrastructure/performance_tracking.jl\\\")")
    println("")
    println("# Benchmark the computation")
    println("workflow_perf = benchmark_full_workflow(TR, degree)")
    println("")
    println("# Save performance results alongside computational results")
    println("save_performance_results(workflow_perf, output_dir, computation_id)")
    println("```")
    
    println("\\n✅ HPC integration pattern demo complete")
    return config_file
end

"""
Main demonstration function
"""
function main()
    println("🎯 BenchmarkTools Integration for HPC Performance Tracking")
    println("=" ^ 70)
    
    if BENCHMARKTOOLS_AVAILABLE
        println("✅ BenchmarkTools available - full functionality enabled")
    else
        println("⚠️  BenchmarkTools not available - basic timing fallback")
        println("   Install with: using Pkg; Pkg.add(\\\"BenchmarkTools\\\")")
    end
    
    try
        # Run demonstrations
        demo_constructor_benchmarking()
        scaling_analysis = demo_scaling_analysis()
        workflow_perf, perf_file = demo_full_workflow_benchmarking()
        config_file = demo_hpc_integration_pattern()
        
        println("\\n🎉 All performance tracking demos completed!")
        
        println("\\n📋 Generated Files:")
        if !isempty(perf_file)
            println("  • Performance data: $perf_file")
        end
        println("  • HPC config: $config_file")
        
        println("\\n💡 Key Features Demonstrated:")
        println("  • Detailed timing statistics with BenchmarkTools")
        println("  • Memory allocation tracking")
        println("  • Scaling analysis across parameters")
        println("  • HPC job integration patterns")
        println("  • JSON-based performance data serialization")
        
        println("\\n🚀 Ready for HPC performance tracking!")
        
    catch e
        println("❌ Error in performance tracking demonstration: $e")
        rethrow(e)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
