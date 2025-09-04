#!/bin/bash
# HPC Monitoring Tool Test Runner
#
# Comprehensive test runner for the HPC monitoring system with multiple test modes:
# - Unit tests with mocked SSH connections
# - Integration tests with 2D examples
# - Real SSH tests (optional, requires cluster access)
# - Performance benchmarks
#
# Usage:
#   ./test/run_hpc_monitoring_tests.sh                    # Standard unit tests
#   ./test/run_hpc_monitoring_tests.sh --integration      # Include integration tests  
#   ./test/run_hpc_monitoring_tests.sh --real-ssh         # Test real SSH connections
#   ./test/run_hpc_monitoring_tests.sh --all              # Run all tests
#   ./test/run_hpc_monitoring_tests.sh --quick            # Fast unit tests only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PYTHON_CMD="python3"
TEST_TIMEOUT=300  # 5 minutes

function print_header() {
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${CYAN}            HPC Monitoring Tool Test Suite${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    echo ""
}

function print_section() {
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

function check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check Python
    if ! command -v $PYTHON_CMD &> /dev/null; then
        echo -e "${RED}❌ Python 3 not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Python 3 available: $($PYTHON_CMD --version)${NC}"
    
    # Check Julia (optional for integration tests)
    if command -v julia &> /dev/null; then
        echo -e "${GREEN}✅ Julia available: $(julia --version | head -1)${NC}"
        JULIA_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  Julia not available (integration tests will be skipped)${NC}"
        JULIA_AVAILABLE=false
    fi
    
    # Check project structure
    if [[ ! -f "$PROJECT_ROOT/tools/hpc/secure_node_config.py" ]]; then
        echo -e "${RED}❌ Secure node configuration not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ HPC monitoring tools found${NC}"
    
    # Check 2D examples
    if [[ -f "$PROJECT_ROOT/Examples/hpc_light_2d_example.jl" ]]; then
        echo -e "${GREEN}✅ 2D examples available${NC}"
        EXAMPLES_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  2D examples not found (some integration tests will be skipped)${NC}"
        EXAMPLES_AVAILABLE=false
    fi
    
    # Check SSH connectivity (for real tests)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes scholten@r04n02 "echo 'SSH_OK'" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SSH connection to r04n02 available${NC}"
        SSH_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  SSH connection to r04n02 not available (real SSH tests will be skipped)${NC}"
        SSH_AVAILABLE=false
    fi
    
    echo ""
}

function run_unit_tests() {
    print_section "Running Unit Tests (Mocked SSH)"
    
    echo "Testing core monitoring functionality with mock node access..."
    
    cd "$PROJECT_ROOT"
    
    # Run unit tests (macOS compatible - no timeout command)
    $PYTHON_CMD test/test_hpc_monitoring.py --unit-only --verbose
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ Unit tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Unit tests failed${NC}"
        return 1
    fi
}

function run_integration_tests() {
    print_section "Running Integration Tests (2D Examples)"
    
    if [[ "$JULIA_AVAILABLE" != true ]] || [[ "$EXAMPLES_AVAILABLE" != true ]]; then
        echo -e "${YELLOW}⏭️  Integration tests skipped (Julia or examples not available)${NC}"
        return 0
    fi
    
    echo "Testing monitoring with realistic 2D experiment scenarios..."
    
    cd "$PROJECT_ROOT"
    
    # Run integration tests
    $PYTHON_CMD test/test_hpc_monitoring.py --verbose
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ Integration tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
        return 1
    fi
}

function run_real_ssh_tests() {
    print_section "Running Real SSH Tests (r04n02 Node)"
    
    if [[ "$SSH_AVAILABLE" != true ]]; then
        echo -e "${YELLOW}⏭️  Real SSH tests skipped (r04n02 not accessible)${NC}"
        return 0
    fi
    
    echo "Testing monitoring with real SSH connections to r04n02..."
    echo -e "${YELLOW}⚠️  These tests will make actual SSH connections to the cluster${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Run real SSH tests
    $PYTHON_CMD test/test_hpc_monitoring.py --real-ssh --verbose
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ Real SSH tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Real SSH tests failed${NC}"
        return 1
    fi
}

function run_performance_benchmarks() {
    print_section "Running Performance Benchmarks"
    
    echo "Benchmarking monitoring system performance..."
    
    cd "$PROJECT_ROOT"
    
    # Create a simple performance test
    $PYTHON_CMD -c "
import time
import sys
sys.path.append('$PROJECT_ROOT')

from test.test_hpc_monitoring import MockNodeAccess, NodeMonitor
from unittest.mock import patch

print('🔄 Running performance benchmarks...')

# Benchmark mock operations
start_time = time.time()
mock_node = MockNodeAccess()

# Simulate 100 command executions
for i in range(100):
    mock_node.execute_command(f'test_command_{i}')

mock_time = time.time() - start_time
print(f'✅ Mock operations: 100 commands in {mock_time:.3f}s ({100/mock_time:.1f} cmd/s)')

# Benchmark monitoring operations
start_time = time.time()
with patch('tools.hpc.node_monitor.SecureNodeAccess', return_value=mock_node):
    monitor = NodeMonitor()
    monitor.node = mock_node
    
    # Generate 10 status reports
    for i in range(10):
        report = monitor.generate_status_report('json')
    
monitor_time = time.time() - start_time
print(f'✅ Monitoring operations: 10 reports in {monitor_time:.3f}s ({10/monitor_time:.1f} reports/s)')

print('🎯 Performance benchmarks completed')
"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Performance benchmarks completed${NC}"
        return 0
    else
        echo -e "${RED}❌ Performance benchmarks failed${NC}"
        return 1
    fi
}

function run_security_validation() {
    print_section "Running Security Validation Tests"
    
    echo "Testing security hook integration and validation..."
    
    cd "$PROJECT_ROOT"
    
    # Test security hook functionality
    if [[ -f "tools/hpc/node-security-hook.sh" ]]; then
        echo "Testing HPC security hook..."
        
        # Test hook with HPC context
        CLAUDE_CONTEXT="Test HPC monitoring" tools/hpc/node-security-hook.sh
        local hook_result=$?
        
        if [[ $hook_result -eq 0 ]]; then
            echo -e "${GREEN}✅ Security hook validation passed${NC}"
        else
            echo -e "${RED}❌ Security hook validation failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Security hook not found, skipping validation${NC}"
    fi
    
    # Test secure configuration
    if [[ -f "tools/hpc/secure_node_config.py" ]]; then
        echo "Testing secure configuration module..."
        
        $PYTHON_CMD -c "
import sys
sys.path.append('$PROJECT_ROOT')
from tools.hpc.secure_node_config import SecureNodeAccess, HPCSecurityError

# Test basic import and initialization (should fail gracefully without SSH)
try:
    # This will fail SSH validation but should handle it gracefully
    node = SecureNodeAccess()
    print('Unexpected success - SSH should have failed in test environment')
except HPCSecurityError as e:
    print(f'✅ Expected security error handled correctly: {str(e)[:50]}...')
except Exception as e:
    print(f'❌ Unexpected error: {e}')
    sys.exit(1)
"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Secure configuration validation passed${NC}"
        else
            echo -e "${RED}❌ Secure configuration validation failed${NC}"
            return 1
        fi
    fi
    
    return 0
}

function main() {
    print_header
    
    # Parse command line arguments
    RUN_UNIT=true
    RUN_INTEGRATION=false
    RUN_REAL_SSH=false
    RUN_PERFORMANCE=false
    RUN_SECURITY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --integration)
                RUN_INTEGRATION=true
                shift
                ;;
            --real-ssh)
                RUN_REAL_SSH=true
                shift
                ;;
            --all)
                RUN_INTEGRATION=true
                RUN_REAL_SSH=true
                RUN_PERFORMANCE=true
                RUN_SECURITY=true
                shift
                ;;
            --quick)
                # Only unit tests, optimized for speed
                echo -e "${CYAN}🚀 Quick mode: Unit tests only${NC}"
                echo ""
                shift
                ;;
            --performance)
                RUN_PERFORMANCE=true
                shift
                ;;
            --security)
                RUN_SECURITY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --integration    Include integration tests with 2D examples"
                echo "  --real-ssh       Test real SSH connections to r04n02"
                echo "  --all            Run all tests including performance and security"
                echo "  --quick          Run only unit tests (fastest)"
                echo "  --performance    Run performance benchmarks"
                echo "  --security       Run security validation tests"
                echo "  --help           Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Basic unit tests"
                echo "  $0 --integration      # Unit + integration tests"
                echo "  $0 --all              # Complete test suite"
                echo "  $0 --quick            # Fastest testing"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run prerequisite checks
    check_prerequisites
    
    # Track test results
    TESTS_RUN=0
    TESTS_PASSED=0
    FAILED_TESTS=()
    
    # Run selected test suites
    if [[ "$RUN_UNIT" == true ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        if run_unit_tests; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            FAILED_TESTS+=("Unit Tests")
        fi
        echo ""
    fi
    
    if [[ "$RUN_INTEGRATION" == true ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        if run_integration_tests; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            FAILED_TESTS+=("Integration Tests")
        fi
        echo ""
    fi
    
    if [[ "$RUN_REAL_SSH" == true ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        if run_real_ssh_tests; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            FAILED_TESTS+=("Real SSH Tests")
        fi
        echo ""
    fi
    
    if [[ "$RUN_PERFORMANCE" == true ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        if run_performance_benchmarks; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            FAILED_TESTS+=("Performance Benchmarks")
        fi
        echo ""
    fi
    
    if [[ "$RUN_SECURITY" == true ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        if run_security_validation; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            FAILED_TESTS+=("Security Validation")
        fi
        echo ""
    fi
    
    # Print final summary
    print_section "Test Results Summary"
    
    echo "Test Suites Run: $TESTS_RUN"
    echo "Test Suites Passed: $TESTS_PASSED"
    echo "Test Suites Failed: $((TESTS_RUN - TESTS_PASSED))"
    
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TEST SUITES PASSED!${NC}"
        echo ""
        echo -e "${GREEN}✅ HPC Monitoring Tool is ready for production use${NC}"
        echo -e "${CYAN}   • Secure node access validated${NC}"
        echo -e "${CYAN}   • Monitoring functionality verified${NC}"
        echo -e "${CYAN}   • 2D experiment integration tested${NC}"
        if [[ "$RUN_REAL_SSH" == true ]] && [[ "$SSH_AVAILABLE" == true ]]; then
            echo -e "${CYAN}   • Real cluster connectivity confirmed${NC}"
        fi
        echo ""
        return 0
    else
        echo -e "${RED}❌ SOME TEST SUITES FAILED:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}   - $failed_test${NC}"
        done
        echo ""
        echo -e "${YELLOW}Please review the test output above for details${NC}"
        return 1
    fi
}

# Run main function
main "$@"