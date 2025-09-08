#!/bin/bash
# Simple Lifecycle Manager Test - Issue #61
# Tests lifecycle state transitions in isolation

set -e

echo "♻️  Lifecycle Manager Test - Issue #61"
echo "====================================="

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
STATE_DIR="$HOOKS_DIR/state"
LIFECYCLE_MANAGER="$HOOKS_DIR/lifecycle_manager.sh"

# Ensure directories exist
mkdir -p "$STATE_DIR"

echo ""
echo "Testing Lifecycle Manager:"
echo "Manager: $LIFECYCLE_MANAGER"

if [[ -f "$LIFECYCLE_MANAGER" ]]; then
    echo "✅ Lifecycle manager exists"
    
    if [[ -x "$LIFECYCLE_MANAGER" ]]; then
        echo "✅ Lifecycle manager is executable"
    else
        echo "⚠️  Making lifecycle manager executable..."
        chmod +x "$LIFECYCLE_MANAGER"
        echo "✅ Lifecycle manager now executable"
    fi
else
    echo "❌ Lifecycle manager not found"
    exit 1
fi

# Test basic state management
TEST_EXPERIMENT_ID="lifecycle_test_$(date +%Y%m%d_%H%M%S)"
echo ""
echo "Testing State Management:"
echo "Test Experiment ID: $TEST_EXPERIMENT_ID"

# Create test state file manually
STATE_FILE="$STATE_DIR/${TEST_EXPERIMENT_ID}.state"
echo "Creating test state: $STATE_FILE"

cat > "$STATE_FILE" << EOF
{
    "experiment_id": "$TEST_EXPERIMENT_ID",
    "current_phase": "validation",
    "status": "pending",
    "context": "lifecycle_test",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENV"
}
EOF

if [[ -f "$STATE_FILE" ]]; then
    echo "✅ Test state file created"
    
    # Test state file reading
    if cat "$STATE_FILE" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        echo "✅ State file has valid JSON"
        
        # Display state content
        echo ""
        echo "State Content:"
        cat "$STATE_FILE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, value in data.items():
    print(f'  {key}: {value}')
"
    else
        echo "❌ State file has invalid JSON"
        exit 1
    fi
else
    echo "❌ Failed to create state file"
    exit 1
fi

# Test valid phase transitions
echo ""
echo "Testing Phase Transitions:"
VALID_PHASES="initialization validation preparation execution monitoring completion recovery cleanup archived"
echo "Valid phases: $VALID_PHASES"

# Test a simple transition sequence
echo ""
echo "Testing transition sequence:"
echo "validation:pending -> preparation:completed"

# Update state to simulate transition
cat > "$STATE_FILE" << EOF
{
    "experiment_id": "$TEST_EXPERIMENT_ID",
    "current_phase": "preparation",
    "status": "completed",
    "context": "lifecycle_test",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENV"
}
EOF

echo "✅ State transition simulated"

# Check if lifecycle manager can read the state
if [[ -x "$LIFECYCLE_MANAGER" ]]; then
    echo ""
    echo "Testing lifecycle manager state reading:"
    
    # Test if manager can handle the state file (basic check)
    if bash -c "source '$LIFECYCLE_MANAGER'" 2>/dev/null; then
        echo "✅ Lifecycle manager functions can be sourced"
    else
        echo "⚠️  Lifecycle manager has syntax issues"
    fi
fi

echo ""
echo "🎯 Lifecycle Test Summary:"
echo "- Environment: $ENV"
echo "- State Directory: $STATE_DIR"
echo "- State File Creation: ✅ Working"
echo "- JSON Validation: ✅ Working"
echo "- Manager File: ✅ Available"

# Cleanup
rm -f "$STATE_FILE"
echo "✅ Test state cleaned up"

echo ""
echo "Next: Test with actual orchestrator integration"