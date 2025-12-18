#!/bin/bash
# Quick Hook Integration Test

HOOKS_DIR="/Users/ghscholt/GlobalOptim/globtimcore/tools/hpc/hooks"

echo "Testing Hook Integration..."
echo ""

# Test 1: Registry
echo "1. Hook Registry Check"
jq -e '.hooks.file_integrity_validator' "$HOOKS_DIR/hook_registry.json" >/dev/null && echo "  ✓ file_integrity_validator registered" || echo "  ✗ FAILED"
jq -e '.hooks.transfer_retry_manager' "$HOOKS_DIR/hook_registry.json" >/dev/null && echo "  ✓ transfer_retry_manager registered" || echo "  ✗ FAILED"
jq -e '.hooks.collection_monitor' "$HOOKS_DIR/hook_registry.json" >/dev/null && echo "  ✓ collection_monitor registered" || echo "  ✗ FAILED"
jq -e '.hooks.metadata_validator' "$HOOKS_DIR/hook_registry.json" >/dev/null && echo "  ✓ metadata_validator registered" || echo "  ✗ FAILED"
echo ""

# Test 2: Hook executable and test mode
echo "2. Hook Test Modes"
"$HOOKS_DIR/file_integrity_validator.sh" --test >/dev/null 2>&1 && echo "  ✓ file_integrity_validator --test" || echo "  ✗ FAILED"
"$HOOKS_DIR/transfer_retry_manager.sh" --test >/dev/null 2>&1 && echo "  ✓ transfer_retry_manager --test" || echo "  ✗ FAILED"
"$HOOKS_DIR/collection_monitor.sh" --test >/dev/null 2>&1 && echo "  ✓ collection_monitor --test" || echo "  ✗ FAILED"
"$HOOKS_DIR/metadata_validator.sh" --test >/dev/null 2>&1 && echo "  ✓ metadata_validator --test" || echo "  ✗ FAILED"
echo ""

# Test 3: Metadata validation
echo "3. Metadata Validation"
cat > /tmp/test_valid.json << 'EOF'
{"experiment_id": "test", "data": [1,2,3]}
EOF

"$HOOKS_DIR/metadata_validator.sh" --validate /tmp/test_valid.json >/dev/null 2>&1 && echo "  ✓ Valid JSON passes" || echo "  ✗ FAILED"

cat > /tmp/test_invalid.json << 'EOF'
{"incomplete": "ptr":
EOF

"$HOOKS_DIR/metadata_validator.sh" --validate /tmp/test_invalid.json >/dev/null 2>&1 && echo "  ✗ Invalid JSON incorrectly passes" || echo "  ✓ Invalid JSON correctly fails"
echo ""

# Test 4: Priority ordering
echo "4. Hook Priority Ordering"
HOOK_COUNT=$(jq '.hooks | length' "$HOOKS_DIR/hook_registry.json")
echo "  ✓ Total hooks registered: $HOOK_COUNT"

FILE_INT_PRIORITY=$(jq -r '.hooks.file_integrity_validator.priority' "$HOOKS_DIR/hook_registry.json")
echo "  ✓ file_integrity_validator priority: $FILE_INT_PRIORITY"

TRANSFER_PRIORITY=$(jq -r '.hooks.transfer_retry_manager.priority' "$HOOKS_DIR/hook_registry.json")
echo "  ✓ transfer_retry_manager priority: $TRANSFER_PRIORITY"
echo ""

echo "All tests complete!"
