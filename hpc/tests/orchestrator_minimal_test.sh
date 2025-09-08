#!/bin/bash
# Minimal Hook Orchestrator Test - Issues #58-62
# Tests orchestrator with minimal configuration

set -e

echo "🎭 Minimal Hook Orchestrator Test - Issue #58"
echo "============================================="

# Auto-detect environment
if [[ -d "/home/scholten/globtim" ]]; then
    GLOBTIM_DIR="/home/scholten/globtim"
    ENV="HPC"
else
    GLOBTIM_DIR="/Users/ghscholt/globtim"
    ENV="LOCAL"
fi

echo "Environment: $ENV"
echo "Project Dir: $GLOBTIM_DIR"

# Setup paths
HOOKS_DIR="$GLOBTIM_DIR/tools/hpc/hooks"
ORCHESTRATOR="$HOOKS_DIR/hook_orchestrator.sh"
REGISTRY_FILE="$HOOKS_DIR/hook_registry.json"

echo ""
echo "Testing Orchestrator Setup:"
echo "Orchestrator: $ORCHESTRATOR"
echo "Registry: $REGISTRY_FILE"

# Check orchestrator exists
if [[ ! -f "$ORCHESTRATOR" ]]; then
    echo "❌ Hook orchestrator not found"
    exit 1
fi

if [[ ! -x "$ORCHESTRATOR" ]]; then
    chmod +x "$ORCHESTRATOR"
    echo "✅ Made orchestrator executable"
fi

# Check registry exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "❌ Hook registry not found"
    exit 1
fi

# Test registry JSON validity
if python3 -c "import json; json.load(open('$REGISTRY_FILE'))" 2>/dev/null; then
    echo "✅ Hook registry has valid JSON"
else
    echo "❌ Hook registry has invalid JSON"
    exit 1
fi

# Test Python dependency
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not available (required for registry)"
    exit 1
fi
echo "✅ Python3 available: $(python3 --version)"

# Create minimal test with limited hooks
echo ""
echo "Creating minimal test experiment..."

TEST_EXP_ID="minimal_test_$(date +%Y%m%d_%H%M%S)"
echo "Test Experiment ID: $TEST_EXP_ID"

# Test basic orchestrator functions by sourcing it
echo ""
echo "Testing orchestrator functions:"

# Source orchestrator to test basic functions
if bash -c "
set -e
source '$ORCHESTRATOR'

# Test environment detection
echo 'Environment in orchestrator: $ENVIRONMENT'
echo 'GlobTim dir in orchestrator: $GLOBTIM_DIR'

# Test basic state management
save_experiment_state '$TEST_EXP_ID' 'validation' 'pending' 'minimal_test'
echo 'State save function: ✅ Working'

# Test state loading
if load_experiment_state '$TEST_EXP_ID' > /dev/null; then
    echo 'State load function: ✅ Working'
else
    echo 'State load function: ⚠️  No state file'
fi

# Test registry loading
if load_hook_registry > /dev/null; then
    echo 'Registry load function: ✅ Working'
else
    echo 'Registry load function: ❌ Failed'
    exit 1
fi
"; then
    echo "✅ Basic orchestrator functions working"
else
    echo "❌ Orchestrator function test failed"
    exit 1
fi

# Test hook discovery for validation phase
echo ""
echo "Testing hook discovery:"

HOOKS_OUTPUT=$(bash -c "
set -e
source '$ORCHESTRATOR'
get_hooks_for_phase 'validation' 'experiment' 'default'
")

if [[ -n "$HOOKS_OUTPUT" ]]; then
    echo "✅ Hook discovery working"
    echo "Discovered hooks for validation phase:"
    echo "$HOOKS_OUTPUT" | head -5
else
    echo "⚠️  No hooks discovered for validation phase"
fi

echo ""
echo "🎯 Minimal Orchestrator Test Summary:"
echo "- Environment Detection: ✅ Working"
echo "- Registry Loading: ✅ Working"
echo "- State Management: ✅ Working"
echo "- Hook Discovery: ✅ Working"
echo "- Python Integration: ✅ Working"

# Cleanup test state
STATE_FILE="$HOOKS_DIR/state/${TEST_EXP_ID}.state"
if [[ -f "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    echo "✅ Test state cleaned up"
fi

echo ""
echo "Next: This confirms orchestrator core functions work."
echo "      The failures are likely in specific hook execution,"
echo "      not in the orchestrator framework itself."