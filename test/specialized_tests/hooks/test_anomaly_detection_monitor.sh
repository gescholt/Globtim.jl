#!/bin/bash

# Test framework for anomaly-detection-monitor hook
# Tests various anomaly detection scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_data_anomaly_monitor"
HOOK_PATH="${SCRIPT_DIR}/../../tools/hpc/hooks/anomaly_detection_monitor.sh"

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

# Test 1: Normal execution (no anomalies)
test_normal_execution() {
    log_test "Normal execution monitoring"

    # Create a normal log file
    cat > "${TEST_DIR}/normal_experiment.log" << 'EOF'
Starting experiment...
Grid generation completed: 20736 points
Polynomial construction took 5.2 seconds
Critical points found: 127
df_critical.z analysis completed in 1.1 seconds
L2 norm: 0.0456
Experiment completed successfully
EOF

    # Run the monitor
    if "${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1 | grep -q "No anomalies detected"; then
        log_pass "Normal execution correctly identified"
    else
        log_fail "False positive on normal execution"
    fi
}

# Test 2: High error rate detection
test_high_error_rate() {
    log_test "High error rate anomaly detection"

    # Create a log file with high error rate
    cat > "${TEST_DIR}/high_error_rate.log" << 'EOF'
ERROR: Failed to process point 1
ERROR: Failed to process point 2
ERROR: Failed to process point 3
Processing point 4
ERROR: Failed to process point 5
ERROR: Failed to process point 6
Processing point 7
ERROR: Failed to process point 8
ERROR: Failed to process point 9
ERROR: Failed to process point 10
EOF

    # Run the monitor
    if "${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1 | grep -q "ERROR RATE ANOMALY"; then
        log_pass "High error rate anomaly detected"
    else
        log_fail "Failed to detect high error rate anomaly"
    fi
}

# Test 3: Julia-specific anomaly detection
test_julia_anomalies() {
    log_test "Julia-specific anomaly detection"

    # Create a log file with Julia anomalies
    cat > "${TEST_DIR}/julia_anomalies.log" << 'EOF'
Starting Julia experiment...
Precompiling package A...
Precompiling package B...
Precompiling package C...
OutOfMemoryError: unable to allocate memory
GC: Total time spent in GC: 45.2%
Process computation...
StackOverflowError: stack space exhausted
signal (15): Terminated
EOF

    # Run the monitor
    local output=$("${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1)

    if echo "${output}" | grep -q "JULIA ANOMALY"; then
        log_pass "Julia-specific anomalies detected"
    else
        log_fail "Failed to detect Julia-specific anomalies"
    fi
}

# Test 4: Performance baseline analysis
test_performance_baseline() {
    log_test "Performance baseline analysis"

    # Create a log file with timing information
    cat > "${TEST_DIR}/performance_timing.log" << 'EOF'
Operation A took 2.1 seconds
Operation B took 1.8 seconds
Operation C took 2.3 seconds
Operation D took 45.7 seconds
Operation E took 1.9 seconds
EOF

    # Run the monitor
    if "${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1 | grep -q "PERFORMANCE ANOMALY"; then
        log_pass "Performance anomaly detected (outlier operation)"
    else
        log_fail "Failed to detect performance anomaly"
    fi
}

# Test 5: Long execution time detection
test_long_execution_time() {
    log_test "Long execution time anomaly detection"

    # Create a simple log file
    cat > "${TEST_DIR}/long_execution.log" << 'EOF'
Long running experiment...
Still processing...
EOF

    # Simulate a process that started 2 hours ago (exceeds 1 hour threshold)
    local old_start_time=$(($(date +%s) - 7200))

    # Run the monitor
    if "${HOOK_PATH}" "${TEST_DIR}" 0 "${old_start_time}" 2>&1 | grep -q "EXECUTION TIME ANOMALY"; then
        log_pass "Long execution time anomaly detected"
    else
        log_fail "Failed to detect long execution time anomaly"
    fi
}

# Test 6: Multiple log files analysis
test_multiple_log_files() {
    log_test "Multiple log files analysis"

    # Create multiple log files with different characteristics
    cat > "${TEST_DIR}/experiment_1.log" << 'EOF'
Normal experiment execution
Operation took 2.1 seconds
Completed successfully
EOF

    cat > "${TEST_DIR}/experiment_2.log" << 'EOF'
ERROR: Major failure occurred
ERROR: Unable to recover
EXCEPTION: System failure
EOF

    cat > "${TEST_DIR}/experiment_3.log" << 'EOF'
OutOfMemoryError: allocation failed
GC: Excessive garbage collection
StackOverflowError occurred
EOF

    # Run the monitor
    local output=$("${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1)

    local anomaly_count=$(echo "${output}" | grep -c "ANOMALY" || echo "0")

    if [[ $anomaly_count -gt 1 ]]; then
        log_pass "Multiple anomalies detected across log files"
    else
        log_fail "Failed to detect multiple anomalies"
    fi
}

# Test 7: Empty/missing log files handling
test_empty_log_handling() {
    log_test "Empty/missing log files handling"

    # Create an empty log file
    touch "${TEST_DIR}/empty.log"

    # Run the monitor (should handle gracefully)
    if "${HOOK_PATH}" "${TEST_DIR}" 0 $(($(date +%s) - 300)) 2>&1 | grep -q "No log content to analyze\|No anomalies detected"; then
        log_pass "Empty log files handled gracefully"
    else
        log_fail "Failed to handle empty log files gracefully"
    fi
}

# Main test execution
main() {
    echo "=== Anomaly Detection Monitor Test Suite ==="

    # Check if bc is available (required for some calculations)
    if ! command -v bc &> /dev/null; then
        log_info "Warning: bc calculator not available - some tests may be limited"
    fi

    setup_test_env

    # Run all tests
    test_normal_execution
    test_high_error_rate
    test_julia_anomalies
    test_performance_baseline
    test_long_execution_time
    test_multiple_log_files
    test_empty_log_handling

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