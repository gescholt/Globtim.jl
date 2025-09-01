#!/bin/bash
"""
GitLab Security Validation Script

Validates that GitLab API access is properly secured and no tokens are exposed.
Checks for security best practices implementation.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Check if files are properly ignored by Git
check_git_ignore() {
    log_info "Checking Git ignore configuration..."
    
    local issues=0
    local sensitive_files=(
        ".env.gitlab.local"
        "tools/gitlab/config.json"
        "tools/gitlab/.gitlab-token"
        ".gitlab-token"
        "gitlab-token.txt"
    )
    
    for file in "${sensitive_files[@]}"; do
        if git check-ignore "$file" >/dev/null 2>&1; then
            log_success "✅ $file is properly ignored by Git"
        else
            log_error "❌ $file is NOT ignored by Git - SECURITY RISK!"
            issues=$((issues + 1))
        fi
    done
    
    return $issues
}

# Check for hardcoded tokens in repository
check_hardcoded_tokens() {
    log_info "Scanning for hardcoded tokens in repository..."
    
    local issues=0
    
    # Patterns that might indicate hardcoded tokens
    local patterns=(
        "glpat-[a-zA-Z0-9_-]+"
        "PRIVATE-TOKEN.*[a-zA-Z0-9]{20,}"
        "access_token.*[a-zA-Z0-9]{20,}"
        "gitlab.*token.*[a-zA-Z0-9]{20,}"
    )
    
    for pattern in "${patterns[@]}"; do
        log_info "Checking pattern: $pattern"
        
        # Search in tracked files only
        if git grep -i -E "$pattern" -- '*.sh' '*.py' '*.md' '*.json' '*.yml' '*.yaml' 2>/dev/null; then
            log_error "❌ Found potential hardcoded token with pattern: $pattern"
            issues=$((issues + 1))
        else
            log_success "✅ No hardcoded tokens found for pattern: $pattern"
        fi
    done
    
    return $issues
}

# Check file permissions
check_file_permissions() {
    log_info "Checking file permissions..."
    
    local issues=0
    
    # Files that should have restricted permissions (600)
    local restricted_files=(
        "tools/gitlab/config.json"
        ".env.gitlab.local"
        "tools/gitlab/secure_config.py"
    )
    
    # Files that should be executable (700)
    local executable_files=(
        "tools/gitlab/get-token.sh"
        "tools/gitlab/gitlab-api.sh"
        "tools/gitlab/setup-secure-config.sh"
        "tools/gitlab/validate-security.sh"
    )
    
    for file in "${restricted_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -f "%A" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
            if [[ "$perms" == "600" ]]; then
                log_success "✅ $file has correct permissions (600)"
            else
                log_warning "⚠️ $file has permissions $perms, should be 600"
                chmod 600 "$file" 2>/dev/null && log_success "Fixed permissions for $file"
            fi
        fi
    done
    
    for file in "${executable_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -f "%A" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
            if [[ "$perms" == "700" ]]; then
                log_success "✅ $file has correct permissions (700)"
            else
                log_warning "⚠️ $file has permissions $perms, should be 700"
                chmod 700 "$file" 2>/dev/null && log_success "Fixed permissions for $file"
            fi
        fi
    done
    
    return $issues
}

# Check token retrieval mechanism
check_token_retrieval() {
    log_info "Testing secure token retrieval..."
    
    local issues=0
    
    # Check if get-token.sh exists and works
    if [[ -f "$SCRIPT_DIR/get-token.sh" ]]; then
        if "$SCRIPT_DIR/get-token.sh" >/dev/null 2>&1; then
            log_success "✅ Token retrieval script works"
        else
            log_error "❌ Token retrieval script failed"
            issues=$((issues + 1))
        fi
    else
        log_error "❌ Token retrieval script not found"
        issues=$((issues + 1))
    fi
    
    # Check if API wrapper exists
    if [[ -f "$SCRIPT_DIR/gitlab-api.sh" ]]; then
        log_success "✅ GitLab API wrapper exists"
    else
        log_error "❌ GitLab API wrapper not found"
        issues=$((issues + 1))
    fi
    
    return $issues
}

# Check environment configuration
check_environment_config() {
    log_info "Checking environment configuration..."
    
    local issues=0
    
    # Check if secure environment file exists
    if [[ -f "$REPO_ROOT/.env.gitlab.local" ]]; then
        log_success "✅ Secure environment file exists"
        
        # Check if it contains sensitive data
        if grep -q "PRIVATE-TOKEN\|access_token" "$REPO_ROOT/.env.gitlab.local" 2>/dev/null; then
            log_error "❌ Environment file contains sensitive token data"
            issues=$((issues + 1))
        else
            log_success "✅ Environment file does not contain sensitive tokens"
        fi
    else
        log_warning "⚠️ Secure environment file not found (.env.gitlab.local)"
    fi
    
    # Check if old insecure file exists
    if [[ -f "$REPO_ROOT/.env.gitlab" ]]; then
        if grep -q "PRIVATE-TOKEN\|access_token" "$REPO_ROOT/.env.gitlab" 2>/dev/null; then
            log_warning "⚠️ Old environment file contains sensitive data"
            log_info "Consider migrating to secure configuration"
        fi
    fi
    
    return $issues
}

# Check script security
check_script_security() {
    log_info "Checking script security practices..."
    
    local issues=0
    
    # Check for insecure curl commands in scripts
    log_info "Scanning for insecure API calls..."
    
    if git grep -n "PRIVATE-TOKEN.*\$" -- '*.sh' 2>/dev/null | grep -v "validate-security.sh"; then
        log_error "❌ Found scripts with potentially insecure token usage"
        issues=$((issues + 1))
    else
        log_success "✅ No insecure token usage found in scripts"
    fi
    
    # Check for direct token exposure in command line
    if git grep -n "curl.*PRIVATE-TOKEN" -- '*.sh' 2>/dev/null | grep -v "validate-security.sh" | grep -v "gitlab-api.sh"; then
        log_warning "⚠️ Found direct curl commands with tokens (should use gitlab-api.sh wrapper)"
    else
        log_success "✅ Scripts use secure API wrapper"
    fi
    
    return $issues
}

# Generate security report
generate_security_report() {
    log_info "Generating security report..."
    
    local report_file="$SCRIPT_DIR/security-report.txt"
    
    cat > "$report_file" << EOF
GitLab Security Validation Report
=================================
Generated: $(date '+%Y-%m-%d %H:%M:%S')

Security Status Summary:
- Git Ignore: $(check_git_ignore >/dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL")
- Hardcoded Tokens: $(check_hardcoded_tokens >/dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL")
- File Permissions: $(check_file_permissions >/dev/null 2>&1 && echo "✅ PASS" || echo "⚠️ FIXED")
- Token Retrieval: $(check_token_retrieval >/dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL")
- Environment Config: $(check_environment_config >/dev/null 2>&1 && echo "✅ PASS" || echo "⚠️ WARNING")
- Script Security: $(check_script_security >/dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL")

Security Recommendations:
1. Always use tools/gitlab/gitlab-api.sh for API calls
2. Never commit files containing tokens
3. Use environment variables or Git credential helper for token storage
4. Regularly rotate GitLab API tokens
5. Monitor token usage in GitLab settings

For detailed security setup, see: tools/gitlab/SECURITY.md
EOF

    log_success "Security report generated: $report_file"
}

# Main validation function
run_validation() {
    echo "🔒 GitLab Security Validation"
    echo "============================="
    echo ""
    
    local total_issues=0
    
    # Run all checks
    check_git_ignore || total_issues=$((total_issues + $?))
    echo ""
    
    check_hardcoded_tokens || total_issues=$((total_issues + $?))
    echo ""
    
    check_file_permissions || total_issues=$((total_issues + $?))
    echo ""
    
    check_token_retrieval || total_issues=$((total_issues + $?))
    echo ""
    
    check_environment_config || total_issues=$((total_issues + $?))
    echo ""
    
    check_script_security || total_issues=$((total_issues + $?))
    echo ""
    
    # Generate report
    generate_security_report
    echo ""
    
    # Summary
    if [[ $total_issues -eq 0 ]]; then
        log_success "🎉 All security checks passed!"
        echo ""
        echo "Your GitLab configuration is secure and follows best practices."
    else
        log_warning "⚠️ Found $total_issues security issues"
        echo ""
        echo "Please review the issues above and run tools/gitlab/setup-secure-config.sh if needed."
    fi
    
    return $total_issues
}

# Display usage
usage() {
    echo "GitLab Security Validation Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  validate    Run complete security validation (default)"
    echo "  report      Generate security report only"
    echo "  fix         Fix common security issues"
    echo "  help        Show this help message"
    echo ""
    echo "This script validates GitLab API security configuration."
}

# Fix common issues
fix_issues() {
    log_info "Fixing common security issues..."
    
    # Fix file permissions
    check_file_permissions
    
    # Ensure sensitive files are in .gitignore
    local gitignore_file="$REPO_ROOT/.gitignore"
    local sensitive_patterns=(
        ".env.gitlab.local"
        "tools/gitlab/config.json"
        "tools/gitlab/.gitlab-token"
        ".gitlab-token"
        "gitlab-token.txt"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        if ! grep -q "^$pattern$" "$gitignore_file" 2>/dev/null; then
            echo "$pattern" >> "$gitignore_file"
            log_success "Added $pattern to .gitignore"
        fi
    done
    
    log_success "Common security issues fixed"
}

# Main execution
main() {
    case "${1:-validate}" in
        validate)
            run_validation
            ;;
        report)
            generate_security_report
            ;;
        fix)
            fix_issues
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
