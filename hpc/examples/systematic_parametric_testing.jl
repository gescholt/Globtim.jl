#!/usr/bin/env julia

"""
Systematic Parametric Testing with Enhanced JSON3 Integration

This script demonstrates comprehensive parameter sweep capabilities
using the enhanced JSON3 infrastructure for HPC testing.

Usage:
    julia hpc/examples/systematic_parametric_testing.jl
"""

# Setup environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Globtim
using JSON3
using DataFrames
using Statistics
using Printf

# Load JSON I/O infrastructure
include("../infrastructure/json_io.jl")

"""
Example 1: Single Function Parameter Sweep
"""
function example_parameter_sweep()
    println("🚀 Example 1: Deuflhard Parameter Sweep")
    println("=" ^ 50)
    
    # Base configuration
    base_config = Dict(
        "metadata" => Dict(
            "description" => "Deuflhard_parameter_sweep",
            "tags" => ["parameter_sweep", "deuflhard", "systematic_testing"]
        ),
        "test_input" => Dict(
            "function_name" => "Deuflhard",
            "dimension" => 2,
            "center" => [0.0, 0.0],
            "sample_range" => 1.4
        ),
        "polynomial_construction" => Dict(
            "basis" => "chebyshev",
            "precision_type" => "Float64",
            "normalized" => true
        )
    )
    
    # Parameter ranges for sweep
    parameter_ranges = Dict(
        "polynomial_construction.degree" => [6, 8, 10],
        "test_input.sample_range" => [1.0, 1.4, 2.0]
    )
    
    # Generate sweep configurations
    sweep_configs = create_parameter_sweep_config(base_config, parameter_ranges)
    
    println("📊 Generated $(length(sweep_configs)) configurations:")
    for (i, config) in enumerate(sweep_configs)
        degree = config["polynomial_construction"]["degree"]
        range = config["test_input"]["sample_range"]
        comp_id = config["metadata"]["computation_id"]
        println("  $i. Degree: $degree, Range: $range, ID: $comp_id")
    end
    
    # Save sweep manifest
    results_dir = "hpc_results/parameter_sweeps/deuflhard_example"
    manifest_path = save_parameter_sweep_manifest(sweep_configs, results_dir)
    
    println("✅ Parameter sweep configuration complete")
    return sweep_configs, manifest_path
end

"""
Example 2: Multi-Function Comparison Study
"""
function example_multi_function_study()
    println("\n🚀 Example 2: Multi-Function Comparison Study")
    println("=" ^ 50)
    
    functions_to_test = [
        ("Deuflhard", [0.0, 0.0], 1.4),
        ("Ackley", [0.0, 0.0], 5.0),
        ("shubert", [0.0, 0.0], 10.0)
    ]
    
    all_configs = Dict[]
    
    for (func_name, center, sample_range) in functions_to_test
        base_config = Dict(
            "metadata" => Dict(
                "description" => "$(func_name)_comparison_study",
                "tags" => ["multi_function", "comparison", lowercase(func_name)]
            ),
            "test_input" => Dict(
                "function_name" => func_name,
                "dimension" => 2,
                "center" => center,
                "sample_range" => sample_range
            ),
            "polynomial_construction" => Dict(
                "degree" => 8,
                "basis" => "chebyshev",
                "precision_type" => "Float64",
                "normalized" => true
            )
        )
        
        # Add computation ID and metadata
        base_config["metadata"]["computation_id"] = generate_computation_id()
        base_config["metadata"]["function_specific"] = Dict(
            "expected_global_minimum" => center,
            "domain_characteristics" => func_name == "Ackley" ? "highly_multimodal" : 
                                      func_name == "shubert" ? "many_local_minima" : "smooth"
        )
        
        push!(all_configs, base_config)
        
        println("📋 $func_name configuration: ID $(base_config["metadata"]["computation_id"])")
    end
    
    # Save multi-function manifest
    results_dir = "hpc_results/multi_function_studies/comparison_2d"
    manifest_path = save_parameter_sweep_manifest(all_configs, results_dir)
    
    println("✅ Multi-function study configuration complete")
    return all_configs, manifest_path
end

"""
Example 3: HPC Job Integration
"""
function example_hpc_integration()
    println("\n🚀 Example 3: HPC Job Integration")
    println("=" ^ 50)
    
    # Create a configuration for HPC submission
    TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.4)
    
    # Create comprehensive configuration
    config = create_input_config(
        TR, 8, :chebyshev, Float64,
        analysis_params=Dict(
            "tol_dist" => 0.025,
            "enable_hessian" => true,
            "max_iters_in_optim" => 100
        ),
        metadata=Dict(
            "description" => "HPC_integration_example",
            "tags" => ["hpc", "integration", "deuflhard"],
            "priority" => "high",
            "expected_runtime_minutes" => 5
        )
    )
    
    # Validate configuration
    is_valid = validate_input_config(config)
    println("📋 Configuration validation: $(is_valid ? "✅ PASSED" : "❌ FAILED")")
    
    if is_valid
        # Save configuration for HPC submission
        config_dir = "hpc_results/integration_examples"
        config_file = joinpath(config_dir, "hpc_integration_$(config["metadata"]["computation_id"]).json")
        save_input_config(config, config_file)
        
        # Compute parameter hash for duplicate detection
        param_hash = compute_parameter_hash(config)
        println("📊 Parameter hash: $param_hash")
        
        # Show how this would integrate with HPC submission
        println("\n🔧 HPC Integration Pattern:")
        println("  1. Configuration saved: $config_file")
        println("  2. Submit job with: python3 submit_with_config.py --config $config_file")
        println("  3. Monitor with: python3 automated_job_monitor.py --test-id $(config["metadata"]["computation_id"])")
        println("  4. Collect results automatically when job completes")
    end
    
    return config
end

"""
Example 4: Results Analysis and Aggregation
"""
function example_results_analysis()
    println("\n🚀 Example 4: Results Analysis and Aggregation")
    println("=" ^ 50)
    
    # Simulate some results for demonstration
    mock_results_dir = "hpc_results/mock_analysis"
    mkpath(mock_results_dir)
    
    # Create mock result files
    for i in 1:3
        mock_result = Dict(
            "metadata" => Dict(
                "computation_id" => generate_computation_id(),
                "total_runtime" => 10.0 + rand() * 20.0
            ),
            "polynomial_results" => Dict(
                "l2_error" => 0.001 + rand() * 0.01,
                "construction_time" => 2.0 + rand() * 3.0
            ),
            "critical_point_results" => Dict(
                "solving_time" => 5.0 + rand() * 10.0,
                "n_valid_critical_points" => rand(1:10)
            )
        )
        
        result_file = joinpath(mock_results_dir, "computation_$(i)_results.json")
        save_output_results(mock_result, result_file)
    end
    
    # Aggregate results
    aggregated = aggregate_sweep_results(mock_results_dir)
    
    if !isempty(aggregated)
        println("📊 Aggregation Results:")
        println("  Total computations: $(aggregated["sweep_summary"]["total_computations"])")
        
        if haskey(aggregated, "performance_analysis")
            perf = aggregated["performance_analysis"]
            if haskey(perf, "l2_error_stats")
                l2_stats = perf["l2_error_stats"]
                @printf "  L2 Error - Mean: %.6f, Std: %.6f\\n" l2_stats["mean"] l2_stats["std"]
            end
        end
        
        # Save aggregated results
        agg_file = joinpath(mock_results_dir, "aggregated_analysis.json")
        open(agg_file, "w") do f
            JSON3.pretty(f, aggregated)
        end
        println("  📁 Aggregated analysis saved: $agg_file")
    end
    
    # Cleanup mock files
    rm(mock_results_dir, recursive=true)
    println("🧹 Mock files cleaned up")
    
    return aggregated
end

"""
Main demonstration function
"""
function main()
    println("🎯 Systematic Parametric Testing with Enhanced JSON3 Integration")
    println("=" ^ 70)
    
    try
        # Run examples
        sweep_configs, sweep_manifest = example_parameter_sweep()
        multi_configs, multi_manifest = example_multi_function_study()
        hpc_config = example_hpc_integration()
        aggregated_results = example_results_analysis()
        
        println("\n🎉 All examples completed successfully!")
        println("\n📋 Summary:")
        println("  • Parameter sweep: $(length(sweep_configs)) configurations")
        println("  • Multi-function study: $(length(multi_configs)) configurations")
        println("  • HPC integration: Configuration validated and saved")
        println("  • Results analysis: Aggregation workflow demonstrated")
        
        println("\n💡 Next Steps:")
        println("  1. Use generated configurations with HPC submission scripts")
        println("  2. Monitor jobs with automated_job_monitor.py")
        println("  3. Aggregate results using aggregate_sweep_results()")
        println("  4. Analyze trends and performance patterns")
        
    catch e
        println("❌ Error in systematic testing demonstration: $e")
        rethrow(e)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
