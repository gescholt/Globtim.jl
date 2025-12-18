#!/bin/bash
# Test: Workflow Integration
# Purpose: Validate error categorization integrates with lifecycle_manager workflow

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TEST_NAME="Workflow Integration"
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIFECYCLE_MANAGER="$SCRIPT_DIR/../../tools/hpc/hooks/lifecycle_manager.sh"
STATE_DIR="$SCRIPT_DIR/../../tools/hpc/hooks/state"
TEST_EXP_PREFIX="test_workflow_$$"

# Cleanup function
cleanup() {
    rm -f "$STATE_DIR/${TEST_EXP_PREFIX}"*.json
}

trap cleanup EXIT

echo "=========================================="
echo " TEST: $TEST_NAME"
echo "=========================================="
echo ""

# Test 1: Create experiment and fail with interface bug
echo -n "Test 1: Interface bug categorization in workflow ... "
exp_id="${TEST_EXP_PREFIX}_interface"

# Create experiment
"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1

# Progress through phases to execution
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1

# Now update with failure and error log
error_log="ArgumentError: column name :val not found"
"$LIFECYCLE_MANAGER" update "$exp_id" execution failed "$error_log" >/dev/null 2>&1

# Check if error category was recorded (this will fail initially - no implementation)
state_file="$STATE_DIR/${exp_id}.json"
if [[ -f "$state_file" ]]; then
    # Try to extract error_info (will fail if not implemented)
    if category=$(python3 -c "import json; state=json.load(open('$state_file')); print(state.get('error_info', {}).get('category', ''))" 2>/dev/null); then
        if [[ "$category" == "INTERFACE_BUG" ]]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (category=$category, expected=INTERFACE_BUG)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}FAIL${NC} (no error_info in state)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (state file not found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Package loading failure
echo -n "Test 2: Package loading failure categorization ... "
exp_id="${TEST_EXP_PREFIX}_package"

"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1
error_log="ERROR: LoadError: failed to load HomotopyContinuation"
"$LIFECYCLE_MANAGER" update "$exp_id" execution failed "$error_log" >/dev/null 2>&1

state_file="$STATE_DIR/${exp_id}.json"
if category=$(python3 -c "import json; state=json.load(open('$state_file')); print(state.get('error_info', {}).get('category', ''))" 2>/dev/null); then
    if [[ "$category" == "PACKAGE_LOADING_FAILURE" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (category=$category, expected=PACKAGE_LOADING_FAILURE)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (no error_info in state)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Mathematical failure
echo -n "Test 3: Mathematical failure categorization ... "
exp_id="${TEST_EXP_PREFIX}_math"

"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1
error_log="HomotopyContinuation: path tracking failed"
"$LIFECYCLE_MANAGER" update "$exp_id" execution failed "$error_log" >/dev/null 2>&1

state_file="$STATE_DIR/${exp_id}.json"
if category=$(python3 -c "import json; state=json.load(open('$state_file')); print(state.get('error_info', {}).get('category', ''))" 2>/dev/null); then
    if [[ "$category" == "MATHEMATICAL_FAILURE" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (category=$category, expected=MATHEMATICAL_FAILURE)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (no error_info in state)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Configuration error
echo -n "Test 4: Configuration error categorization ... "
exp_id="${TEST_EXP_PREFIX}_config"

"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1
error_log="ArgumentError: invalid parameter value GN=50"
"$LIFECYCLE_MANAGER" update "$exp_id" execution failed "$error_log" >/dev/null 2>&1

state_file="$STATE_DIR/${exp_id}.json"
if category=$(python3 -c "import json; state=json.load(open('$state_file')); print(state.get('error_info', {}).get('category', ''))" 2>/dev/null); then
    if [[ "$category" == "CONFIGURATION_ERROR" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (category=$category, expected=CONFIGURATION_ERROR)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (no error_info in state)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Successful completion (no error categorization)
echo -n "Test 5: No categorization on success ... "
exp_id="${TEST_EXP_PREFIX}_success"

"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" execution completed "" >/dev/null 2>&1

state_file="$STATE_DIR/${exp_id}.json"
if has_error=$(python3 -c "import json; state=json.load(open('$state_file')); print('error_info' in state)" 2>/dev/null); then
    if [[ "$has_error" == "False" ]]; then
        echo -e "${GREEN}PASS${NC} (no error_info for successful experiment)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (error_info present for successful experiment)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (could not check state)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Error message persisted in state
echo -n "Test 6: Error message persisted ... "
exp_id="${TEST_EXP_PREFIX}_message"

"$LIFECYCLE_MANAGER" create "$exp_id" "test_context" "test_type" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" initialization completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" validation completed "" >/dev/null 2>&1
"$LIFECYCLE_MANAGER" update "$exp_id" preparation completed "" >/dev/null 2>&1
error_log="ERROR: LoadError: failed to load HomotopyContinuation"
"$LIFECYCLE_MANAGER" update "$exp_id" execution failed "$error_log" >/dev/null 2>&1

state_file="$STATE_DIR/${exp_id}.json"
if message=$(python3 -c "import json; state=json.load(open('$state_file')); print(state.get('error_info', {}).get('message', ''))" 2>/dev/null); then
    if [[ "$message" == "$error_log" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (message mismatch)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (no error message in state)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "=========================================="
echo " RESULTS"
echo "=========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi