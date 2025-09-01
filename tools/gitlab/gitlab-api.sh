#!/bin/bash
"""
Secure GitLab API Wrapper

Provides secure GitLab API access without exposing tokens in command line.
Usage: ./gitlab-api.sh GET /projects/2545/issues
"""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env.gitlab.local" 2>/dev/null || true

# Get token securely
TOKEN=$("$SCRIPT_DIR/get-token.sh")
if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve GitLab token" >&2
    exit 1
fi

# Execute API call
METHOD=${1:-GET}
ENDPOINT=${2:-/projects/$GITLAB_PROJECT_ID}
FULL_URL="$GITLAB_API_URL$ENDPOINT"

case $METHOD in
    GET)
        curl -s -H "PRIVATE-TOKEN: $TOKEN" "$FULL_URL" "${@:3}"
        ;;
    POST)
        curl -s -H "PRIVATE-TOKEN: $TOKEN" -H "Content-Type: application/json" -X POST "$FULL_URL" "${@:3}"
        ;;
    PUT)
        curl -s -H "PRIVATE-TOKEN: $TOKEN" -H "Content-Type: application/json" -X PUT "$FULL_URL" "${@:3}"
        ;;
    DELETE)
        curl -s -H "PRIVATE-TOKEN: $TOKEN" -X DELETE "$FULL_URL" "${@:3}"
        ;;
    *)
        echo "Unsupported method: $METHOD" >&2
        exit 1
        ;;
esac
