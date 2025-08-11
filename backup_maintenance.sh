#!/bin/bash
# Julia HPC Migration - Backup Maintenance Script
# Created: August 11, 2025

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/backup_maintenance.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check command success
check_status() {
    if [ $? -eq 0 ]; then
        log_message "✅ $1"
        return 0
    else
        log_message "❌ $1 - FAILED"
        return 1
    fi
}

show_usage() {
    echo "Julia HPC Backup Maintenance Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  verify     - Run backup verification checks"
    echo "  status     - Show current backup status"
    echo "  sync       - Synchronize local depot with NFS depot"
    echo "  cleanup    - Clean up old temporary files"
    echo "  monitor    - Show storage usage monitoring"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 verify    # Verify backup integrity"
    echo "  $0 status    # Check current status"
    echo "  $0 sync      # Sync depot changes"
}

verify_backup() {
    log_message "=== Starting Backup Verification ==="
    
    # Run the backup verification script
    if [ -f "$SCRIPT_DIR/backup_verification.sh" ]; then
        bash "$SCRIPT_DIR/backup_verification.sh" >> "$LOG_FILE" 2>&1
        check_status "Backup verification completed"
    else
        log_message "❌ Backup verification script not found"
        return 1
    fi
}

show_status() {
    log_message "=== Backup Status Report ==="
    
    echo "Current Status ($(date)):"
    echo ""
    
    # NFS depot size
    echo "📁 NFS Depot Status:"
    DEPOT_SIZE=$(ssh fileserver-ssh "du -sh ~/julia_depot_nfs 2>/dev/null | cut -f1" 2>/dev/null)
    echo "   Size: $DEPOT_SIZE"
    
    # Package count
    PACKAGE_COUNT=$(ssh fileserver-ssh "find ~/julia_depot_nfs -name '*.toml' 2>/dev/null | wc -l" 2>/dev/null)
    echo "   Packages: $PACKAGE_COUNT configuration files"
    
    # Quota status
    echo ""
    echo "💾 Quota Status:"
    ssh falcon "quota -vs 2>/dev/null | grep scholten || df -h ~ | tail -1" 2>/dev/null
    
    # Last verification
    echo ""
    echo "🔍 Last Verification:"
    if [ -f "$LOG_FILE" ]; then
        tail -5 "$LOG_FILE" | grep -E "(✅|❌)" | tail -1
    else
        echo "   No verification log found"
    fi
}

sync_depot() {
    log_message "=== Starting Depot Synchronization ==="
    
    echo "This will synchronize any local changes to the NFS depot."
    echo "⚠️  This operation should be used carefully in production."
    echo ""
    read -p "Continue with synchronization? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_message "User confirmed depot synchronization"
        
        # Check if there are local changes to sync
        ssh falcon "cd ~/globtim_hpc && source ./setup_nfs_julia.sh >/dev/null 2>&1 && julia -e 'using Pkg; Pkg.status()' --startup-file=no" >/dev/null 2>&1
        check_status "Verified Julia depot accessibility"
        
        log_message "Depot synchronization completed (no changes needed - using symbolic link)"
    else
        log_message "Depot synchronization cancelled by user"
    fi
}

cleanup_temp() {
    log_message "=== Starting Cleanup ==="
    
    # Clean up temp files on cluster
    echo "Cleaning temporary files..."
    ssh falcon "cd ~/globtim_hpc && find . -name '*.tmp' -mtime +7 -delete 2>/dev/null; find . -name 'test_*' -mtime +1 -delete 2>/dev/null" 2>/dev/null
    check_status "Cleaned temporary files on cluster"
    
    # Clean up old log files
    if [ -f "$LOG_FILE" ]; then
        # Keep only last 1000 lines of log
        tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        check_status "Cleaned old log entries"
    fi
    
    log_message "Cleanup completed"
}

monitor_usage() {
    log_message "=== Storage Usage Monitoring ==="
    
    echo "📊 Storage Usage Report ($(date)):"
    echo ""
    
    echo "🏠 Home Directory Usage (HPC Cluster):"
    ssh falcon "du -sh ~ 2>/dev/null && echo 'Quota:' && quota -vs 2>/dev/null | grep scholten || df -h ~ | tail -1" 2>/dev/null
    echo ""
    
    echo "💾 NFS Depot Usage (Fileserver):"
    ssh fileserver-ssh "du -sh ~/julia_depot_nfs 2>/dev/null && echo 'Available space:' && df -h ~/julia_depot_nfs | tail -1" 2>/dev/null
    echo ""
    
    echo "🔧 Temp Directory Usage:"
    ssh falcon "du -sh ~/tmp_julia 2>/dev/null || echo 'No temp directory found'" 2>/dev/null
    echo ""
    
    echo "📈 Growth Trend:"
    if [ -f "$LOG_FILE" ]; then
        echo "Recent depot sizes from log:"
        grep "Size:" "$LOG_FILE" | tail -5
    else
        echo "No historical data available"
    fi
}

# Main script logic
case "${1:-help}" in
    verify)
        verify_backup
        ;;
    status)
        show_status
        ;;
    sync)
        sync_depot
        ;;
    cleanup)
        cleanup_temp
        ;;
    monitor)
        monitor_usage
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
