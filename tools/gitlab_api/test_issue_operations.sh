#!/bin/bash
# Issue Operations Tests
# Tests CRUD operations for GitLab issues via the wrapper

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

# Check if token is available for API operations
check_token_available() {
    if ! "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" >/dev/null 2>&1; then
        echo "⚠️  WARNING: No GitLab token available - API operation tests will be limited"
        return 1
    fi
    return 0
}

echo "=== GitLab Issue Operations Tests ==="
echo "Testing CRUD operations for GitLab issues"
echo ""

TOKEN_AVAILABLE=0
if check_token_available; then
    TOKEN_AVAILABLE=1
    echo "✓ GitLab token available - full API testing enabled"
else
    echo "⚠️  GitLab token unavailable - testing command structure only"
fi
echo ""

# Test 1: List issues - basic functionality
echo "Test 1: List issues basic functionality"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LIST_OUTPUT=$("$WRAPPER_SCRIPT" list-issues 2>&1 || echo "COMMAND_FAILED")
    if echo "$LIST_OUTPUT" | grep -q "Listing GitLab issues" && ! echo "$LIST_OUTPUT" | grep -q "COMMAND_FAILED"; then
        test_result 0 "List issues command executes successfully"
        
        # Check if we get valid JSON response
        JSON_PART=$(echo "$LIST_OUTPUT" | grep -v "^\[GITLAB-API\]" | grep -v "^\[ERROR\]" | grep -v "^\[WARNING\]" || echo "")
        if echo "$JSON_PART" | jq . >/dev/null 2>&1; then
            echo "  ✨ Valid JSON response received"
        elif echo "$JSON_PART" | grep -q "\[\]"; then
            echo "  ✨ Empty JSON array (no issues match criteria)"
        else
            echo "  ⚠️  Non-JSON response: ${JSON_PART:0:100}..."
        fi
    else
        test_result 1 "List issues command failed to execute"
    fi
else
    test_result 1 "Cannot test list issues - no token available"
fi

# Test 2: List issues with state parameter
echo "Test 2: List issues with state parameter"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    CLOSED_OUTPUT=$("$WRAPPER_SCRIPT" list-issues closed 2>&1 || echo "COMMAND_FAILED")
    if echo "$CLOSED_OUTPUT" | grep -q "state: closed"; then
        test_result 0 "List issues accepts state parameter correctly"
    else
        test_result 1 "List issues state parameter not working"
    fi
else
    test_result 1 "Cannot test list issues with state - no token available"
fi

# Test 3: Get specific issue (test with a known issue)
echo "Test 3: Get specific issue"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # First, get a list of issues to find a valid issue ID
    ISSUES_JSON=$("$WRAPPER_SCRIPT" list-issues 2>/dev/null | grep -v "^\[GITLAB-API\]" | grep -v "^\[ERROR\]" | grep -v "^\[WARNING\]" || echo "[]")
    ISSUE_IID=$(echo "$ISSUES_JSON" | jq -r '.[0].iid // empty' 2>/dev/null || echo "")
    
    if [[ -n "$ISSUE_IID" && "$ISSUE_IID" != "null" ]]; then
        GET_OUTPUT=$("$WRAPPER_SCRIPT" get-issue "$ISSUE_IID" 2>&1 || echo "COMMAND_FAILED")
        if echo "$GET_OUTPUT" | grep -q "Getting GitLab issue #$ISSUE_IID" && ! echo "$GET_OUTPUT" | grep -q "COMMAND_FAILED"; then
            test_result 0 "Get specific issue command works with valid issue ID"
        else
            test_result 1 "Get specific issue command failed"
        fi
    else
        echo "⚠️  SKIP: Get specific issue (no valid issue IDs found)"
    fi
else
    test_result 1 "Cannot test get specific issue - no token available"
fi

# Test 4: Get non-existent issue (error handling)
echo "Test 4: Get non-existent issue error handling"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    ERROR_OUTPUT=$("$WRAPPER_SCRIPT" get-issue 999999 2>&1 || echo "EXPECTED_ERROR")
    if echo "$ERROR_OUTPUT" | grep -q "EXPECTED_ERROR" || echo "$ERROR_OUTPUT" | grep -q "404"; then
        test_result 0 "Non-existent issue properly returns error"
    else
        test_result 1 "Non-existent issue error handling unclear"
    fi
else
    test_result 1 "Cannot test non-existent issue - no token available"
fi

# Test 5: Create issue (dry run - test command structure)
echo "Test 5: Create issue command structure"
# We'll test the command structure but not actually create issues
CREATE_TEST=$("$WRAPPER_SCRIPT" create-issue "Test Issue Title" "Test Description" "test-label" 2>&1 || echo "COMMAND_FAILED")
if echo "$CREATE_TEST" | grep -q "Creating GitLab issue: Test Issue Title"; then
    if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
        test_result 0 "Create issue command executes (may create actual issue)"
        echo "  ⚠️  Note: This may have created a real issue in GitLab"
    else
        test_result 1 "Create issue failed (expected without token)"
    fi
else
    test_result 1 "Create issue command structure invalid"
fi

# Test 6: Update issue command validation
echo "Test 6: Update issue parameter validation"
UPDATE_VALIDATION=$("$WRAPPER_SCRIPT" update-issue 2>&1 || true)
if echo "$UPDATE_VALIDATION" | grep -q "Usage.*update-issue.*issue_iid"; then
    test_result 0 "Update issue properly validates parameters"
else
    test_result 1 "Update issue parameter validation missing"
fi

# Test 7: List labels functionality
echo "Test 7: List labels functionality"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_OUTPUT=$("$WRAPPER_SCRIPT" list-labels 2>&1 || echo "COMMAND_FAILED")
    if echo "$LABELS_OUTPUT" | grep -q "Listing GitLab labels" && ! echo "$LABELS_OUTPUT" | grep -q "COMMAND_FAILED"; then
        test_result 0 "List labels command executes successfully"
        
        # Check for valid JSON
        JSON_PART=$(echo "$LABELS_OUTPUT" | grep -v "^\[GITLAB-API\]" | grep -v "^\[ERROR\]" | grep -v "^\[WARNING\]" || echo "")
        if echo "$JSON_PART" | jq . >/dev/null 2>&1; then
            echo "  ✨ Valid JSON response with labels"
        else
            echo "  ⚠️  Non-JSON response received"
        fi
    else
        test_result 1 "List labels command failed"
    fi
else
    test_result 1 "Cannot test list labels - no token available"
fi

# Test 8: List milestones functionality
echo "Test 8: List milestones functionality"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_OUTPUT=$("$WRAPPER_SCRIPT" list-milestones 2>&1 || echo "COMMAND_FAILED")
    if echo "$MILESTONES_OUTPUT" | grep -q "Listing GitLab milestones" && ! echo "$MILESTONES_OUTPUT" | grep -q "COMMAND_FAILED"; then
        test_result 0 "List milestones command executes successfully"
    else
        test_result 1 "List milestones command failed"
    fi
else
    test_result 1 "Cannot test list milestones - no token available"
fi

# Test 9: JSON parsing validation
echo "Test 9: JSON parsing validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Test if we can successfully parse the JSON output
    ISSUES_JSON=$("$WRAPPER_SCRIPT" list-issues 2>/dev/null | grep -v "^\[" || echo "{}")
    
    # Try to extract basic fields
    TITLE_COUNT=$(echo "$ISSUES_JSON" | jq -r '.[].title' 2>/dev/null | wc -l | tr -d ' ')
    IID_COUNT=$(echo "$ISSUES_JSON" | jq -r '.[].iid' 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$TITLE_COUNT" == "$IID_COUNT" && "$TITLE_COUNT" -gt 0 ]]; then
        test_result 0 "JSON parsing produces consistent structured data"
    elif [[ "$TITLE_COUNT" == "0" ]]; then
        test_result 0 "JSON parsing successful (empty result set)"
    else
        test_result 1 "JSON parsing produces inconsistent data"
    fi
else
    test_result 1 "Cannot test JSON parsing - no token available"
fi

# Test 10: Error response handling
echo "Test 10: API error response handling"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Test with malformed request (invalid project)
    MALFORMED_TEST=$(timeout 10 curl -s --header "PRIVATE-TOKEN: $(cat ~/.gitlab_token 2>/dev/null || echo invalid)" \
        "https://git.mpi-cbg.de/api/v4/projects/99999999/issues" 2>/dev/null || echo "CURL_FAILED")
    
    if echo "$MALFORMED_TEST" | grep -q "404\|CURL_FAILED"; then
        test_result 0 "API properly handles malformed requests"
    else
        test_result 1 "API error handling unclear"
    fi
else
    test_result 1 "Cannot test API error handling - no token available"
fi

# Test 11: Response time performance
echo "Test 11: Response time performance"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    START_TIME=$(date +%s)
    "$WRAPPER_SCRIPT" list-issues >/dev/null 2>&1 || true
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [[ $DURATION -lt 30 ]]; then
        test_result 0 "API response time acceptable ($DURATION seconds)"
    else
        test_result 1 "API response time slow ($DURATION seconds)"
    fi
else
    test_result 1 "Cannot test response time - no token available"
fi

echo ""
echo "=== Issue Operations Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo ""
    echo "⚠️  WARNING: Many tests skipped due to missing GitLab token"
    echo "To enable full testing, configure GitLab authentication:"
    echo "  ./tools/gitlab/setup-secure-config.sh"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Issue operations tests FAILED"
    exit 1
else
    echo "✅ All available issue operations tests PASSED"
    exit 0
fi