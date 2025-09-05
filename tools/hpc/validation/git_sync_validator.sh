#!/bin/bash
# Git Synchronization Validator - Pre-Execution Validation Component
# Part of Issue #27: Implement Pre-Execution Validation Hook System (Component 4/4)
# Validates Git repository synchronization and workspace preparation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function log() {
    echo -e "${GREEN}[GIT-SYNC-VALIDATOR]${NC} $1" >&2
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
Git Synchronization Validator - Pre-Execution Validation
========================================================

Validates Git repository synchronization and workspace state before experiment execution.
Part of Issue #27: Pre-Execution Validation Hook System.

Usage: $0 <command> [options]

Commands:
  validate                      - Complete Git synchronization validation
  status-check                  - Check Git repository status
  sync-check                    - Check synchronization with remote
  branch-check                  - Validate current branch state
  changes-check                 - Check for uncommitted changes
  prepare-workspace            - Prepare workspace for experiment
  help                         - Show this help

Options:
  --allow-dirty                - Allow uncommitted changes (not recommended)
  --skip-fetch                 - Skip fetching from remote (faster but less accurate)
  --target-branch BRANCH       - Target branch to validate against (default: current)
  --workspace-dir DIR          - Workspace directory to prepare (default: PROJECT_ROOT)

Environment Variables:
  GLOBTIM_ALLOW_DIRTY_WORKSPACE - Set to "1" to allow uncommitted changes
  GLOBTIM_SKIP_REMOTE_CHECK     - Set to "1" to skip remote synchronization check

Examples:
  $0 validate                   # Complete validation (recommended)
  $0 status-check               # Quick status check only
  $0 sync-check                 # Check sync with remote
  $0 prepare-workspace          # Prepare experiment workspace
  $0 validate --allow-dirty     # Allow uncommitted changes

Integration:
  Called by robust_experiment_runner.sh during pre-execution validation.
  Ensures experiments run with proper Git state and workspace preparation.
EOF
}

# Check if we're in a Git repository
function validate_git_repo() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        error "Not a Git repository: $PROJECT_ROOT"
        error "Git synchronization validation requires a Git repository"
        return 1
    fi
    
    log "Git repository detected: $PROJECT_ROOT"
    return 0
}

# Get current Git status
function get_git_status() {
    local repo_path="${1:-$PROJECT_ROOT}"
    
    # Change to repository directory
    cd "$repo_path"
    
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    
    local commit_hash
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    local uncommitted_changes=0
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        uncommitted_changes=1
    fi
    
    local untracked_files=0
    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        untracked_files=1
    fi
    
    local staged_changes=0
    if ! git diff-index --quiet --cached HEAD -- 2>/dev/null; then
        staged_changes=1
    fi
    
    echo "$current_branch,$commit_hash,$uncommitted_changes,$untracked_files,$staged_changes"
}

# Check synchronization with remote
function check_remote_sync() {
    local repo_path="${1:-$PROJECT_ROOT}"
    local skip_fetch="${2:-false}"
    
    cd "$repo_path"
    
    # Get current branch
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        warning "In detached HEAD state - cannot check remote synchronization"
        return 0
    fi
    
    # Check if branch has remote tracking
    local remote_branch
    remote_branch=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null || echo "")
    
    if [[ -z "$remote_branch" ]]; then
        warning "Branch '$current_branch' has no upstream remote - skipping remote sync check"
        return 0
    fi
    
    info "Remote tracking branch: $remote_branch"
    
    # Fetch from remote if not skipping
    if [[ "$skip_fetch" != "true" ]]; then
        info "Fetching from remote to check synchronization..."
        if ! git fetch origin 2>/dev/null; then
            warning "Failed to fetch from remote - may indicate network issues"
            warning "Proceeding with local validation only"
            return 0
        fi
    fi
    
    # Check if local branch is up to date
    local local_commit
    local_commit=$(git rev-parse HEAD)
    
    local remote_commit
    remote_commit=$(git rev-parse "$remote_branch" 2>/dev/null || echo "")
    
    if [[ -z "$remote_commit" ]]; then
        warning "Could not get remote commit for $remote_branch"
        return 0
    fi
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        log "Branch '$current_branch' is up to date with '$remote_branch'"
        return 0
    fi
    
    # Check if local is ahead, behind, or diverged
    local ahead
    ahead=$(git rev-list --count "$remote_branch"..HEAD 2>/dev/null || echo "0")
    
    local behind  
    behind=$(git rev-list --count HEAD.."$remote_branch" 2>/dev/null || echo "0")
    
    if [[ $ahead -gt 0 && $behind -eq 0 ]]; then
        warning "Local branch is $ahead commit(s) ahead of remote"
        warning "Consider pushing changes: git push origin $current_branch"
        return 0
    elif [[ $ahead -eq 0 && $behind -gt 0 ]]; then
        error "Local branch is $behind commit(s) behind remote"
        error "Pull required: git pull origin $current_branch"
        return 1
    elif [[ $ahead -gt 0 && $behind -gt 0 ]]; then
        error "Local branch has diverged ($ahead ahead, $behind behind)"
        error "Merge or rebase required before proceeding"
        return 1
    fi
    
    return 0
}

# Validate Git repository status
function validate_git_status() {
    local allow_dirty="${1:-false}"
    local repo_path="${2:-$PROJECT_ROOT}"
    
    if ! validate_git_repo; then
        return 1
    fi
    
    info "Checking Git repository status..."
    
    local status_info
    status_info=$(get_git_status "$repo_path")
    
    local current_branch commit_hash uncommitted_changes untracked_files staged_changes
    IFS=',' read -r current_branch commit_hash uncommitted_changes untracked_files staged_changes <<< "$status_info"
    
    info "Repository Status:"
    info "  Branch: $current_branch"
    info "  Commit: $commit_hash"
    info "  Uncommitted changes: $([ $uncommitted_changes -eq 1 ] && echo "YES" || echo "NO")"
    info "  Untracked files: $([ $untracked_files -eq 1 ] && echo "YES" || echo "NO")"
    info "  Staged changes: $([ $staged_changes -eq 1 ] && echo "YES" || echo "NO")"
    
    local issues_found=false
    
    # Check for uncommitted changes
    if [[ $uncommitted_changes -eq 1 || $staged_changes -eq 1 ]]; then
        if [[ "$allow_dirty" == "true" || "${GLOBTIM_ALLOW_DIRTY_WORKSPACE:-0}" == "1" ]]; then
            warning "Repository has uncommitted changes (allowed by configuration)"
            warning "Experiment results may not be fully reproducible"
        else
            error "Repository has uncommitted changes"
            error "Commit or stash changes before running experiments for reproducibility"
            error "Or use --allow-dirty flag to proceed anyway (not recommended)"
            issues_found=true
        fi
    fi
    
    # Check for untracked files (less critical)
    if [[ $untracked_files -eq 1 ]]; then
        warning "Repository has untracked files"
        warning "Consider adding important files to Git or .gitignore"
        
        # List some untracked files for context
        local untracked_list
        untracked_list=$(cd "$repo_path" && git ls-files --others --exclude-standard | head -5)
        if [[ -n "$untracked_list" ]]; then
            warning "Examples of untracked files:"
            echo "$untracked_list" | while IFS= read -r file; do
                warning "  - $file"
            done
        fi
    fi
    
    if [[ "$issues_found" == "true" ]]; then
        return 1
    else
        log "Git status validation PASSED"
        return 0
    fi
}

# Check current branch state
function validate_branch_state() {
    local target_branch="${1:-}"
    local repo_path="${2:-$PROJECT_ROOT}"
    
    cd "$repo_path"
    
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    info "Current branch: ${current_branch:-'detached HEAD'}"
    
    # If target branch specified, check if we're on it
    if [[ -n "$target_branch" && "$current_branch" != "$target_branch" ]]; then
        error "Not on target branch: current='$current_branch', expected='$target_branch'"
        error "Switch to target branch: git checkout $target_branch"
        return 1
    fi
    
    # Check if we're in a detached HEAD state
    if [[ -z "$current_branch" ]]; then
        warning "Repository is in detached HEAD state"
        warning "Consider checking out a branch for better reproducibility"
        return 0
    fi
    
    log "Branch state validation PASSED"
    return 0
}

# Prepare workspace for experiment execution
function prepare_workspace() {
    local workspace_dir="${1:-$PROJECT_ROOT}"
    
    info "Preparing workspace: $workspace_dir"
    
    # Create necessary directories
    local required_dirs=(
        "$workspace_dir/hpc_results"
        "$workspace_dir/hpc/experiments/temp"
        "$workspace_dir/.cache"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            info "Creating directory: $dir"
            mkdir -p "$dir"
            if [[ $? -ne 0 ]]; then
                error "Failed to create directory: $dir"
                return 1
            fi
        else
            info "Directory exists: $dir"
        fi
    done
    
    # Set proper permissions for experiment directories
    chmod 755 "$workspace_dir/hpc_results" "$workspace_dir/hpc/experiments/temp" 2>/dev/null || true
    
    # Clean up old temporary files (optional)
    local temp_cleanup_age="+7"  # Files older than 7 days
    if [[ -d "$workspace_dir/hpc/experiments/temp" ]]; then
        local old_files
        old_files=$(find "$workspace_dir/hpc/experiments/temp" -name "*.jl" -mtime "$temp_cleanup_age" 2>/dev/null || true)
        if [[ -n "$old_files" ]]; then
            info "Cleaning up old temporary experiment files"
            echo "$old_files" | while IFS= read -r file; do
                rm -f "$file" 2>/dev/null || true
                info "  Removed: $(basename "$file")"
            done
        fi
    fi
    
    # Verify Julia project accessibility
    local project_toml="$workspace_dir/Project.toml"
    if [[ ! -f "$project_toml" ]]; then
        error "Project.toml not found: $project_toml"
        error "Workspace preparation requires a valid Julia project"
        return 1
    fi
    
    log "Workspace preparation COMPLETED"
    return 0
}

# Comprehensive Git synchronization validation
function validate_all_git() {
    local allow_dirty="${1:-false}"
    local skip_fetch="${2:-false}"
    local target_branch="${3:-}"
    local workspace_dir="${4:-$PROJECT_ROOT}"
    
    echo "🔍 Git Synchronization Validation Starting..."
    echo "Repository: $PROJECT_ROOT"
    echo "Workspace: $workspace_dir"
    echo "Options: allow_dirty=$allow_dirty, skip_fetch=$skip_fetch"
    echo "=" * 60
    
    local validation_results=()
    local overall_success=true
    
    # Git status validation
    if validate_git_status "$allow_dirty"; then
        validation_results+=("Repository Status: ✅ PASSED")
    else
        validation_results+=("Repository Status: ❌ FAILED")
        overall_success=false
    fi
    
    # Remote synchronization check
    if [[ "${GLOBTIM_SKIP_REMOTE_CHECK:-0}" == "1" || "$skip_fetch" == "true" ]]; then
        validation_results+=("Remote Sync: ⏭️  SKIPPED")
    else
        if check_remote_sync "$PROJECT_ROOT" "$skip_fetch"; then
            validation_results+=("Remote Sync: ✅ PASSED")
        else
            validation_results+=("Remote Sync: ❌ FAILED")
            overall_success=false
        fi
    fi
    
    # Branch state validation
    if validate_branch_state "$target_branch"; then
        validation_results+=("Branch State: ✅ PASSED")
    else
        validation_results+=("Branch State: ❌ FAILED")
        overall_success=false
    fi
    
    # Workspace preparation
    if prepare_workspace "$workspace_dir"; then
        validation_results+=("Workspace Prep: ✅ PASSED")
    else
        validation_results+=("Workspace Prep: ❌ FAILED")
        overall_success=false
    fi
    
    echo ""
    echo "=" * 60
    echo "📊 Git Synchronization Summary:"
    for result in "${validation_results[@]}"; do
        echo "  $result"
    done
    
    if [[ "$overall_success" == "true" ]]; then
        echo ""
        echo "🎉 Git Synchronization PASSED - Repository ready for experiments"
        return 0
    else
        echo ""
        echo "❌ Git Synchronization FAILED - Address issues before proceeding"
        echo ""
        echo "Common solutions:"
        echo "  - Commit changes: git add -A && git commit -m 'Pre-experiment state'"
        echo "  - Pull updates: git pull origin \$(git branch --show-current)"
        echo "  - Use --allow-dirty to bypass some checks (not recommended)"
        return 1
    fi
}

# Parse command line arguments and execute
function main() {
    local command="${1:-help}"
    local allow_dirty="false"
    local skip_fetch="false"
    local target_branch=""
    local workspace_dir="$PROJECT_ROOT"
    
    # Parse options
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --allow-dirty)
                allow_dirty="true"
                shift
                ;;
            --skip-fetch)
                skip_fetch="true"
                shift
                ;;
            --target-branch)
                target_branch="$2"
                shift 2
                ;;
            --workspace-dir)
                workspace_dir="$2"
                shift 2
                ;;
            *)
                # Assume it's an argument for the command
                break
                ;;
        esac
    done
    
    case "$command" in
        validate)
            validate_all_git "$allow_dirty" "$skip_fetch" "$target_branch" "$workspace_dir"
            ;;
        status-check)
            validate_git_status "$allow_dirty"
            ;;
        sync-check)
            check_remote_sync "$PROJECT_ROOT" "$skip_fetch"
            ;;
        branch-check)
            validate_branch_state "$target_branch"
            ;;
        changes-check)
            validate_git_status "$allow_dirty" | grep -E "(uncommitted|staged|untracked)"
            ;;
        prepare-workspace)
            prepare_workspace "$workspace_dir"
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