# Git and GitLab Configuration for globtimcore

## Overview

This document describes the locked-down git and GitLab configuration for the globtimcore project, designed to prevent recurring configuration issues that have caused 404 errors and authentication failures.

## Critical Configuration Values

These values are **locked** and should never change:

```bash
# Git remote URL
Remote: git@git.mpi-cbg.de:globaloptim/globtimcore.git

# GitLab project path
Project: globaloptim/globtimcore

# GitLab host
Host: git.mpi-cbg.de

# Default branch
Branch: main
```

## Configuration Protection Infrastructure

### 1. Git Hooks (Automatic Protection)

Three git hooks automatically protect the remote URL:

- **`.git/hooks/post-checkout`** - Runs after checkout
- **`.git/hooks/post-merge`** - Runs after merge
- **`.git/hooks/post-rewrite`** - Runs after rebase/amend

These hooks automatically detect and fix any changes to the remote URL.

**Example output when fixing:**
```
⚠️  WARNING: Remote URL has changed!
   Expected: git@git.mpi-cbg.de:globaloptim/globtimcore.git
   Current:  git@git.mpi-cbg.de:scholten/globtimcore.git
   Fixing remote URL...
✅ Remote URL restored to correct value
```

### 2. Validation Script

Run the validation script to check all configuration:

```bash
./scripts/validate_git_config.sh
```

This script checks:
1. ✅ Git remote URL is correct
2. ✅ No glab-resolved cache (causes 404 errors)
3. ✅ Git hooks are installed and executable
4. ✅ glab authentication token is configured
5. ✅ glab can access the project
6. ✅ Default branch is set to 'main'

**Run this script whenever:**
- You experience 404 errors with glab commands
- Remote URL seems incorrect
- GitLab authentication fails
- After cloning the repository on a new machine

### 3. glab Configuration

The glab CLI tool is configured in `~/.config/glab-cli/config.yml`:

```yaml
hosts:
    git.mpi-cbg.de:
        token: Viq_MEpVpxSH3GFgsv4w
        container_registry_domains: git.mpi-cbg.de,git.mpi-cbg.de:443,registry.git.mpi-cbg.de
        api_host: git.mpi-cbg.de
        git_protocol: ssh
        api_protocol: https
        user: project_2859_bot_b3d7a8a6f07456a7dd781688136ea61a
```

**Important:** The bot account `project_2859_bot_b3d7a8a6f07456a7dd781688136ea61a` must have at least Developer access to the `globaloptim/globtimcore` project.

## Common Issues and Solutions

### Issue 1: glab commands return 404 errors

**Symptoms:**
```bash
$ glab issue list
ERROR: 404 Not Found
```

**Root causes:**
1. Remote URL is incorrect (pointing to wrong project)
2. `glab-resolved` cache is pointing to wrong project
3. Running glab from outside the repository directory

**Solution:**
```bash
# Run validation script
./scripts/validate_git_config.sh

# If that doesn't work, manually fix:
cd /Users/ghscholt/GlobalOptim/globtimcore
git config remote.origin.url git@git.mpi-cbg.de:globaloptim/globtimcore.git
git config --unset remote.origin.glab-resolved  # Remove cache
```

### Issue 2: Remote URL keeps changing to scholten/globtimcore

**Symptom:**
Remote URL changes from `globaloptim/globtimcore` to incorrect values like `scholten/globtimcore`

**Root cause:**
Some operation (merge, rebase, checkout) is changing the remote URL

**Solution:**
The git hooks will automatically fix this. If not:
```bash
./scripts/validate_git_config.sh
```

### Issue 3: glab-resolved cache causes wrong project

**Symptom:**
```bash
$ glab issue list
ERROR: 404 Not Found
```

But git remote is correct.

**Root cause:**
Git config has a `remote.origin.glab-resolved` entry that overrides the URL resolution

**Solution:**
```bash
git config --unset remote.origin.glab-resolved
```

This is automatically done by the validation script.

### Issue 4: Must run glab from repository directory

**Symptom:**
glab commands fail when run from outside the repository

**Root cause:**
glab determines GitLab instance from git repository context

**Solution:**
Always run glab commands from within the repository directory, or use:
```bash
bash -c 'cd /Users/ghscholt/GlobalOptim/globtimcore && glab <command>'
```

## Manual Configuration (if needed)

### If hooks are lost (e.g., after fresh clone)

```bash
cd /Users/ghscholt/GlobalOptim/globtimcore

# Re-create hooks
for hook in post-checkout post-merge post-rewrite; do
    cat > .git/hooks/$hook << 'EOF'
#!/bin/bash
EXPECTED_REMOTE="git@git.mpi-cbg.de:globaloptim/globtimcore.git"
CURRENT_REMOTE=$(git config --get remote.origin.url)
if [ "$CURRENT_REMOTE" != "$EXPECTED_REMOTE" ]; then
    echo "⚠️  WARNING: Remote URL has changed!"
    echo "   Expected: $EXPECTED_REMOTE"
    echo "   Current:  $CURRENT_REMOTE"
    echo "   Fixing remote URL..."
    git config remote.origin.url "$EXPECTED_REMOTE"
    echo "✅ Remote URL restored to correct value"
fi
EOF
    chmod +x .git/hooks/$hook
done

echo "✅ Hooks re-installed"
```

### If glab authentication is lost

1. Check if token exists:
```bash
grep -A5 "git.mpi-cbg.de" ~/.config/glab-cli/config.yml
```

2. If token is missing, you need the bot token or create a personal access token:
   - Go to https://git.mpi-cbg.de/-/profile/personal_access_tokens
   - Create token with scopes: `api`, `read_repository`, `write_repository`
   - Add to `~/.config/glab-cli/config.yml` under `git.mpi-cbg.de: token:`

## Testing the Configuration

After making any changes, verify everything works:

```bash
# 1. Run validation script
./scripts/validate_git_config.sh

# 2. Test glab commands
glab issue list
glab repo view

# 3. Test git operations
git remote -v
git fetch origin
```

## Architecture Decisions

### Why git hooks instead of git config protections?

Git doesn't support write-protecting config values, so we use hooks that run after operations that might change configuration.

### Why not use .gitconfig?

Project-specific git config (`.git/config`) cannot be version-controlled. Hooks also can't be version-controlled (for security), but we provide scripts to reinstall them.

### Why check and fix instead of preventing?

Git hooks run *after* operations, not before. We detect bad state and immediately fix it, which is more robust than trying to prevent the operation.

### Why not use environment variables for everything?

Environment variables would require setting them in every shell session and HPC job. The current approach works automatically once configured.

## Maintenance

### When cloning on a new machine

```bash
git clone git@git.mpi-cbg.de:globaloptim/globtimcore.git
cd globtimcore
./scripts/validate_git_config.sh
```

### When onboarding a new developer

1. Ensure they have access to `globaloptim/globtimcore` on GitLab
2. Ensure they have glab installed: `brew install glab`
3. Run: `./scripts/validate_git_config.sh`
4. They may need to authenticate to git.mpi-cbg.de

### Periodic checks

Run monthly or when experiencing issues:
```bash
./scripts/validate_git_config.sh
```

## Future Improvements

Potential enhancements to consider:

1. **Pre-commit hook** to validate that no hardcoded paths are committed
2. **CI/CD check** that verifies configuration in pipeline
3. **Wrapper script** for common glab commands that ensures correct directory
4. **Git alias** to run validation: `git config alias.validate '!./scripts/validate_git_config.sh'`
5. **Setup script** for new clones that automatically installs hooks
6. **Monitor script** that runs validation before each glab command
7. **Lock file** (`.git/globtim.lock`) to detect if hooks have been removed

## Related Issues

- #126 - GitLab integration for experiment runner
- #129 - Automation epic
- See commit history for issues that prompted this infrastructure

## Support

If you experience configuration issues not covered here:
1. Run `./scripts/validate_git_config.sh` and share output
2. Run `git config --list --show-origin | grep remote`
3. Run `glab auth status`
4. Check if you're in the repository directory: `pwd`
