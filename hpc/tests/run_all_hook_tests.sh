#!/bin/bash
# Master Test Runner for Hook System Debugging
# Issues #58-62: Systematic component testing

set -e

echo "🧪 Hook System Debug Test Suite"
echo "==============================="
echo "Testing individual components to isolate failures"
echo ""

# Auto-detect environment
if [[ -d "/home/scholten/globtim" ]]; then
    ENV="HPC (r04n02)"
else
    ENV="Local macOS"
fi

echo "Environment: $ENV"
echo "Date: $(date)"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test files in dependency order
TESTS=(
    "hook_debug_simple.sh:Basic Environment and Setup"
    "gitlab_hook_test.sh:GitLab Hook Component (Issue #60)"
    "lifecycle_test.sh:Lifecycle Manager (Issue #61)" 
    "orchestrator_minimal_test.sh:Hook Orchestrator Core (Issue #58)"
)

PASSED=0
FAILED=0
WARNINGS=0

# Run each test
for test_entry in "${TESTS[@]}"; do
    IFS=':' read -r test_file test_description <<< "$test_entry"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Running: $test_description"
    echo "   File: $test_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -f "$SCRIPT_DIR/$test_file" ]]; then
        if bash "$SCRIPT_DIR/$test_file"; then
            echo ""
            echo "✅ PASSED: $test_description"
            PASSED=$((PASSED + 1))
        else
            echo ""
            echo "❌ FAILED: $test_description"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ TEST FILE NOT FOUND: $test_file"
        FAILED=$((FAILED + 1))
    fi
    
    echo ""
    echo "Press Enter to continue to next test (or Ctrl+C to stop)..."
    read -r
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 TEST SUITE SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Environment: $ENV"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total: $((PASSED + FAILED))"

if [[ $FAILED -eq 0 ]]; then
    echo ""
    echo "🎉 ALL TESTS PASSED!"
    echo "   Hook system components are working individually."
    echo "   Failures likely due to integration or configuration issues."
else
    echo ""
    echo "⚠️  $FAILED TESTS FAILED"
    echo "   Focus debugging on the failed components first."
fi

echo ""
echo "Next Steps:"
echo "1. Fix any failed components before integration testing"
echo "2. Update GitLab issues #58-62 with test results"  
echo "3. Run full integration test with robust_experiment_runner.sh"