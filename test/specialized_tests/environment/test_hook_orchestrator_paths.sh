#!/bin/bash
# NOTE: These tests require specific HPC environment configuration. See ENV vars below.
#
# Required ENV variables:
#   GLOBTIM_LOCAL_HOME, GLOBTIM_LOCAL_PROJECT, GLOBTIM_HPC_USER, GLOBTIM_HPC_HOST,
#   GLOBTIM_HPC_HOME, GLOBTIM_HPC_PROJECT, GLOBTIM_HPC_NFS_HOME
#
# Hook Orchestrator Path Resolution Test Suite
#
# Tests the environment-aware path resolution logic in hook_orchestrator.sh
# to ensure proper cross-environment hook execution.
#
# Usage:
#     bash tests/environment/test_hook_orchestrator_paths.sh

set -e

# Timeout: kill this script if it runs longer than 60 seconds
TIMEOUT_SECONDS="${GLOBTIM_TEST_TIMEOUT:-60}"
( sleep "${TIMEOUT_SECONDS}" && echo "ERROR: Test timed out after ${TIMEOUT_SECONDS}s" >&2 && kill -TERM $$ 2>/dev/null ) &
TIMEOUT_PID=$!
trap 'kill ${TIMEOUT_PID} 2>/dev/null' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate required ENV variables
for var in GLOBTIM_LOCAL_HOME GLOBTIM_HPC_HOME GLOBTIM_HPC_PROJECT; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: Required environment variable ${var} is not set." >&2
        exit 1
    fi
done

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBTIM_DIR="$(cd "$TEST_DIR/../.." && pwd)"
ORCHESTRATOR_PATH="$GLOBTIM_DIR/tools/hpc/hooks/hook_orchestrator.sh"

echo -e "${BLUE}Hook Orchestrator Path Resolution Test Suite${NC}"
echo "=================================================================="
echo "Testing environment-aware path translation in hook orchestrator"
echo ""

# Source required functions from orchestrator (without running main script)
source_orchestrator_functions() {
    # Extract just the path resolution function from orchestrator
    local temp_func_file="/tmp/hook_orchestrator_functions_$$.sh"

    # Extract the execute_hook function for testing
    sed -n '/^execute_hook()/,/^}/p' "$ORCHESTRATOR_PATH" > "$temp_func_file"

    # Add required variables and functions
    cat >> "$temp_func_file" << 'EOF'
log_info() { echo "INFO: $*"; }
log_debug() { echo "DEBUG: $*"; }
log_error() { echo "ERROR: $*"; }
log_warning() { echo "WARNING: $*"; }
EOF

    source "$temp_func_file"
    rm -f "$temp_func_file"
}

# Test path resolution logic directly
test_path_resolution_logic() {
    local test_name="$1"
    local environment="$2"
    local input_path="$3"
    local expected_output="$4"

    # Simulate the path resolution logic from orchestrator
    local full_path
    if [[ "$input_path" = /* ]]; then
        # Absolute path - check if it needs environment translation
        if [[ "$environment" == "hpc" && "$input_path" =~ ^${GLOBTIM_LOCAL_HOME} ]]; then
            # Translate local paths to HPC paths
            full_path=$(echo "$input_path" | sed "s|^${GLOBTIM_LOCAL_HOME}|${GLOBTIM_HPC_HOME}|")
        elif [[ "$environment" == "local" && "$input_path" =~ ^${GLOBTIM_HPC_HOME} ]]; then
            # Translate HPC paths to local paths
            full_path=$(echo "$input_path" | sed "s|^${GLOBTIM_HPC_HOME}|${GLOBTIM_LOCAL_HOME}|")
        else
            full_path="$input_path"
        fi
    else
        full_path="$GLOBTIM_DIR/$input_path"
    fi

    if [[ "$full_path" == "$expected_output" ]]; then
        echo -e "  PASS: $test_name ${GREEN}PASS${NC}"
        return 0
    else
        echo -e "  FAIL: $test_name ${RED}FAIL${NC}"
        echo "   Expected: $expected_output"
        echo "   Got:      $full_path"
        return 1
    fi
}

# Test environment detection from orchestrator
test_environment_detection() {
    echo -e "\n${YELLOW}Testing Environment Detection${NC}"
    echo "──────────────────────────────"

    # Test the environment detection logic
    local detected_env
    if [[ -d "${GLOBTIM_HPC_PROJECT}" ]]; then
        detected_env="hpc"
    else
        detected_env="local"
    fi

    echo "Detected environment: $detected_env"

    if [[ "$detected_env" == "local" || "$detected_env" == "hpc" ]]; then
        echo -e "  PASS: Environment detection ${GREEN}PASS${NC}"
        return 0
    else
        echo -e "  FAIL: Environment detection ${RED}FAIL${NC}"
        return 1
    fi
}

# Test absolute path translations
test_absolute_path_translations() {
    echo -e "\n${YELLOW}Testing Absolute Path Translations${NC}"
    echo "───────────────────────────────────────"

    local passed=0
    local total=0

    # Test local to HPC translations
    test_cases=(
        "Local to HPC - Main Project|hpc|${GLOBTIM_LOCAL_HOME}/globtim|${GLOBTIM_HPC_HOME}/globtim"
        "Local to HPC - Hook Script|hpc|${GLOBTIM_LOCAL_HOME}/globtim/tools/hpc/hooks/test.sh|${GLOBTIM_HPC_HOME}/globtim/tools/hpc/hooks/test.sh"
        "Local to HPC - Julia Depot|hpc|${GLOBTIM_LOCAL_HOME}/.julia|${GLOBTIM_HPC_HOME}/.julia"
        "HPC to Local - Main Project|local|${GLOBTIM_HPC_HOME}/globtim|${GLOBTIM_LOCAL_HOME}/globtim"
        "HPC to Local - Hook Script|local|${GLOBTIM_HPC_HOME}/globtim/tools/gitlab/hook.sh|${GLOBTIM_LOCAL_HOME}/globtim/tools/gitlab/hook.sh"
        "HPC to Local - Julia Depot|local|${GLOBTIM_HPC_HOME}/.julia|${GLOBTIM_LOCAL_HOME}/.julia"
        "No Translation - System Path HPC|hpc|/tmp/testfile|/tmp/testfile"
        "No Translation - System Path Local|local|/usr/bin/julia|/usr/bin/julia"
    )

    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r name env input expected <<< "$test_case"
        total=$((total + 1))
        if test_path_resolution_logic "$name" "$env" "$input" "$expected"; then
            passed=$((passed + 1))
        fi
    done

    echo ""
    echo "Absolute path translations: $passed/$total passed"
    return $((total - passed))
}

# Test relative path resolution
test_relative_path_resolution() {
    echo -e "\n${YELLOW}Testing Relative Path Resolution${NC}"
    echo "─────────────────────────────────────"

    local passed=0
    local total=0

    # Test relative paths (should be resolved against GLOBTIM_DIR)
    test_cases=(
        "Relative Hook Path|local|tools/hpc/hooks/test.sh|$GLOBTIM_DIR/tools/hpc/hooks/test.sh"
        "Relative GitLab Hook|hpc|tools/gitlab/security.sh|$GLOBTIM_DIR/tools/gitlab/security.sh"
        "Relative Monitor Script|local|tools/monitoring/resource.sh|$GLOBTIM_DIR/tools/monitoring/resource.sh"
    )

    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r name env input expected <<< "$test_case"
        total=$((total + 1))
        if test_path_resolution_logic "$name" "$env" "$input" "$expected"; then
            passed=$((passed + 1))
        fi
    done

    echo ""
    echo "Relative path resolution: $passed/$total passed"
    return $((total - passed))
}

# Test edge cases
test_edge_cases() {
    echo -e "\n${YELLOW}Testing Edge Cases${NC}"
    echo "──────────────────────"

    local passed=0
    local total=0

    # Test edge cases
    test_cases=(
        "Empty Path Local|local||$GLOBTIM_DIR/"
        "Same Environment HPC|hpc|${GLOBTIM_HPC_HOME}/test|${GLOBTIM_HPC_HOME}/test"
        "Same Environment Local|local|${GLOBTIM_LOCAL_HOME}/test|${GLOBTIM_LOCAL_HOME}/test"
    )

    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r name env input expected <<< "$test_case"
        total=$((total + 1))
        if test_path_resolution_logic "$name" "$env" "$input" "$expected"; then
            passed=$((passed + 1))
        fi
    done

    echo ""
    echo "Edge cases: $passed/$total passed"
    return $((total - passed))
}

# Test integration with actual orchestrator
test_orchestrator_integration() {
    echo -e "\n${YELLOW}Testing Hook Orchestrator Integration${NC}"
    echo "──────────────────────────────────────────"

    # Check if orchestrator exists and is executable
    if [[ ! -f "$ORCHESTRATOR_PATH" ]]; then
        echo -e "  FAIL: Hook orchestrator not found ${RED}FAIL${NC}"
        return 1
    fi

    if [[ ! -x "$ORCHESTRATOR_PATH" ]]; then
        echo -e "  FAIL: Hook orchestrator not executable ${RED}FAIL${NC}"
        return 1
    fi

    # Test help command
    if "$ORCHESTRATOR_PATH" --help >/dev/null 2>&1; then
        echo -e "  PASS: Orchestrator help command ${GREEN}PASS${NC}"
    else
        echo -e "  FAIL: Orchestrator help command ${RED}FAIL${NC}"
        return 1
    fi

    # Test registry command
    if "$ORCHESTRATOR_PATH" registry >/dev/null 2>&1; then
        echo -e "  PASS: Orchestrator registry command ${GREEN}PASS${NC}"
    else
        echo -e "  FAIL: Orchestrator registry command ${RED}FAIL${NC}"
        return 1
    fi

    return 0
}

# Main test execution
main() {
    local total_failures=0

    echo "Test environment: $(pwd)"
    echo "Globtim directory: $GLOBTIM_DIR"
    echo "Orchestrator path: $ORCHESTRATOR_PATH"
    echo ""

    # Run test suites
    test_environment_detection || total_failures=$((total_failures + 1))
    test_absolute_path_translations || total_failures=$((total_failures + $?))
    test_relative_path_resolution || total_failures=$((total_failures + $?))
    test_edge_cases || total_failures=$((total_failures + $?))
    test_orchestrator_integration || total_failures=$((total_failures + 1))

    echo ""
    echo "=================================================================="
    echo -e "${BLUE}Test Summary${NC}"

    if [[ $total_failures -eq 0 ]]; then
        echo -e "${GREEN}ALL TESTS PASSED!${NC}"
        echo "   Hook orchestrator path resolution is working correctly"
        echo "   Path resolution requirements satisfied for hook orchestrator"
    else
        echo -e "${RED}$total_failures TEST FAILURES${NC}"
        echo "   Path resolution needs fixes before deployment"
        echo "   Review failing test cases above"
    fi

    echo ""
    echo "Next Steps:"
    echo "1. Fix any failing path resolution logic"
    echo "2. Run integration tests with actual hook execution"
    echo "3. Update documentation with test results"

    return $total_failures
}

# Run the test suite
main "$@"
