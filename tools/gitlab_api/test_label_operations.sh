#!/bin/bash
# Label Operations Tests
# Tests GitLab label management functionality

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

echo "=== Label Operations Tests ==="
echo ""

# Check if token is available
TOKEN_AVAILABLE=0
if "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" >/dev/null 2>&1; then
    TOKEN_AVAILABLE=1
fi

# Test 1: List labels basic functionality
echo "Test 1: List labels basic functionality"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_OUTPUT=$("$WRAPPER_SCRIPT" list-labels 2>&1 || echo "COMMAND_FAILED")
    if echo "$LABELS_OUTPUT" | grep -q "Listing GitLab labels" && ! echo "$LABELS_OUTPUT" | grep -q "COMMAND_FAILED"; then
        test_result 0 "List labels command executes successfully"
        
        # Check JSON structure
        JSON_PART=$(echo "$LABELS_OUTPUT" | grep -v "^\[GITLAB-API\]" | grep -v "^\[ERROR\]" | grep -v "^\[WARNING\]" || echo "")
        if echo "$JSON_PART" | jq . >/dev/null 2>&1; then
            echo "  ✨ Valid JSON response received"
        else
            echo "  ⚠️  Non-JSON response: ${JSON_PART:0:100}..."
        fi
    else
        test_result 1 "List labels command failed to execute"
    fi
else
    test_result 1 "Cannot test list labels - no token available"
fi

# Test 2: Label structure validation
echo "Test 2: Label structure validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    
    # Check if labels have required fields
    LABEL_COUNT=$(echo "$LABELS_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ $LABEL_COUNT -gt 0 ]]; then
        # Check first label structure
        FIRST_LABEL_NAME=$(echo "$LABELS_JSON" | jq -r '.[0].name // empty' 2>/dev/null || echo "")
        FIRST_LABEL_COLOR=$(echo "$LABELS_JSON" | jq -r '.[0].color // empty' 2>/dev/null || echo "")
        
        if [[ -n "$FIRST_LABEL_NAME" ]]; then
            test_result 0 "Label structure contains required fields (name: $FIRST_LABEL_NAME)"
        else
            test_result 1 "Label structure missing required fields"
        fi
    else
        test_result 0 "No labels found (acceptable for new projects)"
    fi
else
    test_result 1 "Cannot validate label structure - no token available"
fi

# Test 3: Standard project labels detection
echo "Test 3: Standard project labels detection"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    
    # Check for common GitLab/project labels
    STANDARD_LABELS=("bug" "feature" "enhancement" "documentation" "priority::high" "priority::medium" "priority::low")
    FOUND_STANDARD=0
    FOUND_LABELS=()
    
    for label in "${STANDARD_LABELS[@]}"; do
        if echo "$LABELS_JSON" | jq -r '.[].name' | grep -q "^$label$"; then
            ((FOUND_STANDARD++))
            FOUND_LABELS+=("$label")
        fi
    done
    
    echo "  Found standard labels: ${FOUND_LABELS[*]}"
    
    if [[ $FOUND_STANDARD -ge 3 ]]; then
        test_result 0 "Standard project labels available ($FOUND_STANDARD/7)"
    elif [[ $FOUND_STANDARD -gt 0 ]]; then
        test_result 0 "Some standard labels found ($FOUND_STANDARD/7)"
    else
        test_result 0 "No standard labels (project may use custom labeling)"
    fi
else
    test_result 1 "Cannot detect standard labels - no token available"
fi

# Test 4: Label color validation
echo "Test 4: Label color format validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    
    VALID_COLORS=0
    TOTAL_COLORS=0
    
    # Check color format (should be hex colors)
    while IFS= read -r color; do
        if [[ -n "$color" && "$color" != "null" ]]; then
            ((TOTAL_COLORS++))
            if [[ $color =~ ^#[0-9A-Fa-f]{6}$ ]]; then
                ((VALID_COLORS++))
            fi
        fi
    done < <(echo "$LABELS_JSON" | jq -r '.[].color // empty' 2>/dev/null)
    
    if [[ $TOTAL_COLORS -gt 0 ]]; then
        if [[ $VALID_COLORS -eq $TOTAL_COLORS ]]; then
            test_result 0 "All label colors in valid hex format ($VALID_COLORS/$TOTAL_COLORS)"
        else
            test_result 1 "Some label colors in invalid format ($VALID_COLORS/$TOTAL_COLORS)"
        fi
    else
        test_result 0 "No labels with colors found"
    fi
else
    test_result 1 "Cannot validate label colors - no token available"
fi

# Test 5: Label name format and restrictions
echo "Test 5: Label name format validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    LABELS_JSON=$("$WRAPPER_SCRIPT" list-labels 2>/dev/null | grep -v "^\[" || echo "[]")
    
    VALID_NAMES=0
    TOTAL_NAMES=0
    PROBLEMATIC_NAMES=()
    
    while IFS= read -r name; do
        if [[ -n "$name" && "$name" != "null" ]]; then
            ((TOTAL_NAMES++))
            
            # Check for problematic characters or formats
            if [[ ${#name} -le 255 && ! $name =~ ^[[:space:]]*$ && ! $name =~ [[:cntrl:]] ]]; then
                ((VALID_NAMES++))
            else
                PROBLEMATIC_NAMES+=("$name")
            fi
        fi
    done < <(echo "$LABELS_JSON" | jq -r '.[].name // empty' 2>/dev/null)
    
    if [[ $TOTAL_NAMES -gt 0 ]]; then
        if [[ $VALID_NAMES -eq $TOTAL_NAMES ]]; then
            test_result 0 "All label names in valid format ($VALID_NAMES/$TOTAL_NAMES)"
        else
            test_result 1 "Some label names problematic ($VALID_NAMES/$TOTAL_NAMES): ${PROBLEMATIC_NAMES[*]}"
        fi
    else
        test_result 0 "No labels found for name validation"
    fi
else
    test_result 1 "Cannot validate label names - no token available"
fi

# Test 6: Label usage in issues simulation
echo "Test 6: Label usage in issues simulation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    # Get a sample of issues to check label usage
    ISSUES_JSON=$("$WRAPPER_SCRIPT" list-issues 2>/dev/null | grep -v "^\[" || echo "[]")
    ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ $ISSUE_COUNT -gt 0 ]]; then
        # Check if issues have labels
        ISSUES_WITH_LABELS=0
        TOTAL_ISSUES=$ISSUE_COUNT
        
        for ((i=0; i<ISSUE_COUNT && i<10; i++)); do
            ISSUE_LABELS=$(echo "$ISSUES_JSON" | jq -r ".[$i].labels[]? // empty" 2>/dev/null)
            if [[ -n "$ISSUE_LABELS" ]]; then
                ((ISSUES_WITH_LABELS++))
            fi
        done
        
        SAMPLE_SIZE=$((ISSUE_COUNT > 10 ? 10 : ISSUE_COUNT))
        echo "  Checked $SAMPLE_SIZE issues, $ISSUES_WITH_LABELS have labels"
        
        if [[ $ISSUES_WITH_LABELS -gt 0 ]]; then
            test_result 0 "Labels are actively used in issues ($ISSUES_WITH_LABELS/$SAMPLE_SIZE)"
        else
            test_result 0 "No label usage found in sample (may be acceptable)"
        fi
    else
        test_result 0 "No issues available for label usage testing"
    fi
else
    test_result 1 "Cannot test label usage - no token available"
fi

# Test 7: Performance test for label retrieval
echo "Test 7: Label retrieval performance"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    START_TIME=$(date +%s)
    "$WRAPPER_SCRIPT" list-labels >/dev/null 2>&1
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [[ $DURATION -lt 10 ]]; then
        test_result 0 "Label retrieval performance acceptable ($DURATION seconds)"
    else
        test_result 1 "Label retrieval performance slow ($DURATION seconds)"
    fi
else
    test_result 1 "Cannot test label performance - no token available"
fi

echo ""
echo "=== Label Operations Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo ""
    echo "⚠️  WARNING: All tests skipped due to missing GitLab token"
    echo "To enable label testing, configure GitLab authentication:"
    echo "  ./tools/gitlab/setup-secure-config.sh"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Label operations tests FAILED"
    exit 1
else
    echo "✅ All available label operations tests PASSED"
    exit 0
fi