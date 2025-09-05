#!/bin/bash
# Intelligent Lifecycle State Manager
# Issue #41: Advanced state tracking and lifecycle coordination
# Manages experiment lifecycle transitions and state persistence

set -e

# Configuration
MANAGER_VERSION="1.0.0"
MANAGER_NAME="lifecycle-manager"

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
STATE_DIR="$HOOKS_DIR/state"
HISTORY_DIR="$HOOKS_DIR/history"
METRICS_DIR="$HOOKS_DIR/metrics"

mkdir -p "$STATE_DIR" "$HISTORY_DIR" "$METRICS_DIR"

# Logging functions
log_info() {
    echo -e "${BOLD}${GREEN}[LIFECYCLE-MANAGER]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$HOOKS_DIR/logs/lifecycle.log"
}

log_warning() {
    echo -e "${BOLD}${YELLOW}[LIFECYCLE WARNING]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$HOOKS_DIR/logs/lifecycle.log"
}

log_error() {
    echo -e "${BOLD}${RED}[LIFECYCLE ERROR]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$HOOKS_DIR/logs/lifecycle.log"
}

# Phase definitions and transitions
VALID_PHASES="initialization validation preparation execution monitoring completion recovery cleanup archived"
VALID_STATUSES="pending running completed failed paused retrying"

# Lifecycle transition rules
get_next_phase() {
    local current_phase=$1
    local current_status=$2
    
    case "$current_phase:$current_status" in
        "initialization:completed") echo "validation" ;;
        "validation:completed") echo "preparation" ;;
        "validation:failed") echo "recovery" ;;
        "preparation:completed") echo "execution" ;;
        "preparation:failed") echo "recovery" ;;
        "execution:completed") echo "monitoring" ;;
        "execution:failed") echo "recovery" ;;
        "monitoring:completed") echo "completion" ;;
        "monitoring:failed") echo "recovery" ;;
        "completion:completed") echo "cleanup" ;;
        "completion:failed") echo "recovery" ;;
        "recovery:completed") 
            # Return to the phase that originally failed
            local original_phase=$(get_experiment_metadata "$experiment_id" "recovery_from_phase")
            echo "${original_phase:-validation}"
            ;;
        "recovery:failed") echo "archived" ;;
        "cleanup:completed") echo "archived" ;;
        "cleanup:failed") echo "archived" ;;
        *) echo "$current_phase" ;; # Stay in current phase for other statuses
    esac
}

can_transition_to() {
    local current_phase=$1
    local current_status=$2
    local target_phase=$3
    
    local next_phase
    next_phase=$(get_next_phase "$current_phase" "$current_status")
    
    # Allow direct transition to next phase
    if [[ "$target_phase" == "$next_phase" ]]; then
        return 0
    fi
    
    # Allow transition to recovery from any phase
    if [[ "$target_phase" == "recovery" ]]; then
        return 0
    fi
    
    # Allow transition to cleanup/archived from completion
    if [[ "$current_phase" == "completion" && ("$target_phase" == "cleanup" || "$target_phase" == "archived") ]]; then
        return 0
    fi
    
    # Allow manual override to any phase from failed status (for debugging)
    if [[ "$current_status" == "failed" ]]; then
        return 0
    fi
    
    return 1
}

# Enhanced state management
create_experiment_state() {
    local experiment_id=$1
    local initial_context="${2:-experiment}"
    local experiment_type="${3:-default}"
    
    local state_file="$STATE_DIR/${experiment_id}.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    cat > "$state_file" << EOF
{
    "experiment_id": "$experiment_id",
    "current_phase": "initialization",
    "status": "pending",
    "context": "$initial_context",
    "experiment_type": "$experiment_type",
    "environment": "$ENVIRONMENT",
    "created_at": "$timestamp",
    "updated_at": "$timestamp",
    "phase_history": [
        {
            "phase": "initialization",
            "status": "pending",
            "timestamp": "$timestamp",
            "duration_seconds": 0
        }
    ],
    "metadata": {
        "manager_version": "$MANAGER_VERSION",
        "total_phases": 0,
        "completed_phases": 0,
        "failed_phases": 0,
        "retry_count": 0,
        "estimated_completion": null,
        "performance_metrics": {}
    },
    "recovery_attempts": [],
    "tags": []
}
EOF
    
    log_info "Created experiment state: $experiment_id"
    echo "$state_file"
}

update_experiment_state() {
    local experiment_id=$1
    local new_phase=$2
    local new_status=$3
    local context="${4:-}"
    local duration="${5:-0}"
    
    local state_file="$STATE_DIR/${experiment_id}.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    if [[ ! -f "$state_file" ]]; then
        log_error "State file not found for experiment: $experiment_id"
        return 1
    fi
    
    # Validate phase transition
    local current_phase current_status
    current_phase=$(get_experiment_phase "$experiment_id")
    current_status=$(get_experiment_status "$experiment_id")
    
    if [[ "$new_phase" != "$current_phase" ]]; then
        if ! can_transition_to "$current_phase" "$current_status" "$new_phase"; then
            log_error "Invalid phase transition: $current_phase:$current_status -> $new_phase"
            return 1
        fi
    fi
    
    # Update state using Python for JSON manipulation
    python3 << EOF
import json
import sys

try:
    with open("$state_file", 'r') as f:
        state = json.load(f)
    
    # Update basic state
    old_phase = state["current_phase"]
    old_status = state["status"]
    
    state["current_phase"] = "$new_phase"
    state["status"] = "$new_status"
    state["updated_at"] = "$timestamp"
    
    if "$context":
        state["context"] = "$context"
    
    # Add to phase history if phase changed
    if "$new_phase" != old_phase or "$new_status" != old_status:
        history_entry = {
            "phase": "$new_phase",
            "status": "$new_status", 
            "timestamp": "$timestamp",
            "duration_seconds": int($duration),
            "previous_phase": old_phase,
            "previous_status": old_status
        }
        state["phase_history"].append(history_entry)
    
    # Update metadata counters
    if "$new_status" == "completed" and old_status != "completed":
        state["metadata"]["completed_phases"] += 1
    elif "$new_status" == "failed" and old_status != "failed":
        state["metadata"]["failed_phases"] += 1
    
    state["metadata"]["total_phases"] = len(state["phase_history"])
    
    # Calculate estimated completion based on historical data
    if state["metadata"]["completed_phases"] > 0:
        avg_duration = sum(h.get("duration_seconds", 0) for h in state["phase_history"]) / len(state["phase_history"])
        remaining_phases = 6  # Rough estimate of remaining phases
        state["metadata"]["estimated_completion"] = int(avg_duration * remaining_phases)
    
    with open("$state_file", 'w') as f:
        json.dump(state, f, indent=2)
    
    print("State updated successfully")
    
except Exception as e:
    print(f"Error updating state: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "Updated experiment state: $experiment_id ($current_phase:$current_status -> $new_phase:$new_status)"
        
        # Archive state to history if experiment completed or archived
        if [[ "$new_phase" == "archived" ]]; then
            archive_experiment_state "$experiment_id"
        fi
        
        return 0
    else
        log_error "Failed to update experiment state: $experiment_id"
        return 1
    fi
}

# State retrieval functions
get_experiment_phase() {
    local experiment_id=$1
    local state_file="$STATE_DIR/${experiment_id}.json"
    
    if [[ -f "$state_file" ]]; then
        python3 -c "import json; state=json.load(open('$state_file')); print(state['current_phase'])"
    else
        echo "unknown"
    fi
}

get_experiment_status() {
    local experiment_id=$1
    local state_file="$STATE_DIR/${experiment_id}.json"
    
    if [[ -f "$state_file" ]]; then
        python3 -c "import json; state=json.load(open('$state_file')); print(state['status'])"
    else
        echo "unknown"
    fi
}

get_experiment_metadata() {
    local experiment_id=$1
    local key=$2
    local state_file="$STATE_DIR/${experiment_id}.json"
    
    if [[ -f "$state_file" ]]; then
        python3 -c "import json; state=json.load(open('$state_file')); print(state.get('metadata', {}).get('$key', ''))"
    fi
}

# Performance and metrics tracking
record_performance_metric() {
    local experiment_id=$1
    local metric_name=$2
    local metric_value=$3
    local phase="${4:-unknown}"
    
    local state_file="$STATE_DIR/${experiment_id}.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    if [[ -f "$state_file" ]]; then
        python3 << EOF
import json

with open("$state_file", 'r') as f:
    state = json.load(f)

if "performance_metrics" not in state["metadata"]:
    state["metadata"]["performance_metrics"] = {}

if "$phase" not in state["metadata"]["performance_metrics"]:
    state["metadata"]["performance_metrics"]["$phase"] = {}

state["metadata"]["performance_metrics"]["$phase"]["$metric_name"] = {
    "value": "$metric_value",
    "timestamp": "$timestamp"
}

with open("$state_file", 'w') as f:
    json.dump(state, f, indent=2)
EOF
        log_info "Recorded performance metric: $metric_name=$metric_value for $experiment_id:$phase"
    fi
}

# Recovery and retry management
record_recovery_attempt() {
    local experiment_id=$1
    local failed_phase=$2
    local failure_reason="${3:-unknown}"
    local recovery_action="${4:-retry}"
    
    local state_file="$STATE_DIR/${experiment_id}.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    python3 << EOF
import json

with open("$state_file", 'r') as f:
    state = json.load(f)

recovery_entry = {
    "failed_phase": "$failed_phase",
    "failure_reason": "$failure_reason",
    "recovery_action": "$recovery_action", 
    "timestamp": "$timestamp",
    "attempt_number": len(state.get("recovery_attempts", [])) + 1
}

if "recovery_attempts" not in state:
    state["recovery_attempts"] = []

state["recovery_attempts"].append(recovery_entry)
state["metadata"]["retry_count"] = len(state["recovery_attempts"])

# Store which phase we're recovering from
state["metadata"]["recovery_from_phase"] = "$failed_phase"

with open("$state_file", 'w') as f:
    json.dump(state, f, indent=2)
EOF
    
    log_info "Recorded recovery attempt for $experiment_id: $failed_phase -> $recovery_action"
}

# Archival and cleanup
archive_experiment_state() {
    local experiment_id=$1
    local state_file="$STATE_DIR/${experiment_id}.json"
    local archive_file="$HISTORY_DIR/${experiment_id}_$(date +%Y%m%d_%H%M%S).json"
    
    if [[ -f "$state_file" ]]; then
        cp "$state_file" "$archive_file"
        rm "$state_file"
        log_info "Archived experiment state: $experiment_id -> $archive_file"
    fi
}

# Analytics and reporting
generate_lifecycle_report() {
    local experiment_id=$1
    local state_file="$STATE_DIR/${experiment_id}.json"
    
    if [[ ! -f "$state_file" ]]; then
        log_error "No state file found for experiment: $experiment_id"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}Lifecycle Report: $experiment_id${NC}"
    echo "=================================="
    
    python3 << EOF
import json
from datetime import datetime

with open("$state_file", 'r') as f:
    state = json.load(f)

print(f"Current Phase: {state['current_phase']}")
print(f"Status: {state['status']}")
print(f"Experiment Type: {state['experiment_type']}")
print(f"Environment: {state['environment']}")
print(f"Created: {state['created_at']}")
print(f"Last Updated: {state['updated_at']}")
print()

print("Phase History:")
print("-" * 50)
for i, entry in enumerate(state.get('phase_history', [])):
    duration = entry.get('duration_seconds', 0)
    print(f"{i+1:2d}. {entry['phase']:12} | {entry['status']:9} | {duration:3d}s | {entry['timestamp']}")

print()
print("Metadata:")
print("-" * 50)
meta = state.get('metadata', {})
print(f"Total Phases: {meta.get('total_phases', 0)}")
print(f"Completed: {meta.get('completed_phases', 0)}")
print(f"Failed: {meta.get('failed_phases', 0)}")
print(f"Retry Count: {meta.get('retry_count', 0)}")
if meta.get('estimated_completion'):
    print(f"Est. Completion: {meta['estimated_completion']}s")

if state.get('recovery_attempts'):
    print()
    print("Recovery Attempts:")
    print("-" * 50)
    for i, recovery in enumerate(state['recovery_attempts']):
        print(f"{i+1}. {recovery['failed_phase']} -> {recovery['recovery_action']} ({recovery['failure_reason']})")

performance = meta.get('performance_metrics', {})
if performance:
    print()
    print("Performance Metrics:")
    print("-" * 50)
    for phase, metrics in performance.items():
        print(f"{phase}:")
        for metric_name, metric_data in metrics.items():
            print(f"  {metric_name}: {metric_data['value']}")
EOF
}

# Batch operations
list_active_experiments() {
    echo -e "${BOLD}${CYAN}Active Experiments${NC}"
    echo "=================="
    
    local state_files=("$STATE_DIR"/*.json)
    if [[ ! -f "${state_files[0]}" ]]; then
        echo "No active experiments found."
        return 0
    fi
    
    printf "%-30s %-12s %-10s %-20s\n" "Experiment ID" "Phase" "Status" "Last Updated"
    printf "%-30s %-12s %-10s %-20s\n" "-------------" "-----" "------" "------------"
    
    for state_file in "${state_files[@]}"; do
        if [[ -f "$state_file" ]]; then
            local exp_id=$(basename "$state_file" .json)
            python3 << EOF
import json
with open("$state_file", 'r') as f:
    state = json.load(f)
    
exp_id = "$exp_id"
if len(exp_id) > 28:
    exp_id = exp_id[:25] + "..."
    
print(f"{exp_id:<30} {state['current_phase']:<12} {state['status']:<10} {state['updated_at'][:19]}")
EOF
        fi
    done
}

cleanup_old_states() {
    local days_old="${1:-30}"
    
    log_info "Cleaning up states older than $days_old days"
    
    find "$STATE_DIR" -name "*.json" -mtime +$days_old -exec rm {} \;
    find "$HISTORY_DIR" -name "*.json" -mtime +90 -exec rm {} \;
    find "$METRICS_DIR" -name "*.json" -mtime +90 -exec rm {} \;
    
    log_info "Cleanup completed"
}

# Help and usage
show_help() {
    echo "Intelligent Lifecycle State Manager v$MANAGER_VERSION"
    echo "===================================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "State Management:"
    echo "  create <exp_id> [context] [type]    - Create new experiment state"
    echo "  update <exp_id> <phase> <status>    - Update experiment state"
    echo "  phase <exp_id>                      - Get current phase"
    echo "  status <exp_id>                     - Get current status"
    echo ""
    echo "Performance Tracking:"
    echo "  metric <exp_id> <name> <value>      - Record performance metric"
    echo "  recovery <exp_id> <phase> <reason>  - Record recovery attempt"
    echo ""
    echo "Reporting:"
    echo "  report <exp_id>                     - Generate lifecycle report"
    echo "  list                                - List all active experiments"
    echo ""
    echo "Maintenance:"
    echo "  archive <exp_id>                    - Archive experiment state"
    echo "  cleanup [days]                      - Clean up old states (default: 30 days)"
    echo ""
    echo "Valid Phases: $VALID_PHASES"
    echo "Valid Statuses: $VALID_STATUSES"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        create)
            if [[ -n "${2:-}" ]]; then
                create_experiment_state "$2" "${3:-experiment}" "${4:-default}"
            else
                log_error "Experiment ID required"
                exit 1
            fi
            ;;
        update)
            if [[ -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]]; then
                update_experiment_state "$2" "$3" "$4" "${5:-}" "${6:-0}"
            else
                log_error "Usage: update <exp_id> <phase> <status> [context] [duration]"
                exit 1
            fi
            ;;
        phase)
            if [[ -n "${2:-}" ]]; then
                get_experiment_phase "$2"
            else
                log_error "Experiment ID required"
                exit 1
            fi
            ;;
        status)
            if [[ -n "${2:-}" ]]; then
                get_experiment_status "$2"
            else
                log_error "Experiment ID required"
                exit 1
            fi
            ;;
        metric)
            if [[ -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]]; then
                record_performance_metric "$2" "$3" "$4" "${5:-unknown}"
            else
                log_error "Usage: metric <exp_id> <name> <value> [phase]"
                exit 1
            fi
            ;;
        recovery)
            if [[ -n "${2:-}" && -n "${3:-}" ]]; then
                record_recovery_attempt "$2" "$3" "${4:-unknown}" "${5:-retry}"
            else
                log_error "Usage: recovery <exp_id> <phase> [reason] [action]"
                exit 1
            fi
            ;;
        report)
            if [[ -n "${2:-}" ]]; then
                generate_lifecycle_report "$2"
            else
                log_error "Experiment ID required"
                exit 1
            fi
            ;;
        list)
            list_active_experiments
            ;;
        archive)
            if [[ -n "${2:-}" ]]; then
                archive_experiment_state "$2"
            else
                log_error "Experiment ID required"
                exit 1
            fi
            ;;
        cleanup)
            cleanup_old_states "${2:-30}"
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