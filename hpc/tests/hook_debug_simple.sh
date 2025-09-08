#!/bin/bash
# Simple Hook System Debug Tests
# Test one component at a time to isolate failures

set -e

echo "🔍 Hook System Debug Tests - Simple Step-by-Step"
echo "================================================"

# Test 1: Environment Detection
echo ""
echo "Test 1: Environment Detection"
echo "-----------------------------"
if [[ -d "/home/scholten/globtim" ]]; then
    GLOBTIM_DIR="/home/scholten/globtim"
    ENVIRONMENT="hpc"
    echo "✅ HPC environment detected: $GLOBTIM_DIR"
elif [[ -d "/Users/ghscholt/globtim" ]]; then
    GLOBTIM_DIR="/Users/ghscholt/globtim"
    ENVIRONMENT="local"
    echo "✅ Local environment detected: $GLOBTIM_DIR"
else
    echo "❌ No GlobTim directory found"
    exit 1
fi

# Test 2: Directory Structure
echo ""
echo "Test 2: Hook Directory Structure"
echo "--------------------------------"
HOOKS_DIR="$GLOBTIM_DIR/tools/hpc/hooks"
STATE_DIR="$HOOKS_DIR/state"

echo "Checking: $HOOKS_DIR"
if [[ -d "$HOOKS_DIR" ]]; then
    echo "✅ Hooks directory exists"
else
    echo "❌ Hooks directory missing"
    exit 1
fi

echo "Checking: $STATE_DIR"
if [[ -d "$STATE_DIR" ]]; then
    echo "✅ State directory exists"
else
    echo "⚠️  State directory missing - creating..."
    mkdir -p "$STATE_DIR"
    echo "✅ State directory created"
fi

# Test 3: Simple State File Creation
echo ""
echo "Test 3: State File Creation"
echo "---------------------------"
TEST_EXPERIMENT_ID="debug_test_$(date +%Y%m%d_%H%M%S)"
STATE_FILE="$STATE_DIR/${TEST_EXPERIMENT_ID}.state"

echo "Creating test state file: $STATE_FILE"
cat > "$STATE_FILE" << EOF
{
    "experiment_id": "$TEST_EXPERIMENT_ID",
    "current_phase": "validation",
    "status": "pending",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "test": true
}
EOF

if [[ -f "$STATE_FILE" ]]; then
    echo "✅ State file created successfully"
    echo "Content preview:"
    head -3 "$STATE_FILE"
else
    echo "❌ Failed to create state file"
    exit 1
fi

# Test 4: GitLab Token Check (non-blocking)
echo ""
echo "Test 4: GitLab Configuration Check"
echo "----------------------------------"
GITLAB_SCRIPT="$GLOBTIM_DIR/tools/gitlab/get-token-noninteractive.sh"
echo "Checking: $GITLAB_SCRIPT"

if [[ -f "$GITLAB_SCRIPT" ]]; then
    echo "✅ GitLab script exists"
    # Check if it's executable
    if [[ -x "$GITLAB_SCRIPT" ]]; then
        echo "✅ GitLab script is executable"
    else
        echo "⚠️  GitLab script not executable"
        chmod +x "$GITLAB_SCRIPT"
        echo "✅ Made GitLab script executable"
    fi
else
    echo "⚠️  GitLab script missing (non-critical for core functionality)"
fi

# Test 5: Python Availability (for hook registry)
echo ""
echo "Test 5: Python3 Availability"
echo "----------------------------"
if command -v python3 &> /dev/null; then
    echo "✅ Python3 available: $(which python3)"
    echo "Version: $(python3 --version)"
else
    echo "❌ Python3 not found (required for hook registry)"
    exit 1
fi

# Test 6: Basic Hook Registry Access
echo ""
echo "Test 6: Hook Registry Access"
echo "----------------------------"
REGISTRY_FILE="$HOOKS_DIR/hook_registry.json"
echo "Checking: $REGISTRY_FILE"

if [[ -f "$REGISTRY_FILE" ]]; then
    echo "✅ Hook registry exists"
    # Test JSON parsing
    if python3 -c "import json; json.load(open('$REGISTRY_FILE'))" 2>/dev/null; then
        echo "✅ Hook registry is valid JSON"
    else
        echo "❌ Hook registry has invalid JSON syntax"
        exit 1
    fi
else
    echo "⚠️  Hook registry missing"
fi

echo ""
echo "🎉 Basic Hook System Tests Completed Successfully"
echo "Environment: $ENVIRONMENT"
echo "Project Directory: $GLOBTIM_DIR"
echo "Test Experiment ID: $TEST_EXPERIMENT_ID"
echo ""
echo "Next: Run this test on the HPC node to verify environment setup"

# Cleanup test state file
rm -f "$STATE_FILE"
echo "✅ Test state file cleaned up"