#!/bin/bash
# Enhanced Epic Progress Tracking with Visual Indicators and Detailed Analysis

source .env.gitlab 2>/dev/null || {
    echo "Error: .env.gitlab not found. Please set up GitLab environment variables."
    exit 1
}

PROJECT_ID="${GITLAB_PROJECT_ID}"
GITLAB_TOKEN="${GITLAB_PRIVATE_TOKEN}"
GITLAB_URL="${GITLAB_API_URL:-https://gitlab.com/api/v4}"

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Unicode symbols
CHECK="✅"
PROGRESS="🔄"
PLANNED="📋"
TARGET="🎯"

# Epic definitions (using arrays instead of associative arrays for compatibility)
EPIC_LABELS=(
    "epic::mathematical-core"
    "epic::test-framework"
    "epic::julia-optimization"
    "epic::documentation"
    "epic::advanced-features"
)

EPIC_NAMES=(
    "Mathematical Core Development"
    "Test Framework Development"
    "Julia Optimization"
    "Documentation & User Experience"
    "Advanced Features"
)

EPIC_DESCRIPTIONS=(
    "Core mathematical computation capabilities"
    "Comprehensive testing infrastructure"
    "Performance and efficiency improvements"
    "User and developer documentation"
    "Next-generation capabilities"
)

EPIC_TARGETS=(
    "4 features"
    "4 features"
    "4 features"
    "4 features"
    "4 features"
)

echo -e "${BOLD}${PURPLE}📈 Epic Progress Report${NC}"
echo "=========================="
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Overall epic summary
total_epics=${#EPIC_LABELS[@]}
completed_epics=0
in_progress_epics=0

for i in "${!EPIC_LABELS[@]}"; do
    epic_label="${EPIC_LABELS[$i]}"

    # Get total issues with this epic label
    total=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get completed issues (closed state)
    done=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&state=closed&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Calculate percentage
    if [ "$total" -gt 0 ]; then
        percentage=$((done * 100 / total))
        if [ $percentage -ge 75 ]; then
            ((completed_epics++))
        elif [ $percentage -ge 25 ]; then
            ((in_progress_epics++))
        fi
    fi
done

echo -e "${BOLD}Epic Overview:${NC}"
echo "Total Epics: $total_epics"
echo "Completed (≥75%): $completed_epics"
echo "In Progress (25-74%): $in_progress_epics"
echo "Planned (<25%): $((total_epics - completed_epics - in_progress_epics))"
echo

# Detailed epic analysis
for i in "${!EPIC_LABELS[@]}"; do
    epic_label="${EPIC_LABELS[$i]}"
    epic_name="${EPIC_NAMES[$i]}"
    epic_desc="${EPIC_DESCRIPTIONS[$i]}"
    epic_target="${EPIC_TARGETS[$i]}"

    echo -e "${BOLD}${TARGET} ${epic_name}${NC}"
    echo "Description: $epic_desc"
    echo "Target: $epic_target"
    echo

    # Get total issues with this epic label
    total=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get completed issues (closed state)
    done=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&state=closed&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get in-progress issues
    in_progress=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label,status::in-progress&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get ready issues
    ready=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label,status::ready&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get backlog issues
    backlog=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label,status::backlog&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Calculate percentage and determine status
    if [ "$total" -gt 0 ]; then
        percentage=$((done * 100 / total))

        if [ $percentage -ge 75 ]; then
            status_symbol="$CHECK"
            status_color="$GREEN"
            status_text="Complete"
        elif [ $percentage -ge 25 ]; then
            status_symbol="$PROGRESS"
            status_color="$YELLOW"
            status_text="In Progress"
        else
            status_symbol="$PLANNED"
            status_color="$RED"
            status_text="Planned"
        fi

        echo -e "${status_color}${status_symbol} Status: ${status_text} (${percentage}%)${NC}"

        # Progress bar
        BAR_LENGTH=30
        FILLED_LENGTH=$(( (percentage * BAR_LENGTH) / 100 ))
        EMPTY_LENGTH=$(( BAR_LENGTH - FILLED_LENGTH ))

        echo -n "Progress: ["
        for i in $(seq 1 $FILLED_LENGTH); do echo -n "█"; done
        for i in $(seq 1 $EMPTY_LENGTH); do echo -n "░"; done
        echo "] ${percentage}%"

        echo "Issues: ${done} complete, ${in_progress} in progress, ${ready} ready, ${backlog} backlog"
        echo "Total: ${total} issues"

        # Show recent activity if any
        if [ $in_progress -gt 0 ]; then
            echo -e "${YELLOW}Active Work:${NC}"
            ACTIVE_ISSUES=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label,status::in-progress&per_page=5" \
                -H "PRIVATE-TOKEN: $GITLAB_TOKEN")
            echo "$ACTIVE_ISSUES" | jq -r '.[] | "  • #\(.iid): \(.title)"' | head -3
            if [ $in_progress -gt 3 ]; then
                echo "  ... and $((in_progress - 3)) more"
            fi
        fi

    else
        echo -e "${RED}${PLANNED} Status: No issues found${NC}"
        echo "Progress: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%"
        echo "Issues: 0 total"
    fi

    echo
    echo "────────────────────────────────────────"
    echo
done

# Summary and recommendations
echo -e "${BOLD}${BLUE}📊 Summary & Recommendations${NC}"
echo "═══════════════════════════════"

# Calculate overall project progress
total_issues=0
total_done=0
total_in_progress=0

for i in "${!EPIC_LABELS[@]}"; do
    epic_label="${EPIC_LABELS[$i]}"
    epic_total=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')
    epic_done=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label&state=closed&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')
    epic_progress=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic_label,status::in-progress&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    total_issues=$((total_issues + epic_total))
    total_done=$((total_done + epic_done))
    total_in_progress=$((total_in_progress + epic_progress))
done

if [ $total_issues -gt 0 ]; then
    overall_percentage=$((total_done * 100 / total_issues))
    echo "Overall Project Progress: ${overall_percentage}% (${total_done}/${total_issues} issues complete)"
    echo "Active Development: ${total_in_progress} issues in progress"
    echo

    # Provide recommendations based on progress
    if [ $overall_percentage -ge 75 ]; then
        echo -e "${GREEN}${CHECK} Project Status: Excellent progress!${NC}"
        echo "Recommendation: Focus on final testing and documentation"
    elif [ $overall_percentage -ge 50 ]; then
        echo -e "${YELLOW}${PROGRESS} Project Status: Good progress${NC}"
        echo "Recommendation: Continue current development pace"
    else
        echo -e "${RED}${PLANNED} Project Status: Early development${NC}"
        echo "Recommendation: Focus on core feature completion"
    fi
else
    echo "No epic issues found. Consider creating issues with epic labels."
fi

echo
echo -e "${BOLD}Next Actions:${NC}"
echo "• Update epic progress in wiki/Planning/EPICS.md"
echo "• Review and prioritize backlog items"
echo "• Consider breaking down large epics into smaller features"
echo "• Schedule epic review meetings for stalled epics"

echo
echo -e "${BOLD}Generated at: $(date)${NC}"
