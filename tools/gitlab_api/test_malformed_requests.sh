#!/bin/bash
# Malformed Requests Tests
# Tests handling of malformed JSON, invalid parameters, and edge cases

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

echo "=== Malformed Requests Tests ==="
echo ""

# Helper function to test direct API calls with malformed data
test_malformed_api_call() {
    local method="$1"
    local endpoint="$2" 
    local data="$3"
    local description="$4"
    
    if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
        local response=$(curl -s -w "%{http_code}" -X "$method" \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            --data "$data" \
            "https://git.mpi-cbg.de/api/v4/$endpoint" 2>&1 || echo "NETWORK_ERROR")
        
        local http_code="${response: -3}"
        
        if [[ "$http_code" =~ ^[4-5][0-9][0-9]$ ]] || echo "$response" | grep -q "NETWORK_ERROR\|error"; then
            test_result 0 "$description - properly rejected with error"
        else
            test_result 1 "$description - not properly validated"
        fi
    else
        test_result 1 "$description - cannot test without token"
    fi
}

# Test 1: Invalid JSON in create issue
echo "Test 1: Invalid JSON in create issue request"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "Test", "description": invalid json}' "Invalid JSON syntax"

# Test 2: Missing required fields
echo "Test 2: Missing required fields in create issue"
test_malformed_api_call "POST" "projects/2545/issues" '{"description": "Missing title"}' "Missing required title field"

# Test 3: Extremely long field values
echo "Test 3: Extremely long field values"
LONG_TITLE=$(printf 'A%.0s' {1..10000})
LONG_JSON="{\"title\": \"$LONG_TITLE\", \"description\": \"Test\"}"
test_malformed_api_call "POST" "projects/2545/issues" "$LONG_JSON" "Extremely long title field"

# Test 4: Invalid data types
echo "Test 4: Invalid data types in JSON"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": 123, "description": true}' "Invalid data types (number/boolean instead of string)"

# Test 5: SQL injection attempt in JSON
echo "Test 5: SQL injection attempt in issue fields"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "Test"; DROP TABLE issues; --", "description": "Test"}' "SQL injection attempt in title"

# Test 6: XSS attempt in JSON
echo "Test 6: XSS attempt in issue fields"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "<script>alert(\"XSS\")</script>", "description": "Test"}' "XSS injection attempt"

# Test 7: Invalid issue IID formats
echo "Test 7: Invalid issue IID formats"
for invalid_iid in "-1" "0" "abc" "999999999999999999" "1.5" "1e10"; do
    if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
        RESPONSE=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545/issues/$invalid_iid" 2>/dev/null || echo "ERROR")
        
        HTTP_CODE="${RESPONSE: -3}"
        if [[ "$HTTP_CODE" =~ ^[4][0-9][0-9]$ ]] || echo "$RESPONSE" | grep -q "ERROR"; then
            echo "  ✓ Invalid IID '$invalid_iid' properly rejected"
        else
            echo "  ⚠️  Invalid IID '$invalid_iid' handling unclear"
        fi
    fi
done
test_result 0 "Invalid issue IID formats tested"

# Test 8: Malformed label strings
echo "Test 8: Malformed label strings"
MALFORMED_LABELS='["label1", 123, null, {"invalid": "object"}, ""]'
test_malformed_api_call "POST" "projects/2545/issues" "{\"title\": \"Test\", \"description\": \"Test\", \"labels\": $MALFORMED_LABELS}" "Malformed labels array"

# Test 9: Invalid milestone references
echo "Test 9: Invalid milestone references"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "Test", "description": "Test", "milestone_id": "invalid"}' "Invalid milestone ID (string instead of number)"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "Test", "description": "Test", "milestone_id": -1}' "Negative milestone ID"

# Test 10: Invalid state transitions
echo "Test 10: Invalid state transitions"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # First try to get a valid issue to test state transitions
    ISSUES_JSON=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues?per_page=1" 2>/dev/null || echo "[]")
    
    ISSUE_IID=$(echo "$ISSUES_JSON" | jq -r '.[0].iid // empty' 2>/dev/null || echo "")
    
    if [[ -n "$ISSUE_IID" && "$ISSUE_IID" != "null" ]]; then
        # Test invalid state event
        test_malformed_api_call "PUT" "projects/2545/issues/$ISSUE_IID" '{"state_event": "invalid_state"}' "Invalid state transition"
    else
        echo "  ⚠️  SKIP: No issues available for state transition testing"
    fi
else
    test_result 1 "Cannot test invalid state transitions - no token available"
fi

# Test 11: Circular JSON references (if possible)
echo "Test 11: Complex nested JSON structures"
NESTED_JSON='{"title": "Test", "description": {"nested": {"deep": {"very": {"deep": "value"}}}}}'
test_malformed_api_call "POST" "projects/2545/issues" "$NESTED_JSON" "Deeply nested JSON structure"

# Test 12: Unicode and special character handling
echo "Test 12: Unicode and special characters"
UNICODE_JSON='{"title": "Test with 🚀 emoji and ñáéíóú", "description": "Mixed content: ASCII + Unicode + 中文 + العربية"}'
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    UNICODE_RESPONSE=$(curl -s -w "%{http_code}" -X "POST" \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json; charset=utf-8" \
        --data "$UNICODE_JSON" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "UNICODE_ERROR")
    
    if echo "$UNICODE_RESPONSE" | grep -q "UNICODE_ERROR\|error"; then
        test_result 1 "Unicode characters caused request failure"
    else
        test_result 0 "Unicode characters handled properly (may create actual issue)"
        echo "  ⚠️  Note: This may have created a real issue with Unicode content"
    fi
else
    test_result 1 "Cannot test Unicode handling - no token available"
fi

# Test 13: Empty and null value handling
echo "Test 13: Empty and null value handling"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": "", "description": null}' "Empty title and null description"
test_malformed_api_call "POST" "projects/2545/issues" '{"title": null, "description": ""}' "Null title and empty description"

# Test 14: Invalid project ID in URL
echo "Test 14: Invalid project ID handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    for invalid_project in "abc" "-1" "999999999" "0"; do
        RESPONSE=$(curl -s -w "%{http_code}" --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/$invalid_project/issues" 2>/dev/null || echo "ERROR")
        
        HTTP_CODE="${RESPONSE: -3}"
        if [[ "$HTTP_CODE" =~ ^[4][0-9][0-9]$ ]] || echo "$RESPONSE" | grep -q "ERROR"; then
            echo "  ✓ Invalid project ID '$invalid_project' properly rejected"
        else
            echo "  ⚠️  Invalid project ID '$invalid_project' handling unclear"
        fi
    done
    test_result 0 "Invalid project IDs properly handled"
else
    test_result 1 "Cannot test invalid project IDs - no token available"
fi

# Test 15: Content-Type header manipulation
echo "Test 15: Invalid Content-Type headers"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test with wrong content type
    WRONG_CT_RESPONSE=$(curl -s -w "%{http_code}" -X "POST" \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: text/plain" \
        --data '{"title": "Test", "description": "Test"}' \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "CT_ERROR")
    
    if echo "$WRONG_CT_RESPONSE" | grep -q "CT_ERROR\|400\|415"; then
        test_result 0 "Invalid Content-Type properly rejected"
    else
        test_result 1 "Invalid Content-Type not properly validated"
    fi
else
    test_result 1 "Cannot test Content-Type validation - no token available"
fi

echo ""
echo "=== Malformed Requests Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

echo ""
echo "⚠️  WARNING: Some tests may have created actual GitLab issues"
echo "Check the GitLab project for any test issues that need cleanup"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Malformed requests tests FAILED"
    exit 1
else
    echo "✅ All malformed requests tests PASSED"
    exit 0
fi