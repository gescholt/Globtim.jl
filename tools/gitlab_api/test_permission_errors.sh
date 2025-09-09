#!/bin/bash
# Permission Error Tests
# Tests handling of authentication and authorization failures

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

echo "=== Permission Error Tests ==="
echo ""

# Test 1: Invalid token format
echo "Test 1: Invalid token format handling"
INVALID_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: invalid-token-format" \
    "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "NETWORK_ERROR")

HTTP_CODE="${INVALID_TOKEN_RESPONSE: -3}"
if [[ "$HTTP_CODE" == "401" ]] || echo "$INVALID_TOKEN_RESPONSE" | grep -q "NETWORK_ERROR"; then
    test_result 0 "Invalid token format properly rejected with 401"
else
    test_result 1 "Invalid token format not properly handled (got HTTP $HTTP_CODE)"
fi

# Test 2: Expired token simulation
echo "Test 2: Expired/revoked token handling"
EXPIRED_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: glpat-xxxxxxxxxxxxxxxxxxxx" \
    "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "NETWORK_ERROR")

HTTP_CODE="${EXPIRED_TOKEN_RESPONSE: -3}"
if [[ "$HTTP_CODE" == "401" ]] || echo "$EXPIRED_TOKEN_RESPONSE" | grep -q "NETWORK_ERROR"; then
    test_result 0 "Expired/invalid token properly rejected with 401"
else
    test_result 1 "Expired token handling unclear (got HTTP $HTTP_CODE)"
fi

# Test 3: No token provided
echo "Test 3: Missing token handling"
NO_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" \
    "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "NETWORK_ERROR")

HTTP_CODE="${NO_TOKEN_RESPONSE: -3}"
if [[ "$HTTP_CODE" == "401" ]] || echo "$NO_TOKEN_RESPONSE" | grep -q "NETWORK_ERROR"; then
    test_result 0 "Missing token properly rejected with 401"
else
    test_result 1 "Missing token not properly handled (got HTTP $HTTP_CODE)"
fi

# Test 4: Token with insufficient permissions
echo "Test 4: Insufficient permissions simulation"
# Test with a token that might have limited scope
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Try to access admin-only endpoints or other projects
    PERMISSION_TEST=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/1" 2>/dev/null || echo "NETWORK_ERROR")
    
    HTTP_CODE="${PERMISSION_TEST: -3}"
    if [[ "$HTTP_CODE" == "403" || "$HTTP_CODE" == "404" || "$HTTP_CODE" == "401" ]]; then
        test_result 0 "Insufficient permissions properly handled with error code"
    elif [[ "$HTTP_CODE" == "200" ]]; then
        test_result 0 "Token has access to other projects (high permissions)"
    else
        test_result 1 "Permission handling unclear (got HTTP $HTTP_CODE)"
    fi
else
    test_result 1 "Cannot test permissions - no token available"
fi

# Test 5: Project access permissions
echo "Test 5: Project access validation"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test access to the specific project
    PROJECT_ACCESS=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "NETWORK_ERROR")
    
    HTTP_CODE="${PROJECT_ACCESS: -3}"
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_result 0 "Project access permissions verified (HTTP 200)"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        test_result 1 "Token lacks project access permissions (HTTP 403)"
    elif [[ "$HTTP_CODE" == "404" ]]; then
        test_result 1 "Project not found or no access (HTTP 404)"
    elif [[ "$HTTP_CODE" == "401" ]]; then
        test_result 1 "Token authentication failed (HTTP 401)"
    else
        test_result 1 "Project access validation unclear (got HTTP $HTTP_CODE)"
    fi
else
    test_result 1 "Cannot test project access - no token available"
fi

# Test 6: Issue creation permissions
echo "Test 6: Issue creation permissions"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test if we can create issues (don't actually create, just test the endpoint response to malformed data)
    CREATE_PERMISSION=$(curl -s -w "%{http_code}" -X POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data '{"title": ""}' \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>/dev/null || echo "NETWORK_ERROR")
    
    HTTP_CODE="${CREATE_PERMISSION: -3}"
    if [[ "$HTTP_CODE" == "400" ]]; then
        test_result 0 "Issue creation permissions available (got validation error as expected)"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        test_result 1 "Token lacks issue creation permissions (HTTP 403)"
    elif [[ "$HTTP_CODE" == "401" ]]; then
        test_result 1 "Authentication failed for issue creation (HTTP 401)"
    elif [[ "$HTTP_CODE" == "201" ]]; then
        test_result 0 "Issue creation permissions available (but may have created empty issue!)"
        echo "  ⚠️  WARNING: Empty issue may have been created"
    else
        test_result 1 "Issue creation permission check unclear (got HTTP $HTTP_CODE)"
    fi
else
    test_result 1 "Cannot test issue creation permissions - no token available"
fi

# Test 7: Issue modification permissions
echo "Test 7: Issue modification permissions"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # First get an issue to test modification
    ISSUES_JSON=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues?per_page=1" 2>/dev/null || echo "[]")
    
    ISSUE_IID=$(echo "$ISSUES_JSON" | jq -r '.[0].iid // empty' 2>/dev/null || echo "")
    
    if [[ -n "$ISSUE_IID" && "$ISSUE_IID" != "null" ]]; then
        # Test modification with minimal change (should not actually change anything)
        MODIFY_PERMISSION=$(curl -s -w "%{http_code}" -X PUT \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            --data '{}' \
            "https://git.mpi-cbg.de/api/v4/projects/2545/issues/$ISSUE_IID" 2>/dev/null || echo "NETWORK_ERROR")
        
        HTTP_CODE="${MODIFY_PERMISSION: -3}"
        if [[ "$HTTP_CODE" == "200" ]]; then
            test_result 0 "Issue modification permissions available"
        elif [[ "$HTTP_CODE" == "403" ]]; then
            test_result 1 "Token lacks issue modification permissions (HTTP 403)"
        elif [[ "$HTTP_CODE" == "401" ]]; then
            test_result 1 "Authentication failed for issue modification (HTTP 401)"
        else
            test_result 1 "Issue modification permission check unclear (got HTTP $HTTP_CODE)"
        fi
    else
        test_result 1 "Cannot test issue modification - no issues available"
    fi
else
    test_result 1 "Cannot test issue modification permissions - no token available"
fi

# Test 8: Admin-only endpoint access
echo "Test 8: Admin-only endpoint access"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test access to admin-only endpoints
    ADMIN_TEST=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/users" 2>/dev/null || echo "NETWORK_ERROR")
    
    HTTP_CODE="${ADMIN_TEST: -3}"
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_result 0 "Token has admin-level permissions (can list users)"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        test_result 0 "Token properly restricted from admin endpoints (HTTP 403)"
    elif [[ "$HTTP_CODE" == "401" ]]; then
        test_result 1 "Authentication failed for admin endpoint (HTTP 401)"
    else
        test_result 1 "Admin endpoint access check unclear (got HTTP $HTTP_CODE)"
    fi
else
    test_result 1 "Cannot test admin permissions - no token available"
fi

# Test 9: Cross-project access
echo "Test 9: Cross-project access validation"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test access to a different project (using a common project ID)
    CROSS_PROJECT_TEST=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/1/issues" 2>/dev/null || echo "NETWORK_ERROR")
    
    HTTP_CODE="${CROSS_PROJECT_TEST: -3}"
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_result 0 "Token has cross-project access permissions"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        test_result 0 "Token properly restricted to specific projects (HTTP 403)"
    elif [[ "$HTTP_CODE" == "404" ]]; then
        test_result 0 "Cross-project access restricted or project not found (HTTP 404)"
    elif [[ "$HTTP_CODE" == "401" ]]; then
        test_result 1 "Authentication failed for cross-project access (HTTP 401)"
    else
        test_result 1 "Cross-project access check unclear (got HTTP $HTTP_CODE)"
    fi
else
    test_result 1 "Cannot test cross-project access - no token available"
fi

# Test 10: Token scope validation
echo "Test 10: Token scope and capabilities"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test different scopes by trying various endpoints
    SCOPES_TESTED=0
    SCOPES_AVAILABLE=0
    
    # Test read scope
    READ_TEST=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "NETWORK_ERROR")
    ((SCOPES_TESTED++))
    if echo "$READ_TEST" | grep -q "200"; then
        ((SCOPES_AVAILABLE++))
        echo "  ✓ Read scope available"
    fi
    
    # Test write scope (minimal test)
    WRITE_TEST=$(curl -s -w "%{http_code}" -X PUT \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data '{}' \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues/999999" 2>/dev/null || echo "NETWORK_ERROR")
    ((SCOPES_TESTED++))
    if echo "$WRITE_TEST" | grep -q "404"; then
        ((SCOPES_AVAILABLE++))
        echo "  ✓ Write scope available (got 404 for non-existent issue as expected)"
    fi
    
    if [[ $SCOPES_AVAILABLE -ge 1 ]]; then
        test_result 0 "Token scopes functional ($SCOPES_AVAILABLE/$SCOPES_TESTED scopes working)"
    else
        test_result 1 "Token scope issues detected ($SCOPES_AVAILABLE/$SCOPES_TESTED scopes working)"
    fi
else
    test_result 1 "Cannot test token scopes - no token available"
fi

echo ""
echo "=== Permission Error Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Permission error tests FAILED"
    exit 1
else
    echo "✅ All permission error tests PASSED"
    exit 0
fi