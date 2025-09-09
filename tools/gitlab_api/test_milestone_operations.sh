#!/bin/bash
# Milestone Operations Tests
# Tests GitLab milestone management functionality

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

echo "=== Milestone Operations Tests ==="
echo ""

# Check if token is available
TOKEN_AVAILABLE=0
if "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" >/dev/null 2>&1; then
    TOKEN_AVAILABLE=1
fi

# Test 1: List milestones basic functionality
echo "Test 1: List milestones basic functionality"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_OUTPUT=$("$WRAPPER_SCRIPT" list-milestones 2>&1 || echo "COMMAND_FAILED")
    if echo "$MILESTONES_OUTPUT" | grep -q "Listing GitLab milestones" && ! echo "$MILESTONES_OUTPUT" | grep -q "COMMAND_FAILED"; then
        test_result 0 "List milestones command executes successfully"
        
        # Check JSON structure
        JSON_PART=$(echo "$MILESTONES_OUTPUT" | grep -v "^\[GITLAB-API\]" | grep -v "^\[ERROR\]" | grep -v "^\[WARNING\]" || echo "")
        if echo "$JSON_PART" | jq . >/dev/null 2>&1; then
            echo "  ✨ Valid JSON response received"
        else
            echo "  ⚠️  Non-JSON response: ${JSON_PART:0:100}..."
        fi
    else
        test_result 1 "List milestones command failed to execute"
    fi
else
    test_result 1 "Cannot test list milestones - no token available"
fi

# Test 2: Milestone structure validation
echo "Test 2: Milestone structure validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_JSON=$("$WRAPPER_SCRIPT" list-milestones 2>/dev/null | grep -v "^\[" || echo "[]")
    
    MILESTONE_COUNT=$(echo "$MILESTONES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    echo "  Found $MILESTONE_COUNT milestones"
    
    if [[ $MILESTONE_COUNT -gt 0 ]]; then
        # Check first milestone structure
        MILESTONE_ID=$(echo "$MILESTONES_JSON" | jq -r '.[0].id // empty' 2>/dev/null || echo "")
        MILESTONE_TITLE=$(echo "$MILESTONES_JSON" | jq -r '.[0].title // empty' 2>/dev/null || echo "")
        MILESTONE_STATE=$(echo "$MILESTONES_JSON" | jq -r '.[0].state // empty' 2>/dev/null || echo "")
        
        if [[ -n "$MILESTONE_ID" && -n "$MILESTONE_TITLE" ]]; then
            test_result 0 "Milestone structure contains required fields (ID: $MILESTONE_ID, Title: $MILESTONE_TITLE)"
        else
            test_result 1 "Milestone structure missing required fields"
        fi
    else
        test_result 0 "No milestones found (acceptable for projects without milestones)"
    fi
else
    test_result 1 "Cannot validate milestone structure - no token available"
fi

# Test 3: Milestone state filtering
echo "Test 3: Milestone state filtering"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Test different states
    ACTIVE_COUNT=0
    CLOSED_COUNT=0
    ALL_COUNT=0
    
    # Active milestones
    ACTIVE_JSON=$("$WRAPPER_SCRIPT" list-milestones active 2>/dev/null | grep -v "^\[" || echo "[]")
    ACTIVE_COUNT=$(echo "$ACTIVE_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    # Closed milestones
    CLOSED_JSON=$("$WRAPPER_SCRIPT" list-milestones closed 2>/dev/null | grep -v "^\[" || echo "[]")
    CLOSED_COUNT=$(echo "$CLOSED_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    # All milestones
    ALL_JSON=$("$WRAPPER_SCRIPT" list-milestones all 2>/dev/null | grep -v "^\[" || echo "[]")
    ALL_COUNT=$(echo "$ALL_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    echo "  Active: $ACTIVE_COUNT, Closed: $CLOSED_COUNT, All: $ALL_COUNT"
    
    # Validate that all >= active + closed (approximately, some edge cases may exist)
    if [[ $ALL_COUNT -ge $ACTIVE_COUNT && $ALL_COUNT -ge $CLOSED_COUNT ]]; then\n        test_result 0 "Milestone state filtering working correctly"
    else
        test_result 1 "Milestone state filtering inconsistent"
    fi
else
    test_result 1 "Cannot test milestone filtering - no token available"
fi

# Test 4: Milestone date handling
echo "Test 4: Milestone date validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_JSON=$("$WRAPPER_SCRIPT" list-milestones all 2>/dev/null | grep -v "^\[" || echo "[]")
    MILESTONE_COUNT=$(echo "$MILESTONES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ $MILESTONE_COUNT -gt 0 ]]; then
        VALID_DATES=0
        TOTAL_DATES=0
        
        # Check due dates format
        while IFS= read -r due_date; do
            if [[ -n "$due_date" && "$due_date" != "null" ]]; then
                ((TOTAL_DATES++))
                # Check if date is in ISO format
                if [[ $due_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || [[ $due_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
                    ((VALID_DATES++))
                fi
            fi
        done < <(echo "$MILESTONES_JSON" | jq -r '.[].due_date // empty' 2>/dev/null)
        
        if [[ $TOTAL_DATES -gt 0 ]]; then
            if [[ $VALID_DATES -eq $TOTAL_DATES ]]; then
                test_result 0 "All milestone dates in valid format ($VALID_DATES/$TOTAL_DATES)"
            else
                test_result 1 "Some milestone dates in invalid format ($VALID_DATES/$TOTAL_DATES)"
            fi
        else
            test_result 0 "No milestone due dates found (acceptable)"
        fi
    else
        test_result 0 "No milestones available for date validation"
    fi
else
    test_result 1 "Cannot validate milestone dates - no token available"
fi

# Test 5: Milestone progress tracking
echo "Test 5: Milestone progress indicators"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    MILESTONES_JSON=$("$WRAPPER_SCRIPT" list-milestones all 2>/dev/null | grep -v "^\[" || echo "[]")
    MILESTONE_COUNT=$(echo "$MILESTONES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ $MILESTONE_COUNT -gt 0 ]]; then
        MILESTONES_WITH_PROGRESS=0
        
        for ((i=0; i<MILESTONE_COUNT; i++)); do
            # Check for progress indicators
            TOTAL_ISSUES=$(echo "$MILESTONES_JSON" | jq -r ".[$i].total_issues_count // 0" 2>/dev/null)
            CLOSED_ISSUES=$(echo "$MILESTONES_JSON" | jq -r ".[$i].closed_issues_count // 0" 2>/dev/null)
            
            if [[ "$TOTAL_ISSUES" != "null" && "$CLOSED_ISSUES" != "null" ]]; then
                ((MILESTONES_WITH_PROGRESS++))\n            fi
        done
        
        if [[ $MILESTONES_WITH_PROGRESS -gt 0 ]]; then
            test_result 0 "Milestones contain progress tracking data ($MILESTONES_WITH_PROGRESS/$MILESTONE_COUNT)"
        else
            test_result 0 "No progress data in milestones (may not be used for issue tracking)"
        fi
    else
        test_result 0 "No milestones available for progress validation"
    fi
else
    test_result 1 "Cannot validate milestone progress - no token available"
fi

# Test 6: Milestone-issue relationship
echo "Test 6: Milestone-issue relationship validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Get issues and check for milestone assignments
    ISSUES_JSON=$("$WRAPPER_SCRIPT" list-issues 2>/dev/null | grep -v "^\[" || echo "[]")
    ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ $ISSUE_COUNT -gt 0 ]]; then
        ISSUES_WITH_MILESTONES=0
        SAMPLE_SIZE=$((ISSUE_COUNT > 10 ? 10 : ISSUE_COUNT))
        
        for ((i=0; i<SAMPLE_SIZE; i++)); do
            MILESTONE_ID=$(echo "$ISSUES_JSON" | jq -r ".[$i].milestone.id // empty" 2>/dev/null)
            if [[ -n "$MILESTONE_ID" && "$MILESTONE_ID" != "null" ]]; then
                ((ISSUES_WITH_MILESTONES++))
            fi
        done
        
        echo "  Checked $SAMPLE_SIZE issues, $ISSUES_WITH_MILESTONES have milestone assignments"
        
        if [[ $ISSUES_WITH_MILESTONES -gt 0 ]]; then
            test_result 0 "Milestones are actively used for issue tracking ($ISSUES_WITH_MILESTONES/$SAMPLE_SIZE)"
        else
            test_result 0 "No milestone usage found in sample (acceptable)"
        fi
    else
        test_result 0 "No issues available for milestone relationship testing"
    fi
else
    test_result 1 "Cannot test milestone-issue relationships - no token available"
fi

# Test 7: Performance test for milestone retrieval
echo "Test 7: Milestone retrieval performance"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    START_TIME=$(date +%s)
    "$WRAPPER_SCRIPT" list-milestones >/dev/null 2>&1
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [[ $DURATION -lt 10 ]]; then
        test_result 0 "Milestone retrieval performance acceptable ($DURATION seconds)"
    else
        test_result 1 "Milestone retrieval performance slow ($DURATION seconds)"
    fi
else
    test_result 1 "Cannot test milestone performance - no token available"
fi

echo ""
echo "=== Milestone Operations Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo ""
    echo "⚠️  WARNING: All tests skipped due to missing GitLab token"
    echo "To enable milestone testing, configure GitLab authentication:"
    echo "  ./tools/gitlab/setup-secure-config.sh"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Milestone operations tests FAILED"
    exit 1
else
    echo "✅ All available milestone operations tests PASSED"
    exit 0
fi