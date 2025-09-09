#!/bin/bash
#
# Package Loading Failure Detection Hook
# ====================================
# 
# Automatically detects package loading failures on HPC cluster and guides
# users through the proven resolution protocol documented in:
# docs/hpc/CROSS_ENVIRONMENT_PACKAGE_MANAGEMENT.md
#
# This hook addresses Issue #42 resolution - 100% package loading success
# achieved through complete environment regeneration protocol.
#
# Author: GlobTim Project - Claude Code Infrastructure
# Date: September 9, 2025
# Integration: Strategic Hook Orchestrator System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.cache/hooks"
HOOK_LOG="$LOG_DIR/package_loading_detector.log"
DOCS_PATH="$PROJECT_ROOT/docs/hpc/CROSS_ENVIRONMENT_PACKAGE_MANAGEMENT.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$HOOK_LOG"
}

# Display header
display_header() {
    echo -e "${RED}${BOLD}🚨 PACKAGE LOADING FAILURE DETECTED${NC}"
    echo -e "${RED}=====================================${NC}"
    echo
    echo -e "${YELLOW}This hook has detected package loading issues that require immediate attention.${NC}"
    echo -e "${YELLOW}Based on successful resolution of Issue #42 (100% success rate achieved).${NC}"
    echo
}

# Check for common package loading failure patterns
detect_package_failures() {
    local log_content="$1"
    local failure_detected=false
    local failure_reasons=()
    
    # Pattern 1: CSV KeyError (primary Issue #42 symptom)
    if echo "$log_content" | grep -q "KeyError.*CSV"; then
        failure_detected=true
        failure_reasons+=("CSV KeyError detected - primary cause of 88.2% HPC failure rate")
    fi
    
    # Pattern 2: OpenBLAS32_jll version conflict
    if echo "$log_content" | grep -q "OpenBLAS32_jll.*Unsatisfiable requirements"; then
        failure_detected=true
        failure_reasons+=("OpenBLAS32_jll version conflict - Julia version mismatch")
    fi
    
    # Pattern 3: Julia version warnings in Manifest
    if echo "$log_content" | grep -q "manifest file has dependencies.*different julia version"; then
        failure_detected=true
        failure_reasons+=("Manifest.toml Julia version mismatch detected")
    fi
    
    # Pattern 4: Package resolution failures
    if echo "$log_content" | grep -qE "(resolve.*ERROR|status.*ERROR.*not found)"; then
        failure_detected=true
        failure_reasons+=("Package resolution failure detected")
    fi
    
    # Pattern 5: Using statement failures for core packages
    if echo "$log_content" | grep -qE "using (CSV|DataFrames|JSON3).*ERROR"; then
        failure_detected=true
        failure_reasons+=("Core package loading failure detected")
    fi
    
    if [ "$failure_detected" = true ]; then
        log_message "PACKAGE LOADING FAILURE DETECTED"
        for reason in "${failure_reasons[@]}"; do
            log_message "- Failure pattern: $reason"
        done
        return 0
    else
        return 1
    fi
}

# Display failure analysis
display_failure_analysis() {
    local log_content="$1"
    
    echo -e "${RED}${BOLD}Failure Analysis:${NC}"
    echo
    
    # Check for specific error patterns and provide targeted guidance
    if echo "$log_content" | grep -q "KeyError.*CSV"; then
        echo -e "${RED}• CSV Package KeyError detected${NC}"
        echo -e "  This is the EXACT error that caused 88.2% failure rate in Issue #42"
    fi
    
    if echo "$log_content" | grep -q "OpenBLAS32_jll"; then
        echo -e "${RED}• OpenBLAS32_jll version conflict detected${NC}"
        echo -e "  Julia version incompatibility (1.10.5 vs 1.11.6) causing binary conflicts"
    fi
    
    if echo "$log_content" | grep -q "different julia version"; then
        echo -e "${RED}• Manifest.toml Julia version mismatch detected${NC}"
        echo -e "  Environment built with different Julia version than current runtime"
    fi
    
    echo
}

# Display the proven solution protocol
display_solution_protocol() {
    echo -e "${GREEN}${BOLD}PROVEN SOLUTION PROTOCOL (100% Success Rate)${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo
    echo -e "${BOLD}This exact protocol resolved all package loading failures on r04n02:${NC}"
    echo
    
    echo -e "${BLUE}1. Connect to HPC cluster:${NC}"
    echo -e "   ${YELLOW}ssh scholten@r04n02${NC}"
    echo -e "   ${YELLOW}cd /home/scholten/globtim${NC}"
    echo
    
    echo -e "${BLUE}2. Pull latest changes (ensure updated Project.toml):${NC}"
    echo -e "   ${YELLOW}git pull${NC}"
    echo
    
    echo -e "${BLUE}3. ${RED}CRITICAL:${NC} ${BLUE}Remove problematic Manifest.toml:${NC}"
    echo -e "   ${YELLOW}rm Manifest.toml${NC}"
    echo
    
    echo -e "${BLUE}4. Regenerate entire environment:${NC}"
    echo -e "   ${YELLOW}julia --project=. -e \"using Pkg; Pkg.instantiate()\"${NC}"
    echo
    
    echo -e "${BLUE}5. Verify package loading:${NC}"
    echo -e "   ${YELLOW}julia --project=. -e \"using CSV, DataFrames; println(\\\"SUCCESS: Packages loaded correctly\\\")\"${NC}"
    echo
}

# Display why this solution works
display_solution_explanation() {
    echo -e "${GREEN}${BOLD}Why This Solution Works:${NC}"
    echo
    echo -e "${GREEN}• Root Cause:${NC} Manifest.toml generated with different Julia version"
    echo -e "${GREEN}• Solution:${NC} Complete environment regeneration using cluster's native Julia"
    echo -e "${GREEN}• Result:${NC} All 203+ packages reinstall with correct version compatibility"
    echo
}

# Display documentation reference
display_documentation_reference() {
    echo -e "${BLUE}${BOLD}Complete Documentation:${NC}"
    echo -e "${BLUE}======================${NC}"
    echo
    echo -e "For complete details, see: ${YELLOW}$DOCS_PATH${NC}"
    echo
    echo -e "${BOLD}Key sections:${NC}"
    echo -e "• 🚨 CRITICAL: Package Loading Failures on HPC Cluster"
    echo -e "• PROVEN SOLUTION PROTOCOL (September 2025)"
    echo -e "• Warning Signs Requiring Immediate Action"
    echo
}

# Display prevention guidance
display_prevention_guidance() {
    echo -e "${YELLOW}${BOLD}Prevention for Future:${NC}"
    echo -e "${YELLOW}===================${NC}"
    echo
    echo -e "${BOLD}DO NOT ATTEMPT:${NC}"
    echo -e "• Manual package version fixes"
    echo -e "• Partial environment updates"
    echo -e "• Ignoring Julia version warnings"
    echo
    echo -e "${BOLD}ALWAYS DO:${NC}"
    echo -e "• Complete Manifest.toml regeneration"
    echo -e "• Full environment rebuild"
    echo -e "• Verification testing after fixes"
    echo
}

# Main detection function
main() {
    local input_log="${1:-}"
    
    # If no input provided, try to detect from common locations
    if [ -z "$input_log" ]; then
        # Check recent Julia operations for failures
        local temp_log=$(mktemp)
        
        # Try to capture recent Julia package operations
        if command -v julia >/dev/null 2>&1; then
            # Test basic package loading
            julia --project="$PROJECT_ROOT" -e "using Pkg; Pkg.status()" 2>&1 | tee "$temp_log" || true
        fi
        
        input_log="$temp_log"
    fi
    
    # Read log content if file exists
    local log_content=""
    if [ -f "$input_log" ]; then
        log_content=$(cat "$input_log")
    elif [ -n "$input_log" ]; then
        # Treat as direct log content
        log_content="$input_log"
    fi
    
    # Detect package failures
    if detect_package_failures "$log_content"; then
        display_header
        display_failure_analysis "$log_content"
        display_solution_protocol
        display_solution_explanation
        display_documentation_reference
        display_prevention_guidance
        
        log_message "Package loading failure detection completed - user guided to resolution protocol"
        
        # Return failure code to trigger hook orchestrator response
        return 1
    else
        log_message "No package loading failures detected"
        return 0
    fi
}

# Hook integration point - can be called by orchestrator or directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi