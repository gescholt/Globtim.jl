#!/bin/bash
# Test Suite for GitLab Security Hook
# Comprehensive testing of all validation scenarios

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/gitlab_hook_tests_$$"
GLOBTIM_PROJECT_DIR="/Users/ghscholt/globtim"
HOOK_SCRIPT="$GLOBTIM_PROJECT_DIR/tools/gitlab/gitlab-security-hook.sh"
ORIGINAL_CONFIG="$GLOBTIM_PROJECT_DIR/.gitlab_config"
BACKUP_CONFIG="$GLOBTIM_PROJECT_DIR/.gitlab_config.test_backup"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Setup and teardown functions
setup_test_env() {
    log_test "Setting up test environment"
    
    # Backup original config if it exists
    if [[ -f "$ORIGINAL_CONFIG" ]]; then
        cp "$ORIGINAL_CONFIG" "$BACKUP_CONFIG"
        log_test "Backed up original .gitlab_config"
    fi
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$GLOBTIM_PROJECT_DIR"
}

cleanup_test_env() {
    log_test "Cleaning up test environment"
    
    # Restore original config
    if [[ -f "$BACKUP_CONFIG" ]]; then
        mv "$BACKUP_CONFIG" "$ORIGINAL_CONFIG"
        log_test "Restored original .gitlab_config"
    fi
    
    # Clean up test files
    rm -rf "$TEST_DIR"
    rm -f "$GLOBTIM_PROJECT_DIR/.gitlab_hook.log"
}

# Helper function to create test config
create_test_config() {
    local config_content="$1"
    echo "$config_content" > "$ORIGINAL_CONFIG"
}

# Helper function to run hook and capture result
run_hook_test() {
    local test_name="$1"
    local expected_exit_code="$2"
    local force_flag="${3:-}"
    
    ((TESTS_RUN++))
    log_test "Running: $test_name"
    
    local actual_exit_code=0
    local output
    
    if [[ -n "$force_flag" ]]; then
        output=$("$HOOK_SCRIPT" --force 2>&1) || actual_exit_code=$?
    else
        # Simulate Claude environment variables
        CLAUDE_TOOL_NAME="Task" CLAUDE_SUBAGENT_TYPE="project-task-updater" \
        output=$("$HOOK_SCRIPT" 2>&1) || actual_exit_code=$?
    fi
    
    if [[ "$actual_exit_code" -eq "$expected_exit_code" ]]; then
        log_success "$test_name (exit code: $actual_exit_code)"
        return 0
    else
        log_failure "$test_name (expected exit code: $expected_exit_code, got: $actual_exit_code)"
        echo "Output: $output"
        return 1
    fi
}

# Test cases
test_missing_config_file() {
    log_test "=== Test: Missing .gitlab_config file ==="
    rm -f "$ORIGINAL_CONFIG"
    run_hook_test "Missing config file should fail" 1 "--force"
}

test_valid_config_file() {
    log_test "=== Test: Valid .gitlab_config file ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Valid config should pass" 0 "--force"
}

test_insecure_permissions() {
    log_test "=== Test: Insecure file permissions (auto-fix) ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 644 "$ORIGINAL_CONFIG"  # Too permissive
    run_hook_test "Insecure permissions should be auto-fixed" 0 "--force"
    
    # Verify permissions were fixed
    local perms=$(stat -f "%A" "$ORIGINAL_CONFIG" 2>/dev/null || stat -c "%a" "$ORIGINAL_CONFIG" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        log_success "Permissions correctly fixed to 600"
    else
        log_failure "Permissions not fixed (still $perms)"
    fi
}

test_missing_required_variables() {
    log_test "=== Test: Missing required variables ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
# GITLAB_TOKEN missing
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Missing required variables should fail" 1 "--force"
}

test_invalid_url_format() {
    log_test "=== Test: Invalid URL format ==="
    create_test_config "GITLAB_URL=not-a-valid-url
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Invalid URL format should fail" 1 "--force"
}

test_short_token() {
    log_test "=== Test: Suspiciously short token ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=short
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Short token should fail" 1 "--force"
}

test_syntax_error_in_config() {
    log_test "=== Test: Syntax error in config file ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim
INVALID_SYNTAX=unclosed quote'"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Syntax error should fail" 1 "--force"
}

test_comments_and_empty_lines() {
    log_test "=== Test: Config with comments and empty lines ==="
    create_test_config "# GitLab Configuration
# This is a comment

GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R

# Another comment
GITLAB_PROJECT_PATH=scholten/globtim

# Final comment"
    chmod 600 "$ORIGINAL_CONFIG"
    run_hook_test "Config with comments should pass" 0 "--force"
}

test_no_trigger_conditions() {
    log_test "=== Test: No trigger conditions (should skip) ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    
    ((TESTS_RUN++))
    log_test "Running: No trigger conditions should skip validation"
    
    local actual_exit_code=0
    local output
    output=$("$HOOK_SCRIPT" 2>&1) || actual_exit_code=$?
    
    if [[ "$actual_exit_code" -eq 0 ]] && [[ "$output" =~ "No trigger conditions" ]]; then
        log_success "No trigger conditions correctly skipped validation"
    else
        log_failure "Should have skipped validation (exit code: $actual_exit_code)"
    fi
}

test_claude_context_trigger() {
    log_test "=== Test: Claude context trigger ==="
    create_test_config "GITLAB_URL=https://git.mpi-cbg.de
GITLAB_TOKEN=yjKZNqzG2TkLzXyU8Q9R
GITLAB_PROJECT_PATH=scholten/globtim"
    chmod 600 "$ORIGINAL_CONFIG"
    
    ((TESTS_RUN++))
    log_test "Running: Claude GitLab context should trigger validation"
    
    local actual_exit_code=0
    local output
    CLAUDE_CONTEXT="Let's update the GitLab issue" \
    output=$("$HOOK_SCRIPT" 2>&1) || actual_exit_code=$?
    
    if [[ "$actual_exit_code" -eq 0 ]] && [[ "$output" =~ "security validation passed" ]]; then
        log_success "Claude context correctly triggered validation"
    else
        log_failure "Claude context should have triggered validation (exit code: $actual_exit_code)"
    fi
}

# Main test execution
run_all_tests() {
    echo "🧪 GitLab Security Hook Test Suite"
    echo "================================="
    
    setup_test_env
    
    # Run all test cases
    test_missing_config_file
    test_valid_config_file
    test_insecure_permissions
    test_missing_required_variables
    test_invalid_url_format
    test_short_token
    test_syntax_error_in_config
    test_comments_and_empty_lines
    test_no_trigger_conditions
    test_claude_context_trigger
    
    cleanup_test_env
    
    # Summary
    echo ""
    echo "🏁 Test Results Summary"
    echo "======================"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Run tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi