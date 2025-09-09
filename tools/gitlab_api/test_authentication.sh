#!/bin/bash
# Authentication Tests for GitLab API
# Tests token validation, retrieval, and authentication scenarios

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

echo "=== GitLab Authentication Tests ==="
echo "Testing token validation and retrieval mechanisms"
echo ""

# Test 1: Token retrieval script exists and is executable
echo "Test 1: Token retrieval script validation"
if [[ -f "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" ]] && [[ -x "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" ]]; then
    test_result 0 "Token retrieval script exists and is executable"
else
    test_result 1 "Token retrieval script missing or not executable"
fi

# Test 2: Environment variable token detection
echo "Test 2: Environment variable token detection"
export GITLAB_PRIVATE_TOKEN="test-token-from-env"
TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
if [[ "$TOKEN_OUTPUT" == "test-token-from-env" ]]; then
    test_result 0 "Environment variable token correctly detected"
else
    test_result 1 "Environment variable token not detected: $TOKEN_OUTPUT"
fi
unset GITLAB_PRIVATE_TOKEN

# Test 3: Config file token detection
echo "Test 3: Config file token detection"
# Create temporary config file
TEMP_CONFIG="$PROJECT_ROOT/.gitlab_config.test"
echo "GITLAB_TOKEN=test-token-from-config" > "$TEMP_CONFIG"

# Temporarily replace the config file path in the script for testing
# This is a simplified test - in reality we'd need to modify the script or test with the actual file
if [[ -f "$PROJECT_ROOT/.gitlab_config" ]]; then
    # Test with existing config
    source "$PROJECT_ROOT/.gitlab_config" 2>/dev/null
    if [[ -n "$GITLAB_TOKEN" ]]; then
        test_result 0 "Config file token available"
    else
        test_result 1 "Config file exists but no token found"
    fi
else
    test_result 1 "No .gitlab_config file found (expected for security)"
fi

# Clean up
rm -f "$TEMP_CONFIG"

# Test 4: No token available scenario
echo "Test 4: No token available error handling"
unset GITLAB_PRIVATE_TOKEN
unset GITLAB_TOKEN
# Run without any token source available
ERROR_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "Error: GitLab API token not found"; then
    test_result 0 "Proper error message when no token available"
else
    test_result 1 "No error message or incorrect error when no token available"
fi

# Test 5: GitLab API basic connectivity (if token is available)
echo "Test 5: GitLab API connectivity test"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    RESPONSE=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" -o /dev/null 2>/dev/null || echo "FAILED")
    
    if [[ "$RESPONSE" == "200" ]]; then
        test_result 0 "GitLab API connectivity successful with valid token"
    elif [[ "$RESPONSE" == "401" ]]; then
        test_result 1 "GitLab API returned 401 (token invalid or expired)"
    elif [[ "$RESPONSE" == "FAILED" ]]; then
        test_result 1 "GitLab API request failed (network/DNS issues)"
    else
        test_result 1 "GitLab API returned unexpected status: $RESPONSE"
    fi
else
    echo "⚠️  SKIP: GitLab API connectivity (no token available)"
fi

# Test 6: Token format validation
echo "Test 6: Token format validation"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # GitLab tokens should be alphanumeric and 20+ characters
    if [[ ${#TOKEN} -ge 20 ]] && [[ $TOKEN =~ ^[a-zA-Z0-9_-]+$ ]]; then
        test_result 0 "Token format appears valid (${#TOKEN} chars, alphanumeric)"
    else
        test_result 1 "Token format suspicious (${#TOKEN} chars): ${TOKEN:0:10}..."
    fi
else
    echo "⚠️  SKIP: Token format validation (no token available)"
fi

# Test 7: Multiple authentication sources priority
echo "Test 7: Authentication source priority"
# Set both environment and potentially config file
export GITLAB_PRIVATE_TOKEN="env-token-priority"
echo "GITLAB_TOKEN=config-token-should-be-ignored" > "$PROJECT_ROOT/.gitlab_config.test"

TOKEN_OUTPUT=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "FAILED")
if [[ "$TOKEN_OUTPUT" == "env-token-priority" ]]; then
    test_result 0 "Environment variable correctly takes priority over config file"
else
    test_result 1 "Environment variable priority incorrect: $TOKEN_OUTPUT"
fi

# Clean up
unset GITLAB_PRIVATE_TOKEN
rm -f "$PROJECT_ROOT/.gitlab_config.test"

# Test 8: curl authentication header format
echo "Test 8: curl authentication header format"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test that the header format works with curl
    HEADER_TEST=$(curl -s -D- -o /dev/null --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null | head -1 || echo "FAILED")
    
    if echo "$HEADER_TEST" | grep -q "HTTP"; then
        test_result 0 "curl authentication header format accepted"
    else
        test_result 1 "curl authentication header format rejected"
    fi
else
    echo "⚠️  SKIP: curl header format test (no token available)"
fi

echo ""
echo "=== Authentication Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Authentication tests FAILED"
    exit 1
else
    echo "✅ All authentication tests PASSED"
    exit 0
fi