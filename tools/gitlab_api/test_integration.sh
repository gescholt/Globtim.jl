#!/bin/bash
# Integration Tests - Project Task Updater Simulation
# Simulates the specific GitLab operations used by project-task-updater agent

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

# Check if token is available
check_token_available() {
    if ! "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

echo "=== Project Task Updater Integration Tests ==="
echo "Simulating specific operations used by project-task-updater agent"
echo ""

TOKEN_AVAILABLE=0
if check_token_available; then
    TOKEN_AVAILABLE=1
    echo "✓ GitLab token available - full integration testing enabled"
else
    echo "⚠️  GitLab token unavailable - testing simulation mode only"
fi
echo ""

# Test 1: Agent pre-flight checks (as per agent specification)
echo "Test 1: Agent pre-flight checks simulation"
PREFLIGHT_PASSED=0

# Check 1: Verify working directory
if [[ -d "$PROJECT_ROOT/.git" ]]; then
    echo "  ✓ Git repository detected"
    ((PREFLIGHT_PASSED++))
else
    echo "  ❌ Not in git repository"
fi

# Check 2: Check token existence
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    echo "  ✓ GitLab token available"
    ((PREFLIGHT_PASSED++))
else
    echo "  ⚠️  GitLab token not available"
fi

# Check 3: Test API connectivity
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    CONNECTIVITY_TEST=$("$WRAPPER_SCRIPT" test 2>&1 || echo "FAILED")
    if echo "$CONNECTIVITY_TEST" | grep -q "✅ GitLab API connection successful"; then
        echo "  ✓ GitLab API connectivity confirmed"
        ((PREFLIGHT_PASSED++))
    else
        echo "  ⚠️  GitLab API connectivity issues"
    fi
else
    echo "  ⚠️  Cannot test API connectivity without token"
fi

if [[ $PREFLIGHT_PASSED -ge 2 ]]; then
    test_result 0 "Agent pre-flight checks mostly successful ($PREFLIGHT_PASSED/3)"
else
    test_result 1 "Agent pre-flight checks failed ($PREFLIGHT_PASSED/3)"
fi

# Test 2: Feature completion workflow simulation
echo "Test 2: Feature completion workflow simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Step 1: List open issues to find one to work with
    OPEN_ISSUES=$("$WRAPPER_SCRIPT" list-issues opened 2>/dev/null | grep -v "^\[" || echo "[]")
    ISSUE_COUNT=$(echo "$OPEN_ISSUES" | jq '. | length' 2>/dev/null || echo "0")
    
    echo "  Found $ISSUE_COUNT open issues"
    
    if [[ $ISSUE_COUNT -gt 0 ]]; then
        # Get first issue for testing
        ISSUE_IID=$(echo "$OPEN_ISSUES" | jq -r '.[0].iid' 2>/dev/null || echo "")
        ISSUE_TITLE=$(echo "$OPEN_ISSUES" | jq -r '.[0].title' 2>/dev/null || echo "Unknown")
        
        echo "  Testing with issue #$ISSUE_IID: $ISSUE_TITLE"
        
        # Step 2: Get issue details (typical agent operation)
        ISSUE_DETAILS=$("$WRAPPER_SCRIPT" get-issue "$ISSUE_IID" 2>/dev/null || echo "{}")
        if echo "$ISSUE_DETAILS" | jq . >/dev/null 2>&1; then
            test_result 0 "Feature workflow: Issue retrieval successful"
        else
            test_result 1 "Feature workflow: Issue retrieval failed"
        fi
    else
        echo "  ⚠️  No open issues available for workflow testing"
        test_result 1 "Feature workflow: No test issues available"
    fi
else
    test_result 1 "Feature workflow: Cannot test without token"
fi

# Test 3: Label management simulation
echo "Test 3: Label management simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Get available labels (agent needs this for validation)
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    LABEL_COUNT=$(echo "$LABELS_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    echo "  Found $LABEL_COUNT project labels"
    
    # Check for standard labels that agent expects
    STANDARD_LABELS=("feature" "bug" "enhancement" "completed" "in-progress")
    FOUND_STANDARD=0
    
    for label in "${STANDARD_LABELS[@]}"; do
        if echo "$LABELS_JSON" | jq -r '.[].name' | grep -q "^$label$"; then
            ((FOUND_STANDARD++))
        fi
    done
    
    if [[ $FOUND_STANDARD -ge 3 ]]; then
        test_result 0 "Label management: Standard labels available ($FOUND_STANDARD/5)"
    else
        test_result 1 "Label management: Missing standard labels ($FOUND_STANDARD/5)"
    fi
else
    test_result 1 "Label management: Cannot test without token"
fi

# Test 4: Milestone tracking simulation
echo "Test 4: Milestone tracking simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_JSON=$("$WRAPPER_SCRIPT" list-milestones 2>/dev/null | grep -v "^\[" || echo "[]")
    MILESTONE_COUNT=$(echo "$MILESTONES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    echo "  Found $MILESTONE_COUNT active milestones"
    
    if [[ $MILESTONE_COUNT -gt 0 ]]; then
        # Check if milestones have proper structure
        MILESTONE_ID=$(echo "$MILESTONES_JSON" | jq -r '.[0].id' 2>/dev/null || echo "")
        MILESTONE_TITLE=$(echo "$MILESTONES_JSON" | jq -r '.[0].title' 2>/dev/null || echo "")
        
        if [[ -n "$MILESTONE_ID" && "$MILESTONE_ID" != "null" ]]; then
            test_result 0 "Milestone tracking: Milestones accessible with proper structure"
        else
            test_result 1 "Milestone tracking: Milestone structure invalid"
        fi
    else
        test_result 0 "Milestone tracking: No active milestones (acceptable)"
    fi
else
    test_result 1 "Milestone tracking: Cannot test without token"
fi

# Test 5: Error handling workflow
echo "Test 5: Error handling workflow simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Test agent error handling patterns
    
    # Scenario 1: Invalid issue ID
    INVALID_ISSUE=$("$WRAPPER_SCRIPT" get-issue 999999 2>&1 || echo "ERROR_CAUGHT")
    if echo "$INVALID_ISSUE" | grep -q "ERROR_CAUGHT\|404\|not found"; then
        echo "  ✓ Invalid issue ID properly handled"
        ERROR_HANDLING_SCORE=1
    else
        echo "  ❌ Invalid issue ID handling unclear"
        ERROR_HANDLING_SCORE=0
    fi
    
    # Scenario 2: API timeout simulation (short timeout)
    timeout 5 "$WRAPPER_SCRIPT" list-issues >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo "  ✓ API responds within reasonable timeout"
        ((ERROR_HANDLING_SCORE++))
    else
        echo "  ⚠️  API response slow or timeout"
    fi
    
    if [[ $ERROR_HANDLING_SCORE -ge 1 ]]; then
        test_result 0 "Error handling: Basic error scenarios handled properly"
    else
        test_result 1 "Error handling: Issues with error handling"
    fi
else
    test_result 1 "Error handling: Cannot test without token"
fi

# Test 6: JSON parsing reliability (critical for agent)
echo "Test 6: JSON parsing reliability"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Test various JSON parsing scenarios
    PARSING_FAILURES=0
    
    # Test 1: Issues JSON
    ISSUES_JSON=$("$WRAPPER_SCRIPT" list-issues 2>/dev/null | grep -v "^\[" || echo "[]")
    if ! echo "$ISSUES_JSON" | jq . >/dev/null 2>&1; then
        echo "  ❌ Issues JSON parsing failed"
        ((PARSING_FAILURES++))
    fi
    
    # Test 2: Labels JSON
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    if ! echo "$LABELS_JSON" | jq . >/dev/null 2>&1; then
        echo "  ❌ Labels JSON parsing failed"
        ((PARSING_FAILURES++))
    fi
    
    # Test 3: Milestones JSON
    MILESTONES_JSON=$("$WRAPPER_SCRIPT" list-milestones 2>/dev/null | grep -v "^\[" || echo "[]")
    if ! echo "$MILESTONES_JSON" | jq . >/dev/null 2>&1; then
        echo "  ❌ Milestones JSON parsing failed"
        ((PARSING_FAILURES++))
    fi
    
    if [[ $PARSING_FAILURES -eq 0 ]]; then
        test_result 0 "JSON parsing: All API responses produce valid JSON"
    else
        test_result 1 "JSON parsing: $PARSING_FAILURES JSON parsing failures detected"
    fi
else
    test_result 1 "JSON parsing: Cannot test without token"
fi

# Test 7: Agent authentication failure simulation
echo "Test 7: Authentication failure handling"
# Test what happens when token becomes invalid
export GITLAB_PRIVATE_TOKEN="invalid-token-for-testing"
AUTH_FAILURE_TEST=$("$WRAPPER_SCRIPT" test 2>&1 || echo "AUTH_FAILED")
unset GITLAB_PRIVATE_TOKEN

if echo "$AUTH_FAILURE_TEST" | grep -q "❌ GitLab API connection failed\|AUTH_FAILED"; then
    test_result 0 "Authentication failure: Properly detected and reported"
else
    test_result 1 "Authentication failure: Not properly handled"
fi

# Test 8: Agent communication protocol (logging and output format)
echo "Test 8: Agent communication protocol"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    PROTOCOL_TEST=$("$WRAPPER_SCRIPT" list-issues 2>&1 || echo "FAILED")
    
    PROTOCOL_SCORE=0
    
    # Check for proper logging prefixes
    if echo "$PROTOCOL_TEST" | grep -q "\[GITLAB-API\]"; then
        echo "  ✓ Proper logging prefixes present"
        ((PROTOCOL_SCORE++))
    fi
    
    # Check for structured output (JSON separate from logs)
    JSON_LINES=$(echo "$PROTOCOL_TEST" | grep -v "^\[" | wc -l | tr -d ' ')
    if [[ $JSON_LINES -gt 0 ]]; then
        echo "  ✓ Structured output with separate logs and data"
        ((PROTOCOL_SCORE++))
    fi
    
    # Check for error handling logs
    if echo "$PROTOCOL_TEST" | grep -E "\[ERROR\]|\[WARNING\]" >/dev/null 2>&1; then
        echo "  ✓ Error logging capabilities present"
        ((PROTOCOL_SCORE++))
    elif ! echo "$PROTOCOL_TEST" | grep -q "FAILED"; then
        echo "  ✓ No errors occurred (good)"
        ((PROTOCOL_SCORE++))
    fi
    
    if [[ $PROTOCOL_SCORE -ge 2 ]]; then
        test_result 0 "Communication protocol: Proper agent communication format"
    else
        test_result 1 "Communication protocol: Issues with agent communication"
    fi
else
    test_result 1 "Communication protocol: Cannot test without token"
fi

echo ""
echo "=== Integration Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo ""
    echo "⚠️  WARNING: Most integration tests skipped due to missing GitLab token"
    echo "This could be the root cause of project-task-updater agent failures!"
    echo ""
    echo "To fix GitLab API communication issues:"
    echo "1. Configure GitLab authentication: ./tools/gitlab/setup-secure-config.sh"
    echo "2. Verify token permissions on GitLab project"
    echo "3. Check network connectivity to git.mpi-cbg.de"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Integration tests FAILED - This likely explains project-task-updater issues"
    exit 1
else
    echo "✅ All available integration tests PASSED"
    exit 0
fi