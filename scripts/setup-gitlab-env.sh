#!/bin/bash
# Automatically detect GitLab configuration from git remote

# 1. Get your project ID from the current repo
REMOTE_URL=$(git config --get remote.origin.url)
echo "Detected remote: $REMOTE_URL"

# Extract project path (username/project)
PROJECT_PATH=$(echo "$REMOTE_URL" | sed 's/.*[:/]\(.*\)\.git/\1/')
echo "Project path: $PROJECT_PATH"

# Convert git URL to API URL
if [[ "$REMOTE_URL" == git@* ]]; then
    # SSH URL format
    API_BASE=$(echo "$REMOTE_URL" | sed 's/git@/https:\/\//' | sed 's/:[0-9]*:/:/' | sed 's/\.git$//' | sed 's/\(.*\):.*/\1/')
else
    # HTTPS URL format
    API_BASE=$(echo "$REMOTE_URL" | sed 's/\.git$//' | sed 's/\(.*\)\/[^\/]*\/[^\/]*$/\1/')
fi

GITLAB_API_URL="$API_BASE/api/v4"
echo "API URL: $GITLAB_API_URL"

# 2. Try to get project ID via API (requires token)
echo
echo "To get your project ID automatically, you need a personal access token first."
echo "Get your token from:"
echo "$API_BASE/-/profile/personal_access_tokens"
echo "Create one with 'api' scope"
echo

# 3. Create .env.gitlab
cat > .env.gitlab << EOF
export GITLAB_API_URL="$GITLAB_API_URL"
export GITLAB_PROJECT_ID=""  # Will be filled after we have the token
export GITLAB_PRIVATE_TOKEN=""  # Add your personal access token here
EOF

echo "Created .env.gitlab - Please add your personal access token"
echo
echo "After adding your token to .env.gitlab, run:"
echo "  source .env.gitlab"
echo "  ./scripts/get-gitlab-project-id.sh"
echo "  ./scripts/setup-gitlab-labels.sh"
