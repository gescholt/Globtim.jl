"""
4D Benchmark Study - Main Execution Script

Comprehensive 4D benchmark analysis with standardized testing, sparsification analysis,
convergence tracking, and visualization.

This script runs the complete 4D benchmark suite and generates all plots and reports.

Usage:
    # Quick test (development)
    julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl quick
    
    # Standard comprehensive test
    julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl standard
    
    # Intensive research-level test
    julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl intensive
    
    # Custom single function analysis
    julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl custom Sphere
"""

using Pkg
Pkg.activate(".")

using Globtim
using DataFrames
using Dates
using Printf

# Include our framework modules
include("benchmark_4d_framework.jl")
include("plotting_4d.jl")

# ============================================================================
# MAIN EXECUTION FUNCTIONS
# ============================================================================

"""
    run_quick_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")

Run quick 4D benchmark study for development and testing.
"""
function run_quick_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")
    println("🚀 Starting Quick 4D Benchmark Study")
    println("=" * 60)
    
    # Create output directory
    output_dir = create_labeled_output_directory(output_base_dir, "quick_4d_study")
    println("📁 Output directory: $output_dir")
    
    # Run benchmark suite
    results = run_4d_benchmark_suite(QUICK_4D_CONFIG, track_convergence=true)
    
    # Generate plots and reports
    if !isempty(results)
        plot_sparsification_analysis(results, output_dir)
        plot_convergence_comparison(results, output_dir)
        
        # Generate convergence data for distance plots
        convergence_data = []
        for result in results
            if !isempty(result.distance_to_global)
                push!(convergence_data, (
                    degree = result.degree,
                    function_name = result.function_name,
                    tracker = (
                        distances_to_global = result.distance_to_global,
                        initial_points = [], # Simplified for quick test
                        refined_points = [],
                        gradient_norms = fill(NaN, length(result.distance_to_global))
                    )
                ))
            end
        end
        
        if !isempty(convergence_data)
            plot_distance_to_minimizers(convergence_data, output_dir)
        end
        
        generate_summary_report(results, output_dir)
        save_results_metadata(results, output_dir)
    end
    
    println("\n✅ Quick 4D study completed!")
    println("📊 Results saved to: $output_dir")
    
    return results, output_dir
end

"""
    run_standard_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")

Run standard comprehensive 4D benchmark study.
"""
function run_standard_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")
    println("🚀 Starting Standard 4D Benchmark Study")
    println("=" * 60)
    
    # Create output directory
    output_dir = create_labeled_output_directory(output_base_dir, "standard_4d_study")
    println("📁 Output directory: $output_dir")
    
    # Run benchmark suite
    results = run_4d_benchmark_suite(STANDARD_4D_CONFIG, track_convergence=true)
    
    # Generate comprehensive analysis
    if !isempty(results)
        # Run detailed convergence studies for key functions
        convergence_studies = []
        key_functions = [:Sphere, :Rosenbrock, :Griewank]
        
        for func_name in key_functions
            if func_name in STANDARD_4D_CONFIG.functions
                println("\n🎯 Running detailed convergence study for $func_name...")
                conv_data = convergence_study_4d(func_name, degrees=STANDARD_4D_CONFIG.degrees)
                append!(convergence_studies, conv_data)
            end
        end
        
        # Generate all plots
        plot_sparsification_analysis(results, output_dir)
        plot_convergence_comparison(results, output_dir)
        
        if !isempty(convergence_studies)
            plot_distance_to_minimizers(convergence_studies, output_dir)
        end
        
        generate_summary_report(results, output_dir)
        save_results_metadata(results, output_dir)
        
        # Save detailed convergence data
        if !isempty(convergence_studies)
            conv_summary_file = joinpath(output_dir, "convergence_study_summary.txt")
            open(conv_summary_file, "w") do io
                println(io, "DETAILED CONVERGENCE STUDY SUMMARY")
                println(io, "=" ^ 40)
                println(io, "Generated: $(Dates.now())")
                println(io)
                
                for study in convergence_studies
                    println(io, "Function: $(get(study, :function_name, "unknown"))")
                    println(io, "Degree: $(study.degree)")
                    println(io, "L2 Error: $(study.l2_error)")
                    if haskey(study, :tracker)
                        println(io, "Points analyzed: $(length(study.tracker.initial_points))")
                        println(io, "Mean final distance to global: $(mean(study.tracker.distances_to_global))")
                        println(io, "Mean gradient norm: $(mean(study.tracker.gradient_norms))")
                    end
                    println(io, "-" ^ 30)
                end
            end
            println("  ✓ Saved: convergence_study_summary.txt")
        end
    end
    
    println("\n✅ Standard 4D study completed!")
    println("📊 Results saved to: $output_dir")
    
    return results, output_dir
end

"""
    run_intensive_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")

Run intensive research-level 4D benchmark study.
"""
function run_intensive_4d_study(output_base_dir="Examples/4d_benchmark_tests/results")
    println("🚀 Starting Intensive 4D Benchmark Study")
    println("⚠️  This may take significant time and computational resources!")
    println("=" * 60)
    
    # Create output directory
    output_dir = create_labeled_output_directory(output_base_dir, "intensive_4d_study")
    println("📁 Output directory: $output_dir")
    
    # Run benchmark suite
    results = run_4d_benchmark_suite(INTENSIVE_4D_CONFIG, track_convergence=true)
    
    # Generate comprehensive analysis for all functions
    if !isempty(results)
        convergence_studies = []
        
        for func_name in INTENSIVE_4D_CONFIG.functions
            println("\n🎯 Running detailed convergence study for $func_name...")
            try
                conv_data = convergence_study_4d(func_name, degrees=INTENSIVE_4D_CONFIG.degrees)
                append!(convergence_studies, conv_data)
            catch e
                println("❌ Error in convergence study for $func_name: $e")
            end
        end
        
        # Generate all plots and analysis
        plot_sparsification_analysis(results, output_dir)
        plot_convergence_comparison(results, output_dir)
        
        if !isempty(convergence_studies)
            plot_distance_to_minimizers(convergence_studies, output_dir)
        end
        
        generate_summary_report(results, output_dir)
        save_results_metadata(results, output_dir)
        
        # Generate detailed performance analysis
        performance_file = joinpath(output_dir, "performance_analysis.txt")
        open(performance_file, "w") do io
            println(io, "INTENSIVE 4D BENCHMARK PERFORMANCE ANALYSIS")
            println(io, "=" ^ 50)
            println(io, "Generated: $(Dates.now())")
            println(io)
            
            # Performance by function
            for func_name in unique([r.function_name for r in results])
                func_results = filter(r -> r.function_name == func_name, results)
                
                println(io, "FUNCTION: $func_name")
                println(io, "  Results count: $(length(func_results))")
                println(io, "  Mean construction time: $(mean([r.construction_time for r in func_results]))")
                println(io, "  Mean analysis time: $(mean([r.analysis_time for r in func_results]))")
                println(io, "  Mean L2 error: $(mean([r.l2_error for r in func_results]))")
                println(io, "  Mean convergence rate: $(mean([r.convergence_metrics.convergence_rate for r in func_results]))")
                println(io)
            end
            
            # Performance by degree
            for degree in unique([r.degree for r in results])
                degree_results = filter(r -> r.degree == degree, results)
                
                println(io, "DEGREE: $degree")
                println(io, "  Results count: $(length(degree_results))")
                println(io, "  Mean construction time: $(mean([r.construction_time for r in degree_results]))")
                println(io, "  Mean analysis time: $(mean([r.analysis_time for r in degree_results]))")
                println(io, "  Mean L2 error: $(mean([r.l2_error for r in degree_results]))")
                println(io)
            end
        end
        println("  ✓ Saved: performance_analysis.txt")
    end
    
    println("\n✅ Intensive 4D study completed!")
    println("📊 Results saved to: $output_dir")
    
    return results, output_dir
end

"""
    run_custom_function_study(func_name::Symbol, output_base_dir="Examples/4d_benchmark_tests/results")

Run detailed study of a single function.
"""
function run_custom_function_study(func_name::Symbol, output_base_dir="Examples/4d_benchmark_tests/results")
    println("🚀 Starting Custom Function Study: $func_name")
    println("=" * 60)
    
    # Create output directory
    output_dir = create_labeled_output_directory(output_base_dir, "custom_$(func_name)_study")
    println("📁 Output directory: $output_dir")
    
    # Run detailed analysis
    results = analyze_4d_function(
        func_name,
        degrees=[4, 6, 8, 10, 12],
        samples=[100, 200, 500],
        sparsification_thresholds=[1e-2, 1e-3, 1e-4, 1e-5, 1e-6],
        track_convergence=true,
        config_name="custom_detailed"
    )
    
    # Run convergence study
    convergence_data = convergence_study_4d(func_name, degrees=[4, 6, 8, 10, 12], track_distance=true)
    
    # Generate plots
    if !isempty(results)
        plot_sparsification_analysis(results, output_dir)
        plot_convergence_comparison(results, output_dir)
    end
    
    if !isempty(convergence_data)
        plot_distance_to_minimizers(convergence_data, output_dir)
    end
    
    # Generate custom report
    report_file = joinpath(output_dir, "$(func_name)_detailed_report.txt")
    open(report_file, "w") do io
        println(io, "DETAILED ANALYSIS REPORT: $func_name")
        println(io, "=" ^ 50)
        println(io, "Generated: $(Dates.now())")
        println(io)
        
        func_info = BENCHMARK_4D_FUNCTIONS[func_name]
        println(io, "FUNCTION PROPERTIES:")
        println(io, "  Domain: $(func_info.domain)")
        println(io, "  Global minimum location: $(func_info.global_min)")
        println(io, "  Global minimum value: $(func_info.f_min)")
        println(io)
        
        if !isempty(results)
            println(io, "POLYNOMIAL APPROXIMATION RESULTS:")
            for result in results
                println(io, "  Degree $(result.degree), $(result.sample_count) samples:")
                println(io, "    L2 error: $(result.l2_error)")
                println(io, "    Construction time: $(result.construction_time)s")
                println(io, "    Analysis time: $(result.analysis_time)s")
                println(io, "    Convergence rate: $(result.convergence_metrics.convergence_rate)")
                println(io)
            end
        end
    end
    
    println("\n✅ Custom function study completed!")
    println("📊 Results saved to: $output_dir")
    
    return results, convergence_data, output_dir
end

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

function main()
    if length(ARGS) == 0
        println("Usage: julia run_4d_benchmark_study.jl [quick|standard|intensive|custom] [function_name]")
        println()
        println("Available modes:")
        println("  quick     - Fast development test")
        println("  standard  - Comprehensive analysis")
        println("  intensive - Research-level analysis")
        println("  custom    - Single function analysis (requires function name)")
        println()
        println("Available functions for custom mode:")
        for func_name in keys(BENCHMARK_4D_FUNCTIONS)
            println("  $func_name")
        end
        return
    end
    
    mode = ARGS[1]
    
    try
        if mode == "quick"
            run_quick_4d_study()
        elseif mode == "standard"
            run_standard_4d_study()
        elseif mode == "intensive"
            run_intensive_4d_study()
        elseif mode == "custom"
            if length(ARGS) < 2
                println("Error: Custom mode requires function name")
                println("Available functions: $(keys(BENCHMARK_4D_FUNCTIONS))")
                return
            end
            func_name = Symbol(ARGS[2])
            if !haskey(BENCHMARK_4D_FUNCTIONS, func_name)
                println("Error: Unknown function $func_name")
                println("Available functions: $(keys(BENCHMARK_4D_FUNCTIONS))")
                return
            end
            run_custom_function_study(func_name)
        else
            println("Error: Unknown mode '$mode'")
            println("Available modes: quick, standard, intensive, custom")
        end
    catch e
        println("❌ Error during execution: $e")
        println("Stack trace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
