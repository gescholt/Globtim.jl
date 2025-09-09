#!/bin/bash
# Comprehensive GitLab API Test Suite Runner
# For Issue #63: project-task-updater agent GitLab API communication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[SUITE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "========================================="
echo "GitLab API Comprehensive Test Suite"
echo "Issue #63: project-task-updater agent"
echo "========================================="
echo ""

# Check environment
log "Checking test environment..."

if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
    error "Not in a git repository. Run from project root."
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh" ]]; then
    error "GitLab wrapper script not found"
    exit 1
fi

log "Environment check passed"
echo ""

# Test Suite Overview
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

run_test_suite() {
    local suite_name="$1"
    local script_path="$2"
    local description="$3"
    
    ((TOTAL_SUITES++))
    
    echo "========================================="
    echo "Test Suite: $suite_name"
    echo "Description: $description"
    echo "========================================="
    
    if [[ ! -f "$script_path" ]]; then
        error "Test script not found: $script_path"
        ((FAILED_SUITES++))
        return 1
    fi
    
    if ! chmod +x "$script_path" 2>/dev/null; then
        warn "Could not make test script executable"
    fi
    
    if "$script_path"; then
        log "✅ Test suite '$suite_name' PASSED"
        ((PASSED_SUITES++))
        return 0
    else
        error "❌ Test suite '$suite_name' FAILED"
        ((FAILED_SUITES++))
        return 1
    fi
}

# Run all test suites
echo "Starting comprehensive test execution..."
echo ""

# Suite 1: Basic GitLab API functionality
run_test_suite "Basic API" \
    "$SCRIPT_DIR/test_suite_runner.sh" \
    "Basic GitLab API connectivity and CRUD operations"

echo ""

# Suite 2: Integration testing (agent simulation)
run_test_suite "Integration" \
    "$SCRIPT_DIR/test_integration.sh" \
    "project-task-updater agent workflow simulation"

echo ""

# Suite 3: Agent-specific pattern testing
run_test_suite "Agent Patterns" \
    "$SCRIPT_DIR/test_agent_specific.sh" \
    "Specific patterns and bugs in project-task-updater agent"

echo ""

# Suite 4: Authentication and security testing
run_test_suite "Authentication" \
    "$SCRIPT_DIR/test_auth_patterns.sh" \
    "Authentication methods and security validation"

echo ""

# Overall Results
echo "========================================="
echo "COMPREHENSIVE TEST RESULTS"
echo "========================================="
echo "Total Test Suites: $TOTAL_SUITES"
echo "Passed: $PASSED_SUITES"
echo "Failed: $FAILED_SUITES"
echo "Success Rate: $(( PASSED_SUITES * 100 / TOTAL_SUITES ))%"
echo ""

# Issue #63 Analysis
if [[ $FAILED_SUITES -gt 0 ]]; then
    echo "🔍 ISSUE #63 ANALYSIS:"
    echo "❌ Tests failed - GitLab API communication issues confirmed"
    echo ""
    echo "RECOMMENDED ACTIONS:"
    echo "1. 🔧 Fix agent configuration (variable usage)"
    echo "2. 🔑 Verify GitLab token setup"  
    echo "3. 🧪 Run individual failing test suites for details"
    echo "4. 📝 Update agent documentation"
    echo ""
    echo "PRIORITY: HIGH - project-task-updater agent needs fixes"
else
    echo "🎉 ISSUE #63 ANALYSIS:"
    echo "✅ All tests passed - GitLab API communication working"
    echo ""
    echo "POSSIBLE CAUSES OF ORIGINAL ISSUE:"
    echo "1. 🕒 Temporary network/server issue (now resolved)"
    echo "2. 🔄 Token was refreshed since issue was created"
    echo "3. 🔧 Configuration was already fixed"
    echo "4. 🎯 Issue exists only in specific environments"
    echo ""
    echo "RECOMMENDED ACTION: Mark Issue #63 as investigated/resolved"
fi

# Generate summary report
REPORT_FILE="$SCRIPT_DIR/test_results_$(date +%Y%m%d_%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# GitLab API Test Results - Issue #63

**Date**: $(date)
**Issue**: Fix project-task-updater agent GitLab API communication

## Test Results Summary

- **Total Test Suites**: $TOTAL_SUITES
- **Passed**: $PASSED_SUITES  
- **Failed**: $FAILED_SUITES
- **Success Rate**: $(( PASSED_SUITES * 100 / TOTAL_SUITES ))%

## Test Suites Executed

1. **Basic API Tests**: Core GitLab API functionality
2. **Integration Tests**: project-task-updater workflow simulation  
3. **Agent Pattern Tests**: Specific agent configuration validation
4. **Authentication Tests**: Token and security validation

## Issue #63 Status

$(if [[ $FAILED_SUITES -gt 0 ]]; then
    echo "**Status**: 🔴 CONFIRMED - Issues found requiring fixes"
    echo ""
    echo "**Root Causes Identified**:"
    echo "- Agent configuration issues"
    echo "- Token handling problems"  
    echo "- API communication protocol issues"
else
    echo "**Status**: ✅ CANNOT REPRODUCE - All tests pass"
    echo ""
    echo "**Possible Explanations**:"
    echo "- Issue was temporary and has been resolved"
    echo "- Configuration has been fixed since issue creation"
    echo "- Issue occurs only in specific environments"
fi)

## Next Steps

$(if [[ $FAILED_SUITES -gt 0 ]]; then
    echo "1. Fix identified agent configuration issues"
    echo "2. Update project-task-updater agent documentation"
    echo "3. Implement proper error handling"
    echo "4. Re-run test suite to validate fixes"
else
    echo "1. Mark Issue #63 as investigated"
    echo "2. Document current working state"  
    echo "3. Consider adding monitoring for future issues"
    echo "4. Update agent to use best practices"
fi)

---
Generated by GitLab API Test Suite
EOF

info "Test summary report generated: $REPORT_FILE"

# Exit with appropriate code
if [[ $FAILED_SUITES -gt 0 ]]; then
    exit 1
else
    exit 0
fi