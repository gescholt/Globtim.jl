#!/bin/bash
"""
Install Git Hooks for GitLab Issue Sync

Sets up automatic synchronization between Git commits and GitLab issues.
Creates hooks that update issue status based on commit messages.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in a Git repository
check_git_repo() {
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        echo "Error: Not in a Git repository"
        exit 1
    fi
    log_info "Git repository detected: $REPO_ROOT"
}

# Create post-commit hook
create_post_commit_hook() {
    local hook_file="$HOOKS_DIR/post-commit"
    
    log_info "Creating post-commit hook..."
    
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# GitLab Issue Sync - Post-commit Hook
# Automatically updates GitLab issues based on commit messages

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/gitlab"
CONFIG_FILE="$SCRIPT_DIR/config.json"

# Check if sync is enabled and configured
if [[ ! -f "$CONFIG_FILE" ]]; then
    # Silently skip if not configured
    exit 0
fi

# Check if Python and required modules are available
if ! command -v python3 &> /dev/null; then
    exit 0
fi

# Check if sync script exists
if [[ ! -f "$SCRIPT_DIR/task_sync.py" ]]; then
    exit 0
fi

# Run sync in background to avoid slowing down commits
(
    cd "$(git rev-parse --show-toplevel)"
    python3 "$SCRIPT_DIR/task_sync.py" --config "$CONFIG_FILE" sync-commit 2>/dev/null || true
) &

# Don't wait for background process
exit 0
EOF

    chmod +x "$hook_file"
    log_success "Post-commit hook created: $hook_file"
}

# Create prepare-commit-msg hook
create_prepare_commit_msg_hook() {
    local hook_file="$HOOKS_DIR/prepare-commit-msg"
    
    log_info "Creating prepare-commit-msg hook..."
    
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# GitLab Issue Sync - Prepare Commit Message Hook
# Automatically adds issue references to commit messages based on branch name

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only modify message for regular commits (not merges, etc.)
if [[ "$COMMIT_SOURCE" != "" ]]; then
    exit 0
fi

# Get current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Extract issue number from branch name (e.g., issue-123-feature-name)
if [[ "$BRANCH_NAME" =~ issue[_-]([0-9]+) ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
    
    # Check if issue reference is already in commit message
    if ! grep -q "#$ISSUE_NUM" "$COMMIT_MSG_FILE"; then
        # Add issue reference to commit message
        echo "" >> "$COMMIT_MSG_FILE"
        echo "Refs #$ISSUE_NUM" >> "$COMMIT_MSG_FILE"
    fi
fi

exit 0
EOF

    chmod +x "$hook_file"
    log_success "Prepare-commit-msg hook created: $hook_file"
}

# Create commit-msg hook for validation
create_commit_msg_hook() {
    local hook_file="$HOOKS_DIR/commit-msg"
    
    log_info "Creating commit-msg hook..."
    
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# GitLab Issue Sync - Commit Message Hook
# Validates commit messages and provides helpful feedback

COMMIT_MSG_FILE=$1

# Read commit message
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Check for issue references
if echo "$COMMIT_MSG" | grep -q "#[0-9]\+"; then
    # Found issue reference - provide helpful feedback
    ISSUE_REFS=$(echo "$COMMIT_MSG" | grep -o "#[0-9]\+" | tr '\n' ' ')
    echo "✅ Commit references GitLab issues: $ISSUE_REFS"
    
    # Check for closing keywords
    if echo "$COMMIT_MSG" | grep -qi "\(closes\|fixes\|resolves\) #[0-9]\+"; then
        echo "🎯 This commit will close/resolve issues automatically"
    fi
fi

exit 0
EOF

    chmod +x "$hook_file"
    log_success "Commit-msg hook created: $hook_file"
}

# Backup existing hooks
backup_existing_hooks() {
    local hooks=("post-commit" "prepare-commit-msg" "commit-msg")
    local backup_dir="$HOOKS_DIR/backup-$(date +%Y%m%d_%H%M%S)"
    
    local has_existing=false
    for hook in "${hooks[@]}"; do
        if [[ -f "$HOOKS_DIR/$hook" ]]; then
            if [[ ! $has_existing ]]; then
                mkdir -p "$backup_dir"
                log_warning "Backing up existing hooks to: $backup_dir"
                has_existing=true
            fi
            cp "$HOOKS_DIR/$hook" "$backup_dir/"
            log_info "Backed up: $hook"
        fi
    done
}

# Install all hooks
install_hooks() {
    log_info "Installing GitLab issue sync hooks..."
    
    # Create hooks directory if it doesn't exist
    mkdir -p "$HOOKS_DIR"
    
    # Backup existing hooks
    backup_existing_hooks
    
    # Create new hooks
    create_post_commit_hook
    create_prepare_commit_msg_hook
    create_commit_msg_hook
    
    log_success "All hooks installed successfully!"
}

# Uninstall hooks
uninstall_hooks() {
    local hooks=("post-commit" "prepare-commit-msg" "commit-msg")
    
    log_info "Uninstalling GitLab issue sync hooks..."
    
    for hook in "${hooks[@]}"; do
        local hook_file="$HOOKS_DIR/$hook"
        if [[ -f "$hook_file" ]] && grep -q "GitLab Issue Sync" "$hook_file"; then
            rm "$hook_file"
            log_info "Removed: $hook"
        fi
    done
    
    log_success "Hooks uninstalled"
}

# Show hook status
show_status() {
    local hooks=("post-commit" "prepare-commit-msg" "commit-msg")
    
    echo "GitLab Issue Sync Hook Status"
    echo "=============================="
    echo ""
    
    for hook in "${hooks[@]}"; do
        local hook_file="$HOOKS_DIR/$hook"
        if [[ -f "$hook_file" ]]; then
            if grep -q "GitLab Issue Sync" "$hook_file"; then
                echo "✅ $hook: Installed"
            else
                echo "⚠️  $hook: Exists (not GitLab sync)"
            fi
        else
            echo "❌ $hook: Not installed"
        fi
    done
    
    echo ""
    
    # Check configuration
    local config_file="$SCRIPT_DIR/config.json"
    if [[ -f "$config_file" ]]; then
        echo "✅ Configuration: Found ($config_file)"
    else
        echo "❌ Configuration: Missing ($config_file)"
        echo "   Run: cp $SCRIPT_DIR/config.json.template $config_file"
    fi
}

# Display usage
usage() {
    echo "GitLab Issue Sync Hook Installer"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install     Install GitLab issue sync hooks"
    echo "  uninstall   Remove GitLab issue sync hooks"
    echo "  status      Show current hook status"
    echo "  help        Show this help message"
    echo ""
    echo "The hooks will:"
    echo "  - Automatically reference issues in commit messages based on branch names"
    echo "  - Update GitLab issue status when commits reference them"
    echo "  - Provide helpful feedback about issue references"
    echo ""
    echo "Example workflow:"
    echo "  1. Create branch: git checkout -b issue-123-fix-bug"
    echo "  2. Make commits: git commit -m 'Fix memory leak'"
    echo "     → Automatically adds 'Refs #123' to commit message"
    echo "  3. Final commit: git commit -m 'Complete fix, closes #123'"
    echo "     → Automatically updates GitLab issue status"
}

# Main execution
main() {
    case "${1:-help}" in
        install)
            check_git_repo
            install_hooks
            echo ""
            echo "🎉 GitLab issue sync hooks are now installed!"
            echo ""
            echo "Next steps:"
            echo "1. Configure GitLab access: cp $SCRIPT_DIR/config.json.template $SCRIPT_DIR/config.json"
            echo "2. Edit config.json with your GitLab project ID and access token"
            echo "3. Create branches with issue numbers: git checkout -b issue-123-feature-name"
            echo "4. Commit normally - hooks will handle GitLab sync automatically"
            ;;
        uninstall)
            check_git_repo
            uninstall_hooks
            ;;
        status)
            check_git_repo
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
