#!/bin/bash
# Integrated Experiment Monitor
# Enhances the robust experiment runner with automatic resource monitoring
#
# This script bridges the gap between experiment execution and resource monitoring,
# providing seamless integration with the tmux-based execution framework.

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Support both local and HPC environments
if [ -d "/home/scholten/globtim" ]; then
    # HPC environment (r04n02)
    GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
else
    # Local development environment
    GLOBTIM_DIR="${GLOBTIM_DIR:-/Users/ghscholt/globtim}"
fi
MONITOR_HOOK="$GLOBTIM_DIR/tools/hpc/monitoring/hpc_resource_monitor_hook.sh"

print_info() {
    echo -e "${GREEN}[MONITOR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[MONITOR]${NC} $1"
}

# Enhanced experiment starter with monitoring
start_monitored_experiment() {
    local experiment_type=$1
    local session_name=$2
    shift 2
    local extra_args="$@"
    
    print_info "Starting monitored experiment: $experiment_type"
    print_info "Session: $session_name"
    
    # Pre-experiment monitoring
    print_info "Collecting pre-experiment baseline metrics..."
    "$MONITOR_HOOK" collect
    
    # Start the actual experiment using the robust runner
    "$GLOBTIM_DIR/hpc/experiments/robust_experiment_runner.sh" "$experiment_type" $extra_args
    
    # Get the actual session name created by the runner
    if [ -f "$GLOBTIM_DIR/.current_experiment_session" ]; then
        local actual_session=$(cat "$GLOBTIM_DIR/.current_experiment_session")
        print_info "Experiment started in session: $actual_session"
        
        # Start background monitoring for this specific experiment
        "$MONITOR_HOOK" start-monitoring "$actual_session"
        
        # Create monitoring dashboard
        print_info "Generating monitoring dashboard..."
        "$MONITOR_HOOK" dashboard
        
        print_info "Monitoring setup complete!"
        print_info "Commands:"
        print_info "  Monitor status: $MONITOR_HOOK status"
        print_info "  Full scan:      $MONITOR_HOOK full-scan"
        print_info "  Attach to experiment: tmux attach -t $actual_session"
        print_info "  View dashboard: Latest file in $GLOBTIM_DIR/tools/hpc/monitoring/dashboard/"
        
    else
        print_warning "Could not determine experiment session name"
    fi
}

# Monitor existing experiment
monitor_existing() {
    local session_name=$1
    
    if [ -z "$session_name" ]; then
        print_info "Finding active GlobTim sessions..."
        local sessions=$(tmux ls 2>/dev/null | grep globtim | cut -d: -f1 || echo "")
        
        if [ -z "$sessions" ]; then
            print_warning "No active GlobTim experiments found"
            return 1
        fi
        
        print_info "Active sessions: $sessions"
        for session in $sessions; do
            print_info "Starting monitoring for: $session"
            "$MONITOR_HOOK" start-monitoring "$session"
        done
    else
        if tmux has-session -t "$session_name" 2>/dev/null; then
            print_info "Starting monitoring for existing session: $session_name"
            "$MONITOR_HOOK" start-monitoring "$session_name"
        else
            print_warning "Session '$session_name' not found"
            return 1
        fi
    fi
}

# Stop monitoring for experiment
stop_monitoring() {
    local session_name=$1
    
    if [ -n "$session_name" ]; then
        print_info "Stopping monitoring for: $session_name"
        "$MONITOR_HOOK" stop-monitoring "$session_name"
    else
        print_info "Stopping all experiment monitoring..."
        # Find all monitor PIDs and stop them
        local monitor_dir="$GLOBTIM_DIR/tools/hpc/monitoring/monitors"
        if [ -d "$monitor_dir" ]; then
            for pid_file in "$monitor_dir"/*.pid; do
                if [ -f "$pid_file" ]; then
                    local session=$(basename "$pid_file" .pid)
                    "$MONITOR_HOOK" stop-monitoring "$session"
                fi
            done
        fi
        print_info "All monitoring stopped"
    fi
}

# Enhanced status check with monitoring
check_experiment_status() {
    print_info "Checking experiment and monitoring status..."
    
    # Use the original status check
    "$GLOBTIM_DIR/hpc/experiments/robust_experiment_runner.sh" status
    
    echo ""
    print_info "Resource monitoring status:"
    "$MONITOR_HOOK" status
    
    echo ""
    print_info "Recent alerts:"
    "$MONITOR_HOOK" alerts
}

# Generate comprehensive monitoring report
generate_monitoring_report() {
    local report_dir="$GLOBTIM_DIR/tools/hpc/monitoring/reports"
    mkdir -p "$report_dir"
    local report_file="$report_dir/monitoring_report_$(date +%Y%m%d_%H%M%S).txt"
    
    print_info "Generating comprehensive monitoring report..."
    
    {
        echo "GlobTim HPC Monitoring Report"
        echo "============================="
        echo "Generated: $(date)"
        echo ""
        
        echo "1. SYSTEM STATUS"
        echo "================"
        "$MONITOR_HOOK" status
        
        echo ""
        echo "2. ACTIVE EXPERIMENTS"
        echo "===================="
        "$GLOBTIM_DIR/hpc/experiments/robust_experiment_runner.sh" list
        
        echo ""
        echo "3. RECENT PERFORMANCE METRICS"
        echo "============================="
        # Show latest performance data
        local perf_dir="$GLOBTIM_DIR/tools/hpc/monitoring/performance"
        if [ -d "$perf_dir" ]; then
            echo "Latest performance logs:"
            ls -lt "$perf_dir"/performance_*.log 2>/dev/null | head -3
        fi
        
        echo ""
        echo "4. RECENT ALERTS"
        echo "================"
        "$MONITOR_HOOK" alerts
        
        echo ""
        echo "5. MONITORING CONFIGURATION"
        echo "=========================="
        echo "Memory Threshold: ${MEMORY_THRESHOLD:-85}%"
        echo "CPU Threshold: ${CPU_THRESHOLD:-90}%"
        echo "Disk Threshold: ${DISK_THRESHOLD:-90}%"
        echo "Julia Process Threshold: ${JULIA_PROCESS_THRESHOLD:-4}"
        
    } > "$report_file"
    
    print_info "Report generated: $report_file"
    echo "$report_file"
}

# Show help
show_help() {
    echo "Integrated Experiment Monitor for r04n02"
    echo "========================================"
    echo ""
    echo "Provides seamless integration between experiment execution and resource monitoring"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Experiment Commands:"
    echo "  start-2d                  - Start monitored 2D test experiment"
    echo "  start-4d [samples] [degree] - Start monitored 4D model experiment"
    echo "  status                    - Check experiment and monitoring status"
    echo "  attach                    - Attach to current experiment session"
    echo ""
    echo "Monitoring Commands:"
    echo "  monitor [session]         - Start monitoring existing experiment(s)"
    echo "  stop-monitor [session]    - Stop monitoring for experiment(s)"
    echo "  dashboard                 - Generate monitoring dashboard"
    echo "  scan                      - Run full monitoring scan"
    echo "  report                    - Generate comprehensive monitoring report"
    echo ""
    echo "Direct Monitoring (passes through to monitor hook):"
    echo "  collect                   - Collect current metrics"
    echo "  alerts                    - Show recent alerts"
    echo "  performance-check         - Run performance regression analysis"
    echo ""
    echo "Examples:"
    echo "  $0 start-4d 10 12         # Start monitored 4D experiment"
    echo "  $0 monitor                # Start monitoring all active sessions"
    echo "  $0 status                 # Check experiment and monitoring status"
    echo "  $0 report                 # Generate comprehensive report"
    echo "  $0 dashboard              # Create monitoring dashboard"
}

# Main command dispatcher
case "${1:-help}" in
    start-2d)
        start_monitored_experiment "2d-test"
        ;;
    start-4d)
        SAMPLES=${2:-10}
        DEGREE=${3:-12}
        start_monitored_experiment "4d-model" "" "$SAMPLES" "$DEGREE"
        ;;
    status)
        check_experiment_status
        ;;
    attach)
        "$GLOBTIM_DIR/hpc/experiments/robust_experiment_runner.sh" attach
        ;;
    monitor)
        monitor_existing "$2"
        ;;
    stop-monitor)
        stop_monitoring "$2"
        ;;
    dashboard)
        print_info "Generating monitoring dashboard..."
        "$MONITOR_HOOK" dashboard
        ;;
    scan)
        print_info "Running full monitoring scan..."
        "$MONITOR_HOOK" full-scan
        ;;
    report)
        generate_monitoring_report
        ;;
    # Pass-through commands to monitor hook
    collect|alerts|performance-check)
        "$MONITOR_HOOK" "$@"
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