#!/bin/bash
# Test Suite for Issue #38: Remove Hook Orchestrator Fallback Mechanisms
# Tests fail-fast behavior when hooks fail instead of falling back to defaults

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBTIM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORCHESTRATOR="$GLOBTIM_DIR/tools/hpc/hooks/hook_orchestrator.sh"
TEST_HOOKS_DIR="$SCRIPT_DIR/test_hooks"
TEST_STATE_DIR="$SCRIPT_DIR/test_state"
TEST_LOG_DIR="$SCRIPT_DIR/test_logs"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup and cleanup functions
setup_test_environment() {
    echo -e "${BLUE}Setting up test environment...${NC}"

    # Create test directories
    mkdir -p "$TEST_HOOKS_DIR" "$TEST_STATE_DIR" "$TEST_LOG_DIR"

    # Create test hook registry with intentionally failing hooks
    cat > "$TEST_HOOKS_DIR/test_registry.json" << 'EOF'
{
    "version": "1.0.0",
    "description": "Test registry for Issue #38 fallback removal",
    "hooks": {
        "failing_critical_hook": {
            "path": "tests/hooks/test_hooks/failing_hook.sh",
            "phases": ["validation"],
            "contexts": ["test"],
            "experiment_types": ["test"],
            "priority": 10,
            "timeout": 5,
            "retry_count": 1,
            "critical": true,
            "description": "Critical hook that always fails"
        },
        "failing_non_critical_hook": {
            "path": "tests/hooks/test_hooks/failing_hook.sh",
            "phases": ["preparation"],
            "contexts": ["test"],
            "experiment_types": ["test"],
            "priority": 20,
            "timeout": 5,
            "retry_count": 1,
            "critical": false,
            "description": "Non-critical hook that always fails"
        },
        "nonexistent_hook": {
            "path": "tests/hooks/test_hooks/nonexistent_hook.sh",
            "phases": ["execution"],
            "contexts": ["test"],
            "experiment_types": ["test"],
            "priority": 30,
            "timeout": 5,
            "retry_count": 1,
            "critical": true,
            "description": "Hook that does not exist"
        },
        "successful_hook": {
            "path": "tests/hooks/test_hooks/successful_hook.sh",
            "phases": ["completion"],
            "contexts": ["test"],
            "experiment_types": ["test"],
            "priority": 40,
            "timeout": 5,
            "retry_count": 1,
            "critical": false,
            "description": "Hook that always succeeds"
        }
    }
}
EOF

    # Create test hooks
    cat > "$TEST_HOOKS_DIR/failing_hook.sh" << 'EOF'
#!/bin/bash
# Test hook that always fails
echo "Failing hook executed with context: $1"
echo "This hook is designed to fail for testing purposes" >&2
exit 1
EOF

    cat > "$TEST_HOOKS_DIR/successful_hook.sh" << 'EOF'
#!/bin/bash
# Test hook that always succeeds
echo "Successful hook executed with context: $1"
echo "Hook completed successfully"
exit 0
EOF

    # Make hooks executable
    chmod +x "$TEST_HOOKS_DIR/failing_hook.sh"
    chmod +x "$TEST_HOOKS_DIR/successful_hook.sh"

    echo -e "${GREEN}Test environment setup complete${NC}"
}

cleanup_test_environment() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    rm -rf "$TEST_HOOKS_DIR" "$TEST_STATE_DIR" "$TEST_LOG_DIR"
    echo -e "${GREEN}Test environment cleaned up${NC}"
}

# Test utility functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "${BOLD}${BLUE}Running test: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test functions for specific fallback mechanisms

test_critical_hook_failure_aborts_phase() {
    echo "Testing critical hook failure aborts phase execution"

    # Override environment variables to use test registry
    export GLOBTIM_DIR="$GLOBTIM_DIR"
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export REGISTRY_FILE="$TEST_HOOKS_DIR/hook_registry.json"

    # Copy test registry to expected location
    cp "$TEST_HOOKS_DIR/test_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase with failing critical hook - should fail
    if "$ORCHESTRATOR" phase validation test 2>/dev/null; then
        echo "ERROR: Phase execution should have failed with critical hook failure"
        return 1
    fi

    echo "✓ Critical hook failure correctly aborted phase execution"
    return 0
}

test_nonexistent_critical_hook_fails_fast() {
    echo "Testing nonexistent critical hook fails fast"

    # Override environment variables to use test registry
    export GLOBTIM_DIR="$GLOBTIM_DIR"
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export REGISTRY_FILE="$TEST_HOOKS_DIR/hook_registry.json"

    # Copy test registry to expected location
    cp "$TEST_HOOKS_DIR/test_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase with nonexistent critical hook - should fail immediately
    if "$ORCHESTRATOR" phase execution test 2>/dev/null; then
        echo "ERROR: Phase execution should have failed with nonexistent critical hook"
        return 1
    fi

    echo "✓ Nonexistent critical hook correctly failed fast"
    return 0
}

test_non_critical_hook_failure_fails_fast() {
    echo "Testing non-critical hook failure now fails fast (no more fallback)"

    # Override environment variables to use test registry
    export GLOBTIM_DIR="$GLOBTIM_DIR"
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export REGISTRY_FILE="$TEST_HOOKS_DIR/hook_registry.json"

    # Copy test registry to expected location
    cp "$TEST_HOOKS_DIR/test_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase with failing non-critical hook - should now fail
    if "$ORCHESTRATOR" phase preparation test 2>/dev/null; then
        echo "ERROR: Phase execution should have failed - no more fallback for non-critical hooks"
        return 1
    fi

    echo "✓ Non-critical hook failure correctly failed fast (no fallback)"
    return 0
}

test_successful_hook_execution() {
    echo "Testing successful hook execution"

    # Override environment variables to use test registry
    export GLOBTIM_DIR="$GLOBTIM_DIR"
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export REGISTRY_FILE="$TEST_HOOKS_DIR/hook_registry.json"

    # Copy test registry to expected location
    cp "$TEST_HOOKS_DIR/test_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase with successful hook - should succeed
    if ! "$ORCHESTRATOR" phase completion test 2>/dev/null; then
        echo "ERROR: Phase execution should have succeeded with successful hook"
        return 1
    fi

    echo "✓ Successful hook execution worked correctly"
    return 0
}

test_pipeline_aborts_on_critical_failure() {
    echo "Testing full pipeline aborts on critical failure"

    # Override environment variables to use test registry
    export GLOBTIM_DIR="$GLOBTIM_DIR"
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"
    export REGISTRY_FILE="$TEST_HOOKS_DIR/hook_registry.json"

    # Copy test registry to expected location
    cp "$TEST_HOOKS_DIR/test_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute full pipeline - should fail at validation phase due to critical hook
    if "$ORCHESTRATOR" orchestrate test 2>/dev/null; then
        echo "ERROR: Pipeline should have failed at validation phase"
        return 1
    fi

    echo "✓ Pipeline correctly aborted on critical failure"
    return 0
}

test_no_fallback_to_default_phase_behavior() {
    echo "Testing no fallback to default phase behavior when hooks fail"

    # Create registry with no hooks for a phase
    cat > "$TEST_HOOKS_DIR/empty_registry.json" << 'EOF'
{
    "version": "1.0.0",
    "description": "Empty test registry",
    "hooks": {}
}
EOF

    # Override environment variables to use test registry
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"

    # Copy empty registry to expected location
    cp "$TEST_HOOKS_DIR/empty_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase with no hooks - should succeed but not perform default behavior
    if ! "$ORCHESTRATOR" phase validation test 2>/dev/null; then
        echo "ERROR: Phase execution should succeed when no hooks are configured"
        return 1
    fi

    echo "✓ No fallback to default behavior when no hooks configured"
    return 0
}

test_retry_mechanism_respects_retry_count() {
    echo "Testing retry mechanism respects configured retry count"

    # Create registry with hook that has multiple retries
    cat > "$TEST_HOOKS_DIR/retry_registry.json" << 'EOF'
{
    "version": "1.0.0",
    "description": "Retry test registry",
    "hooks": {
        "failing_retry_hook": {
            "path": "tests/hooks/test_hooks/failing_hook.sh",
            "phases": ["validation"],
            "contexts": ["retry_test"],
            "experiment_types": ["test"],
            "priority": 10,
            "timeout": 5,
            "retry_count": 3,
            "critical": true,
            "description": "Hook that fails and should be retried 3 times"
        }
    }
}
EOF

    # Override environment variables to use test registry
    export HOOKS_DIR="$TEST_HOOKS_DIR"
    export STATE_DIR="$TEST_STATE_DIR"
    export LOG_DIR="$TEST_LOG_DIR"

    # Copy retry registry to expected location
    cp "$TEST_HOOKS_DIR/retry_registry.json" "$TEST_HOOKS_DIR/hook_registry.json"

    # Execute phase - should fail after 3 attempts
    local start_time=$(date +%s)
    "$ORCHESTRATOR" phase validation retry_test 2>/dev/null || true
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Should take at least 6 seconds (3 attempts with 2-second backoff between retries)
    if [[ $duration -lt 6 ]]; then
        echo "ERROR: Hook should have been retried multiple times (duration: ${duration}s)"
        return 1
    fi

    echo "✓ Retry mechanism correctly respected retry count"
    return 0
}

# Main test execution
main() {
    echo -e "${BOLD}${BLUE}Issue #38: Hook Orchestrator Fallback Removal Test Suite${NC}"
    echo "=============================================================="

    setup_test_environment

    # Run all tests
    run_test "Critical hook failure aborts phase" test_critical_hook_failure_aborts_phase
    run_test "Nonexistent critical hook fails fast" test_nonexistent_critical_hook_fails_fast
    run_test "Non-critical hook failure fails fast" test_non_critical_hook_failure_fails_fast
    run_test "Successful hook execution" test_successful_hook_execution
    run_test "Pipeline aborts on critical failure" test_pipeline_aborts_on_critical_failure
    run_test "No fallback to default phase behavior" test_no_fallback_to_default_phase_behavior
    run_test "Retry mechanism respects retry count" test_retry_mechanism_respects_retry_count

    cleanup_test_environment

    # Report results
    echo ""
    echo -e "${BOLD}${BLUE}Test Results Summary${NC}"
    echo "===================="
    echo -e "Tests run: ${BOLD}$TESTS_RUN${NC}"
    echo -e "Tests passed: ${BOLD}${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${BOLD}${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}All tests passed! ✓${NC}"
        return 0
    else
        echo -e "${BOLD}${RED}Some tests failed! ✗${NC}"
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi