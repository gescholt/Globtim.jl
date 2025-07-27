#!/bin/bash
# Test milestone creation with minimal data

source .env.gitlab

# Simple test
echo "Testing milestone creation..."

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Milestone"}' \
  "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1 | cut -d: -f2)
RESPONSE=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Code: $HTTP_CODE"
echo "Response: $RESPONSE"

# Try with verbose to see headers
echo -e "\n\nVerbose request:"
curl -v -X POST \
  -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Milestone 2"}' \
  "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones" 2>&1 | grep -E "< HTTP|< |{|}"
