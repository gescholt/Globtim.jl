#!/bin/bash
# HPC Resource Monitor Hook for r04n02 Tmux-Based Execution
# Comprehensive resource monitoring and alerting system for direct node access
#
# Integrates with existing monitoring infrastructure and provides:
# - Real-time resource monitoring
# - Automated alerts for resource issues
# - Performance regression detection
# - Dashboard capabilities for remote monitoring
# - Experiment lifecycle tracking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration - Support both local and HPC environments
if [ -d "/home/scholten/globtim" ]; then
    # HPC environment (r04n02)
    GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
else
    # Local development environment
    GLOBTIM_DIR="${GLOBTIM_DIR:-/Users/ghscholt/globtim}"
fi

MONITOR_DIR="$GLOBTIM_DIR/tools/hpc/monitoring"
LOG_DIR="$MONITOR_DIR/logs"
ALERT_DIR="$MONITOR_DIR/alerts"
PERFORMANCE_DIR="$MONITOR_DIR/performance"
DASHBOARD_DIR="$MONITOR_DIR/dashboard"

# Resource thresholds for alerts
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-85}    # Percentage
CPU_THRESHOLD=${CPU_THRESHOLD:-90}          # Percentage
DISK_THRESHOLD=${DISK_THRESHOLD:-90}        # Percentage
JULIA_PROCESS_THRESHOLD=${JULIA_PROCESS_THRESHOLD:-4}  # Number of Julia processes

# Create necessary directories
mkdir -p "$LOG_DIR" "$ALERT_DIR" "$PERFORMANCE_DIR" "$DASHBOARD_DIR"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/resource_monitor.log"
}

log_alert() {
    local alert_level=$1
    local message=$2
    local alert_file="$ALERT_DIR/alerts_$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$alert_level] $message" | tee -a "$alert_file"
    log "ALERT [$alert_level]: $message"
}

log_performance() {
    local metric_name=$1
    local metric_value=$2
    local perf_file="$PERFORMANCE_DIR/performance_$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $metric_name: $metric_value" | tee -a "$perf_file"
}

# Resource monitoring functions
collect_node_metrics() {
    local metrics_file="$PERFORMANCE_DIR/node_metrics_$(date +%Y%m%d_%H%M%S).json"
    
    # Memory metrics
    local memory_info=$(free -m)
    local total_mem=$(echo "$memory_info" | awk 'NR==2{print $2}')
    local used_mem=$(echo "$memory_info" | awk 'NR==2{print $3}')
    local memory_percent=$(( (used_mem * 100) / total_mem ))
    
    # CPU metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Disk usage (home directory)
    local disk_usage=$(df -h ~ | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Julia process count
    local julia_processes=$(pgrep -f julia | wc -l)
    
    # Tmux session count
    local tmux_sessions=$(tmux ls 2>/dev/null | grep globtim | wc -l || echo "0")
    
    # Network connectivity test
    local network_status="OK"
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        network_status="FAILED"
    fi
    
    # Create JSON metrics
    cat > "$metrics_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "node": "r04n02",
    "memory": {
        "total_mb": $total_mem,
        "used_mb": $used_mem,
        "usage_percent": $memory_percent
    },
    "cpu": {
        "usage_percent": $(printf "%.1f" "$cpu_usage")
    },
    "disk": {
        "home_usage_percent": $disk_usage
    },
    "processes": {
        "julia_count": $julia_processes,
        "tmux_sessions": $tmux_sessions
    },
    "network": {
        "status": "$network_status"
    }
}
EOF
    
    # Log performance metrics
    log_performance "MEMORY_USAGE" "${memory_percent}%"
    log_performance "CPU_USAGE" "${cpu_usage}%"
    log_performance "DISK_USAGE" "${disk_usage}%"
    log_performance "JULIA_PROCESSES" "$julia_processes"
    log_performance "TMUX_SESSIONS" "$tmux_sessions"
    
    # Check thresholds and generate alerts
    check_resource_thresholds "$memory_percent" "$cpu_usage" "$disk_usage" "$julia_processes"
    
    echo "$metrics_file"
}

check_resource_thresholds() {
    local memory_usage=$1
    local cpu_usage=$2
    local disk_usage=$3
    local julia_processes=$4
    
    # Memory threshold check
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        log_alert "HIGH" "Memory usage exceeded threshold: ${memory_usage}% > ${MEMORY_THRESHOLD}%"
    fi
    
    # CPU threshold check
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log_alert "HIGH" "CPU usage exceeded threshold: ${cpu_usage}% > ${CPU_THRESHOLD}%"
    fi
    
    # Disk threshold check
    if (( disk_usage > DISK_THRESHOLD )); then
        log_alert "CRITICAL" "Disk usage exceeded threshold: ${disk_usage}% > ${DISK_THRESHOLD}%"
    fi
    
    # Julia process check
    if (( julia_processes > JULIA_PROCESS_THRESHOLD )); then
        log_alert "MEDIUM" "Multiple Julia processes detected: $julia_processes processes"
    fi
}

monitor_tmux_experiments() {
    local experiment_status_file="$PERFORMANCE_DIR/experiment_status_$(date +%Y%m%d_%H%M%S).json"
    
    log "Monitoring active tmux experiments..."
    
    # Get all GlobTim tmux sessions
    local sessions=$(tmux ls 2>/dev/null | grep globtim | cut -d: -f1 || echo "")
    
    if [ -z "$sessions" ]; then
        log "No active GlobTim experiments found"
        echo '{"active_experiments": [], "total_count": 0}' > "$experiment_status_file"
        return
    fi
    
    local experiment_data='{"active_experiments": ['
    local count=0
    
    for session in $sessions; do
        if [ $count -gt 0 ]; then
            experiment_data+=','
        fi
        
        # Get session details
        local session_info=$(tmux display-message -t "$session" -p "#{session_created}")
        local log_dir="/home/scholten/globtim/hpc_results/$session"
        local has_logs="false"
        local log_size=0
        
        if [ -d "$log_dir" ]; then
            has_logs="true"
            log_size=$(du -s "$log_dir" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        # Check if Julia is running in the session
        local julia_running="false"
        if tmux list-panes -t "$session" -F "#{pane_pid}" | xargs -I {} pgrep -P {} julia >/dev/null 2>&1; then
            julia_running="true"
        fi
        
        experiment_data+="{\"session_name\": \"$session\", \"created_time\": \"$session_info\", \"julia_running\": $julia_running, \"has_logs\": $has_logs, \"log_size_kb\": $log_size}"
        ((count++))
    done
    
    experiment_data+="], \"total_count\": $count, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "$experiment_data" > "$experiment_status_file"
    
    log "Found $count active experiments: $sessions"
    log_performance "ACTIVE_EXPERIMENTS" "$count"
}

create_performance_dashboard() {
    local dashboard_file="$DASHBOARD_DIR/dashboard_$(date +%Y%m%d_%H%M%S).html"
    
    # Get latest metrics
    local latest_metrics=$(ls -t "$PERFORMANCE_DIR"/node_metrics_*.json 2>/dev/null | head -1)
    local latest_experiments=$(ls -t "$PERFORMANCE_DIR"/experiment_status_*.json 2>/dev/null | head -1)
    
    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>r04n02 HPC Resource Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 15px; border-radius: 5px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric-card { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-value { font-size: 24px; font-weight: bold; color: #3498db; }
        .metric-label { color: #7f8c8d; font-size: 14px; }
        .alert-high { border-left: 4px solid #e74c3c; }
        .alert-medium { border-left: 4px solid #f39c12; }
        .alert-ok { border-left: 4px solid #27ae60; }
        .experiments { background: white; padding: 15px; border-radius: 8px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .refresh-time { color: #7f8c8d; font-size: 12px; text-align: right; }
    </style>
    <meta http-equiv="refresh" content="30">
</head>
<body>
    <div class="header">
        <h1>🖥️ r04n02 HPC Resource Monitor</h1>
        <p>Real-time monitoring of tmux-based experiment execution</p>
    </div>
EOF
    
    if [ -f "$latest_metrics" ]; then
        # Parse JSON and create dashboard content
        local memory_percent=$(cat "$latest_metrics" | grep -o '"usage_percent": [0-9]*' | cut -d: -f2 | tr -d ' ')
        local cpu_usage=$(cat "$latest_metrics" | grep -o '"usage_percent": [0-9.]*' | tail -1 | cut -d: -f2 | tr -d ' ')
        local julia_count=$(cat "$latest_metrics" | grep -o '"julia_count": [0-9]*' | cut -d: -f2 | tr -d ' ')
        local tmux_count=$(cat "$latest_metrics" | grep -o '"tmux_sessions": [0-9]*' | cut -d: -f2 | tr -d ' ')
        
        # Determine alert levels
        local memory_class="alert-ok"
        local cpu_class="alert-ok"
        
        if (( memory_percent > MEMORY_THRESHOLD )); then
            memory_class="alert-high"
        elif (( memory_percent > 70 )); then
            memory_class="alert-medium"
        fi
        
        if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
            cpu_class="alert-high"
        elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
            cpu_class="alert-medium"
        fi
        
        cat >> "$dashboard_file" << EOF
    <div class="metrics">
        <div class="metric-card $memory_class">
            <div class="metric-value">${memory_percent}%</div>
            <div class="metric-label">Memory Usage</div>
        </div>
        <div class="metric-card $cpu_class">
            <div class="metric-value">${cpu_usage}%</div>
            <div class="metric-label">CPU Usage</div>
        </div>
        <div class="metric-card alert-ok">
            <div class="metric-value">${julia_count}</div>
            <div class="metric-label">Julia Processes</div>
        </div>
        <div class="metric-card alert-ok">
            <div class="metric-value">${tmux_count}</div>
            <div class="metric-label">Active Experiments</div>
        </div>
    </div>
EOF
    fi
    
    cat >> "$dashboard_file" << 'EOF'
    <div class="experiments">
        <h3>📊 Experiment Status</h3>
EOF
    
    if [ -f "$latest_experiments" ]; then
        # Add experiment information
        echo "        <p>Latest experiment monitoring data available.</p>" >> "$dashboard_file"
    else
        echo "        <p>No experiment data available.</p>" >> "$dashboard_file"
    fi
    
    cat >> "$dashboard_file" << EOF
        <div class="refresh-time">Last updated: $(date)</div>
    </div>
</body>
</html>
EOF
    
    log "Dashboard created: $dashboard_file"
    echo "$dashboard_file"
}

performance_regression_check() {
    log "Running performance regression check..."
    
    # Get recent performance files
    local recent_files=$(ls -t "$PERFORMANCE_DIR"/performance_*.log 2>/dev/null | head -7)
    
    if [ -z "$recent_files" ]; then
        log "No performance history available for regression check"
        return
    fi
    
    # Extract constructor times from recent runs
    local constructor_times=()
    for file in $recent_files; do
        local time=$(grep "Constructor.*mean_time" "$file" 2>/dev/null | tail -1 | grep -o '[0-9.]\+' | head -1)
        if [ -n "$time" ]; then
            constructor_times+=("$time")
        fi
    done
    
    if [ ${#constructor_times[@]} -lt 3 ]; then
        log "Insufficient performance data for regression analysis"
        return
    fi
    
    # Simple regression check: compare latest 3 with previous 3
    local recent_avg=$(printf '%s\n' "${constructor_times[@]:0:3}" | awk '{sum+=$1} END {print sum/NR}')
    local previous_avg=$(printf '%s\n' "${constructor_times[@]:3:3}" | awk '{sum+=$1} END {print sum/NR}')
    
    # Check for significant performance degradation (>20% slower)
    local regression_threshold=1.2
    if (( $(echo "$recent_avg > $previous_avg * $regression_threshold" | bc -l) )); then
        log_alert "MEDIUM" "Performance regression detected: Constructor time increased from ${previous_avg}s to ${recent_avg}s"
    else
        log "Performance check passed: Recent avg ${recent_avg}s vs Previous avg ${previous_avg}s"
    fi
}

# Hook integration functions
start_experiment_monitoring() {
    local experiment_session=$1
    log "Starting monitoring for experiment: $experiment_session"
    
    # Create experiment-specific monitoring
    local monitor_script="/tmp/monitor_${experiment_session}.sh"
    
    cat > "$monitor_script" << 'SCRIPT_EOF'
#!/bin/bash
EXPERIMENT_SESSION="$1"
MONITOR_DIR="$2"

while tmux has-session -t "$EXPERIMENT_SESSION" 2>/dev/null; do
    # Collect metrics every 60 seconds while experiment runs
    "$MONITOR_DIR/../monitoring/hpc_resource_monitor_hook.sh" collect
    sleep 60
done

# Final monitoring after experiment completion
"$MONITOR_DIR/../monitoring/hpc_resource_monitor_hook.sh" collect
"$MONITOR_DIR/../monitoring/hpc_resource_monitor_hook.sh" performance-check

echo "Monitoring completed for experiment: $EXPERIMENT_SESSION"
SCRIPT_EOF
    
    chmod +x "$monitor_script"
    
    # Start background monitoring
    nohup bash "$monitor_script" "$experiment_session" "$MONITOR_DIR" > "$LOG_DIR/monitor_${experiment_session}.log" 2>&1 &
    local monitor_pid=$!
    
    echo "$monitor_pid" > "$MONITOR_DIR/monitors/${experiment_session}.pid"
    log "Background monitoring started for $experiment_session (PID: $monitor_pid)"
}

stop_experiment_monitoring() {
    local experiment_session=$1
    local pid_file="$MONITOR_DIR/monitors/${experiment_session}.pid"
    
    if [ -f "$pid_file" ]; then
        local monitor_pid=$(cat "$pid_file")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            kill "$monitor_pid"
            log "Stopped monitoring for experiment: $experiment_session (PID: $monitor_pid)"
        fi
        rm -f "$pid_file"
    fi
}

# Main command functions
show_help() {
    echo "HPC Resource Monitor Hook for r04n02"
    echo "===================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  collect                    - Collect current node metrics and check thresholds"
    echo "  experiments               - Monitor active tmux experiments"
    echo "  dashboard                 - Generate HTML performance dashboard"
    echo "  performance-check         - Run performance regression analysis"
    echo "  start-monitoring <session> - Start background monitoring for experiment"
    echo "  stop-monitoring <session>  - Stop background monitoring for experiment"
    echo "  full-scan                 - Run complete monitoring cycle"
    echo "  alerts                    - Show recent alerts"
    echo "  status                    - Show system status summary"
    echo ""
    echo "Examples:"
    echo "  $0 collect                # Collect metrics and check thresholds"
    echo "  $0 full-scan              # Complete monitoring cycle"
    echo "  $0 start-monitoring globtim_4d_20250904_143022"
    echo "  $0 dashboard              # Generate performance dashboard"
}

show_status() {
    echo -e "${CYAN}r04n02 HPC Resource Monitor Status${NC}"
    echo "================================="
    
    # Latest metrics
    local latest_metrics=$(ls -t "$PERFORMANCE_DIR"/node_metrics_*.json 2>/dev/null | head -1)
    if [ -f "$latest_metrics" ]; then
        echo -e "${GREEN}✓${NC} Latest metrics: $(basename "$latest_metrics")"
        local memory_percent=$(cat "$latest_metrics" | grep -o '"usage_percent": [0-9]*' | cut -d: -f2 | tr -d ' ')
        local julia_count=$(cat "$latest_metrics" | grep -o '"julia_count": [0-9]*' | cut -d: -f2 | tr -d ' ')
        echo "  Memory Usage: ${memory_percent}%"
        echo "  Julia Processes: ${julia_count}"
    else
        echo -e "${YELLOW}⚠${NC} No metrics available - run 'collect' command"
    fi
    
    # Active experiments
    local tmux_count=$(tmux ls 2>/dev/null | grep globtim | wc -l || echo "0")
    echo -e "${GREEN}✓${NC} Active Experiments: $tmux_count"
    
    # Recent alerts
    local alert_count=$(find "$ALERT_DIR" -name "*.log" -mtime -1 -exec cat {} \; 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Recent Alerts (24h): $alert_count"
    
    # Dashboard status
    local latest_dashboard=$(ls -t "$DASHBOARD_DIR"/dashboard_*.html 2>/dev/null | head -1)
    if [ -f "$latest_dashboard" ]; then
        echo -e "${GREEN}✓${NC} Latest Dashboard: $(basename "$latest_dashboard")"
    fi
}

show_recent_alerts() {
    echo -e "${YELLOW}Recent Alerts (Last 24 hours)${NC}"
    echo "=============================="
    
    find "$ALERT_DIR" -name "*.log" -mtime -1 -exec cat {} \; 2>/dev/null | tail -10
    
    if [ $? -ne 0 ] || [ ! -s "$ALERT_DIR"/*.log 2>/dev/null ]; then
        echo "No recent alerts found."
    fi
}

# Create monitoring directories
mkdir -p "$MONITOR_DIR/monitors"

# Main command dispatcher
case "${1:-help}" in
    collect)
        metrics_file=$(collect_node_metrics)
        log "Metrics collected: $metrics_file"
        ;;
    experiments)
        monitor_tmux_experiments
        ;;
    dashboard)
        dashboard_file=$(create_performance_dashboard)
        echo "Dashboard created: $dashboard_file"
        ;;
    performance-check)
        performance_regression_check
        ;;
    start-monitoring)
        if [ -n "$2" ]; then
            start_experiment_monitoring "$2"
        else
            echo "Error: Experiment session name required"
            exit 1
        fi
        ;;
    stop-monitoring)
        if [ -n "$2" ]; then
            stop_experiment_monitoring "$2"
        else
            echo "Error: Experiment session name required"
            exit 1
        fi
        ;;
    full-scan)
        log "Starting full monitoring scan..."
        collect_node_metrics
        monitor_tmux_experiments
        create_performance_dashboard
        performance_regression_check
        log "Full monitoring scan completed"
        ;;
    alerts)
        show_recent_alerts
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac