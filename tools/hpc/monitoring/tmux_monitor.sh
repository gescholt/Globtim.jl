#!/bin/bash
# Enhanced Tmux Session Monitor with HPC Resource Integration
# ==========================================================
#
# Advanced monitoring system for tmux-based experiment sessions on r04n02.
# Integrates with the HPC Resource Monitor Hook system for comprehensive
# experiment lifecycle management.
#
# Features:
# - Real-time tmux session monitoring with resource tracking
# - Integration with HPC resource alerts and thresholds
# - Experiment progress analysis through log parsing
# - Automated session cleanup and result management
# - Performance regression detection
# - Dashboard capability for remote monitoring
#
# Usage:
#   tools/hpc/monitoring/tmux_monitor.sh [session_name]
#   tools/hpc/monitoring/tmux_monitor.sh --all
#   tools/hpc/monitoring/tmux_monitor.sh --dashboard
#   tools/hpc/monitoring/tmux_monitor.sh --cleanup-stale
#
# Author: Claude Code HPC monitoring system
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
REFRESH_INTERVAL=${HPC_MONITOR_INTERVAL:-30}
GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
RESOURCE_HOOK="$HOME/.claude/hooks/hpc-resource-monitor.sh"
TMUX_LOG_DIR="$PROJECT_ROOT/hpc/logs/tmux_monitoring"
STALE_SESSION_THRESHOLD=${STALE_THRESHOLD_HOURS:-24}  # hours

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

function log_monitoring_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$TMUX_LOG_DIR"
    
    echo "[$timestamp] [$level] $message" >> "$TMUX_LOG_DIR/tmux_monitor.log"
    
    # Also log to console if verbose
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${CYAN}[$timestamp] [$level]${NC} $message" >&2
    fi
}

function print_header() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}               Enhanced Tmux Session Monitor                      ${NC}"
    echo -e "${CYAN}        Integrated HPC Resource Monitoring for r04n02            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

function get_session_list() {
    # Get list of tmux sessions, filtering for GlobTim-related sessions
    local session_filter="${1:-globtim}"
    
    if ! command -v tmux >/dev/null 2>&1; then
        log_monitoring_event "ERROR" "tmux not available"
        return 1
    fi
    
    # Use secure node access if available, otherwise local tmux
    if [[ -f "$PROJECT_ROOT/tools/hpc/secure_node_config.py" ]]; then
        python3 "$PROJECT_ROOT/tools/hpc/secure_node_config.py" -c "list_sessions" 2>/dev/null | grep -i "$session_filter" || true
    else
        tmux ls 2>/dev/null | grep -i "$session_filter" || echo "No sessions found"
    fi
}

function analyze_session_health() {
    local session_name="$1"
    
    log_monitoring_event "INFO" "Analyzing health of session: $session_name"
    
    # Initialize health report
    local health_report="{}"
    
    # Check session existence
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        health_report='{"exists": false, "status": "not_found"}'
        echo "$health_report"
        return 1
    fi
    
    # Get session info
    local session_info
    session_info=$(tmux list-sessions -F '#{session_name}:#{session_created}:#{session_activity}:#{session_windows}' 2>/dev/null | grep "^$session_name:" || echo "")
    
    if [[ -z "$session_info" ]]; then
        health_report='{"exists": true, "status": "info_unavailable"}'
        echo "$health_report"
        return 1
    fi
    
    # Parse session info
    IFS=':' read -r name created activity windows <<< "$session_info"
    
    # Calculate session age and last activity
    local current_time=$(date +%s)
    local session_age_hours=0
    local last_activity_hours=0
    
    if [[ "$created" =~ ^[0-9]+$ ]]; then
        session_age_hours=$(( (current_time - created) / 3600 ))
    fi
    
    if [[ "$activity" =~ ^[0-9]+$ ]]; then
        last_activity_hours=$(( (current_time - activity) / 3600 ))
    fi
    
    # Check for experiment output directory
    local output_dir="$GLOBTIM_DIR/hpc_results/$session_name"
    local has_output_dir=false
    local log_files=()
    local latest_log_size=0
    
    # This would need secure node access for remote checking
    if [[ -d "$output_dir" ]]; then
        has_output_dir=true
        log_files=($(ls -1t "$output_dir"/*.log 2>/dev/null | head -5 || true))
        if [[ ${#log_files[@]} -gt 0 ]]; then
            latest_log_size=$(stat -f%z "${log_files[0]}" 2>/dev/null || echo "0")
        fi
    fi
    
    # Determine session health status
    local status="healthy"
    local warnings=()
    local errors=()
    
    # Check for stale sessions
    if [[ $last_activity_hours -gt $STALE_SESSION_THRESHOLD ]]; then
        status="stale"
        warnings+=("No activity for $last_activity_hours hours")
    fi
    
    # Check for long-running sessions without output
    if [[ $session_age_hours -gt 2 && ! $has_output_dir ]]; then
        warnings+=("Session running for $session_age_hours hours without output directory")
    fi
    
    # Check for sessions with very small or no log output
    if [[ $has_output_dir && $latest_log_size -lt 1000 && $session_age_hours -gt 1 ]]; then
        warnings+=("Minimal log output after $session_age_hours hours")
    fi
    
    # Use Python for JSON formatting
    if command -v python3 >/dev/null 2>&1; then
        health_report=$(python3 -c "
import json
report = {
    'session_name': '$session_name',
    'exists': True,
    'status': '$status',
    'session_age_hours': $session_age_hours,
    'last_activity_hours': $last_activity_hours,
    'windows': $windows,
    'has_output_dir': $has_output_dir,
    'latest_log_size': $latest_log_size,
    'warnings': $(printf '%s\n' "${warnings[@]}" | python3 -c "import sys, json; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))" 2>/dev/null || echo '[]'),
    'errors': $(printf '%s\n' "${errors[@]}" | python3 -c "import sys, json; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))" 2>/dev/null || echo '[]')
}
print(json.dumps(report, indent=2))
")
    else
        # Fallback without Python
        health_report="{\"session_name\":\"$session_name\",\"exists\":true,\"status\":\"$status\",\"session_age_hours\":$session_age_hours,\"warnings\":${#warnings[@]},\"errors\":${#errors[@]}}"
    fi
    
    echo "$health_report"
}

function integrate_resource_monitoring() {
    local session_name="$1"
    
    # Call the HPC resource monitor hook if available
    if [[ -x "$RESOURCE_HOOK" ]]; then
        log_monitoring_event "INFO" "Integrating resource monitoring for session: $session_name"
        
        # Get current resource status
        local resource_status
        resource_status=$("$RESOURCE_HOOK" status 2>/dev/null) || {
            log_monitoring_event "WARNING" "Resource hook failed, continuing without resource data"
            resource_status='{"error": "resource_hook_failed"}'
        }
        
        # Check for resource alerts
        "$RESOURCE_HOOK" check_resources >/dev/null 2>&1 || log_monitoring_event "WARNING" "Resource check generated alerts"
        
        # Monitor specific session
        "$RESOURCE_HOOK" monitor "$session_name" >/dev/null 2>&1 || log_monitoring_event "INFO" "Session-specific monitoring completed"
        
        echo "$resource_status"
    else
        log_monitoring_event "WARNING" "HPC resource monitor hook not available at: $RESOURCE_HOOK"
        echo '{"error": "resource_hook_not_available"}'
    fi
}

function monitor_single_session() {
    local session_name="$1"
    
    log_monitoring_event "INFO" "Starting detailed monitoring of session: $session_name"
    
    echo -e "${GREEN}🔍 Detailed Session Monitoring: $session_name${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop monitoring${NC}\n"
    
    while true; do
        clear
        print_header
        echo -e "${BLUE}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "${BLUE}Session:${NC} $session_name\n"
        
        # Get session health analysis
        local health_report
        health_report=$(analyze_session_health "$session_name") || {
            echo -e "${RED}❌ Session not found or unavailable${NC}"
            break
        }
        
        # Display session health
        echo -e "${BLUE}📊 Session Health Analysis:${NC}"
        echo "────────────────────────────────────────────────"
        
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import json
try:
    health = json.loads('''$health_report''')
    status = health.get('status', 'unknown')
    age = health.get('session_age_hours', 0)
    activity = health.get('last_activity_hours', 0)
    windows = health.get('windows', 0)
    
    status_color = '🟢' if status == 'healthy' else '🟡' if status == 'stale' else '🔴'
    print(f'   Status: {status_color} {status.upper()}')
    print(f'   Session Age: {age:.1f} hours')
    print(f'   Last Activity: {activity:.1f} hours ago')
    print(f'   Windows: {windows}')
    
    warnings = health.get('warnings', [])
    if warnings:
        print(f'   ⚠️  Warnings: {len(warnings)}')
        for warning in warnings[:3]:  # Show top 3 warnings
            print(f'      • {warning}')
            
    errors = health.get('errors', [])
    if errors:
        print(f'   ❌ Errors: {len(errors)}')
        for error in errors[:3]:  # Show top 3 errors
            print(f'      • {error}')
            
except Exception as e:
    print(f'   Error parsing health report: {e}')
" 2>/dev/null || echo "   Health analysis unavailable"
        else
            echo "   Session monitoring requires Python3"
        fi
        
        echo ""
        
        # Integrate resource monitoring
        echo -e "${BLUE}💻 System Resources:${NC}"
        echo "────────────────────────────────────────────────"
        local resource_data
        resource_data=$(integrate_resource_monitoring "$session_name")
        
        if command -v python3 >/dev/null 2>&1 && [[ "$resource_data" != *"error"* ]]; then
            python3 -c "
import json
try:
    data = json.loads('''$resource_data''')
    resources = data.get('system_resources', {})
    memory = resources.get('memory', {})
    cpu = resources.get('cpu_load', {})
    
    mem_usage = memory.get('usage_percent', 0)
    cpu_load = cpu.get('1min', 0)
    
    mem_color = '🟢' if mem_usage < 70 else '🟡' if mem_usage < 90 else '🔴'
    cpu_color = '🟢' if cpu_load < 4 else '🟡' if cpu_load < 8 else '🔴'
    
    print(f'   Memory Usage: {mem_color} {mem_usage:.1f}%')
    print(f'   CPU Load (1m): {cpu_color} {cpu_load:.2f}')
    
    anomalies = data.get('anomalies', [])
    if anomalies:
        print(f'   🚨 Anomalies: {len(anomalies)} detected')
        
except Exception as e:
    print(f'   Resource data parsing failed: {e}')
" 2>/dev/null
        else
            echo "   Resource monitoring unavailable"
        fi
        
        echo ""
        
        # Show recent tmux session activity
        echo -e "${BLUE}📝 Recent Session Activity:${NC}"
        echo "────────────────────────────────────────────────"
        
        # Capture pane content from session (last 10 lines)
        if tmux has-session -t "$session_name" 2>/dev/null; then
            local pane_content
            pane_content=$(tmux capture-pane -t "$session_name" -p 2>/dev/null | tail -10 || echo "Unable to capture session content")
            echo "$pane_content" | sed 's/^/   /'
        else
            echo "   Session not accessible"
        fi
        
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "Refreshing in $REFRESH_INTERVAL seconds... (Press Ctrl+C to stop)"
        sleep $REFRESH_INTERVAL
    done
    
    log_monitoring_event "INFO" "Session monitoring stopped for: $session_name"
}

function monitor_all_sessions() {
    log_monitoring_event "INFO" "Starting monitoring of all GlobTim sessions"
    
    echo -e "${GREEN}🖥️  Monitoring All GlobTim Sessions${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop monitoring${NC}\n"
    
    while true; do
        clear
        print_header
        echo -e "${BLUE}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
        
        # Get list of active sessions
        local sessions
        sessions=$(get_session_list)
        
        if [[ "$sessions" == "No sessions found" || -z "$sessions" ]]; then
            echo -e "${YELLOW}📭 No active GlobTim sessions found${NC}"
        else
            echo -e "${BLUE}🧪 Active GlobTim Sessions:${NC}"
            echo "────────────────────────────────────────────────"
            
            echo "$sessions" | while IFS=':' read -r session_name session_info || [[ -n "$session_name" ]]; do
                if [[ -n "$session_name" ]]; then
                    # Get quick health check
                    local health
                    health=$(analyze_session_health "$session_name" 2>/dev/null) || continue
                    
                    if command -v python3 >/dev/null 2>&1; then
                        python3 -c "
import json
try:
    health = json.loads('''$health''')
    name = health.get('session_name', '$session_name')
    status = health.get('status', 'unknown')
    age = health.get('session_age_hours', 0)
    
    status_icon = '🟢' if status == 'healthy' else '🟡' if status == 'stale' else '🔴'
    print(f'   {status_icon} {name} ({status}, {age:.1f}h)')
except:
    print(f'   ❓ $session_name (analysis failed)')
"
                    else
                        echo "   • $session_name"
                    fi
                fi
            done
        fi
        
        echo ""
        
        # System overview
        echo -e "${BLUE}💻 System Overview:${NC}"
        echo "────────────────────────────────────────────────"
        
        if [[ -x "$RESOURCE_HOOK" ]]; then
            local system_status
            system_status=$("$RESOURCE_HOOK" status 2>/dev/null) || echo '{"error": "resource_check_failed"}'
            
            if command -v python3 >/dev/null 2>&1 && [[ "$system_status" != *"error"* ]]; then
                python3 -c "
import json
try:
    data = json.loads('''$system_status''')
    summary = data.get('summary', {})
    resources = data.get('system_resources', {})
    
    health = summary.get('system_health', 'unknown')
    sessions_count = summary.get('total_sessions', 0)
    experiments_count = summary.get('active_experiments', 0)
    anomalies_count = summary.get('anomaly_count', 0)
    
    health_icon = '🟢' if health == 'healthy' else '🟡' if anomalies_count > 0 else '🔴'
    print(f'   System Health: {health_icon} {health.upper()}')
    print(f'   Active Sessions: {sessions_count}')
    print(f'   Running Experiments: {experiments_count}')
    if anomalies_count > 0:
        print(f'   ⚠️  Anomalies: {anomalies_count}')
        
except Exception as e:
    print(f'   System status unavailable: {e}')
" 2>/dev/null
            else
                echo "   System monitoring unavailable"
            fi
        else
            echo "   HPC resource hook not available"
        fi
        
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "Options: Enter session name to monitor details, or wait for refresh"
        echo -e "Refreshing in $REFRESH_INTERVAL seconds..."
        
        # Wait for input with timeout
        read -t $REFRESH_INTERVAL -p "Session name (or Enter to continue): " session_input || true
        if [[ -n "$session_input" && "$session_input" != "" ]]; then
            monitor_single_session "$session_input"
            # Return to all-sessions monitoring when single session monitoring ends
        fi
    done
}

function cleanup_stale_sessions() {
    log_monitoring_event "INFO" "Starting cleanup of stale sessions"
    
    echo -e "${YELLOW}🧹 Cleaning up stale tmux sessions${NC}"
    
    local sessions
    sessions=$(get_session_list)
    local cleaned_count=0
    
    if [[ "$sessions" == "No sessions found" || -z "$sessions" ]]; then
        echo -e "${GREEN}✅ No sessions to clean up${NC}"
        return 0
    fi
    
    echo "$sessions" | while IFS=':' read -r session_name session_info || [[ -n "$session_name" ]]; do
        if [[ -n "$session_name" ]]; then
            local health
            health=$(analyze_session_health "$session_name" 2>/dev/null) || continue
            
            if command -v python3 >/dev/null 2>&1; then
                local is_stale
                is_stale=$(python3 -c "
import json
try:
    health = json.loads('''$health''')
    status = health.get('status', 'unknown')
    age = health.get('session_age_hours', 0)
    activity = health.get('last_activity_hours', 0)
    
    # Consider stale if marked as stale or very old with no recent activity
    if status == 'stale' or (age > $STALE_SESSION_THRESHOLD and activity > $STALE_SESSION_THRESHOLD):
        print('true')
    else:
        print('false')
except:
    print('false')
")
                
                if [[ "$is_stale" == "true" ]]; then
                    echo -e "${YELLOW}⚠️  Found stale session: $session_name${NC}"
                    
                    # Ask for confirmation before killing
                    read -p "Kill stale session '$session_name'? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        if tmux kill-session -t "$session_name" 2>/dev/null; then
                            echo -e "${GREEN}✅ Killed stale session: $session_name${NC}"
                            log_monitoring_event "INFO" "Killed stale session: $session_name"
                            ((cleaned_count++))
                        else
                            echo -e "${RED}❌ Failed to kill session: $session_name${NC}"
                            log_monitoring_event "ERROR" "Failed to kill stale session: $session_name"
                        fi
                    else
                        echo -e "${BLUE}ℹ️  Skipped session: $session_name${NC}"
                    fi
                fi
            fi
        fi
    done
    
    echo -e "${GREEN}✅ Cleanup completed. Sessions cleaned: $cleaned_count${NC}"
    log_monitoring_event "INFO" "Cleanup completed - $cleaned_count sessions cleaned"
}

function start_dashboard() {
    log_monitoring_event "INFO" "Starting tmux monitoring dashboard"
    
    # Use the node monitor dashboard if available
    if [[ -f "$PROJECT_ROOT/tools/hpc/node_monitor.py" ]]; then
        echo -e "${CYAN}🖥️  Starting Enhanced HPC Monitoring Dashboard${NC}"
        echo -e "${CYAN}   Integrating tmux session monitoring with resource tracking${NC}\n"
        
        cd "$PROJECT_ROOT" && python3 tools/hpc/node_monitor.py --dashboard
    else
        echo -e "${YELLOW}⚠️  Advanced dashboard not available, using basic monitoring${NC}\n"
        monitor_all_sessions
    fi
}

function show_usage() {
    cat <<EOF
Enhanced Tmux Session Monitor with HPC Resource Integration
==========================================================

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  [session_name]    Monitor specific tmux session in detail
  --all            Monitor all GlobTim sessions (default)
  --dashboard      Start integrated monitoring dashboard
  --cleanup-stale  Clean up stale sessions older than ${STALE_SESSION_THRESHOLD}h
  --list           List all active GlobTim sessions
  --help           Show this help message

Environment Variables:
  HPC_MONITOR_INTERVAL     Refresh interval in seconds (default: $REFRESH_INTERVAL)
  STALE_THRESHOLD_HOURS    Hours before session considered stale (default: $STALE_SESSION_THRESHOLD)
  VERBOSE                  Enable verbose logging (true/false)

Examples:
  # Monitor all sessions with dashboard
  $0 --dashboard

  # Monitor specific session
  $0 globtim_4d_20250904_143022

  # Monitor all sessions (basic view)
  $0 --all

  # Clean up old sessions
  $0 --cleanup-stale

  # List active sessions
  $0 --list

Integration:
  This monitor integrates with:
  - ~/.claude/hooks/hpc-resource-monitor.sh (resource alerts)
  - tools/hpc/node_monitor.py (comprehensive analysis)
  - tools/hpc/secure_node_config.py (secure node access)

Log Files:
  Monitoring logs: $TMUX_LOG_DIR/tmux_monitor.log

EOF
}

function main() {
    # Ensure log directory exists
    mkdir -p "$TMUX_LOG_DIR"
    
    local command="${1:---all}"
    
    log_monitoring_event "INFO" "Tmux monitor started with command: $command"
    
    case "$command" in
        "--all")
            monitor_all_sessions
            ;;
        "--dashboard")
            start_dashboard
            ;;
        "--cleanup-stale")
            cleanup_stale_sessions
            ;;
        "--list")
            echo -e "${BLUE}Active GlobTim Sessions:${NC}"
            get_session_list
            ;;
        "--help"|"-h")
            show_usage
            ;;
        *)
            # Assume it's a session name
            monitor_single_session "$command"
            ;;
    esac
    
    log_monitoring_event "INFO" "Tmux monitor session ended"
}

# Set up signal handlers for clean exit
trap 'echo -e "\n${GREEN}👋 Tmux monitoring stopped${NC}"; exit 0' SIGINT SIGTERM

# Execute main function
main "$@"