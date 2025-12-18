#!/bin/bash
# Test: Experiment Tracking → GitLab Issue Sync
# Phase 1 Quick Win Implementation Tests

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_SKIPPED=0

function test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

function test_fail() {
    echo -e "${RED}✗${NC} $1"
    echo "  Expected: $2"
    echo "  Got: $3"
}

function test_skip() {
    echo -e "${GREEN}⊘${NC} $1"
    ((TESTS_SKIPPED++))
}

function run_test() {
    ((TESTS_RUN++))
}

echo "=== GitLab Sync Test Suite ==="
echo ""

# Test 1: Can we read experiment tracking JSON?
run_test
TRACKING_FILE="$REPO_ROOT/experiments/lv4d_campaign_2025/tracking/batch_20250928_094810.json"
if [[ -f "$TRACKING_FILE" ]]; then
    BATCH_ID=$(python3 -c "import json; print(json.load(open('$TRACKING_FILE'))['batch_id'])")
    if [[ "$BATCH_ID" == "batch_20250928_094810" ]]; then
        test_pass "Read batch_id from tracking JSON"
    else
        test_fail "Read batch_id from tracking JSON" "batch_20250928_094810" "$BATCH_ID"
    fi
else
    test_fail "Find tracking JSON file" "$TRACKING_FILE" "not found"
fi

# Test 2: Can we extract session count?
run_test
if [[ -f "$TRACKING_FILE" ]]; then
    SESSION_COUNT=$(python3 -c "import json; print(len(json.load(open('$TRACKING_FILE'))['sessions']))")
    if [[ "$SESSION_COUNT" -gt 0 ]]; then
        test_pass "Extract session count ($SESSION_COUNT sessions)"
    else
        test_fail "Extract session count" ">0" "$SESSION_COUNT"
    fi
fi

# Test 3: Can we find the GitLab wrapper?
run_test
GITLAB_WRAPPER="$REPO_ROOT/tools/gitlab/secure_gitlab_wrapper.py"
if [[ -f "$GITLAB_WRAPPER" ]]; then
    test_pass "Find GitLab API wrapper"
else
    test_fail "Find GitLab API wrapper" "$GITLAB_WRAPPER" "not found"
fi

# Test 4: Can we access GitLab API? (read-only test)
run_test
if [[ -f "$GITLAB_WRAPPER" ]]; then
    # Test using Python API directly
    ISSUE_COUNT=$(python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT')
from tools.gitlab.secure_gitlab_wrapper import SecureGitLabAPI
api = SecureGitLabAPI()
issues = api.list_issues()
print(len(issues))
" 2>/dev/null || echo "0")
    if [[ "$ISSUE_COUNT" -gt 0 ]]; then
        test_pass "Access GitLab API ($ISSUE_COUNT issues found)"
    else
        test_fail "Access GitLab API" ">0 issues" "$ISSUE_COUNT issues"
    fi
fi

# Test 5: Can we find the gitlab-security-hook.sh?
run_test
SECURITY_HOOK="$REPO_ROOT/tools/gitlab/gitlab-security-hook.sh"
if [[ -f "$SECURITY_HOOK" ]]; then
    test_pass "Find gitlab-security-hook.sh"
else
    test_fail "Find gitlab-security-hook.sh" "$SECURITY_HOOK" "not found"
fi

# Test 6: Can we format experiment data for GitLab issue?
run_test
if [[ -f "$TRACKING_FILE" ]]; then
    # Extract experiment data and format as GitLab issue
    ISSUE_DATA=$(python3 -c "
import json
data = json.load(open('$TRACKING_FILE'))
title = f\"Experiment Batch: {data['batch_id']}\"
description = f'''## Batch Information
- Batch ID: {data['batch_id']}
- Start Time: {data['start_time']}
- Total Experiments: {data['total_experiments']}
- Sessions: {len(data['sessions'])}

## Sessions
'''
for session in data['sessions']:
    description += f\"- {session['session_name']}: {session.get('status', 'unknown')}\\n\"

print(json.dumps({'title': title, 'description': description}))
")
    ISSUE_TITLE=$(echo "$ISSUE_DATA" | python3 -c "import json, sys; print(json.load(sys.stdin)['title'])")
    if [[ "$ISSUE_TITLE" == *"batch_20250928_094810"* ]]; then
        test_pass "Format experiment data for GitLab issue"
    else
        test_fail "Format experiment data for GitLab issue" "batch_20250928_094810 in title" "$ISSUE_TITLE"
    fi
fi

# Test 7: Can we run sync script in dry-run mode?
run_test
SYNC_SCRIPT="$REPO_ROOT/tools/gitlab/sync_experiment_to_gitlab.py"
if [[ -f "$SYNC_SCRIPT" && -f "$TRACKING_FILE" ]]; then
    OUTPUT=$(python3 "$SYNC_SCRIPT" "$TRACKING_FILE" --dry-run 2>&1)
    if [[ "$OUTPUT" == *"DRY RUN MODE"* && "$OUTPUT" == *"batch_20250928_094810"* ]]; then
        test_pass "Run sync script in dry-run mode"
    else
        test_fail "Run sync script in dry-run mode" "DRY RUN output with batch_id" "unexpected output"
    fi
else
    test_fail "Run sync script in dry-run mode" "sync script and tracking file" "not found"
fi

# Test 8: Does GitLab issue template exist?
run_test
ISSUE_TEMPLATE="$REPO_ROOT/.gitlab/issue_templates/experiment.md"
if [[ -f "$ISSUE_TEMPLATE" ]]; then
    # Check that template has required sections
    if grep -q "## Experiment Batch" "$ISSUE_TEMPLATE" && \
       grep -q "## Sessions" "$ISSUE_TEMPLATE" && \
       grep -q "## Metadata" "$ISSUE_TEMPLATE"; then
        test_pass "GitLab issue template exists with required sections"
    else
        test_fail "GitLab issue template" "required sections" "missing sections"
    fi
else
    test_fail "GitLab issue template" "$ISSUE_TEMPLATE" "not found"
fi

# Test 9: Can we add gitlab_issue_id to tracking JSON?
run_test
TEST_JSON=$(mktemp)
cat > "$TEST_JSON" << 'EOF'
{
  "batch_id": "test_batch",
  "start_time": "2025-10-02T10:00:00+02:00",
  "total_experiments": 2,
  "sessions": []
}
EOF

# Add gitlab_issue_id field
UPDATED_JSON=$(python3 -c "
import json
data = json.load(open('$TEST_JSON'))
data['gitlab_issue_id'] = 123
print(json.dumps(data, indent=2))
")
echo "$UPDATED_JSON" > "$TEST_JSON"

# Verify field exists
ISSUE_ID=$(python3 -c "import json; print(json.load(open('$TEST_JSON')).get('gitlab_issue_id', 'missing'))")
rm -f "$TEST_JSON"

if [[ "$ISSUE_ID" == "123" ]]; then
    test_pass "Add gitlab_issue_id to tracking JSON schema"
else
    test_fail "Add gitlab_issue_id to tracking JSON schema" "123" "$ISSUE_ID"
fi

# Test 10: Create actual GitLab issue (INTEGRATION TEST)
run_test
# Only run if --integration flag is passed
if [[ "${1:-}" == "--integration" ]]; then
    # Find tracking file without gitlab_issue_id
    TEST_TRACKING=$(python3 -c "
import json
from pathlib import Path
tracking_dir = Path('$REPO_ROOT/experiments/lv4d_campaign_2025/tracking')
for json_file in sorted(tracking_dir.glob('*.json')):
    with open(json_file) as f:
        data = json.load(f)
        if 'gitlab_issue_id' not in data:
            print(json_file)
            break
" 2>/dev/null || echo "")

    if [[ -n "$TEST_TRACKING" ]]; then
        # Create GitLab issue
        OUTPUT=$(python3 "$SYNC_SCRIPT" "$TEST_TRACKING" 2>&1)
        if [[ "$OUTPUT" == *"✅ Created issue #"* ]]; then
            # Verify gitlab_issue_id was added to tracking file
            STORED_ISSUE_ID=$(python3 -c "import json; print(json.load(open('$TEST_TRACKING')).get('gitlab_issue_id', 'missing'))")
            if [[ "$STORED_ISSUE_ID" != "missing" && "$STORED_ISSUE_ID" =~ ^[0-9]+$ ]]; then
                test_pass "Create GitLab issue and store ID (issue #$STORED_ISSUE_ID)"
            else
                test_fail "Store gitlab_issue_id in tracking file" "numeric ID" "$STORED_ISSUE_ID"
            fi
        else
            test_fail "Create GitLab issue" "success message" "error"
        fi
    else
        test_fail "Find tracking file without gitlab_issue_id" "found file" "none available"
    fi
else
    # Skip integration test
    test_skip "Create GitLab issue (skipped - use --integration to run)"
fi

# Test 11: Bulk dry-run testing (all batches)
run_test
BATCH_COUNT=$(ls -1 "$REPO_ROOT/experiments/lv4d_campaign_2025/tracking"/*.json 2>/dev/null | wc -l)
if [[ "$BATCH_COUNT" -gt 0 ]]; then
    FAILED_BATCHES=0
    for batch in "$REPO_ROOT/experiments/lv4d_campaign_2025/tracking"/*.json; do
        if ! python3 "$SYNC_SCRIPT" "$batch" --dry-run >/dev/null 2>&1; then
            ((FAILED_BATCHES++))
        fi
    done

    if [[ "$FAILED_BATCHES" -eq 0 ]]; then
        test_pass "Bulk dry-run test ($BATCH_COUNT batches)"
    else
        test_fail "Bulk dry-run test" "0 failures" "$FAILED_BATCHES/$BATCH_COUNT batches failed"
    fi
else
    test_fail "Bulk dry-run test" "batches found" "no batches"
fi

# Test 12: Update existing GitLab issue (requires --integration)
run_test
if [[ "${1:-}" == "--integration" ]]; then
    # Find a tracking file with gitlab_issue_id
    TEST_UPDATE=$(python3 -c "
import json
from pathlib import Path
tracking_dir = Path('$REPO_ROOT/experiments/lv4d_campaign_2025/tracking')
for json_file in sorted(tracking_dir.glob('*.json')):
    with open(json_file) as f:
        data = json.load(f)
        if 'gitlab_issue_id' in data:
            print(json_file)
            print(data['gitlab_issue_id'])
            break
" 2>/dev/null || echo "")

    if [[ -n "$TEST_UPDATE" ]]; then
        TRACKING_PATH=$(echo "$TEST_UPDATE" | head -n1)
        ISSUE_ID=$(echo "$TEST_UPDATE" | tail -n1)

        # Test update with --issue-id flag
        OUTPUT=$(python3 "$SYNC_SCRIPT" "$TRACKING_PATH" --issue-id "$ISSUE_ID" 2>&1)
        if [[ "$OUTPUT" == *"✅ Updated issue #$ISSUE_ID"* ]]; then
            test_pass "Update GitLab issue #$ISSUE_ID"
        else
            test_fail "Update GitLab issue" "success message" "error"
        fi
    else
        test_fail "Find tracking file with gitlab_issue_id" "found file" "none available"
    fi
else
    test_skip "Update GitLab issue (skipped - use --integration to run)"
fi

# Test 13: Duplicate issue prevention
run_test
# Find a tracking file with gitlab_issue_id
TRACKING_WITH_ID=$(python3 -c "
import json
from pathlib import Path
tracking_dir = Path('$REPO_ROOT/experiments/lv4d_campaign_2025/tracking')
for json_file in sorted(tracking_dir.glob('*.json')):
    with open(json_file) as f:
        data = json.load(f)
        if 'gitlab_issue_id' in data:
            print(json_file)
            break
" 2>/dev/null || echo "")

if [[ -n "$TRACKING_WITH_ID" ]]; then
    # Try to create issue without --issue-id (should warn)
    OUTPUT=$(python3 "$SYNC_SCRIPT" "$TRACKING_WITH_ID" 2>&1)
    if [[ "$OUTPUT" == *"⚠️  Tracking file already has gitlab_issue_id"* ]]; then
        test_pass "Duplicate issue prevention (warning displayed)"
    else
        test_fail "Duplicate issue prevention" "warning message" "no warning"
    fi
else
    test_skip "Duplicate issue prevention (no tracked issues found)"
fi

echo ""
echo "=== Test Results ==="
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
if [[ "$TESTS_SKIPPED" -gt 0 ]]; then
    echo "Tests skipped: $TESTS_SKIPPED"
fi

EXPECTED_PASSED=$((TESTS_RUN - TESTS_SKIPPED))
if [[ "$TESTS_PASSED" -eq "$EXPECTED_PASSED" ]]; then
    echo -e "${GREEN}All non-skipped tests passed!${NC}"
    exit 0
else
    FAILED=$((EXPECTED_PASSED - TESTS_PASSED))
    echo -e "${RED}$FAILED test(s) failed${NC}"
    exit 1
fi
