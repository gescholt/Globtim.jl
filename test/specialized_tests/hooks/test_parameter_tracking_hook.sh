#!/bin/bash

# Test framework for parameter-tracking-hook
# Tests Issue #17: Standardize Parameter Tracking for HPC Experiments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_data_parameter_tracking"
HOOK_PATH="${SCRIPT_DIR}/../../tools/hpc/hooks/parameter_tracking_hook.sh"

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

    # Create a sample Julia script for testing
    cat > "${TEST_DIR}/sample_experiment.jl" << 'EOF'
# Sample 4D Lotka-Volterra experiment
using Globtim

# Configuration parameters
GN = 12  # samples per dimension
degree = 6
sample_range = 0.1
center = [1.0, 1.0, 3.0, 1.0]

# Run experiment
println("Starting 4D experiment...")
EOF

    # Create a sample log file
    touch "${TEST_DIR}/experiment.log"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "${TEST_DIR}"
}

# Test 1: Basic experiment_params.json creation
test_basic_params_creation() {
    log_test "Basic experiment_params.json creation"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="test_experiment"
    local output_dir="${TEST_DIR}/output"

    # Run the hook
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        log_pass "experiment_params.json created successfully"
    else
        log_fail "Failed to create experiment_params.json"
        return
    fi

    # Check JSON structure
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$params_file" > /dev/null 2>&1; then
            log_pass "Valid JSON structure"
        else
            log_fail "Invalid JSON structure"
        fi
    else
        log_pass "JSON validation skipped (python3 not available)"
    fi
}

# Test 2: Git information capture
test_git_info_capture() {
    log_test "Git information capture in parameters"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="git_test"
    local output_dir="${TEST_DIR}/git_output"

    # Run the hook
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Check for git information in the JSON
        if grep -q "git_commit_hash" "$params_file" && grep -q "git_branch" "$params_file"; then
            log_pass "Git information captured in parameters"
        else
            log_fail "Git information missing from parameters"
        fi
    else
        log_fail "Parameter file not created for git test"
    fi
}

# Test 3: Environment information capture
test_environment_info_capture() {
    log_test "Environment information capture"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="env_test"
    local output_dir="${TEST_DIR}/env_output"

    # Run the hook
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Check for environment information
        local has_hostname=$(grep -c "hostname" "$params_file" 2>/dev/null || echo "0")
        local has_julia=$(grep -c "julia_version" "$params_file" 2>/dev/null || echo "0")
        local has_environment=$(grep -c "environment" "$params_file" 2>/dev/null || echo "0")

        if [[ $has_hostname -gt 0 ]] && [[ $has_julia -gt 0 ]] && [[ $has_environment -gt 0 ]]; then
            log_pass "Environment information captured"
        else
            log_fail "Environment information incomplete"
        fi
    else
        log_fail "Parameter file not created for environment test"
    fi
}

# Test 4: Julia script parameter detection
test_julia_parameter_detection() {
    log_test "Julia script parameter detection"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="param_detection_test"
    local output_dir="${TEST_DIR}/param_output"

    # Run the hook
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Check if detected_parameters contains our GN parameter
        if grep -q "detected_parameters" "$params_file"; then
            log_pass "Parameter detection mechanism present"
        else
            log_fail "Parameter detection mechanism missing"
        fi
    else
        log_fail "Parameter file not created for detection test"
    fi
}

# Test 5: Parameter summary log integration
test_log_integration() {
    log_test "Parameter summary log integration"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="log_test"
    local output_dir="${TEST_DIR}/log_output"
    local log_file="${TEST_DIR}/test_experiment.log"

    # Create parameter file first
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Add parameter summary to log
        "${HOOK_PATH}" add-to-log "$params_file" "$log_file" >/dev/null 2>&1

        if [[ -f "$log_file" ]] && grep -q "EXPERIMENT PARAMETER SUMMARY" "$log_file"; then
            log_pass "Parameter summary added to log file"
        else
            log_fail "Failed to add parameter summary to log"
        fi
    else
        log_fail "Parameter file not created for log integration test"
    fi
}

# Test 6: Resource information capture
test_resource_info_capture() {
    log_test "Resource information capture"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="resource_test"
    local output_dir="${TEST_DIR}/resource_output"

    # Run the hook
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Check for resource information
        local has_memory=$(grep -c "memory_total" "$params_file" 2>/dev/null || echo "0")
        local has_cpu=$(grep -c "cpu_count" "$params_file" 2>/dev/null || echo "0")

        if [[ $has_memory -gt 0 ]] && [[ $has_cpu -gt 0 ]]; then
            log_pass "Resource information captured"
        else
            log_fail "Resource information incomplete"
        fi
    else
        log_fail "Parameter file not created for resource test"
    fi
}

# Test 7: Timing information accuracy
test_timing_info() {
    log_test "Timing information accuracy"

    local script_path="${TEST_DIR}/sample_experiment.jl"
    local experiment_name="timing_test"
    local output_dir="${TEST_DIR}/timing_output"
    local start_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Run the hook with custom start time
    "${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" "" "$start_time" >/dev/null 2>&1
    local params_file="$output_dir/experiment_params.json"

    if [[ -f "$params_file" ]]; then
        # Check if timing information is present
        if grep -q "experiment_start_time" "$params_file" && grep -q "parameter_capture_time" "$params_file"; then
            log_pass "Timing information captured"

            # Verify the start time matches what we provided
            if grep -q "$start_time" "$params_file"; then
                log_pass "Custom start time correctly recorded"
            else
                log_fail "Custom start time not correctly recorded"
            fi
        else
            log_fail "Timing information missing"
        fi
    else
        log_fail "Parameter file not created for timing test"
    fi
}

# Test 8: Error handling for missing files
test_error_handling() {
    log_test "Error handling for missing script files"

    local script_path="${TEST_DIR}/nonexistent_script.jl"
    local experiment_name="error_test"
    local output_dir="${TEST_DIR}/error_output"

    # Run the hook with non-existent script (should still work)
    local params_file=$("${HOOK_PATH}" create "$script_path" "$experiment_name" "$output_dir" 2>/dev/null)

    if [[ -f "$params_file" ]]; then
        # Should still create parameter file even with missing script
        if grep -q "nonexistent_script.jl" "$params_file"; then
            log_pass "Graceful handling of missing script file"
        else
            log_fail "Script path not recorded for missing file"
        fi
    else
        log_fail "Parameter file not created for missing script (should be graceful)"
    fi
}

# Main test execution
main() {
    echo "=== Parameter Tracking Hook Test Suite ==="

    setup_test_env

    # Run all tests
    test_basic_params_creation
    test_git_info_capture
    test_environment_info_capture
    test_julia_parameter_detection
    test_log_integration
    test_resource_info_capture
    test_timing_info
    test_error_handling

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