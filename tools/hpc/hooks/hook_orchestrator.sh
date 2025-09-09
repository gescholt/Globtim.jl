#!/bin/bash
# Strategic Hook Orchestrator for HPC Computation Pipeline
# Issue #41: Unified hook integration with intelligent lifecycle management
# Coordinates all HPC hooks with phase-aware execution and automated recovery

set -e

# Version and metadata
ORCHESTRATOR_VERSION="1.0.0"
ORCHESTRATOR_NAME="hpc-hook-orchestrator"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration - Auto-detect environment
if [[ -d "/home/scholten/globtim" ]]; then
    GLOBTIM_DIR="/home/scholten/globtim"
    ENVIRONMENT="hpc"
else
    GLOBTIM_DIR="/Users/ghscholt/globtim"
    ENVIRONMENT="local"
fi

HOOKS_DIR="$GLOBTIM_DIR/tools/hpc/hooks"
REGISTRY_FILE="$HOOKS_DIR/hook_registry.json"
STATE_DIR="$HOOKS_DIR/state"
LOG_DIR="$HOOKS_DIR/logs"

# Create necessary directories
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Logging functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$ORCHESTRATOR_NAME] [$level] $message" | tee -a "$LOG_DIR/orchestrator.log"
}

log_info() {
    log "INFO" "$@"
    echo -e "${BOLD}${GREEN}[ORCHESTRATOR]${NC} $*" >&2
}

log_warning() {
    log "WARN" "$@"
    echo -e "${BOLD}${YELLOW}[ORCHESTRATOR WARNING]${NC} $*" >&2
}

log_error() {
    log "ERROR" "$@"
    echo -e "${BOLD}${RED}[ORCHESTRATOR ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        log "DEBUG" "$@"
        echo -e "${BOLD}${BLUE}[ORCHESTRATOR DEBUG]${NC} $*" >&2
    fi
}

# Execution phases (using space-separated format for compatibility)
PHASES="validation:Pre-execution_validation_and_environment_checks preparation:Resource_preparation_and_experiment_setup execution:Core_experiment_execution monitoring:Real-time_monitoring_and_performance_tracking completion:Post-execution_cleanup_and_result_processing recovery:Error_handling_and_automated_recovery"

get_phase_description() {
    local phase=$1
    echo "$PHASES" | tr ' ' '\n' | grep "^${phase}:" | cut -d: -f2 | tr '_' ' '
}

# State management functions
save_experiment_state() {
    local experiment_id=$1
    local phase=$2
    local status=$3
    local context="${4:-}"
    
    local state_file="$STATE_DIR/${experiment_id}.state"
    
    cat > "$state_file" << EOF
{
    "experiment_id": "$experiment_id",
    "current_phase": "$phase", 
    "status": "$status",
    "context": "$context",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "orchestrator_version": "$ORCHESTRATOR_VERSION"
}
EOF
    
    log_debug "Saved state for experiment $experiment_id: phase=$phase, status=$status"
}

load_experiment_state() {
    local experiment_id=$1
    local state_file="$STATE_DIR/${experiment_id}.state"
    
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
        return 0
    else
        log_debug "No state file found for experiment: $experiment_id"
        return 1
    fi
}

get_current_phase() {
    local experiment_id=$1
    local state_json
    
    if state_json=$(load_experiment_state "$experiment_id"); then
        echo "$state_json" | grep -o '"current_phase": "[^"]*"' | cut -d'"' -f4
    else
        echo "validation"  # Default to first phase
    fi
}

get_experiment_status() {
    local experiment_id=$1
    local state_json
    
    if state_json=$(load_experiment_state "$experiment_id"); then
        echo "$state_json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4
    else
        echo "unknown"
    fi
}

# Hook registry management
load_hook_registry() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_warning "Hook registry not found, creating default registry"
        create_default_registry
    fi
    
    cat "$REGISTRY_FILE"
}

get_hooks_for_phase() {
    local phase=$1
    local context="${2:-experiment}"
    local experiment_type="${3:-default}"
    
    local registry_json
    registry_json=$(load_hook_registry)
    
    # Extract hooks for the specified phase that match context and experiment type
    echo "$registry_json" | python3 -c "
import json, sys
registry = json.load(sys.stdin)
phase = '$phase'
context = '$context'
experiment_type = '$experiment_type'

hooks = []
for hook_id, config in registry.get('hooks', {}).items():
    if phase in config.get('phases', []):
        # Check context match
        if context in config.get('contexts', ['*']) or '*' in config.get('contexts', []):
            # Check experiment type match  
            if experiment_type in config.get('experiment_types', ['*']) or '*' in config.get('experiment_types', []):
                hooks.append({
                    'id': hook_id,
                    'path': config['path'],
                    'priority': config.get('priority', 50),
                    'timeout': config.get('timeout', 300),
                    'retry_count': config.get('retry_count', 1),
                    'critical': config.get('critical', False)
                })

# Sort by priority (lower numbers = higher priority)
hooks.sort(key=lambda x: x['priority'])
print(json.dumps(hooks, indent=2))
"
}

# Hook execution functions
execute_hook() {
    local hook_config=$1
    local experiment_id=$2
    local phase=$3
    local context="${4:-}"
    
    local hook_id=$(echo "$hook_config" | python3 -c "import json, sys; print(json.load(sys.stdin)['id'])")
    local hook_path=$(echo "$hook_config" | python3 -c "import json, sys; print(json.load(sys.stdin)['path'])")
    local timeout=$(echo "$hook_config" | python3 -c "import json, sys; print(json.load(sys.stdin).get('timeout', 300))")
    local retry_count=$(echo "$hook_config" | python3 -c "import json, sys; print(json.load(sys.stdin).get('retry_count', 1))")
    local is_critical=$(echo "$hook_config" | python3 -c "import json, sys; print(json.load(sys.stdin).get('critical', False))")
    
    log_info "Executing hook: $hook_id (phase: $phase)"
    log_debug "Hook path: $hook_path, timeout: ${timeout}s, retries: $retry_count, critical: $is_critical"
    
    # Resolve hook path with environment-aware path translation
    local full_path
    if [[ "$hook_path" = /* ]]; then
        # Absolute path - check if it needs environment translation
        if [[ "$ENVIRONMENT" == "hpc" && "$hook_path" =~ ^/Users/ghscholt ]]; then
            # Translate macOS paths to HPC paths
            full_path="${hook_path/\/Users\/ghscholt/\/home\/scholten}"
        elif [[ "$ENVIRONMENT" == "local" && "$hook_path" =~ ^/home/scholten ]]; then
            # Translate HPC paths to macOS paths
            full_path="${hook_path/\/home\/scholten/\/Users\/ghscholt}"
        else
            full_path="$hook_path"
        fi
    else
        full_path="$GLOBTIM_DIR/$hook_path"
    fi
    
    if [[ ! -x "$full_path" ]]; then
        log_error "Hook not executable or not found: $full_path"
        if [[ "$is_critical" == "true" ]]; then
            return 1
        else
            log_warning "Skipping non-critical hook: $hook_id"
            return 0
        fi
    fi
    
    # Set up environment for hook execution
    export HOOK_ORCHESTRATOR_VERSION="$ORCHESTRATOR_VERSION"
    export HOOK_EXPERIMENT_ID="$experiment_id"
    export HOOK_PHASE="$phase"
    export HOOK_CONTEXT="$context"
    export HOOK_ENVIRONMENT="$ENVIRONMENT"
    export CLAUDE_CONTEXT="$context"
    
    # Execute hook with retries
    local attempt=1
    local hook_output
    local hook_exit_code
    
    while [[ $attempt -le $retry_count ]]; do
        log_debug "Executing hook $hook_id (attempt $attempt/$retry_count)"
        
        if [[ $attempt -gt 1 ]]; then
            log_info "Retrying hook $hook_id (attempt $attempt/$retry_count)"
            sleep $((attempt * 2))  # Exponential backoff
        fi
        
        # Execute with timeout (environment-aware)
        if [[ "$ENVIRONMENT" == "local" ]] || ! command -v timeout >/dev/null 2>&1; then
            # On macOS or when timeout is not available, run without timeout
            if hook_output=$("$full_path" "$context" 2>&1); then
                hook_exit_code=0
                log_info "Hook $hook_id completed successfully"
                break
            else
                hook_exit_code=$?
                log_warning "Hook $hook_id failed (attempt $attempt/$retry_count): exit code $hook_exit_code"
                log_debug "Hook output: $hook_output"
            fi
        else
            # On Linux/HPC with timeout available
            if hook_output=$(timeout "$timeout" "$full_path" "$context" 2>&1); then
                hook_exit_code=0
                log_info "Hook $hook_id completed successfully"
                break
            else
                hook_exit_code=$?
                log_warning "Hook $hook_id failed (attempt $attempt/$retry_count): exit code $hook_exit_code"
                log_debug "Hook output: $hook_output"
            fi
        fi
        
        ((attempt++))
    done
    
    # Log hook execution result
    local result_file="$LOG_DIR/hook_${hook_id}_${experiment_id}_$(date +%Y%m%d_%H%M%S).log"
    cat > "$result_file" << EOF
Hook Execution Report
====================
Hook ID: $hook_id
Hook Path: $full_path
Experiment ID: $experiment_id
Phase: $phase
Context: $context
Attempts: $((attempt - 1))/$retry_count
Exit Code: $hook_exit_code
Critical: $is_critical
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Output:
$hook_output
EOF
    
    if [[ $hook_exit_code -eq 0 ]]; then
        log_info "Hook $hook_id executed successfully"
        return 0
    else
        log_error "Hook $hook_id failed after $retry_count attempts"
        if [[ "$is_critical" == "true" ]]; then
            log_error "Critical hook failure - aborting phase execution"
            return 1
        else
            log_warning "Non-critical hook failure - continuing execution"
            return 0
        fi
    fi
}

execute_phase() {
    local experiment_id=$1
    local phase=$2
    local context="${3:-experiment}"
    local experiment_type="${4:-default}"
    
    log_info "Starting phase: $phase for experiment: $experiment_id"
    
    # Initialize lifecycle management
    local lifecycle_manager="$HOOKS_DIR/lifecycle_manager.sh"
    if [[ -x "$lifecycle_manager" ]]; then
        "$lifecycle_manager" update "$experiment_id" "$phase" "running" "$context" 0
    else
        save_experiment_state "$experiment_id" "$phase" "running" "$context"
    fi
    
    # Get hooks for this phase
    local hooks_json
    hooks_json=$(get_hooks_for_phase "$phase" "$context" "$experiment_type")
    
    if [[ "$hooks_json" == "[]" ]]; then
        log_info "No hooks configured for phase: $phase"
        if [[ -x "$lifecycle_manager" ]]; then
            "$lifecycle_manager" update "$experiment_id" "$phase" "completed" "$context" 0
        else
            save_experiment_state "$experiment_id" "$phase" "completed" "$context"
        fi
        return 0
    fi
    
    # Execute hooks in priority order
    local hook_count
    hook_count=$(echo "$hooks_json" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))")
    
    log_info "Executing $hook_count hooks for phase: $phase"
    
    local i=0
    while [[ $i -lt $hook_count ]]; do
        local hook_config
        hook_config=$(echo "$hooks_json" | python3 -c "import json, sys; hooks = json.load(sys.stdin); print(json.dumps(hooks[$i]))" i=$i)
        
        if ! execute_hook "$hook_config" "$experiment_id" "$phase" "$context"; then
            log_error "Phase $phase failed due to hook execution failure"
            
            # Update lifecycle state to failed
            if [[ -x "$lifecycle_manager" ]]; then
                "$lifecycle_manager" update "$experiment_id" "$phase" "failed" "$context" 0
            else
                save_experiment_state "$experiment_id" "$phase" "failed" "$context"
            fi
            
            # Attempt automated recovery if recovery engine is available
            local recovery_engine="$HOOKS_DIR/recovery_engine.sh"
            if [[ -x "$recovery_engine" ]]; then
                log_info "Attempting automated recovery for phase failure"
                local hook_log=$(ls -t "$LOG_DIR"/hook_*.log | head -1)
                local error_output=""
                if [[ -f "$hook_log" ]]; then
                    error_output=$(cat "$hook_log")
                fi
                
                if "$recovery_engine" recover "$experiment_id" "$phase" "$error_output" 1; then
                    log_info "Automated recovery succeeded - retrying phase"
                    # Retry the phase after successful recovery
                    if execute_phase "$experiment_id" "$phase" "$context" "$experiment_type"; then
                        return 0
                    fi
                fi
                
                log_error "Automated recovery failed or retry unsuccessful"
            fi
            
            return 1
        fi
        
        ((i++))
    done
    
    log_info "Phase $phase completed successfully for experiment: $experiment_id"
    if [[ -x "$lifecycle_manager" ]]; then
        "$lifecycle_manager" update "$experiment_id" "$phase" "completed" "$context" 0
    else
        save_experiment_state "$experiment_id" "$phase" "completed" "$context"
    fi
    return 0
}

# Context and experiment type detection
detect_experiment_type() {
    local context="$1"
    
    if [[ "$context" =~ 4d ]]; then
        echo "4d"
    elif [[ "$context" =~ 2d ]]; then  
        echo "2d"
    elif [[ "$context" =~ (test|benchmark) ]]; then
        echo "test"
    else
        echo "default"
    fi
}

extract_experiment_id() {
    local context="$1"
    
    # Try to extract from existing tmux session or generate new one
    if [[ "$context" =~ globtim_([^_]+_[0-9]+_[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$(basename "${context// /_}")_$(date +%Y%m%d_%H%M%S)"
    fi
}

# Main orchestration functions
orchestrate_full_pipeline() {
    local context="$1"
    local experiment_type
    local experiment_id
    
    experiment_type=$(detect_experiment_type "$context")
    experiment_id=$(extract_experiment_id "$context")
    
    log_info "Starting full pipeline orchestration"
    log_info "Context: $context"
    log_info "Experiment Type: $experiment_type" 
    log_info "Experiment ID: $experiment_id"
    
    # Initialize experiment state using lifecycle manager and mark initialization as completed
    local lifecycle_manager="$HOOKS_DIR/lifecycle_manager.sh"
    if [[ -x "$lifecycle_manager" ]]; then
        "$lifecycle_manager" create "$experiment_id" "$context" "$experiment_type"
        "$lifecycle_manager" update "$experiment_id" "initialization" "completed" "$context" 0
    fi
    
    # Define phase execution order
    local phases=("validation" "preparation" "execution" "monitoring" "completion")
    
    for phase in "${phases[@]}"; do
        log_info "Orchestrating phase: $phase"
        
        if ! execute_phase "$experiment_id" "$phase" "$context" "$experiment_type"; then
            log_error "Pipeline failed at phase: $phase"
            
            # Attempt recovery if available
            if execute_phase "$experiment_id" "recovery" "$context" "$experiment_type"; then
                log_info "Recovery phase completed - attempting to continue"
                # Continue with next phase after successful recovery
                continue
            else
                log_error "Recovery failed - aborting pipeline"
                return 1
            fi
        fi
        
        log_info "Phase $phase completed successfully"
    done
    
    log_info "Full pipeline orchestration completed successfully"
    if [[ -x "$lifecycle_manager" ]]; then
        "$lifecycle_manager" update "$experiment_id" "archived" "completed" "$context" 0
    else
        save_experiment_state "$experiment_id" "pipeline" "completed" "$context"
    fi
    return 0
}

orchestrate_single_phase() {
    local phase="$1"
    local context="${2:-experiment}"
    local experiment_type
    local experiment_id
    
    experiment_type=$(detect_experiment_type "$context")
    experiment_id=$(extract_experiment_id "$context")
    
    log_info "Starting single phase orchestration: $phase"
    log_info "Context: $context"
    log_info "Experiment Type: $experiment_type"
    log_info "Experiment ID: $experiment_id"
    
    if execute_phase "$experiment_id" "$phase" "$context" "$experiment_type"; then
        log_info "Single phase orchestration completed successfully: $phase"
        return 0
    else
        log_error "Single phase orchestration failed: $phase"
        return 1
    fi
}

# Status and monitoring functions
show_experiment_status() {
    local experiment_id="${1:-}"
    
    if [[ -n "$experiment_id" ]]; then
        # Show specific experiment status
        local state_json
        if state_json=$(load_experiment_state "$experiment_id"); then
            echo -e "${BOLD}${CYAN}Experiment Status: $experiment_id${NC}"
            echo "=================================="
            echo "$state_json" | python3 -c "
import json, sys
state = json.load(sys.stdin)
print(f'Phase: {state[\"current_phase\"]}')
print(f'Status: {state[\"status\"]}')  
print(f'Context: {state[\"context\"]}')
print(f'Environment: {state[\"environment\"]}')
print(f'Last Updated: {state[\"timestamp\"]}')
"
        else
            log_error "No state found for experiment: $experiment_id"
            return 1
        fi
    else
        # Show all experiments
        echo -e "${BOLD}${CYAN}All Experiment Status${NC}"
        echo "===================="
        
        local state_files=("$STATE_DIR"/*.state)
        if [[ ! -f "${state_files[0]}" ]]; then
            echo "No active experiments found."
            return 0
        fi
        
        for state_file in "${state_files[@]}"; do
            if [[ -f "$state_file" ]]; then
                local exp_id=$(basename "$state_file" .state)
                local state_json=$(cat "$state_file")
                local phase=$(echo "$state_json" | grep -o '"current_phase": "[^"]*"' | cut -d'"' -f4)
                local status=$(echo "$state_json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
                
                echo "  $exp_id: $phase ($status)"
            fi
        done
    fi
}

show_hook_registry() {
    echo -e "${BOLD}${CYAN}Hook Registry${NC}"
    echo "============="
    
    if [[ -f "$REGISTRY_FILE" ]]; then
        cat "$REGISTRY_FILE" | python3 -c "
import json, sys
registry = json.load(sys.stdin)
for hook_id, config in registry.get('hooks', {}).items():
    print(f'{hook_id}:')
    print(f'  Path: {config[\"path\"]}')
    print(f'  Phases: {config.get(\"phases\", [])}')
    print(f'  Contexts: {config.get(\"contexts\", [])}')
    print(f'  Priority: {config.get(\"priority\", 50)}')
    print(f'  Critical: {config.get(\"critical\", False)}')
    print()
"
    else
        echo "No hook registry found."
    fi
}

# Help and usage functions
show_help() {
    echo "Strategic Hook Orchestrator v$ORCHESTRATOR_VERSION"
    echo "=================================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Pipeline Commands:"
    echo "  orchestrate <context>           - Run full pipeline orchestration"
    echo "  phase <phase_name> [context]   - Execute single phase"
    echo ""  
    echo "Management Commands:"
    echo "  status [experiment_id]         - Show experiment status"
    echo "  registry                       - Show hook registry"
    echo "  cleanup [experiment_id]        - Clean up experiment state"
    echo ""
    echo "Available Phases:"
    echo "$PHASES" | tr ' ' '\n' | while IFS=: read -r phase desc; do
        echo "  $phase - $(echo "$desc" | tr '_' ' ')"
    done
    echo ""
    echo "Examples:"
    echo "  $0 orchestrate \"4d-model 10 12\"           # Full pipeline"
    echo "  $0 phase validation \"test experiment\"     # Single validation"
    echo "  $0 status globtim_4d_20250905_143022       # Experiment status"
    echo ""
    echo "Environment Variables:"
    echo "  DEBUG=true                     - Enable debug logging"
    echo "  HOOK_TIMEOUT=600               - Override default hook timeout"
}

# Cleanup functions
cleanup_experiment() {
    local experiment_id="${1:-}"
    
    if [[ -z "$experiment_id" ]]; then
        log_error "Experiment ID required for cleanup"
        return 1
    fi
    
    local state_file="$STATE_DIR/${experiment_id}.state"
    
    if [[ -f "$state_file" ]]; then
        rm "$state_file"
        log_info "Cleaned up state for experiment: $experiment_id"
    else
        log_warning "No state file found for experiment: $experiment_id"
    fi
    
    # Clean up old log files for this experiment
    find "$LOG_DIR" -name "hook_*_${experiment_id}_*.log" -mtime +7 -delete 2>/dev/null || true
    
    log_info "Cleanup completed for experiment: $experiment_id"
}

create_default_registry() {
    log_info "Creating default hook registry"
    
    cat > "$REGISTRY_FILE" << 'EOF'
{
    "version": "1.0.0",
    "description": "Strategic Hook Integration Registry - Issue #41",
    "hooks": {
        "pre_execution_validation": {
            "path": "/Users/ghscholt/.claude/hooks/pre-execution-validation.sh",
            "phases": ["validation"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 10,
            "timeout": 60,
            "retry_count": 2,
            "critical": true,
            "description": "Pre-execution validation from Issue #27"
        },
        "resource_monitor": {
            "path": "tools/hpc/monitoring/hpc_resource_monitor_hook.sh",
            "phases": ["monitoring", "preparation"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 30,
            "timeout": 30,
            "retry_count": 1,
            "critical": false,
            "description": "HPC resource monitoring from Issue #26"
        },
        "ssh_security": {
            "path": "tools/hpc/ssh-security-hook.sh", 
            "phases": ["validation", "preparation"],
            "contexts": ["hpc", "cluster"],
            "experiment_types": ["*"],
            "priority": 5,
            "timeout": 15,
            "retry_count": 1,
            "critical": true,
            "description": "SSH security validation for HPC access"
        },
        "gitlab_integration": {
            "path": "tools/gitlab/gitlab-security-hook.sh",
            "phases": ["completion"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 50,
            "timeout": 30,
            "retry_count": 1,
            "critical": false,
            "description": "GitLab project integration and status updates"
        },
        "package_loading_detector": {
            "path": "tools/hpc/hooks/package_loading_detector.sh",
            "phases": ["validation", "preparation"],
            "contexts": ["*"],
            "experiment_types": ["*"],
            "priority": 15,
            "timeout": 120,
            "retry_count": 1,
            "critical": true,
            "description": "Package loading failure detection and automatic resolution guidance"
        }
    }
}
EOF
    
    log_info "Default hook registry created at: $REGISTRY_FILE"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        orchestrate)
            if [[ -n "${2:-}" ]]; then
                orchestrate_full_pipeline "$2"
            else
                log_error "Context required for orchestration"
                exit 1
            fi
            ;;
        phase)
            if [[ -n "${2:-}" ]]; then
                orchestrate_single_phase "$2" "${3:-experiment}"
            else
                log_error "Phase name required"
                exit 1  
            fi
            ;;
        status)
            show_experiment_status "${2:-}"
            ;;
        registry)
            show_hook_registry
            ;;
        cleanup)
            cleanup_experiment "${2:-}"
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

# Initialize on first run
if [[ ! -f "$REGISTRY_FILE" ]]; then
    create_default_registry
fi

# Execute main function
main "$@"