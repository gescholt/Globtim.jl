#!/bin/bash
# Claude Wrapper Script Tests
# Tests the claude-agent-gitlab.sh wrapper functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER_SCRIPT="$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh"

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    if [[ $1 -eq 0 ]]; then
        echo "✅ PASS: $2"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $2"
        ((TESTS_FAILED++))
    fi
}

echo "=== Claude Wrapper Script Tests ==="
echo "Testing claude-agent-gitlab.sh wrapper functionality"
echo ""

# Test 1: Wrapper script exists and is executable
echo "Test 1: Wrapper script validation"
if [[ -f "$WRAPPER_SCRIPT" ]] && [[ -x "$WRAPPER_SCRIPT" ]]; then
    test_result 0 "Wrapper script exists and is executable"
else
    test_result 1 "Wrapper script missing or not executable"
    exit 1
fi

# Test 2: Help command functionality
echo "Test 2: Help command"
HELP_OUTPUT=$("$WRAPPER_SCRIPT" help 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -q "Claude Code Agent GitLab API Wrapper"; then
    test_result 0 "Help command displays correct information"
else
    test_result 1 "Help command missing or incorrect"
fi

# Test 3: Test command (basic connectivity)
echo "Test 3: Test command functionality"
TEST_OUTPUT=$("$WRAPPER_SCRIPT" test 2>&1 || true)
if echo "$TEST_OUTPUT" | grep -q "Testing GitLab API connection"; then
    test_result 0 "Test command executes and shows connection attempt"
    
    # Check if the test actually succeeds (if token is available)
    if echo "$TEST_OUTPUT" | grep -q "✅ GitLab API connection successful"; then
        echo "  ✨ API connection successful"
    elif echo "$TEST_OUTPUT" | grep -q "❌ GitLab API connection failed"; then
        echo "  ⚠️  API connection failed (likely token/network issue)"
    fi
else
    test_result 1 "Test command not functioning properly"
fi

# Test 4: Command validation (invalid command)
echo "Test 4: Invalid command handling"
INVALID_OUTPUT=$("$WRAPPER_SCRIPT" invalid-command 2>&1 || true)
if echo "$INVALID_OUTPUT" | grep -q "Unknown command"; then
    test_result 0 "Invalid commands properly rejected with error message"
else
    test_result 1 "Invalid commands not properly handled"
fi

# Test 5: List issues command structure
echo "Test 5: List issues command structure"
LIST_OUTPUT=$("$WRAPPER_SCRIPT" list-issues 2>&1 || true)
if echo "$LIST_OUTPUT" | grep -q "Listing GitLab issues"; then
    test_result 0 "List issues command executes with proper logging"
    
    # Check if we get JSON response or error
    if echo "$LIST_OUTPUT" | grep -q "\[" || echo "$LIST_OUTPUT" | grep -q "Error"; then
        echo "  ✨ Command produces output (JSON or error)"
    fi
else
    test_result 1 "List issues command not functioning"
fi

# Test 6: Get issue command parameter validation
echo "Test 6: Get issue parameter validation"
GET_OUTPUT=$("$WRAPPER_SCRIPT" get-issue 2>&1 || true)
if echo "$GET_OUTPUT" | grep -q "Usage.*get-issue.*issue_iid"; then
    test_result 0 "Get issue command properly validates required parameters"
else
    test_result 1 "Get issue command parameter validation missing"
fi

# Test 7: Create issue parameter validation
echo "Test 7: Create issue parameter validation"
CREATE_OUTPUT=$("$WRAPPER_SCRIPT" create-issue 2>&1 || true)
if echo "$CREATE_OUTPUT" | grep -q "Usage.*create-issue.*title.*description"; then
    test_result 0 "Create issue command properly validates required parameters"
else
    test_result 1 "Create issue command parameter validation missing"
fi

# Test 8: Update issue parameter validation
echo "Test 8: Update issue parameter validation"
UPDATE_OUTPUT=$("$WRAPPER_SCRIPT" update-issue 2>&1 || true)
if echo "$UPDATE_OUTPUT" | grep -q "Usage.*update-issue.*issue_iid"; then
    test_result 0 "Update issue command properly validates required parameters"
else
    test_result 1 "Update issue command parameter validation missing"
fi

# Test 9: Environment detection
echo "Test 9: Script environment detection"
# Check if script properly detects its environment
ENV_TEST=$("$WRAPPER_SCRIPT" test 2>&1 | head -5 || true)
if echo "$ENV_TEST" | grep -q "GITLAB-API"; then
    test_result 0 "Script properly initializes with logging prefix"
else
    test_result 1 "Script environment setup issues"
fi

# Test 10: Token acquisition attempt
echo "Test 10: Token acquisition mechanism"
# This tests whether the wrapper properly attempts to get a token
TOKEN_TEST_OUTPUT=$("$WRAPPER_SCRIPT" list-labels 2>&1 || true)
if echo "$TOKEN_TEST_OUTPUT" | grep -q "No GitLab token available" || echo "$TOKEN_TEST_OUTPUT" | grep -q "Listing GitLab labels"; then
    test_result 0 "Wrapper properly attempts token acquisition"
else
    test_result 1 "Wrapper token acquisition mechanism unclear"
fi

# Test 11: JSON output validation (if token available)
echo "Test 11: JSON output validation"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    LABELS_OUTPUT=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null || echo "FAILED")
    if echo "$LABELS_OUTPUT" | jq . >/dev/null 2>&1; then
        test_result 0 "Wrapper produces valid JSON output"
    elif echo "$LABELS_OUTPUT" | grep -q "FAILED\|Error"; then
        test_result 1 "Wrapper failed to produce output (API/network issue)"
    else
        test_result 1 "Wrapper produces invalid JSON output"
    fi
else
    echo "⚠️  SKIP: JSON output validation (no token available)"
fi

# Test 12: Error handling and logging
echo "Test 12: Error handling and logging"
# Test with a likely invalid issue ID
ERROR_TEST=$("$WRAPPER_SCRIPT" get-issue 99999 2>&1 || true)
if echo "$ERROR_TEST" | grep -q "Getting GitLab issue #99999"; then
    test_result 0 "Wrapper provides proper logging for operations"
    
    # Check if error is handled gracefully
    if echo "$ERROR_TEST" | grep -q "404\|not found" || echo "$ERROR_TEST" | grep -q "Error"; then
        echo "  ✨ Errors handled gracefully"
    fi
else
    test_result 1 "Wrapper logging mechanism not working"
fi

# Test 13: Command completion status
echo "Test 13: Command completion and exit codes"
# Test that successful commands return 0 and failed ones return non-zero
"$WRAPPER_SCRIPT" help >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    test_result 0 "Help command returns proper exit code (0)"
else
    test_result 1 "Help command returns improper exit code"
fi

"$WRAPPER_SCRIPT" invalid-command >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    test_result 0 "Invalid command returns proper error exit code (non-zero)"
else
    test_result 1 "Invalid command returns improper exit code (should be non-zero)"
fi

echo ""
echo "=== Claude Wrapper Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Claude wrapper tests FAILED"
    exit 1
else
    echo "✅ All Claude wrapper tests PASSED"
    exit 0
fi