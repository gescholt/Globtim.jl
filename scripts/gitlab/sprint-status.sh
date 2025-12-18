#!/bin/bash
# View current sprint status

source .env.gitlab

echo "=== Sprint Status: Sprint 2025-01 ==="
echo

# Get milestone details
echo "📅 Milestone Details:"
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID" | \
    jq '{
        title: .title,
        state: .state,
        start_date: .start_date,
        due_date: .due_date,
        description: .description | split("\n")[0:3] | join(" | ")
    }'

echo
echo "📊 Issue Summary:"
# Get issues for this milestone
ISSUES=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones/$CURRENT_MILESTONE_ID/issues")

# Count by status
echo "$ISSUES" | jq -r '
    group_by(.labels[] | select(startswith("status::"))) |
    map({
        status: (.[0].labels[] | select(startswith("status::")) | split("::")[1]),
        count: length
    }) |
    .[] | "  \(.status): \(.count)"'

# Total issues
TOTAL=$(echo "$ISSUES" | jq 'length')
echo "  Total: $TOTAL"

echo
echo "📋 Issues by Priority:"
echo "$ISSUES" | jq -r '
    group_by(.labels[] | select(startswith("priority::"))) |
    map({
        priority: (.[0].labels[] | select(startswith("priority::")) | split("::")[1]),
        count: length
    }) |
    .[] | "  \(.priority): \(.count)"'

echo
echo "🎯 Issue List:"
echo "$ISSUES" | jq -r '.[] | "  #\(.iid): \(.title)"' | head -10

echo
echo "🔗 Links:"
echo "  Milestone: https://git.mpi-cbg.de/globaloptim/globtimcore/-/milestones/$CURRENT_MILESTONE_ID"
echo "  Issues: https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues?milestone_title=Sprint+2025-01"
echo "  Board: https://git.mpi-cbg.de/globaloptim/globtimcore/-/boards"
