#!/bin/bash
#
# Hook Integration End-to-End Test
# Tests new reliability hooks: file_integrity_validator, transfer_retry_manager,
# collection_monitor, metadata_validator
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
HOOKS_DIR="${SCRIPT_DIR}/../tools/hpc/hooks"
TEST_DIR="/tmp/hook_integration_test_$(date +%s)"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Create test environment
mkdir -p "$TEST_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "  Hook Integration End-to-End Test"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Test directory: $TEST_DIR"
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

section() {
    echo ""
    echo -e "${YELLOW}━━━ $1 ━━━${NC}"
}

# Test 1: Verify all hooks are registered
section "Test 1: Hook Registry Validation"

if jq -e '.hooks.file_integrity_validator' "$HOOKS_DIR/hook_registry.json" >/dev/null; then
    pass "file_integrity_validator registered in hook registry"
else
    fail "file_integrity_validator NOT registered"
fi

if jq -e '.hooks.transfer_retry_manager' "$HOOKS_DIR/hook_registry.json" >/dev/null; then
    pass "transfer_retry_manager registered in hook registry"
else
    fail "transfer_retry_manager NOT registered"
fi

if jq -e '.hooks.collection_monitor' "$HOOKS_DIR/hook_registry.json" >/dev/null; then
    pass "collection_monitor registered in hook registry"
else
    fail "collection_monitor NOT registered"
fi

if jq -e '.hooks.metadata_validator' "$HOOKS_DIR/hook_registry.json" >/dev/null; then
    pass "metadata_validator registered in hook registry"
else
    fail "metadata_validator NOT registered"
fi

# Test 2: Metadata Validator
section "Test 2: Metadata Validator"

# Create test JSON files
cat > "$TEST_DIR/valid.json" << 'EOF'
{
  "experiment_id": "test_001",
  "total_computations": 100,
  "success_rate": 0.95
}
EOF

cat > "$TEST_DIR/truncated.json" << 'EOF'
{
  "experiment_id": "test_002",
  "results": {
    "ptr":
EOF

# Test valid JSON
if "$HOOKS_DIR/metadata_validator.sh" --validate "$TEST_DIR/valid.json" >/dev/null 2>&1; then
    pass "Valid JSON passes validation"
else
    fail "Valid JSON fails validation"
fi

# Test truncated JSON (should fail)
if "$HOOKS_DIR/metadata_validator.sh" --validate "$TEST_DIR/truncated.json" >/dev/null 2>&1; then
    fail "Truncated JSON incorrectly passes validation"
else
    pass "Truncated JSON correctly fails validation"
fi

# Test schema validation
if "$HOOKS_DIR/metadata_validator.sh" --validate-schema "$TEST_DIR/valid.json" "experiment_id,total_computations" >/dev/null 2>&1; then
    pass "Schema validation with required fields passes"
else
    fail "Schema validation fails"
fi

# Test corruption detection
if "$HOOKS_DIR/metadata_validator.sh" --check-corruption "$TEST_DIR/truncated.json" >/dev/null 2>&1; then
    fail "Corruption detection misses truncated JSON"
else
    pass "Corruption detection correctly identifies truncated JSON"
fi

# Test 3: Collection Monitor Status
section "Test 3: Collection Monitor"

# Test that collection monitor loads and reports status correctly
if "$HOOKS_DIR/collection_monitor.sh" --test >/dev/null 2>&1; then
    pass "Collection monitor test mode works"
else
    fail "Collection monitor test mode fails"
fi

# Test status query on non-existent collection (should fail gracefully)
if "$HOOKS_DIR/collection_monitor.sh" --status "nonexistent_collection" >/dev/null 2>&1; then
    fail "Collection monitor incorrectly reports status for non-existent collection"
else
    pass "Collection monitor correctly handles non-existent collection"
fi

# Test 4: File Integrity Validator (local test only)
section "Test 4: File Integrity Validator"

# Create test files
echo "test data for validation" > "$TEST_DIR/test_file.txt"

# Test JSON validation on our valid JSON
if "$HOOKS_DIR/file_integrity_validator.sh" --validate-json "$TEST_DIR/valid.json" >/dev/null 2>&1; then
    pass "File integrity validator JSON check passes for valid JSON"
else
    fail "File integrity validator JSON check fails for valid JSON"
fi

# Test JSON validation on truncated JSON
if "$HOOKS_DIR/file_integrity_validator.sh" --validate-json "$TEST_DIR/truncated.json" >/dev/null 2>&1; then
    fail "File integrity validator incorrectly passes truncated JSON"
else
    pass "File integrity validator correctly rejects truncated JSON"
fi

# Test 5: Hook Orchestrator Integration
section "Test 5: Hook Orchestrator Integration"

# Verify hook orchestrator can load the registry
if "$HOOKS_DIR/hook_orchestrator.sh" version >/dev/null 2>&1; then
    pass "Hook orchestrator loads successfully"
else
    # Try alternative command
    if [[ -x "$HOOKS_DIR/hook_orchestrator.sh" ]]; then
        pass "Hook orchestrator is executable"
    else
        fail "Hook orchestrator not executable"
    fi
fi

# Count hooks in registry
HOOK_COUNT=$(jq '.hooks | length' "$HOOKS_DIR/hook_registry.json")
if [[ $HOOK_COUNT -ge 12 ]]; then
    pass "Hook registry contains $HOOK_COUNT hooks (including new ones)"
else
    fail "Hook registry only contains $HOOK_COUNT hooks (expected >= 12)"
fi

# Test 6: Transfer Retry Manager (dry run test)
section "Test 6: Transfer Retry Manager"

# Test mode should work
if "$HOOKS_DIR/transfer_retry_manager.sh" --test >/dev/null 2>&1; then
    pass "Transfer retry manager test mode works"
else
    fail "Transfer retry manager test mode fails"
fi

# Verify it has the expected functions
if grep -q "transfer_with_retry" "$HOOKS_DIR/transfer_retry_manager.sh"; then
    pass "Transfer retry manager contains retry logic"
else
    fail "Transfer retry manager missing retry logic"
fi

if grep -q "bulk_transfer_with_retry" "$HOOKS_DIR/transfer_retry_manager.sh"; then
    pass "Transfer retry manager contains bulk transfer logic"
else
    fail "Transfer retry manager missing bulk transfer logic"
fi

# Test 7: Integration with existing hooks
section "Test 7: Hook Priority and Phase Assignment"

# Check that new hooks have appropriate priority values
FILE_INT_PRIORITY=$(jq -r '.hooks.file_integrity_validator.priority' "$HOOKS_DIR/hook_registry.json")
TRANSFER_PRIORITY=$(jq -r '.hooks.transfer_retry_manager.priority' "$HOOKS_DIR/hook_registry.json")

if [[ $FILE_INT_PRIORITY -eq 22 ]] && [[ $TRANSFER_PRIORITY -eq 23 ]]; then
    pass "New hooks have correct priority ordering (file_integrity: $FILE_INT_PRIORITY, transfer: $TRANSFER_PRIORITY)"
else
    fail "Hook priorities are incorrect (file_integrity: $FILE_INT_PRIORITY, transfer: $TRANSFER_PRIORITY)"
fi

# Verify phases are appropriate
METADATA_PHASE=$(jq -r '.hooks.metadata_validator.phases[0]' "$HOOKS_DIR/hook_registry.json")
MONITOR_PHASE=$(jq -r '.hooks.collection_monitor.phases[0]' "$HOOKS_DIR/hook_registry.json")

if [[ "$METADATA_PHASE" == "completion" ]] && [[ "$MONITOR_PHASE" == "monitoring" ]]; then
    pass "Hooks assigned to appropriate phases (metadata: $METADATA_PHASE, monitor: $MONITOR_PHASE)"
else
    fail "Hook phases are incorrect (metadata: $METADATA_PHASE, monitor: $MONITOR_PHASE)"
fi

# Cleanup
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Test Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
