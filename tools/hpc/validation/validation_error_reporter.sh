#!/bin/bash
# Enhanced Error Reporter for Pre-Execution Validation
# Part of Issue #27: Implement Pre-Execution Validation Hook System
# Consolidates and formats all validation errors with actionable solutions

set -e

# Configuration
GLOBTIM_ROOT="/home/scholten/globtim"
LOCAL_GLOBTIM_ROOT="/Users/ghscholt/globtim"
VALIDATION_LOG="/tmp/validation_errors_$$.json"
REPORT_NAME="validation_error_reporter"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

function log() {
    echo -e "${BOLD}${GREEN}[$REPORT_NAME]${NC} $1" >&2
}

function warning() {
    echo -e "${BOLD}${YELLOW}[$REPORT_NAME WARNING]${NC} $1" >&2
}

function error() {
    echo -e "${BOLD}${RED}[$REPORT_NAME ERROR]${NC} $1" >&2
}

function info() {
    echo -e "${BOLD}${BLUE}[$REPORT_NAME INFO]${NC} $1" >&2
}

function section_header() {
    echo -e "\n${BOLD}${CYAN}================================${NC}"
    echo -e "${BOLD}${CYAN} $1${NC}"
    echo -e "${BOLD}${CYAN}================================${NC}\n"
}

# Structure for validation results
init_validation_log() {
    cat > "$VALIDATION_LOG" << EOF
{
  "validation_timestamp": "$(date -Iseconds)",
  "validation_session": "$(basename $0)_$$",
  "components": {
    "script_discovery": {
      "status": "not_run",
      "errors": [],
      "warnings": [],
      "execution_time": 0
    },
    "julia_environment": {
      "status": "not_run",
      "errors": [],
      "warnings": [],
      "execution_time": 0
    },
    "resource_availability": {
      "status": "not_run", 
      "errors": [],
      "warnings": [],
      "execution_time": 0
    },
    "git_synchronization": {
      "status": "not_run",
      "errors": [],
      "warnings": [],
      "execution_time": 0
    }
  },
  "overall_status": "pending",
  "total_execution_time": 0,
  "recommendations": []
}
EOF
}

# Update component status in validation log
update_component_status() {
    local component="$1"
    local status="$2"
    local execution_time="${3:-0}"
    shift 3
    local errors=("$@")
    
    # Use jq to update the JSON log (fallback to manual if jq not available)
    if command -v jq >/dev/null 2>&1; then
        local temp_log=$(mktemp)
        jq --arg comp "$component" --arg stat "$status" --argjson time "$execution_time" \
           --argjson errs "$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)" \
           '.components[$comp].status = $stat | .components[$comp].execution_time = $time | .components[$comp].errors = $errs' \
           "$VALIDATION_LOG" > "$temp_log" && mv "$temp_log" "$VALIDATION_LOG"
    else
        # Fallback: manual JSON update (basic)
        warning "jq not available - using basic error logging"
    fi
}

# Generate comprehensive error report
generate_error_report() {
    local validation_success="$1"
    
    section_header "VALIDATION ERROR REPORT"
    
    echo -e "${BOLD}Session Information:${NC}"
    echo "  • Timestamp: $(date)"
    echo "  • Session ID: $(basename $0)_$$"
    echo "  • Overall Status: $([ "$validation_success" = "true" ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo ""
    
    # Component Status Summary
    echo -e "${BOLD}Component Status Summary:${NC}"
    
    local script_status="${SCRIPT_DISCOVERY_STATUS:-not_run}"
    local julia_status="${JULIA_VALIDATION_STATUS:-not_run}"  
    local resource_status="${RESOURCE_VALIDATION_STATUS:-not_run}"
    local git_status="${GIT_VALIDATION_STATUS:-not_run}"
    
    echo "  • Script Discovery:     $(format_status "$script_status")"
    echo "  • Julia Environment:    $(format_status "$julia_status")"
    echo "  • Resource Availability: $(format_status "$resource_status")"
    echo "  • Git Synchronization:  $(format_status "$git_status")"
    echo ""
    
    # Detailed Error Analysis
    if [ "$validation_success" != "true" ]; then
        section_header "DETAILED ERROR ANALYSIS"
        
        # Script Discovery Errors
        if [ "$script_status" = "failed" ] && [ -n "${SCRIPT_DISCOVERY_ERRORS:-}" ]; then
            echo -e "${BOLD}Script Discovery Issues:${NC}"
            echo "$SCRIPT_DISCOVERY_ERRORS" | while IFS= read -r line; do
                echo "  ❌ $line"
            done
            echo ""
            echo -e "${BOLD}Resolution Steps:${NC}"
            echo "  1. Verify script name spelling and location"
            echo "  2. Check available scripts: ./tools/hpc/validation/script_discovery.sh list"
            echo "  3. Move script to standard directory (Examples/, hpc/experiments/, test/)"
            echo "  4. Use absolute path if script is in custom location"
            echo ""
        fi
        
        # Julia Environment Errors  
        if [ "$julia_status" = "failed" ] && [ -n "${JULIA_VALIDATION_ERRORS:-}" ]; then
            echo -e "${BOLD}Julia Environment Issues:${NC}"
            echo "$JULIA_VALIDATION_ERRORS" | while IFS= read -r line; do
                echo "  ❌ $line"  
            done
            echo ""
            echo -e "${BOLD}Resolution Steps:${NC}"
            echo "  1. Install missing packages: julia --project=. -e 'using Pkg; Pkg.instantiate()'"
            echo "  2. Check Julia version compatibility (required: 1.10+)"
            echo "  3. Clear package cache: rm -rf ~/.julia/compiled/v*/PackageName"
            echo "  4. Verify Project.toml and Manifest.toml are present and valid"
            echo ""
        fi
        
        # Resource Availability Errors
        if [ "$resource_status" = "failed" ] && [ -n "${RESOURCE_VALIDATION_ERRORS:-}" ]; then
            echo -e "${BOLD}Resource Availability Issues:${NC}"
            echo "$RESOURCE_VALIDATION_ERRORS" | while IFS= read -r line; do
                echo "  ❌ $line"
            done
            echo ""
            echo -e "${BOLD}Resolution Steps:${NC}"
            echo "  1. Wait for current experiments to complete: tmux ls"
            echo "  2. Clean up old results: rm -rf hpc_results/globtim_*"
            echo "  3. Reduce problem size (degree/dimension) if memory constrained"
            echo "  4. Check system load: htop, free -h, df -h"
            echo ""
        fi
        
        # Git Synchronization Errors
        if [ "$git_status" = "failed" ] && [ -n "${GIT_VALIDATION_ERRORS:-}" ]; then
            echo -e "${BOLD}Git Synchronization Issues:${NC}"
            echo "$GIT_VALIDATION_ERRORS" | while IFS= read -r line; do
                echo "  ❌ $line"
            done
            echo ""
            echo -e "${BOLD}Resolution Steps:${NC}"
            echo "  1. Commit uncommitted changes: git add -A && git commit -m 'WIP'"
            echo "  2. Pull latest changes: git pull origin main"
            echo "  3. Use --allow-dirty flag if needed (not recommended for reproducibility)"
            echo "  4. Verify correct branch: git checkout main"
            echo ""
        fi
        
        section_header "RECOMMENDED ACTIONS"
        
        echo -e "${BOLD}Priority Order:${NC}"
        echo "  1. Address FAILED components first (critical blockers)"
        echo "  2. Review WARNING components (potential issues)" 
        echo "  3. Re-run validation: ./tools/hpc/validation/validation_error_reporter.sh validate"
        echo "  4. If issues persist, check logs and documentation"
        echo ""
        
        echo -e "${BOLD}Quick Diagnostic Commands:${NC}"
        echo "  • Test script discovery: ./tools/hpc/validation/script_discovery.sh discover your_script.jl"
        echo "  • Test Julia environment: ./tools/hpc/validation/package_validator.jl critical"
        echo "  • Test resources: ./tools/hpc/validation/resource_validator.sh validate"
        echo "  • Test git status: ./tools/hpc/validation/git_sync_validator.sh validate --allow-dirty"
        echo ""
        
        echo -e "${BOLD}Documentation:${NC}"
        echo "  • User Guide: docs/hpc/VALIDATION_SYSTEM_USER_GUIDE.md"
        echo "  • Workflow Guide: docs/hpc/ROBUST_WORKFLOW_GUIDE.md"  
        echo "  • Troubleshooting: Search for specific error messages in documentation"
        echo ""
    else
        echo -e "${GREEN}✅ All validation components passed successfully!${NC}"
        echo -e "${GREEN}✅ System is ready for experiment execution.${NC}"
        echo ""
    fi
}

# Format status for display
format_status() {
    local status="$1"
    case "$status" in
        "passed") echo "✅ PASSED" ;;
        "failed") echo "❌ FAILED" ;;
        "warning") echo "⚠️  WARNING" ;;
        "not_run") echo "⏸️  NOT RUN" ;;
        *) echo "❓ UNKNOWN" ;;
    esac
}

# Export error information to structured format
export_error_report() {
    local format="${1:-text}"
    local output_file="${2:-/tmp/validation_report_$(date +%Y%m%d_%H%M%S).$format}"
    
    case "$format" in
        "json")
            if [ -f "$VALIDATION_LOG" ]; then
                cp "$VALIDATION_LOG" "$output_file"
                info "JSON report exported to: $output_file"
            else
                error "No validation log available for JSON export"
                return 1
            fi
            ;;
        "text"|*)
            generate_error_report "${VALIDATION_SUCCESS:-false}" > "$output_file"
            info "Text report exported to: $output_file"
            ;;
    esac
}

# Test validation error reporting
test_error_reporting() {
    log "Testing enhanced error reporting system..."
    
    # Initialize test validation log
    init_validation_log
    
    # Simulate component failures for testing
    export SCRIPT_DISCOVERY_STATUS="failed"
    export SCRIPT_DISCOVERY_ERRORS="Script 'nonexistent.jl' not found in any search location"
    
    export JULIA_VALIDATION_STATUS="warning"  
    export JULIA_VALIDATION_ERRORS="CSV package not available (non-critical)"
    
    export RESOURCE_VALIDATION_STATUS="passed"
    export GIT_VALIDATION_STATUS="passed"
    
    # Generate test report
    log "Generating test error report..."
    generate_error_report "false"
    
    log "✅ Error reporting system test completed"
}

# Run comprehensive validation with error reporting
run_validation_with_reporting() {
    log "Starting comprehensive validation with enhanced error reporting..."
    
    init_validation_log
    local validation_success="true"
    local start_time=$(date +%s)
    
    # Component 1: Script Discovery
    if [ -n "${1:-}" ]; then
        info "Running script discovery validation..."
        local script_start=$(date +%s)
        if ! output=$(./tools/hpc/validation/script_discovery.sh discover "$1" 2>&1); then
            export SCRIPT_DISCOVERY_STATUS="failed"
            export SCRIPT_DISCOVERY_ERRORS="$output"
            validation_success="false"
        else
            export SCRIPT_DISCOVERY_STATUS="passed"
        fi
        local script_time=$(($(date +%s) - script_start))
        update_component_status "script_discovery" "$SCRIPT_DISCOVERY_STATUS" "$script_time" "${SCRIPT_DISCOVERY_ERRORS:-}"
    fi
    
    # Component 2: Julia Environment
    info "Running Julia environment validation..."
    local julia_start=$(date +%s)
    if ! output=$(./tools/hpc/validation/package_validator.jl critical 2>&1); then
        export JULIA_VALIDATION_STATUS="failed"
        export JULIA_VALIDATION_ERRORS="$output"
        validation_success="false"
    else
        export JULIA_VALIDATION_STATUS="passed"
    fi
    local julia_time=$(($(date +%s) - julia_start))
    update_component_status "julia_environment" "$JULIA_VALIDATION_STATUS" "$julia_time" "${JULIA_VALIDATION_ERRORS:-}"
    
    # Component 3: Resource Availability
    info "Running resource availability validation..."
    local resource_start=$(date +%s)
    if ! output=$(./tools/hpc/validation/resource_validator.sh validate 2>&1); then
        export RESOURCE_VALIDATION_STATUS="failed"
        export RESOURCE_VALIDATION_ERRORS="$output"
        validation_success="false"
    else
        export RESOURCE_VALIDATION_STATUS="passed"
    fi
    local resource_time=$(($(date +%s) - resource_start))
    update_component_status "resource_availability" "$RESOURCE_VALIDATION_STATUS" "$resource_time" "${RESOURCE_VALIDATION_ERRORS:-}"
    
    # Component 4: Git Synchronization
    info "Running git synchronization validation..."
    local git_start=$(date +%s)
    if ! output=$(./tools/hpc/validation/git_sync_validator.sh validate --allow-dirty 2>&1); then
        export GIT_VALIDATION_STATUS="failed"
        export GIT_VALIDATION_ERRORS="$output"
        validation_success="false"
    else
        export GIT_VALIDATION_STATUS="passed"
    fi
    local git_time=$(($(date +%s) - git_start))
    update_component_status "git_synchronization" "$GIT_VALIDATION_STATUS" "$git_time" "${GIT_VALIDATION_ERRORS:-}"
    
    local total_time=$(($(date +%s) - start_time))
    export VALIDATION_SUCCESS="$validation_success"
    
    # Generate comprehensive report
    generate_error_report "$validation_success"
    
    # Export reports
    export_error_report "text" "/tmp/validation_report_$(date +%Y%m%d_%H%M%S).txt"
    export_error_report "json" "/tmp/validation_report_$(date +%Y%m%d_%H%M%S).json"
    
    log "Total validation time: ${total_time}s"
    log "Reports saved to /tmp/validation_report_*"
    
    # Return appropriate exit code
    [ "$validation_success" = "true" ] && return 0 || return 1
}

# Show usage information
show_usage() {
    cat << EOF
Enhanced Error Reporter for Pre-Execution Validation
Part of Issue #27: Implement Pre-Execution Validation Hook System

USAGE:
    $0 validate [script_name]    # Run full validation with error reporting
    $0 report [text|json] [file] # Generate report from last validation
    $0 test                      # Test error reporting system
    $0 help                      # Show this usage information

EXAMPLES:
    $0 validate Examples/hpc_minimal_2d_example.jl
    $0 validate 4d-model
    $0 report json /tmp/my_validation_report.json
    $0 test

FEATURES:
    ✓ Comprehensive error collection and analysis
    ✓ Actionable resolution steps for each error type
    ✓ JSON and text report export capabilities
    ✓ Integration with all 4 validation components
    ✓ Execution time tracking and performance metrics
    ✓ Structured error categorization and prioritization

EOF
}

# Main command processing
main() {
    local command="${1:-help}"
    
    case "$command" in
        "validate")
            run_validation_with_reporting "${2:-}"
            ;;
        "report")
            export_error_report "${2:-text}" "${3:-}"
            ;;
        "test")
            test_error_reporting
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Cleanup on exit
cleanup() {
    [ -f "$VALIDATION_LOG" ] && rm -f "$VALIDATION_LOG"
}
trap cleanup EXIT

# Run main function
main "$@"