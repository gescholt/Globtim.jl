# GitLab API Security Guide

## Overview

This guide explains how to securely access GitLab API without exposing tokens in scripts or version control.

## Security Principles

1. **Never commit tokens** - All token files are in `.gitignore`
2. **Use secure storage** - Environment variables, Git credential helper, or Keychain
3. **Restrict permissions** - Configuration files have 600 permissions
4. **Secure retrieval** - Tokens retrieved at runtime, not stored in scripts

## Token Storage Methods

### Method 1: Environment Variable (Recommended for Development)

```bash
# Add to ~/.bashrc, ~/.zshrc, or ~/.bash_profile
export GITLAB_PRIVATE_TOKEN='your-token-here'

# Reload shell
source ~/.bashrc
```

### Method 2: Git Credential Helper (Recommended for Production)

```bash
# Configure Git credential helper
git config --local credential.https://git.mpi-cbg.de.helper store

# Store token (will be prompted)
./tools/gitlab/setup-secure-config.sh
```

### Method 3: macOS Keychain (macOS Only)

```bash
# Store in Keychain
security add-generic-password -a "$(whoami)" -s "gitlab-api-token" -w "your-token-here"
```

## Usage

### Secure API Calls

```bash
# Instead of: curl -H "PRIVATE-TOKEN: token" ...
# Use:
./tools/gitlab/gitlab-api.sh GET /projects/2545/issues

# Examples:
./tools/gitlab/gitlab-api.sh GET /projects/2545/issues
./tools/gitlab/gitlab-api.sh POST /projects/2545/issues -d '{"title":"New Issue"}'
```

### Python Scripts

```python
from tools.gitlab.secure_config import load_secure_config

# Automatically loads token securely
config = load_secure_config()
```

## File Security

### Protected Files (600 permissions)
- `tools/gitlab/config.json` - API configuration
- `.env.gitlab.local` - Environment variables
- `tools/gitlab/secure_config.py` - Python configuration

### Executable Scripts (700 permissions)
- `tools/gitlab/get-token.sh` - Token retrieval
- `tools/gitlab/gitlab-api.sh` - API wrapper

### Git Ignored Files
- `.env.gitlab.local`
- `tools/gitlab/config.json`
- `tools/gitlab/.gitlab-token`
- `.gitlab-token`
- `gitlab-token.txt`

## Troubleshooting

### Token Not Found Error

```bash
# Check token sources
echo $GITLAB_PRIVATE_TOKEN  # Environment variable
./tools/gitlab/get-token.sh  # All sources

# Test API access
./tools/gitlab/gitlab-api.sh GET /projects/2545
```

### Permission Denied

```bash
# Fix file permissions
chmod 600 tools/gitlab/config.json
chmod 700 tools/gitlab/get-token.sh
```

## Best Practices

1. **Use environment variables** for development
2. **Use Git credential helper** for production/CI
3. **Never log tokens** in scripts or output
4. **Rotate tokens regularly** (every 90 days)
5. **Use minimal scope** tokens (only required permissions)
6. **Monitor token usage** in GitLab settings

## Token Management

### Creating a GitLab API Token

1. Go to GitLab → User Settings → Access Tokens
2. Create token with minimal required scopes:
   - `api` - For full API access
   - `read_api` - For read-only access (if sufficient)
3. Copy token immediately (won't be shown again)
4. Store using one of the secure methods above

### Rotating Tokens

1. Create new token in GitLab
2. Update storage method:
   ```bash
   # Environment variable
   export GITLAB_PRIVATE_TOKEN='new-token'
   
   # Git credential helper
   ./tools/gitlab/setup-secure-config.sh
   
   # Keychain
   security add-generic-password -a "$(whoami)" -s "gitlab-api-token" -w "new-token"
   ```
3. Test access with new token
4. Revoke old token in GitLab

This security setup ensures tokens are never exposed in version control, command history, or process lists while maintaining easy access for development and automation.
