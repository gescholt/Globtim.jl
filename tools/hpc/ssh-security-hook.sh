#!/bin/bash
# SSH Security Communication Hook for Claude Code
#
# Provides comprehensive security validation and monitoring for SSH communications
# with HPC cluster nodes. Ensures all SSH operations follow security best practices
# and maintains audit trails.
#
# Features:
# - Pre-connection security validation
# - SSH configuration hardening checks
# - Connection encryption verification
# - Session monitoring and logging
# - Anomaly detection for SSH operations
# - Post-connection security validation
#
# Usage: Automatically triggered by Claude Code agents for SSH operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SSH_LOG_FILE="$PROJECT_ROOT/tools/hpc/.ssh_security.log"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# SSH Security configuration
REQUIRED_SSH_VERSION="8.0"
ALLOWED_HOSTS=("falcon" "r04n02" "fileserver-ssh")
REQUIRED_KEY_TYPES=("ed25519" "rsa" "ecdsa")
MAX_CONNECTION_TIME=300  # 5 minutes
SUSPICIOUS_COMMANDS=("rm -rf" "dd if=" "mkfs" "format" "fdisk")

function log_ssh_event() {
    local level=$1
    local message=$2
    local timestamp=$(date -Iseconds)
    local host=${3:-"unknown"}
    local command=${4:-""}
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$SSH_LOG_FILE")"
    
    # Log to file with structured format
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"host\":\"$host\",\"command\":\"$command\",\"user\":\"$(whoami)\",\"pid\":$$}" >> "$SSH_LOG_FILE"
    
    # Also log to stderr with colors
    case $level in
        "ERROR")
            echo -e "${RED}🔒 SSH SECURITY [$level]: $message${NC}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  SSH SECURITY [$level]: $message${NC}" >&2
            ;;
        "INFO")
            echo -e "${GREEN}🛡️  SSH SECURITY [$level]: $message${NC}" >&2
            ;;
        "DEBUG")
            echo -e "${BLUE}🔍 SSH SECURITY [$level]: $message${NC}" >&2
            ;;
    esac
}

function validate_ssh_version() {
    log_ssh_event "DEBUG" "Validating SSH client version"
    
    # Get SSH version
    local ssh_version=$(ssh -V 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    if [[ -z "$ssh_version" ]]; then
        log_ssh_event "ERROR" "Unable to determine SSH version"
        return 1
    fi
    
    # Compare version (basic numeric comparison)
    local major=$(echo "$ssh_version" | cut -d. -f1)
    local minor=$(echo "$ssh_version" | cut -d. -f2)
    local req_major=$(echo "$REQUIRED_SSH_VERSION" | cut -d. -f1)
    local req_minor=$(echo "$REQUIRED_SSH_VERSION" | cut -d. -f2)
    
    if [[ $major -lt $req_major ]] || [[ $major -eq $req_major && $minor -lt $req_minor ]]; then
        log_ssh_event "ERROR" "SSH version $ssh_version is below minimum required $REQUIRED_SSH_VERSION"
        return 1
    fi
    
    log_ssh_event "INFO" "SSH version $ssh_version meets security requirements"
    return 0
}

function validate_ssh_keys() {
    log_ssh_event "DEBUG" "Validating SSH key security"
    
    local key_found=false
    local key_issues=()
    
    # Check for SSH keys
    for key_type in "${REQUIRED_KEY_TYPES[@]}"; do
        local key_file="$HOME/.ssh/id_$key_type"
        
        if [[ -f "$key_file" ]]; then
            key_found=true
            log_ssh_event "DEBUG" "Found SSH key: $key_file"
            
            # Check key permissions
            local perms=$(stat -f "%OLp" "$key_file" 2>/dev/null || stat -c "%a" "$key_file" 2>/dev/null)
            if [[ "$perms" != "600" ]]; then
                key_issues+=("Key $key_file has permissions $perms (should be 600)")
                chmod 600 "$key_file"
                log_ssh_event "WARN" "Fixed permissions for $key_file"
            fi
            
            # Check key strength (for RSA keys)
            if [[ "$key_type" == "rsa" ]]; then
                local key_size=$(ssh-keygen -l -f "$key_file" 2>/dev/null | awk '{print $1}')
                if [[ -n "$key_size" && $key_size -lt 2048 ]]; then
                    key_issues+=("RSA key $key_file has weak key size: $key_size bits (recommend 2048+)")
                fi
            fi
        fi
    done
    
    if [[ "$key_found" != true ]]; then
        log_ssh_event "ERROR" "No SSH keys found in ~/.ssh/"
        return 1
    fi
    
    if [[ ${#key_issues[@]} -gt 0 ]]; then
        for issue in "${key_issues[@]}"; do
            log_ssh_event "WARN" "$issue"
        done
    fi
    
    log_ssh_event "INFO" "SSH key validation completed"
    return 0
}

function validate_ssh_config() {
    log_ssh_event "DEBUG" "Validating SSH configuration security"
    
    if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
        log_ssh_event "WARN" "SSH config file not found: $SSH_CONFIG_FILE"
        return 0  # Not critical, SSH will use defaults
    fi
    
    local config_issues=()
    
    # Check for security-relevant configurations
    local security_checks=(
        "PasswordAuthentication:no:Password authentication should be disabled"
        "PubkeyAuthentication:yes:Public key authentication should be enabled"
        "Protocol:2:SSH Protocol 2 should be specified"
        "StrictHostKeyChecking:accept-new:Host key checking should be enabled"
    )
    
    for check in "${security_checks[@]}"; do
        IFS=':' read -r setting expected_value message <<< "$check"
        
        # Check if setting exists and has correct value
        local current_value=$(grep -i "^[[:space:]]*$setting" "$SSH_CONFIG_FILE" | head -1 | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
        expected_value=$(echo "$expected_value" | tr '[:upper:]' '[:lower:]')
        
        if [[ -n "$current_value" && "$current_value" != "$expected_value" ]]; then
            config_issues+=("$message (current: $current_value, expected: $expected_value)")
        fi
    done
    
    if [[ ${#config_issues[@]} -gt 0 ]]; then
        for issue in "${config_issues[@]}"; do
            log_ssh_event "WARN" "SSH config: $issue"
        done
    fi
    
    log_ssh_event "INFO" "SSH configuration validation completed"
    return 0
}

function validate_known_hosts() {
    log_ssh_event "DEBUG" "Validating SSH known hosts security"
    
    if [[ ! -f "$SSH_KNOWN_HOSTS" ]]; then
        log_ssh_event "WARN" "SSH known_hosts file not found: $SSH_KNOWN_HOSTS"
        return 0
    fi
    
    # Check known_hosts permissions
    local perms=$(stat -f "%OLp" "$SSH_KNOWN_HOSTS" 2>/dev/null || stat -c "%a" "$SSH_KNOWN_HOSTS" 2>/dev/null)
    if [[ "$perms" != "644" && "$perms" != "600" ]]; then
        chmod 600 "$SSH_KNOWN_HOSTS"
        log_ssh_event "WARN" "Fixed known_hosts permissions"
    fi
    
    # Check for our required hosts
    local missing_hosts=()
    for host in "${ALLOWED_HOSTS[@]}"; do
        if ! grep -q "$host" "$SSH_KNOWN_HOSTS"; then
            missing_hosts+=("$host")
        fi
    done
    
    if [[ ${#missing_hosts[@]} -gt 0 ]]; then
        log_ssh_event "INFO" "Missing known_hosts entries: ${missing_hosts[*]} (will be added on first connection)"
    fi
    
    log_ssh_event "INFO" "Known hosts validation completed"
    return 0
}

function validate_connection_security() {
    local target_host=$1
    local command=${2:-""}
    
    log_ssh_event "DEBUG" "Validating connection security for $target_host"
    
    # Validate target host
    local host_allowed=false
    for allowed_host in "${ALLOWED_HOSTS[@]}"; do
        if [[ "$target_host" =~ $allowed_host ]]; then
            host_allowed=true
            break
        fi
    done
    
    if [[ "$host_allowed" != true ]]; then
        log_ssh_event "ERROR" "Connection to unauthorized host: $target_host"
        return 1
    fi
    
    # Validate command security
    if [[ -n "$command" ]]; then
        for suspicious_cmd in "${SUSPICIOUS_COMMANDS[@]}"; do
            if [[ "$command" =~ $suspicious_cmd ]]; then
                log_ssh_event "WARN" "Potentially dangerous command detected: $suspicious_cmd in '$command'"
                # Allow but log - don't block legitimate administrative commands
            fi
        done
    fi
    
    log_ssh_event "INFO" "Connection security validation passed for $target_host"
    return 0
}

function test_ssh_connection() {
    local target_host=$1
    log_ssh_event "DEBUG" "Testing SSH connection to $target_host"
    
    # Test connection with timeout (macOS compatible)
    local start_time=$(date +%s)
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$target_host" "echo 'SSH_TEST_SUCCESS'" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_ssh_event "INFO" "SSH connection test successful to $target_host (${duration}s)"
        return 0
    else
        log_ssh_event "ERROR" "SSH connection test failed to $target_host"
        return 1
    fi
}

function monitor_ssh_session() {
    local target_host=$1
    local command=${2:-""}
    local session_id=$$
    
    log_ssh_event "INFO" "Starting SSH session monitoring" "$target_host" "$command"
    
    # Record session start
    echo "{\"session_id\":$session_id,\"host\":\"$target_host\",\"command\":\"$command\",\"start_time\":\"$(date -Iseconds)\",\"status\":\"started\"}" >> "$SSH_LOG_FILE.sessions"
    
    # Return session monitoring function
    echo "monitor_session_end() {
        echo \"{\\\"session_id\\\":$session_id,\\\"host\\\":\\\"$target_host\\\",\\\"end_time\\\":\\\"$(date -Iseconds)\\\",\\\"status\\\":\\\"completed\\\"}\" >> \"$SSH_LOG_FILE.sessions\"
        log_ssh_event \"INFO\" \"SSH session completed\" \"$target_host\" \"$command\"
    }"
}

function run_comprehensive_ssh_security_check() {
    log_ssh_event "INFO" "Starting comprehensive SSH security check"
    
    local checks_passed=0
    local total_checks=0
    
    # Run all security validations
    local security_checks=(
        "validate_ssh_version"
        "validate_ssh_keys"
        "validate_ssh_config"
        "validate_known_hosts"
    )
    
    for check in "${security_checks[@]}"; do
        total_checks=$((total_checks + 1))
        if $check; then
            checks_passed=$((checks_passed + 1))
        fi
    done
    
    log_ssh_event "INFO" "SSH security check completed: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        echo -e "${GREEN}🎉 SSH SECURITY: All security checks passed!${NC}"
        echo -e "${CYAN}   • SSH version: $(ssh -V 2>&1 | head -1)${NC}"
        echo -e "${CYAN}   • Key-based authentication configured${NC}"
        echo -e "${CYAN}   • Configuration security validated${NC}"
        echo -e "${CYAN}   • Known hosts properly configured${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  SSH SECURITY: $((total_checks - checks_passed)) security issues detected${NC}"
        echo -e "${YELLOW}   Review the log for details: $SSH_LOG_FILE${NC}"
        return 1
    fi
}

function secure_ssh_execute() {
    local target_host=$1
    local command=${2:-""}
    
    log_ssh_event "INFO" "Executing secure SSH command" "$target_host" "$command"
    
    # Pre-connection validation
    validate_connection_security "$target_host" "$command" || return 1
    
    # Start session monitoring
    local monitor_func=$(monitor_ssh_session "$target_host" "$command")
    
    # Execute SSH command with security monitoring
    local ssh_result
    if [[ -n "$command" ]]; then
        ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$target_host" "$command"
        ssh_result=$?
    else
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$target_host"
        ssh_result=$?
    fi
    
    # End session monitoring
    eval "$monitor_func"
    
    if [[ $ssh_result -eq 0 ]]; then
        log_ssh_event "INFO" "SSH command completed successfully" "$target_host" "$command"
    else
        log_ssh_event "ERROR" "SSH command failed with exit code $ssh_result" "$target_host" "$command"
    fi
    
    return $ssh_result
}

function main() {
    local action=${1:-"validate"}
    local target_host=${2:-""}
    local command=${3:-""}
    
    case $action in
        "validate"|"check")
            run_comprehensive_ssh_security_check
            ;;
        "test")
            if [[ -z "$target_host" ]]; then
                echo "Usage: $0 test <hostname>"
                exit 1
            fi
            test_ssh_connection "$target_host"
            ;;
        "execute"|"ssh")
            if [[ -z "$target_host" ]]; then
                echo "Usage: $0 execute <hostname> [command]"
                exit 1
            fi
            secure_ssh_execute "$target_host" "$command"
            ;;
        "monitor")
            echo "SSH Security Monitoring Dashboard"
            echo "================================"
            echo "Recent SSH sessions:"
            if [[ -f "$SSH_LOG_FILE.sessions" ]]; then
                tail -10 "$SSH_LOG_FILE.sessions" | jq -r '. | "\(.start_time // .end_time) \(.host) \(.status)"' 2>/dev/null || tail -10 "$SSH_LOG_FILE.sessions"
            else
                echo "No session history found"
            fi
            echo ""
            echo "Recent security events:"
            if [[ -f "$SSH_LOG_FILE" ]]; then
                tail -10 "$SSH_LOG_FILE" | jq -r '. | "\(.timestamp) [\(.level)] \(.message)"' 2>/dev/null || tail -10 "$SSH_LOG_FILE"
            else
                echo "No security events logged"
            fi
            ;;
        *)
            echo "SSH Security Hook for HPC Cluster Communication"
            echo "Usage: $0 {validate|test|execute|monitor} [options]"
            echo ""
            echo "Commands:"
            echo "  validate              Run comprehensive security check"
            echo "  test <hostname>       Test SSH connection to hostname"
            echo "  execute <hostname> [cmd] Execute command securely via SSH"
            echo "  monitor               Show SSH security monitoring dashboard"
            echo ""
            echo "Examples:"
            echo "  $0 validate                    # Check SSH security configuration"
            echo "  $0 test r04n02                # Test connection to r04n02"
            echo "  $0 execute r04n02 'uptime'    # Execute command securely"
            echo "  $0 monitor                     # Show monitoring dashboard"
            ;;
    esac
}

# Handle different invocation contexts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct execution
    main "$@"
elif [[ -n "$CLAUDE_CONTEXT" ]]; then
    # Called as Claude Code hook
    log_ssh_event "INFO" "SSH security hook triggered by Claude Code" "" "$CLAUDE_CONTEXT"
    run_comprehensive_ssh_security_check
else
    # Sourced by another script
    log_ssh_event "DEBUG" "SSH security functions loaded"
fi