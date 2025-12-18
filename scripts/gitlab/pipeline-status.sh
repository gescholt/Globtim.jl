#!/bin/bash
# Check GitLab pipeline status

source .env.gitlab
# For consistency with documentation
GITLAB_TOKEN="${GITLAB_PRIVATE_TOKEN}"

echo "=== GitLab CI/CD Pipeline Status ==="
echo

# Get latest pipelines
echo "📊 Recent Pipelines:"
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines?per_page=5" | \
    jq -r '.[] | "  [\(.status)] #\(.id) - \(.ref) - \(.created_at)"' || echo "  No pipelines found"

echo
echo "🔧 Pipeline Configuration:"
if [ -f .gitlab-ci.yml ]; then
    echo "  ✅ .gitlab-ci.yml exists"
    echo "  Jobs configured:"
    grep -E "^[a-zA-Z].*:$" .gitlab-ci.yml | grep -v "^stages:" | sed 's/:$//' | sed 's/^/    - /'
else
    echo "  ❌ No .gitlab-ci.yml found"
fi

echo
echo "🚀 To trigger a pipeline:"
echo "  1. Commit and push changes"
echo "  2. Create a merge request"
echo "  3. Push to main or clean-version branches"

echo
echo "🔗 GitLab CI/CD URL:"
echo "  https://git.mpi-cbg.de/globaloptim/globtimcore/-/pipelines"
