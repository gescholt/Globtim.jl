#!/bin/bash
# Sprint Transition Tool - Close current sprint and create next one

source .env.gitlab

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}🔄 Sprint Transition Tool${NC}"
echo "========================"
echo

# Get current milestone
CURRENT=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID")

CURRENT_TITLE=$(echo "$CURRENT" | jq -r '.title')
CURRENT_STATE=$(echo "$CURRENT" | jq -r '.state')

echo -e "${BOLD}Current Sprint:${NC} $CURRENT_TITLE (ID: $CURRENT_MILESTONE_ID)"
echo -e "${BOLD}State:${NC} $CURRENT_STATE"
echo

# Show sprint summary
echo -e "${BOLD}📊 Sprint Summary${NC}"
echo "────────────────"

# Get issues summary
ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID/issues?per_page=100")

CLOSED_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.state=="closed")] | length')
OPEN_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.state=="opened")] | length')
TOTAL_COUNT=$(echo "$ISSUES" | jq 'length')

echo -e "${GREEN}✅ Completed:${NC} $CLOSED_COUNT"
echo -e "${YELLOW}🔄 Remaining:${NC} $OPEN_COUNT"
echo -e "${BLUE}📊 Total:${NC} $TOTAL_COUNT"
echo

if [ $OPEN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Open Issues:${NC}"
    echo "$ISSUES" | jq -r '.[] | select(.state=="opened") | "  - \(.title)"'
    echo
fi

# Ask for confirmation
echo -e "${BOLD}Actions to perform:${NC}"
echo "1. Close current sprint: $CURRENT_TITLE"
echo "2. Move open issues to next sprint"
echo "3. Create new sprint milestone"
echo

read -p "Continue with sprint transition? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Sprint transition cancelled."
    exit 0
fi

# Step 1: Close current milestone
echo
echo -e "${BOLD}📌 Step 1: Closing current sprint...${NC}"
curl -s -X PUT \
    -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"state_event": "close"}' \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID" > /dev/null

echo "✅ Sprint $CURRENT_TITLE closed"

# Step 2: Create new sprint
echo
echo -e "${BOLD}📌 Step 2: Creating new sprint...${NC}"

# Extract sprint number and increment
SPRINT_NUM=$(echo "$CURRENT_TITLE" | grep -oE '[0-9]+-[0-9]+$' | cut -d- -f2)
YEAR=$(date +%Y)
NEW_NUM=$(printf "%02d" $((10#$SPRINT_NUM + 1)))
NEW_TITLE="Sprint $YEAR-$NEW_NUM"

# Calculate dates (2-week sprint)
START_DATE=$(date +%Y-%m-%d)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    END_DATE=$(date -v +14d +%Y-%m-%d)
else
    # Linux
    END_DATE=$(date -d "+14 days" +%Y-%m-%d)
fi

# Create description with carryover information
DESCRIPTION="## Sprint Goals
- [To be defined in sprint planning]

## Carryover from $CURRENT_TITLE
- $OPEN_COUNT issues carried forward

## Focus Areas
1. **Development**: [TBD]
2. **Testing**: [TBD]
3. **Documentation**: [TBD]

## Success Criteria
- All P0/P1 issues resolved
- Tests passing with >80% coverage
- Documentation updated"

# Create new milestone
JSON_PAYLOAD=$(jq -n \
    --arg title "$NEW_TITLE" \
    --arg desc "$DESCRIPTION" \
    --arg start "$START_DATE" \
    --arg due "$END_DATE" \
    '{title: $title, description: $desc, start_date: $start, due_date: $due}')

RESPONSE=$(curl -s -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones")

NEW_MILESTONE_ID=$(echo "$RESPONSE" | jq -r '.id')

if [ -n "$NEW_MILESTONE_ID" ]; then
    echo "✅ Created new sprint: $NEW_TITLE (ID: $NEW_MILESTONE_ID)"
else
    echo "❌ Failed to create new sprint"
    echo "$RESPONSE" | jq .
    exit 1
fi

# Step 3: Move open issues to new sprint
echo
echo -e "${BOLD}📌 Step 3: Moving open issues to new sprint...${NC}"

MOVED_COUNT=0
echo "$ISSUES" | jq -r '.[] | select(.state=="opened") | .iid' | while read -r ISSUE_ID; do
    curl -s -X PUT \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"milestone_id\": $NEW_MILESTONE_ID}" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues/$ISSUE_ID" > /dev/null
    ((MOVED_COUNT++))
    echo -n "."
done
echo
echo "✅ Moved $OPEN_COUNT open issues to $NEW_TITLE"

# Step 4: Update .env.gitlab
echo
echo -e "${BOLD}📌 Step 4: Updating configuration...${NC}"

# Remove old CURRENT_MILESTONE_ID and add new one
grep -v "^export CURRENT_MILESTONE_ID=" .env.gitlab > .env.gitlab.tmp
mv .env.gitlab.tmp .env.gitlab
echo "export CURRENT_MILESTONE_ID=\"$NEW_MILESTONE_ID\"" >> .env.gitlab

echo "✅ Updated CURRENT_MILESTONE_ID in .env.gitlab"

# Show summary
echo
echo -e "${BOLD}✨ Sprint Transition Complete!${NC}"
echo "──────────────────────────────"
echo -e "${GREEN}Old Sprint:${NC} $CURRENT_TITLE (closed)"
echo -e "${BLUE}New Sprint:${NC} $NEW_TITLE (active)"
echo -e "${YELLOW}Issues Moved:${NC} $OPEN_COUNT"
echo
echo "Next steps:"
echo "1. Run sprint planning meeting"
echo "2. Update sprint goals in GitLab"
echo "3. Create new issues for the sprint"
echo "4. Run: ./scripts/sprint-dashboard.sh to view the new sprint"