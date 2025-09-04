#!/bin/bash
# GitLab Security Hook for Claude Code
# Validates .gitlab_config before any GitLab operations
# Usage: Called automatically by Claude hooks system

set -euo pipefail

# Configuration
GLOBTIM_PROJECT_DIR="/Users/ghscholt/globtim"
SECURE_TOKEN_SCRIPT="$GLOBTIM_PROJECT_DIR/tools/gitlab/get-token.sh"
HOOK_LOG_FILE="$GLOBTIM_PROJECT_DIR/.gitlab_hook.log"
REQUIRED_VARS=("GITLAB_URL" "GITLAB_TOKEN" "GITLAB_PROJECT_PATH")

# Logging function
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$HOOK_LOG_FILE"
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "WARN" ]]; then
        echo "🔒 GitLab Security Hook [$level]: $message" >&2
    fi
}

# Main validation function
validate_gitlab_config() {
    local exit_code=0
    
    log_event "INFO" "Starting GitLab configuration validation"
    
    # Check if we're in the correct directory
    if [[ ! -d "$GLOBTIM_PROJECT_DIR" ]]; then
        log_event "ERROR" "GlobTim project directory not found: $GLOBTIM_PROJECT_DIR"
        return 1
    fi
    
    cd "$GLOBTIM_PROJECT_DIR"
    
    # Check if secure token script exists
    if [[ ! -f "$SECURE_TOKEN_SCRIPT" ]]; then
        log_event "ERROR" "Secure token script not found at $SECURE_TOKEN_SCRIPT"
        echo "❌ GitLab secure token system not available."
        echo "   Expected script: $SECURE_TOKEN_SCRIPT"
        echo "   Please ensure secure GitLab configuration is set up."
        return 1
    fi
    
    # Check script permissions (should be secure)
    local script_perms=$(stat -f "%A" "$SECURE_TOKEN_SCRIPT" 2>/dev/null || stat -c "%a" "$SECURE_TOKEN_SCRIPT" 2>/dev/null)
    if [[ "$script_perms" != "700" ]] && [[ "$script_perms" != "500" ]]; then
        log_event "WARN" "Securing token script permissions: $script_perms"
        chmod 700 "$SECURE_TOKEN_SCRIPT"
    fi
    
    # Set up secure environment variables
    local missing_vars=()
    
    # Set known configuration
    export GITLAB_URL="https://git.mpi-cbg.de"
    export GITLAB_PROJECT_PATH="scholten/globtim"
    
    # Use secure token retrieval (simpler approach)
    if [[ -x "$SECURE_TOKEN_SCRIPT" ]]; then
        if token_output=$("$SECURE_TOKEN_SCRIPT" 2>/dev/null) && [[ -n "$token_output" ]]; then
            export GITLAB_TOKEN="$token_output"
            log_event "INFO" "Secure token retrieval verified"
        else
            log_event "WARN" "Secure token script failed, checking environment"
            # Fallback: check if GITLAB_PRIVATE_TOKEN exists
            if [[ -n "${GITLAB_PRIVATE_TOKEN:-}" ]]; then
                export GITLAB_TOKEN="$GITLAB_PRIVATE_TOKEN"
                log_event "INFO" "Using GITLAB_PRIVATE_TOKEN from environment"
            else
                log_event "ERROR" "No secure token available"
                missing_vars+=("GITLAB_TOKEN")
            fi
        fi
    else
        log_event "ERROR" "Secure token script not executable"
        missing_vars+=("GITLAB_TOKEN")
    fi
    
    # Check each required variable exists (avoid duplicates)
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            # Only add if not already in missing_vars
            if [[ ! " ${missing_vars[*]} " =~ " ${var} " ]]; then
                missing_vars+=("$var")
            fi
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_event "ERROR" "Missing required variables: ${missing_vars[*]}"
        echo "❌ GitLab configuration incomplete. Missing variables:"
        printf "   - %s\n" "${missing_vars[@]}"
        return 1
    fi
    
    # Validate URL format
    if [[ ! "$GITLAB_URL" =~ ^https?:// ]]; then
        log_event "ERROR" "Invalid GITLAB_URL format: $GITLAB_URL"
        echo "❌ GITLAB_URL must start with http:// or https://"
        return 1
    fi
    
    # Validate project path format
    if [[ ! "$GITLAB_PROJECT_PATH" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        log_event "ERROR" "Invalid project path format: $GITLAB_PROJECT_PATH"
        echo "❌ GITLAB_PROJECT_PATH should be in format: owner/project"
        return 1
    fi
    
    log_event "INFO" "GitLab configuration validation successful"
    return 0
}

# Main execution
main() {
    # Check trigger conditions
    local should_validate=false
    
    # Check environment variables from Claude
    if [[ "${CLAUDE_TOOL_NAME:-}" == "Task" ]] && [[ "${CLAUDE_SUBAGENT_TYPE:-}" == "project-task-updater" ]]; then
        should_validate=true
        log_event "INFO" "Triggered by project-task-updater agent"
    fi
    
    if [[ "${CLAUDE_CONTEXT:-}" =~ [Gg]it[Ll]ab ]]; then
        should_validate=true
        log_event "INFO" "Triggered by GitLab context mention"
    fi
    
    # Force validation if explicitly called
    if [[ "${1:-}" == "--force" ]]; then
        should_validate=true
        log_event "INFO" "Forced validation requested"
    fi
    
    if [[ "$should_validate" == "true" ]]; then
        if validate_gitlab_config; then
            echo "✅ GitLab security validation passed"
            log_event "INFO" "Security validation completed successfully"
            exit 0
        else
            echo "❌ GitLab security validation failed"
            log_event "ERROR" "Security validation failed"
            exit 1
        fi
    else
        log_event "INFO" "No trigger conditions met, skipping validation"
        exit 0
    fi
}

# Handle script being called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi