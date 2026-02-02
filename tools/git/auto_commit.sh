#!/bin/bash
# Auto-commit Script (Issue #140 Phase 2)
#
# Automatically commits and optionally pushes changes when threshold is met.
# Based on .claude/hooks/git-auto-commit-push.md converted to executable script.
#
# Usage:
#   ./auto_commit.sh [OPTIONS]
#
# Options:
#   --threshold N     Commit if N or more files modified (default: 5)
#   --no-push         Commit but don't push to remote
#   --dry-run         Show what would be done without executing
#   -h, --help        Show this help message
#
# Examples:
#   # Auto-commit if 5+ files modified (default):
#   ./auto_commit.sh
#
#   # Custom threshold:
#   ./auto_commit.sh --threshold 10
#
#   # Commit without pushing:
#   ./auto_commit.sh --no-push
#
#   # Preview actions:
#   ./auto_commit.sh --dry-run

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

THRESHOLD=5
PUSH=true
DRY_RUN=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Usage Function
# ============================================================================

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Auto-commit script that commits changes when a threshold of modified files is
reached. Optionally pushes to remote repository.

Options:
  --threshold N     Commit if N or more files modified (default: 5)
  --no-push         Commit but don't push to remote
  --dry-run         Show what would be done without executing
  -h, --help        Show this help message

Examples:
  # Auto-commit if 5+ files modified (default):
  $(basename "$0")

  # Custom threshold (commit if 10+ files):
  $(basename "$0") --threshold 10

  # Commit without pushing:
  $(basename "$0") --no-push

  # Preview what would happen:
  $(basename "$0") --dry-run

Workflow:
  1. Check if in git repository (exit cleanly if not)
  2. Check for uncommitted changes
  3. Count modified/new files
  4. If count >= threshold: commit (and optionally push)
  5. Otherwise: exit cleanly

See also:
  - .claude/hooks/git-auto-commit-push.md
  - Issue #140 Phase 2: Git Workflow Integration
EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            --threshold)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --threshold requires a number"
                    exit 1
                fi
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    echo "ERROR: Invalid threshold value: $2 (must be a number)"
                    exit 1
                fi
                THRESHOLD="$2"
                shift 2
                ;;
            --no-push)
                PUSH=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# ============================================================================
# Git Functions
# ============================================================================

check_git_repository() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        # Not an error - just exit cleanly
        exit 0
    fi
}

get_git_status() {
    git status --porcelain
}

count_modified_files() {
    local git_status="$1"
    echo "$git_status" | wc -l | tr -d ' '
}

stage_all_changes() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: git add -A"
    else
        git add -A
    fi
}

create_commit() {
    local file_count="$1"

    local commit_msg
    commit_msg=$(cat <<EOF
chore: Auto-commit of development progress

🔄 Changes Summary:
- $file_count files modified/added
- Auto-committed when threshold ($THRESHOLD files) was reached

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would commit with message:"
        echo "$commit_msg"
    else
        git commit -m "$commit_msg"
        log_success "Committed $file_count files"
    fi
}

push_to_remote() {
    if [[ "$PUSH" == "false" ]]; then
        log_info "Skipping push (--no-push flag set)"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: git push"
    else
        # Check if we have a remote to push to
        if git remote get-url origin > /dev/null 2>&1; then
            git push
            log_success "Pushed to remote"
        else
            log_warning "No remote 'origin' configured - skipping push"
        fi
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # Parse arguments
    parse_arguments "$@"

    # Check if in git repository (exits cleanly if not)
    check_git_repository

    # Get git status
    git_status=$(get_git_status)

    # Exit cleanly if no changes
    if [[ -z "$git_status" ]]; then
        exit 0  # No changes to commit
    fi

    # Count modified/new files
    file_count=$(count_modified_files "$git_status")

    # Check if threshold is met
    if [[ "$file_count" -ge "$THRESHOLD" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Threshold met: $file_count files >= $THRESHOLD"
        else
            log_info "Auto-commit threshold met: $file_count files >= $THRESHOLD"
        fi

        # Stage all changes
        stage_all_changes

        # Create commit
        create_commit "$file_count"

        # Push to remote (if enabled)
        push_to_remote

        if [[ "$DRY_RUN" == "false" ]]; then
            log_success "✅ Auto-committed and pushed $file_count files"
        fi
    else
        # Below threshold - exit cleanly
        exit 0
    fi
}

# Run main function
main "$@"
