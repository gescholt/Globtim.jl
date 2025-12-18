#!/bin/bash
# Get GitLab project ID using the API

# Check if token is set
if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "Error: GITLAB_PRIVATE_TOKEN not set"
    echo "Please run: source .env.gitlab"
    exit 1
fi

if [ -z "$GITLAB_API_URL" ]; then
    echo "Error: GITLAB_API_URL not set"
    echo "Please run: source .env.gitlab"
    exit 1
fi

# Get project path from git remote
REMOTE_URL=$(git config --get remote.origin.url)
# Extract project path - handle both SSH and HTTPS formats
if [[ "$REMOTE_URL" == git@* ]]; then
    # SSH format: git@host:user/project.git
    PROJECT_PATH=$(echo "$REMOTE_URL" | sed 's/^git@[^:]*:\(.*\)\.git$/\1/')
else
    # HTTPS format: https://host/user/project.git
    PROJECT_PATH=$(echo "$REMOTE_URL" | sed 's|^https://[^/]*/\(.*\)\.git$|\1|')
fi

echo "Looking up project: $PROJECT_PATH"
echo "Using API: $GITLAB_API_URL"

# URL encode the project path (replace / with %2F)
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's/\//%2F/g')

# Get project info
RESPONSE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$ENCODED_PATH")

# Extract project ID
PROJECT_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not get project ID"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "Found project ID: $PROJECT_ID"

# Update .env.gitlab
sed -i.bak "s/export GITLAB_PROJECT_ID=\"\"/export GITLAB_PROJECT_ID=\"$PROJECT_ID\"/" .env.gitlab
rm .env.gitlab.bak

echo "Updated .env.gitlab with project ID"
echo
echo "Now run:"
echo "  source .env.gitlab"
echo "  ./scripts/setup-gitlab-labels.sh"
