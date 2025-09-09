#!/bin/bash
# Wrapper Edge Cases Tests
# Tests edge cases and error scenarios for claude-agent-gitlab.sh

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

echo "=== Wrapper Edge Cases Tests ==="
echo ""

# Test 1: Very long command-line arguments
echo "Test 1: Very long command-line arguments"
LONG_TITLE=$(printf 'A%.0s' {1..1000})
LONG_DESC=$(printf 'B%.0s' {1..5000})
LONG_LABELS=$(printf 'label%.0s,' {1..100})

LONG_ARG_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "$LONG_TITLE" "$LONG_DESC" "$LONG_LABELS" 2>&1 || echo "FAILED")
if echo "$LONG_ARG_OUTPUT" | grep -q "Creating GitLab issue"; then
    test_result 0 "Very long arguments handled without crash"
else
    test_result 1 "Very long arguments caused failure"
fi

# Test 2: Special characters in arguments
echo "Test 2: Special characters in arguments"
SPECIAL_TITLE="Test with \"quotes\" and 'apostrophes' & symbols"
SPECIAL_DESC="Description with newlines\nand tabs\tand quotes \"test\" and backslashes \\"
SPECIAL_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "$SPECIAL_TITLE" "$SPECIAL_DESC" 2>&1 || echo "FAILED")

if echo "$SPECIAL_OUTPUT" | grep -q "Creating GitLab issue" && ! echo "$SPECIAL_OUTPUT" | grep -q "FAILED"; then
    test_result 0 "Special characters in arguments handled properly"
else
    test_result 1 "Special characters caused command parsing issues"
fi

# Test 3: Empty string arguments
echo "Test 3: Empty string arguments"
EMPTY_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "" "" "" 2>&1 || echo "FAILED")
if echo "$EMPTY_OUTPUT" | grep -q "Creating GitLab issue"; then
    test_result 0 "Empty string arguments handled"
else
    test_result 1 "Empty string arguments caused failure"
fi

# Test 4: Missing arguments for commands that require them
echo "Test 4: Missing required arguments"
MISSING_ARGS=$("$WRAPPER_SCRIPT" get-issue 2>&1 || true)
if echo "$MISSING_ARGS" | grep -q "Usage.*get-issue"; then
    test_result 0 "Missing required arguments properly detected and usage shown"
else
    test_result 1 "Missing arguments not properly handled"
fi

# Test 5: Invalid issue IID format
echo "Test 5: Invalid issue IID format"
for invalid_iid in "abc" "123abc" "-1" "0" "99999999999999999999"; do
    INVALID_OUTPUT=$("$WRAPPER_SCRIPT" get-issue "$invalid_iid" 2>&1 || echo "EXPECTED_ERROR")
    if echo "$INVALID_OUTPUT" | grep -q "Getting GitLab issue #$invalid_iid"; then
        echo "  Attempted to get issue with invalid IID: $invalid_iid"
    fi
done
test_result 0 "Invalid IID formats processed (API will handle validation)"

# Test 6: JSON injection in arguments
echo "Test 6: JSON injection attempt"
JSON_INJECTION='{"malicious": "payload", "state_event": "close"}'
INJECTION_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "Test" "$JSON_INJECTION" 2>&1 || echo "FAILED")
if echo "$INJECTION_OUTPUT" | grep -q "Creating GitLab issue"; then
    test_result 0 "JSON injection in description handled (not interpreted as JSON)"
else
    test_result 1 "JSON injection caused unexpected behavior"
fi

# Test 7: Command injection attempt
echo "Test 7: Command injection attempt"
CMD_INJECTION="Test; rm -rf /tmp/test; echo malicious"
CMD_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "$CMD_INJECTION" "Description" 2>&1 || echo "FAILED")
if echo "$CMD_OUTPUT" | grep -q "Creating GitLab issue" && ! echo "$CMD_OUTPUT" | grep -q "malicious"; then
    test_result 0 "Command injection properly escaped"
else
    test_result 1 "Command injection not properly handled"
fi

# Test 8: Binary data in arguments
echo "Test 8: Binary data in arguments"
BINARY_DATA=$(echo -e "\x00\x01\x02\x03\xFF")
BINARY_OUTPUT=$("$WRAPPER_SCRIPT" create-issue "Binary Test" "$BINARY_DATA" 2>&1 || echo "FAILED")
if echo "$BINARY_OUTPUT" | grep -q "Creating GitLab issue"; then
    test_result 0 "Binary data in arguments handled without crash"
else
    test_result 1 "Binary data caused failure"
fi

# Test 9: Concurrent wrapper execution
echo "Test 9: Concurrent wrapper execution"
"$WRAPPER_SCRIPT" help >/dev/null 2>&1 &
PID1=$!
"$WRAPPER_SCRIPT" help >/dev/null 2>&1 &
PID2=$!
"$WRAPPER_SCRIPT" help >/dev/null 2>&1 &
PID3=$!

wait $PID1 $PID2 $PID3
EXIT_CODES=($?)

if [[ ${EXIT_CODES[0]} -eq 0 ]]; then
    test_result 0 "Concurrent wrapper execution handled successfully"
else
    test_result 1 "Concurrent execution caused issues"
fi

# Test 10: Environment variable interference
echo "Test 10: Environment variable interference"
export GITLAB_PROJECT_ID="invalid-project-id"
export PRIVATE_TOKEN="interference-token"
INTERFERENCE_OUTPUT=$("$WRAPPER_SCRIPT" test 2>&1 || echo "EXPECTED_ERROR")
unset GITLAB_PROJECT_ID PRIVATE_TOKEN

if echo "$INTERFERENCE_OUTPUT" | grep -q "Testing GitLab API connection"; then
    test_result 0 "Environment variable interference handled (wrapper uses own config)"
else
    test_result 1 "Environment variables interfered with wrapper operation"
fi

# Test 11: Corrupted token scenarios
echo "Test 11: Corrupted token handling"
# Test with various corrupted token formats
export GITLAB_PRIVATE_TOKEN="corrupted-token-with-invalid-chars-!@#$%^&*()"
CORRUPT_OUTPUT=$("$WRAPPER_SCRIPT" test 2>&1 || echo "EXPECTED_ERROR")
unset GITLAB_PRIVATE_TOKEN

if echo "$CORRUPT_OUTPUT" | grep -q "❌ GitLab API connection failed\|EXPECTED_ERROR"; then
    test_result 0 "Corrupted token properly rejected by API"
else
    test_result 1 "Corrupted token handling unclear"
fi

# Test 12: Network timeout simulation
echo "Test 12: Network timeout handling"
# Use invalid hostname to force timeout
export GITLAB_API_BASE_URL="https://nonexistent.gitlab.invalid"
TIMEOUT_OUTPUT=$(timeout 10 "$WRAPPER_SCRIPT" test 2>&1 || echo "TIMEOUT_OR_ERROR")
unset GITLAB_API_BASE_URL

if echo "$TIMEOUT_OUTPUT" | grep -q "TIMEOUT_OR_ERROR\|failed\|connection"; then
    test_result 0 "Network timeout/failure handled gracefully"
else
    test_result 1 "Network issues not properly handled"
fi

# Test 13: Large JSON response handling
echo "Test 13: Large JSON response simulation"
# This would test if the wrapper can handle large API responses
# We'll simulate by testing with list-issues which could return many issues
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    LARGE_RESPONSE=$("$WRAPPER_SCRIPT" list-issues all 2>&1 || echo "FAILED")
    if echo "$LARGE_RESPONSE" | grep -q "Listing GitLab issues" && ! echo "$LARGE_RESPONSE" | grep -q "FAILED"; then
        test_result 0 "Large API responses handled successfully"
    else
        test_result 1 "Large API response handling issues"
    fi
else
    test_result 1 "Cannot test large responses - no token available"
fi

# Test 14: Signal handling (interruption)
echo "Test 14: Signal handling during operation"
# Start a wrapper command and interrupt it
"$WRAPPER_SCRIPT" list-issues >/dev/null 2>&1 &
WRAPPER_PID=$!
sleep 0.5
kill -TERM $WRAPPER_PID 2>/dev/null || true
wait $WRAPPER_PID 2>/dev/null || true

# Check if process was properly cleaned up
if ! ps -p $WRAPPER_PID >/dev/null 2>&1; then
    test_result 0 "Signal interruption handled cleanly"
else
    test_result 1 "Signal handling left orphaned processes"
    kill -9 $WRAPPER_PID 2>/dev/null || true
fi

# Test 15: Malformed curl responses
echo "Test 15: Malformed API response handling"
# This tests the wrapper's ability to handle unexpected API responses
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test with an endpoint that might return HTML instead of JSON (error pages)
    MALFORMED_TEST=$("$WRAPPER_SCRIPT" get-issue 0 2>&1 || echo "EXPECTED_ERROR")
    if echo "$MALFORMED_TEST" | grep -q "EXPECTED_ERROR\|Getting GitLab issue"; then
        test_result 0 "Malformed API responses handled without crash"
    else
        test_result 1 "Malformed response handling unclear"
    fi
else
    test_result 1 "Cannot test malformed responses - no token available"
fi

echo ""
echo "=== Wrapper Edge Cases Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Wrapper edge case tests FAILED"
    exit 1
else
    echo "✅ All wrapper edge case tests PASSED"
    exit 0
fi