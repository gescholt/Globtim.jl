#!/bin/bash
# Run all DrWatson.jl feature tests
#
# Usage: ./run_all_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DrWatson.jl Feature Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Function to run a test
run_test() {
    local test_file=$1
    local test_name=$2

    echo -e "${BLUE}Running: $test_name${NC}"
    echo ""

    if julia --project="$PROJECT_ROOT" "$SCRIPT_DIR/$test_file"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo ""
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        echo ""
        echo -e "${RED}❌ FAILED: $test_name${NC}"
    fi
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Run all tests
run_test "test_1_installation.jl" "Test 1: Package Installation"
run_test "test_2_savename.jl" "Test 2: savename() Functionality"
run_test "test_3_dict_macro.jl" "Test 3: @dict Macro"
run_test "test_4_datadir.jl" "Test 4: datadir() Path Management"
run_test "test_5_tagsave.jl" "Test 5: tagsave() Git Tracking"
run_test "test_6_produce_or_load.jl" "Test 6: produce_or_load() Caching"

# Print summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Suite Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}• $test${NC}"
    done
    echo ""
    exit 1
fi