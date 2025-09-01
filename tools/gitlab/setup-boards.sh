#!/bin/bash
"""
GitLab Boards Setup and Management Script

Helps set up and manage GitLab project boards for sprint management.
Provides utilities for board configuration and issue organization.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env.gitlab.local" 2>/dev/null || source "$SCRIPT_DIR/../../.env.gitlab" 2>/dev/null || true

# Use secure API wrapper
GITLAB_API="$SCRIPT_DIR/gitlab-api.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if secure API wrapper is available
check_api_access() {
    if [[ ! -f "$GITLAB_API" ]]; then
        log_error "Secure API wrapper not found. Run tools/gitlab/setup-secure-config.sh"
        exit 1
    fi
    
    # Test API access
    if ! $GITLAB_API GET "/projects/$GITLAB_PROJECT_ID" >/dev/null 2>&1; then
        log_error "GitLab API access failed. Check your token and configuration."
        exit 1
    fi
    
    log_success "GitLab API access confirmed"
}

# List existing boards
list_boards() {
    log_info "Listing existing project boards..."
    
    BOARDS=$($GITLAB_API GET "/projects/$GITLAB_PROJECT_ID/boards")
    
    if [[ $(echo "$BOARDS" | jq 'length') -eq 0 ]]; then
        log_warning "No boards found. Use 'create-boards' to set up project boards."
        return
    fi
    
    echo "$BOARDS" | jq -r '.[] | "Board ID: \(.id) | Name: \(.name) | Lists: \(.lists | length)"'
}

# Get board configuration recommendations
show_board_config() {
    log_info "Recommended board configuration for Globtim project:"
    echo ""
    
    echo "📋 Development Workflow Board"
    echo "  Purpose: Daily task management"
    echo "  Lists needed:"
    echo "    - Backlog (status::backlog)"
    echo "    - Ready (status::ready)"
    echo "    - In Progress (status::in-progress)"
    echo "    - Review (status::review)"
    echo "    - Testing (status::testing)"
    echo "    - Done (status::done)"
    echo "    - Blocked (status::blocked)"
    echo ""
    
    echo "🎯 Epic Progress Board"
    echo "  Purpose: Strategic project tracking"
    echo "  Lists needed:"
    echo "    - Mathematical Core (epic::mathematical-core)"
    echo "    - Test Framework (epic::test-framework)"
    echo "    - Performance (epic::performance)"
    echo "    - Documentation (epic::documentation)"
    echo "    - HPC Deployment (epic::hpc-deployment)"
    echo "    - Visualization (epic::visualization)"
    echo "    - Advanced Features (epic::advanced-features)"
    echo ""
    
    echo "⚡ Priority Focus Board"
    echo "  Purpose: Urgency-based prioritization"
    echo "  Lists needed:"
    echo "    - Critical (Priority::Critical)"
    echo "    - High (Priority::High)"
    echo "    - Medium (Priority::Medium)"
    echo "    - Low (Priority::Low)"
    echo ""
}

# Check current issues and their labels
analyze_issues() {
    log_info "Analyzing current issues for board readiness..."
    
    ISSUES=$($GITLAB_API GET "/projects/$GITLAB_PROJECT_ID/issues?state=opened&per_page=100")
    TOTAL_ISSUES=$(echo "$ISSUES" | jq 'length')
    
    log_info "Found $TOTAL_ISSUES open issues"
    
    # Check status label coverage
    STATUS_LABELED=$(echo "$ISSUES" | jq '[.[] | select(.labels[] | startswith("status::"))] | length')
    PRIORITY_LABELED=$(echo "$ISSUES" | jq '[.[] | select(.labels[] | startswith("Priority::"))] | length')
    EPIC_LABELED=$(echo "$ISSUES" | jq '[.[] | select(.labels[] | startswith("epic::"))] | length')
    
    echo ""
    echo "Label Coverage Analysis:"
    echo "  Status labels: $STATUS_LABELED/$TOTAL_ISSUES ($(( STATUS_LABELED * 100 / TOTAL_ISSUES ))%)"
    echo "  Priority labels: $PRIORITY_LABELED/$TOTAL_ISSUES ($(( PRIORITY_LABELED * 100 / TOTAL_ISSUES ))%)"
    echo "  Epic labels: $EPIC_LABELED/$TOTAL_ISSUES ($(( EPIC_LABELED * 100 / TOTAL_ISSUES ))%)"
    
    if [[ $STATUS_LABELED -lt $TOTAL_ISSUES ]]; then
        log_warning "Some issues missing status labels - boards may not show all issues"
    fi
    
    if [[ $PRIORITY_LABELED -lt $TOTAL_ISSUES ]]; then
        log_warning "Some issues missing priority labels - priority board may be incomplete"
    fi
    
    # Show issues by current status
    echo ""
    echo "Issues by Status:"
    echo "$ISSUES" | jq -r '
        group_by(.labels[] | select(startswith("status::"))) |
        map({
            status: (.[0].labels[] | select(startswith("status::")) | split("::")[1] // "unlabeled"),
            count: length,
            issues: map("#\(.iid): \(.title)")
        }) |
        .[] | "  \(.status): \(.count) issues"
    '
}

# Generate board URLs
show_board_urls() {
    log_info "GitLab Board URLs:"
    echo ""
    echo "🔗 Board Access Links:"
    echo "  Project Boards: https://git.mpi-cbg.de/scholten/globtim/-/boards"
    echo "  Create New Board: https://git.mpi-cbg.de/scholten/globtim/-/boards/new"
    echo ""
    echo "📋 Recommended Board Names:"
    echo "  1. Development Workflow"
    echo "  2. Epic Progress"
    echo "  3. Priority Focus"
    echo ""
    echo "💡 After creating boards, update the URLs in:"
    echo "  - docs/project-management/gitlab-boards-guide.md"
    echo "  - docs/project-management/boards-quick-reference.md"
}

# Validate board setup
validate_boards() {
    log_info "Validating board setup..."
    
    # This would need to be expanded with actual board validation
    # For now, just check if we can access the boards endpoint
    
    BOARDS=$($GITLAB_API GET "/projects/$GITLAB_PROJECT_ID/boards")
    BOARD_COUNT=$(echo "$BOARDS" | jq 'length')
    
    if [[ $BOARD_COUNT -eq 0 ]]; then
        log_warning "No boards found. Create boards using GitLab web interface."
        return 1
    elif [[ $BOARD_COUNT -lt 3 ]]; then
        log_warning "Only $BOARD_COUNT boards found. Recommended: 3 boards (Development, Epic, Priority)"
        return 1
    else
        log_success "Found $BOARD_COUNT boards - good coverage"
        return 0
    fi
}

# Show board creation instructions
show_creation_guide() {
    echo "📋 Board Creation Guide"
    echo "======================"
    echo ""
    echo "Since GitLab boards must be created through the web interface,"
    echo "follow these steps:"
    echo ""
    echo "1. 🌐 Open GitLab Boards:"
    echo "   https://git.mpi-cbg.de/scholten/globtim/-/boards"
    echo ""
    echo "2. 📋 Create Development Workflow Board:"
    echo "   - Click 'Create new board'"
    echo "   - Name: 'Development Workflow'"
    echo "   - Add lists for each status label:"
    echo "     * Backlog (status::backlog)"
    echo "     * Ready (status::ready)"
    echo "     * In Progress (status::in-progress)"
    echo "     * Review (status::review)"
    echo "     * Testing (status::testing)"
    echo "     * Done (status::done)"
    echo "     * Blocked (status::blocked)"
    echo ""
    echo "3. 🎯 Create Epic Progress Board:"
    echo "   - Click 'Create new board'"
    echo "   - Name: 'Epic Progress'"
    echo "   - Add lists for each epic label:"
    echo "     * Mathematical Core (epic::mathematical-core)"
    echo "     * Test Framework (epic::test-framework)"
    echo "     * Performance (epic::performance)"
    echo "     * Documentation (epic::documentation)"
    echo "     * HPC Deployment (epic::hpc-deployment)"
    echo "     * Visualization (epic::visualization)"
    echo "     * Advanced Features (epic::advanced-features)"
    echo ""
    echo "4. ⚡ Create Priority Focus Board:"
    echo "   - Click 'Create new board'"
    echo "   - Name: 'Priority Focus'"
    echo "   - Add lists for each priority label:"
    echo "     * Critical (Priority::Critical)"
    echo "     * High (Priority::High)"
    echo "     * Medium (Priority::Medium)"
    echo "     * Low (Priority::Low)"
    echo ""
    echo "5. ✅ Verify Setup:"
    echo "   ./tools/gitlab/setup-boards.sh validate"
    echo ""
}

# Display usage
usage() {
    echo "GitLab Boards Setup and Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  list            List existing boards"
    echo "  analyze         Analyze issues for board readiness"
    echo "  config          Show recommended board configuration"
    echo "  urls            Show board URLs and access links"
    echo "  create-guide    Show step-by-step board creation guide"
    echo "  validate        Validate current board setup"
    echo "  help            Show this help message"
    echo ""
    echo "This script helps set up and manage GitLab project boards."
    echo "Boards must be created through GitLab web interface."
}

# Main execution
main() {
    case "${1:-help}" in
        list)
            check_api_access
            list_boards
            ;;
        analyze)
            check_api_access
            analyze_issues
            ;;
        config)
            show_board_config
            ;;
        urls)
            show_board_urls
            ;;
        create-guide)
            show_creation_guide
            ;;
        validate)
            check_api_access
            validate_boards
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

# Run main function
main "$@"
