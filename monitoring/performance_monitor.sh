#!/bin/bash
# Julia HPC Performance Monitoring Script
# Created: August 11, 2025

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
PERFORMANCE_LOG="$LOG_DIR/performance_$(date +%Y%m%d).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log_metric() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PERFORMANCE_LOG"
}

# Function to collect system metrics
collect_system_metrics() {
    log_metric "=== System Metrics Collection ==="
    
    # CPU and Memory usage
    log_metric "CPU_USAGE: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)"
    log_metric "MEMORY_USAGE: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')"
    
    # Storage metrics
    log_metric "HOME_USAGE: $(ssh falcon "df -h ~ | tail -1 | awk '{print \$5}'" 2>/dev/null)"
    log_metric "NFS_DEPOT_SIZE: $(ssh fileserver-ssh "du -sh ~/julia_depot_nfs 2>/dev/null | cut -f1" 2>/dev/null)"
    
    # Job queue status
    local running_jobs=$(ssh falcon "squeue -u scholten | wc -l" 2>/dev/null)
    log_metric "RUNNING_JOBS: $((running_jobs - 1))"  # Subtract header line
}

# Function to test Julia performance
test_julia_performance() {
    log_metric "=== Julia Performance Test ==="
    
    # Create temporary performance test script
    local test_script="/tmp/julia_perf_test_$$.jl"
    
    cat > "$test_script" << 'EOF'
using Dates

println("PERF_TEST_START: ", Dates.now())

# Startup time test
startup_time = @elapsed begin
    # Basic operations
    x = 1 + 1
end
println("STARTUP_TIME: ", startup_time)

# Package loading test
pkg_time = @elapsed begin
    using LinearAlgebra
end
println("PACKAGE_LOAD_TIME: ", pkg_time)

# Computation test
comp_time = @elapsed begin
    A = rand(500, 500)
    B = A * A
    eigenvals = eigvals(A)
end
println("COMPUTATION_TIME: ", comp_time)

# Memory allocation test
alloc_time = @elapsed begin
    arrays = [rand(50, 50) for i in 1:50]
end
println("ALLOCATION_TIME: ", alloc_time)

println("PERF_TEST_END: ", Dates.now())
EOF

    # Run performance test on cluster
    ssh falcon "cd ~/globtim_hpc && source ./setup_nfs_julia.sh >/dev/null 2>&1 && julia --startup-file=no $test_script" 2>/dev/null | while read line; do
        if [[ $line == STARTUP_TIME:* ]] || [[ $line == PACKAGE_LOAD_TIME:* ]] || [[ $line == COMPUTATION_TIME:* ]] || [[ $line == ALLOCATION_TIME:* ]]; then
            log_metric "$line"
        fi
    done
    
    # Clean up
    ssh falcon "rm -f $test_script" 2>/dev/null
}

# Function to check depot health
check_depot_health() {
    log_metric "=== Depot Health Check ==="
    
    # Check NFS depot accessibility
    if ssh fileserver-ssh "ls ~/julia_depot_nfs >/dev/null 2>&1"; then
        log_metric "NFS_DEPOT_STATUS: ACCESSIBLE"
        
        # Count packages
        local package_count=$(ssh fileserver-ssh "find ~/julia_depot_nfs -name '*.toml' 2>/dev/null | wc -l")
        log_metric "PACKAGE_COUNT: $package_count"
    else
        log_metric "NFS_DEPOT_STATUS: INACCESSIBLE"
    fi
    
    # Check symbolic link
    if ssh falcon "ls -la ~/.julia >/dev/null 2>&1"; then
        log_metric "SYMLINK_STATUS: EXISTS"
    else
        log_metric "SYMLINK_STATUS: MISSING"
    fi
    
    # Check quota status
    local quota_usage=$(ssh falcon "quota -vs 2>/dev/null | grep scholten | awk '{print \$2}'" 2>/dev/null)
    if [ -n "$quota_usage" ]; then
        log_metric "QUOTA_USAGE: $quota_usage"
    fi
}

# Function to generate performance report
generate_report() {
    local report_file="$LOG_DIR/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "Julia HPC Performance Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Recent performance metrics
    echo "Recent Performance Metrics:" >> "$report_file"
    echo "-------------------------" >> "$report_file"
    tail -20 "$PERFORMANCE_LOG" | grep -E "(STARTUP_TIME|PACKAGE_LOAD_TIME|COMPUTATION_TIME)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Storage trends
    echo "Storage Trends:" >> "$report_file"
    echo "---------------" >> "$report_file"
    tail -50 "$PERFORMANCE_LOG" | grep -E "(NFS_DEPOT_SIZE|QUOTA_USAGE)" | tail -10 >> "$report_file"
    echo "" >> "$report_file"
    
    # System health
    echo "System Health:" >> "$report_file"
    echo "-------------" >> "$report_file"
    tail -10 "$PERFORMANCE_LOG" | grep -E "(NFS_DEPOT_STATUS|SYMLINK_STATUS)" >> "$report_file"
    
    echo "Report saved to: $report_file"
    log_metric "REPORT_GENERATED: $report_file"
}

# Function to show usage
show_usage() {
    echo "Julia HPC Performance Monitor"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  collect    - Collect current performance metrics"
    echo "  test       - Run Julia performance test"
    echo "  health     - Check depot and system health"
    echo "  report     - Generate performance report"
    echo "  monitor    - Run continuous monitoring (collect + test + health)"
    echo "  logs       - Show recent log entries"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 monitor   # Run full monitoring cycle"
    echo "  $0 test      # Test Julia performance only"
    echo "  $0 report    # Generate performance report"
}

# Function to show recent logs
show_logs() {
    if [ -f "$PERFORMANCE_LOG" ]; then
        echo "Recent performance metrics:"
        echo "=========================="
        tail -20 "$PERFORMANCE_LOG"
    else
        echo "No performance log found for today."
    fi
}

# Main script logic
case "${1:-help}" in
    collect)
        collect_system_metrics
        ;;
    test)
        test_julia_performance
        ;;
    health)
        check_depot_health
        ;;
    report)
        generate_report
        ;;
    monitor)
        log_metric "Starting full monitoring cycle"
        collect_system_metrics
        test_julia_performance
        check_depot_health
        log_metric "Monitoring cycle complete"
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
