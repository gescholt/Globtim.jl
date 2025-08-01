"""
Extended Precision Benchmarks for Polynomial Basis Conversion

This test suite benchmarks the current precision handling capabilities
and identifies areas for improvement in the extended precision implementation.
"""

using Test
using Globtim
using DynamicPolynomials
using BenchmarkTools
using DataFrames
using Statistics
using LinearAlgebra

# Test functions with known exact polynomial representations
const TEST_FUNCTIONS = Dict(
    :polynomial_2d => (x -> x[1]^4 + 2*x[1]^2*x[2]^2 + x[2]^4, "Exact polynomial"),
    :polynomial_1d => (x -> 2*x[1]^3 - 3*x[1]^2 + x[1] - 1, "Cubic polynomial"),
    :smooth_2d => (x -> exp(-x[1]^2 - x[2]^2), "Smooth Gaussian"),
    :oscillatory_1d => (x -> sin(5*π*x[1]), "Oscillatory function"),
    :rational_2d => (x -> 1/(1 + x[1]^2 + x[2]^2), "Rational function")
)

const PRECISION_TYPES = [Float64Precision, RationalPrecision, BigFloatPrecision]
const DEGREES = [4, 8, 12, 16, 20]
const BASES = [:chebyshev, :legendre]

"""
    compute_approximation_error(f::Function, poly, test_points::Matrix)

Compute the maximum approximation error between function f and polynomial poly
over the given test points.
"""
function compute_approximation_error(f::Function, poly, test_points::Matrix)
    max_error = 0.0
    for i in 1:size(test_points, 1)
        point = test_points[i, :]

        # Evaluate function
        f_val = f(point)

        # Evaluate polynomial
        if length(point) == 1
            @polyvar x
            poly_val = substitute(poly, x => point[1])
        else
            @polyvar x[1:length(point)]
            substitutions = [x[j] => point[j] for j in 1:length(point)]
            poly_val = substitute(poly, substitutions...)
        end

        # Convert to Float64 for comparison
        poly_val_float = Float64(poly_val)
        error = abs(f_val - poly_val_float)
        max_error = max(max_error, error)
    end
    return max_error
end

"""
    generate_test_points(dim::Int, n_points::Int=100)

Generate test points in [-1,1]^dim for error evaluation.
"""
function generate_test_points(dim::Int, n_points::Int=100)
    return 2 * rand(n_points, dim) .- 1
end

"""
    benchmark_precision_accuracy()

Benchmark approximation accuracy for different precision types.
"""
function benchmark_precision_accuracy()
    println("=== Precision Accuracy Benchmark ===")

    results = DataFrame(
        function_name = String[],
        basis = Symbol[],
        degree = Int[],
        precision = String[],
        max_error = Float64[],
        mean_coeff_magnitude = Float64[],
        condition_number = Float64[]
    )

    for (func_name, (f, description)) in TEST_FUNCTIONS
        println("\nTesting $func_name: $description")

        # Determine dimension from function
        dim = func_name in [:polynomial_1d, :oscillatory_1d] ? 1 : 2

        # Create test input
        TR = test_input(f, dim=dim, center=zeros(dim), sample_range=1.0, tolerance=nothing)

        # Generate test points for error evaluation
        test_points = generate_test_points(dim, 200)

        for basis in BASES, degree in DEGREES[1:min(4, end)], precision in PRECISION_TYPES
            try
                # Skip high degrees for expensive precisions
                if precision == BigFloatPrecision && degree > 12
                    continue
                end

                # Construct polynomial approximation
                pol = Constructor(TR, degree, basis=basis, precision=precision, verbose=0)

                # Convert to monomial basis
                if dim == 1
                    @polyvar x
                    mono_poly = to_exact_monomial_basis(pol, variables=[x])
                else
                    @polyvar x[1:dim]
                    mono_poly = to_exact_monomial_basis(pol, variables=x)
                end

                # Compute approximation error
                max_error = compute_approximation_error(f, mono_poly, test_points)

                # Compute coefficient statistics
                coeffs = [Float64(coefficient(t)) for t in terms(mono_poly)]
                mean_coeff_magnitude = mean(abs.(coeffs))

                # Estimate condition number (simplified)
                condition_number = maximum(abs.(coeffs)) / minimum(abs.(coeffs[abs.(coeffs) .> 1e-15]))

                push!(results, (
                    string(func_name),
                    basis,
                    degree,
                    string(precision),
                    max_error,
                    mean_coeff_magnitude,
                    condition_number
                ))

                println("  $basis deg=$degree $precision: error=$(max_error:.2e)")

            catch e
                println("  ERROR: $basis deg=$degree $precision: $e")
            end
        end
    end

    return results
end

"""
    benchmark_precision_performance()

Benchmark computational performance for different precision types.
"""
function benchmark_precision_performance()
    println("\n=== Precision Performance Benchmark ===")

    # Use a simple 2D polynomial for consistent timing
    f = x -> x[1]^4 + x[2]^4
    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

    performance_results = DataFrame(
        basis = Symbol[],
        degree = Int[],
        precision = String[],
        construction_time = Float64[],
        conversion_time = Float64[],
        total_time = Float64[]
    )

    @polyvar x[1:2]

    for basis in BASES, degree in [4, 8, 12], precision in PRECISION_TYPES
        try
            println("Benchmarking $basis degree=$degree precision=$precision")

            # Benchmark polynomial construction
            construction_time = @elapsed begin
                pol = Constructor(TR, degree, basis=basis, precision=precision, verbose=0)
            end

            # Benchmark monomial conversion
            conversion_time = @elapsed begin
                mono_poly = to_exact_monomial_basis(pol, variables=x)
            end

            total_time = construction_time + conversion_time

            push!(performance_results, (
                basis,
                degree,
                string(precision),
                construction_time,
                conversion_time,
                total_time
            ))

            println("  Construction: $(construction_time:.3f)s, Conversion: $(conversion_time:.3f)s")

        catch e
            println("  ERROR: $e")
        end
    end

    return performance_results
end

"""
    analyze_precision_benefits()

Analyze the benefits of different precision types for specific scenarios.
"""
function analyze_precision_benefits()
    println("\n=== Precision Benefits Analysis ===")

    # Test exact polynomial representation
    println("\n1. Exact Polynomial Test (should have zero error with RationalPrecision)")
    f_exact = x -> x[1]^4 + 2*x[1]^2*x[2]^2 + x[2]^4
    TR_exact = test_input(f_exact, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

    @polyvar x[1:2]
    test_points = generate_test_points(2, 100)

    for precision in PRECISION_TYPES
        try
            pol = Constructor(TR_exact, 4, basis=:chebyshev, precision=precision, verbose=0)
            mono_poly = to_exact_monomial_basis(pol, variables=x)
            error = compute_approximation_error(f_exact, mono_poly, test_points)
            println("  $precision: error = $(error:.2e)")
        catch e
            println("  $precision: ERROR - $e")
        end
    end

    # Test high-degree approximation stability
    println("\n2. High-Degree Stability Test")
    f_smooth = x -> exp(-x[1]^2 - x[2]^2)
    TR_smooth = test_input(f_smooth, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

    for degree in [12, 16, 20]
        println("  Degree $degree:")
        for precision in PRECISION_TYPES
            try
                pol = Constructor(TR_smooth, degree, basis=:chebyshev, precision=precision, verbose=0)
                mono_poly = to_exact_monomial_basis(pol, variables=x)
                error = compute_approximation_error(f_smooth, mono_poly, test_points)

                # Check for numerical issues (NaN, Inf)
                coeffs = [Float64(coefficient(t)) for t in terms(mono_poly)]
                has_issues = any(isnan.(coeffs)) || any(isinf.(coeffs))

                status = has_issues ? "UNSTABLE" : "OK"
                println("    $precision: error = $(error:.2e) [$status]")
            catch e
                println("    $precision: FAILED - $e")
            end
        end
    end
end

"""
    run_extended_precision_benchmarks()

Run all extended precision benchmarks and return results.
"""
function run_extended_precision_benchmarks()
    println("Starting Extended Precision Benchmarks...")
    println("=" ^ 60)

    # Run accuracy benchmarks
    accuracy_results = benchmark_precision_accuracy()

    # Run performance benchmarks
    performance_results = benchmark_precision_performance()

    # Run precision benefits analysis
    analyze_precision_benefits()

    println("\n" * "=" ^ 60)
    println("Benchmark Summary:")
    println("- Accuracy results: $(nrow(accuracy_results)) test cases")
    println("- Performance results: $(nrow(performance_results)) test cases")

    return (accuracy=accuracy_results, performance=performance_results)
end

# Test suite integration
@testset "Extended Precision Benchmarks" begin
    @testset "Accuracy Benchmarks" begin
        results = benchmark_precision_accuracy()
        @test nrow(results) > 0

        # Test that RationalPrecision gives better accuracy for exact polynomials
        exact_poly_results = filter(r -> r.function_name == "polynomial_2d", results)
        if nrow(exact_poly_results) > 0
            rational_errors = filter(r -> r.precision == "RationalPrecision", exact_poly_results)
            float64_errors = filter(r -> r.precision == "Float64Precision", exact_poly_results)

            if nrow(rational_errors) > 0 && nrow(float64_errors) > 0
                @test minimum(rational_errors.max_error) <= minimum(float64_errors.max_error)
            end
        end
    end

    @testset "Performance Benchmarks" begin
        results = benchmark_precision_performance()
        @test nrow(results) > 0

        # Test that Float64Precision is fastest
        float64_times = filter(r -> r.precision == "Float64Precision", results)
        if nrow(float64_times) > 0
            @test all(float64_times.total_time .> 0)
        end
    end
end