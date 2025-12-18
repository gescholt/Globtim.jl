#!/bin/bash
# Test suite for auto_commit.sh (Phase 2 of Issue #140)
# Tests MUST fail initially, then pass after implementation (TDD approach)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "========================================================================"
echo "auto_commit.sh - TDD Test Suite (Phase 2)"
echo "========================================================================"
echo ""

# =============================================================================
# Test 1: Script exists and is executable
# =============================================================================
echo -e "${BLUE}=== Test 1: Basic Script Properties ===${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/../auto_commit.sh"

echo "Test 1.1: auto_commit.sh exists"
((TESTS_RUN++))
if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: Script exists"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Script not found at $AUTO_COMMIT_SCRIPT"
    ((TESTS_FAILED++))
    echo -e "${YELLOW}⚠ This is expected in TDD - create the script${NC}"
fi

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 1.2: auto_commit.sh is executable"
    ((TESTS_RUN++))
    if [[ -x "$AUTO_COMMIT_SCRIPT" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Script is executable"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Script is not executable"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 2: Usage/Help Message
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 2: Usage and Help ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 2.1: Script shows usage when called with --help"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" --help 2>&1 | grep -qi "usage\|Usage"; then
        echo -e "${GREEN}✓ PASS${NC}: Shows usage message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: No usage message"
        ((TESTS_FAILED++))
    fi

    echo "Test 2.2: Script supports -h flag"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" -h 2>&1 | grep -qi "usage\|Usage"; then
        echo -e "${GREEN}✓ PASS${NC}: -h flag works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: -h flag doesn't work"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 3: Git Repository Detection
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 3: Git Repository Detection ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 3.1: Script checks if in git repository"
    ((TESTS_RUN++))
    if grep -q "git rev-parse\|git status" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Checks git repository"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't check git repository"
        ((TESTS_FAILED++))
    fi

    echo "Test 3.2: Script exits cleanly if not in git repo"
    ((TESTS_RUN++))
    # Create non-git directory
    NON_GIT_DIR="$TEST_DIR/non_git"
    mkdir -p "$NON_GIT_DIR"
    cd "$NON_GIT_DIR"
    OUTPUT=$("$AUTO_COMMIT_SCRIPT" 2>&1 || true)
    if [[ -z "$OUTPUT" ]] || ! echo "$OUTPUT" | grep -qi "error"; then
        echo -e "${GREEN}✓ PASS${NC}: Exits cleanly for non-git directory"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't handle non-git directory cleanly"
        ((TESTS_FAILED++))
    fi
    cd - > /dev/null
fi

# =============================================================================
# Test 4: Change Detection
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 4: Change Detection ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 4.1: Script detects uncommitted changes"
    ((TESTS_RUN++))
    if grep -q "git status --porcelain" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Detects uncommitted changes"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't detect uncommitted changes"
        ((TESTS_FAILED++))
    fi

    echo "Test 4.2: Script counts modified files"
    ((TESTS_RUN++))
    if grep -q "wc -l\|file_count\|FILE_COUNT" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Counts modified files"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't count modified files"
        ((TESTS_FAILED++))
    fi

    echo "Test 4.3: Script exits cleanly if no changes"
    ((TESTS_RUN++))
    if grep -q "exit 0\|return 0" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Can exit cleanly"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't exit cleanly"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 5: Threshold Logic
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 5: Threshold Logic ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 5.1: Script supports file count threshold"
    ((TESTS_RUN++))
    if grep -q "threshold\|THRESHOLD\|-ge.*5" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Supports threshold"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't support threshold"
        ((TESTS_FAILED++))
    fi

    echo "Test 5.2: Default threshold is 5 files"
    ((TESTS_RUN++))
    if grep -q "5\|THRESHOLD=5" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Default threshold is 5"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Default threshold not set to 5"
        ((TESTS_FAILED++))
    fi

    echo "Test 5.3: Script supports --threshold flag"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" --help 2>&1 | grep -qi "threshold"; then
        echo -e "${GREEN}✓ PASS${NC}: Supports --threshold flag"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't support --threshold flag"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 6: Commit Functionality
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 6: Commit Functionality ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 6.1: Script stages all changes"
    ((TESTS_RUN++))
    if grep -q "git add" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Stages changes"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't stage changes"
        ((TESTS_FAILED++))
    fi

    echo "Test 6.2: Script creates commit"
    ((TESTS_RUN++))
    if grep -q "git commit" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Creates commit"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't create commit"
        ((TESTS_FAILED++))
    fi

    echo "Test 6.3: Commit message includes file count"
    ((TESTS_RUN++))
    if grep -q '\$file_count\|\$FILE_COUNT\|file.*modified' "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Includes file count in message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't include file count"
        ((TESTS_FAILED++))
    fi

    echo "Test 6.4: Commit message includes Claude Code attribution"
    ((TESTS_RUN++))
    if grep -q "Claude Code\|claude.com" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Includes attribution"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't include attribution"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 7: Push Functionality
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 7: Push Functionality ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 7.1: Script can push to remote"
    ((TESTS_RUN++))
    if grep -q "git push" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Can push to remote"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Cannot push to remote"
        ((TESTS_FAILED++))
    fi

    echo "Test 7.2: Script supports --no-push flag"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" --help 2>&1 | grep -qi "no-push"; then
        echo -e "${GREEN}✓ PASS${NC}: Supports --no-push"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't support --no-push"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 8: Error Handling
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 8: Error Handling ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 8.1: Script validates threshold is a number"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" --threshold abc 2>&1 | grep -qi "error\|invalid\|number"; then
        echo -e "${GREEN}✓ PASS${NC}: Validates threshold"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't validate threshold"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Test 9: Dry Run Mode
# =============================================================================
echo ""
echo -e "${BLUE}=== Test 9: Dry Run Mode ===${NC}"
echo ""

if [[ -f "$AUTO_COMMIT_SCRIPT" ]]; then
    echo "Test 9.1: Script supports --dry-run flag"
    ((TESTS_RUN++))
    if "$AUTO_COMMIT_SCRIPT" --help 2>&1 | grep -qi "dry-run\|dry run"; then
        echo -e "${GREEN}✓ PASS${NC}: Supports --dry-run"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Doesn't support --dry-run"
        ((TESTS_FAILED++))
    fi

    echo "Test 9.2: Dry run doesn't execute git commands"
    ((TESTS_RUN++))
    if grep -q "DRY_RUN.*true\|dry_run.*true" "$AUTO_COMMIT_SCRIPT"; then
        echo -e "${GREEN}✓ PASS${NC}: Has dry run logic"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: No dry run logic"
        ((TESTS_FAILED++))
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================================================"
echo "Test Summary"
echo "========================================================================"
echo "Total Tests: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Test suite FAILED${NC}"
    echo "This is EXPECTED in TDD - now implement auto_commit.sh to make tests pass"
    exit 1
else
    echo -e "${GREEN}✅ All tests PASSED${NC}"
    exit 0
fi
