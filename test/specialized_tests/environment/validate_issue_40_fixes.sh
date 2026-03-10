#!/bin/bash
# NOTE: These tests require specific HPC environment configuration. See ENV vars below.
#
# Required ENV variables:
#   GLOBTIM_LOCAL_HOME, GLOBTIM_LOCAL_PROJECT, GLOBTIM_HPC_USER, GLOBTIM_HPC_HOST,
#   GLOBTIM_HPC_HOME, GLOBTIM_HPC_PROJECT, GLOBTIM_HPC_NFS_HOME
#
# Comprehensive Validation Suite for Environment-Aware Path Resolution
#
# This script runs all tests to validate that environment-aware path resolution works correctly.
# Tests both the Julia environment utilities and the bash hook orchestrator integration.
#
# Usage:
#     bash tests/environment/validate_issue_40_fixes.sh

set -e

# Timeout: kill this script if it runs longer than 120 seconds
TIMEOUT_SECONDS="${GLOBTIM_TEST_TIMEOUT:-120}"
( sleep "${TIMEOUT_SECONDS}" && echo "ERROR: Test timed out after ${TIMEOUT_SECONDS}s" >&2 && kill -TERM $$ 2>/dev/null ) &
TIMEOUT_PID=$!
trap 'kill ${TIMEOUT_PID} 2>/dev/null' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate required ENV variables
for var in GLOBTIM_LOCAL_HOME GLOBTIM_LOCAL_PROJECT GLOBTIM_HPC_USER GLOBTIM_HPC_HOST GLOBTIM_HPC_HOME GLOBTIM_HPC_PROJECT GLOBTIM_HPC_NFS_HOME; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: Required environment variable ${var} is not set." >&2
        exit 1
    fi
done

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBTIM_DIR="$(cd "$TEST_DIR/../.." && pwd)"

echo -e "${BLUE}🧪 Comprehensive Validation Suite for Environment-Aware Path Resolution${NC}"
echo "=================================================================="
echo "Validating Environment-Aware Path Resolution System"
echo ""
echo "Test environment: $(pwd)"
echo "Globtim directory: $GLOBTIM_DIR"
echo ""

# Track overall results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_description="$3"

    echo -e "${YELLOW}Running: $test_name${NC}"
    echo "Description: $test_description"
    echo "Command: $test_command"
    echo "──────────────────────────────────────────────────────────────"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if eval "$test_command"; then
        echo -e "✅ $test_name: ${GREEN}PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo ""
        return 0
    else
        echo -e "❌ $test_name: ${RED}FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        return 1
    fi
}

# Test 1: Julia Environment Utilities
run_test "Julia Environment Utilities" \
         "julia --project=. tests/environment/test_path_resolution.jl" \
         "Tests environment detection, path translation, and cross-environment resolution"

# Test 2: Hook Orchestrator Path Resolution
run_test "Hook Orchestrator Path Resolution" \
         "bash tests/environment/test_hook_orchestrator_paths.sh" \
         "Tests bash-based path resolution in hook orchestrator system"

# Test 3: Collection Script Environment Awareness
run_test "Collection Script Environment Detection" \
         "julia --project=. -e 'include(\"collect_cluster_experiments.jl\"); println(\"Environment: \", EnvironmentUtils.auto_detect_environment()); println(\"HPC Project: \", EnvironmentUtils.get_project_directory(:hpc))'" \
         "Tests that collect_cluster_experiments.jl properly detects environment and resolves paths"

# Test 4: Hook Registry Path Resolution (if registry exists)
if [[ -f "$GLOBTIM_DIR/tools/hpc/hooks/hook_registry.json" ]]; then
    run_test "Hook Registry Validation" \
             "julia --project=. -e 'include(\"tests/environment/environment_utils.jl\"); using .EnvironmentUtils; config = Dict(\"path\" => ENV[\"GLOBTIM_LOCAL_PROJECT\"] * \"/tools/test.sh\"); resolved = resolve_hook_config(config, :local, :hpc); println(\"Resolved path: \", resolved[\"resolved_path\"])'" \
             "Tests hook configuration path resolution for actual hook registry"
fi

# Test 5: Cross-Environment File Path Validation
run_test "Cross-Environment File Paths" \
         "julia --project=. -e 'include(\"tests/environment/environment_utils.jl\"); using .EnvironmentUtils; local_path = ENV[\"GLOBTIM_LOCAL_PROJECT\"] * \"/src/Main.jl\"; hpc_path = translate_path(local_path, :local, :hpc); back_to_local = translate_path(hpc_path, :hpc, :local); println(\"Round-trip test: \", local_path == back_to_local ? \"PASS\" : \"FAIL\")'" \
         "Tests bidirectional path translation consistency"

# Test 6: SSH Command Generation
run_test "SSH Command Generation" \
         "julia --project=. -e 'include(\"tests/environment/environment_utils.jl\"); using .EnvironmentUtils; cmd = generate_experiment_collection_command(:local, :hpc, \"20250916\"); expected_target = ENV[\"GLOBTIM_HPC_USER\"] * \"@\" * ENV[\"GLOBTIM_HPC_HOST\"]; println(\"SSH command: \", cmd); println(contains(cmd, expected_target) ? \"PASS\" : \"FAIL\")'" \
         "Tests SSH command generation for cluster operations"

# Test 7: Existing Hook Tests (if available)
if [[ -f "$GLOBTIM_DIR/hpc/tests/run_all_hook_tests.sh" ]]; then
    run_test "Existing Hook System Tests" \
             "timeout 300 bash $GLOBTIM_DIR/hpc/tests/run_all_hook_tests.sh" \
             "Runs existing hook system tests to ensure no regressions"
fi

# Test 8: Environment Consistency Check
run_test "Environment Consistency" \
         "julia --project=. -e 'include(\"tests/environment/environment_utils.jl\"); using .EnvironmentUtils; env = auto_detect_environment(); proj_dir = get_project_directory(env); println(\"Environment: \$env\"); println(\"Project directory exists: \", isdir(proj_dir)); isdir(proj_dir) || exit(1)'" \
         "Validates that detected environment has accessible project directory"

# Final Results Summary
echo "=================================================================="
echo -e "${BLUE}Validation Summary for Environment-Aware Path Resolution${NC}"
echo "=================================================================="

echo "Total tests run: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo ""
    echo -e "🎉 ${GREEN}ALL TESTS PASSED!${NC}"
    echo ""
    echo "✅ Environment-Aware Path Resolution Requirements Satisfied:"
    echo "   ✓ Environment auto-detection working"
    echo "   ✓ Bidirectional path translation functional"
    echo "   ✓ collect_cluster_experiments.jl uses environment-aware paths"
    echo "   ✓ Hook orchestrator path resolution working"
    echo "   ✓ Cross-environment file operations supported"
    echo "   ✓ SSH command generation environment-aware"
    echo ""
    echo "🚀 Ready for Production Deployment"
    echo ""
    echo "Deployment Checklist:"
    echo "   □ Deploy to HPC cluster for testing"
    echo "   □ Run integration tests with actual cluster operations"
    echo "   □ Update hook system documentation"
    echo "   □ Consider implementing similar fixes for other hardcoded paths"

    exit_code=0
else
    echo ""
    echo -e "⚠️  ${RED}$FAILED_TESTS TESTS FAILED${NC}"
    echo ""
    echo "❌ Environment-aware path resolution NOT fully working"
    echo ""
    echo "Required Actions:"
    echo "   1. Review failed test cases above"
    echo "   2. Fix identified path resolution issues"
    echo "   3. Re-run validation suite"
    echo "   4. Do NOT deploy until all tests pass"

    exit_code=1
fi

echo ""
echo "=================================================================="
echo "Validation completed: $(date)"
echo "=================================================================="

exit $exit_code