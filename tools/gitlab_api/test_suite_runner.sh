#!/bin/bash
# GitLab API Test Suite Runner
# Comprehensive test suite to identify project-task-updater agent communication failures

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"

# Logging functions
log() {
    echo -e "${BLUE}[TEST-RUNNER]${NC} $1" | tee -a "$TEST_RESULTS_DIR/test_run_$TIMESTAMP.log"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_RESULTS_DIR/test_run_$TIMESTAMP.log"
    ((PASSED_TESTS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_RESULTS_DIR/test_run_$TIMESTAMP.log"
    ((FAILED_TESTS++))
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_RESULTS_DIR/test_run_$TIMESTAMP.log"
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    ((TOTAL_TESTS++))
    log "Running test: $test_name"
    
    if bash "$SCRIPT_DIR/$test_script" > "$TEST_RESULTS_DIR/${test_name}_$TIMESTAMP.log" 2>&1; then
        success "$test_name"
        return 0
    else
        fail "$test_name"
        return 1
    fi
}

# Pre-flight checks
preflight_checks() {
    log "=== Pre-flight Checks ==="
    
    # Check if we're in the correct directory
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        fail "Not in git repository root"
        exit 1
    fi
    success "Git repository detected"
    
    # Check if GitLab tools exist
    if [[ ! -f "$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh" ]]; then
        fail "claude-agent-gitlab.sh not found"
        exit 1
    fi
    success "GitLab tools detected"
    
    # Check if token retrieval script exists
    if [[ ! -f "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" ]]; then
        fail "get-token-noninteractive.sh not found"
        exit 1
    fi
    success "Token retrieval script detected"
    
    log "Pre-flight checks complete"
    echo ""
}

# Main test execution
main() {
    log "=== GitLab API Test Suite ==="
    log "Timestamp: $TIMESTAMP"
    log "Project Root: $PROJECT_ROOT"
    log "Results Directory: $TEST_RESULTS_DIR"
    echo ""
    
    preflight_checks
    
    # Run test categories
    log "=== Authentication Tests ==="
    run_test "token_validation" "test_authentication.sh"
    run_test "token_edge_cases" "test_auth_edge_cases.sh"
    echo ""
    
    log "=== Wrapper Script Tests ==="
    run_test "claude_wrapper_basic" "test_claude_wrapper.sh"
    run_test "claude_wrapper_edge_cases" "test_wrapper_edge_cases.sh"
    echo ""
    
    log "=== API Operation Tests ==="
    run_test "api_connectivity" "test_api_connectivity.sh"
    run_test "issue_crud_operations" "test_issue_operations.sh"
    run_test "label_operations" "test_label_operations.sh"
    run_test "milestone_operations" "test_milestone_operations.sh"
    echo ""
    
    log "=== Error Handling Tests ==="
    run_test "network_failures" "test_network_failures.sh"
    run_test "malformed_requests" "test_malformed_requests.sh"
    run_test "permission_errors" "test_permission_errors.sh"
    echo ""
    
    log "=== Performance Tests ==="
    run_test "timeout_handling" "test_timeout_handling.sh"
    run_test "rate_limiting" "test_rate_limiting.sh"
    echo ""
    
    log "=== Integration Tests ==="
    run_test "project_task_updater_simulation" "test_integration.sh"
    echo ""
    
    # Generate summary report
    generate_summary_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Generate comprehensive summary report
generate_summary_report() {
    local summary_file="$TEST_RESULTS_DIR/test_summary_$TIMESTAMP.md"
    
    log "=== Test Results Summary ==="
    log "Total Tests: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"
    log "Success Rate: $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%"
    
    # Create markdown summary
    cat > "$summary_file" << EOF
# GitLab API Test Suite Results

**Test Run**: $TIMESTAMP  
**Project**: GlobTim GitLab API Communication  
**Purpose**: Identify project-task-updater agent failures (Issue #63)

## Summary Statistics

- **Total Tests**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS  
- **Failed**: $FAILED_TESTS
- **Success Rate**: $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%

## Test Categories

### Authentication Tests
- Token validation and retrieval
- Edge cases with missing/invalid tokens
- Environment variable fallbacks

### Wrapper Script Tests  
- claude-agent-gitlab.sh functionality
- Command-line parameter handling
- Error response processing

### API Operation Tests
- Issue CRUD operations
- Label management
- Milestone operations
- Project metadata access

### Error Handling Tests
- Network failure scenarios
- Malformed request handling
- Permission and authorization errors

### Performance Tests
- Timeout handling
- Rate limiting behavior
- Response time validation

### Integration Tests
- project-task-updater agent simulation
- End-to-end workflow testing

## Detailed Results

EOF

    # Add individual test results
    for log_file in "$TEST_RESULTS_DIR"/*_$TIMESTAMP.log; do
        if [[ -f "$log_file" && "$log_file" != *"test_run_$TIMESTAMP.log" ]]; then
            test_name=$(basename "$log_file" "_$TIMESTAMP.log")
            echo "### $test_name" >> "$summary_file"
            echo '```' >> "$summary_file"
            head -20 "$log_file" >> "$summary_file"
            echo '```' >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done
    
    log "Summary report generated: $summary_file"
}

# Execute main function
main "$@"