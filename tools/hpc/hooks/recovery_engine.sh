#!/bin/bash
# Automated Recovery Engine
# Issue #41: Intelligent error handling and automated recovery system
# Implements pattern recognition and automated recovery workflows

set -e

# Configuration
RECOVERY_VERSION="1.0.0"
RECOVERY_NAME="recovery-engine"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Auto-detect environment
if [[ -d "/home/scholten/globtim" ]]; then
    GLOBTIM_DIR="/home/scholten/globtim"
    ENVIRONMENT="hpc"
else
    GLOBTIM_DIR="/Users/ghscholt/globtim"
    ENVIRONMENT="local"
fi

HOOKS_DIR="$GLOBTIM_DIR/tools/hpc/hooks"
RECOVERY_DIR="$HOOKS_DIR/recovery"
PATTERNS_FILE="$RECOVERY_DIR/failure_patterns.json"
ACTIONS_DIR="$RECOVERY_DIR/actions"
LOG_DIR="$HOOKS_DIR/logs"

# Create necessary directories
mkdir -p "$RECOVERY_DIR" "$ACTIONS_DIR" "$LOG_DIR"

# Logging functions
log_info() {
    echo -e "${BOLD}${GREEN}[RECOVERY-ENGINE]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_DIR/recovery.log"
}

log_warning() {
    echo -e "${BOLD}${YELLOW}[RECOVERY WARNING]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_DIR/recovery.log"
}

log_error() {
    echo -e "${BOLD}${RED}[RECOVERY ERROR]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_DIR/recovery.log"
}

# Recovery strategy definitions
initialize_failure_patterns() {
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        log_info "Creating default failure patterns database"
        cat > "$PATTERNS_FILE" << 'EOF'
{
    "version": "1.0.0",
    "description": "Failure patterns and automated recovery strategies",
    "patterns": {
        "package_not_found": {
            "signatures": [
                "Package .* not found in current path",
                "LoadError.*not found",
                "ArgumentError: Package .* not found"
            ],
            "phase": "validation",
            "severity": "critical",
            "recovery_actions": [
                "check_julia_environment",
                "reinstall_packages",
                "update_manifest"
            ],
            "max_retries": 2,
            "backoff_seconds": 30
        },
        "memory_exhaustion": {
            "signatures": [
                "OutOfMemoryError",
                "cannot allocate memory",
                "Julia: OutOfMemoryError"
            ],
            "phase": "execution",
            "severity": "critical",
            "recovery_actions": [
                "increase_memory_limit",
                "reduce_problem_size",
                "cleanup_memory"
            ],
            "max_retries": 1,
            "backoff_seconds": 60
        },
        "disk_space_full": {
            "signatures": [
                "No space left on device",
                "Disk quota exceeded",
                "OSError.*No space left"
            ],
            "phase": "execution",
            "severity": "critical",
            "recovery_actions": [
                "cleanup_temp_files",
                "archive_old_results",
                "alert_administrator"
            ],
            "max_retries": 1,
            "backoff_seconds": 0
        },
        "network_timeout": {
            "signatures": [
                "Connection timed out",
                "Network is unreachable",
                "DNS resolution failed"
            ],
            "phase": "preparation",
            "severity": "medium",
            "recovery_actions": [
                "retry_with_backoff",
                "check_network_connectivity",
                "use_cached_resources"
            ],
            "max_retries": 3,
            "backoff_seconds": 15
        },
        "permission_denied": {
            "signatures": [
                "Permission denied",
                "Operation not permitted",
                "Access is denied"
            ],
            "phase": "preparation",
            "severity": "medium",
            "recovery_actions": [
                "fix_file_permissions",
                "check_user_privileges",
                "create_alternative_path"
            ],
            "max_retries": 2,
            "backoff_seconds": 5
        },
        "ssh_connection_failed": {
            "signatures": [
                "ssh: connect to host .* port .* Connection refused",
                "Host key verification failed",
                "Permission denied (publickey)"
            ],
            "phase": "preparation",
            "severity": "high",
            "recovery_actions": [
                "check_ssh_keys",
                "test_ssh_connectivity",
                "fallback_authentication"
            ],
            "max_retries": 3,
            "backoff_seconds": 10
        },
        "tmux_session_exists": {
            "signatures": [
                "duplicate session",
                "session already exists"
            ],
            "phase": "preparation",
            "severity": "low",
            "recovery_actions": [
                "cleanup_old_sessions",
                "generate_unique_session_name"
            ],
            "max_retries": 1,
            "backoff_seconds": 5
        },
        "julia_compilation_failed": {
            "signatures": [
                "Compilation failed",
                "ERROR: LoadError: UndefVarError",
                "BoundsError"
            ],
            "phase": "execution",
            "severity": "high",
            "recovery_actions": [
                "clear_julia_cache",
                "reinstall_problematic_package",
                "fallback_to_safe_mode"
            ],
            "max_retries": 2,
            "backoff_seconds": 45
        }
    }
}
EOF
        log_info "Created failure patterns database: $PATTERNS_FILE"
    fi
}

# Pattern matching and analysis
analyze_failure() {
    local error_output="$1"
    local phase="${2:-unknown}"
    local experiment_id="${3:-unknown}"
    
    log_info "Analyzing failure for experiment: $experiment_id (phase: $phase)"
    
    # Load patterns and match against error output
    python3 << EOF
import json
import re
import sys

try:
    with open("$PATTERNS_FILE", 'r') as f:
        patterns_db = json.load(f)
    
    error_text = """$error_output"""
    phase = "$phase"
    
    matches = []
    
    for pattern_name, pattern_data in patterns_db.get('patterns', {}).items():
        signatures = pattern_data.get('signatures', [])
        pattern_phase = pattern_data.get('phase', 'unknown')
        
        # Check if any signature matches the error output
        for signature in signatures:
            if re.search(signature, error_text, re.IGNORECASE | re.MULTILINE):
                match_score = 1.0
                
                # Bonus score for phase match
                if pattern_phase == phase or pattern_phase == 'unknown':
                    match_score += 0.5
                
                matches.append({
                    'pattern': pattern_name,
                    'score': match_score,
                    'data': pattern_data
                })
                break
    
    if matches:
        # Sort by score (highest first)
        matches.sort(key=lambda x: x['score'], reverse=True)
        best_match = matches[0]
        
        print(f"MATCH_FOUND:{best_match['pattern']}")
        print(f"SEVERITY:{best_match['data']['severity']}")
        print(f"MAX_RETRIES:{best_match['data']['max_retries']}")
        print(f"BACKOFF:{best_match['data']['backoff_seconds']}")
        
        actions = best_match['data'].get('recovery_actions', [])
        for action in actions:
            print(f"ACTION:{action}")
    else:
        print("NO_MATCH_FOUND")
        print("SEVERITY:unknown")
        print("MAX_RETRIES:1")
        print("BACKOFF:30")
        print("ACTION:generic_error_recovery")

except Exception as e:
    print(f"ERROR_ANALYSIS_FAILED:{e}")
    sys.exit(1)
EOF
}

# Recovery action implementations
execute_recovery_action() {
    local action="$1"
    local experiment_id="$2"
    local phase="${3:-unknown}"
    local error_output="${4:-}"
    
    log_info "Executing recovery action: $action for experiment: $experiment_id"
    
    local action_script="$ACTIONS_DIR/${action}.sh"
    
    # Check if custom action script exists
    if [[ -x "$action_script" ]]; then
        log_info "Running custom recovery action script: $action_script"
        if "$action_script" "$experiment_id" "$phase" "$error_output"; then
            log_info "Custom recovery action succeeded: $action"
            return 0
        else
            log_error "Custom recovery action failed: $action"
            return 1
        fi
    fi
    
    # Built-in recovery actions
    case "$action" in
        check_julia_environment)
            check_julia_environment_action "$experiment_id"
            ;;
        reinstall_packages)
            reinstall_packages_action "$experiment_id"
            ;;
        increase_memory_limit)
            increase_memory_limit_action "$experiment_id"
            ;;
        cleanup_temp_files)
            cleanup_temp_files_action "$experiment_id"
            ;;
        cleanup_old_sessions)
            cleanup_old_sessions_action "$experiment_id"
            ;;
        check_ssh_connectivity)
            check_ssh_connectivity_action "$experiment_id"
            ;;
        clear_julia_cache)
            clear_julia_cache_action "$experiment_id"
            ;;
        retry_with_backoff)
            retry_with_backoff_action "$experiment_id" "$phase"
            ;;
        generic_error_recovery)
            generic_error_recovery_action "$experiment_id" "$phase"
            ;;
        alert_administrator)
            alert_administrator_action "$experiment_id" "$error_output"
            ;;
        *)
            log_error "Unknown recovery action: $action"
            return 1
            ;;
    esac
}

# Built-in recovery action implementations
check_julia_environment_action() {
    local experiment_id="$1"
    
    log_info "Checking Julia environment for experiment: $experiment_id"
    
    # Run Julia environment validation
    local package_validator="$GLOBTIM_DIR/tools/hpc/validation/package_validator.jl"
    if [[ -x "$package_validator" ]]; then
        if julia --project="$GLOBTIM_DIR" "$package_validator" --critical; then
            log_info "Julia environment check passed"
            return 0
        else
            log_error "Julia environment check failed"
            return 1
        fi
    else
        log_warning "Julia environment validator not available"
        return 1
    fi
}

reinstall_packages_action() {
    local experiment_id="$1"
    
    log_info "Reinstalling Julia packages for experiment: $experiment_id"
    
    # Attempt to reinstall critical packages
    julia --project="$GLOBTIM_DIR" -e "
        using Pkg
        Pkg.instantiate()
        Pkg.precompile()
        println(\"Package reinstallation completed\")
    " 2>&1 | tee "$LOG_DIR/package_reinstall_${experiment_id}.log"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log_info "Package reinstallation succeeded"
        return 0
    else
        log_error "Package reinstallation failed"
        return 1
    fi
}

increase_memory_limit_action() {
    local experiment_id="$1"
    
    log_info "Attempting to increase memory limit for experiment: $experiment_id"
    
    # Set Julia memory hints
    export JULIA_HEAP_SIZE_HINT="50G"
    
    log_info "Set JULIA_HEAP_SIZE_HINT to $JULIA_HEAP_SIZE_HINT"
    return 0
}

cleanup_temp_files_action() {
    local experiment_id="$1"
    
    log_info "Cleaning up temporary files for experiment: $experiment_id"
    
    # Clean up various temp locations
    local cleanup_paths=(
        "$GLOBTIM_DIR/hpc/experiments/temp"
        "$GLOBTIM_DIR/hpc_results"
        "/tmp/julia_*"
        "/tmp/globtim_*"
    )
    
    for path in "${cleanup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            find "$path" -type f -mtime +1 -delete 2>/dev/null || true
            log_info "Cleaned up old files in: $path"
        fi
    done
    
    # Also clean up old tmux session logs
    find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    return 0
}

cleanup_old_sessions_action() {
    local experiment_id="$1"
    
    log_info "Cleaning up old tmux sessions for experiment: $experiment_id"
    
    # Kill old globtim tmux sessions
    tmux list-sessions 2>/dev/null | grep globtim | cut -d: -f1 | while read session; do
        # Only kill sessions older than 1 hour
        session_age=$(tmux display-message -t "$session" -p "#{session_created}")
        current_time=$(date +%s)
        
        if [[ $((current_time - session_age)) -gt 3600 ]]; then
            log_info "Killing old tmux session: $session"
            tmux kill-session -t "$session" 2>/dev/null || true
        fi
    done
    
    return 0
}

check_ssh_connectivity_action() {
    local experiment_id="$1"
    
    log_info "Checking SSH connectivity for experiment: $experiment_id"
    
    if [[ "$ENVIRONMENT" == "local" ]]; then
        # Test connection to r04n02
        if ssh -o ConnectTimeout=10 -o BatchMode=yes scholten@r04n02 "echo 'SSH connectivity test successful'" 2>/dev/null; then
            log_info "SSH connectivity test passed"
            return 0
        else
            log_error "SSH connectivity test failed"
            return 1
        fi
    else
        log_info "Running on HPC - SSH connectivity not applicable"
        return 0
    fi
}

clear_julia_cache_action() {
    local experiment_id="$1"
    
    log_info "Clearing Julia compilation cache for experiment: $experiment_id"
    
    # Clear Julia compiled cache
    local julia_cache_dirs=(
        "$HOME/.julia/compiled"
        "$HOME/.julia/logs"
    )
    
    for cache_dir in "${julia_cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            rm -rf "$cache_dir" 2>/dev/null || true
            log_info "Cleared Julia cache: $cache_dir"
        fi
    done
    
    return 0
}

retry_with_backoff_action() {
    local experiment_id="$1"
    local phase="$2"
    
    log_info "Retry with backoff for experiment: $experiment_id (phase: $phase)"
    
    # This is mainly a marker - the actual retry will be handled by the orchestrator
    return 0
}

generic_error_recovery_action() {
    local experiment_id="$1"
    local phase="$2"
    
    log_info "Executing generic error recovery for experiment: $experiment_id (phase: $phase)"
    
    # Generic recovery steps
    cleanup_temp_files_action "$experiment_id"
    
    if [[ "$phase" == "execution" ]]; then
        clear_julia_cache_action "$experiment_id"
    fi
    
    return 0
}

alert_administrator_action() {
    local experiment_id="$1"
    local error_output="$2"
    
    log_info "Alerting administrator about critical failure: $experiment_id"
    
    # Create alert file for monitoring systems
    local alert_file="$RECOVERY_DIR/alerts/critical_failure_${experiment_id}_$(date +%Y%m%d_%H%M%S).alert"
    mkdir -p "$(dirname "$alert_file")"
    
    cat > "$alert_file" << EOF
CRITICAL_FAILURE_ALERT
=====================
Experiment ID: $experiment_id
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Environment: $ENVIRONMENT
Recovery Version: $RECOVERY_VERSION

Error Output:
$error_output

This failure requires administrator intervention.
EOF
    
    log_warning "Critical failure alert created: $alert_file"
    return 0
}

# Main recovery orchestration
recover_experiment() {
    local experiment_id="$1"
    local failed_phase="$2"
    local error_output="$3"
    local attempt_number="${4:-1}"
    
    log_info "Starting recovery for experiment: $experiment_id (attempt: $attempt_number)"
    
    # Analyze the failure
    local analysis_result
    analysis_result=$(analyze_failure "$error_output" "$failed_phase" "$experiment_id")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failure analysis failed for experiment: $experiment_id"
        return 1
    fi
    
    # Parse analysis results
    local pattern_name=$(echo "$analysis_result" | grep "^MATCH_FOUND:" | cut -d: -f2)
    local severity=$(echo "$analysis_result" | grep "^SEVERITY:" | cut -d: -f2)
    local max_retries=$(echo "$analysis_result" | grep "^MAX_RETRIES:" | cut -d: -f2)
    local backoff_seconds=$(echo "$analysis_result" | grep "^BACKOFF:" | cut -d: -f2)
    local actions=($(echo "$analysis_result" | grep "^ACTION:" | cut -d: -f2))
    
    if [[ -n "$pattern_name" && "$pattern_name" != "NO_MATCH_FOUND" ]]; then
        log_info "Matched failure pattern: $pattern_name (severity: $severity)"
    else
        log_warning "No specific failure pattern matched - using generic recovery"
        pattern_name="unknown_failure"
    fi
    
    # Check if we've exceeded max retries
    if [[ $attempt_number -gt $max_retries ]]; then
        log_error "Maximum recovery attempts exceeded ($attempt_number > $max_retries)"
        return 1
    fi
    
    # Record recovery attempt using lifecycle manager
    local lifecycle_manager="$HOOKS_DIR/lifecycle_manager.sh"
    if [[ -x "$lifecycle_manager" ]]; then
        "$lifecycle_manager" recovery "$experiment_id" "$failed_phase" "$pattern_name" "auto_recovery"
    fi
    
    # Apply backoff delay if specified
    if [[ $backoff_seconds -gt 0 ]]; then
        log_info "Applying recovery backoff delay: ${backoff_seconds}s"
        sleep "$backoff_seconds"
    fi
    
    # Execute recovery actions
    local recovery_success=true
    for action in "${actions[@]}"; do
        if [[ -n "$action" ]]; then
            if ! execute_recovery_action "$action" "$experiment_id" "$failed_phase" "$error_output"; then
                log_error "Recovery action failed: $action"
                recovery_success=false
                break
            fi
        fi
    done
    
    if [[ "$recovery_success" == "true" ]]; then
        log_info "Recovery completed successfully for experiment: $experiment_id"
        return 0
    else
        log_error "Recovery failed for experiment: $experiment_id"
        return 1
    fi
}

# Status and monitoring
show_recovery_status() {
    local experiment_id="${1:-}"
    
    if [[ -n "$experiment_id" ]]; then
        # Show specific experiment recovery status
        echo -e "${BOLD}${CYAN}Recovery Status: $experiment_id${NC}"
        echo "==============================="
        
        local lifecycle_manager="$HOOKS_DIR/lifecycle_manager.sh"
        if [[ -x "$lifecycle_manager" ]]; then
            "$lifecycle_manager" report "$experiment_id" | grep -A10 "Recovery Attempts:" || echo "No recovery attempts found."
        fi
    else
        # Show all recent recovery attempts
        echo -e "${BOLD}${CYAN}Recent Recovery Activities${NC}"
        echo "=========================="
        
        find "$LOG_DIR" -name "recovery.log" -exec tail -20 {} \; 2>/dev/null | grep -E "(Starting recovery|Recovery completed|Recovery failed)" | tail -10
    fi
}

list_failure_patterns() {
    echo -e "${BOLD}${CYAN}Available Failure Patterns${NC}"
    echo "=========================="
    
    if [[ -f "$PATTERNS_FILE" ]]; then
        python3 -c "
import json
with open('$PATTERNS_FILE', 'r') as f:
    patterns = json.load(f)

for name, data in patterns.get('patterns', {}).items():
    print(f'{name}:')
    print(f'  Phase: {data.get(\"phase\", \"unknown\")}')
    print(f'  Severity: {data.get(\"severity\", \"unknown\")}')
    print(f'  Max Retries: {data.get(\"max_retries\", 1)}')
    print(f'  Actions: {data.get(\"recovery_actions\", [])}')
    print()
"
    else
        log_error "No failure patterns file found"
    fi
}

# Help and usage
show_help() {
    echo "Automated Recovery Engine v$RECOVERY_VERSION"
    echo "==========================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Recovery Commands:"
    echo "  recover <exp_id> <phase> <error_output>  - Execute recovery for experiment"
    echo "  analyze <error_output> [phase]           - Analyze error and suggest recovery"
    echo ""
    echo "Action Commands:"
    echo "  action <action_name> <exp_id> [phase]    - Execute specific recovery action"
    echo ""
    echo "Status Commands:"
    echo "  status [exp_id]                          - Show recovery status"
    echo "  patterns                                 - List available failure patterns"
    echo ""
    echo "Built-in Recovery Actions:"
    echo "  check_julia_environment    - Validate Julia package environment"
    echo "  reinstall_packages         - Reinstall Julia packages"
    echo "  increase_memory_limit      - Set higher memory limits"
    echo "  cleanup_temp_files         - Clean up temporary files"
    echo "  cleanup_old_sessions       - Remove old tmux sessions"
    echo "  clear_julia_cache          - Clear Julia compilation cache"
    echo "  generic_error_recovery     - Generic recovery steps"
    echo ""
    echo "Examples:"
    echo "  $0 recover exp_001 execution \"OutOfMemoryError: ...\"" 
    echo "  $0 action cleanup_temp_files exp_001"
    echo "  $0 patterns"
}

# Main command dispatcher
main() {
    # Initialize patterns database if needed
    initialize_failure_patterns
    
    case "${1:-help}" in
        recover)
            if [[ -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]]; then
                recover_experiment "$2" "$3" "$4" "${5:-1}"
            else
                log_error "Usage: recover <exp_id> <phase> <error_output> [attempt_number]"
                exit 1
            fi
            ;;
        analyze)
            if [[ -n "${2:-}" ]]; then
                analyze_failure "$2" "${3:-unknown}" "analysis"
            else
                log_error "Usage: analyze <error_output> [phase]"
                exit 1
            fi
            ;;
        action)
            if [[ -n "${2:-}" && -n "${3:-}" ]]; then
                execute_recovery_action "$2" "$3" "${4:-unknown}" "${5:-}"
            else
                log_error "Usage: action <action_name> <exp_id> [phase] [error_output]"
                exit 1
            fi
            ;;
        status)
            show_recovery_status "${2:-}"
            ;;
        patterns)
            list_failure_patterns
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: ${1:-}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"