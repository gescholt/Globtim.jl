#!/bin/bash
# Sprint Management Dashboard for GitLab

source .env.gitlab

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}📊 Sprint Management Dashboard${NC}"
echo "================================"
echo

# Get current milestone details
MILESTONE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID")

TITLE=$(echo "$MILESTONE" | jq -r '.title')
START_DATE=$(echo "$MILESTONE" | jq -r '.start_date')
DUE_DATE=$(echo "$MILESTONE" | jq -r '.due_date')
STATE=$(echo "$MILESTONE" | jq -r '.state')

echo -e "${BOLD}Current Sprint:${NC} $TITLE"
echo -e "${BOLD}Status:${NC} $STATE"
echo -e "${BOLD}Duration:${NC} $START_DATE → $DUE_DATE"

# Calculate days remaining
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DUE_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$DUE_DATE" +%s 2>/dev/null || echo 0)
    NOW_TIMESTAMP=$(date +%s)
    if [ $DUE_TIMESTAMP -ne 0 ]; then
        DAYS_LEFT=$(( (DUE_TIMESTAMP - NOW_TIMESTAMP) / 86400 ))
    else
        DAYS_LEFT=0
    fi
else
    # Linux
    DAYS_LEFT=$(( ($(date -d "$DUE_DATE" +%s) - $(date +%s)) / 86400 ))
fi

if [ $DAYS_LEFT -lt 0 ]; then
    echo -e "${RED}⚠️  Sprint overdue by $((-DAYS_LEFT)) days${NC}"
elif [ $DAYS_LEFT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Sprint ends today!${NC}"
else
    echo -e "${BOLD}Days Remaining:${NC} $DAYS_LEFT"
fi

echo

# Get all issues in milestone
ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID/issues?per_page=100")

# Count by state
OPEN_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.state=="opened")] | length')
CLOSED_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.state=="closed")] | length')
TOTAL_COUNT=$(echo "$ISSUES" | jq 'length')

# Calculate progress
if [ $TOTAL_COUNT -gt 0 ]; then
    PROGRESS=$(( (CLOSED_COUNT * 100) / TOTAL_COUNT ))
else
    PROGRESS=0
fi

echo -e "${BOLD}📈 Sprint Progress${NC}"
echo "─────────────────"

# Progress bar
BAR_LENGTH=30
FILLED_LENGTH=$(( (PROGRESS * BAR_LENGTH) / 100 ))
EMPTY_LENGTH=$(( BAR_LENGTH - FILLED_LENGTH ))

echo -n "["
for i in $(seq 1 $FILLED_LENGTH); do echo -n "█"; done
for i in $(seq 1 $EMPTY_LENGTH); do echo -n "░"; done
echo "] ${PROGRESS}%"

echo
echo -e "${GREEN}✅ Closed:${NC} $CLOSED_COUNT"
echo -e "${YELLOW}🔄 Open:${NC} $OPEN_COUNT"
echo -e "${BLUE}📊 Total:${NC} $TOTAL_COUNT"
echo

# Issues by priority
echo -e "${BOLD}📋 Open Issues by Priority${NC}"
echo "──────────────────────────"

for priority in "Priority::Critical" "Priority::High" "Priority::Medium" "Priority::Low"; do
    COUNT=$(echo "$ISSUES" | jq --arg p "$priority" \
        '[.[] | select(.state=="opened" and (.labels | contains([$p])))] | length')
    if [ $COUNT -gt 0 ]; then
        case $priority in
            "Priority::Critical") echo -e "${RED}🔴 Critical:${NC} $COUNT" ;;
            "Priority::High") echo -e "${YELLOW}🟡 High:${NC} $COUNT" ;;
            "Priority::Medium") echo -e "${BLUE}🔵 Medium:${NC} $COUNT" ;;
            "Priority::Low") echo -e "${GREEN}🟢 Low:${NC} $COUNT" ;;
        esac
    fi
done

echo

# Issues by type
echo -e "${BOLD}📦 Open Issues by Type${NC}"
echo "─────────────────────"

for type in "Type::Bug" "Type::Feature" "Type::Enhancement" "Type::Documentation" "Type::Test"; do
    COUNT=$(echo "$ISSUES" | jq --arg t "$type" \
        '[.[] | select(.state=="opened" and (.labels | contains([$t])))] | length')
    if [ $COUNT -gt 0 ]; then
        TYPE_NAME=$(echo $type | cut -d: -f3)
        echo "$TYPE_NAME: $COUNT"
    fi
done

echo

# Team velocity (if previous sprints exist)
echo -e "${BOLD}📊 Velocity Metrics${NC}"
echo "─────────────────"

# Get last 3 completed milestones
PAST_MILESTONES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones?state=closed&per_page=3" | \
    jq -r '.[] | select(.title | startswith("Sprint"))')

if [ -n "$PAST_MILESTONES" ]; then
    echo "Last 3 Sprints:"
    echo "$PAST_MILESTONES" | jq -r '.title' | while read -r sprint; do
        SPRINT_ID=$(echo "$PAST_MILESTONES" | jq -r --arg s "$sprint" 'select(.title==$s) | .id')
        SPRINT_ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
            "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$SPRINT_ID/issues?state=closed&per_page=100")
        COMPLETED=$(echo "$SPRINT_ISSUES" | jq 'length')
        echo "  $sprint: $COMPLETED issues completed"
    done
else
    echo "No previous sprints found for velocity calculation"
fi

echo

# Upcoming work
echo -e "${BOLD}🎯 Focus Areas${NC}"
echo "─────────────"
echo "$MILESTONE" | jq -r '.description' | grep -A 10 "## Focus Areas" | tail -n +2 | head -n 3

echo

# Quick actions
echo -e "${BOLD}⚡ Quick Actions${NC}"
echo "───────────────"
echo "• View all issues: ./scripts/gitlab-explore.sh | grep -A 50 'Recent Issues'"
echo "• Create new issue: ./scripts/create-sprint-issues.sh"
echo "• Update milestone: Edit CURRENT_MILESTONE_ID in .env.gitlab"
echo "• Close sprint: Mark milestone as closed in GitLab"