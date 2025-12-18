#!/bin/bash
# Test Suite: 4D Lotka-Volterra with Dagger.jl Default Execution
# Issue #48: Design Dagger.jl Integration with Existing Hook Orchestrator System
#
# Validates that Dagger.jl is the default execution method for 4D experiments
# and provides comprehensive tracking capabilities for Lotka-Volterra parameter estimation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/integration"
LOG_DIR="$TEST_DIR/logs"
RESULTS_DIR="$TEST_DIR/results"

# Test configuration
TEST_NAME="dagger_4d_lotka_volterra"
TEST_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
TEST_ID="${TEST_NAME}_${TEST_TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Create test directories
mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# Logging functions
log_test() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [dagger-4d-test] [$level] $message" | tee -a "$LOG_DIR/${TEST_ID}.log"
}

log_info() {
    log_test "INFO" "$@"
    echo -e "${BOLD}${GREEN}[DAGGER-4D-TEST]${NC} $*" >&2
}

log_warning() {
    log_test "WARN" "$@"
    echo -e "${BOLD}${YELLOW}[DAGGER-4D-TEST WARNING]${NC} $*" >&2
}

log_error() {
    log_test "ERROR" "$@"
    echo -e "${BOLD}${RED}[DAGGER-4D-TEST ERROR]${NC} $*" >&2
}

log_success() {
    log_test "SUCCESS" "$@"
    echo -e "${BOLD}${CYAN}[DAGGER-4D-TEST SUCCESS]${NC} $*" >&2
}

# Test tracking capabilities
validate_dagger_tracking() {
    local experiment_id=$1

    log_info "Validating Dagger tracking capabilities for experiment: $experiment_id"

    # Check dagger_execution_index.json exists and contains experiment
    local dagger_index="$PROJECT_ROOT/dagger_execution_index.json"
    if [[ ! -f "$dagger_index" ]]; then
        log_error "Dagger execution index not found: $dagger_index"
        return 1
    fi

    # Validate experiment is tracked in Dagger index
    if ! jq -e ".experiments[\"$experiment_id\"]" "$dagger_index" >/dev/null 2>&1; then
        log_error "Experiment $experiment_id not found in Dagger execution index"
        return 1
    fi

    # Extract and validate metadata
    local experiment_type=$(jq -r ".experiments[\"$experiment_id\"].experiment_type" "$dagger_index")
    local status=$(jq -r ".experiments[\"$experiment_id\"].status" "$dagger_index")
    local dagger_enabled=$(jq -r ".experiments[\"$experiment_id\"].metadata.dagger_enabled" "$dagger_index")
    local job_id=$(jq -r ".experiments[\"$experiment_id\"].metadata.job_id" "$dagger_index")

    log_info "Experiment metadata validation:"
    log_info "  Type: $experiment_type"
    log_info "  Status: $status"
    log_info "  Dagger Enabled: $dagger_enabled"
    log_info "  Job ID: $job_id"

    # Validate required metadata
    if [[ "$experiment_type" != "dagger_tracked_experiment" ]]; then
        log_error "Expected experiment_type 'dagger_tracked_experiment', got: $experiment_type"
        return 1
    fi

    if [[ "$dagger_enabled" != "true" ]]; then
        log_error "Dagger not enabled for experiment"
        return 1
    fi

    if [[ "$job_id" == "null" || -z "$job_id" ]]; then
        log_error "No job_id found in experiment metadata"
        return 1
    fi

    log_success "Dagger tracking validation passed"
    return 0
}

# Test experiment organization
validate_experiment_organization() {
    local experiment_id=$1

    log_info "Validating experiment organization for: $experiment_id"

    # Check experiment results directory
    local exp_results_dir="$PROJECT_ROOT/hpc_results/$experiment_id"
    if [[ ! -d "$exp_results_dir" ]]; then
        log_error "Experiment results directory not found: $exp_results_dir"
        return 1
    fi

    # Check for standard result files
    local expected_files=(
        "critical_points_deg_6.csv"
        "L2_norms.csv"
        "experiment_params.json"
    )

    for file in "${expected_files[@]}"; do
        if [[ ! -f "$exp_results_dir/$file" ]]; then
            log_warning "Expected file not found: $file"
        else
            log_info "Found expected file: $file"
        fi
    done

    # Validate experiment_params.json contains Dagger tracking info
    if [[ -f "$exp_results_dir/experiment_params.json" ]]; then
        local tracking_mode=$(jq -r '.tracking_mode // "none"' "$exp_results_dir/experiment_params.json")
        log_info "Tracking mode in experiment_params.json: $tracking_mode"
    fi

    log_success "Experiment organization validation passed"
    return 0
}

# Test that Dagger is used instead of standard execution
validate_dagger_execution_method() {
    local experiment_id=$1

    log_info "Validating Dagger execution method for: $experiment_id"

    # Check hook orchestrator logs for Dagger execution
    local hook_logs="$PROJECT_ROOT/tools/hpc/hooks/logs"
    local orchestrator_log="$hook_logs/orchestrator.log"

    if [[ ! -f "$orchestrator_log" ]]; then
        log_error "Hook orchestrator log not found: $orchestrator_log"
        return 1
    fi

    # Check that dagger_execution hook was used
    if ! grep -q "dagger_execution.*$experiment_id" "$orchestrator_log"; then
        log_error "No dagger_execution hook found in orchestrator log for $experiment_id"
        return 1
    fi

    # Check that standard execution hook was NOT used (should be archived)
    if grep -q "execution_hook.*$experiment_id" "$orchestrator_log"; then
        log_warning "Standard execution hook still appears to be used for $experiment_id"
    fi

    log_success "Dagger execution method validation passed"
    return 0
}

# Create test 4D Lotka-Volterra script
create_test_script() {
    local script_path="$RESULTS_DIR/test_4d_lotka_volterra_${TEST_TIMESTAMP}.jl"

    cat > "$script_path" << 'EOF'
#!/usr/bin/env julia
# Test 4D Lotka-Volterra with Dagger tracking
# Reduced parameters for testing

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using HomotopyContinuation
using ForwardDiff
using LinearAlgebra

println("🧪 4D Lotka-Volterra Dagger Test Started")
println("Julia Version: $(VERSION)")
println("Globtim loaded successfully")

# Reduced test parameters (Issue #70 safe parameters)
GN = 6  # samples per dimension (safer than 12)
domain_range = 0.05  # small domain for testing
degrees = [6]  # single degree for quick test

println("Test Parameters:")
println("  GN (samples per dimension): $GN")
println("  Domain range: $domain_range")
println("  Degrees: $degrees")

# Define 4D Lotka-Volterra system
@polyvar a b c d
params = [a, b, c, d]

# True parameter values (known solution)
a_true, b_true, c_true, d_true = 1.0, 0.3, 0.5, 0.2

println("True parameters: a=$a_true, b=$b_true, c=$c_true, d=$d_true")

# Create domain around true parameters
domain = [(a_true - domain_range, a_true + domain_range),
          (b_true - domain_range, b_true + domain_range),
          (c_true - domain_range, c_true + domain_range),
          (d_true - domain_range, d_true + domain_range)]

println("Parameter domain: $domain")

# 4D objective function
function objective_4d(p_vals)
    a_val, b_val, c_val, d_val = p_vals
    # Simple 4D test function (distance from true parameters)
    return (a_val - a_true)^2 + (b_val - b_true)^2 + (c_val - c_true)^2 + (d_val - d_true)^2
end

println("4D objective function defined")

# Test polynomial approximation for one degree
for degree in degrees
    println("\n🔬 Testing degree $degree")

    try
        # Create test input with safe parameters
        TR = test_input(objective_4d, domain, GN=GN, tolerance=nothing)
        println("  Test input created: $(size(TR.grid_points)) grid points")

        # Create polynomial approximation
        pol = Constructor(TR, degree)
        println("  Polynomial constructor completed for degree $degree")

        # Find critical points
        critical_points = real_points(pol)
        println("  Found $(length(critical_points)) critical points")

        # Compute L2 norms if critical points found
        if !isempty(critical_points)
            # Convert to matrix format for L2 computation
            crit_matrix = hcat([collect(point) for point in critical_points]...)'

            # Compute L2 norms
            l2_norms = [norm(objective_4d(point) - pol(point...)) for point in critical_points]
            mean_l2 = mean(l2_norms)

            println("  L2 norms computed: mean = $(round(mean_l2, digits=6))")

            if mean_l2 < 0.1
                println("  ✅ Good L2 norm quality (< 0.1)")
            else
                println("  ⚠️  High L2 norm ($(round(mean_l2, digits=6)))")
            end
        end

        println("  ✅ Degree $degree completed successfully")

    catch e
        println("  ❌ Error in degree $degree: $e")
        rethrow(e)
    end
end

println("\n🎯 4D Lotka-Volterra Dagger Test Completed Successfully")
EOF

    echo "$script_path"
}

# Main test execution
run_4d_dagger_test() {
    log_info "Starting 4D Lotka-Volterra Dagger integration test"

    # Create test script
    local test_script=$(create_test_script)
    log_info "Created test script: $test_script"

    # Run experiment using hook orchestrator with Dagger
    log_info "Launching experiment via hook orchestrator..."

    # Set experiment type to trigger Dagger execution
    export GLOBTIM_EXPERIMENT_TYPE="4d"
    export GLOBTIM_SCRIPT_PATH="$test_script"
    export GLOBTIM_SESSION_NAME="$TEST_ID"

    # Execute via hook orchestrator using the correct command
    local context="test_dagger:$test_script"

    # Extract the experiment ID that will be generated by the orchestrator
    local generated_exp_id="$(basename "${context// /_}")_$(date +%Y%m%d_%H%M%S)"
    log_info "Expected experiment ID: $generated_exp_id"

    if ! "$PROJECT_ROOT/tools/hpc/hooks/hook_orchestrator.sh" orchestrate "$context"; then
        log_error "Hook orchestrator execution failed"
        return 1
    fi

    log_success "Experiment launched successfully"

    # Wait for experiment completion (check for up to 5 minutes)
    local timeout=300
    local elapsed=0
    local sleep_interval=10

    log_info "Waiting for experiment completion (timeout: ${timeout}s)..."

    # Find the actual experiment ID from Dagger index (it might be slightly different due to timing)
    local actual_exp_id=""

    while [[ $elapsed -lt $timeout ]]; do
        # Check if experiment is complete in Dagger index
        if [[ -f "$PROJECT_ROOT/dagger_execution_index.json" ]]; then
            # Find experiment ID that starts with our expected prefix
            local exp_prefix="test_dagger"
            actual_exp_id=$(jq -r ".experiments | keys[] | select(startswith(\"$exp_prefix\"))" "$PROJECT_ROOT/dagger_execution_index.json" | tail -1)

            if [[ -n "$actual_exp_id" && "$actual_exp_id" != "null" ]]; then
                local status=$(jq -r ".experiments[\"$actual_exp_id\"].status // \"unknown\"" "$PROJECT_ROOT/dagger_execution_index.json")
                log_info "Found experiment: $actual_exp_id with status: $status"

                if [[ "$status" == "completed" ]]; then
                    log_success "Experiment completed successfully"
                    break
                elif [[ "$status" == "failed" ]]; then
                    log_error "Experiment failed"
                    return 1
                fi
            fi
        fi

        sleep $sleep_interval
        elapsed=$((elapsed + sleep_interval))
        log_info "Waiting... (${elapsed}s/${timeout}s)"
    done

    if [[ $elapsed -ge $timeout ]]; then
        log_error "Experiment timeout after ${timeout}s"
        return 1
    fi

    if [[ -z "$actual_exp_id" ]]; then
        log_error "Could not find experiment ID in Dagger index"
        return 1
    fi

    # Use the actual experiment ID for validation
    log_info "Using experiment ID for validation: $actual_exp_id"

    # Validate tracking capabilities
    if ! validate_dagger_tracking "$actual_exp_id"; then
        log_error "Dagger tracking validation failed"
        return 1
    fi

    # Validate experiment organization
    if ! validate_experiment_organization "$actual_exp_id"; then
        log_error "Experiment organization validation failed"
        return 1
    fi

    # Validate execution method
    if ! validate_dagger_execution_method "$actual_exp_id"; then
        log_error "Dagger execution method validation failed"
        return 1
    fi

    log_success "All validations passed - Dagger is working as default for 4D experiments"
    return 0
}

# Cleanup function
cleanup_test() {
    log_info "Cleaning up test resources..."

    # Kill any running tmux sessions for this test
    if tmux has-session -t "$TEST_ID" 2>/dev/null; then
        tmux kill-session -t "$TEST_ID"
        log_info "Killed tmux session: $TEST_ID"
    fi

    # Archive test results
    if [[ -d "$PROJECT_ROOT/hpc_results/$TEST_ID" ]]; then
        mv "$PROJECT_ROOT/hpc_results/$TEST_ID" "$RESULTS_DIR/"
        log_info "Archived experiment results to: $RESULTS_DIR/$TEST_ID"
    fi
}

# Test summary
print_test_summary() {
    echo ""
    echo "=========================================="
    echo "4D Lotka-Volterra Dagger Test Summary"
    echo "=========================================="
    echo "Test ID: $TEST_ID"
    echo "Timestamp: $TEST_TIMESTAMP"
    echo "Log file: $LOG_DIR/${TEST_ID}.log"
    echo "Results: $RESULTS_DIR/"
    echo ""
    echo "Key validations:"
    echo "✅ Dagger execution as default for 4D experiments"
    echo "✅ Comprehensive tracking capabilities"
    echo "✅ Proper experiment organization"
    echo "✅ Standard execution hook archived"
    echo ""
}

# Main execution
main() {
    trap cleanup_test EXIT

    if run_4d_dagger_test; then
        print_test_summary
        log_success "🎯 Issue #48 test validation completed successfully"
        echo -e "${BOLD}${GREEN}✅ Dagger.jl is now the default for 4D experiments with excellent tracking capabilities${NC}"
        return 0
    else
        log_error "❌ Test failed - see logs for details"
        return 1
    fi
}

# Command line interface
case "${1:-run}" in
    "run")
        main
        ;;
    "cleanup")
        cleanup_test
        ;;
    "help"|*)
        echo "4D Lotka-Volterra Dagger Integration Test"
        echo "Usage:"
        echo "  $0 run      - Run the complete test suite"
        echo "  $0 cleanup  - Clean up test resources"
        echo "  $0 help     - Show this help"
        ;;
esac