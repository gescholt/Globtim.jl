#!/bin/bash
# Setup GitLab labels for project management

# Check if environment variables are set, otherwise prompt
if [ -z "$GITLAB_PROJECT_ID" ]; then
    echo "GITLAB_PROJECT_ID not set."
    echo -n "Enter GitLab Project ID: "
    read PROJECT_ID
else
    PROJECT_ID="${GITLAB_PROJECT_ID}"
fi

if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "GITLAB_PRIVATE_TOKEN not set."
    echo -n "Enter GitLab Personal Access Token: "
    read -s GITLAB_TOKEN
    echo
else
    GITLAB_TOKEN="${GITLAB_PRIVATE_TOKEN}"
fi

GITLAB_URL="${GITLAB_API_URL:-https://gitlab.com/api/v4}"

# Verify credentials
echo "Testing GitLab API connection..."
echo "Project ID: $PROJECT_ID"
echo "API URL: $GITLAB_URL"

# First check if we can reach the API
RESPONSE=$(curl -s -w "\n%{http_code}" "$GITLAB_URL/projects/$PROJECT_ID" \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" != "200" ]; then
    echo "Error: Failed to connect to GitLab API (HTTP $HTTP_CODE)"
    if [ "$HTTP_CODE" = "404" ]; then
        echo "Project not found. Please verify the project ID."
        echo "For project 'Globtim', the ID might be different than 2859"
    elif [ "$HTTP_CODE" = "401" ]; then
        echo "Authentication failed. Please check your access token."
    fi
    echo "Response: $BODY"
    exit 1
fi

echo "Successfully connected to GitLab API!"
PROJECT_NAME=$(echo "$BODY" | jq -r .name)
echo "Project found: $PROJECT_NAME"
echo

# Function to create label
create_label() {
    local name="$1"
    local color="$2"
    local description="$3"

    curl -s -X POST "$GITLAB_URL/projects/$PROJECT_ID/labels" \
        -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        -d "name=$name&color=$color&description=$description" | jq .
}

echo "Creating Epic Labels..."
create_label "epic::test-framework" "#7F8C8D" "Core testing framework development"
create_label "epic::julia-optimization" "#9B59B6" "Julia performance improvements"
create_label "epic::maple-integration" "#3498DB" "Maple system integration"
create_label "epic::documentation" "#1ABC9C" "Documentation and guides"

echo "Creating Status Labels..."
create_label "status::backlog" "#95A5A6" "In backlog"
create_label "status::ready" "#F39C12" "Ready for development"
create_label "status::in-progress" "#3498DB" "Currently being worked on"
create_label "status::review" "#9B59B6" "In code review"
create_label "status::testing" "#E67E22" "Being tested"
create_label "status::done" "#27AE60" "Completed"

echo "Creating Priority Labels..."
create_label "priority::critical" "#E74C3C" "Must be done ASAP"
create_label "priority::high" "#E67E22" "High priority"
create_label "priority::medium" "#F39C12" "Medium priority"
create_label "priority::low" "#95A5A6" "Low priority"

echo "Creating Type Labels..."
create_label "type::feature" "#2ECC71" "New feature"
create_label "type::bug" "#E74C3C" "Bug fix"
create_label "type::research" "#8E44AD" "Research task"
create_label "type::documentation" "#34495E" "Documentation"
create_label "type::test" "#16A085" "Test-related"

echo "Creating Component Labels..."
create_label "component::julia-core" "#1ABC9C" "Julia core functionality"
create_label "component::maple-interface" "#16A085" "Maple interface"
create_label "component::test-generation" "#2980B9" "Test generation"
create_label "component::ci-cd" "#34495E" "CI/CD pipeline"

echo "Creating Special Labels..."
create_label "blocked" "#E74C3C" "Blocked by dependency"
create_label "needs-discussion" "#F39C12" "Needs team discussion"
