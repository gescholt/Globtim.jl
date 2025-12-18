#!/bin/bash
# Test Framework for Robust Job Management System - Issue #84
# Test-First Implementation: Automated Job Lifecycle Management
# Tests: submit → monitor → collect pipeline with defensive error handling

set -e

# Test configuration
TEST_NAME="job_lifecycle_automation"
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
TEST_STATE_DIR="$TEMP_DIR/test_state"
TEST_RESULTS_DIR="$TEMP_DIR/test_results"
TEST_LOGS_DIR="$TEMP_DIR/test_logs"

mkdir -p "$TEST_STATE_DIR" "$TEST_RESULTS_DIR" "$TEST_LOGS_DIR"

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
    echo -e "${BOLD}${GREEN}[TEST-INFO]${NC} $*"
}

test_warning() {
    test_log "WARN" "$@"
    echo -e "${BOLD}${YELLOW}[TEST-WARNING]${NC} $*"
}

test_error() {
    test_log "ERROR" "$@"
    echo -e "${BOLD}${RED}[TEST-ERROR]${NC} $*"
}

test_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        test_log "DEBUG" "$@"
        echo -e "${BOLD}${BLUE}[TEST-DEBUG]${NC} $*"
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

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"

    if eval "$command" >/dev/null 2>&1; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        return 1
    fi
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
        test_error "  Text: '$text'"
        test_error "  Pattern: '$pattern'"
        return 1
    fi
}

# Mock job management system for testing
create_mock_job_manager() {
    local mock_script="$TEMP_DIR/mock_robust_job_manager.sh"

    cat > "$mock_script" << 'EOF'
#!/bin/bash
# Mock Robust Job Manager for Testing
set -e

OPERATION="${1:-help}"
JOB_ID="${2:-}"
CONTEXT="${3:-}"

STATE_DIR="${TEST_STATE_DIR:-/tmp/test_state}"
RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/test_results}"

mkdir -p "$STATE_DIR" "$RESULTS_DIR"

case "$OPERATION" in
    submit)
        if [[ -z "$JOB_ID" || -z "$CONTEXT" ]]; then
            echo "ERROR: Job ID and context required for submit operation"
            exit 1
        fi

        # Create job state file
        cat > "$STATE_DIR/${JOB_ID}.state" << EOL
{
    "job_id": "$JOB_ID",
    "context": "$CONTEXT",
    "status": "submitted",
    "phase": "execution",
    "submitted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOL
        echo "Job $JOB_ID submitted successfully"
        ;;

    monitor)
        if [[ -z "$JOB_ID" ]]; then
            echo "ERROR: Job ID required for monitor operation"
            exit 1
        fi

        local state_file="$STATE_DIR/${JOB_ID}.state"
        if [[ ! -f "$state_file" ]]; then
            echo "ERROR: Job $JOB_ID not found"
            exit 1
        fi

        # Simulate job progress
        local current_status=$(grep '"status"' "$state_file" | cut -d'"' -f4)
        case "$current_status" in
            "submitted")
                # Update to running
                sed -i.bak 's/"status": "submitted"/"status": "running"/' "$state_file"
                sed -i.bak 's/"phase": "execution"/"phase": "monitoring"/' "$state_file"
                echo "Job $JOB_ID is now running"
                ;;
            "running")
                # Update to completed
                sed -i.bak 's/"status": "running"/"status": "completed"/' "$state_file"
                sed -i.bak 's/"phase": "monitoring"/"phase": "completion"/' "$state_file"

                # Create mock results
                mkdir -p "$RESULTS_DIR/$JOB_ID"
                echo "degree,critical_points,l2_norm" > "$RESULTS_DIR/$JOB_ID/critical_points_deg_6.csv"
                echo "6,42,0.001234" >> "$RESULTS_DIR/$JOB_ID/critical_points_deg_6.csv"

                echo "Job $JOB_ID completed successfully"
                ;;
            "completed")
                echo "Job $JOB_ID already completed"
                ;;
            "failed")
                echo "Job $JOB_ID failed"
                exit 1
                ;;
        esac
        ;;

    collect)
        if [[ -z "$JOB_ID" ]]; then
            echo "ERROR: Job ID required for collect operation"
            exit 1
        fi

        local state_file="$STATE_DIR/${JOB_ID}.state"
        if [[ ! -f "$state_file" ]]; then
            echo "ERROR: Job $JOB_ID not found"
            exit 1
        fi

        local current_status=$(grep '"status"' "$state_file" | cut -d'"' -f4)
        if [[ "$current_status" != "completed" ]]; then
            echo "ERROR: Job $JOB_ID not completed (status: $current_status)"
            exit 1
        fi

        # Validate results exist
        local results_dir="$RESULTS_DIR/$JOB_ID"
        if [[ ! -d "$results_dir" ]]; then
            echo "ERROR: Results directory not found for job $JOB_ID"
            exit 1
        fi

        # Perform defensive CSV validation
        local csv_file="$results_dir/critical_points_deg_6.csv"
        if [[ ! -f "$csv_file" ]]; then
            echo "ERROR: Expected CSV file not found: $csv_file"
            exit 1
        fi

        # Validate CSV structure
        local header=$(head -n1 "$csv_file")
        if [[ "$header" != "degree,critical_points,l2_norm" ]]; then
            echo "ERROR: Invalid CSV header in $csv_file"
            echo "Expected: degree,critical_points,l2_norm"
            echo "Found: $header"
            exit 1
        fi

        # Validate data row
        local data_row=$(tail -n1 "$csv_file")
        if [[ -z "$data_row" ]]; then
            echo "ERROR: No data rows found in $csv_file"
            exit 1
        fi

        echo "Job $JOB_ID results collected and validated successfully"
        echo "Results location: $results_dir"
        ;;

    status)
        if [[ -z "$JOB_ID" ]]; then
            # List all jobs
            echo "Active jobs:"
            for state_file in "$STATE_DIR"/*.state; do
                if [[ -f "$state_file" ]]; then
                    local job_id=$(basename "$state_file" .state)
                    local status=$(grep '"status"' "$state_file" | cut -d'"' -f4)
                    local phase=$(grep '"phase"' "$state_file" | cut -d'"' -f4)
                    echo "  $job_id: $status ($phase)"
                fi
            done
        else
            # Show specific job status
            local state_file="$STATE_DIR/${JOB_ID}.state"
            if [[ -f "$state_file" ]]; then
                cat "$state_file"
            else
                echo "ERROR: Job $JOB_ID not found"
                exit 1
            fi
        fi
        ;;

    help|*)
        echo "Mock Robust Job Manager"
        echo "Usage: $0 <operation> [job_id] [context]"
        echo ""
        echo "Operations:"
        echo "  submit <job_id> <context>  - Submit new job"
        echo "  monitor <job_id>           - Monitor job progress"
        echo "  collect <job_id>           - Collect and validate results"
        echo "  status [job_id]            - Show job status"
        ;;
esac
EOF

    chmod +x "$mock_script"
    echo "$mock_script"
}

# Test cases for automated job lifecycle

test_job_submission() {
    test_info "🧪 Testing job submission functionality"

    local mock_manager=$(create_mock_job_manager)
    local job_id="test_job_$(date +%Y%m%d_%H%M%S)"
    local context="4d_lotka_volterra_test"

    # Test successful job submission
    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    local output
    output=$("$mock_manager" submit "$job_id" "$context" 2>&1)

    assert_contains "$output" "submitted successfully" "Job submission should succeed"
    assert_file_exists "$TEST_STATE_DIR/${job_id}.state" "Job state file should be created"

    # Validate job state content
    local state_content=$(cat "$TEST_STATE_DIR/${job_id}.state")
    assert_contains "$state_content" '"status": "submitted"' "Job should have submitted status"
    assert_contains "$state_content" '"job_id": "'$job_id'"' "Job state should contain correct job ID"
    assert_contains "$state_content" '"context": "'$context'"' "Job state should contain correct context"

    test_info "✅ Job submission test passed"
}

test_job_monitoring() {
    test_info "🧪 Testing job monitoring functionality"

    local mock_manager=$(create_mock_job_manager)
    local job_id="test_monitor_job_$(date +%Y%m%d_%H%M%S)"
    local context="4d_monitoring_test"

    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    # Submit job first
    "$mock_manager" submit "$job_id" "$context" >/dev/null

    # Test first monitoring call (submitted → running)
    local output
    output=$("$mock_manager" monitor "$job_id" 2>&1)
    assert_contains "$output" "is now running" "Job should transition to running state"

    local state_content=$(cat "$TEST_STATE_DIR/${job_id}.state")
    assert_contains "$state_content" '"status": "running"' "Job should have running status"
    assert_contains "$state_content" '"phase": "monitoring"' "Job should be in monitoring phase"

    # Test second monitoring call (running → completed)
    output=$("$mock_manager" monitor "$job_id" 2>&1)
    assert_contains "$output" "completed successfully" "Job should transition to completed state"

    state_content=$(cat "$TEST_STATE_DIR/${job_id}.state")
    assert_contains "$state_content" '"status": "completed"' "Job should have completed status"
    assert_contains "$state_content" '"phase": "completion"' "Job should be in completion phase"

    # Verify results were created
    assert_file_exists "$TEST_RESULTS_DIR/$job_id/critical_points_deg_6.csv" "Results file should be created"

    test_info "✅ Job monitoring test passed"
}

test_result_collection_and_validation() {
    test_info "🧪 Testing result collection and defensive validation"

    local mock_manager=$(create_mock_job_manager)
    local job_id="test_collect_job_$(date +%Y%m%d_%H%M%S)"
    local context="4d_collection_test"

    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    # Submit and complete job
    "$mock_manager" submit "$job_id" "$context" >/dev/null
    "$mock_manager" monitor "$job_id" >/dev/null  # submitted → running
    "$mock_manager" monitor "$job_id" >/dev/null  # running → completed

    # Test result collection
    local output
    output=$("mock_manager" collect "$job_id" 2>&1)
    assert_contains "$output" "collected and validated successfully" "Results should be collected successfully"
    assert_contains "$output" "Results location:" "Collection should report results location"

    # Test defensive CSV validation
    local csv_file="$TEST_RESULTS_DIR/$job_id/critical_points_deg_6.csv"
    local header=$(head -n1 "$csv_file")
    assert_equals "degree,critical_points,l2_norm" "$header" "CSV should have correct header"

    local data_row=$(tail -n1 "$csv_file")
    assert_contains "$data_row" "6,42,0.001234" "CSV should contain expected data"

    # Test collection of non-existent job (should fail)
    local fake_job_id="nonexistent_job"
    if "$mock_manager" collect "$fake_job_id" 2>&1 | grep -q "Job $fake_job_id not found"; then
        test_info "✅ Collection correctly fails for non-existent job"
    else
        test_error "❌ Collection should fail for non-existent job"
        return 1
    fi

    test_info "✅ Result collection and validation test passed"
}

test_error_detection_and_recovery() {
    test_info "🧪 Testing error detection and recovery mechanisms"

    local mock_manager=$(create_mock_job_manager)

    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    # Test collection without completion (should fail)
    local incomplete_job="incomplete_job_$(date +%Y%m%d_%H%M%S)"
    "$mock_manager" submit "$incomplete_job" "test_context" >/dev/null

    local output
    if output=$("$mock_manager" collect "$incomplete_job" 2>&1); then
        test_error "❌ Collection should fail for incomplete job"
        return 1
    else
        assert_contains "$output" "not completed" "Collection should fail with appropriate error message"
        test_info "✅ Error detection works for incomplete jobs"
    fi

    # Test CSV validation with corrupted file
    local corrupt_job="corrupt_job_$(date +%Y%m%d_%H%M%S)"
    "$mock_manager" submit "$corrupt_job" "test_context" >/dev/null
    "$mock_manager" monitor "$corrupt_job" >/dev/null
    "$mock_manager" monitor "$corrupt_job" >/dev/null

    # Corrupt the CSV file
    local corrupt_csv="$TEST_RESULTS_DIR/$corrupt_job/critical_points_deg_6.csv"
    echo "invalid,header,format" > "$corrupt_csv"
    echo "bad,data,row" >> "$corrupt_csv"

    if output=$("$mock_manager" collect "$corrupt_job" 2>&1); then
        test_error "❌ Collection should fail for corrupted CSV"
        return 1
    else
        assert_contains "$output" "Invalid CSV header" "Collection should detect CSV corruption"
        test_info "✅ Error detection works for corrupted CSV files"
    fi

    test_info "✅ Error detection and recovery test passed"
}

test_job_status_reporting() {
    test_info "🧪 Testing job status reporting functionality"

    local mock_manager=$(create_mock_job_manager)

    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    # Create multiple jobs in different states
    local job1="status_test_job1_$(date +%Y%m%d_%H%M%S)"
    local job2="status_test_job2_$(date +%Y%m%d_%H%M%S)"

    "$mock_manager" submit "$job1" "test_context1" >/dev/null
    "$mock_manager" submit "$job2" "test_context2" >/dev/null
    "$mock_manager" monitor "$job2" >/dev/null  # job2 → running

    # Test listing all jobs
    local output
    output=$("$mock_manager" status 2>&1)
    assert_contains "$output" "Active jobs:" "Status should list active jobs"
    assert_contains "$output" "$job1: submitted" "Should show job1 as submitted"
    assert_contains "$output" "$job2: running" "Should show job2 as running"

    # Test specific job status
    output=$("$mock_manager" status "$job1" 2>&1)
    assert_contains "$output" '"job_id": "'$job1'"' "Should show specific job details"
    assert_contains "$output" '"status": "submitted"' "Should show correct job status"

    test_info "✅ Job status reporting test passed"
}

test_full_lifecycle_integration() {
    test_info "🧪 Testing complete job lifecycle integration"

    local mock_manager=$(create_mock_job_manager)
    local job_id="integration_test_$(date +%Y%m%d_%H%M%S)"
    local context="4d_lotka_volterra_full_test"

    export TEST_STATE_DIR="$TEST_STATE_DIR"
    export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"

    # Full lifecycle: submit → monitor → collect
    test_info "  Phase 1: Job Submission"
    "$mock_manager" submit "$job_id" "$context" >/dev/null
    assert_file_exists "$TEST_STATE_DIR/${job_id}.state" "Job state should be created"

    test_info "  Phase 2: Job Monitoring (submitted → running)"
    "$mock_manager" monitor "$job_id" >/dev/null
    local state_content=$(cat "$TEST_STATE_DIR/${job_id}.state")
    assert_contains "$state_content" '"status": "running"' "Job should be running"

    test_info "  Phase 3: Job Completion (running → completed)"
    "$mock_manager" monitor "$job_id" >/dev/null
    state_content=$(cat "$TEST_STATE_DIR/${job_id}.state")
    assert_contains "$state_content" '"status": "completed"' "Job should be completed"

    test_info "  Phase 4: Result Collection and Validation"
    local output
    output=$("$mock_manager" collect "$job_id" 2>&1)
    assert_contains "$output" "collected and validated successfully" "Results should be collected"

    # Verify complete pipeline
    assert_file_exists "$TEST_RESULTS_DIR/$job_id/critical_points_deg_6.csv" "Results file should exist"
    local csv_content=$(cat "$TEST_RESULTS_DIR/$job_id/critical_points_deg_6.csv")
    assert_contains "$csv_content" "degree,critical_points,l2_norm" "CSV should have correct format"

    test_info "✅ Full lifecycle integration test passed"
}

# Main test runner
run_all_tests() {
    test_info "🚀 Starting Robust Job Management System Tests"
    test_info "Test Version: $TEST_VERSION"
    test_info "Temporary Directory: $TEMP_DIR"
    test_info "====================================================="

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # List of test functions
    local tests=(
        "test_job_submission"
        "test_job_monitoring"
        "test_result_collection_and_validation"
        "test_error_detection_and_recovery"
        "test_job_status_reporting"
        "test_full_lifecycle_integration"
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
    test_info "🏁 Test Results Summary"
    test_info "====================================================="
    test_info "Total Tests: $total_tests"
    test_info "Passed: $passed_tests"
    test_info "Failed: $failed_tests"

    if [[ $failed_tests -eq 0 ]]; then
        test_info "🎉 ALL TESTS PASSED! 🎉"
        test_info "Ready for implementation of robust job management system."
        return 0
    else
        test_error "💥 $failed_tests TESTS FAILED"
        test_error "Please fix test failures before implementing system."
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi