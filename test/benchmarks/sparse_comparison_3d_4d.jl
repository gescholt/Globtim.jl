# Comprehensive Benchmark: Sparse Re-optimization vs Simple Truncation
# Focus: 3D and 4D examples to validate high-precision re-optimization approach

using Globtim
using DataFrames
using CSV
using Statistics
using Printf
using Dates

include("benchmark_test_functions.jl")

# ============================================================================
# BENCHMARK CONFIGURATION
# ============================================================================

struct BenchmarkConfig
    dimensions::Vector{Int}
    degrees::Vector{Int}
    thresholds::Vector{Float64}
    n_test_points::Int
    n_eval_points::Int
    output_dir::String
    verbose::Bool
end

function default_benchmark_config()
    return BenchmarkConfig(
        [3, 4],              # dimensions
        [8, 10, 12],         # degrees
        [1e-6, 1e-5],        # thresholds
        100,                 # test points for error
        10000,               # evaluation points for timing
        "benchmark_results", # output directory
        true                 # verbose
    )
end

# ============================================================================
# SINGLE TEST EXECUTION
# ============================================================================

"""
Run single test case: baseline + truncation + re-optimization (Float64 & BigFloat).
"""
function run_single_benchmark(
    test_func,
    dim::Int,
    degree::Int,
    threshold::Float64;
    n_test_points::Int = 100,
    n_eval_points::Int = 10000,
    verbose::Bool = true
)
    fname = test_func.name
    f = test_func.func

    if verbose
        println("\n" * "="^70)
        println("Testing: $fname")
        println("  Dimension: $dim, Degree: $degree, Threshold: $threshold")
        println("  Description: $(test_func.description)")
        println("="^70)
    end

    # Phase 1: Baseline Construction
    if verbose; println("Phase 1: Baseline construction..."); end

    TR = test_input(f, dim=dim, center=zeros(dim), sample_range=1.0)

    t_baseline = @elapsed begin
        pol_baseline = Constructor(TR, degree, basis=:chebyshev, verbose=0)
    end

    n_coeffs_total = length(pol_baseline.coeffs)

    if verbose
        println("  ✓ Baseline: $n_coeffs_total coefficients, time=$(round(t_baseline, digits=3))s")
        println("  Condition number: $(pol_baseline.cond_vandermonde)")
    end

    # Phase 2: Simple Truncation
    if verbose; println("\nPhase 2: Simple truncation..."); end

    t_truncation = @elapsed begin
        result_trunc = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            mode = :relative,
            reoptimize = false
        )
    end

    n_coeffs_trunc = result_trunc.sparsity_info.new_nnz
    sparsity_trunc = n_coeffs_trunc / n_coeffs_total

    if verbose
        println("  ✓ Truncation: $n_coeffs_trunc coefficients ($(round(sparsity_trunc*100, digits=1))%)")
        println("  Time: $(round(t_truncation, digits=3))s")
        println("  L2-norm ratio: $(round(result_trunc.l2_ratio*100, digits=1))%")
    end

    # Phase 3: Re-optimization (Float64)
    if verbose; println("\nPhase 3: Re-optimization (Float64)..."); end

    t_reopt_f64 = @elapsed begin
        result_f64 = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            mode = :relative,
            reoptimize = true,
            precision = Float64,
            solver = :qr
        )
    end

    n_coeffs_f64 = result_f64.sparsity_info.new_nnz

    if verbose
        println("  ✓ Float64 reopt: $n_coeffs_f64 coefficients")
        println("  Time: $(round(t_reopt_f64, digits=3))s ($(round(t_reopt_f64/t_truncation, digits=1))x slower)")
        println("  L2-norm ratio: $(round(result_f64.l2_ratio*100, digits=1))%")
        println("  Condition number: $(result_f64.optimization_info.condition_number)")
    end

    # Phase 4: Re-optimization (BigFloat)
    if verbose; println("\nPhase 4: Re-optimization (BigFloat)..."); end

    t_reopt_bf = @elapsed begin
        result_bf = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            mode = :relative,
            reoptimize = true,
            precision = BigFloat,
            solver = :qr
        )
    end

    n_coeffs_bf = result_bf.sparsity_info.new_nnz

    if verbose
        println("  ✓ BigFloat reopt: $n_coeffs_bf coefficients")
        println("  Time: $(round(t_reopt_bf, digits=3))s ($(round(t_reopt_bf/t_truncation, digits=1))x slower)")
        println("  L2-norm ratio: $(round(result_bf.l2_ratio*100, digits=1))%")
        println("  Condition number: $(result_bf.optimization_info.condition_number)")
    end

    # Phase 5: Accuracy Evaluation
    if verbose; println("\nPhase 5: Accuracy evaluation..."); end

    test_grid = generate_test_grid(dim, Int(round(n_test_points^(1/dim))))

    errors_trunc = [abs(f(pt) - result_trunc.polynomial(pt...)) for pt in test_grid]
    errors_f64 = [abs(f(pt) - result_f64.polynomial(pt...)) for pt in test_grid]
    errors_bf = [abs(f(pt) - result_bf.polynomial(pt...)) for pt in test_grid]

    metrics_trunc = compute_error_metrics(f, result_trunc.polynomial, test_grid)
    metrics_f64 = compute_error_metrics(f, result_f64.polynomial, test_grid)
    metrics_bf = compute_error_metrics(f, result_bf.polynomial, test_grid)

    if verbose
        println("  Max errors:")
        println("    Truncation:      $(scientific(metrics_trunc.max_error))")
        println("    Float64 reopt:   $(scientific(metrics_f64.max_error))")
        println("    BigFloat reopt:  $(scientific(metrics_bf.max_error))")
        println("  Mean errors:")
        println("    Truncation:      $(scientific(metrics_trunc.mean_error))")
        println("    Float64 reopt:   $(scientific(metrics_f64.mean_error))")
        println("    BigFloat reopt:  $(scientific(metrics_bf.mean_error))")
    end

    # Phase 6: Evaluation Speed
    if verbose; println("\nPhase 6: Evaluation speed test..."); end

    eval_points = generate_random_test_points(dim, n_eval_points)

    # Dense baseline
    mono_dense = to_exact_monomial_basis(pol_baseline)
    t_eval_dense = @elapsed for pt in eval_points; mono_dense(pt...); end

    # Sparse variants
    t_eval_trunc = @elapsed for pt in eval_points; result_trunc.polynomial(pt...); end
    t_eval_f64 = @elapsed for pt in eval_points; result_f64.polynomial(pt...); end
    t_eval_bf = @elapsed for pt in eval_points; result_bf.polynomial(pt...); end

    speedup_trunc = t_eval_dense / t_eval_trunc
    speedup_f64 = t_eval_dense / t_eval_f64
    speedup_bf = t_eval_dense / t_eval_bf

    if verbose
        println("  Evaluation speedup ($(n_eval_points) points):")
        println("    Truncation:      $(round(speedup_trunc, digits=2))x")
        println("    Float64 reopt:   $(round(speedup_f64, digits=2))x")
        println("    BigFloat reopt:  $(round(speedup_bf, digits=2))x")
    end

    # Compile results
    result = (
        function_name = fname,
        category = test_func.category,
        expected_sparsity = test_func.expected_sparsity,
        dimension = dim,
        degree = degree,
        threshold = threshold,

        # Baseline
        n_coeffs_baseline = n_coeffs_total,
        time_baseline = t_baseline,
        cond_baseline = pol_baseline.cond_vandermonde,

        # Truncation
        n_coeffs_trunc = n_coeffs_trunc,
        sparsity_trunc = sparsity_trunc,
        time_truncation = t_truncation,
        l2_ratio_trunc = result_trunc.l2_ratio,
        max_error_trunc = metrics_trunc.max_error,
        mean_error_trunc = metrics_trunc.mean_error,
        rmse_trunc = metrics_trunc.rmse,

        # Float64 reopt
        n_coeffs_f64 = n_coeffs_f64,
        time_reopt_f64 = t_reopt_f64,
        l2_ratio_f64 = result_f64.l2_ratio,
        max_error_f64 = metrics_f64.max_error,
        mean_error_f64 = metrics_f64.mean_error,
        rmse_f64 = metrics_f64.rmse,
        cond_f64 = result_f64.optimization_info.condition_number,
        overhead_f64 = t_reopt_f64 / t_truncation,

        # BigFloat reopt
        n_coeffs_bf = n_coeffs_bf,
        time_reopt_bf = t_reopt_bf,
        l2_ratio_bf = result_bf.l2_ratio,
        max_error_bf = metrics_bf.max_error,
        mean_error_bf = metrics_bf.mean_error,
        rmse_bf = metrics_bf.rmse,
        cond_bf = result_bf.optimization_info.condition_number,
        overhead_bf = t_reopt_bf / t_truncation,

        # Evaluation speed
        time_eval_dense = t_eval_dense,
        time_eval_trunc = t_eval_trunc,
        time_eval_f64 = t_eval_f64,
        time_eval_bf = t_eval_bf,
        speedup_trunc = speedup_trunc,
        speedup_f64 = speedup_f64,
        speedup_bf = speedup_bf,

        # Improvements
        l2_improvement_f64 = result_f64.l2_ratio - result_trunc.l2_ratio,
        l2_improvement_bf = result_bf.l2_ratio - result_trunc.l2_ratio,
        error_reduction_f64 = (metrics_trunc.mean_error - metrics_f64.mean_error) / metrics_trunc.mean_error,
        error_reduction_bf = (metrics_trunc.mean_error - metrics_bf.mean_error) / metrics_trunc.mean_error
    )

    if verbose
        println("\n" * "="^70)
        println("✓ Test complete!")
        println("="^70)
    end

    return result
end

# ============================================================================
# FULL BENCHMARK SUITE
# ============================================================================

"""
Run complete benchmark suite across all dimensions, degrees, thresholds.
"""
function run_full_benchmark(config::BenchmarkConfig = default_benchmark_config())
    println("="^70)
    println("SPARSE RE-OPTIMIZATION BENCHMARK SUITE")
    println("="^70)
    println("Configuration:")
    println("  Dimensions: $(config.dimensions)")
    println("  Degrees: $(config.degrees)")
    println("  Thresholds: $(config.thresholds)")
    println("  Test points: $(config.n_test_points)")
    println("  Eval points: $(config.n_eval_points)")
    println("="^70)

    results = DataFrame[]

    for dim in config.dimensions
        test_funcs = get_test_functions(dim)

        println("\n" * "█"^70)
        println("█  DIMENSION: $(dim)D")
        println("█  Test functions: $(length(test_funcs))")
        println("█"^70)

        for test_func in test_funcs
            for degree in config.degrees
                for threshold in config.thresholds
                    try
                        result = run_single_benchmark(
                            test_func,
                            dim,
                            degree,
                            threshold;
                            n_test_points = config.n_test_points,
                            n_eval_points = config.n_eval_points,
                            verbose = config.verbose
                        )

                        push!(results, DataFrame(result))

                    catch e
                        @error "Test failed: $(test_func.name), dim=$dim, deg=$degree, thr=$threshold" exception=e
                    end
                end
            end
        end
    end

    # Combine results
    results_df = vcat(results...)

    # Save results
    mkpath(config.output_dir)
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    csv_file = joinpath(config.output_dir, "benchmark_$(timestamp).csv")
    CSV.write(csv_file, results_df)

    println("\n" * "="^70)
    println("✓ BENCHMARK COMPLETE!")
    println("  Results saved to: $csv_file")
    println("  Total tests: $(nrow(results_df))")
    println("="^70)

    return results_df
end

# ============================================================================
# ANALYSIS & REPORTING
# ============================================================================

"""
Generate comparison report from benchmark results.
"""
function generate_comparison_report(results::DataFrame)
    println("\n" * "="^70)
    println("COMPARISON REPORT: Re-optimization vs Truncation")
    println("="^70)

    # Overall statistics
    println("\n## Overall Statistics\n")
    println("Total test cases: $(nrow(results))")
    println("Dimensions: $(unique(results.dimension))")
    println("Degrees: $(sort(unique(results.degree)))")
    println("Functions: $(length(unique(results.function_name)))")

    # Accuracy improvements
    println("\n## Accuracy Improvements (BigFloat vs Truncation)\n")

    mean_l2_improvement = mean(results.l2_improvement_bf)
    cases_l2_better = count(results.l2_improvement_bf .> 0)
    cases_l2_much_better = count(results.l2_improvement_bf .> 0.05)

    println("L2-norm ratio improvement:")
    println("  Mean: $(round(mean_l2_improvement*100, digits=1))%")
    println("  Cases with improvement: $cases_l2_better / $(nrow(results)) ($(round(cases_l2_better/nrow(results)*100, digits=1))%)")
    println("  Cases with >5% improvement: $cases_l2_much_better / $(nrow(results))")

    mean_error_reduction = mean(filter(!isnan, results.error_reduction_bf)) * 100
    cases_error_better = count(results.error_reduction_bf .> 0)

    println("\nMean error reduction:")
    println("  Average: $(round(mean_error_reduction, digits=1))%")
    println("  Cases with reduction: $cases_error_better / $(nrow(results))")

    # Time overhead
    println("\n## Computational Overhead\n")

    println("BigFloat re-optimization time overhead:")
    println("  Median: $(round(median(results.overhead_bf), digits=1))x")
    println("  Mean: $(round(mean(results.overhead_bf), digits=1))x")
    println("  Max: $(round(maximum(results.overhead_bf), digits=1))x")

    cases_fast = count(results.time_reopt_bf .< 30.0)
    println("\nCases completing <30s: $cases_fast / $(nrow(results))")

    # Evaluation speedup
    println("\n## Evaluation Speedup (from sparsity)\n")

    println("Mean speedup:")
    println("  Truncation:     $(round(mean(results.speedup_trunc), digits=2))x")
    println("  Float64 reopt:  $(round(mean(results.speedup_f64), digits=2))x")
    println("  BigFloat reopt: $(round(mean(results.speedup_bf), digits=2))x")

    # Category breakdown
    println("\n## Breakdown by Function Category\n")

    for cat in unique(results.category)
        cat_results = results[results.category .== cat, :]
        n_cat = nrow(cat_results)

        println("Category: $cat ($n_cat cases)")
        println("  Mean L2 improvement: $(round(mean(cat_results.l2_improvement_bf)*100, digits=1))%")
        println("  Mean error reduction: $(round(mean(filter(!isnan, cat_results.error_reduction_bf))*100, digits=1))%")
        println("  Mean overhead: $(round(mean(cat_results.overhead_bf), digits=1))x")
        println()
    end

    # Dimension breakdown
    println("\n## Breakdown by Dimension\n")

    for dim in sort(unique(results.dimension))
        dim_results = results[results.dimension .== dim, :]

        println("Dimension: $(dim)D ($(nrow(dim_results)) cases)")
        println("  Mean L2 improvement: $(round(mean(dim_results.l2_improvement_bf)*100, digits=1))%")
        println("  Mean error reduction: $(round(mean(filter(!isnan, dim_results.error_reduction_bf))*100, digits=1))%")
        println("  Mean overhead: $(round(mean(dim_results.overhead_bf), digits=1))x")
        println("  Mean condition number: $(scientific(mean(dim_results.cond_bf)))")
        println()
    end

    # Recommendations
    println("\n## Recommendations\n")

    # Find cases where re-optimization helps most
    significant_improvement = results[results.l2_improvement_bf .> 0.05, :]

    if nrow(significant_improvement) > 0
        println("✓ Re-optimization recommended for:")
        for row in eachrow(significant_improvement)
            println("  • $(row.function_name) ($(row.dimension)D, degree=$(row.degree))")
            println("    L2 improvement: $(round(row.l2_improvement_bf*100, digits=1))%, overhead: $(round(row.overhead_bf, digits=1))x")
        end
    end

    println("\n" * "="^70)
end

"""
Helper function to format numbers in scientific notation.
"""
function scientific(x::Real)
    return @sprintf("%.2e", x)
end

# ============================================================================
# ENTRY POINT
# ============================================================================

"""
Run benchmark suite with default configuration.
"""
function run_benchmark()
    config = default_benchmark_config()
    results = run_full_benchmark(config)
    generate_comparison_report(results)
    return results
end

# Export main functions
export run_single_benchmark,
       run_full_benchmark,
       generate_comparison_report,
       run_benchmark,
       BenchmarkConfig,
       default_benchmark_config
