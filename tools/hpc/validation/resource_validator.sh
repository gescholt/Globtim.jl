#!/bin/bash
# Resource Availability Validator - Pre-Execution Validation Component
# Part of Issue #27: Implement Pre-Execution Validation Hook System (Component 3/4)
# Validates system resources before experiment execution to prevent OutOfMemory errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Default thresholds (can be overridden)
MIN_MEMORY_GB="${MIN_MEMORY_GB:-10}"      # Minimum free memory in GB
MIN_DISK_GB="${MIN_DISK_GB:-5}"           # Minimum free disk space in GB
MAX_CPU_LOAD="${MAX_CPU_LOAD:-80}"        # Maximum CPU load percentage
MAX_EXPERIMENTS="${MAX_EXPERIMENTS:-5}"   # Maximum concurrent experiments

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function log() {
    echo -e "${GREEN}[RESOURCE-VALIDATOR]${NC} $1" >&2
}

function warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

function info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

function show_usage() {
    cat << EOF
Resource Availability Validator - Pre-Execution Validation
=========================================================

Validates system resources before experiment execution to prevent failures.
Part of Issue #27: Pre-Execution Validation Hook System.

Usage: $0 <command> [options]

Commands:
  validate [degree] [dimension]  - Validate resources for experiment
  memory-check                   - Check available memory
  disk-check                     - Check available disk space  
  cpu-check                      - Check CPU load
  experiments-check              - Check running experiments count
  predict [degree] [dimension]   - Predict memory requirements
  help                          - Show this help

Options:
  --min-memory GB               - Minimum free memory required (default: $MIN_MEMORY_GB)
  --min-disk GB                 - Minimum free disk space required (default: $MIN_DISK_GB)
  --max-cpu-load %              - Maximum CPU load allowed (default: $MAX_CPU_LOAD)
  --max-experiments N           - Maximum concurrent experiments (default: $MAX_EXPERIMENTS)

Environment Variables:
  MIN_MEMORY_GB                 - Override minimum memory requirement
  MIN_DISK_GB                   - Override minimum disk requirement
  MAX_CPU_LOAD                  - Override maximum CPU load
  MAX_EXPERIMENTS               - Override maximum experiments

Examples:
  $0 validate                   # General resource validation
  $0 validate 12 4              # Validate for 4D degree-12 experiment
  $0 memory-check               # Check memory only
  $0 predict 15 5               # Predict memory for high-complexity experiment
  $0 validate --min-memory 50   # Require 50GB free memory

Integration:
  Called by robust_experiment_runner.sh during pre-execution validation.
  Used by memory_predictor.sh for resource requirement estimation.
EOF
}

# Get memory information in GB
function get_memory_info() {
    local memory_info
    
    if command -v free >/dev/null 2>&1; then
        # Linux systems
        memory_info=$(free -g 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local total_gb=$(echo "$memory_info" | awk '/^Mem:/ {print $2}')
            local available_gb=$(echo "$memory_info" | awk '/^Mem:/ {print $7}')
            local used_gb=$(echo "$memory_info" | awk '/^Mem:/ {print $3}')
            
            # If available column doesn't exist, calculate it
            if [[ -z "$available_gb" ]]; then
                local free_gb=$(echo "$memory_info" | awk '/^Mem:/ {print $4}')
                local buffers_gb=$(echo "$memory_info" | awk '/^Mem:/ {print $6}')
                available_gb=$((free_gb + buffers_gb))
            fi
            
            echo "$total_gb,$used_gb,$available_gb"
            return 0
        fi
    fi
    
    # macOS fallback
    if command -v vm_stat >/dev/null 2>&1; then
        local vm_info
        vm_info=$(vm_stat 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local page_size=$(vm_stat | head -1 | grep -o '[0-9]\+')
            local free_pages=$(echo "$vm_info" | awk '/Pages free:/ {print $3}' | tr -d '.')
            local available_gb=$(( (free_pages * page_size) / (1024 * 1024 * 1024) ))
            
            # Get total memory
            local total_bytes
            if command -v sysctl >/dev/null 2>&1; then
                total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
                local total_gb=$((total_bytes / (1024 * 1024 * 1024)))
                local used_gb=$((total_gb - available_gb))
                echo "$total_gb,$used_gb,$available_gb"
                return 0
            fi
        fi
    fi
    
    # Fallback - return unknown
    echo "0,0,0"
    return 1
}

# Get disk space information in GB  
function get_disk_info() {
    local disk_path="${1:-$PROJECT_ROOT}"
    
    if command -v df >/dev/null 2>&1; then
        local disk_info
        
        # Try different df options for compatibility
        if df -BG "$disk_path" >/dev/null 2>&1; then
            # Linux style with -BG
            disk_info=$(df -BG "$disk_path" 2>/dev/null | tail -1)
            local total_gb=$(echo "$disk_info" | awk '{print $2}' | tr -d 'G')
            local used_gb=$(echo "$disk_info" | awk '{print $3}' | tr -d 'G')
            local available_gb=$(echo "$disk_info" | awk '{print $4}' | tr -d 'G')
        elif df -h "$disk_path" >/dev/null 2>&1; then
            # macOS/BSD style with -h, convert to GB
            disk_info=$(df -h "$disk_path" 2>/dev/null | tail -1)
            local total_raw=$(echo "$disk_info" | awk '{print $2}')
            local used_raw=$(echo "$disk_info" | awk '{print $3}')
            local available_raw=$(echo "$disk_info" | awk '{print $4}')
            
            # Convert to GB (rough conversion)
            local total_gb=$(echo "$total_raw" | sed 's/[GT]i\?$//' | awk '{if($1 ~ /T$/) print int($1*1000); else if($1 ~ /G$/) print int($1); else print int($1/1000)}' 2>/dev/null || echo "0")
            local used_gb=$(echo "$used_raw" | sed 's/[GT]i\?$//' | awk '{if($1 ~ /T$/) print int($1*1000); else if($1 ~ /G$/) print int($1); else print int($1/1000)}' 2>/dev/null || echo "0")
            local available_gb=$(echo "$available_raw" | sed 's/[GT]i\?$//' | awk '{if($1 ~ /T$/) print int($1*1000); else if($1 ~ /G$/) print int($1); else print int($1/1000)}' 2>/dev/null || echo "0")
        else
            echo "0,0,0"
            return 1
        fi
        
        echo "$total_gb,$used_gb,$available_gb"
        return 0
    fi
    
    echo "0,0,0"
    return 1
}

# Get CPU load average
function get_cpu_load() {
    local load_avg
    
    if command -v uptime >/dev/null 2>&1; then
        load_avg=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs)
        if [[ $? -eq 0 ]]; then
            local load_1min=$(echo "$load_avg" | awk '{print $1}')
            local load_5min=$(echo "$load_avg" | awk '{print $2}')
            local load_15min=$(echo "$load_avg" | awk '{print $3}')
            echo "$load_1min,$load_5min,$load_15min"
            return 0
        fi
    fi
    
    echo "0,0,0"
    return 1
}

# Count running GlobTim experiments (tmux sessions)
function count_running_experiments() {
    local experiment_count=0
    
    if command -v tmux >/dev/null 2>&1; then
        # Count tmux sessions that look like GlobTim experiments
        local sessions
        sessions=$(tmux list-sessions 2>/dev/null | grep -c "globtim_" || echo "0")
        experiment_count=$sessions
    fi
    
    # Also check for Julia processes that might be running experiments
    if command -v pgrep >/dev/null 2>&1; then
        local julia_processes
        julia_processes=$(pgrep -f "julia.*experiment" 2>/dev/null | wc -l || echo "0")
        experiment_count=$((experiment_count + julia_processes))
    fi
    
    echo "$experiment_count"
}

# Predict memory requirements based on polynomial degree and dimension
function predict_memory_requirements() {
    local degree="${1:-10}"
    local dimension="${2:-3}"
    
    # Use memory_predictor.sh if available
    local memory_predictor="$PROJECT_ROOT/tools/hpc/monitoring/memory_predictor.sh"
    if [[ -x "$memory_predictor" ]]; then
        local prediction
        prediction=$("$memory_predictor" --degree "$degree" --dimension "$dimension" --format json 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            # Extract total_memory_gb from JSON
            local required_gb
            if command -v python3 >/dev/null 2>&1; then
                required_gb=$(echo "$prediction" | python3 -c "import json, sys; data=json.loads(sys.stdin.read()); print(data.get('total_memory_gb', 0))" 2>/dev/null || echo "0")
            else
                # Fallback: extract from JSON manually
                required_gb=$(echo "$prediction" | grep -o '"total_memory_gb": [0-9.]*' | awk '{print $2}' | tr -d ',' || echo "0")
            fi
            echo "$required_gb"
            return 0
        fi
    fi
    
    # Fallback calculation: rough estimation
    # Basis functions ≈ C(degree + dimension, dimension)
    # Memory requirement grows exponentially with degree and dimension
    local basis_estimate=1000  # Conservative base estimate
    
    if [[ $degree -gt 10 && $dimension -gt 3 ]]; then
        basis_estimate=50000  # High-complexity estimation
    elif [[ $degree -gt 8 || $dimension -gt 3 ]]; then
        basis_estimate=10000  # Medium-complexity estimation
    fi
    
    # Rough memory estimate: basis_functions^2 * 8 bytes / 1GB + overhead
    local memory_gb=$((basis_estimate / 1000 + 5))  # Conservative + overhead
    echo "$memory_gb"
}

# Validate memory availability
function validate_memory() {
    local required_gb="${1:-$MIN_MEMORY_GB}"
    
    info "Checking memory availability (required: ${required_gb}GB)"
    
    local memory_data
    memory_data=$(get_memory_info)
    if [[ $? -ne 0 ]]; then
        error "Failed to retrieve memory information"
        return 1
    fi
    
    local total_gb available_gb used_gb
    IFS=',' read -r total_gb used_gb available_gb <<< "$memory_data"
    
    if [[ "$total_gb" == "0" ]]; then
        error "Could not determine system memory"
        return 1
    fi
    
    local usage_percent=0
    if [[ $total_gb -gt 0 ]]; then
        usage_percent=$((used_gb * 100 / total_gb))
    fi
    
    info "Memory Status: ${available_gb}GB available / ${total_gb}GB total (${usage_percent}% used)"
    
    if [[ $available_gb -lt $required_gb ]]; then
        error "Insufficient memory: ${available_gb}GB available < ${required_gb}GB required"
        warning "Consider:"
        warning "  - Reducing polynomial degree or problem dimension"
        warning "  - Stopping other running experiments"
        warning "  - Using lower memory requirements with --min-memory"
        return 1
    else
        log "Memory validation PASSED: ${available_gb}GB available ≥ ${required_gb}GB required"
        return 0
    fi
}

# Validate disk space availability
function validate_disk() {
    local required_gb="${1:-$MIN_DISK_GB}"
    local disk_path="${2:-$PROJECT_ROOT}"
    
    info "Checking disk space availability (required: ${required_gb}GB)"
    
    local disk_data
    disk_data=$(get_disk_info "$disk_path")
    if [[ $? -ne 0 ]]; then
        error "Failed to retrieve disk space information"
        return 1
    fi
    
    local total_gb used_gb available_gb
    IFS=',' read -r total_gb used_gb available_gb <<< "$disk_data"
    
    if [[ "$total_gb" == "0" ]]; then
        error "Could not determine disk space for: $disk_path"
        return 1
    fi
    
    local usage_percent=0
    if [[ $total_gb -gt 0 ]]; then
        usage_percent=$((used_gb * 100 / total_gb))
    fi
    
    info "Disk Status: ${available_gb}GB available / ${total_gb}GB total (${usage_percent}% used)"
    
    if [[ $available_gb -lt $required_gb ]]; then
        error "Insufficient disk space: ${available_gb}GB available < ${required_gb}GB required"
        warning "Consider cleaning up old experiment results or using different storage location"
        return 1
    else
        log "Disk validation PASSED: ${available_gb}GB available ≥ ${required_gb}GB required"
        return 0
    fi
}

# Validate CPU load
function validate_cpu() {
    local max_load_percent="${1:-$MAX_CPU_LOAD}"
    
    info "Checking CPU load (max allowed: ${max_load_percent}%)"
    
    local load_data
    load_data=$(get_cpu_load)
    if [[ $? -ne 0 ]]; then
        error "Failed to retrieve CPU load information"
        return 1
    fi
    
    local load_1min load_5min load_15min
    IFS=',' read -r load_1min load_5min load_15min <<< "$load_data"
    
    # Get number of CPU cores for percentage calculation
    local cpu_cores=1
    if command -v nproc >/dev/null 2>&1; then
        cpu_cores=$(nproc)
    elif [[ -r /proc/cpuinfo ]]; then
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    fi
    
    local load_percent_1min
    load_percent_1min=$(echo "$load_1min $cpu_cores" | awk '{printf "%.1f", ($1 / $2) * 100}')
    
    info "CPU Status: Load averages: ${load_1min}, ${load_5min}, ${load_15min} (1min load: ${load_percent_1min}%)"
    
    local threshold_exceeded=0
    if (( $(echo "$load_percent_1min > $max_load_percent" | bc -l 2>/dev/null || echo "0") )); then
        threshold_exceeded=1
    fi
    
    if [[ $threshold_exceeded -eq 1 ]]; then
        warning "High CPU load: ${load_percent_1min}% > ${max_load_percent}% threshold"
        warning "Current experiment may run slowly or compete for resources"
        warning "Consider waiting for lower system load or adjusting --max-cpu-load"
        return 1
    else
        log "CPU validation PASSED: ${load_percent_1min}% load ≤ ${max_load_percent}% threshold"
        return 0
    fi
}

# Validate concurrent experiments
function validate_experiments() {
    local max_experiments="${1:-$MAX_EXPERIMENTS}"
    
    info "Checking concurrent experiments (max allowed: $max_experiments)"
    
    local running_count
    running_count=$(count_running_experiments)
    
    info "Concurrent Experiments: $running_count running"
    
    if [[ $running_count -ge $max_experiments ]]; then
        error "Too many concurrent experiments: $running_count ≥ $max_experiments"
        warning "Consider:"
        warning "  - Waiting for current experiments to complete"  
        warning "  - Stopping unnecessary experiments with 'tmux kill-session'"
        warning "  - Adjusting --max-experiments limit"
        
        # Show running experiments
        if command -v tmux >/dev/null 2>&1; then
            local sessions
            sessions=$(tmux list-sessions 2>/dev/null | grep "globtim_" || echo "")
            if [[ -n "$sessions" ]]; then
                warning "Running GlobTim sessions:"
                echo "$sessions" | while IFS= read -r session; do
                    warning "  - $session"
                done
            fi
        fi
        
        return 1
    else
        log "Experiments validation PASSED: $running_count < $max_experiments limit"
        return 0
    fi
}

# Comprehensive resource validation
function validate_all_resources() {
    local degree="${1:-}"
    local dimension="${2:-}"
    local memory_gb="$MIN_MEMORY_GB"
    local disk_gb="$MIN_DISK_GB"
    local cpu_load="$MAX_CPU_LOAD"
    local max_exp="$MAX_EXPERIMENTS"
    
    # If degree and dimension provided, predict memory requirements
    if [[ -n "$degree" && -n "$dimension" ]]; then
        info "Predicting memory requirements for degree=$degree, dimension=$dimension"
        local predicted_memory
        predicted_memory=$(predict_memory_requirements "$degree" "$dimension")
        if [[ $? -eq 0 && "$predicted_memory" != "0" ]]; then
            # Use predicted memory if it's higher than default
            if (( $(echo "$predicted_memory > $memory_gb" | bc -l 2>/dev/null || echo "0") )); then
                memory_gb=$(echo "$predicted_memory" | awk '{printf "%.0f", $1 + 1}')  # Round up + buffer
                info "Adjusted memory requirement to ${memory_gb}GB based on prediction"
            fi
        fi
    fi
    
    echo "🔍 Resource Validation Starting..."
    echo "Required Resources: Memory ≥ ${memory_gb}GB, Disk ≥ ${disk_gb}GB, CPU ≤ ${cpu_load}%, Experiments ≤ ${max_exp}"
    echo "=" * 60
    
    local validation_results=()
    local overall_success=true
    
    # Memory validation
    if validate_memory "$memory_gb"; then
        validation_results+=("Memory: ✅ PASSED")
    else
        validation_results+=("Memory: ❌ FAILED")
        overall_success=false
    fi
    
    # Disk validation  
    if validate_disk "$disk_gb"; then
        validation_results+=("Disk: ✅ PASSED")
    else
        validation_results+=("Disk: ❌ FAILED")
        overall_success=false
    fi
    
    # CPU validation
    if validate_cpu "$cpu_load"; then
        validation_results+=("CPU: ✅ PASSED")
    else
        validation_results+=("CPU: ⚠️  WARNING (not blocking)")
        # CPU load warnings don't block execution
    fi
    
    # Experiments validation
    if validate_experiments "$max_exp"; then
        validation_results+=("Experiments: ✅ PASSED")
    else
        validation_results+=("Experiments: ❌ FAILED")
        overall_success=false
    fi
    
    echo ""
    echo "=" * 60
    echo "📊 Resource Validation Summary:"
    for result in "${validation_results[@]}"; do
        echo "  $result"
    done
    
    if [[ "$overall_success" == true ]]; then
        echo ""
        echo "🎉 Resource Validation PASSED - Ready for experiment execution"
        return 0
    else
        echo ""
        echo "❌ Resource Validation FAILED - Address issues before proceeding"
        return 1
    fi
}

# Parse command line arguments
function main() {
    local command="${1:-help}"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --min-memory)
                MIN_MEMORY_GB="$2"
                shift 2
                ;;
            --min-disk)
                MIN_DISK_GB="$2"
                shift 2
                ;;
            --max-cpu-load)
                MAX_CPU_LOAD="$2"
                shift 2
                ;;
            --max-experiments)
                MAX_EXPERIMENTS="$2"
                shift 2
                ;;
            *)
                if [[ "$1" != "$command" ]]; then
                    break
                fi
                shift
                ;;
        esac
    done
    
    case "$command" in
        validate)
            local degree="${2:-}"
            local dimension="${3:-}"
            validate_all_resources "$degree" "$dimension"
            ;;
        memory-check)
            validate_memory
            ;;
        disk-check)
            validate_disk
            ;;
        cpu-check)
            validate_cpu
            ;;
        experiments-check)
            validate_experiments
            ;;
        predict)
            local degree="${2:-10}"
            local dimension="${3:-3}"
            local required_gb
            required_gb=$(predict_memory_requirements "$degree" "$dimension")
            echo "Predicted memory requirement: ${required_gb}GB for degree=$degree, dimension=$dimension"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi