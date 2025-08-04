#!/bin/bash
# Comprehensive Project Dashboard - One-stop view of project status
# Combines sprint, epic, and feature status with actionable insights

source .env.gitlab 2>/dev/null || {
    echo "Error: .env.gitlab not found. Please set up GitLab environment variables."
    echo "Run: cp .env.gitlab.example .env.gitlab and configure your settings"
    exit 1
}

# ANSI color codes and symbols
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

CHECK="✅"
PROGRESS="🔄"
PLANNED="📋"
WARNING="⚠️"
TARGET="🎯"
ROCKET="🚀"
CHART="📊"
CLOCK="⏰"

clear
echo -e "${BOLD}${CYAN}${ROCKET} Globtim Project Dashboard${NC}"
echo "══════════════════════════════════════════"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Quick Health Check
echo -e "${BOLD}${CHART} Project Health Overview${NC}"
echo "─────────────────────────────"

# Get basic project metrics
TOTAL_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?per_page=1" -I | \
    grep -i x-total | cut -d' ' -f2 | tr -d '\r' 2>/dev/null || echo "0")

OPEN_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?state=opened&per_page=1" -I | \
    grep -i x-total | cut -d' ' -f2 | tr -d '\r' 2>/dev/null || echo "0")

CLOSED_ISSUES=$((TOTAL_ISSUES - OPEN_ISSUES))

if [ $TOTAL_ISSUES -gt 0 ]; then
    COMPLETION_RATE=$(( (CLOSED_ISSUES * 100) / TOTAL_ISSUES ))
    
    if [ $COMPLETION_RATE -ge 75 ]; then
        health_color="$GREEN"
        health_symbol="$CHECK"
        health_status="Excellent"
    elif [ $COMPLETION_RATE -ge 50 ]; then
        health_color="$YELLOW"
        health_symbol="$PROGRESS"
        health_status="Good"
    else
        health_color="$RED"
        health_symbol="$WARNING"
        health_status="Needs Attention"
    fi
    
    echo -e "${health_color}${health_symbol} Overall Health: ${health_status} (${COMPLETION_RATE}% complete)${NC}"
else
    echo -e "${RED}${WARNING} No issues found - project may need setup${NC}"
fi

echo "Total Issues: $TOTAL_ISSUES | Open: $OPEN_ISSUES | Closed: $CLOSED_ISSUES"
echo

# Current Sprint Status (Compact)
echo -e "${BOLD}${CLOCK} Current Sprint${NC}"
echo "─────────────────"

if [ -n "$CURRENT_MILESTONE_ID" ]; then
    MILESTONE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID" 2>/dev/null)
    
    if [ "$MILESTONE" != "null" ] && [ -n "$MILESTONE" ]; then
        TITLE=$(echo "$MILESTONE" | jq -r '.title // "Unknown"')
        DUE_DATE=$(echo "$MILESTONE" | jq -r '.due_date // "No due date"')
        
        SPRINT_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
            "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID/issues?per_page=100" 2>/dev/null)
        
        if [ -n "$SPRINT_ISSUES" ]; then
            SPRINT_OPEN=$(echo "$SPRINT_ISSUES" | jq '[.[] | select(.state=="opened")] | length' 2>/dev/null || echo "0")
            SPRINT_CLOSED=$(echo "$SPRINT_ISSUES" | jq '[.[] | select(.state=="closed")] | length' 2>/dev/null || echo "0")
            SPRINT_TOTAL=$(echo "$SPRINT_ISSUES" | jq 'length' 2>/dev/null || echo "0")
            
            if [ $SPRINT_TOTAL -gt 0 ]; then
                SPRINT_PROGRESS=$(( (SPRINT_CLOSED * 100) / SPRINT_TOTAL ))
                echo -e "${PROGRESS} ${TITLE} - ${SPRINT_PROGRESS}% complete (${SPRINT_CLOSED}/${SPRINT_TOTAL})"
                echo "Due: $DUE_DATE"
            else
                echo -e "${PLANNED} ${TITLE} - No issues assigned"
            fi
        else
            echo -e "${WARNING} ${TITLE} - Unable to fetch issues"
        fi
    else
        echo -e "${RED}${WARNING} Milestone not found (ID: $CURRENT_MILESTONE_ID)${NC}"
    fi
else
    echo -e "${RED}${WARNING} No current milestone configured${NC}"
    echo "Set CURRENT_MILESTONE_ID in .env.gitlab"
fi

echo

# Epic Progress (Compact)
echo -e "${BOLD}${TARGET} Epic Progress${NC}"
echo "─────────────────"

# Core epics with simplified status (using arrays for compatibility)
EPIC_LABELS=("epic::mathematical-core" "epic::test-framework" "epic::julia-optimization" "epic::documentation")
EPIC_SHORTS=("Math Core" "Testing" "Optimization" "Documentation")

for i in "${!EPIC_LABELS[@]}"; do
    epic_label="${EPIC_LABELS[$i]}"
    epic_short="${EPIC_SHORTS[$i]}"
    
    total=$(curl -s "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=$epic_label&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    
    done=$(curl -s "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=$epic_label&state=closed&per_page=100" \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$total" -gt 0 ]; then
        percentage=$((done * 100 / total))
        
        if [ $percentage -ge 75 ]; then
            echo -e "${GREEN}${CHECK} ${epic_short}: ${percentage}% (${done}/${total})${NC}"
        elif [ $percentage -ge 25 ]; then
            echo -e "${YELLOW}${PROGRESS} ${epic_short}: ${percentage}% (${done}/${total})${NC}"
        else
            echo -e "${RED}${PLANNED} ${epic_short}: ${percentage}% (${done}/${total})${NC}"
        fi
    else
        echo -e "${RED}${PLANNED} ${epic_short}: No issues${NC}"
    fi
done

echo

# Feature Status
echo -e "${BOLD}${ROCKET} Feature Status${NC}"
echo "─────────────────"

echo -e "${GREEN}${CHECK} Production Ready:${NC}"
echo "  • AdaptivePrecision System | L2 Norm Analysis | Anisotropic Grids"

echo -e "${YELLOW}${PROGRESS} In Development:${NC}"
echo "  • 4D Testing Framework | Enhanced Analysis | Visualization"

echo -e "${RED}${PLANNED} Planned:${NC}"
echo "  • Advanced Grids | Performance Optimization | Extended Integration"

echo

# Priority Issues
echo -e "${BOLD}${WARNING} Priority Issues${NC}"
echo "─────────────────"

CRITICAL_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Priority::Critical&state=opened&per_page=5" 2>/dev/null)

HIGH_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?labels=Priority::High&state=opened&per_page=5" 2>/dev/null)

CRITICAL_COUNT=$(echo "$CRITICAL_ISSUES" | jq 'length' 2>/dev/null || echo "0")
HIGH_COUNT=$(echo "$HIGH_ISSUES" | jq 'length' 2>/dev/null || echo "0")

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo -e "${RED}🔴 Critical Issues: $CRITICAL_COUNT${NC}"
    echo "$CRITICAL_ISSUES" | jq -r '.[] | "  • #\(.iid): \(.title)"' 2>/dev/null | head -3
elif [ $HIGH_COUNT -gt 0 ]; then
    echo -e "${YELLOW}🟡 High Priority Issues: $HIGH_COUNT${NC}"
    echo "$HIGH_ISSUES" | jq -r '.[] | "  • #\(.iid): \(.title)"' 2>/dev/null | head -3
else
    echo -e "${GREEN}${CHECK} No critical or high priority issues${NC}"
fi

echo

# Quick Actions
echo -e "${BOLD}⚡ Quick Actions${NC}"
echo "───────────────"
echo "1. Detailed Sprint: ./scripts/sprint-dashboard.sh"
echo "2. Epic Analysis:   ./scripts/epic-progress.sh"
echo "3. Full Report:     ./scripts/project-status-report.sh"
echo "4. Explore Project: ./scripts/gitlab-explore.sh"
echo "5. Update Docs:     Edit wiki/Planning/ files"

echo

# System Status
echo -e "${BOLD}🔧 System Status${NC}"
echo "───────────────"

# Check if key files exist
if [ -f ".env.gitlab" ]; then
    echo -e "${GREEN}${CHECK} GitLab configuration found${NC}"
else
    echo -e "${RED}${WARNING} GitLab configuration missing${NC}"
fi

if [ -d "wiki/Planning" ]; then
    echo -e "${GREEN}${CHECK} Planning documentation exists${NC}"
else
    echo -e "${RED}${WARNING} Planning documentation missing${NC}"
fi

if [ -f "PROJECT_STATUS_ANALYSIS.md" ]; then
    echo -e "${GREEN}${CHECK} Project analysis available${NC}"
else
    echo -e "${YELLOW}${WARNING} Project analysis not found${NC}"
fi

echo
echo -e "${BOLD}Dashboard refresh: $(date '+%H:%M:%S')${NC}"
echo "Run './scripts/project-dashboard.sh' to refresh"
