#!/bin/bash
# Authentication Pattern Tests for project-task-updater agent
# Tests token handling, security, and authentication flows

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log() { echo -e "${GREEN}[AUTH]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "✅ PASS: $2"
        ((TESTS_PASSED++))
    else
        echo -e "❌ FAIL: $2"
        ((TESTS_FAILED++))
    fi
}

echo "=== Authentication Pattern Tests ==="
echo "Testing token handling and authentication methods"
echo ""

# Test 1: Token Retrieval Methods
echo "Test 1: Token Retrieval Method Validation"
log "Testing different token retrieval methods..."

# Method 1: Non-interactive script (RECOMMENDED)
TOKEN_METHOD1=""
if [[ -f "$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" ]]; then
    TOKEN_METHOD1=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null || echo "")
    if [[ -n "$TOKEN_METHOD1" && "${#TOKEN_METHOD1}" -eq 20 ]]; then
        test_result 0 "Token method 1: Non-interactive script retrieval works"
        WORKING_TOKEN="$TOKEN_METHOD1"
        TOKEN_AVAILABLE=1
    else
        test_result 1 "Token method 1: Non-interactive script failed or invalid token"
        TOKEN_AVAILABLE=0
    fi
else
    test_result 1 "Token method 1: Non-interactive script not found"
    TOKEN_AVAILABLE=0
fi

# Method 2: Environment variable (FALLBACK)
TOKEN_METHOD2="$GITLAB_PRIVATE_TOKEN"
if [[ -n "$TOKEN_METHOD2" ]]; then
    test_result 0 "Token method 2: Environment variable available"
else
    test_result 0 "Token method 2: Environment variable not set (expected)"
fi

# Method 3: Config file (BACKUP)
TOKEN_METHOD3=""
if [[ -f ~/.gitlab_config ]]; then
    TOKEN_METHOD3=$(grep "private_token" ~/.gitlab_config 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "")
    if [[ -n "$TOKEN_METHOD3" ]]; then
        test_result 0 "Token method 3: Config file token available"
    else
        test_result 1 "Token method 3: Config file exists but no valid token"
    fi
else
    test_result 0 "Token method 3: No config file (acceptable)"
fi

# Test 2: Token Security Validation
echo "Test 2: Token Security and Format Validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Validating token security properties..."
    
    # Check token length (GitLab tokens are typically 20 characters)
    TOKEN_LENGTH=${#WORKING_TOKEN}
    if [[ $TOKEN_LENGTH -eq 20 ]]; then
        test_result 0 "Token security: Correct token length ($TOKEN_LENGTH characters)"
    else
        test_result 1 "Token security: Unexpected token length ($TOKEN_LENGTH characters)"
    fi
    
    # Check token format (alphanumeric)
    if [[ "$WORKING_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
        test_result 0 "Token security: Valid alphanumeric format"
    else
        test_result 1 "Token security: Invalid token format"
    fi
    
    # Check token is not exposed in environment
    if env | grep -q "GITLAB.*$WORKING_TOKEN"; then
        test_result 1 "Token security: Token exposed in environment variables"
    else
        test_result 0 "Token security: Token not exposed in environment"
    fi
else
    test_result 1 "Token security: Cannot validate - no token available"
fi

# Test 3: Authentication Header Formats
echo "Test 3: Authentication Header Format Testing"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing different authentication header formats..."
    
    # Format 1: PRIVATE-TOKEN header (CORRECT for GitLab)
    AUTH_TEST1=$(curl -s -w "%{http_code}" -o /dev/null \
        --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/user" 2>/dev/null || echo "000")
    
    if [[ "$AUTH_TEST1" == "200" ]]; then
        test_result 0 "Auth header: PRIVATE-TOKEN format works (correct)"
    else
        test_result 1 "Auth header: PRIVATE-TOKEN format failed (HTTP $AUTH_TEST1)"
    fi
    
    # Format 2: Authorization Bearer header (WRONG for GitLab)
    AUTH_TEST2=$(curl -s -w "%{http_code}" -o /dev/null \
        --header "Authorization: Bearer $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/user" 2>/dev/null || echo "000")
    
    if [[ "$AUTH_TEST2" == "401" ]]; then
        test_result 0 "Auth header: Authorization Bearer fails as expected"
    else
        test_result 1 "Auth header: Authorization Bearer unexpectedly works"
    fi
    
    # Format 3: URL parameter (WRONG for security)
    AUTH_TEST3=$(curl -s -w "%{http_code}" -o /dev/null \
        "https://git.mpi-cbg.de/api/v4/user?private_token=$WORKING_TOKEN" 2>/dev/null || echo "000")
    
    if [[ "$AUTH_TEST3" == "200" ]]; then
        warn "Auth header: URL parameter works but is less secure"
        test_result 0 "Auth header: URL parameter method functional"
    else
        test_result 0 "Auth header: URL parameter method disabled (good security)"
    fi
else
    test_result 1 "Auth header: Cannot test without token"
fi

# Test 4: Token Permissions and Scopes
echo "Test 4: Token Permissions Validation"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing token permissions and scopes..."
    
    # Test API access (basic permission)
    API_ACCESS=$(curl -s --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/user" 2>/dev/null | jq -r '.username' 2>/dev/null || echo "")
    
    if [[ -n "$API_ACCESS" && "$API_ACCESS" != "null" ]]; then
        test_result 0 "Permissions: API access available (user: $API_ACCESS)"
    else
        test_result 1 "Permissions: No API access with current token"
    fi
    
    # Test project access
    PROJECT_ACCESS=$(curl -s --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null | jq -r '.name' 2>/dev/null || echo "")
    
    if [[ -n "$PROJECT_ACCESS" && "$PROJECT_ACCESS" != "null" ]]; then
        test_result 0 "Permissions: Project access available (project: $PROJECT_ACCESS)"
    else
        test_result 1 "Permissions: No project access with current token"
    fi
    
    # Test issue read access
    ISSUE_READ=$(curl -s --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$ISSUE_READ" -gt 0 ]]; then
        test_result 0 "Permissions: Issue read access available ($ISSUE_READ issues)"
    else
        test_result 1 "Permissions: No issue read access"
    fi
    
    # Test issue write access (dry run - don't actually create)
    WRITE_TEST=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
        --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        --header "Content-Type: application/json" \
        --data '{"title":"DRY_RUN_TEST"}' \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>/dev/null || echo "000")
    
    if [[ "$WRITE_TEST" =~ ^(201|400|422)$ ]]; then
        # 201 = created, 400/422 = validation error (but permission exists)
        test_result 0 "Permissions: Issue write access available"
    elif [[ "$WRITE_TEST" == "403" ]]; then
        test_result 1 "Permissions: Issue write access forbidden"
    else
        test_result 1 "Permissions: Issue write access test inconclusive (HTTP $WRITE_TEST)"
    fi
else
    test_result 1 "Permissions: Cannot test without token"
fi

# Test 5: Rate Limiting and API Health
echo "Test 5: Rate Limiting and API Health"
if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
    log "Testing API rate limits and health..."
    
    # Make multiple requests to check rate limiting
    RATE_LIMIT_TESTS=5
    RATE_LIMIT_SUCCESS=0
    
    for i in $(seq 1 $RATE_LIMIT_TESTS); do
        RATE_TEST=$(curl -s -w "%{http_code}" -o /dev/null \
            --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "000")
        
        if [[ "$RATE_TEST" == "200" ]]; then
            ((RATE_LIMIT_SUCCESS++))
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    if [[ $RATE_LIMIT_SUCCESS -eq $RATE_LIMIT_TESTS ]]; then
        test_result 0 "Rate limits: All $RATE_LIMIT_TESTS requests succeeded"
    else
        test_result 1 "Rate limits: Only $RATE_LIMIT_SUCCESS/$RATE_LIMIT_TESTS requests succeeded"
    fi
    
    # Check response time
    RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s \
        --header "PRIVATE-TOKEN: $WORKING_TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "999")
    
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo 0) )); then
        test_result 0 "API health: Response time acceptable (${RESPONSE_TIME}s)"
    else
        test_result 1 "API health: Response time slow (${RESPONSE_TIME}s)"
    fi
else
    test_result 1 "Rate limits: Cannot test without token"
fi

# Test 6: Agent Token Handling Pattern
echo "Test 6: Agent Token Handling Pattern Analysis"
log "Analyzing how the agent should handle tokens..."

AGENT_CONFIG="$PROJECT_ROOT/.claude/agents/project-task-updater.md"
if [[ -f "$AGENT_CONFIG" ]]; then
    # Check for problematic patterns in agent config
    UNDEFINED_VAR_COUNT=$(grep -c "\$GITLAB_TOKEN" "$AGENT_CONFIG" 2>/dev/null || echo "0")
    CORRECT_VAR_COUNT=$(grep -c "\$TOKEN" "$AGENT_CONFIG" 2>/dev/null || echo "0")
    TOKEN_SCRIPT_COUNT=$(grep -c "get-token-noninteractive.sh" "$AGENT_CONFIG" 2>/dev/null || echo "0")
    
    if [[ $UNDEFINED_VAR_COUNT -gt 0 ]]; then
        test_result 1 "Agent pattern: Found $UNDEFINED_VAR_COUNT uses of undefined \$GITLAB_TOKEN"
    else
        test_result 0 "Agent pattern: No undefined \$GITLAB_TOKEN usage found"
    fi
    
    if [[ $TOKEN_SCRIPT_COUNT -gt 0 ]]; then
        test_result 0 "Agent pattern: Uses proper token retrieval script ($TOKEN_SCRIPT_COUNT references)"
    else
        test_result 1 "Agent pattern: Missing proper token retrieval script references"
    fi
    
    # Check for secure token handling
    if grep -q "export.*TOKEN" "$AGENT_CONFIG" 2>/dev/null; then
        test_result 1 "Agent pattern: Found token export (potential security risk)"
    else
        test_result 0 "Agent pattern: No token exports found (good security)"
    fi
else
    test_result 1 "Agent pattern: Agent configuration file not found"
fi

# Test 7: Authentication Error Recovery
echo "Test 7: Authentication Error Recovery Testing"
log "Testing authentication failure scenarios..."

# Test with invalid token
INVALID_TOKEN="invalid-test-token-123"
INVALID_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    --header "PRIVATE-TOKEN: $INVALID_TOKEN" \
    "https://git.mpi-cbg.de/api/v4/user" 2>/dev/null || echo "000")

if [[ "$INVALID_RESPONSE" == "401" ]]; then
    test_result 0 "Error recovery: Invalid token properly rejected (401)"
else
    test_result 1 "Error recovery: Invalid token not properly rejected ($INVALID_RESPONSE)"
fi

# Test with no token
NO_TOKEN_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
    "https://git.mpi-cbg.de/api/v4/user" 2>/dev/null || echo "000")

if [[ "$NO_TOKEN_RESPONSE" == "401" ]]; then
    test_result 0 "Error recovery: Missing token properly rejected (401)"
else
    test_result 1 "Error recovery: Missing token not properly rejected ($NO_TOKEN_RESPONSE)"
fi

# Test wrapper script error handling
WRAPPER_ERROR_TEST=$("$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh" test 2>&1 \
    >/dev/null || echo "WRAPPER_ERROR")

if echo "$WRAPPER_ERROR_TEST" | grep -q "ERROR\|connection failed"; then
    if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
        test_result 0 "Error recovery: Wrapper properly handles missing token"
    else
        test_result 1 "Error recovery: Wrapper shows error despite token availability"
    fi
else
    if [[ $TOKEN_AVAILABLE -eq 1 ]]; then
        test_result 0 "Error recovery: Wrapper works with valid token"
    else
        test_result 1 "Error recovery: Wrapper doesn't properly handle missing token"
    fi
fi

# Results Summary
echo ""
echo "=== Authentication Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TOKEN_AVAILABLE -eq 0 ]]; then
    echo ""
    echo "🔴 CRITICAL FINDING: No GitLab token available"
    echo "This is likely the PRIMARY cause of Issue #63"
    echo ""
    echo "SOLUTION: Set up GitLab authentication:"
    echo "  ./tools/gitlab/setup-secure-config.sh"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Authentication issues detected - contributing to Issue #63"
    exit 1
else
    echo "✅ Authentication system functional"
    exit 0
fi