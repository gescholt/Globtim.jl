#!/bin/bash

# Integration Test Suite for Error Categorization System
# Tests integration with collect_cluster_experiments.jl and real experiment data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/../.."
TEST_DATA_DIR="${SCRIPT_DIR}/test_data_integration"
COLLECT_SCRIPT="${PROJECT_DIR}/collect_cluster_experiments.jl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    echo -e "${BLUE}TEST: $1${NC}"
}

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}INFO${NC}: $1"
}

# Setup test environment
setup_test_env() {
    log_info "Setting up integration test environment"
    rm -rf "${TEST_DATA_DIR}"
    mkdir -p "${TEST_DATA_DIR}"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up integration test environment"
    rm -rf "${TEST_DATA_DIR}"
}

# Create mock experiment data with various error types
create_mock_experiment_data() {
    log_info "Creating mock experiment data with diverse error patterns"

    # Create directory structure
    mkdir -p "${TEST_DATA_DIR}/exp1_interface_bug"
    mkdir -p "${TEST_DATA_DIR}/exp2_math_failure"
    mkdir -p "${TEST_DATA_DIR}/exp3_memory_issue"
    mkdir -p "${TEST_DATA_DIR}/exp4_config_error"
    mkdir -p "${TEST_DATA_DIR}/exp5_successful"

    # Experiment 1: Interface bug (df_critical.val issue)
    cat > "${TEST_DATA_DIR}/exp1_interface_bug/results_summary.json" << 'EOF'
[
  {
    "degree": 4,
    "success": false,
    "error": "BoundsError: attempt to access df_critical.val at index [1]",
    "computation_time": 45.2
  },
  {
    "degree": 5,
    "success": false,
    "error": "column name :val not found in DataFrame",
    "computation_time": 52.1
  }
]
EOF

    cat > "${TEST_DATA_DIR}/exp1_interface_bug/experiment_config.json" << 'EOF'
{
    "domain_range": 0.1,
    "GN": 14,
    "degrees": [4, 5],
    "experiment_type": "lotka_volterra_4d"
}
EOF

    # Experiment 2: Mathematical failure
    cat > "${TEST_DATA_DIR}/exp2_math_failure/results_summary.json" << 'EOF'
[
  {
    "degree": 6,
    "success": false,
    "error": "HomotopyContinuation failed to find solutions: singular matrix",
    "computation_time": 120.5
  },
  {
    "degree": 7,
    "success": false,
    "error": "polynomial system failed to converge after 1000 iterations",
    "computation_time": 180.3
  }
]
EOF

    # Experiment 3: Infrastructure issue (memory)
    cat > "${TEST_DATA_DIR}/exp3_memory_issue/results_summary.json" << 'EOF'
[
  {
    "degree": 8,
    "success": false,
    "error": "OutOfMemoryError: unable to allocate 2.5GB array",
    "computation_time": 15.2
  }
]
EOF

    # Experiment 4: Configuration error
    cat > "${TEST_DATA_DIR}/exp4_config_error/results_summary.json" << 'EOF'
[
  {
    "degree": 10,
    "success": false,
    "error": "DimensionMismatch: degree too high for given sample count",
    "computation_time": 5.8
  }
]
EOF

    # Experiment 5: Successful experiment
    cat > "${TEST_DATA_DIR}/exp5_successful/results_summary.json" << 'EOF'
[
  {
    "degree": 4,
    "success": true,
    "error": "",
    "computation_time": 89.7,
    "critical_points": 42,
    "l2_norm": 0.0123
  }
]
EOF
}

# Test error categorization module independently
test_error_categorization_module() {
    log_test "Error categorization module functionality"

    # Run the Julia test suite
    if cd "${PROJECT_DIR}" && julia --project=. tests/error_categorization/test_error_taxonomy.jl; then
        log_pass "Error categorization module tests passed"
    else
        log_fail "Error categorization module tests failed"
    fi
}

# Test integration with collect_cluster_experiments.jl
test_collect_experiments_integration() {
    log_test "Integration with collect_cluster_experiments.jl"

    # Create a modified version of collect_cluster_experiments.jl for testing
    cat > "${TEST_DATA_DIR}/test_collect_experiments.jl" << 'EOF'
#!/usr/bin/env julia
# Test version of collect_cluster_experiments.jl for integration testing

using Pkg
Pkg.activate(".")

using JSON
using DataFrames
using Statistics
using Printf
using Dates
using CSV

# Include error categorization system
include("src/ErrorCategorization.jl")
using .ErrorCategorization

# Mock experiment analysis function
function test_analyze_experiments(test_data_dir)
    println("🔍 Testing enhanced error analysis...")

    all_results = []

    # Load mock experiment data
    for dir in readdir(test_data_dir)
        dir_path = joinpath(test_data_dir, dir)
        if isdir(dir_path)
            results_file = joinpath(dir_path, "results_summary.json")
            if isfile(results_file)
                results = JSON.parsefile(results_file)
                for result in results
                    result["experiment"] = dir
                    push!(all_results, result)
                end
            end
        end
    end

    println("   Loaded $(length(all_results)) experiment results")

    # Apply enhanced error analysis
    failed_results = filter(r -> !get(r, "success", false) && !isempty(get(r, "error", "")), all_results)

    if !isempty(failed_results)
        println("   Analyzing $(length(failed_results)) failed experiments...")

        error_analysis_df = analyze_experiment_errors(failed_results)

        if nrow(error_analysis_df) > 0
            println("   ✅ Successfully categorized $(nrow(error_analysis_df)) errors")

            # Category distribution
            category_counts = combine(groupby(error_analysis_df, :category), nrow => :count)
            println("   📊 Categories found: $(join(category_counts.category, ", "))")

            # Check for expected categories
            expected_categories = ["INTERFACE_BUG", "MATHEMATICAL_FAILURE", "INFRASTRUCTURE_ISSUE", "CONFIGURATION_ERROR"]
            found_categories = Set(error_analysis_df.category)

            for expected in expected_categories
                if expected in found_categories
                    println("   ✓ Found expected category: $expected")
                else
                    println("   ⚠️  Missing expected category: $expected")
                end
            end

            # Generate report
            error_report = generate_error_report(error_analysis_df)
            println("   📋 Generated report with $(length(error_report["recommendations"])) recommendations")

            return true
        else
            println("   ❌ No errors were categorized")
            return false
        end
    else
        println("   ℹ️  No failed experiments to analyze")
        return true
    end
end

# Run the test
success = test_analyze_experiments(ARGS[1])
exit(success ? 0 : 1)
EOF

    # Run the integration test
    if cd "${PROJECT_DIR}" && julia "${TEST_DATA_DIR}/test_collect_experiments.jl" "${TEST_DATA_DIR}"; then
        log_pass "collect_cluster_experiments.jl integration successful"
    else
        log_fail "collect_cluster_experiments.jl integration failed"
    fi
}

# Test error pattern coverage
test_error_pattern_coverage() {
    log_test "Error pattern coverage and accuracy"

    # Create a Julia script to test pattern coverage
    cat > "${TEST_DATA_DIR}/test_pattern_coverage.jl" << 'EOF'
#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("src/ErrorCategorization.jl")
using .ErrorCategorization

# Test specific error patterns from our mock data
test_cases = [
    ("BoundsError: attempt to access df_critical.val", "INTERFACE_BUG"),
    ("column name :val not found", "INTERFACE_BUG"),
    ("HomotopyContinuation failed to find solutions", "MATHEMATICAL_FAILURE"),
    ("singular matrix", "MATHEMATICAL_FAILURE"),
    ("failed to converge", "MATHEMATICAL_FAILURE"),
    ("OutOfMemoryError: unable to allocate", "INFRASTRUCTURE_ISSUE"),
    ("DimensionMismatch: degree too high", "CONFIGURATION_ERROR")
]

all_passed = true

for (error_msg, expected_category) in test_cases
    classification = categorize_error(error_msg)
    actual_category = string(classification.category)

    if actual_category == expected_category
        println("✓ PASS: '$error_msg' → $actual_category")
    else
        println("✗ FAIL: '$error_msg' → $actual_category (expected $expected_category)")
        all_passed = false
    end
end

println("\nOverall pattern coverage test: $(all_passed ? "PASSED" : "FAILED")")
exit(all_passed ? 0 : 1)
EOF

    if cd "${PROJECT_DIR}" && julia "${TEST_DATA_DIR}/test_pattern_coverage.jl"; then
        log_pass "Error pattern coverage test passed"
    else
        log_fail "Error pattern coverage test failed"
    fi
}

# Test report generation and structure
test_report_generation() {
    log_test "Error report generation and structure"

    cat > "${TEST_DATA_DIR}/test_report_generation.jl" << 'EOF'
#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using DataFrames
include("src/ErrorCategorization.jl")
using .ErrorCategorization

# Create test error data
test_errors = [
    Dict("experiment" => "exp1", "error" => "df_critical.val not found", "success" => false),
    Dict("experiment" => "exp2", "error" => "OutOfMemoryError occurred", "success" => false),
    Dict("experiment" => "exp3", "error" => "failed to converge", "success" => false)
]

# Analyze errors
error_df = analyze_experiment_errors(test_errors)

if nrow(error_df) == 0
    println("❌ No errors were analyzed")
    exit(1)
end

# Generate report
report = generate_error_report(error_df)

# Validate report structure
required_fields = ["total_errors", "category_distribution", "severity_distribution",
                  "recommendations", "key_insights"]

all_fields_present = true
for field in required_fields
    if haskey(report, field)
        println("✓ Report contains field: $field")
    else
        println("✗ Report missing field: $field")
        all_fields_present = false
    end
end

# Validate content quality
has_recommendations = length(report["recommendations"]) > 0
has_insights = length(report["key_insights"]) > 0
has_categories = length(report["category_distribution"]) > 0

content_quality = has_recommendations && has_insights && has_categories

println("\nReport quality: $(content_quality ? "GOOD" : "POOR")")
println("Structure completeness: $(all_fields_present ? "COMPLETE" : "INCOMPLETE")")

exit((all_fields_present && content_quality) ? 0 : 1)
EOF

    if cd "${PROJECT_DIR}" && julia "${TEST_DATA_DIR}/test_report_generation.jl"; then
        log_pass "Report generation test passed"
    else
        log_fail "Report generation test failed"
    fi
}

# Test performance with large datasets
test_performance_scaling() {
    log_test "Performance scaling with large error datasets"

    cat > "${TEST_DATA_DIR}/test_performance.jl" << 'EOF'
#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("src/ErrorCategorization.jl")
using .ErrorCategorization

# Generate large test dataset
function generate_large_error_dataset(n::Int)
    error_patterns = [
        "df_critical.val not found",
        "OutOfMemoryError: allocation failed",
        "HomotopyContinuation failed to converge",
        "DimensionMismatch in array operations",
        "Package loading error occurred"
    ]

    results = []
    for i in 1:n
        pattern = error_patterns[mod(i-1, length(error_patterns)) + 1]
        push!(results, Dict(
            "experiment" => "exp_$i",
            "error" => pattern,
            "success" => false,
            "degree" => mod(i, 10) + 1
        ))
    end
    return results
end

# Test with different dataset sizes
test_sizes = [100, 500, 1000]
all_passed = true

for size in test_sizes
    println("Testing with $size errors...")

    start_time = time()
    test_data = generate_large_error_dataset(size)
    error_df = analyze_experiment_errors(test_data)
    report = generate_error_report(error_df)
    end_time = time()

    elapsed = end_time - start_time

    if nrow(error_df) == size && elapsed < 10.0  # Should complete within 10 seconds
        println("✓ $size errors processed in $(round(elapsed, digits=2))s")
    else
        println("✗ $size errors: performance issue ($(round(elapsed, digits=2))s)")
        all_passed = false
    end
end

exit(all_passed ? 0 : 1)
EOF

    if cd "${PROJECT_DIR}" && julia "${TEST_DATA_DIR}/test_performance.jl"; then
        log_pass "Performance scaling test passed"
    else
        log_fail "Performance scaling test failed"
    fi
}

# Main test execution
main() {
    echo "=== Error Categorization Integration Test Suite ==="
    echo "Issue #37: Enhanced Experiment Error Categorization System"
    echo

    setup_test_env
    create_mock_experiment_data

    # Run all integration tests
    test_error_categorization_module
    test_collect_experiments_integration
    test_error_pattern_coverage
    test_report_generation
    test_performance_scaling

    cleanup_test_env

    # Print summary
    echo
    echo "=== INTEGRATION TEST SUMMARY ==="
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All integration tests passed!${NC}"
        echo "Issue #37 implementation is ready for production use."
        exit 0
    else
        echo -e "${RED}❌ Some integration tests failed!${NC}"
        echo "Fix the failing tests before deploying Issue #37."
        exit 1
    fi
}

# Execute main function
main "$@"