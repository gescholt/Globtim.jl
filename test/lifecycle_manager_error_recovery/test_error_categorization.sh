#!/bin/bash
# Test: Error Categorization
# Purpose: Validate 4-category error taxonomy

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAME="Error Categorization"
TESTS_PASSED=0
TESTS_FAILED=0

# Source the lifecycle manager to get the categorization function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIFECYCLE_MANAGER="$SCRIPT_DIR/../../tools/hpc/hooks/lifecycle_manager.sh"

if [[ ! -f "$LIFECYCLE_MANAGER" ]]; then
    echo -e "${RED}ERROR: lifecycle_manager.sh not found at $LIFECYCLE_MANAGER${NC}"
    exit 1
fi

# Source the categorization function (we'll add this)
# For now, we'll test by calling the script directly

test_categorization() {
    local test_name="$1"
    local error_log="$2"
    local expected_category="$3"

    echo -n "Testing: $test_name ... "

    # Create temp file with error log
    local temp_error=$(mktemp)
    echo "$error_log" > "$temp_error"

    # Try to categorize (this will fail initially - no function exists yet)
    if result=$("$LIFECYCLE_MANAGER" categorize "$temp_error" 2>&1); then
        if [[ "$result" == "$expected_category" ]]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (got: $result, expected: $expected_category)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}FAIL${NC} (function returned error: $result)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    rm -f "$temp_error"
}

test_categorization_fail() {
    local test_name="$1"
    local error_log="$2"

    echo -n "Testing: $test_name (should fail) ... "

    local temp_error=$(mktemp)
    echo "$error_log" > "$temp_error"

    if "$LIFECYCLE_MANAGER" categorize "$temp_error" 2>/dev/null; then
        echo -e "${RED}FAIL${NC} (should have failed but passed)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}PASS${NC} (correctly failed)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    rm -f "$temp_error"
}

echo "=========================================="
echo " TEST: $TEST_NAME"
echo "=========================================="
echo ""

# Test 1: INTERFACE_BUG - .val column naming
test_categorization \
    "Interface bug - .val column" \
    "ArgumentError: column name :val not found in df_critical" \
    "INTERFACE_BUG"

# Test 2: INTERFACE_BUG - df_critical.val usage
test_categorization \
    "Interface bug - df_critical.val" \
    "ERROR: BoundsError: attempt to access df_critical.val" \
    "INTERFACE_BUG"

# Test 3: PACKAGE_LOADING_FAILURE - HomotopyContinuation
test_categorization \
    "Package loading - HomotopyContinuation" \
    "ERROR: LoadError: failed to load HomotopyContinuation" \
    "PACKAGE_LOADING_FAILURE"

# Test 4: PACKAGE_LOADING_FAILURE - StaticArrays
test_categorization \
    "Package loading - StaticArrays" \
    "ArgumentError: Package StaticArrays not found in current path" \
    "PACKAGE_LOADING_FAILURE"

# Test 5: PACKAGE_LOADING_FAILURE - Precompilation
test_categorization \
    "Package loading - Precompilation" \
    "ERROR: failed to precompile HomotopyContinuation" \
    "PACKAGE_LOADING_FAILURE"

# Test 6: MATHEMATICAL_FAILURE - tracking failed
test_categorization \
    "Mathematical failure - tracking" \
    "HomotopyContinuation: path tracking failed for system" \
    "MATHEMATICAL_FAILURE"

# Test 7: MATHEMATICAL_FAILURE - convergence
test_categorization \
    "Mathematical failure - convergence" \
    "ERROR: convergence not achieved after 1000 iterations" \
    "MATHEMATICAL_FAILURE"

# Test 8: MATHEMATICAL_FAILURE - singular matrix
test_categorization \
    "Mathematical failure - singular matrix" \
    "LinearAlgebra: singular matrix detected in computation" \
    "MATHEMATICAL_FAILURE"

# Test 9: CONFIGURATION_ERROR - invalid parameter
test_categorization \
    "Configuration error - invalid parameter" \
    "ArgumentError: invalid parameter value GN=50, must be <= 20" \
    "CONFIGURATION_ERROR"

# Test 10: CONFIGURATION_ERROR - missing argument
test_categorization \
    "Configuration error - missing argument" \
    "ERROR: missing required argument: domain_size" \
    "CONFIGURATION_ERROR"

# Test 11: CONFIGURATION_ERROR - bounds exceeded
test_categorization \
    "Configuration error - bounds exceeded" \
    "DomainError: bounds exceeded for degree=15, maximum is 12" \
    "CONFIGURATION_ERROR"

# Test 12: Unknown error (should fail fast - no fallback)
test_categorization_fail \
    "Unknown error pattern" \
    "Something completely unexpected happened with no known pattern"

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