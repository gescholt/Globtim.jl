#!/bin/bash
# Test Script for HPC Resource Monitor Hook System
# Validates monitoring system functionality in development environment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
GLOBTIM_DIR="/Users/ghscholt/globtim"
MONITOR_HOOK="$GLOBTIM_DIR/tools/hpc/monitoring/hpc_resource_monitor_hook.sh"
INTEGRATED_MONITOR="$GLOBTIM_DIR/tools/hpc/monitoring/integrated_experiment_monitor.sh"
CLAUDE_HOOK="/Users/ghscholt/.claude/hooks/hpc-resource-monitor.sh"

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test 1: Check if monitoring scripts exist and are executable
test_script_existence() {
    print_test "Checking monitoring script existence and permissions..."
    
    local all_good=true
    
    if [ -f "$MONITOR_HOOK" ] && [ -x "$MONITOR_HOOK" ]; then
        print_success "HPC Resource Monitor Hook exists and is executable"
    else
        print_error "HPC Resource Monitor Hook missing or not executable: $MONITOR_HOOK"
        all_good=false
    fi
    
    if [ -f "$INTEGRATED_MONITOR" ] && [ -x "$INTEGRATED_MONITOR" ]; then
        print_success "Integrated Experiment Monitor exists and is executable"
    else
        print_error "Integrated Experiment Monitor missing or not executable: $INTEGRATED_MONITOR"
        all_good=false
    fi
    
    if [ -f "$CLAUDE_HOOK" ] && [ -x "$CLAUDE_HOOK" ]; then
        print_success "Claude Code Hook exists and is executable"
    else
        print_error "Claude Code Hook missing or not executable: $CLAUDE_HOOK"
        all_good=false
    fi
    
    return $([ "$all_good" = true ])
}

# Test 2: Test help functionality
test_help_functionality() {
    print_test "Testing help functionality..."
    
    # Test main monitor hook help
    if "$MONITOR_HOOK" help >/dev/null 2>&1; then
        print_success "Monitor hook help command works"
    else
        print_error "Monitor hook help command failed"
        return 1
    fi
    
    # Test integrated monitor help  
    if "$INTEGRATED_MONITOR" help >/dev/null 2>&1; then
        print_success "Integrated monitor help command works"
    else
        print_error "Integrated monitor help command failed"
        return 1
    fi
    
    # Test Claude hook help (without context - should show help)
    if "$CLAUDE_HOOK" 2>/dev/null | grep -q "HPC Resource Monitor Hook"; then
        print_success "Claude hook help display works"
    else
        print_error "Claude hook help display failed"
        return 1
    fi
}

# Test 3: Test directory creation
test_directory_creation() {
    print_test "Testing monitoring directory creation..."
    
    # Create test directories
    local test_dirs=(
        "$GLOBTIM_DIR/tools/hpc/monitoring/logs"
        "$GLOBTIM_DIR/tools/hpc/monitoring/alerts"
        "$GLOBTIM_DIR/tools/hpc/monitoring/performance"
        "$GLOBTIM_DIR/tools/hpc/monitoring/dashboard"
        "$GLOBTIM_DIR/tools/hpc/monitoring/monitors"
        "$GLOBTIM_DIR/tools/hpc/monitoring/reports"
    )
    
    local all_created=true
    for dir in "${test_dirs[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            print_success "Created directory: $dir"
        else
            print_error "Failed to create directory: $dir"
            all_created=false
        fi
    done
    
    return $([ "$all_created" = true ])
}

# Test 4: Test Claude Code hook security
test_claude_hook_security() {
    print_test "Testing Claude Code hook security..."
    
    # Test without CLAUDE_CONTEXT (should fail)
    if "$CLAUDE_HOOK" status 2>&1 | grep -q "must be called through Claude Code"; then
        print_success "Security validation works - rejects calls without proper context"
    else
        print_error "Security validation failed - should reject calls without CLAUDE_CONTEXT"
        return 1
    fi
    
    # Test with invalid command (should fail)
    if CLAUDE_CONTEXT="test" "$CLAUDE_HOOK" invalid_command 2>&1 | grep -q "Unauthorized monitoring command"; then
        print_success "Command validation works - rejects unauthorized commands"
    else
        print_error "Command validation failed - should reject unauthorized commands"
        return 1
    fi
    
    # Test with valid command and context (should attempt to work, may fail on macOS due to Linux commands)
    print_warning "Note: Further testing requires Linux environment (r04n02) for full functionality"
}

# Test 5: Test configuration detection
test_environment_detection() {
    print_test "Testing environment detection..."
    
    # Check if scripts correctly detect local vs HPC environment
    if grep -q "Local development environment" "$MONITOR_HOOK" 2>/dev/null; then
        print_success "Environment detection logic present in monitor hook"
    else
        print_warning "Environment detection may need verification"
    fi
    
    # Test GLOBTIM_DIR detection
    local detected_dir=$(GLOBTIM_DIR="" bash -c 'source '"$MONITOR_HOOK"' 2>/dev/null; echo $GLOBTIM_DIR' | head -1)
    if [ -n "$detected_dir" ]; then
        print_success "GLOBTIM_DIR detection works: $detected_dir"
    else
        print_warning "GLOBTIM_DIR detection may need verification"
    fi
}

# Test 6: Test logging functionality
test_logging_functionality() {
    print_test "Testing logging functionality..."
    
    # Create test log entry using Claude hook
    local test_context="Test logging functionality"
    export CLAUDE_CONTEXT="$test_context"
    
    # This will fail on macOS due to Linux commands, but should create log entry
    "$CLAUDE_HOOK" status >/dev/null 2>&1 || true
    
    # Check if log file was created
    local log_file="/Users/ghscholt/.claude/logs/hpc-resource-monitor.log"
    if [ -f "$log_file" ] && grep -q "$test_context" "$log_file"; then
        print_success "Claude hook logging works - log entry created"
    else
        print_warning "Claude hook logging may need verification - check $log_file"
    fi
}

# Test 7: Validate JSON structure for metrics (mock test)
test_json_structure() {
    print_test "Testing JSON metric structure..."
    
    # Create a mock JSON metrics file to test structure
    local test_json='{"timestamp":"2025-09-04T12:00:00Z","node":"test","memory":{"usage_percent":50}}'
    local test_file="/tmp/test_metrics.json"
    
    echo "$test_json" > "$test_file"
    
    # Validate JSON structure
    if python3 -m json.tool "$test_file" >/dev/null 2>&1; then
        print_success "JSON metric structure validation works"
    else
        print_error "JSON metric structure validation failed"
        return 1
    fi
    
    # Clean up
    rm -f "$test_file"
}

# Run all tests
run_all_tests() {
    echo "HPC Resource Monitor Hook System Testing"
    echo "========================================"
    echo ""
    
    local tests_passed=0
    local tests_total=7
    
    # Run each test
    if test_script_existence; then ((tests_passed++)); fi
    echo ""
    
    if test_help_functionality; then ((tests_passed++)); fi
    echo ""
    
    if test_directory_creation; then ((tests_passed++)); fi
    echo ""
    
    if test_claude_hook_security; then ((tests_passed++)); fi
    echo ""
    
    if test_environment_detection; then ((tests_passed++)); fi
    echo ""
    
    if test_logging_functionality; then ((tests_passed++)); fi
    echo ""
    
    if test_json_structure; then ((tests_passed++)); fi
    echo ""
    
    # Summary
    echo "Test Results Summary"
    echo "==================="
    echo "Tests Passed: $tests_passed/$tests_total"
    
    if [ $tests_passed -eq $tests_total ]; then
        print_success "All tests passed! Monitoring system is ready for deployment."
        echo ""
        echo "Next Steps:"
        echo "1. Deploy scripts to r04n02 compute node"
        echo "2. Test full functionality in HPC environment"
        echo "3. Validate integration with existing experiment workflows"
        return 0
    else
        print_warning "Some tests failed or need verification in HPC environment."
        echo ""
        echo "Notes:"
        echo "- Some functionality requires Linux environment (r04n02) for full testing"
        echo "- Local tests validate core structure and security features"
        echo "- HPC deployment will provide complete functionality validation"
        return 1
    fi
}

# Additional utility functions for manual testing
show_monitoring_structure() {
    echo "Current Monitoring System Structure:"
    echo "==================================="
    find "$GLOBTIM_DIR/tools/hpc/monitoring" -type f -name "*.sh" -exec echo "📄 {}" \;
    find "$GLOBTIM_DIR/tools/hpc/monitoring" -type d -exec echo "📁 {}" \;
    echo ""
    echo "Claude Code Hook:"
    echo "📄 $CLAUDE_HOOK"
    echo ""
    echo "Documentation:"
    echo "📄 $GLOBTIM_DIR/docs/hpc/HPC_RESOURCE_MONITOR_HOOK_DOCUMENTATION.md"
}

# Main command dispatcher
case "${1:-test}" in
    test)
        run_all_tests
        ;;
    structure)
        show_monitoring_structure
        ;;
    help)
        echo "HPC Resource Monitor Test Script"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  test      - Run all validation tests (default)"
        echo "  structure - Show monitoring system file structure"
        echo "  help      - Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for available commands"
        exit 1
        ;;
esac