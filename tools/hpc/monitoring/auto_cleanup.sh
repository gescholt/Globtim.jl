#!/bin/bash
# Automated HPC Cleanup and Resource Management System
# ====================================================
#
# Automated cleanup system for failed experiments, stale sessions, and
# resource optimization on r04n02 compute node. Integrates with the
# HPC Resource Monitor Hook system for intelligent cleanup decisions.
#
# Features:
# - Automatic cleanup of failed/stale experiment sessions
# - Log file rotation and archival
# - Temporary file cleanup with safety checks
# - Resource usage optimization
# - Experiment result organization
# - Integration with alert system for cleanup notifications
#
# Safety Features:
# - Confirmation prompts for destructive operations
# - Backup creation before cleanup
# - Detailed logging of all cleanup actions
# - Resource usage validation before cleanup
#
# Usage:
#   tools/hpc/monitoring/auto_cleanup.sh --stale-sessions
#   tools/hpc/monitoring/auto_cleanup.sh --log-rotation
#   tools/hpc/monitoring/auto_cleanup.sh --temp-files
#   tools/hpc/monitoring/auto_cleanup.sh --full-cleanup
#   tools/hpc/monitoring/auto_cleanup.sh --dry-run
#
# Author: Claude Code HPC monitoring system
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
GLOBTIM_DIR="${GLOBTIM_DIR:-/home/scholten/globtim}"
RESOURCE_HOOK="$HOME/.claude/hooks/hpc-resource-monitor.sh"
CLEANUP_LOG_DIR="$PROJECT_ROOT/hpc/logs/cleanup"
BACKUP_DIR="$PROJECT_ROOT/hpc/backups/cleanup_$(date +%Y%m%d)"

# Cleanup thresholds
STALE_SESSION_HOURS=${CLEANUP_STALE_HOURS:-48}       # Hours before session considered stale
STALE_LOG_DAYS=${CLEANUP_LOG_DAYS:-14}               # Days before logs are archived
STALE_TEMP_HOURS=${CLEANUP_TEMP_HOURS:-24}           # Hours before temp files cleaned
MAX_LOG_SIZE_MB=${CLEANUP_MAX_LOG_MB:-500}           # Max log file size before rotation

# Safety settings
DRY_RUN=false
FORCE=false
BACKUP_ENABLED=true
INTERACTIVE=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

function log_cleanup_event() {
    local level="$1"
    local message="$2"
    local action="${3:-general}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$CLEANUP_LOG_DIR"
    
    local log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level", 
  "action": "$action",
  "message": "$message",
  "dry_run": $DRY_RUN,
  "force": $FORCE
}
EOF
)
    
    echo "$log_entry" >> "$CLEANUP_LOG_DIR/auto_cleanup.jsonl"
    
    # Also log to console
    local color="$NC"
    case "$level" in
        "ERROR") color="$RED" ;;
        "WARNING") color="$YELLOW" ;;
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
    esac
    
    echo -e "${color}[$timestamp] [$level]${NC} $message"
}

function usage() {
    cat <<EOF
Automated HPC Cleanup and Resource Management System
===================================================

Intelligent cleanup system for HPC experiment management with safety features.

Usage: $0 [ACTIONS] [OPTIONS]

Actions:
  --stale-sessions       Clean up stale tmux sessions
  --log-rotation         Rotate and archive large log files  
  --temp-files           Clean up temporary experiment files
  --failed-experiments   Clean up failed experiment directories
  --organize-results     Organize experiment results by date/type
  --full-cleanup         Run all cleanup actions
  --disk-space          Free up disk space (comprehensive cleanup)

Options:
  --dry-run             Show what would be cleaned without doing it
  --force               Skip confirmation prompts (use with caution)
  --no-backup           Disable backup creation before cleanup
  --interactive         Enable interactive mode for confirmations (default)
  --stale-hours HOURS   Hours before sessions considered stale (default: $STALE_SESSION_HOURS)
  --log-days DAYS       Days before logs archived (default: $STALE_LOG_DAYS)
  --temp-hours HOURS    Hours before temp files cleaned (default: $STALE_TEMP_HOURS)
  --max-log-mb MB       Max log size before rotation (default: $MAX_LOG_SIZE_MB)
  --help               Show this help

Safety Features:
  - Confirmation prompts for destructive operations
  - Automatic backup creation before cleanup
  - Detailed logging of all actions
  - Dry-run mode for testing
  - Resource usage validation

Integration:
  - Uses HPC Resource Monitor Hook for system status
  - Integrates with tmux monitoring system
  - Coordinates with experiment runners

Examples:
  # Safe cleanup with dry-run first
  $0 --full-cleanup --dry-run
  $0 --full-cleanup

  # Clean only stale sessions
  $0 --stale-sessions

  # Emergency disk space cleanup
  $0 --disk-space --force

  # Organize results without cleanup
  $0 --organize-results

Log Files:
  Cleanup logs: $CLEANUP_LOG_DIR/auto_cleanup.jsonl
  Backups: $BACKUP_DIR/

EOF
}

function check_system_resources() {
    log_cleanup_event "INFO" "Checking system resources before cleanup" "resource_check"
    
    local resource_status="{}"
    
    # Use resource hook if available
    if [[ -x "$RESOURCE_HOOK" ]]; then
        resource_status=$("$RESOURCE_HOOK" status 2>/dev/null) || {
            log_cleanup_event "WARNING" "Resource hook failed, using fallback" "resource_check"
            resource_status='{"error": "resource_hook_failed"}'
        }
    fi
    
    # Extract key metrics
    if command -v python3 >/dev/null 2>&1 && [[ "$resource_status" != *"error"* ]]; then
        local resource_summary
        resource_summary=$(python3 -c "
import json
try:
    data = json.loads('''$resource_status''')
    resources = data.get('system_resources', {})
    memory = resources.get('memory', {})
    disk = resources.get('disk', {})
    
    mem_usage = memory.get('usage_percent', 0)
    disk_usage = disk.get('usage_percent', 0)
    anomalies = len(data.get('anomalies', []))
    
    print(f'Memory: {mem_usage:.1f}% | Disk: {disk_usage}% | Anomalies: {anomalies}')
    
    # Return status for decision making
    if disk_usage > 90:
        print('CRITICAL_DISK')
    elif disk_usage > 80 or mem_usage > 90:
        print('HIGH_USAGE')
    elif anomalies > 0:
        print('ANOMALIES_DETECTED')
    else:
        print('HEALTHY')
        
except Exception as e:
    print('Resource check failed')
    print('UNKNOWN')
")
        
        echo "$resource_summary"
    else
        echo "Resource check unavailable"
        echo "UNKNOWN"
    fi
}

function create_backup() {
    local backup_name="$1"
    local source_path="$2"
    
    if [[ "$BACKUP_ENABLED" == false ]]; then
        log_cleanup_event "INFO" "Backup disabled, skipping backup creation" "backup"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_cleanup_event "INFO" "[DRY RUN] Would create backup: $backup_name" "backup"
        return 0
    fi
    
    log_cleanup_event "INFO" "Creating backup: $backup_name" "backup"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ -f "$source_path" ]]; then
        cp "$source_path" "$backup_path" || {
            log_cleanup_event "ERROR" "Failed to create backup: $backup_name" "backup"
            return 1
        }
    elif [[ -d "$source_path" ]]; then
        cp -r "$source_path" "$backup_path" || {
            log_cleanup_event "ERROR" "Failed to create directory backup: $backup_name" "backup"
            return 1
        }
    else
        log_cleanup_event "WARNING" "Source path not found for backup: $source_path" "backup"
        return 1
    fi
    
    log_cleanup_event "SUCCESS" "Backup created successfully: $backup_path" "backup"
    return 0
}

function cleanup_stale_sessions() {
    log_cleanup_event "INFO" "Starting stale session cleanup (threshold: ${STALE_SESSION_HOURS}h)" "stale_sessions"
    
    # Get list of tmux sessions
    local sessions
    if command -v tmux >/dev/null 2>&1; then
        sessions=$(tmux ls 2>/dev/null | grep -i globtim || echo "")
    else
        log_cleanup_event "WARNING" "tmux not available for session cleanup" "stale_sessions"
        return 1
    fi
    
    if [[ -z "$sessions" ]]; then
        log_cleanup_event "INFO" "No GlobTim sessions found" "stale_sessions"
        return 0
    fi
    
    local cleaned_count=0
    local current_time=$(date +%s)
    local threshold_seconds=$((STALE_SESSION_HOURS * 3600))
    
    echo "$sessions" | while IFS=':' read -r session_line; do
        # Parse session info
        local session_name=$(echo "$session_line" | awk '{print $1}')
        
        if [[ -n "$session_name" ]]; then
            # Get session creation time
            local session_info
            session_info=$(tmux list-sessions -F '#{session_name}:#{session_created}:#{session_activity}' 2>/dev/null | grep "^$session_name:" || echo "")
            
            if [[ -n "$session_info" ]]; then
                IFS=':' read -r name created activity <<< "$session_info"
                
                # Calculate session age
                local age_seconds=$((current_time - created))
                local activity_seconds=$((current_time - activity))
                
                # Check if session is stale
                if [[ $age_seconds -gt $threshold_seconds && $activity_seconds -gt $threshold_seconds ]]; then
                    local age_hours=$((age_seconds / 3600))
                    local activity_hours=$((activity_seconds / 3600))
                    
                    log_cleanup_event "WARNING" "Found stale session: $session_name (age: ${age_hours}h, inactive: ${activity_hours}h)" "stale_sessions"
                    
                    # Confirmation check
                    if [[ "$INTERACTIVE" == true && "$FORCE" == false && "$DRY_RUN" == false ]]; then
                        echo -e "${YELLOW}⚠️  Stale session found: $session_name${NC}"
                        echo "   Age: ${age_hours} hours, Inactive: ${activity_hours} hours"
                        read -p "Kill this stale session? [y/N]: " confirm
                        
                        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                            log_cleanup_event "INFO" "User skipped cleanup of session: $session_name" "stale_sessions"
                            continue
                        fi
                    fi
                    
                    # Perform cleanup
                    if [[ "$DRY_RUN" == true ]]; then
                        log_cleanup_event "INFO" "[DRY RUN] Would kill stale session: $session_name" "stale_sessions"
                        ((cleaned_count++))
                    else
                        if tmux kill-session -t "$session_name" 2>/dev/null; then
                            log_cleanup_event "SUCCESS" "Killed stale session: $session_name" "stale_sessions"
                            ((cleaned_count++))
                        else
                            log_cleanup_event "ERROR" "Failed to kill session: $session_name" "stale_sessions"
                        fi
                    fi
                fi
            fi
        fi
    done
    
    log_cleanup_event "SUCCESS" "Stale session cleanup completed - $cleaned_count sessions processed" "stale_sessions"
}

function cleanup_log_files() {
    log_cleanup_event "INFO" "Starting log file rotation and cleanup (threshold: ${STALE_LOG_DAYS} days, ${MAX_LOG_SIZE_MB}MB)" "log_cleanup"
    
    # Define log directories to clean
    local log_directories=(
        "$PROJECT_ROOT/hpc/logs"
        "$PROJECT_ROOT/tools/hpc"
        "$HOME/.claude"
        "$GLOBTIM_DIR/hpc_results"
        "$GLOBTIM_DIR/node_experiments/outputs"
    )
    
    local cleaned_files=0
    local archived_files=0
    local threshold_timestamp=$(date -d "$STALE_LOG_DAYS days ago" +%s)
    local max_size_bytes=$((MAX_LOG_SIZE_MB * 1024 * 1024))
    
    for log_dir in "${log_directories[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            continue
        fi
        
        log_cleanup_event "INFO" "Processing log directory: $log_dir" "log_cleanup"
        
        # Find log files that need processing
        find "$log_dir" -type f \( -name "*.log" -o -name "*.jsonl" -o -name "*.out" -o -name "*.err" \) | while read -r log_file; do
            # Get file info
            local file_size=$(stat -f%z "$log_file" 2>/dev/null || echo "0")
            local file_mtime=$(stat -f%m "$log_file" 2>/dev/null || echo "0")
            local file_age_days=$(( ($(date +%s) - file_mtime) / 86400 ))
            
            local needs_processing=false
            local reason=""
            
            # Check if file is old
            if [[ $file_mtime -lt $threshold_timestamp ]]; then
                needs_processing=true
                reason="old (${file_age_days} days)"
            fi
            
            # Check if file is too large
            if [[ $file_size -gt $max_size_bytes ]]; then
                needs_processing=true
                local size_mb=$((file_size / 1024 / 1024))
                reason="${reason:+$reason, }large (${size_mb}MB)"
            fi
            
            if [[ "$needs_processing" == true ]]; then
                log_cleanup_event "INFO" "Log file needs processing: $log_file ($reason)" "log_cleanup"
                
                # Create backup before processing
                local backup_name="$(basename "$log_file").$(date +%Y%m%d_%H%M%S)"
                
                if [[ "$DRY_RUN" == true ]]; then
                    log_cleanup_event "INFO" "[DRY RUN] Would process log file: $log_file" "log_cleanup"
                    ((cleaned_files++))
                else
                    # Create backup
                    create_backup "$backup_name" "$log_file"
                    
                    # Compress and archive the file
                    local archive_path="$BACKUP_DIR/${backup_name}.gz"
                    if gzip -c "$log_file" > "$archive_path" 2>/dev/null; then
                        # Truncate original file (keep it but empty it)
                        > "$log_file"
                        log_cleanup_event "SUCCESS" "Log file archived and truncated: $log_file -> $archive_path" "log_cleanup"
                        ((archived_files++))
                    else
                        log_cleanup_event "ERROR" "Failed to archive log file: $log_file" "log_cleanup"
                    fi
                fi
            fi
        done
    done
    
    log_cleanup_event "SUCCESS" "Log cleanup completed - $archived_files files archived" "log_cleanup"
}

function cleanup_temp_files() {
    log_cleanup_event "INFO" "Starting temporary file cleanup (threshold: ${STALE_TEMP_HOURS}h)" "temp_cleanup"
    
    # Define temporary directories and patterns
    local temp_locations=(
        "$PROJECT_ROOT/hpc/experiments/temp"
        "$PROJECT_ROOT/tools/hpc/.tmp"
        "$HOME/.claude/.tmp"
        "$GLOBTIM_DIR/node_experiments/outputs/*/temp"
    )
    
    local temp_patterns=(
        "*.tmp"
        "*.temp" 
        "*_temp_*"
        "tmpfile_*"
        "julia_temp_*"
    )
    
    local cleaned_count=0
    local threshold_timestamp=$(date -d "$STALE_TEMP_HOURS hours ago" +%s)
    
    for temp_location in "${temp_locations[@]}"; do
        if [[ "$temp_location" == *"*"* ]]; then
            # Handle glob patterns
            for actual_dir in $temp_location; do
                if [[ -d "$actual_dir" ]]; then
                    process_temp_directory "$actual_dir" "$threshold_timestamp"
                fi
            done
        elif [[ -d "$temp_location" ]]; then
            process_temp_directory "$temp_location" "$threshold_timestamp"
        fi
    done
    
    log_cleanup_event "SUCCESS" "Temporary file cleanup completed - $cleaned_count files processed" "temp_cleanup"
}

function process_temp_directory() {
    local temp_dir="$1"
    local threshold_timestamp="$2"
    
    log_cleanup_event "INFO" "Processing temp directory: $temp_dir" "temp_cleanup"
    
    # Find old temporary files
    find "$temp_dir" -type f -name "*.tmp" -o -name "*.temp" -o -name "*_temp_*" | while read -r temp_file; do
        local file_mtime=$(stat -f%m "$temp_file" 2>/dev/null || echo "0")
        
        if [[ $file_mtime -lt $threshold_timestamp ]]; then
            local age_hours=$(( ($(date +%s) - file_mtime) / 3600 ))
            
            if [[ "$DRY_RUN" == true ]]; then
                log_cleanup_event "INFO" "[DRY RUN] Would delete temp file: $temp_file (age: ${age_hours}h)" "temp_cleanup"
            else
                if rm "$temp_file" 2>/dev/null; then
                    log_cleanup_event "SUCCESS" "Deleted temp file: $temp_file (age: ${age_hours}h)" "temp_cleanup"
                else
                    log_cleanup_event "ERROR" "Failed to delete temp file: $temp_file" "temp_cleanup"
                fi
            fi
        fi
    done
    
    # Clean up empty temp directories
    if [[ "$DRY_RUN" == false ]]; then
        find "$temp_dir" -type d -empty -delete 2>/dev/null || true
    fi
}

function cleanup_failed_experiments() {
    log_cleanup_event "INFO" "Starting failed experiment cleanup" "failed_experiments"
    
    local experiment_dirs=(
        "$GLOBTIM_DIR/hpc_results"
        "$GLOBTIM_DIR/node_experiments/outputs"
    )
    
    local cleaned_count=0
    
    for experiment_dir in "${experiment_dirs[@]}"; do
        if [[ ! -d "$experiment_dir" ]]; then
            continue
        fi
        
        log_cleanup_event "INFO" "Checking experiment directory: $experiment_dir" "failed_experiments"
        
        # Look for experiment directories that indicate failure
        find "$experiment_dir" -type d -name "globtim_*" | while read -r exp_dir; do
            local is_failed=false
            local failure_reason=""
            
            # Check for error indicators
            if [[ -f "$exp_dir/error.log" && -s "$exp_dir/error.log" ]]; then
                is_failed=true
                failure_reason="error.log present"
            fi
            
            # Check for empty or minimal output
            local output_files=$(find "$exp_dir" -name "*.csv" -o -name "*.json" -o -name "*.jld2" | wc -l)
            if [[ $output_files -eq 0 ]]; then
                local dir_age_hours=$(( ($(date +%s) - $(stat -f%m "$exp_dir" 2>/dev/null || echo "0")) / 3600 ))
                if [[ $dir_age_hours -gt 6 ]]; then  # No output after 6 hours likely indicates failure
                    is_failed=true
                    failure_reason="${failure_reason:+$failure_reason, }no output files after ${dir_age_hours}h"
                fi
            fi
            
            # Check for Julia crash indicators
            if grep -r "signal\|segfault\|OutOfMemoryError\|killed" "$exp_dir"/*.log 2>/dev/null >/dev/null; then
                is_failed=true
                failure_reason="${failure_reason:+$failure_reason, }Julia crash detected"
            fi
            
            if [[ "$is_failed" == true ]]; then
                log_cleanup_event "WARNING" "Found failed experiment: $(basename "$exp_dir") ($failure_reason)" "failed_experiments"
                
                # Confirmation check
                if [[ "$INTERACTIVE" == true && "$FORCE" == false && "$DRY_RUN" == false ]]; then
                    echo -e "${YELLOW}⚠️  Failed experiment found: $(basename "$exp_dir")${NC}"
                    echo "   Reason: $failure_reason"
                    read -p "Delete this failed experiment? [y/N]: " confirm
                    
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        log_cleanup_event "INFO" "User skipped cleanup of experiment: $(basename "$exp_dir")" "failed_experiments"
                        continue
                    fi
                fi
                
                # Create backup before deletion
                local backup_name="failed_$(basename "$exp_dir")"
                create_backup "$backup_name" "$exp_dir"
                
                # Perform cleanup
                if [[ "$DRY_RUN" == true ]]; then
                    log_cleanup_event "INFO" "[DRY RUN] Would delete failed experiment: $exp_dir" "failed_experiments"
                    ((cleaned_count++))
                else
                    if rm -rf "$exp_dir" 2>/dev/null; then
                        log_cleanup_event "SUCCESS" "Deleted failed experiment: $exp_dir" "failed_experiments"
                        ((cleaned_count++))
                    else
                        log_cleanup_event "ERROR" "Failed to delete experiment directory: $exp_dir" "failed_experiments"
                    fi
                fi
            fi
        done
    done
    
    log_cleanup_event "SUCCESS" "Failed experiment cleanup completed - $cleaned_count experiments processed" "failed_experiments"
}

function organize_results() {
    log_cleanup_event "INFO" "Starting experiment results organization" "organize_results"
    
    local results_dir="$GLOBTIM_DIR/hpc_results"
    local organized_dir="$GLOBTIM_DIR/hpc_results/organized"
    
    if [[ ! -d "$results_dir" ]]; then
        log_cleanup_event "WARNING" "Results directory not found: $results_dir" "organize_results"
        return 1
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$organized_dir"/{by_date,by_type,by_status}
    fi
    
    local organized_count=0
    
    # Find experiment directories
    find "$results_dir" -maxdepth 1 -type d -name "globtim_*" | while read -r exp_dir; do
        local exp_name=$(basename "$exp_dir")
        
        # Extract date from experiment name (format: globtim_type_YYYYMMDD_HHMMSS)
        local exp_date=""
        if [[ "$exp_name" =~ globtim_.*_([0-9]{8})_[0-9]{6} ]]; then
            exp_date="${BASH_REMATCH[1]}"
        fi
        
        # Extract experiment type
        local exp_type=""
        if [[ "$exp_name" =~ globtim_([^_]+)_ ]]; then
            exp_type="${BASH_REMATCH[1]}"
        fi
        
        # Determine experiment status
        local exp_status="unknown"
        if [[ -f "$exp_dir/success.marker" || -f "$exp_dir/completed.json" ]]; then
            exp_status="completed"
        elif [[ -f "$exp_dir/error.log" && -s "$exp_dir/error.log" ]]; then
            exp_status="failed"
        elif find "$exp_dir" -name "*.csv" -o -name "*.json" | grep -q .; then
            exp_status="partial"
        else
            exp_status="empty"
        fi
        
        log_cleanup_event "INFO" "Processing experiment: $exp_name (type: $exp_type, date: $exp_date, status: $exp_status)" "organize_results"
        
        if [[ "$DRY_RUN" == true ]]; then
            log_cleanup_event "INFO" "[DRY RUN] Would organize experiment: $exp_name" "organize_results"
            ((organized_count++))
        else
            # Create organization structure
            if [[ -n "$exp_date" ]]; then
                local year="${exp_date:0:4}"
                local month="${exp_date:4:2}"
                mkdir -p "$organized_dir/by_date/$year/$month"
                
                # Create symlinks for organization (don't move original files)
                ln -sf "$(realpath "$exp_dir")" "$organized_dir/by_date/$year/$month/$(basename "$exp_dir")" 2>/dev/null || true
            fi
            
            if [[ -n "$exp_type" ]]; then
                mkdir -p "$organized_dir/by_type/$exp_type"
                ln -sf "$(realpath "$exp_dir")" "$organized_dir/by_type/$exp_type/$(basename "$exp_dir")" 2>/dev/null || true
            fi
            
            mkdir -p "$organized_dir/by_status/$exp_status"
            ln -sf "$(realpath "$exp_dir")" "$organized_dir/by_status/$exp_status/$(basename "$exp_dir")" 2>/dev/null || true
            
            ((organized_count++))
        fi
    done
    
    log_cleanup_event "SUCCESS" "Results organization completed - $organized_count experiments processed" "organize_results"
}

function disk_space_cleanup() {
    log_cleanup_event "INFO" "Starting comprehensive disk space cleanup" "disk_space"
    
    echo -e "${YELLOW}🚨 Emergency Disk Space Cleanup${NC}"
    
    # Check current disk usage
    local disk_usage
    disk_usage=$(df . | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
    
    echo "Current disk usage: ${disk_usage}%"
    log_cleanup_event "INFO" "Starting disk cleanup with current usage: ${disk_usage}%" "disk_space"
    
    if [[ $disk_usage -lt 80 && "$FORCE" == false ]]; then
        echo -e "${GREEN}✅ Disk usage is acceptable (${disk_usage}%), cleanup not needed${NC}"
        return 0
    fi
    
    # Run all cleanup actions in aggressive mode
    log_cleanup_event "WARNING" "Running comprehensive cleanup due to high disk usage" "disk_space"
    
    # Temporarily set aggressive thresholds
    local original_stale_hours=$STALE_SESSION_HOURS
    local original_log_days=$STALE_LOG_DAYS
    local original_temp_hours=$STALE_TEMP_HOURS
    
    STALE_SESSION_HOURS=24     # More aggressive
    STALE_LOG_DAYS=7          # More aggressive  
    STALE_TEMP_HOURS=12       # More aggressive
    
    # Run all cleanup functions
    cleanup_stale_sessions
    cleanup_log_files
    cleanup_temp_files
    cleanup_failed_experiments
    
    # Restore original thresholds
    STALE_SESSION_HOURS=$original_stale_hours
    STALE_LOG_DAYS=$original_log_days
    STALE_TEMP_HOURS=$original_temp_hours
    
    # Check disk usage again
    local new_disk_usage
    new_disk_usage=$(df . | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
    local freed_space=$((disk_usage - new_disk_usage))
    
    log_cleanup_event "SUCCESS" "Disk space cleanup completed - freed ${freed_space}% space (${disk_usage}% -> ${new_disk_usage}%)" "disk_space"
    echo -e "${GREEN}✅ Cleanup completed. Freed ${freed_space}% disk space${NC}"
}

function main() {
    # Parse command line arguments
    local actions=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stale-sessions)
                actions+=("stale_sessions")
                shift
                ;;
            --log-rotation)
                actions+=("log_rotation")
                shift
                ;;
            --temp-files)
                actions+=("temp_files")
                shift
                ;;
            --failed-experiments)
                actions+=("failed_experiments")
                shift
                ;;
            --organize-results)
                actions+=("organize_results")
                shift
                ;;
            --full-cleanup)
                actions+=("stale_sessions" "log_rotation" "temp_files" "failed_experiments")
                shift
                ;;
            --disk-space)
                actions+=("disk_space")
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                INTERACTIVE=false
                shift
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --stale-hours)
                STALE_SESSION_HOURS="$2"
                shift 2
                ;;
            --log-days)
                STALE_LOG_DAYS="$2"
                shift 2
                ;;
            --temp-hours)
                STALE_TEMP_HOURS="$2"
                shift 2
                ;;
            --max-log-mb)
                MAX_LOG_SIZE_MB="$2"
                shift 2
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
    
    # Default to showing help if no actions specified
    if [[ ${#actions[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No cleanup actions specified${NC}"
        usage
        exit 1
    fi
    
    # Ensure log directory exists
    mkdir -p "$CLEANUP_LOG_DIR"
    
    # Check system resources first
    echo -e "${BLUE}🔍 System Resource Check${NC}"
    local resource_check
    resource_check=$(check_system_resources)
    echo "$resource_check"
    
    # Log startup
    log_cleanup_event "INFO" "Auto cleanup started with actions: ${actions[*]}" "startup"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}🧪 DRY RUN MODE - No actual changes will be made${NC}"
    fi
    
    if [[ "$FORCE" == true ]]; then
        echo -e "${RED}⚠️  FORCE MODE - Skipping confirmations${NC}"
    fi
    
    # Execute requested actions
    for action in "${actions[@]}"; do
        case "$action" in
            "stale_sessions")
                cleanup_stale_sessions
                ;;
            "log_rotation")
                cleanup_log_files
                ;;
            "temp_files")
                cleanup_temp_files
                ;;
            "failed_experiments")
                cleanup_failed_experiments
                ;;
            "organize_results")
                organize_results
                ;;
            "disk_space")
                disk_space_cleanup
                ;;
            *)
                log_cleanup_event "ERROR" "Unknown action: $action" "error"
                ;;
        esac
        
        echo ""  # Add spacing between actions
    done
    
    log_cleanup_event "SUCCESS" "Auto cleanup completed successfully" "completion"
    echo -e "${GREEN}✅ Cleanup operations completed${NC}"
    
    if [[ "$BACKUP_ENABLED" == true && -d "$BACKUP_DIR" ]]; then
        local backup_count=$(find "$BACKUP_DIR" -type f | wc -l)
        echo -e "${BLUE}📦 Backups created: $backup_count files in $BACKUP_DIR${NC}"
    fi
}

# Execute main function
main "$@"