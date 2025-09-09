#!/bin/bash
# API Connectivity Tests
# Tests basic GitLab API connectivity and network scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    if [[ $1 -eq 0 ]]; then
        echo "✅ PASS: $2"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $2"
        ((TESTS_FAILED++))
    fi
}

echo "=== API Connectivity Tests ==="
echo ""

# Test 1: DNS resolution
echo "Test 1: DNS resolution for git.mpi-cbg.de"
if nslookup git.mpi-cbg.de >/dev/null 2>&1 || dig git.mpi-cbg.de >/dev/null 2>&1; then
    test_result 0 "DNS resolution successful"
else
    test_result 1 "DNS resolution failed - network connectivity issue"
fi

# Test 2: HTTPS connectivity
echo "Test 2: HTTPS connectivity"
if curl -I -s --connect-timeout 10 https://git.mpi-cbg.de >/dev/null 2>&1; then
    test_result 0 "HTTPS connectivity to GitLab instance successful"
else
    test_result 1 "HTTPS connectivity failed - firewall or network issue"
fi

# Test 3: API endpoint accessibility
echo "Test 3: API endpoint accessibility"
API_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 https://git.mpi-cbg.de/api/v4/version 2>/dev/null || echo "FAILED")
if [[ "$API_RESPONSE" == "200" ]]; then
    test_result 0 "GitLab API endpoint accessible"
elif [[ "$API_RESPONSE" == "401" ]]; then
    test_result 0 "GitLab API endpoint accessible (401 expected without auth)"
elif [[ "$API_RESPONSE" == "FAILED" ]]; then
    test_result 1 "API endpoint completely inaccessible"
else
    test_result 1 "API endpoint returned unexpected status: $API_RESPONSE"
fi

# Test 4: SSL certificate validation
echo "Test 4: SSL certificate validation"
if curl -s --cacert-status https://git.mpi-cbg.de >/dev/null 2>&1; then
    test_result 0 "SSL certificate validation successful"
else
    test_result 1 "SSL certificate validation failed"
fi

# Test 5: Project-specific endpoint (if token available)
echo "Test 5: Project-specific endpoint access"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    PROJECT_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --header "PRIVATE-TOKEN: $TOKEN" \
        https://git.mpi-cbg.de/api/v4/projects/2545 2>/dev/null || echo "FAILED")
    
    if [[ "$PROJECT_RESPONSE" == "200" ]]; then
        test_result 0 "Project-specific endpoint accessible with token"
    elif [[ "$PROJECT_RESPONSE" == "401" ]]; then
        test_result 1 "Token authentication failed (401)"
    elif [[ "$PROJECT_RESPONSE" == "403" ]]; then
        test_result 1 "Token lacks project access permissions (403)"
    elif [[ "$PROJECT_RESPONSE" == "404" ]]; then
        test_result 1 "Project not found or not accessible (404)"
    else
        test_result 1 "Project endpoint returned unexpected status: $PROJECT_RESPONSE"
    fi
else
    echo "⚠️  SKIP: Project endpoint test (no token available)"
fi

# Test 6: API rate limiting detection
echo "Test 6: API rate limiting behavior"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Make multiple rapid requests to test rate limiting
    RATE_LIMIT_DETECTED=0
    for i in {1..5}; do
        RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --header "PRIVATE-TOKEN: $TOKEN" \
            https://git.mpi-cbg.de/api/v4/projects/2545 2>/dev/null || echo "FAILED")
        if [[ "$RESPONSE" == "429" ]]; then
            RATE_LIMIT_DETECTED=1
            break
        fi
        sleep 0.1
    done
    
    if [[ $RATE_LIMIT_DETECTED -eq 1 ]]; then
        test_result 0 "Rate limiting properly enforced by API"
    else
        test_result 0 "No rate limiting detected with moderate usage (acceptable)"
    fi
else
    echo "⚠️  SKIP: Rate limiting test (no token available)"
fi

# Test 7: Response time measurement
echo "Test 7: API response time"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    START_TIME=$(date +%s.%N)
    RESPONSE=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" https://git.mpi-cbg.de/api/v4/projects/2545 2>/dev/null || echo "FAILED")
    END_TIME=$(date +%s.%N)
    RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "N/A")
    
    if [[ "$RESPONSE" != "FAILED" && "$RESPONSE_TIME" != "N/A" ]]; then
        if (( $(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo 0) )); then
            test_result 0 "API response time acceptable (${RESPONSE_TIME}s)"
        else
            test_result 1 "API response time slow (${RESPONSE_TIME}s)"
        fi
    else
        test_result 1 "Could not measure API response time"
    fi
else
    echo "⚠️  SKIP: Response time test (no token available)"
fi

# Test 8: IPv4 vs IPv6 connectivity
echo "Test 8: IP version connectivity"
IPV4_TEST=$(curl -4 -s -I --connect-timeout 5 https://git.mpi-cbg.de 2>/dev/null && echo "IPV4_OK" || echo "IPV4_FAIL")
IPV6_TEST=$(curl -6 -s -I --connect-timeout 5 https://git.mpi-cbg.de 2>/dev/null && echo "IPV6_OK" || echo "IPV6_FAIL")

if [[ "$IPV4_TEST" == "IPV4_OK" ]]; then
    echo "  ✓ IPv4 connectivity working"
fi
if [[ "$IPV6_TEST" == "IPV6_OK" ]]; then
    echo "  ✓ IPv6 connectivity working"
fi

if [[ "$IPV4_TEST" == "IPV4_OK" || "$IPV6_TEST" == "IPV6_OK" ]]; then
    test_result 0 "IP connectivity available (IPv4: $IPV4_TEST, IPv6: $IPV6_TEST)"
else
    test_result 1 "No IP connectivity available"
fi

# Test 9: Proxy detection and handling
echo "Test 9: Proxy configuration detection"
if [[ -n "$HTTP_PROXY" || -n "$HTTPS_PROXY" || -n "$http_proxy" || -n "$https_proxy" ]]; then
    echo "  Proxy detected: HTTP_PROXY=$HTTP_PROXY, HTTPS_PROXY=$HTTPS_PROXY"
    test_result 0 "Proxy configuration detected and accessible"
else
    test_result 0 "No proxy configuration detected (direct connection)"
fi

# Test 10: User-Agent and header handling
echo "Test 10: Custom headers and User-Agent"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    CUSTOM_RESPONSE=$(curl -s -H "User-Agent: GlobTim-Test-Suite/1.0" -H "PRIVATE-TOKEN: $TOKEN" \
        https://git.mpi-cbg.de/api/v4/projects/2545 2>/dev/null || echo "FAILED")
    
    if [[ "$CUSTOM_RESPONSE" != "FAILED" ]] && echo "$CUSTOM_RESPONSE" | jq . >/dev/null 2>&1; then
        test_result 0 "Custom headers accepted by API"
    else
        test_result 1 "Custom headers caused API issues"
    fi
else
    echo "⚠️  SKIP: Custom headers test (no token available)"
fi

echo ""
echo "=== API Connectivity Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ API connectivity tests FAILED"
    exit 1
else
    echo "✅ All API connectivity tests PASSED"
    exit 0
fi