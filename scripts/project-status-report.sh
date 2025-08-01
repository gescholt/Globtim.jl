#!/bin/bash
# Enhanced Project Status Report Generator
# Generates comprehensive project status including features, epics, and roadmap progress

source .env.gitlab 2>/dev/null || {
    echo "Error: .env.gitlab not found. Please set up GitLab environment variables."
    exit 1
}

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Unicode symbols
CHECK="✅"
PROGRESS="🔄"
PLANNED="📋"
WARNING="⚠️"
TARGET="🎯"
ROCKET="🚀"

echo -e "${BOLD}${CYAN}📊 Globtim Project Status Report${NC}"
echo "========================================"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Project Overview
echo -e "${BOLD}${BLUE}🎯 Project Overview${NC}"
echo "─────────────────────"

# Get total issues and recent activity
TOTAL_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?per_page=1" -I | \
    grep -i x-total | cut -d' ' -f2 | tr -d '\r')

OPEN_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?state=opened&per_page=1" -I | \
    grep -i x-total | cut -d' ' -f2 | tr -d '\r')

CLOSED_ISSUES=$((TOTAL_ISSUES - OPEN_ISSUES))

echo "Total Issues: $TOTAL_ISSUES"
echo "Open Issues: $OPEN_ISSUES"
echo "Closed Issues: $CLOSED_ISSUES"

if [ $TOTAL_ISSUES -gt 0 ]; then
    COMPLETION_RATE=$(( (CLOSED_ISSUES * 100) / TOTAL_ISSUES ))
    echo "Overall Completion: ${COMPLETION_RATE}%"
fi

echo

# Epic Progress Analysis
echo -e "${BOLD}${PURPLE}📈 Epic Progress Analysis${NC}"
echo "──────────────────────────"

# Define epics with their expected features
declare -A EPICS
EPICS["epic::mathematical-core"]="Mathematical Core Development"
EPICS["epic::test-framework"]="Test Framework Development"
EPICS["epic::julia-optimization"]="Julia Optimization"
EPICS["epic::documentation"]="Documentation & User Experience"
EPICS["epic::advanced-features"]="Advanced Features"

for epic_label in "${!EPICS[@]}"; do
    epic_name="${EPICS[$epic_label]}"
    
    # Get total issues with this epic label
    total=$(curl -s "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=$epic_label&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" | jq '. | length')
    
    # Get completed issues
    done=$(curl -s "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=$epic_label&state=closed&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" | jq '. | length')
    
    # Get in-progress issues
    in_progress=$(curl -s "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=$epic_label,status::in-progress&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" | jq '. | length')
    
    # Calculate percentage
    if [ "$total" -gt 0 ]; then
        percentage=$((done * 100 / total))
        
        # Determine status symbol
        if [ $percentage -ge 75 ]; then
            status_symbol="$CHECK"
            status_color="$GREEN"
        elif [ $percentage -ge 25 ]; then
            status_symbol="$PROGRESS"
            status_color="$YELLOW"
        else
            status_symbol="$PLANNED"
            status_color="$RED"
        fi
        
        echo -e "${status_color}${status_symbol} ${epic_name}${NC}"
        echo "   Progress: ${percentage}% (${done}/${total} complete, ${in_progress} in progress)"
    else
        echo -e "${RED}${PLANNED} ${epic_name}${NC}"
        echo "   Progress: No issues found"
    fi
    echo
done

# Current Sprint Status
echo -e "${BOLD}${GREEN}🏃‍♂️ Current Sprint Status${NC}"
echo "─────────────────────────"

if [ -n "$CURRENT_MILESTONE_ID" ]; then
    # Get current milestone details
    MILESTONE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID")
    
    TITLE=$(echo "$MILESTONE" | jq -r '.title')
    START_DATE=$(echo "$MILESTONE" | jq -r '.start_date')
    DUE_DATE=$(echo "$MILESTONE" | jq -r '.due_date')
    STATE=$(echo "$MILESTONE" | jq -r '.state')
    
    echo "Sprint: $TITLE"
    echo "Period: $START_DATE → $DUE_DATE"
    echo "Status: $STATE"
    
    # Get sprint issues
    SPRINT_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID/issues?per_page=100")
    
    SPRINT_OPEN=$(echo "$SPRINT_ISSUES" | jq '[.[] | select(.state=="opened")] | length')
    SPRINT_CLOSED=$(echo "$SPRINT_ISSUES" | jq '[.[] | select(.state=="closed")] | length')
    SPRINT_TOTAL=$(echo "$SPRINT_ISSUES" | jq 'length')
    
    if [ $SPRINT_TOTAL -gt 0 ]; then
        SPRINT_PROGRESS=$(( (SPRINT_CLOSED * 100) / SPRINT_TOTAL ))
        echo "Progress: ${SPRINT_PROGRESS}% (${SPRINT_CLOSED}/${SPRINT_TOTAL} complete)"
        
        # Progress bar
        BAR_LENGTH=20
        FILLED_LENGTH=$(( (SPRINT_PROGRESS * BAR_LENGTH) / 100 ))
        EMPTY_LENGTH=$(( BAR_LENGTH - FILLED_LENGTH ))
        
        echo -n "["
        for i in $(seq 1 $FILLED_LENGTH); do echo -n "█"; done
        for i in $(seq 1 $EMPTY_LENGTH); do echo -n "░"; done
        echo "]"
    fi
else
    echo "No current milestone configured"
fi

echo

# Feature Status Summary
echo -e "${BOLD}${CYAN}🚀 Feature Status Summary${NC}"
echo "─────────────────────────"

echo -e "${GREEN}${CHECK} Production Ready Features:${NC}"
echo "  • AdaptivePrecision System - Hybrid precision computation"
echo "  • L2 Norm Analysis Framework - Comprehensive error analysis"
echo "  • Anisotropic Grid Support - Multi-resolution grids"
echo "  • Polynomial System Solving - Critical point analysis"
echo

echo -e "${YELLOW}${PROGRESS} Active Development:${NC}"
echo "  • 4D Testing Framework - High-dimensional problem testing"
echo "  • Enhanced Analysis Tools - Advanced mathematical analysis"
echo "  • Visualization & Plotting - Enhanced plotting capabilities"
echo

echo -e "${RED}${PLANNED} Planned Features:${NC}"
echo "  • Advanced Grid Structures - Sparse and adaptive grids"
echo "  • Performance Optimization - Parallel processing enhancements"
echo "  • Extended Integration - Multiple solver backends"
echo

# Recent Activity
echo -e "${BOLD}${BLUE}📊 Recent Activity${NC}"
echo "─────────────────"

# Get recent issues (last 7 days)
WEEK_AGO=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
RECENT_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?created_after=${WEEK_AGO}T00:00:00Z&per_page=10")

RECENT_COUNT=$(echo "$RECENT_ISSUES" | jq 'length')
echo "New Issues (Last 7 days): $RECENT_COUNT"

if [ $RECENT_COUNT -gt 0 ]; then
    echo "Recent Issues:"
    echo "$RECENT_ISSUES" | jq -r '.[] | "  • #\(.iid): \(.title)"' | head -5
    if [ $RECENT_COUNT -gt 5 ]; then
        echo "  ... and $((RECENT_COUNT - 5)) more"
    fi
fi

echo

# Quality Metrics
echo -e "${BOLD}${PURPLE}🔍 Quality Metrics${NC}"
echo "─────────────────"

# Count issues by type
BUG_COUNT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Type::Bug&state=opened&per_page=100" | jq 'length')

FEATURE_COUNT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Type::Feature&state=opened&per_page=100" | jq 'length')

TEST_COUNT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Type::Test&state=opened&per_page=100" | jq 'length')

DOC_COUNT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Type::Documentation&state=opened&per_page=100" | jq 'length')

echo "Open Bugs: $BUG_COUNT"
echo "Open Features: $FEATURE_COUNT"
echo "Open Tests: $TEST_COUNT"
echo "Open Documentation: $DOC_COUNT"

# Calculate quality ratio
TOTAL_OPEN_TYPED=$((BUG_COUNT + FEATURE_COUNT + TEST_COUNT + DOC_COUNT))
if [ $TOTAL_OPEN_TYPED -gt 0 ]; then
    BUG_RATIO=$(( (BUG_COUNT * 100) / TOTAL_OPEN_TYPED ))
    echo "Bug Ratio: ${BUG_RATIO}%"
    
    if [ $BUG_RATIO -lt 20 ]; then
        echo -e "${GREEN}${CHECK} Good bug ratio${NC}"
    elif [ $BUG_RATIO -lt 40 ]; then
        echo -e "${YELLOW}${WARNING} Moderate bug ratio${NC}"
    else
        echo -e "${RED}${WARNING} High bug ratio - focus on quality${NC}"
    fi
fi

echo

# Next Steps and Recommendations
echo -e "${BOLD}${TARGET} Next Steps & Recommendations${NC}"
echo "────────────────────────────────"

# Analyze current state and provide recommendations
if [ $BUG_COUNT -gt 5 ]; then
    echo -e "${RED}• Priority: Address open bugs (${BUG_COUNT} open)${NC}"
fi

if [ $SPRINT_PROGRESS -lt 50 ] 2>/dev/null; then
    echo -e "${YELLOW}• Focus: Sprint progress is behind (${SPRINT_PROGRESS}%)${NC}"
fi

echo -e "${BLUE}• Continue: 4D testing framework development${NC}"
echo -e "${BLUE}• Enhance: Visualization and plotting capabilities${NC}"
echo -e "${BLUE}• Plan: Advanced grid structures for Q4 2024${NC}"

echo

# Quick Actions
echo -e "${BOLD}⚡ Quick Actions${NC}"
echo "───────────────"
echo "• View detailed sprint: ./scripts/sprint-dashboard.sh"
echo "• Check epic progress: ./scripts/epic-progress.sh"
echo "• Explore project: ./scripts/gitlab-explore.sh"
echo "• Update project docs: Edit wiki/Planning/ files"

echo
echo -e "${BOLD}Report generated successfully!${NC}"
