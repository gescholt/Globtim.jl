#!/bin/bash

# Test framework for auto-result-analyzer hook
# Tests common interface debugging scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_data_auto_analyzer"
HOOK_PATH="${SCRIPT_DIR}/../../tools/hpc/hooks/auto_result_analyzer.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    echo "TEST: $1"
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
    log_info "Setting up test environment"
    rm -rf "${TEST_DIR}"
    mkdir -p "${TEST_DIR}"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "${TEST_DIR}"
}

# Test 1: Interface bug detection (df_critical.val vs df_critical.z)
test_interface_bug_detection() {
    log_test "Interface bug detection (df_critical.val usage)"

    # Create a test log file with the interface bug
    cat > "${TEST_DIR}/interface_bug.log" << 'EOF'
Processing degree 6...
degree_results["best_value"] = minimum(df_critical.val)
degree_results["worst_value"] = maximum(df_critical.val)
degree_results["mean_value"] = mean(df_critical.val)
ERROR: BoundsError: attempt to access 0-element Vector{Float64} at index [1]
EOF

    # Run the analyzer
    if "${HOOK_PATH}" "${TEST_DIR}" 2>&1 | grep -q "INTERFACE BUG DETECTED"; then
        log_pass "Detected df_critical.val interface bug"
    else
        log_fail "Failed to detect df_critical.val interface bug"
    fi
}

# Test 2: Correct usage detection (df_critical.z)
test_correct_usage_detection() {
    log_test "Correct usage detection (df_critical.z)"

    # Create a test log file with correct usage
    cat > "${TEST_DIR}/correct_usage.log" << 'EOF'
Processing degree 6...
degree_results["best_value"] = minimum(df_critical.z)
degree_results["worst_value"] = maximum(df_critical.z)
degree_results["mean_value"] = mean(df_critical.z)
✓ Analysis completed successfully
EOF

    # Run the analyzer
    if "${HOOK_PATH}" "${TEST_DIR}" 2>&1 | grep -q "Correct column usage detected"; then
        log_pass "Detected correct df_critical.z usage"
    else
        log_fail "Failed to detect correct df_critical.z usage"
    fi
}

# Test 3: JSON result analysis
test_json_result_analysis() {
    log_test "JSON result analysis"

    # Create a test JSON file with interface error
    cat > "${TEST_DIR}/failed_experiment.json" << 'EOF'
{
    "status": "failed",
    "error": "BoundsError: attempt to access df_critical.val",
    "experiment_id": "test_001",
    "timestamp": "2025-09-21T10:30:00"
}
EOF

    # Create a successful experiment JSON
    cat > "${TEST_DIR}/successful_experiment.json" << 'EOF'
{
    "status": "success",
    "results": {
        "critical_points": 42,
        "l2_norm": 0.0123
    },
    "experiment_id": "test_002",
    "timestamp": "2025-09-21T10:35:00"
}
EOF

    # Run the analyzer
    local output=$("${HOOK_PATH}" "${TEST_DIR}" 2>&1)

    if echo "${output}" | grep -q "Experiment failed" && echo "${output}" | grep -q "Experiment completed successfully"; then
        log_pass "JSON analysis detected both failed and successful experiments"
    else
        log_fail "JSON analysis failed to properly categorize experiments"
    fi
}

# Test 4: MethodError detection
test_method_error_detection() {
    log_test "MethodError detection"

    # Create a test log file with MethodError
    cat > "${TEST_DIR}/method_error.log" << 'EOF'
ERROR: MethodError: no method matching create_level_set_visualization(::typeof(tref_3d), ::Array{SVector{3, Float64}, 3}, ::DataFrame, ::Tuple{Float64, Float64})
The function `create_level_set_visualization` exists, but no method is defined for this combination of argument types.
EOF

    # Run the analyzer
    if "${HOOK_PATH}" "${TEST_DIR}" 2>&1 | grep -q "Julia error pattern.*detected"; then
        log_pass "Detected MethodError pattern"
    else
        log_fail "Failed to detect MethodError pattern"
    fi
}

# Test 5: No issues scenario
test_no_issues_scenario() {
    log_test "No issues scenario"

    # Create clean log files
    cat > "${TEST_DIR}/clean_experiment.log" << 'EOF'
Starting experiment...
Grid generation completed: 20736 points
Polynomial construction successful
Critical points found: 127
df_critical.z analysis completed
L2 norm: 0.0456
Experiment completed successfully
EOF

    cat > "${TEST_DIR}/clean_result.json" << 'EOF'
{
    "status": "success",
    "results": {
        "critical_points": 127,
        "l2_norm": 0.0456
    }
}
EOF

    # Run the analyzer
    if "${HOOK_PATH}" "${TEST_DIR}" 2>&1 | grep -q "No interface issues detected"; then
        log_pass "Correctly identified clean experiment with no issues"
    else
        log_fail "False positive on clean experiment"
    fi
}

# Test 6: Multiple files analysis
test_multiple_files_analysis() {
    log_test "Multiple files analysis"

    # Create multiple test files with mixed issues
    cat > "${TEST_DIR}/multi_1.log" << 'EOF'
degree_results["best_value"] = minimum(df_critical.val)
EOF

    cat > "${TEST_DIR}/multi_2.log" << 'EOF'
degree_results["best_value"] = minimum(df_critical.z)
EOF

    cat > "${TEST_DIR}/multi_3.json" << 'EOF'
{"status": "success"}
EOF

    # Run the analyzer
    local output=$("${HOOK_PATH}" "${TEST_DIR}" 2>&1)

    if echo "${output}" | grep -q "Files analyzed: 3" && echo "${output}" | grep -q "Issues found: 1"; then
        log_pass "Multiple files analysis with correct counts"
    else
        log_fail "Multiple files analysis count mismatch"
    fi
}

# Main test execution
main() {
    echo "=== Auto-Result-Analyzer Hook Test Suite ==="

    setup_test_env

    # Run all tests
    test_interface_bug_detection
    test_correct_usage_detection
    test_json_result_analysis
    test_method_error_detection
    test_no_issues_scenario
    test_multiple_files_analysis

    cleanup_test_env

    # Print summary
    echo
    echo "=== TEST SUMMARY ==="
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"