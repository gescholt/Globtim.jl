#!/bin/bash
"""
GitLab Task Migration Script

Complete workflow for migrating local tasks to GitLab issues.
Handles extraction, conversion, and bulk creation with proper error handling.
"""

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
TASKS_FILE="$SCRIPT_DIR/extracted_tasks.json"
REPORT_FILE="$SCRIPT_DIR/migration_report.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check required Python packages
    python3 -c "import requests" 2>/dev/null || {
        log_error "Python 'requests' package is required. Install with: pip install requests"
        exit 1
    }
    
    # Check configuration file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Copy config.json.template to config.json and fill in your GitLab details"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Extract tasks from repository
extract_tasks() {
    log_info "Extracting tasks from repository..."
    
    cd "$REPO_ROOT"
    python3 "$SCRIPT_DIR/task_extractor.py" \
        --repo-root "$REPO_ROOT" \
        --output "$TASKS_FILE" \
        --summary
        
    if [[ $? -eq 0 ]]; then
        log_success "Task extraction completed"
        log_info "Tasks saved to: $TASKS_FILE"
    else
        log_error "Task extraction failed"
        exit 1
    fi
}

# Validate extracted tasks
validate_tasks() {
    log_info "Validating extracted tasks..."
    
    if [[ ! -f "$TASKS_FILE" ]]; then
        log_error "Tasks file not found: $TASKS_FILE"
        exit 1
    fi
    
    # Check if file is valid JSON
    python3 -c "import json; json.load(open('$TASKS_FILE'))" 2>/dev/null || {
        log_error "Invalid JSON in tasks file: $TASKS_FILE"
        exit 1
    }
    
    # Count tasks
    TASK_COUNT=$(python3 -c "import json; print(len(json.load(open('$TASKS_FILE'))))")
    log_success "Validation passed: $TASK_COUNT tasks ready for migration"
}

# Perform dry run
dry_run() {
    log_info "Performing dry run migration..."
    
    python3 "$SCRIPT_DIR/gitlab_manager.py" \
        --config "$CONFIG_FILE" \
        --tasks "$TASKS_FILE" \
        --dry-run \
        --report "$REPORT_FILE.dry-run"
        
    if [[ $? -eq 0 ]]; then
        log_success "Dry run completed successfully"
        log_info "Review the dry run report: $REPORT_FILE.dry-run"
    else
        log_error "Dry run failed"
        exit 1
    fi
}

# Perform actual migration
migrate_tasks() {
    log_info "Starting actual migration to GitLab..."
    log_warning "This will create real GitLab issues. Continue? (y/N)"
    
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Migration cancelled by user"
        exit 0
    fi
    
    python3 "$SCRIPT_DIR/gitlab_manager.py" \
        --config "$CONFIG_FILE" \
        --tasks "$TASKS_FILE" \
        --report "$REPORT_FILE"
        
    if [[ $? -eq 0 ]]; then
        log_success "Migration completed successfully"
        log_info "Migration report: $REPORT_FILE"
    else
        log_error "Migration failed"
        exit 1
    fi
}

# Clean up temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Archive the tasks file with timestamp
    if [[ -f "$TASKS_FILE" ]]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        ARCHIVE_FILE="$SCRIPT_DIR/extracted_tasks_$TIMESTAMP.json"
        mv "$TASKS_FILE" "$ARCHIVE_FILE"
        log_info "Tasks file archived as: $ARCHIVE_FILE"
    fi
}

# Display usage information
usage() {
    echo "GitLab Task Migration Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  extract     Extract tasks from repository"
    echo "  validate    Validate extracted tasks"
    echo "  dry-run     Perform dry run migration"
    echo "  migrate     Perform actual migration"
    echo "  full        Run complete migration workflow"
    echo "  cleanup     Clean up temporary files"
    echo "  help        Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Copy config.json.template to config.json and fill in your GitLab details"
    echo ""
    echo "Examples:"
    echo "  $0 full                    # Complete migration workflow"
    echo "  $0 extract && $0 dry-run   # Extract and test without creating issues"
}

# Main execution
main() {
    case "${1:-help}" in
        extract)
            check_prerequisites
            extract_tasks
            ;;
        validate)
            validate_tasks
            ;;
        dry-run)
            check_prerequisites
            validate_tasks
            dry_run
            ;;
        migrate)
            check_prerequisites
            validate_tasks
            migrate_tasks
            ;;
        full)
            check_prerequisites
            extract_tasks
            validate_tasks
            dry_run
            
            log_info "Dry run completed. Review the results above."
            log_warning "Proceed with actual migration? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                migrate_tasks
            else
                log_info "Migration cancelled. You can run '$0 migrate' later."
            fi
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
