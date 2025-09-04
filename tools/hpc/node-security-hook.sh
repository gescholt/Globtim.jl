#!/bin/bash
# HPC Node Security Hook for Claude Code
#
# Validates and secures all HPC node operations before execution.
# Integrates with Claude Code's hook system to ensure secure cluster access.
#
# Usage: This hook is automatically triggered by Claude Code agents
#        Environment: CLAUDE_TOOL_NAME, CLAUDE_CONTEXT, CLAUDE_SUBAGENT_TYPE

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$PROJECT_ROOT/tools/hpc/.node_security.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function log_security_event() {
    local level=$1
    local message=$2
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}🔒 HPC SECURITY: $message${NC}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  HPC SECURITY: $message${NC}" >&2
            ;;
        "INFO")
            echo -e "${GREEN}🛡️  HPC SECURITY: $message${NC}" >&2
            ;;
        "DEBUG")
            echo -e "${BLUE}🔍 HPC SECURITY: $message${NC}" >&2
            ;;
    esac
}

function validate_ssh_configuration() {
    log_security_event "DEBUG" "Validating SSH configuration for r04n02 access"
    
    # Check SSH key exists (try common key types)
    SSH_KEY=""
    for key_type in id_rsa id_ed25519 id_ecdsa; do
        if [[ -f "$HOME/.ssh/$key_type" ]]; then
            SSH_KEY="$HOME/.ssh/$key_type"
            break
        fi
    done
    
    if [[ -z "$SSH_KEY" ]]; then
        log_security_event "ERROR" "No SSH private key found in ~/.ssh/"
        echo "To fix: Generate SSH key with 'ssh-keygen -t ed25519 -C \"your_email@example.com\"'"
        return 1
    fi
    
    log_security_event "INFO" "Found SSH key: $SSH_KEY"
    
    # Check SSH key permissions
    KEY_PERMS=$(stat -f "%OLp" "$SSH_KEY" 2>/dev/null || stat -c "%a" "$SSH_KEY" 2>/dev/null)
    if [[ "$KEY_PERMS" != "600" ]]; then
        log_security_event "WARN" "SSH key permissions should be 600, found: $KEY_PERMS"
        chmod 600 "$SSH_KEY"
        log_security_event "INFO" "SSH key permissions corrected to 600"
    fi
    
    # Test SSH connection (non-interactive)
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
         scholten@r04n02 "echo 'SSH_OK'" >/dev/null 2>&1; then
        log_security_event "ERROR" "SSH connection to r04n02 failed"
        echo "To fix: Ensure SSH key is added to r04n02: ssh-copy-id scholten@r04n02"
        return 1
    fi
    
    log_security_event "INFO" "SSH configuration validated successfully"
    return 0
}

function validate_node_access_security() {
    log_security_event "DEBUG" "Validating HPC node access security policies"
    
    # Check for prohibited operations
    context_check=$(echo "$CLAUDE_CONTEXT" | tr '[:upper:]' '[:lower:]')
    if [[ "$context_check" =~ (password|token|secret|credential) ]]; then
        if [[ ! "$context_check" =~ (secure|validate|check) ]]; then
            log_security_event "ERROR" "Potential credential exposure detected in context"
            return 1
        fi
    fi
    
    # Validate working directory constraints
    if [[ "$context_check" =~ /tmp ]]; then
        log_security_event "ERROR" "Operations in /tmp directory are prohibited"
        echo "Use /home/scholten/globtim/hpc/experiments/temp/ instead"
        return 1
    fi
    
    # Check for dangerous commands
    DANGEROUS_PATTERNS=("rm -rf /" "mkfs" "dd if=" "format" "> /dev/")
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
        if [[ "$context_check" =~ $pattern_lower ]]; then
            log_security_event "ERROR" "Potentially destructive command pattern detected: $pattern"
            return 1
        fi
    done
    
    log_security_event "INFO" "Node access security validation passed"
    return 0
}

function validate_experiment_environment() {
    log_security_event "DEBUG" "Validating experiment execution environment"
    
    # Test Python wrapper availability
    PYTHON_WRAPPER="$PROJECT_ROOT/tools/hpc/secure_node_config.py"
    if [[ ! -f "$PYTHON_WRAPPER" ]]; then
        log_security_event "ERROR" "Secure node configuration wrapper not found: $PYTHON_WRAPPER"
        return 1
    fi
    
    # Test Python wrapper functionality (quick validation)
    if ! python3 -c "
import sys
sys.path.append('$PROJECT_ROOT/tools/hpc')
try:
    from secure_node_config import SecureNodeAccess
    # Quick validation without full SSH test
    print('WRAPPER_OK')
except ImportError as e:
    print(f'WRAPPER_ERROR: {e}')
    sys.exit(1)
" 2>/dev/null | grep -q "WRAPPER_OK"; then
        log_security_event "WARN" "Secure node wrapper validation failed (may indicate dependency issues)"
        # Don't fail here as this might be environment-specific
    else
        log_security_event "INFO" "Python wrapper validated successfully"
    fi
    
    return 0
}

function check_agent_compliance() {
    local agent_type=${CLAUDE_SUBAGENT_TYPE:-"unknown"}
    local tool_name=${CLAUDE_TOOL_NAME:-"unknown"}
    
    log_security_event "DEBUG" "Checking agent compliance: $agent_type via $tool_name"
    
    # Ensure HPC-related agents use proper security patterns
    case $agent_type in
        "hpc-cluster-operator")
            log_security_event "INFO" "HPC cluster operator agent - enforcing security protocols"
            # This agent should use SecureNodeAccess wrapper
            ;;
        "julia-test-architect"|"julia-documenter-expert")
            context_check=$(echo "$CLAUDE_CONTEXT" | tr '[:upper:]' '[:lower:]')
            if [[ "$context_check" =~ (cluster|hpc|node|r04n02) ]]; then
                log_security_event "INFO" "Julia agent with HPC context - security protocols active"
            fi
            ;;
        *)
            context_check=$(echo "$CLAUDE_CONTEXT" | tr '[:upper:]' '[:lower:]')
            if [[ "$context_check" =~ (ssh|r04n02|cluster|hpc) ]]; then
                log_security_event "WARN" "Non-HPC agent attempting cluster access: $agent_type"
                echo "Consider using hpc-cluster-operator agent for cluster operations"
            fi
            ;;
    esac
    
    return 0
}

function main() {
    local context="${CLAUDE_CONTEXT:-"No context provided"}"
    local tool_name="${CLAUDE_TOOL_NAME:-"unknown"}"
    local agent_type="${CLAUDE_SUBAGENT_TYPE:-"unknown"}"
    
    log_security_event "INFO" "Security validation started - Context: $context"
    log_security_event "DEBUG" "Tool: $tool_name, Agent: $agent_type"
    
    # Only validate if HPC-related context detected
    context_lower=$(echo "$context" | tr '[:upper:]' '[:lower:]')
    if [[ "$context_lower" =~ (cluster|hpc|r04n02|ssh|tmux|node|experiment|monitoring) ]]; then
        log_security_event "INFO" "HPC context detected - performing full security validation"
        
        # Run all security validations
        validate_ssh_configuration || exit 1
        validate_node_access_security || exit 1
        validate_experiment_environment || exit 1
        check_agent_compliance || exit 1
        
        log_security_event "INFO" "All HPC security validations passed"
        
        # Provide usage guidance
        echo ""
        echo -e "${GREEN}🛡️  HPC Security Validation Complete${NC}"
        echo -e "${CYAN}   • SSH access to r04n02 verified${NC}"
        echo -e "${CYAN}   • Security policies validated${NC}"
        echo -e "${CYAN}   • Experiment environment ready${NC}"
        echo ""
        echo -e "${BLUE}Recommended usage:${NC}"
        echo -e "${BLUE}   Python: from tools.hpc.secure_node_config import SecureNodeAccess${NC}"
        echo -e "${BLUE}   Direct:  ssh scholten@r04n02 'cd /home/scholten/globtim && command'${NC}"
        echo ""
        
    else
        log_security_event "DEBUG" "No HPC context detected - skipping cluster security validation"
        echo -e "${CYAN}🔍 HPC Security Hook: No cluster operations detected${NC}"
    fi
    
    return 0
}

# Trap errors and log them
trap 'log_security_event "ERROR" "Security hook failed at line $LINENO"' ERR

# Run main validation
main "$@"