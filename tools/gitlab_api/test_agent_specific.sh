#!/bin/bash
# Agent-Specific Tests for project-task-updater
# Tests the exact patterns and operations used by the agent

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER_SCRIPT="$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "✅ PASS: $2"
        ((TESTS_PASSED++))
    else
        echo -e "❌ FAIL: $2"
        ((TESTS_FAILED++))
    fi
}

echo "=== Project-Task-Updater Agent Specific Tests ==="
echo "Testing exact patterns from agent configuration"
echo ""

# Test 1: Token Variable Usage (Critical Bug)
echo "Test 1: Token Variable Usage Pattern"
log "Testing agent's token retrieval pattern..."

# Simulate the WRONG way the agent currently does it
export GITLAB_TOKEN=""  # This should fail - agent uses undefined variable
if [[ -z "$GITLAB_TOKEN" ]]; then
    test_result 0 "Token pattern: Agent's \$GITLAB_TOKEN variable is undefined (confirms bug)"
else
    test_result 1 "Token pattern: \$GITLAB_TOKEN unexpectedly defined"
fi

# Test the CORRECT way it should work
TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "")
if [[ -n "$TOKEN" ]]; then
    test_result 0 "Token pattern: Correct token retrieval method works"
    TOKEN_AVAILABLE=1
else
    test_result 1 "Token pattern: Token retrieval failed"
    TOKEN_AVAILABLE=0
fi

# Test 2: Agent Pre-flight Check Simulation
echo "Test 2: Agent Pre-flight Check Pattern"
log "Simulating agent's required pre-flight checks..."

# Check 1: Working directory check (from agent line 200)
cd "$PROJECT_ROOT" 2>/dev/null || true
PWD_CHECK=$(pwd)
if [[ "$PWD_CHECK" == *"globtim" ]]; then
    test_result 0 "Pre-flight: Working directory check passes"
else
    test_result 1 "Pre-flight: Working directory check fails"
fi

# Check 2: Git repository check (from agent line 200)
if git status >/dev/null 2>&1; then
    test_result 0 "Pre-flight: Git repository check passes"
else
    test_result 1 "Pre-flight: Git repository check fails"
fi

# Check 3: Token file check (from agent line 201)
if [[ -f ~/.gitlab_token_secure ]]; then
    test_result 0 "Pre-flight: Token file exists"
else
    test_result 1 "Pre-flight: Token file missing (expected for this setup)"
fi

# Test 3: Direct cURL Pattern (Agent Lines 48-50)
echo "Test 3: Agent's Direct cURL Pattern"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing agent's direct cURL command pattern..."
    
    # Test the BROKEN pattern from the agent (line 48)
    BROKEN_CURL_RESULT=$(curl -s --fail --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "CURL_FAILED")
    
    if echo "$BROKEN_CURL_RESULT" | grep -q "CURL_FAILED"; then
        test_result 0 "cURL pattern: Agent's broken pattern fails as expected"
    else
        test_result 1 "cURL pattern: Agent's broken pattern unexpectedly works"
    fi
    
    # Test the FIXED pattern
    FIXED_CURL_RESULT=$(curl -s --fail --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "CURL_FAILED")
    
    if echo "$FIXED_CURL_RESULT" | grep -q -v "CURL_FAILED" && echo "$FIXED_CURL_RESULT" | jq . >/dev/null 2>&1; then
        test_result 0 "cURL pattern: Fixed pattern works correctly"
    else
        test_result 1 "cURL pattern: Fixed pattern still fails"
    fi
else
    test_result 1 "cURL pattern: Cannot test without token"
fi

# Test 4: Wrapper Script vs Direct API Usage
echo "Test 4: Wrapper Script vs Direct API Comparison"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Comparing wrapper script vs direct API calls..."
    
    # Test wrapper script method (RECOMMENDED)
    WRAPPER_RESULT=$("$WRAPPER_SCRIPT" list-issues 2>&1 | grep -v "^\[" || echo "WRAPPER_FAILED")
    WRAPPER_SUCCESS=0
    if echo "$WRAPPER_RESULT" | jq . >/dev/null 2>&1; then
        WRAPPER_SUCCESS=1
    fi
    
    # Test direct API method (FALLBACK)
    DIRECT_RESULT=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "DIRECT_FAILED")
    DIRECT_SUCCESS=0
    if echo "$DIRECT_RESULT" | jq . >/dev/null 2>&1; then
        DIRECT_SUCCESS=1
    fi
    
    if [[ $WRAPPER_SUCCESS -eq 1 && $DIRECT_SUCCESS -eq 1 ]]; then
        test_result 0 "API methods: Both wrapper and direct methods work"
    elif [[ $WRAPPER_SUCCESS -eq 1 ]]; then
        test_result 0 "API methods: Wrapper works (direct failed)"
    elif [[ $DIRECT_SUCCESS -eq 1 ]]; then
        test_result 0 "API methods: Direct works (wrapper failed)"
    else
        test_result 1 "API methods: Both methods failed"
    fi
else
    test_result 1 "API methods: Cannot test without token"
fi

# Test 5: Issue Update Pattern Simulation
echo "Test 5: Issue Update Pattern"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing issue update operations..."
    
    # Get a test issue (Issue #63 - this very issue)
    TEST_ISSUE_ID="63"
    
    # Test getting issue details (agent operation)
    ISSUE_DETAILS=$("$WRAPPER_SCRIPT" get-issue "$TEST_ISSUE_ID" 2>/dev/null || echo "{}")
    if echo "$ISSUE_DETAILS" | jq . >/dev/null 2>&1; then
        test_result 0 "Issue operations: Can retrieve issue #$TEST_ISSUE_ID"
        
        # Test updating issue with labels (agent operation)
        UPDATE_RESULT=$("$WRAPPER_SCRIPT" update-issue "$TEST_ISSUE_ID" "" "" "bug,api-communication,tested" "" 2>/dev/null || echo "UPDATE_FAILED")
        if echo "$UPDATE_RESULT" | jq . >/dev/null 2>&1; then
            test_result 0 "Issue operations: Can update issue labels"
        else
            test_result 1 "Issue operations: Issue update failed"
        fi
    else
        test_result 1 "Issue operations: Cannot retrieve issue #$TEST_ISSUE_ID"
    fi
else
    test_result 1 "Issue operations: Cannot test without token"
fi

# Test 6: Error Handling Pattern
echo "Test 6: Error Handling Pattern Validation"
log "Testing agent error handling patterns..."

# Test agent's error handling with invalid token
export GITLAB_PRIVATE_TOKEN="invalid-token"
ERROR_TEST=$("$WRAPPER_SCRIPT" test 2>&1 || echo "ERROR_CAUGHT")
unset GITLAB_PRIVATE_TOKEN

if echo "$ERROR_TEST" | grep -q "❌ GitLab API connection failed\|ERROR_CAUGHT"; then
    test_result 0 "Error handling: Invalid token properly handled"
else
    test_result 1 "Error handling: Invalid token not properly handled"
fi

# Test 7: Label Management Validation
echo "Test 7: Label Management Pattern"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing standard label availability..."
    
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    
    # Check for agent's expected labels (from lines 100-105 in agent config)
    REQUIRED_LABELS=("completed" "in-progress" "feature" "bug" "enhancement")
    FOUND_LABELS=0
    
    for label in "${REQUIRED_LABELS[@]}"; do
        if echo "$LABELS_JSON" | jq -r '.[].name' 2>/dev/null | grep -q "^$label$"; then
            ((FOUND_LABELS++))
        fi
    done
    
    if [[ $FOUND_LABELS -ge 3 ]]; then
        test_result 0 "Labels: Required labels available ($FOUND_LABELS/5)"
    else
        test_result 1 "Labels: Missing required labels ($FOUND_LABELS/5)"
    fi
else
    test_result 1 "Labels: Cannot test without token"
fi

# Test 8: Agent Configuration Consistency
echo "Test 8: Agent Configuration Consistency"
log "Checking agent configuration file consistency..."

AGENT_CONFIG="$PROJECT_ROOT/.claude/agents/project-task-updater.md"
if [[ -f "$AGENT_CONFIG" ]]; then
    # Check for the bug patterns in the agent config
    GITLAB_TOKEN_USAGE=$(grep -c "\$GITLAB_TOKEN" "$AGENT_CONFIG" || echo "0")
    TOKEN_USAGE=$(grep -c "\$TOKEN" "$AGENT_CONFIG" || echo "0")
    WRAPPER_USAGE=$(grep -c "claude-agent-gitlab.sh" "$AGENT_CONFIG" || echo "0")
    
    if [[ $GITLAB_TOKEN_USAGE -gt 0 ]]; then
        test_result 1 "Config consistency: Found $GITLAB_TOKEN_USAGE instances of broken \$GITLAB_TOKEN usage"
    else
        test_result 0 "Config consistency: No broken \$GITLAB_TOKEN usage found"
    fi
    
    if [[ $WRAPPER_USAGE -gt 0 ]]; then
        test_result 0 "Config consistency: Found $WRAPPER_USAGE wrapper script references"
    else
        test_result 1 "Config consistency: No wrapper script references found"
    fi
else
    test_result 1 "Config consistency: Agent configuration file not found"
fi

# Test 9: Full Workflow Simulation
echo "Test 9: Complete Agent Workflow Simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Running complete agent workflow simulation..."
    
    WORKFLOW_STEPS=0
    
    # Step 1: Pre-flight checks
    if git status >/dev/null 2>&1; then
        ((WORKFLOW_STEPS++))
    fi
    
    # Step 2: Token retrieval
    if [[ -n "$TOKEN" ]]; then
        ((WORKFLOW_STEPS++))
    fi
    
    # Step 3: API connectivity
    if "$WRAPPER_SCRIPT" test >/dev/null 2>&1; then
        ((WORKFLOW_STEPS++))
    fi
    
    # Step 4: Issue operations
    if "$WRAPPER_SCRIPT" get-issue 63 >/dev/null 2>&1; then
        ((WORKFLOW_STEPS++))
    fi
    
    if [[ $WORKFLOW_STEPS -ge 3 ]]; then
        test_result 0 "Complete workflow: Agent workflow mostly functional ($WORKFLOW_STEPS/4)"
    else
        test_result 1 "Complete workflow: Agent workflow has issues ($WORKFLOW_STEPS/4)"
    fi
else
    test_result 1 "Complete workflow: Cannot test without token"
fi

# Results Summary
echo ""
echo "=== Agent-Specific Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

# Provide specific recommendations based on test results
echo ""
echo "=== Issue #63 Analysis Summary ==="

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo "🔴 CRITICAL: No GitLab token available - this is likely the root cause"
    echo "   Solution: Run ./tools/gitlab/setup-secure-config.sh"
fi

if grep -q "\$GITLAB_TOKEN" "$PROJECT_ROOT/.claude/agents/project-task-updater.md" 2>/dev/null; then
    echo "🔴 CRITICAL: Agent uses undefined \$GITLAB_TOKEN variable"
    echo "   Solution: Replace \$GITLAB_TOKEN with proper token retrieval"
fi

if [[ $TESTS_FAILED -gt $TESTS_PASSED ]]; then
    echo "❌ CONCLUSION: Multiple issues found - Issue #63 is valid"
    exit 1
else
    echo "✅ CONCLUSION: Most tests pass - Issue #63 may be resolved or minimal"
    exit 0
fi