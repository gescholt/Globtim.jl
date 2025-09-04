#!/bin/bash
# Claude Code Agent Integration for HPC Resource Monitoring
# =========================================================
#
# Integration layer that enables Claude Code agents to trigger HPC resource
# monitoring hooks and access comprehensive system status information.
# This script serves as the bridge between Claude Code operations and
# the HPC Resource Monitor Hook system.
#
# Agent Integration Points:
# - hpc-cluster-operator: Experiment lifecycle management
# - project-task-updater: HPC status validation for GitLab updates
# - julia-test-architect: HPC-based testing coordination
# - julia-documenter-expert: HPC documentation builds
# - julia-repo-guardian: Cross-environment validation
#
# Usage:
#   # Called by Claude Code agents automatically
#   tools/hpc/monitoring/agent_integration.sh --agent hpc-cluster-operator --action start_experiment
#   tools/hpc/monitoring/agent_integration.sh --agent project-task-updater --action validate_completion
#   tools/hpc/monitoring/agent_integration.sh --context "GitLab issue update" --validate-cluster
#
# Author: Claude Code HPC monitoring system
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
RESOURCE_HOOK="$HOME/.claude/hooks/hpc-resource-monitor.sh"
SSH_SECURITY_HOOK="$PROJECT_ROOT/tools/hpc/ssh-security-hook.sh"
INTEGRATION_LOG="$PROJECT_ROOT/tools/hpc/.agent_integration.log"

# Agent configuration
AGENT_TYPES=(
    "hpc-cluster-operator"
    "project-task-updater"
    "julia-test-architect"
    "julia-documenter-expert"
    "julia-repo-guardian"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function log_integration_event() {
    local level="$1"
    local agent="$2"
    local action="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "agent": "$agent",
  "action": "$action",
  "message": "$message",
  "claude_context": "${CLAUDE_CONTEXT:-unknown}",
  "claude_tool_name": "${CLAUDE_TOOL_NAME:-unknown}",
  "claude_subagent_type": "${CLAUDE_SUBAGENT_TYPE:-unknown}"
}
EOF
)
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$INTEGRATION_LOG")"
    echo "$log_entry" >> "$INTEGRATION_LOG"
    
    # Console output with color
    local color="$NC"
    case "$level" in
        "ERROR") color="$RED" ;;
        "WARNING") color="$YELLOW" ;;
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
    esac
    
    echo -e "${color}[$timestamp] [$agent] $message${NC}" >&2
}

function usage() {
    cat <<EOF
Claude Code Agent Integration for HPC Resource Monitoring
========================================================

Integration layer for Claude Code agents to access HPC monitoring capabilities.

Usage: $0 [OPTIONS] --agent AGENT_TYPE --action ACTION

Options:
  --agent AGENT_TYPE          Claude Code agent type (required)
  --action ACTION            Action to perform (required)
  --context CONTEXT          Claude Code context description
  --validate-cluster         Validate cluster access before proceeding
  --format FORMAT           Output format: json, text (default: json)
  --timeout SECONDS         Operation timeout (default: 60)
  --help                    Show this help

Agent Types:
  hpc-cluster-operator      HPC experiment management and execution
  project-task-updater      GitLab issue updates with HPC validation
  julia-test-architect      HPC-based testing coordination
  julia-documenter-expert   HPC documentation builds
  julia-repo-guardian       Cross-environment validation

Actions:
  start_experiment          Start HPC experiment with monitoring
  monitor_experiment        Get experiment status and resources
  validate_completion       Validate experiment completion
  check_resources           Get current system resource status
  validate_cluster          Validate cluster connectivity and health
  get_dashboard_url         Get monitoring dashboard information
  emergency_stop            Emergency stop for runaway experiments
  cleanup_stale             Clean up stale experiments and sessions

Examples:
  # HPC cluster operator starting experiment
  $0 --agent hpc-cluster-operator --action start_experiment --context "4D parameter estimation"

  # Project task updater validating completion
  $0 --agent project-task-updater --action validate_completion --context "GitLab issue #26 update"

  # Emergency stop from any agent
  $0 --agent hpc-cluster-operator --action emergency_stop --context "Memory overflow detected"

  # Cluster validation for GitLab updates
  $0 --agent project-task-updater --validate-cluster --context "HPC status verification"

Integration Features:
  - SSH security validation through security hooks
  - Resource monitoring with automated alerts
  - Performance tracking and regression detection
  - Automated cleanup and maintenance
  - Dashboard access and status reporting

Environment Variables:
  CLAUDE_CONTEXT          Description of current Claude Code context
  CLAUDE_TOOL_NAME        Name of tool/operation being performed
  CLAUDE_SUBAGENT_TYPE    Type of Claude Code subagent making request

EOF
}

function validate_agent_type() {
    local agent_type="$1"
    
    local valid=false
    for valid_agent in "${AGENT_TYPES[@]}"; do
        if [[ "$agent_type" == "$valid_agent" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == false ]]; then
        echo -e "${RED}❌ Invalid agent type: $agent_type${NC}" >&2
        echo "Valid agent types: ${AGENT_TYPES[*]}" >&2
        return 1
    fi
}

function validate_cluster_access() {
    local agent="$1"
    
    log_integration_event "INFO" "$agent" "cluster_validation" "Validating cluster access through SSH security framework"
    
    # Use SSH security hook for validation
    if [[ -x "$SSH_SECURITY_HOOK" ]]; then
        if "$SSH_SECURITY_HOOK" validate >/dev/null 2>&1; then
            log_integration_event "SUCCESS" "$agent" "cluster_validation" "Cluster access validated successfully"
            return 0
        else
            log_integration_event "ERROR" "$agent" "cluster_validation" "Cluster access validation failed"
            return 1
        fi
    else
        log_integration_event "WARNING" "$agent" "cluster_validation" "SSH security hook not available, using fallback validation"
        
        # Fallback validation using resource hook
        if [[ -x "$RESOURCE_HOOK" ]]; then
            if "$RESOURCE_HOOK" health_check >/dev/null 2>&1; then
                log_integration_event "SUCCESS" "$agent" "cluster_validation" "Cluster access validated via fallback method"
                return 0
            else
                log_integration_event "ERROR" "$agent" "cluster_validation" "Fallback cluster validation failed"
                return 1
            fi
        else
            log_integration_event "ERROR" "$agent" "cluster_validation" "No validation methods available"
            return 1
        fi
    fi
}

function execute_agent_action() {
    local agent="$1"
    local action="$2"
    local format="${3:-json}"
    local timeout="${4:-60}"
    
    log_integration_event "INFO" "$agent" "$action" "Executing agent action with timeout ${timeout}s"
    
    case "$action" in
        "start_experiment")
            execute_start_experiment "$agent" "$format" "$timeout"
            ;;
        "monitor_experiment")
            execute_monitor_experiment "$agent" "$format" "$timeout"
            ;;
        "validate_completion")
            execute_validate_completion "$agent" "$format" "$timeout"
            ;;
        "check_resources")
            execute_check_resources "$agent" "$format" "$timeout"
            ;;
        "validate_cluster")
            if validate_cluster_access "$agent"; then
                echo '{"status": "success", "message": "Cluster access validated"}'
            else
                echo '{"status": "failed", "message": "Cluster access validation failed"}'
            fi
            ;;
        "get_dashboard_url")
            execute_get_dashboard_url "$agent" "$format"
            ;;
        "emergency_stop")
            execute_emergency_stop "$agent" "$format" "$timeout"
            ;;
        "cleanup_stale")
            execute_cleanup_stale "$agent" "$format" "$timeout"
            ;;
        *)
            log_integration_event "ERROR" "$agent" "$action" "Unknown action requested"
            echo '{"status": "error", "message": "Unknown action: '$action'"}'
            return 1
            ;;
    esac
}

function execute_start_experiment() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "INFO" "$agent" "start_experiment" "Starting experiment with monitoring integration"
    
    # Validate cluster access first
    if ! validate_cluster_access "$agent"; then
        echo '{"status": "failed", "message": "Cluster access validation failed", "action": "start_experiment"}'
        return 1
    fi
    
    # Get current resource status
    local resource_status="{}"
    if [[ -x "$RESOURCE_HOOK" ]]; then
        resource_status=$("$RESOURCE_HOOK" status 2>/dev/null) || resource_status='{"error": "resource_check_failed"}'
    fi
    
    # Check if resources are adequate for experiment
    if command -v python3 >/dev/null 2>&1; then
        local resource_check
        resource_check=$(python3 -c "
import json
try:
    data = json.loads('''$resource_status''')
    resources = data.get('system_resources', {})
    memory = resources.get('memory', {})
    disk = resources.get('disk', {})
    
    mem_usage = memory.get('usage_percent', 0)
    disk_usage = disk.get('usage_percent', 0)
    anomalies = len(data.get('anomalies', []))
    
    if mem_usage > 90 or disk_usage > 90:
        print('insufficient_resources')
    elif anomalies > 2:
        print('system_issues')
    else:
        print('ready')
except:
    print('unknown')
")
        
        if [[ "$resource_check" == "insufficient_resources" ]]; then
            log_integration_event "WARNING" "$agent" "start_experiment" "Insufficient resources for experiment start"
            echo '{"status": "warning", "message": "System resources may be insufficient", "resource_status": '$resource_status'}'
            return 0  # Warning, not error
        elif [[ "$resource_check" == "system_issues" ]]; then
            log_integration_event "WARNING" "$agent" "start_experiment" "System anomalies detected before experiment start"
            echo '{"status": "warning", "message": "System anomalies detected", "resource_status": '$resource_status'}'
            return 0
        fi
    fi
    
    # Experiment can proceed
    log_integration_event "SUCCESS" "$agent" "start_experiment" "Experiment cleared to start with monitoring active"
    echo '{"status": "success", "message": "Experiment ready to start", "monitoring_enabled": true, "resource_status": '$resource_status'}'
}

function execute_monitor_experiment() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "INFO" "$agent" "monitor_experiment" "Monitoring active experiments"
    
    # Get comprehensive monitoring data
    local monitoring_data="{}"
    if [[ -x "$RESOURCE_HOOK" ]]; then
        monitoring_data=$("$RESOURCE_HOOK" status 2>/dev/null) || monitoring_data='{"error": "monitoring_failed"}'
    fi
    
    # Enhance with agent-specific monitoring
    if command -v python3 >/dev/null 2>&1; then
        local enhanced_data
        enhanced_data=$(python3 -c "
import json
try:
    base_data = json.loads('''$monitoring_data''')
    
    # Add agent-specific context
    base_data['agent_context'] = {
        'requesting_agent': '$agent',
        'context': '${CLAUDE_CONTEXT:-unknown}',
        'tool_name': '${CLAUDE_TOOL_NAME:-unknown}',
        'timestamp': '$(date -Iseconds)'
    }
    
    # Summarize for agent consumption
    summary = base_data.get('summary', {})
    active_experiments = base_data.get('active_experiments', [])
    anomalies = base_data.get('anomalies', [])
    
    base_data['agent_summary'] = {
        'experiments_running': len([exp for exp in active_experiments if exp.get('status') not in ['failed', 'completed']]),
        'experiments_completed': len([exp for exp in active_experiments if exp.get('status') == 'completed']),
        'experiments_failed': len([exp for exp in active_experiments if exp.get('status') == 'failed']),
        'active_alerts': len(anomalies),
        'system_health': summary.get('system_health', 'unknown')
    }
    
    print(json.dumps(base_data, indent=2))
except:
    print('''$monitoring_data''')
")
        echo "$enhanced_data"
    else
        echo "$monitoring_data"
    fi
    
    log_integration_event "SUCCESS" "$agent" "monitor_experiment" "Experiment monitoring data provided"
}

function execute_validate_completion() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "INFO" "$agent" "validate_completion" "Validating experiment completion status"
    
    # Special handling for project-task-updater agent
    if [[ "$agent" == "project-task-updater" ]]; then
        # This agent needs HPC validation before updating GitLab issues
        if ! validate_cluster_access "$agent"; then
            echo '{"status": "cluster_unavailable", "message": "Cannot validate completion - cluster access failed", "recommendation": "Update GitLab with local documentation only"}'
            return 0  # Not an error, just limited capability
        fi
    fi
    
    # Get current experiment status
    local status_data="{}"
    if [[ -x "$RESOURCE_HOOK" ]]; then
        status_data=$("$RESOURCE_HOOK" status 2>/dev/null) || status_data='{"error": "status_check_failed"}'
    fi
    
    # Analyze completion status
    if command -v python3 >/dev/null 2>&1; then
        local completion_analysis
        completion_analysis=$(python3 -c "
import json
try:
    data = json.loads('''$status_data''')
    experiments = data.get('active_experiments', [])
    anomalies = data.get('anomalies', [])
    
    completed_count = len([exp for exp in experiments if exp.get('status') == 'completed'])
    running_count = len([exp for exp in experiments if exp.get('status') in ['running', 'in_progress']])
    failed_count = len([exp for exp in experiments if exp.get('status') == 'failed'])
    
    # Determine overall completion status
    if running_count > 0:
        status = 'experiments_running'
        message = f'{running_count} experiments still running'
    elif failed_count > 0 and completed_count == 0:
        status = 'experiments_failed'
        message = f'{failed_count} experiments failed, none completed'
    elif completed_count > 0:
        status = 'experiments_completed'
        message = f'{completed_count} experiments completed successfully'
        if failed_count > 0:
            message += f', {failed_count} failed'
    else:
        status = 'no_experiments'
        message = 'No recent experiments found'
    
    # Check for system issues
    critical_anomalies = len([a for a in anomalies if a.get('severity') == 'critical'])
    if critical_anomalies > 0:
        status = 'system_issues'
        message += f', {critical_anomalies} critical system issues'
    
    result = {
        'status': status,
        'message': message,
        'completed_experiments': completed_count,
        'running_experiments': running_count,
        'failed_experiments': failed_count,
        'critical_issues': critical_anomalies,
        'validation_timestamp': '$(date -Iseconds)',
        'agent_context': '$agent'
    }
    
    print(json.dumps(result, indent=2))
    
except Exception as e:
    print(f'{{\"status\": \"validation_error\", \"message\": \"Failed to analyze completion status: {e}\"}}')
")
        echo "$completion_analysis"
    else
        echo '{"status": "validation_unavailable", "message": "Python3 required for completion analysis"}'
    fi
    
    log_integration_event "SUCCESS" "$agent" "validate_completion" "Completion validation analysis completed"
}

function execute_check_resources() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "INFO" "$agent" "check_resources" "Checking system resources"
    
    # Get resource status with alerts
    if [[ -x "$RESOURCE_HOOK" ]]; then
        timeout "$timeout" "$RESOURCE_HOOK" check_resources 2>/dev/null || {
            echo '{"status": "timeout", "message": "Resource check timed out after '$timeout' seconds"}'
            return 1
        }
    else
        echo '{"status": "unavailable", "message": "HPC resource monitor hook not available"}'
        return 1
    fi
    
    log_integration_event "SUCCESS" "$agent" "check_resources" "Resource check completed"
}

function execute_get_dashboard_url() {
    local agent="$1"
    local format="$2"
    
    log_integration_event "INFO" "$agent" "get_dashboard_url" "Providing dashboard access information"
    
    # Generate dashboard access information
    local dashboard_info
    dashboard_info=$(cat <<EOF
{
  "status": "available",
  "dashboard_options": [
    {
      "type": "command_line",
      "command": "$RESOURCE_HOOK dashboard",
      "description": "Terminal-based monitoring dashboard"
    },
    {
      "type": "tmux_monitor",
      "command": "$PROJECT_ROOT/tools/hpc/monitoring/tmux_monitor.sh --dashboard",
      "description": "Tmux session monitoring dashboard"
    },
    {
      "type": "node_monitor",
      "command": "cd $PROJECT_ROOT && python3 tools/hpc/node_monitor.py --dashboard",
      "description": "Advanced node monitoring dashboard"
    }
  ],
  "access_requirements": [
    "SSH access to r04n02",
    "Python3 for advanced features",
    "tmux for session monitoring"
  ],
  "agent_context": "$agent",
  "timestamp": "$(date -Iseconds)"
}
EOF
)
    
    echo "$dashboard_info"
    log_integration_event "SUCCESS" "$agent" "get_dashboard_url" "Dashboard information provided"
}

function execute_emergency_stop() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "WARNING" "$agent" "emergency_stop" "EMERGENCY STOP requested by agent"
    
    # Validate cluster access for emergency operations
    if ! validate_cluster_access "$agent"; then
        echo '{"status": "failed", "message": "Emergency stop failed - no cluster access"}'
        return 1
    fi
    
    # Execute emergency stop procedures
    local stop_results="{}"
    
    if command -v python3 >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/tools/hpc/secure_node_config.py" ]]; then
        stop_results=$(python3 -c "
import json, sys
sys.path.append('$PROJECT_ROOT')

try:
    from tools.hpc.secure_node_config import SecureNodeAccess
    node = SecureNodeAccess()
    
    # Get list of sessions to stop
    sessions = node.list_tmux_sessions()
    globtim_sessions = [s for s in sessions if 'globtim' in s.get('name', '').lower()]
    
    stopped_sessions = []
    for session in globtim_sessions:
        session_name = session.get('name', '')
        try:
            result = node.emergency_stop(session_name)
            if result.get('session_killed'):
                stopped_sessions.append(session_name)
        except:
            continue
    
    result = {
        'status': 'completed',
        'message': f'Emergency stop completed - {len(stopped_sessions)} sessions stopped',
        'stopped_sessions': stopped_sessions,
        'total_sessions_found': len(globtim_sessions),
        'timestamp': '$(date -Iseconds)'
    }
    
    print(json.dumps(result, indent=2))
    
except Exception as e:
    print(f'{{\"status\": \"error\", \"message\": \"Emergency stop failed: {e}\"}}')
")
    else
        # Fallback emergency stop
        echo '{"status": "limited", "message": "Emergency stop capabilities limited without Python3/secure access"}'
    fi
    
    echo "$stop_results"
    log_integration_event "SUCCESS" "$agent" "emergency_stop" "Emergency stop procedures completed"
}

function execute_cleanup_stale() {
    local agent="$1"
    local format="$2"
    local timeout="$3"
    
    log_integration_event "INFO" "$agent" "cleanup_stale" "Executing stale session cleanup"
    
    # Execute cleanup with timeout
    local cleanup_script="$PROJECT_ROOT/tools/hpc/monitoring/auto_cleanup.sh"
    
    if [[ -x "$cleanup_script" ]]; then
        local cleanup_result
        cleanup_result=$(timeout "$timeout" "$cleanup_script" --stale-sessions --force 2>&1 || echo "cleanup_timeout_or_error")
        
        if [[ "$cleanup_result" == "cleanup_timeout_or_error" ]]; then
            echo '{"status": "timeout", "message": "Cleanup operation timed out"}'
            return 1
        else
            echo '{"status": "completed", "message": "Stale cleanup completed", "output": "'"$cleanup_result"'"}'
        fi
    else
        echo '{"status": "unavailable", "message": "Cleanup script not available"}'
        return 1
    fi
    
    log_integration_event "SUCCESS" "$agent" "cleanup_stale" "Stale cleanup operation completed"
}

function main() {
    local agent=""
    local action=""
    local format="json"
    local timeout="60"
    local validate_cluster=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --agent)
                agent="$2"
                shift 2
                ;;
            --action)
                action="$2"
                shift 2
                ;;
            --context)
                export CLAUDE_CONTEXT="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --validate-cluster)
                validate_cluster=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$agent" ]]; then
        echo -e "${RED}❌ Agent type is required${NC}" >&2
        usage
        exit 1
    fi
    
    if [[ -z "$action" && "$validate_cluster" == false ]]; then
        echo -e "${RED}❌ Action is required (or use --validate-cluster)${NC}" >&2
        usage
        exit 1
    fi
    
    # Validate agent type
    validate_agent_type "$agent" || exit 1
    
    # Set up environment context for logging
    export CLAUDE_SUBAGENT_TYPE="${agent}"
    
    # Execute cluster validation if requested
    if [[ "$validate_cluster" == true ]]; then
        if validate_cluster_access "$agent"; then
            echo '{"status": "success", "message": "Cluster access validated"}'
        else
            echo '{"status": "failed", "message": "Cluster access validation failed"}'
            exit 1
        fi
        
        # If no action specified, just exit after validation
        if [[ -z "$action" ]]; then
            exit 0
        fi
    fi
    
    # Execute the requested action
    execute_agent_action "$agent" "$action" "$format" "$timeout"
}

# Execute main function
main "$@"