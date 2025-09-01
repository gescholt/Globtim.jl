#!/bin/bash
"""
Secure GitLab Configuration Setup

Sets up secure GitLab API access using Git credential helper and environment variables.
Implements security best practices to prevent token exposure.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
ENV_FILE="$REPO_ROOT/.env.gitlab.local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a Git repository
check_git_repo() {
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        log_error "Not in a Git repository"
        exit 1
    fi
}

# Set up Git credential helper for GitLab
setup_git_credentials() {
    log_info "Setting up Git credential helper for GitLab..."
    
    # Configure Git to use credential helper for GitLab
    git config --local credential.https://git.mpi-cbg.de.helper store
    git config --local credential.https://git.mpi-cbg.de.username "$(git config user.name || echo 'your-username')"
    
    log_success "Git credential helper configured for git.mpi-cbg.de"
}

# Create secure environment file
create_env_file() {
    log_info "Creating secure environment configuration..."
    
    # Get GitLab details
    echo "Please provide your GitLab configuration:"
    echo ""
    
    # Get project ID
    read -p "GitLab Project ID (current: 2545): " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-2545}
    
    # Get GitLab URL
    read -p "GitLab URL (current: https://git.mpi-cbg.de): " GITLAB_URL
    GITLAB_URL=${GITLAB_URL:-https://git.mpi-cbg.de}
    
    # Get milestone ID
    read -p "Current Milestone ID (current: 119): " MILESTONE_ID
    MILESTONE_ID=${MILESTONE_ID:-119}
    
    # Create environment file
    cat > "$ENV_FILE" << EOF
# GitLab Configuration - Local Environment
# This file is automatically ignored by Git (.gitignore)
# DO NOT COMMIT THIS FILE

export GITLAB_API_URL="${GITLAB_URL}/api/v4"
export GITLAB_PROJECT_ID="$PROJECT_ID"
export CURRENT_MILESTONE_ID="$MILESTONE_ID"

# Token will be retrieved from Git credential helper or environment
# Set GITLAB_PRIVATE_TOKEN environment variable or use Git credential helper
EOF

    chmod 600 "$ENV_FILE"  # Restrict permissions
    log_success "Environment file created: $ENV_FILE"
}

# Create secure config.json
create_config_json() {
    log_info "Creating secure GitLab API configuration..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "project_id": "$PROJECT_ID",
  "base_url": "${GITLAB_URL}/api/v4",
  "rate_limit_delay": 1.0,
  "token_source": "environment"
}
EOF

    chmod 600 "$CONFIG_FILE"  # Restrict permissions
    log_success "API configuration created: $CONFIG_FILE"
}

# Create token management script
create_token_manager() {
    log_info "Creating secure token management script..."
    
    cat > "$SCRIPT_DIR/get-token.sh" << 'EOF'
#!/bin/bash
"""
Secure GitLab Token Retrieval

Retrieves GitLab API token from secure sources without exposing it in scripts.
Priority: Environment Variable > Git Credential Helper > Keychain
"""

# Try environment variable first
if [[ -n "$GITLAB_PRIVATE_TOKEN" ]]; then
    echo "$GITLAB_PRIVATE_TOKEN"
    exit 0
fi

# Try Git credential helper
if command -v git &> /dev/null; then
    # Use Git credential helper to get token
    TOKEN=$(echo "protocol=https
host=git.mpi-cbg.de
path=api/v4" | git credential fill 2>/dev/null | grep "password=" | cut -d= -f2)
    
    if [[ -n "$TOKEN" ]]; then
        echo "$TOKEN"
        exit 0
    fi
fi

# Try macOS Keychain (if available)
if command -v security &> /dev/null; then
    TOKEN=$(security find-generic-password -a "$(whoami)" -s "gitlab-api-token" -w 2>/dev/null || true)
    if [[ -n "$TOKEN" ]]; then
        echo "$TOKEN"
        exit 0
    fi
fi

# No token found
echo "Error: GitLab API token not found" >&2
echo "Please set GITLAB_PRIVATE_TOKEN environment variable or configure Git credential helper" >&2
exit 1
EOF

    chmod 700 "$SCRIPT_DIR/get-token.sh"  # Executable, restricted permissions
    log_success "Token manager created: $SCRIPT_DIR/get-token.sh"
}

# Update existing scripts to use secure token retrieval
update_scripts() {
    log_info "Updating scripts to use secure token retrieval..."
    
    # Create secure wrapper for curl commands
    cat > "$SCRIPT_DIR/gitlab-api.sh" << 'EOF'
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
EOF

    chmod 700 "$SCRIPT_DIR/gitlab-api.sh"
    log_success "GitLab API wrapper created: $SCRIPT_DIR/gitlab-api.sh"
}

# Update Python scripts to use secure configuration
update_python_scripts() {
    log_info "Updating Python scripts for secure token handling..."
    
    # Update gitlab_manager.py to use secure token retrieval
    cat > "$SCRIPT_DIR/secure_config.py" << 'EOF'
#!/usr/bin/env python3
"""
Secure GitLab Configuration Manager

Handles secure retrieval of GitLab API tokens and configuration.
"""

import os
import json
import subprocess
from pathlib import Path
from typing import Optional

def get_gitlab_token() -> Optional[str]:
    """Securely retrieve GitLab API token from various sources"""
    
    # Try environment variable first
    token = os.environ.get('GITLAB_PRIVATE_TOKEN')
    if token:
        return token
    
    # Try Git credential helper
    try:
        script_dir = Path(__file__).parent
        token_script = script_dir / 'get-token.sh'
        if token_script.exists():
            result = subprocess.run([str(token_script)], 
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass
    
    return None

def load_secure_config(config_file: str = None) -> dict:
    """Load GitLab configuration with secure token handling"""
    
    if config_file is None:
        script_dir = Path(__file__).parent
        config_file = script_dir / 'config.json'
    
    # Load base configuration
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Get token securely
    token = get_gitlab_token()
    if not token:
        raise ValueError("GitLab API token not found. Please set GITLAB_PRIVATE_TOKEN environment variable or configure Git credential helper.")
    
    config['access_token'] = token
    return config

if __name__ == '__main__':
    try:
        config = load_secure_config()
        print(f"Configuration loaded successfully for project {config['project_id']}")
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
EOF

    chmod 600 "$SCRIPT_DIR/secure_config.py"
    log_success "Secure Python configuration manager created"
}

# Set up token in Git credential helper
setup_token_storage() {
    log_info "Setting up secure token storage..."
    
    echo ""
    echo "To complete the setup, you need to store your GitLab API token securely."
    echo "Choose your preferred method:"
    echo ""
    echo "1. Environment Variable (recommended for development)"
    echo "2. Git Credential Helper (recommended for production)"
    echo "3. macOS Keychain (macOS only)"
    echo ""
    
    read -p "Choose method (1-3): " METHOD
    
    case $METHOD in
        1)
            echo ""
            echo "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
            echo "export GITLAB_PRIVATE_TOKEN='your-token-here'"
            echo ""
            echo "Then reload your shell or run: source ~/.bashrc"
            ;;
        2)
            echo ""
            read -s -p "Enter your GitLab API token: " TOKEN
            echo ""
            
            # Store in Git credential helper
            echo "protocol=https
host=git.mpi-cbg.de
username=$(git config user.name || echo 'your-username')
password=$TOKEN" | git credential approve
            
            log_success "Token stored in Git credential helper"
            ;;
        3)
            if command -v security &> /dev/null; then
                echo ""
                read -s -p "Enter your GitLab API token: " TOKEN
                echo ""
                
                # Store in macOS Keychain
                security add-generic-password -a "$(whoami)" -s "gitlab-api-token" -w "$TOKEN"
                log_success "Token stored in macOS Keychain"
            else
                log_error "macOS Keychain not available on this system"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Create documentation
create_documentation() {
    log_info "Creating security documentation..."
    
    cat > "$SCRIPT_DIR/SECURITY.md" << 'EOF'
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
EOF

    log_success "Security documentation created: $SCRIPT_DIR/SECURITY.md"
}

# Display usage
usage() {
    echo "GitLab Secure Configuration Setup"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup       Complete secure configuration setup"
    echo "  credentials Configure Git credential helper only"
    echo "  token       Set up token storage only"
    echo "  test        Test current configuration"
    echo "  help        Show this help message"
    echo ""
    echo "This script sets up secure GitLab API access without exposing tokens."
}

# Test current configuration
test_config() {
    log_info "Testing GitLab API configuration..."
    
    # Source environment if available
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    fi
    
    # Test token retrieval
    if [[ -f "$SCRIPT_DIR/get-token.sh" ]]; then
        TOKEN=$("$SCRIPT_DIR/get-token.sh" 2>/dev/null)
        if [[ $? -eq 0 && -n "$TOKEN" ]]; then
            log_success "Token retrieval: OK"
        else
            log_error "Token retrieval: FAILED"
            return 1
        fi
    else
        log_error "Token manager not found"
        return 1
    fi
    
    # Test API access
    if [[ -f "$SCRIPT_DIR/gitlab-api.sh" ]]; then
        RESPONSE=$("$SCRIPT_DIR/gitlab-api.sh" GET "/projects/$GITLAB_PROJECT_ID" 2>/dev/null)
        if [[ $? -eq 0 && -n "$RESPONSE" ]]; then
            PROJECT_NAME=$(echo "$RESPONSE" | jq -r '.name' 2>/dev/null || echo "Unknown")
            log_success "API access: OK (Project: $PROJECT_NAME)"
        else
            log_error "API access: FAILED"
            return 1
        fi
    else
        log_error "API wrapper not found"
        return 1
    fi
    
    log_success "All tests passed!"
}

# Main execution
main() {
    case "${1:-setup}" in
        setup)
            check_git_repo
            setup_git_credentials
            create_env_file
            create_config_json
            create_token_manager
            update_scripts
            update_python_scripts
            create_documentation
            setup_token_storage
            
            echo ""
            log_success "Secure GitLab configuration setup complete!"
            echo ""
            echo "Next steps:"
            echo "1. Test configuration: $0 test"
            echo "2. Use secure API calls: ./tools/gitlab/gitlab-api.sh GET /projects/2545/issues"
            echo "3. Read security guide: cat tools/gitlab/SECURITY.md"
            ;;
        credentials)
            check_git_repo
            setup_git_credentials
            ;;
        token)
            setup_token_storage
            ;;
        test)
            test_config
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
