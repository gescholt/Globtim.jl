#!/bin/bash
# Create GitLab sprint milestone

source .env.gitlab

# Calculate dates (2-week sprint)
START_DATE=$(date +%Y-%m-%d)
END_DATE=$(date -d "+14 days" +%Y-%m-%d 2>/dev/null || date -v +14d +%Y-%m-%d)

MILESTONE_TITLE="Sprint 2025-01"
MILESTONE_DESCRIPTION="## Sprint Goals\n- Set up project management workflow\n- Implement initial Julia optimization features\n- Establish testing framework\n\n## Focus Areas\n1. **Infrastructure**: GitLab boards, CI/CD setup\n2. **Development**: Core functionality improvements\n3. **Documentation**: Update README and API docs\n\n## Success Criteria\n- All P0/P1 issues resolved\n- Tests passing with >80% coverage\n- Documentation updated"

echo "Creating milestone: $MILESTONE_TITLE"
echo "Duration: $START_DATE to $END_DATE"

# Create JSON payload with jq to ensure proper escaping
JSON_PAYLOAD=$(jq -n \
  --arg title "$MILESTONE_TITLE" \
  --arg desc "$MILESTONE_DESCRIPTION" \
  --arg start "$START_DATE" \
  --arg due "$END_DATE" \
  '{title: $title, description: $desc, start_date: $start, due_date: $due}')

# Create milestone
echo "Sending request to: $GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones")

# Extract HTTP code
HTTP_CODE=$(echo "$RESPONSE" | tail -n1 | cut -d: -f2)
RESPONSE=$(echo "$RESPONSE" | sed '$d')  # Remove HTTP code line

echo "HTTP Response Code: $HTTP_CODE"

# Debug: show raw response if jq fails
if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "Raw response: $RESPONSE"
fi

MILESTONE_ID=$(echo "$RESPONSE" | jq -r '.id // empty' 2>/dev/null)

if [ -n "$MILESTONE_ID" ]; then
    echo "✅ Milestone created successfully (ID: $MILESTONE_ID)"
    echo "$RESPONSE" | jq '{id, title, start_date, due_date, state}'
else
    echo "❌ Failed to create milestone"
    echo "Response: $RESPONSE"
    exit 1
fi

# Save milestone ID for future use
echo "export CURRENT_MILESTONE_ID=\"$MILESTONE_ID\"" >> .env.gitlab
echo "Added CURRENT_MILESTONE_ID to .env.gitlab"
