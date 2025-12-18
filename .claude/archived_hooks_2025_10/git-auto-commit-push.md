---
name: git-auto-commit-push
description: Automatically commit and push changes when significant work is completed
events: ["PostToolUse"]
---

# Git Auto Commit Push Hook

This hook automatically commits and pushes changes when significant development work is completed.

## Trigger Conditions

The hook activates when:
1. Multiple files have been modified (5+ files)
2. New features or major changes are implemented
3. Documentation updates are substantial
4. User explicitly requests commit/push operations

## Implementation

```bash
#!/bin/bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

# Get git status
git_status=$(git status --porcelain)
if [ -z "$git_status" ]; then
    exit 0  # No changes to commit
fi

# Count modified/new files
file_count=$(echo "$git_status" | wc -l | tr -d ' ')

# Auto-commit threshold (5+ files or explicit user request)
if [ "$file_count" -ge 5 ] || [[ "$CLAUDE_CONTEXT" == *"commit"* ]] || [[ "$CLAUDE_CONTEXT" == *"push"* ]]; then
    
    # Source GitLab token for authentication
    if [ -f .env.gitlab.local ]; then
        source .env.gitlab.local
        # Ensure git remote uses token authentication
        if [[ "$(git remote get-url origin)" != *"oauth2:"* ]]; then
            git remote set-url origin "https://oauth2:${GITLAB_PRIVATE_TOKEN}@git.mpi-cbg.de/globaloptim/globtimcore.git"
        fi
    fi
    
    # Stage all changes
    git add .
    
    # Generate commit message based on changes
    commit_msg="feat: Auto-commit of development progress

🔄 Changes Summary:
- $file_count files modified/added
- Context: $CLAUDE_CONTEXT

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    
    # Commit with generated message
    git commit -m "$commit_msg"
    
    # Push to remote
    git push
    
    echo "✅ Auto-committed and pushed $file_count files"
fi
```

## Usage

The hook runs automatically after tool use. To manually trigger:

```bash
export CLAUDE_CONTEXT="commit and push changes"
# Hook will activate on next significant tool use
```

## Configuration

Add to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "git-auto-commit-push": {
      "enabled": true,
      "threshold": 5
    }
  }
}
```