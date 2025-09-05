#!/bin/bash
# Claude Code Agent GitLab API Wrapper
# Provides non-interactive GitLab API access for Claude Code agents
# Prevents VSCode password dialogs and authentication prompts

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITLAB_PROJECT_ID="2545"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[GITLAB-API]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

# Get GitLab token using non-interactive method
get_gitlab_token() {
    local token
    
    # Try non-interactive token retrieval
    if token=$("$SCRIPT_DIR/get-token-noninteractive.sh" 2>/dev/null); then
        echo "$token"
        return 0
    fi
    
    # Fallback: try environment variable
    if [ -n "$GITLAB_PRIVATE_TOKEN" ]; then
        echo "$GITLAB_PRIVATE_TOKEN"
        return 0
    fi
    
    error "No GitLab token available. Set up authentication with:"
    error "  1. Run: $SCRIPT_DIR/setup-secure-config.sh"
    error "  2. Or set: export GITLAB_PRIVATE_TOKEN=your-token"
    return 1
}

# Make GitLab API call
gitlab_api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    local token
    if ! token=$(get_gitlab_token); then
        return 1
    fi
    
    local base_url="https://git.mpi-cbg.de/api/v4"
    local full_url="$base_url/$endpoint"
    
    log "Making $method request to: $endpoint"
    
    if [ "$method" = "GET" ]; then
        curl -s --header "PRIVATE-TOKEN: $token" "$full_url"
    elif [ "$method" = "POST" ]; then
        curl -s --header "PRIVATE-TOKEN: $token" \
             --header "Content-Type: application/json" \
             --data "$data" \
             "$full_url"
    elif [ "$method" = "PUT" ]; then
        curl -s --header "PRIVATE-TOKEN: $token" \
             --header "Content-Type: application/json" \
             --data "$data" \
             --request PUT \
             "$full_url"
    else
        error "Unsupported HTTP method: $method"
        return 1
    fi
}

# Create GitLab issue
create_issue() {
    local title="$1"
    local description="$2"
    local labels="$3"
    local milestone_id="$4"
    
    local issue_data=$(cat <<EOF
{
    "title": "$title",
    "description": "$description",
    "labels": "$labels"$([ -n "$milestone_id" ] && echo ", \"milestone_id\": $milestone_id" || echo "")
}
EOF
    )
    
    log "Creating GitLab issue: $title"
    gitlab_api "POST" "projects/$GITLAB_PROJECT_ID/issues" "$issue_data"
}

# Update GitLab issue
update_issue() {
    local issue_iid="$1"
    local title="$2"
    local description="$3"
    local labels="$4"
    local state_event="$5"
    
    local update_data=$(cat <<EOF
{$([ -n "$title" ] && echo "\"title\": \"$title\",")
$([ -n "$description" ] && echo "\"description\": \"$description\",")
$([ -n "$labels" ] && echo "\"labels\": \"$labels\",")
$([ -n "$state_event" ] && echo "\"state_event\": \"$state_event\"")}
EOF
    )
    
    # Clean up trailing commas
    update_data=$(echo "$update_data" | sed 's/,}/}/' | sed 's/,$//')
    
    log "Updating GitLab issue #$issue_iid"
    gitlab_api "PUT" "projects/$GITLAB_PROJECT_ID/issues/$issue_iid" "$update_data"
}

# List GitLab issues
list_issues() {
    local state="${1:-opened}"
    local labels="$2"
    
    local query_params="state=$state"
    if [ -n "$labels" ]; then
        query_params="${query_params}&labels=$labels"
    fi
    
    log "Listing GitLab issues (state: $state)"
    gitlab_api "GET" "projects/$GITLAB_PROJECT_ID/issues?$query_params"
}

# Get GitLab milestones
list_milestones() {
    local state="${1:-active}"
    
    log "Listing GitLab milestones (state: $state)"
    gitlab_api "GET" "projects/$GITLAB_PROJECT_ID/milestones?state=$state"
}

# Get project labels
list_labels() {
    log "Listing GitLab labels"
    gitlab_api "GET" "projects/$GITLAB_PROJECT_ID/labels"
}

# Get specific GitLab issue
get_issue() {
    local issue_iid="$1"
    
    if [ -z "$issue_iid" ]; then
        error "Issue ID is required"
        return 1
    fi
    
    log "Getting GitLab issue #$issue_iid"
    gitlab_api "GET" "projects/$GITLAB_PROJECT_ID/issues/$issue_iid"
}

# Test GitLab API connectivity
test_connection() {
    log "Testing GitLab API connection..."
    
    if gitlab_api "GET" "projects/$GITLAB_PROJECT_ID" >/dev/null; then
        log "✅ GitLab API connection successful"
        return 0
    else
        error "❌ GitLab API connection failed"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
Claude Code Agent GitLab API Wrapper
===================================

Non-interactive GitLab API access for Claude Code agents.
Prevents VSCode password dialogs and authentication prompts.

Usage: $0 <command> [options]

Commands:
  test                          - Test GitLab API connection
  get-issue <iid>               - Get specific issue by ID
  list-issues [state] [labels]  - List issues (state: opened|closed|all)
  list-milestones [state]       - List milestones (state: active|closed|all)  
  list-labels                   - List project labels
  create-issue <title> <desc> [labels] [milestone_id] - Create new issue
  update-issue <iid> [title] [desc] [labels] [state] - Update existing issue

Examples:
  $0 test
  $0 get-issue 15
  $0 list-issues opened
  $0 create-issue "Fix authentication" "Resolve GitLab auth issues" "type::bug,priority::high"
  $0 update-issue 30 "" "" "" "close"

Environment:
  GITLAB_PRIVATE_TOKEN - GitLab API token (alternative to .gitlab_config)
  
Authentication:
  Uses non-interactive token retrieval from .gitlab_config file or environment variable.
  No interactive prompts or VSCode dialogs will appear.
EOF
}

# Main command dispatcher
case "${1:-help}" in
    test)
        test_connection
        ;;
    get-issue)
        if [ $# -lt 2 ]; then
            error "Usage: $0 get-issue <issue_iid>"
            exit 1
        fi
        get_issue "$2"
        ;;
    list-issues)
        list_issues "$2" "$3"
        ;;
    list-milestones)
        list_milestones "$2"
        ;;
    list-labels)
        list_labels
        ;;
    create-issue)
        if [ $# -lt 3 ]; then
            error "Usage: $0 create-issue <title> <description> [labels] [milestone_id]"
            exit 1
        fi
        create_issue "$2" "$3" "$4" "$5"
        ;;
    update-issue)
        if [ $# -lt 2 ]; then
            error "Usage: $0 update-issue <issue_iid> [title] [description] [labels] [state_event]"
            exit 1
        fi
        update_issue "$2" "$3" "$4" "$5" "$6"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac