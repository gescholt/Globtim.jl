---
name: git-auth-enforcer
description: Ensures git remote always uses OAuth2 token authentication to prevent auth reverts
events: ["PreToolUse"]
---

# Git Authentication Enforcer Hook

This hook ensures the git remote URL is always configured with OAuth2 token authentication before any git operations, preventing authentication failures.

## Implementation

```bash
#!/bin/bash

# Only run for git-related operations
if [[ "$CLAUDE_TOOL_NAME" != *"git"* ]] && [[ "$CLAUDE_COMMAND" != *"git"* ]]; then
    exit 0
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Source GitLab token
if [ -f .env.gitlab.local ]; then
    source .env.gitlab.local
    
    # Check current remote URL
    current_url=$(git remote get-url origin 2>/dev/null)
    
    # If URL doesn't contain oauth2 token, fix it
    if [[ "$current_url" != *"oauth2:"* ]]; then
        echo "🔧 Enforcing OAuth2 token authentication for git remote"
        git remote set-url origin "https://oauth2:${GITLAB_PRIVATE_TOKEN}@git.mpi-cbg.de/scholten/globtim.git"
        echo "✅ Git remote URL updated to use token authentication"
    fi
fi
```

## Purpose

Prevents authentication failures by ensuring:
1. Git remote always uses OAuth2 token format
2. No manual credential prompts
3. Consistent authentication across all git operations
4. Automatic URL correction before any git command