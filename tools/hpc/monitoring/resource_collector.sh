#!/bin/bash
# HPC Resource Collector
# ======================
# 
# Collects comprehensive system resource metrics from r04n02 compute node
# for integration with the HPC Resource Monitor Hook system.
#
# This script provides the core data collection functionality that feeds into:
# - Real-time monitoring dashboards
# - Automated alert systems
# - Performance regression detection
# - Experiment lifecycle management
#
# Usage:
#   tools/hpc/monitoring/resource_collector.sh [--format json|text] [--interval 30]
#
# Author: Claude Code HPC monitoring system
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Default configuration
FORMAT="json"
INTERVAL=""
OUTPUT_FILE=""
CONTINUOUS=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function usage() {
    cat <<EOF
HPC Resource Collector
====================

Collects comprehensive system resource metrics from r04n02 compute node.

Usage: $0 [OPTIONS]

Options:
  --format FORMAT      Output format: json, text, csv (default: json)
  --interval SECONDS   Continuous collection interval (default: single snapshot)
  --output FILE        Output file (default: stdout)
  --continuous         Continuous monitoring mode
  --help              Show this help

Examples:
  # Single snapshot in JSON format
  $0 --format json

  # Continuous monitoring every 30 seconds
  $0 --continuous --interval 30

  # Save to file in CSV format
  $0 --format csv --output /tmp/hpc_metrics.csv

Integration:
  This collector is used by:
  - ~/.claude/hooks/hpc-resource-monitor.sh
  - tools/hpc/node_monitor.py
  - hpc/monitoring/live_monitor.sh

EOF
}

function log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$FORMAT" == "json" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}" >&2
    else
        echo "[$timestamp] [$level] $message" >&2
    fi
}

function collect_system_metrics() {
    log_message "INFO" "Collecting system metrics from r04n02"
    
    # Use secure_node_config.py for authenticated access
    local node_command="python3 '$PROJECT_ROOT/tools/hpc/secure_node_config.py'"
    
    # Try to use the node monitor if available, otherwise fallback to direct commands
    if [[ -f "$PROJECT_ROOT/tools/hpc/node_monitor.py" ]]; then
        local metrics_json
        metrics_json=$(cd "$PROJECT_ROOT" && python3 tools/hpc/node_monitor.py --report --format json 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            echo "$metrics_json"
            return 0
        fi
    fi
    
    # Fallback: Direct resource collection
    collect_basic_metrics
}

function collect_basic_metrics() {
    log_message "INFO" "Using fallback basic metrics collection"
    
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname 2>/dev/null || echo "local")
    
    # Try to get basic system info
    local memory_info="{}"
    local cpu_info="{}"
    local disk_info="{}"
    local process_info="{}"
    
    # Memory information (if available)
    if command -v free >/dev/null 2>&1; then
        local mem_data=$(free -b 2>/dev/null | awk '/^Mem:/ {printf "%s,%s,%s,%.1f", $2, $3, $4, ($3/$2)*100}' || echo "0,0,0,0")
        IFS=',' read -r mem_total mem_used mem_free mem_percent <<< "$mem_data"
        memory_info=$(cat <<EOF
{
  "total": $mem_total,
  "used": $mem_used,
  "free": $mem_free,
  "usage_percent": $mem_percent
}
EOF
)
    fi
    
    # CPU load average
    if command -v uptime >/dev/null 2>&1; then
        local load_data=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs || echo "0 0 0")
        read -r load_1min load_5min load_15min <<< "$load_data"
        cpu_info=$(cat <<EOF
{
  "1min": ${load_1min:-0},
  "5min": ${load_5min:-0}, 
  "15min": ${load_15min:-0}
}
EOF
)
    fi
    
    # Disk usage
    if command -v df >/dev/null 2>&1; then
        local disk_data=$(df . 2>/dev/null | awk 'NR==2 {printf "%s,%s,%s,%d", $2*1024, $3*1024, $4*1024, $5}' | tr -d '%' || echo "0,0,0,0")
        IFS=',' read -r disk_total disk_used disk_available disk_percent <<< "$disk_data"
        disk_info=$(cat <<EOF
{
  "total": $disk_total,
  "used": $disk_used,
  "available": $disk_available,
  "usage_percent": $disk_percent
}
EOF
)
    fi
    
    # Process count
    if command -v ps >/dev/null 2>&1; then
        local process_count=$(ps aux 2>/dev/null | wc -l || echo "0")
        process_info=$(cat <<EOF
{
  "total_processes": $process_count,
  "julia_processes": 0
}
EOF
)
    fi
    
    # Construct final JSON
    cat <<EOF
{
  "report_timestamp": "$timestamp",
  "hostname": "$hostname",
  "monitoring_system": {
    "version": "1.0",
    "collector": "resource_collector.sh",
    "mode": "fallback"
  },
  "system_resources": {
    "timestamp": "$timestamp",
    "memory": $memory_info,
    "cpu_load": $cpu_info,
    "disk": $disk_info,
    "processes": $process_count
  },
  "tmux_sessions": [],
  "active_experiments": [],
  "anomalies": [],
  "summary": {
    "system_health": "unknown",
    "collection_method": "fallback"
  }
}
EOF
}

function format_output() {
    local metrics_json="$1"
    
    case "$FORMAT" in
        "json")
            echo "$metrics_json" | jq '.' 2>/dev/null || echo "$metrics_json"
            ;;
        "text")
            format_text_output "$metrics_json"
            ;;
        "csv")
            format_csv_output "$metrics_json"
            ;;
        *)
            log_message "ERROR" "Unknown format: $FORMAT"
            echo "$metrics_json"
            ;;
    esac
}

function format_text_output() {
    local metrics_json="$1"
    
    # Extract key metrics using Python or jq
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
from datetime import datetime

try:
    data = json.loads(sys.stdin.read())
    
    print('HPC Resource Status')
    print('==================')
    print(f'Timestamp: {data.get(\"report_timestamp\", \"N/A\")}')
    print(f'Hostname: {data.get(\"hostname\", \"N/A\")}')
    print()
    
    # System resources
    res = data.get('system_resources', {})
    memory = res.get('memory', {})
    cpu = res.get('cpu_load', {})
    disk = res.get('disk', {})
    
    print('System Resources:')
    print(f'  Memory Usage: {memory.get(\"usage_percent\", 0):.1f}%')
    print(f'  CPU Load (1m): {cpu.get(\"1min\", 0):.2f}')
    print(f'  Disk Usage: {disk.get(\"usage_percent\", 0)}%')
    print(f'  Processes: {res.get(\"processes\", 0)}')
    print()
    
    # Sessions and experiments
    sessions = data.get('tmux_sessions', [])
    experiments = data.get('active_experiments', [])
    anomalies = data.get('anomalies', [])
    
    print(f'Active Sessions: {len(sessions)}')
    print(f'Running Experiments: {len(experiments)}')
    print(f'Anomalies Detected: {len(anomalies)}')
    
    if anomalies:
        print()
        print('Recent Anomalies:')
        for anomaly in anomalies[:5]:  # Show up to 5 most recent
            severity = anomaly.get('severity', 'UNKNOWN')
            message = anomaly.get('message', 'No message')
            print(f'  [{severity}] {message}')

except Exception as e:
    print(f'Error formatting output: {e}')
    print('Raw JSON:')
    print(sys.stdin.read())
" <<< "$metrics_json"
    else
        echo "Text formatting requires Python3"
        echo "$metrics_json"
    fi
}

function format_csv_output() {
    local metrics_json="$1"
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys

try:
    data = json.loads(sys.stdin.read())
    
    # CSV header
    print('timestamp,hostname,memory_usage_percent,cpu_load_1min,disk_usage_percent,processes,sessions,experiments,anomalies')
    
    # Extract data
    timestamp = data.get('report_timestamp', '')
    hostname = data.get('hostname', '')
    
    res = data.get('system_resources', {})
    memory_usage = res.get('memory', {}).get('usage_percent', 0)
    cpu_load = res.get('cpu_load', {}).get('1min', 0)
    disk_usage = res.get('disk', {}).get('usage_percent', 0)
    processes = res.get('processes', 0)
    
    sessions_count = len(data.get('tmux_sessions', []))
    experiments_count = len(data.get('active_experiments', []))
    anomalies_count = len(data.get('anomalies', []))
    
    # CSV data row
    print(f'{timestamp},{hostname},{memory_usage},{cpu_load},{disk_usage},{processes},{sessions_count},{experiments_count},{anomalies_count}')

except Exception as e:
    print(f'Error,Error,0,0,0,0,0,0,0')
" <<< "$metrics_json"
    else
        echo "CSV formatting requires Python3"
        echo "timestamp,error"
        echo "$(date -Iseconds),Python3 not available"
    fi
}

function run_continuous_monitoring() {
    log_message "INFO" "Starting continuous monitoring (interval: ${INTERVAL}s)"
    
    # Set up signal handlers for clean exit
    trap 'log_message "INFO" "Stopping continuous monitoring"; exit 0' SIGINT SIGTERM
    
    local iteration=0
    while true; do
        ((iteration++))
        log_message "INFO" "Collection iteration: $iteration"
        
        local metrics
        metrics=$(collect_system_metrics)
        
        if [[ -n "$OUTPUT_FILE" ]]; then
            format_output "$metrics" >> "$OUTPUT_FILE"
        else
            format_output "$metrics"
        fi
        
        if [[ -n "$INTERVAL" ]]; then
            sleep "$INTERVAL"
        else
            log_message "WARNING" "No interval specified for continuous mode, using 30s default"
            sleep 30
        fi
    done
}

function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --continuous)
                CONTINUOUS=true
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
    
    # Validate format
    if [[ "$FORMAT" != "json" && "$FORMAT" != "text" && "$FORMAT" != "csv" ]]; then
        log_message "ERROR" "Invalid format: $FORMAT"
        exit 1
    fi
    
    # Run monitoring
    if [[ "$CONTINUOUS" == true ]]; then
        run_continuous_monitoring
    else
        # Single collection
        log_message "INFO" "Performing single resource collection"
        local metrics
        metrics=$(collect_system_metrics)
        
        if [[ -n "$OUTPUT_FILE" ]]; then
            format_output "$metrics" > "$OUTPUT_FILE"
            log_message "INFO" "Results saved to: $OUTPUT_FILE"
        else
            format_output "$metrics"
        fi
    fi
}

# Execute main function
main "$@"