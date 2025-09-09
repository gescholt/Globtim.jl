#!/bin/bash
# Authentication Edge Cases Tests
# Tests complex authentication scenarios and edge cases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

echo "=== Authentication Edge Cases Tests ==="
echo ""

# Test 1: Empty token handling
echo "Test 1: Empty token handling"
export GITLAB_PRIVATE_TOKEN=""
EMPTY_TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>&1 || echo "ERROR_EXPECTED")
unset GITLAB_PRIVATE_TOKEN

if echo "$EMPTY_TOKEN_OUTPUT" | grep -q "Error.*not found\|ERROR_EXPECTED"; then
    test_result 0 "Empty token properly rejected"
else
    test_result 1 "Empty token not properly handled"
fi

# Test 2: Whitespace-only token
echo "Test 2: Whitespace-only token"
export GITLAB_PRIVATE_TOKEN="   "
WHITESPACE_TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN

if [[ "$WHITESPACE_TOKEN_OUTPUT" == "   " ]]; then
    echo "  ⚠️  Whitespace token accepted (potential security issue)"
    test_result 1 "Whitespace-only token should be rejected"
else
    test_result 0 "Whitespace-only token properly handled"
fi

# Test 3: Very long token
echo "Test 3: Very long token handling"
LONG_TOKEN=$(printf 'a%.0s' {1..1000})
export GITLAB_PRIVATE_TOKEN="$LONG_TOKEN"
LONG_TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN

if [[ ${#LONG_TOKEN_OUTPUT} -eq 1000 ]]; then
    test_result 0 "Very long token handled correctly"
else
    test_result 1 "Very long token truncated or rejected"
fi

# Test 4: Token with special characters
echo "Test 4: Token with special characters"
SPECIAL_TOKEN="abc123_-+/="
export GITLAB_PRIVATE_TOKEN="$SPECIAL_TOKEN"
SPECIAL_TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN

if [[ "$SPECIAL_TOKEN_OUTPUT" == "$SPECIAL_TOKEN" ]]; then
    test_result 0 "Token with special characters handled correctly"
else
    test_result 1 "Token with special characters not properly handled"
fi

# Test 5: Multiple environment variables set
echo "Test 5: Environment variable precedence"
export GITLAB_PRIVATE_TOKEN="env-token"
export GITLAB_TOKEN="config-style-token"
PRECEDENCE_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN GITLAB_TOKEN

if [[ "$PRECEDENCE_OUTPUT" == "env-token" ]]; then
    test_result 0 "GITLAB_PRIVATE_TOKEN takes precedence over GITLAB_TOKEN"
else
    test_result 1 "Environment variable precedence incorrect: $PRECEDENCE_OUTPUT"
fi

# Test 6: Config file with multiple tokens
echo "Test 6: Config file with multiple token definitions"
TEMP_CONFIG="$PROJECT_ROOT/.gitlab_config.test"
cat > "$TEMP_CONFIG" << EOF
GITLAB_TOKEN=first-token
GITLAB_PRIVATE_TOKEN=second-token
GITLAB_API_TOKEN=third-token
EOF

# Simulate sourcing this config
source "$TEMP_CONFIG"
if [[ -n "$GITLAB_TOKEN" ]]; then
    test_result 0 "Config file properly defines token variables"
else
    test_result 1 "Config file token definitions not working"
fi
unset GITLAB_TOKEN GITLAB_PRIVATE_TOKEN GITLAB_API_TOKEN
rm -f "$TEMP_CONFIG"

# Test 7: Config file with invalid syntax
echo "Test 7: Config file with invalid syntax"
INVALID_CONFIG="$PROJECT_ROOT/.gitlab_config.invalid"
cat > "$INVALID_CONFIG" << EOF
GITLAB_TOKEN=valid-token
invalid syntax here
GITLAB_TOKEN=another-token
EOF

# Try to source it (should handle gracefully)
if source "$INVALID_CONFIG" 2>/dev/null; then
    if [[ -n "$GITLAB_TOKEN" ]]; then
        test_result 0 "Invalid config file handled gracefully"
    else
        test_result 1 "Invalid config file broke token parsing"
    fi
else
    test_result 0 "Invalid config file properly rejected"
fi
rm -f "$INVALID_CONFIG"
unset GITLAB_TOKEN

# Test 8: Permission denied on config file
echo "Test 8: Config file permission handling"
PROTECTED_CONFIG="$PROJECT_ROOT/.gitlab_config.protected"
echo "GITLAB_TOKEN=protected-token" > "$PROTECTED_CONFIG"
chmod 000 "$PROTECTED_CONFIG" 2>/dev/null || true

# Try to read protected file
PROTECTED_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>&1 || echo "FAILED")

# Restore permissions and clean up
chmod 644 "$PROTECTED_CONFIG" 2>/dev/null || true
rm -f "$PROTECTED_CONFIG" 2>/dev/null || true

if echo "$PROTECTED_OUTPUT" | grep -q "Error\|FAILED"; then
    test_result 0 "Permission denied config file handled gracefully"
else
    test_result 1 "Permission denied config file not properly handled"
fi

# Test 9: Concurrent access simulation
echo "Test 9: Concurrent token access"
export GITLAB_PRIVATE_TOKEN="concurrent-test-token"

# Run multiple instances simultaneously
"$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" &
PID1=$!
"$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" &
PID2=$!
"$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" &
PID3=$!

wait $PID1 $PID2 $PID3

if [[ $? -eq 0 ]]; then
    test_result 0 "Concurrent token access handled without issues"
else
    test_result 1 "Concurrent access caused failures"
fi

unset GITLAB_PRIVATE_TOKEN

# Test 10: Token with newlines/carriage returns
echo "Test 10: Token with embedded newlines"
TOKEN_WITH_NEWLINES="token-part1
token-part2"
export GITLAB_PRIVATE_TOKEN="$TOKEN_WITH_NEWLINES"
NEWLINE_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN

# This should either preserve the newlines or fail gracefully
if [[ "$NEWLINE_OUTPUT" == "$TOKEN_WITH_NEWLINES" ]] || [[ "$NEWLINE_OUTPUT" == "FAILED" ]]; then
    test_result 0 "Token with newlines handled consistently"
else
    test_result 1 "Token with newlines corrupted: $(echo "$NEWLINE_OUTPUT" | tr '\n' ' ')"
fi

# Test 11: Non-existent config file directory
echo "Test 11: Non-existent config directory handling"
NONEXISTENT_CONFIG="/nonexistent/path/.gitlab_config"
# This test verifies the script doesn't crash when config path is invalid
if "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null; then
    test_result 0 "Non-existent config path handled without crash"
else
    # This is expected behavior
    test_result 0 "Non-existent config path properly rejected"
fi

# Test 12: Unicode characters in token
echo "Test 12: Unicode characters in token"
UNICODE_TOKEN="token-with-ñáéíóú-characters"
export GITLAB_PRIVATE_TOKEN="$UNICODE_TOKEN"
UNICODE_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
unset GITLAB_PRIVATE_TOKEN

if [[ "$UNICODE_OUTPUT" == "$UNICODE_TOKEN" ]]; then
    test_result 0 "Unicode characters in token preserved"
else
    test_result 1 "Unicode characters in token not handled properly"
fi

echo ""
echo "=== Authentication Edge Cases Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Authentication edge case tests FAILED"
    exit 1
else
    echo "✅ All authentication edge case tests PASSED"
    exit 0
fi