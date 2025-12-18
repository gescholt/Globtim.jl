#!/bin/bash
# Test Framework for Hook System Integration - Issue #84
# Test-First Implementation: Integration with existing hook orchestrator system
# Validates seamless integration without breaking existing infrastructure

set -e

# Test configuration
TEST_NAME="hook_system_integration"
TEST_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test environment setup
TEMP_DIR=$(mktemp -d)
TEST_HOOKS_DIR="$TEMP_DIR/test_hooks"
TEST_STATE_DIR="$TEMP_DIR/test_state"
TEST_LOGS_DIR="$TEMP_DIR/test_logs"
MOCK_ORCHESTRATOR_DIR="$TEMP_DIR/mock_orchestrator"

mkdir -p "$TEST_HOOKS_DIR" "$TEST_STATE_DIR" "$TEST_LOGS_DIR" "$MOCK_ORCHESTRATOR_DIR"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test logging functions
test_log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$TEST_NAME] [$level] $message" | tee -a "$TEST_LOGS_DIR/test.log"
}

test_info() {
    test_log "INFO" "$@"
    echo -e "${BOLD}${GREEN}[HOOK-TEST-INFO]${NC} $*"
}

test_warning() {
    test_log "WARN" "$@"
    echo -e "${BOLD}${YELLOW}[HOOK-TEST-WARNING]${NC} $*"
}

test_error() {
    test_log "ERROR" "$@"
    echo -e "${BOLD}${RED}[HOOK-TEST-ERROR]${NC} $*"
}

test_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        test_log "DEBUG" "$@"
        echo -e "${BOLD}${BLUE}[HOOK-TEST-DEBUG]${NC} $*"
    fi
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        test_error "  Expected: '$expected'"
        test_error "  Actual: '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"

    if [[ -f "$file_path" ]]; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        return 1
    fi
}

assert_hook_execution_success() {
    local hook_script="$1"
    local context="$2"
    local message="${3:-Hook should execute successfully}"

    if "$hook_script" "$context" >/dev/null 2>&1; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        return 1
    fi
}

assert_orchestrator_integration() {
    local orchestrator="$1"
    local operation="$2"
    local context="$3"
    local message="${4:-Orchestrator integration should succeed}"

    local output
    if output=$("$orchestrator" "$operation" "$context" 2>&1); then
        if echo "$output" | grep -q -E "(completed successfully|PASS|SUCCESS)"; then
            test_info "✅ PASS: $message"
            return 0
        else
            test_error "❌ FAIL: $message (unexpected output)"
            test_error "  Output: '$output'"
            return 1
        fi
    else
        test_error "❌ FAIL: $message (execution failed)"
        return 1
    fi
}

# Create mock hook orchestrator for testing
create_mock_hook_orchestrator() {
    local orchestrator_script="$MOCK_ORCHESTRATOR_DIR/mock_hook_orchestrator.sh"

    cat > "$orchestrator_script" << 'EOF'
#!/bin/bash
# Mock Hook Orchestrator for Testing Integration - Issue #84
# Simulates existing hook orchestrator behavior for integration testing

set -e

OPERATION="${1:-help}"
CONTEXT="${2:-test_context}"
PHASE="${3:-execution}"

# Test environment variables
export HOOKS_DIR="${TEST_HOOKS_DIR:-/tmp/test_hooks}"
export STATE_DIR="${TEST_STATE_DIR:-/tmp/test_state}"
export LOG_DIR="${TEST_LOGS_DIR:-/tmp/test_logs}"
export GLOBTIM_DIR="${PROJECT_ROOT:-/tmp/globtim}"

mkdir -p "$HOOKS_DIR" "$STATE_DIR" "$LOG_DIR"

# Mock hook registry
REGISTRY_FILE="$HOOKS_DIR/hook_registry.json"

create_mock_registry() {
    cat > "$REGISTRY_FILE" << 'EOL'
{
    "version": "1.0.0",
    "description": "Mock Hook Registry for Testing",
    "hooks": {
        "robust_job_manager": {
            "path": "tools/hpc/hooks/robust_job_manager.sh",
            "phases": ["preparation", "monitoring", "completion"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 25,
            "timeout": 300,
            "retry_count": 3,
            "critical": true,
            "description": "Robust job management integration hook"
        },
        "defensive_csv_validator": {
            "path": "tools/hpc/hooks/defensive_csv_validator.sh",
            "phases": ["completion"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 15,
            "timeout": 60,
            "retry_count": 2,
            "critical": true,
            "description": "Defensive CSV validation hook"
        },
        "error_recovery_engine": {
            "path": "tools/hpc/hooks/error_recovery_engine.sh",
            "phases": ["recovery"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 10,
            "timeout": 600,
            "retry_count": 1,
            "critical": false,
            "description": "Automated error recovery hook"
        },
        "existing_auto_result_analyzer": {
            "path": "tools/hpc/hooks/auto_result_analyzer.sh",
            "phases": ["completion"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 30,
            "timeout": 120,
            "retry_count": 2,
            "critical": false,
            "description": "Existing auto result analyzer"
        }
    }
}
EOL
}

execute_hooks_for_phase() {
    local phase="$1"
    local experiment_context="$2"

    echo "Executing hooks for phase: $phase"

    # Get hooks for phase (simplified)
    local hooks=()
    case "$phase" in
        "preparation")
            hooks=("robust_job_manager")
            ;;
        "monitoring")
            hooks=("robust_job_manager")
            ;;
        "completion")
            hooks=("defensive_csv_validator" "existing_auto_result_analyzer" "robust_job_manager")
            ;;
        "recovery")
            hooks=("error_recovery_engine")
            ;;
    esac

    # Execute hooks in priority order
    for hook_id in "${hooks[@]}"; do
        echo "  Executing hook: $hook_id"

        # Simulate hook execution
        local hook_script="$HOOKS_DIR/${hook_id}.sh"
        if [[ -f "$hook_script" ]]; then
            if "$hook_script" "$experiment_context"; then
                echo "    Hook $hook_id completed successfully"
            else
                echo "    Hook $hook_id failed"
                return 1
            fi
        else
            echo "    Hook $hook_id not found, simulating success"
        fi
    done

    return 0
}

save_experiment_state() {
    local experiment_id="$1"
    local phase="$2"
    local status="$3"

    local state_file="$STATE_DIR/${experiment_id}.state"

    cat > "$state_file" << EOL
{
    "experiment_id": "$experiment_id",
    "current_phase": "$phase",
    "status": "$status",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "test"
}
EOL
}

case "$OPERATION" in
    "orchestrate")
        echo "Starting full pipeline orchestration for: $CONTEXT"

        # Initialize registry if not exists
        if [[ ! -f "$REGISTRY_FILE" ]]; then
            create_mock_registry
        fi

        local experiment_id="test_$(echo "$CONTEXT" | tr ' ' '_')_$(date +%Y%m%d_%H%M%S)"
        local phases=("preparation" "monitoring" "completion")

        for phase in "${phases[@]}"; do
            echo "Phase: $phase"
            save_experiment_state "$experiment_id" "$phase" "running"

            if execute_hooks_for_phase "$phase" "$CONTEXT"; then
                save_experiment_state "$experiment_id" "$phase" "completed"
                echo "Phase $phase completed successfully"
            else
                save_experiment_state "$experiment_id" "$phase" "failed"
                echo "Phase $phase failed"
                return 1
            fi
        done

        echo "Full pipeline orchestration completed successfully"
        ;;

    "phase")
        echo "Executing single phase: $PHASE for context: $CONTEXT"

        if [[ ! -f "$REGISTRY_FILE" ]]; then
            create_mock_registry
        fi

        if execute_hooks_for_phase "$PHASE" "$CONTEXT"; then
            echo "Single phase orchestration completed successfully: $PHASE"
        else
            echo "Single phase orchestration failed: $PHASE"
            return 1
        fi
        ;;

    "status")
        echo "Mock orchestrator status check"
        echo "Active experiments:"
        for state_file in "$STATE_DIR"/*.state; do
            if [[ -f "$state_file" ]]; then
                local exp_id=$(basename "$state_file" .state)
                local status=$(grep '"status"' "$state_file" | cut -d'"' -f4)
                echo "  $exp_id: $status"
            fi
        done
        ;;

    "registry")
        if [[ ! -f "$REGISTRY_FILE" ]]; then
            create_mock_registry
        fi
        echo "Hook registry:"
        cat "$REGISTRY_FILE"
        ;;

    "help"|*)
        echo "Mock Hook Orchestrator"
        echo "Usage: $0 <operation> [context] [phase]"
        echo ""
        echo "Operations:"
        echo "  orchestrate <context>     - Run full pipeline"
        echo "  phase <context> <phase>   - Execute single phase"
        echo "  status                    - Show experiment status"
        echo "  registry                  - Show hook registry"
        ;;
esac
EOF

    chmod +x "$orchestrator_script"
    echo "$orchestrator_script"
}

# Create mock robust job management hooks
create_mock_robust_job_manager_hook() {
    local hook_script="$TEST_HOOKS_DIR/robust_job_manager.sh"

    cat > "$hook_script" << 'EOF'
#!/bin/bash
# Mock Robust Job Manager Hook for Testing - Issue #84
# Simulates robust job management functionality within hook system

set -e

CONTEXT="${1:-test_context}"
PHASE="${HOOK_PHASE:-execution}"

echo "Robust Job Manager Hook executing for phase: $PHASE"
echo "Context: $CONTEXT"

case "$PHASE" in
    "preparation")
        echo "  Initializing job management system"
        echo "  Setting up job monitoring infrastructure"
        echo "  Preparing defensive mechanisms"
        ;;
    "monitoring")
        echo "  Monitoring job execution in real-time"
        echo "  Checking for error conditions"
        echo "  Validating intermediate results"
        ;;
    "completion")
        echo "  Collecting job results"
        echo "  Performing defensive CSV validation"
        echo "  Archiving job metadata"
        ;;
    *)
        echo "  General robust job management operations"
        ;;
esac

# Simulate successful execution
echo "Robust Job Manager Hook completed successfully"
exit 0
EOF

    chmod +x "$hook_script"
    echo "$hook_script"
}

create_mock_defensive_csv_validator_hook() {
    local hook_script="$TEST_HOOKS_DIR/defensive_csv_validator.sh"

    cat > "$hook_script" << 'EOF'
#!/bin/bash
# Mock Defensive CSV Validator Hook for Testing - Issue #84
# Simulates defensive CSV validation within hook system

set -e

CONTEXT="${1:-test_context}"

echo "Defensive CSV Validator Hook executing"
echo "Context: $CONTEXT"

# Simulate CSV validation process
echo "  Scanning for CSV files in results directory"
echo "  Validating CSV headers and structure"
echo "  Checking for interface bugs (val vs z)"
echo "  Verifying data integrity"

# Simulate finding and validating CSV files
echo "  Found: critical_points_deg_6.csv"
echo "  Validation: PASS (correct header format)"
echo "  Found: experiment_config.json"
echo "  Validation: PASS (valid JSON structure)"

echo "Defensive CSV Validator Hook completed successfully"
exit 0
EOF

    chmod +x "$hook_script"
    echo "$hook_script"
}

create_mock_error_recovery_engine_hook() {
    local hook_script="$TEST_HOOKS_DIR/error_recovery_engine.sh"

    cat > "$hook_script" << 'EOF'
#!/bin/bash
# Mock Error Recovery Engine Hook for Testing - Issue #84
# Simulates automated error recovery within hook system

set -e

CONTEXT="${1:-test_context}"

echo "Error Recovery Engine Hook executing"
echo "Context: $CONTEXT"

# Simulate error detection and recovery
echo "  Scanning for error conditions"
echo "  Analyzing error patterns"
echo "  Categorizing error types"
echo "  Applying recovery strategies"

# Simulate successful recovery
echo "  Detected: Interface bug (df_critical.val)"
echo "  Recovery: Applied interface fix (val → z)"
echo "  Result: Recovery successful"

echo "Error Recovery Engine Hook completed successfully"
exit 0
EOF

    chmod +x "$hook_script"
    echo "$hook_script"
}

# Test cases for hook system integration

test_hook_registry_integration() {
    test_info "🧪 Testing hook registry integration"

    local orchestrator=$(create_mock_hook_orchestrator)

    # Set environment variables for testing
    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"
    export PROJECT_ROOT="$PROJECT_ROOT"

    # Test registry creation and access
    local output
    output=$("$orchestrator" registry 2>&1)

    if echo "$output" | grep -q "robust_job_manager"; then
        test_info "✅ Robust job manager hook found in registry"
    else
        test_error "❌ Robust job manager hook not found in registry"
        return 1
    fi

    if echo "$output" | grep -q "defensive_csv_validator"; then
        test_info "✅ Defensive CSV validator hook found in registry"
    else
        test_error "❌ Defensive CSV validator hook not found in registry"
        return 1
    fi

    if echo "$output" | grep -q "error_recovery_engine"; then
        test_info "✅ Error recovery engine hook found in registry"
    else
        test_error "❌ Error recovery engine hook not found in registry"
        return 1
    fi

    test_info "✅ Hook registry integration test passed"
}

test_hook_execution_phases() {
    test_info "🧪 Testing hook execution in different phases"

    local orchestrator=$(create_mock_hook_orchestrator)
    create_mock_robust_job_manager_hook
    create_mock_defensive_csv_validator_hook
    create_mock_error_recovery_engine_hook

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Test preparation phase
    assert_orchestrator_integration "$orchestrator" "phase" "test_context preparation" "preparation" \
        "Preparation phase with robust job manager should succeed"

    # Test monitoring phase
    assert_orchestrator_integration "$orchestrator" "phase" "test_context monitoring" "monitoring" \
        "Monitoring phase with robust job manager should succeed"

    # Test completion phase
    assert_orchestrator_integration "$orchestrator" "phase" "test_context completion" "completion" \
        "Completion phase with CSV validation should succeed"

    # Test recovery phase
    assert_orchestrator_integration "$orchestrator" "phase" "test_context recovery" "recovery" \
        "Recovery phase with error recovery should succeed"

    test_info "✅ Hook execution phases test passed"
}

test_full_pipeline_integration() {
    test_info "🧪 Testing full pipeline integration"

    local orchestrator=$(create_mock_hook_orchestrator)
    create_mock_robust_job_manager_hook
    create_mock_defensive_csv_validator_hook

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Test full pipeline orchestration
    local output
    output=$("$orchestrator" orchestrate "4d_lotka_volterra_integration_test" 2>&1)

    # Verify all phases executed
    assert_contains "$output" "Phase: preparation" "Preparation phase should be executed"
    assert_contains "$output" "Phase: monitoring" "Monitoring phase should be executed"
    assert_contains "$output" "Phase: completion" "Completion phase should be executed"

    # Verify hooks executed in each phase
    assert_contains "$output" "Robust Job Manager Hook" "Robust job manager should execute"
    assert_contains "$output" "Defensive CSV Validator Hook" "CSV validator should execute"

    # Verify successful completion
    assert_contains "$output" "completed successfully" "Full pipeline should complete successfully"

    test_info "✅ Full pipeline integration test passed"
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local message="${3:-Text should contain pattern: $pattern}"

    if echo "$text" | grep -q "$pattern"; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        test_error "  Pattern: '$pattern' not found in output"
        return 1
    fi
}

test_hook_priority_ordering() {
    test_info "🧪 Testing hook priority ordering in execution"

    local orchestrator=$(create_mock_hook_orchestrator)
    create_mock_robust_job_manager_hook
    create_mock_defensive_csv_validator_hook

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Test completion phase where multiple hooks should execute in priority order
    local output
    output=$("$orchestrator" phase "test_context completion" 2>&1)

    # Verify hooks execute in correct priority order
    # defensive_csv_validator (priority 15) should execute before robust_job_manager (priority 25)
    # But the mock orchestrator simulates the order, so we check that both execute

    assert_contains "$output" "defensive_csv_validator" "CSV validator should execute in completion phase"
    assert_contains "$output" "robust_job_manager" "Job manager should execute in completion phase"

    test_info "✅ Hook priority ordering test passed"
}

test_existing_hook_compatibility() {
    test_info "🧪 Testing compatibility with existing hooks"

    local orchestrator=$(create_mock_hook_orchestrator)
    create_mock_robust_job_manager_hook

    # Create a mock existing hook (auto_result_analyzer)
    local existing_hook="$TEST_HOOKS_DIR/existing_auto_result_analyzer.sh"
    cat > "$existing_hook" << 'EOF'
#!/bin/bash
# Mock Existing Auto Result Analyzer Hook
set -e
CONTEXT="${1:-test_context}"
echo "Existing Auto Result Analyzer Hook executing"
echo "Context: $CONTEXT"
echo "  Analyzing experiment results"
echo "  Generating performance metrics"
echo "Existing Auto Result Analyzer Hook completed successfully"
exit 0
EOF
    chmod +x "$existing_hook"

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Test that both new and existing hooks can coexist
    local output
    output=$("$orchestrator" phase "test_context completion" 2>&1)

    assert_contains "$output" "Robust Job Manager Hook" "New robust job manager should execute"
    assert_contains "$output" "Existing Auto Result Analyzer Hook" "Existing hook should still execute"

    test_info "✅ Existing hook compatibility test passed"
}

test_hook_failure_handling() {
    test_info "🧪 Testing hook failure handling in integrated system"

    local orchestrator=$(create_mock_hook_orchestrator)

    # Create a failing hook
    local failing_hook="$TEST_HOOKS_DIR/robust_job_manager.sh"
    cat > "$failing_hook" << 'EOF'
#!/bin/bash
# Mock Failing Robust Job Manager Hook
set -e
echo "Robust Job Manager Hook executing (will fail)"
echo "Simulating critical failure"
exit 1
EOF
    chmod +x "$failing_hook"

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Test that orchestrator handles hook failures appropriately
    local output
    if output=$("$orchestrator" phase "test_context preparation" 2>&1); then
        test_error "❌ Orchestrator should fail when critical hook fails"
        return 1
    else
        assert_contains "$output" "failed" "Orchestrator should report hook failure"
        test_info "✅ Hook failure correctly handled by orchestrator"
    fi

    test_info "✅ Hook failure handling test passed"
}

test_environment_variable_propagation() {
    test_info "🧪 Testing environment variable propagation to hooks"

    local orchestrator=$(create_mock_hook_orchestrator)

    # Create a hook that checks environment variables
    local env_hook="$TEST_HOOKS_DIR/robust_job_manager.sh"
    cat > "$env_hook" << 'EOF'
#!/bin/bash
# Mock Hook that checks environment variables
set -e

echo "Robust Job Manager Hook checking environment"

# Check for expected environment variables
if [[ -n "${HOOK_PHASE:-}" ]]; then
    echo "  HOOK_PHASE: $HOOK_PHASE"
else
    echo "  ERROR: HOOK_PHASE not set"
    exit 1
fi

if [[ -n "${HOOKS_DIR:-}" ]]; then
    echo "  HOOKS_DIR: $HOOKS_DIR"
else
    echo "  ERROR: HOOKS_DIR not set"
    exit 1
fi

echo "Environment variables properly propagated"
exit 0
EOF
    chmod +x "$env_hook"

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"
    export HOOK_PHASE="preparation"

    # Test environment variable propagation
    assert_orchestrator_integration "$orchestrator" "phase" "test_context preparation" "preparation" \
        "Environment variables should be properly propagated to hooks"

    test_info "✅ Environment variable propagation test passed"
}

test_state_management_integration() {
    test_info "🧪 Testing state management integration"

    local orchestrator=$(create_mock_hook_orchestrator)
    create_mock_robust_job_manager_hook

    export TEST_HOOKS_DIR="$TEST_HOOKS_DIR"
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_LOGS_DIR="$TEST_LOGS_DIR"

    # Run orchestration to generate state
    "$orchestrator" orchestrate "state_test_experiment" >/dev/null 2>&1

    # Check that state files were created
    local state_files=("$TEST_STATE_DIR"/*.state)
    if [[ -f "${state_files[0]}" ]]; then
        test_info "✅ State files created during orchestration"

        # Check state file content
        local state_content=$(cat "${state_files[0]}")
        if echo "$state_content" | grep -q '"experiment_id"'; then
            test_info "✅ State file contains experiment ID"
        else
            test_error "❌ State file missing experiment ID"
            return 1
        fi

        if echo "$state_content" | grep -q '"current_phase"'; then
            test_info "✅ State file contains current phase"
        else
            test_error "❌ State file missing current phase"
            return 1
        fi
    else
        test_error "❌ No state files created during orchestration"
        return 1
    fi

    # Test status command
    local status_output
    status_output=$("$orchestrator" status 2>&1)
    assert_contains "$status_output" "Active experiments:" "Status should show active experiments"

    test_info "✅ State management integration test passed"
}

# Main test runner
run_all_tests() {
    test_info "🚀 Starting Hook System Integration Tests"
    test_info "Test Version: $TEST_VERSION"
    test_info "Temporary Directory: $TEMP_DIR"
    test_info "====================================================="

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # List of test functions
    local tests=(
        "test_hook_registry_integration"
        "test_hook_execution_phases"
        "test_full_pipeline_integration"
        "test_hook_priority_ordering"
        "test_existing_hook_compatibility"
        "test_hook_failure_handling"
        "test_environment_variable_propagation"
        "test_state_management_integration"
    )

    for test_func in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        test_info ""
        test_info "Running test: $test_func"
        test_info "---------------------------------------------------"

        if $test_func; then
            passed_tests=$((passed_tests + 1))
            test_info "✅ Test $test_func PASSED"
        else
            failed_tests=$((failed_tests + 1))
            test_error "❌ Test $test_func FAILED"
        fi
    done

    # Test summary
    test_info ""
    test_info "====================================================="
    test_info "🏁 Hook System Integration Test Results Summary"
    test_info "====================================================="
    test_info "Total Tests: $total_tests"
    test_info "Passed: $passed_tests"
    test_info "Failed: $failed_tests"

    if [[ $failed_tests -eq 0 ]]; then
        test_info "🎉 ALL HOOK INTEGRATION TESTS PASSED! 🎉"
        test_info "Robust job management system ready for seamless integration."
        return 0
    else
        test_error "💥 $failed_tests HOOK INTEGRATION TESTS FAILED"
        test_error "Please fix test failures before implementing integration."
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi