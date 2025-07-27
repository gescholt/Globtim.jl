#!/bin/bash
# Track progress of epics by counting issues with epic labels

PROJECT_ID="${GITLAB_PROJECT_ID}"
GITLAB_TOKEN="${GITLAB_PRIVATE_TOKEN}"
GITLAB_URL="${GITLAB_API_URL:-https://gitlab.com/api/v4}"

# Epic labels to track
EPICS=(
    "epic::test-framework"
    "epic::julia-optimization"
    "epic::maple-integration"
    "epic::documentation"
)

echo "Epic Progress Report"
echo "==================="
echo ""

for epic in "${EPICS[@]}"; do
    echo "## $epic"

    # Get total issues with this epic label
    total=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get completed issues (status::done)
    done=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic,status::done" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Get in-progress issues
    in_progress=$(curl -s "$GITLAB_URL/projects/$PROJECT_ID/issues?labels=$epic,status::in-progress" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '. | length')

    # Calculate percentage
    if [ "$total" -gt 0 ]; then
        percentage=$((done * 100 / total))
    else
        percentage=0
    fi

    echo "Total Issues: $total"
    echo "Completed: $done"
    echo "In Progress: $in_progress"
    echo "Progress: $percentage%"
    echo ""
done

echo "Generated at: $(date)"
