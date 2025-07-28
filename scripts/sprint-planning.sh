#!/bin/bash
# Sprint Planning Helper - Analyze backlog and suggest sprint scope

source .env.gitlab

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}📋 Sprint Planning Assistant${NC}"
echo "==========================="
echo

# Get current milestone info
MILESTONE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID")

TITLE=$(echo "$MILESTONE" | jq -r '.title')
START_DATE=$(echo "$MILESTONE" | jq -r '.start_date')
DUE_DATE=$(echo "$MILESTONE" | jq -r '.due_date')

echo -e "${BOLD}Planning for:${NC} $TITLE"
echo -e "${BOLD}Sprint Duration:${NC} $START_DATE → $DUE_DATE (14 days)"
echo

# Get all open issues not in any milestone (backlog)
echo -e "${BOLD}📚 Analyzing Backlog${NC}"
echo "──────────────────"

BACKLOG=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?state=opened&milestone=none&per_page=100")

BACKLOG_COUNT=$(echo "$BACKLOG" | jq 'length')
echo "Total backlog items: $BACKLOG_COUNT"
echo

# Analyze by priority
echo -e "${BOLD}🎯 Priority Breakdown${NC}"
echo "───────────────────"

for priority in "Priority::Critical" "Priority::High" "Priority::Medium" "Priority::Low"; do
    ITEMS=$(echo "$BACKLOG" | jq --arg p "$priority" \
        '[.[] | select(.labels | contains([$p]))]')
    COUNT=$(echo "$ITEMS" | jq 'length')
    
    if [ $COUNT -gt 0 ]; then
        case $priority in
            "Priority::Critical") 
                echo -e "${RED}🔴 Critical ($COUNT):${NC}"
                echo "$ITEMS" | jq -r '.[] | "   - \(.title) (IID: #\(.iid))"'
                ;;
            "Priority::High") 
                echo -e "${YELLOW}🟡 High ($COUNT):${NC}"
                echo "$ITEMS" | jq -r '.[] | "   - \(.title) (IID: #\(.iid))"'
                ;;
            "Priority::Medium") 
                echo -e "${BLUE}🔵 Medium ($COUNT):${NC}"
                if [ $COUNT -le 5 ]; then
                    echo "$ITEMS" | jq -r '.[] | "   - \(.title) (IID: #\(.iid))"'
                else
                    echo "   [Showing first 5 of $COUNT]"
                    echo "$ITEMS" | jq -r '.[] | "   - \(.title) (IID: #\(.iid))"' | head -5
                fi
                ;;
            "Priority::Low") 
                echo -e "${GREEN}🟢 Low:${NC} $COUNT items"
                ;;
        esac
    fi
done

echo

# Effort estimation
echo -e "${BOLD}⏱️  Effort Analysis${NC}"
echo "────────────────"

TOTAL_HOURS=0
for effort in "Effort::XS" "Effort::S" "Effort::M" "Effort::L" "Effort::XL"; do
    ITEMS=$(echo "$BACKLOG" | jq --arg e "$effort" '[.[] | select(.labels | contains([$e]))]')
    COUNT=$(echo "$ITEMS" | jq 'length')
    
    if [ $COUNT -gt 0 ]; then
        case $effort in
            "Effort::XS") 
                HOURS=$((COUNT * 2))  # 1-2 hours avg
                echo "XS (1-2h): $COUNT items ≈ $HOURS hours"
                ;;
            "Effort::S") 
                HOURS=$((COUNT * 3))  # 2-4 hours avg
                echo "S (2-4h): $COUNT items ≈ $HOURS hours"
                ;;
            "Effort::M") 
                HOURS=$((COUNT * 6))  # 4-8 hours avg
                echo "M (4-8h): $COUNT items ≈ $HOURS hours"
                ;;
            "Effort::L") 
                HOURS=$((COUNT * 12)) # 1-2 days avg
                echo "L (1-2d): $COUNT items ≈ $HOURS hours"
                ;;
            "Effort::XL") 
                HOURS=$((COUNT * 24)) # 2-5 days avg
                echo "XL (2-5d): $COUNT items ≈ $HOURS hours"
                ;;
        esac
        TOTAL_HOURS=$((TOTAL_HOURS + HOURS))
    fi
done

echo
echo -e "${BOLD}Total estimated effort:${NC} $TOTAL_HOURS hours"
echo -e "${BOLD}Available sprint capacity:${NC} ~80 hours (10 days × 8h)"
echo

# Suggested sprint scope
echo -e "${BOLD}🎯 Suggested Sprint Scope${NC}"
echo "───────────────────────"

echo "Based on priorities and capacity, consider including:"
echo

# All critical issues
CRITICAL=$(echo "$BACKLOG" | jq '[.[] | select(.labels | contains(["Priority::Critical"]))]')
CRITICAL_COUNT=$(echo "$CRITICAL" | jq 'length')
CRITICAL_HOURS=0

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo -e "${RED}Critical Issues (Must Have):${NC}"
    echo "$CRITICAL" | jq -r '.[] | {title: .title, iid: .iid, effort: (.labels | map(select(startswith("Effort::"))) | .[0] // "Effort::M")} | "  □ #\(.iid): \(.title) [\(.effort)]"'
    
    # Estimate hours for critical
    for effort in "XS" "S" "M" "L" "XL"; do
        COUNT=$(echo "$CRITICAL" | jq --arg e "Effort::$effort" '[.[] | select(.labels | contains([$e]))] | length')
        case $effort in
            "XS") CRITICAL_HOURS=$((CRITICAL_HOURS + COUNT * 2)) ;;
            "S") CRITICAL_HOURS=$((CRITICAL_HOURS + COUNT * 3)) ;;
            "M") CRITICAL_HOURS=$((CRITICAL_HOURS + COUNT * 6)) ;;
            "L") CRITICAL_HOURS=$((CRITICAL_HOURS + COUNT * 12)) ;;
            "XL") CRITICAL_HOURS=$((CRITICAL_HOURS + COUNT * 24)) ;;
        esac
    done
    echo
fi

# High priority issues that fit
HIGH=$(echo "$BACKLOG" | jq '[.[] | select(.labels | contains(["Priority::High"]))]')
HIGH_COUNT=$(echo "$HIGH" | jq 'length')

if [ $HIGH_COUNT -gt 0 ] && [ $CRITICAL_HOURS -lt 60 ]; then
    echo -e "${YELLOW}High Priority Issues (Should Have):${NC}"
    REMAINING_CAPACITY=$((80 - CRITICAL_HOURS))
    echo "  (Remaining capacity: ~$REMAINING_CAPACITY hours)"
    
    # Show high priority items that might fit
    echo "$HIGH" | jq -r '.[] | {title: .title, iid: .iid, effort: (.labels | map(select(startswith("Effort::"))) | .[0] // "Effort::M")} | "  □ #\(.iid): \(.title) [\(.effort)]"' | head -10
    echo
fi

# Quick actions to add issues
echo -e "${BOLD}⚡ Quick Actions${NC}"
echo "──────────────"
echo "To add an issue to the sprint, use:"
echo -e "${MAGENTA}curl -s -X PUT -H \"PRIVATE-TOKEN: \$GITLAB_PRIVATE_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"milestone_id\": $CURRENT_MILESTONE_ID}' \\
  \"\$GITLAB_API_URL/projects/\$GITLAB_PROJECT_ID/issues/ISSUE_ID\"${NC}"
echo
echo "Or use the issue IDs listed above with this helper:"
echo -e "${MAGENTA}./scripts/add-to-sprint.sh ISSUE_ID [ISSUE_ID2 ...]${NC}"

# Create the helper script
cat > /Users/ghscholt/globtim/scripts/add-to-sprint.sh << 'EOF'
#!/bin/bash
# Add issues to current sprint by IID

source .env.gitlab

if [ $# -eq 0 ]; then
    echo "Usage: $0 ISSUE_ID [ISSUE_ID2 ...]"
    echo "Example: $0 123 456 789"
    exit 1
fi

echo "Adding issues to sprint (Milestone ID: $CURRENT_MILESTONE_ID)..."

for ISSUE_ID in "$@"; do
    echo -n "Adding issue #$ISSUE_ID... "
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X PUT \
        -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"milestone_id\": $CURRENT_MILESTONE_ID}" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues/$ISSUE_ID")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1 | cut -d: -f2)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅"
    else
        echo "❌ (HTTP $HTTP_CODE)"
    fi
done

echo "Done!"
EOF

chmod +x /Users/ghscholt/globtim/scripts/add-to-sprint.sh

echo
echo "Helper script created: ./scripts/add-to-sprint.sh"