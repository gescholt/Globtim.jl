#!/bin/bash
# Explore GitLab project structure and settings

source .env.gitlab

echo "=== GitLab Project Information ==="
echo "Server: ${GITLAB_API_URL%/api/v4}"
echo "Project ID: $GITLAB_PROJECT_ID"
echo

# Get project details
echo "=== Project Details ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID" | \
    jq '{
        name: .name,
        path: .path_with_namespace,
        description: .description,
        default_branch: .default_branch,
        visibility: .visibility,
        created_at: .created_at,
        issues_enabled: .issues_enabled,
        merge_requests_enabled: .merge_requests_enabled,
        wiki_enabled: .wiki_enabled,
        snippets_enabled: .snippets_enabled,
        container_registry_enabled: .container_registry_enabled,
        packages_enabled: .packages_enabled
    }'

echo
echo "=== Repository Statistics ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/statistics" | \
    jq '.'

echo
echo "=== Recent Issues ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?per_page=5" | \
    jq '.[] | {id: .iid, title: .title, state: .state, labels: .labels, created_at: .created_at}'

echo
echo "=== Recent Merge Requests ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/merge_requests?per_page=5" | \
    jq '.[] | {id: .iid, title: .title, state: .state, source_branch: .source_branch, target_branch: .target_branch}'

echo
echo "=== CI/CD Pipelines ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines?per_page=5" | \
    jq '.[] | {id: .id, status: .status, ref: .ref, created_at: .created_at}'

echo
echo "=== Protected Branches ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/protected_branches" | \
    jq '.[] | {name: .name, push_access_levels: .push_access_levels, merge_access_levels: .merge_access_levels}'

echo
echo "=== Project Members ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/members" | \
    jq '.[] | {username: .username, name: .name, access_level: .access_level, expires_at: .expires_at}'

echo
echo "=== Milestones ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/milestones" | \
    jq '.[] | {id: .id, title: .title, state: .state, due_date: .due_date}'

echo
echo "=== Labels Summary ==="
curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" | \
    jq 'group_by(.name | split("::")[0]) | map({category: .[0].name | split("::")[0], count: length, labels: map(.name)})'
