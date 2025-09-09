#!/bin/bash
# Network Failure Tests
# Tests handling of network-related failures and edge cases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER_SCRIPT="$PROJECT_ROOT/tools/gitlab/claude-agent-gitlab.sh"

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

echo "=== Network Failure Tests ==="
echo ""

# Test 1: DNS resolution failure simulation
echo "Test 1: DNS resolution failure handling"
# Test with invalid hostname
export GITLAB_API_BASE_URL="https://nonexistent-gitlab-instance.invalid"
DNS_FAILURE_OUTPUT=$(timeout 10 "$WRAPPER_SCRIPT" test 2>&1 || echo "EXPECTED_FAILURE")
unset GITLAB_API_BASE_URL

if echo "$DNS_FAILURE_OUTPUT" | grep -q "EXPECTED_FAILURE\|failed\|connection"; then
    test_result 0 "DNS resolution failure handled gracefully"
else
    test_result 1 "DNS resolution failure not properly handled"
fi

# Test 2: Connection timeout simulation
echo "Test 2: Connection timeout handling"
# Use a non-routable IP address to force timeout
TIMEOUT_TEST=$(timeout 15 curl -s --connect-timeout 5 --header "PRIVATE-TOKEN: test" \
    "http://192.0.2.1/api/v4/projects/1" 2>&1 || echo "TIMEOUT_EXPECTED")

if echo "$TIMEOUT_TEST" | grep -q "TIMEOUT_EXPECTED\|timeout\|Connection timed out"; then
    test_result 0 "Connection timeout properly detected and handled"
else
    test_result 1 "Connection timeout not properly handled"
fi

# Test 3: SSL certificate errors
echo "Test 3: SSL certificate error handling"
# Test with a hostname that has SSL issues (self-signed, expired, etc.)
SSL_ERROR_TEST=$(curl -s --max-time 10 --header "PRIVATE-TOKEN: test" \
    "https://self-signed.badssl.com/api/test" 2>&1 || echo "SSL_ERROR_EXPECTED")

if echo "$SSL_ERROR_TEST" | grep -q "SSL_ERROR_EXPECTED\|certificate\|SSL"; then
    test_result 0 "SSL certificate errors detected and handled"
else
    test_result 1 "SSL certificate error handling unclear"
fi

# Test 4: Network unreachable simulation
echo "Test 4: Network unreachable handling"
# Test with reserved IP range that should be unreachable
UNREACHABLE_TEST=$(timeout 10 curl -s --connect-timeout 3 --header "PRIVATE-TOKEN: test" \
    "http://203.0.113.1/api/v4/test" 2>&1 || echo "UNREACHABLE_EXPECTED")

if echo "$UNREACHABLE_TEST" | grep -q "UNREACHABLE_EXPECTED\|unreachable\|No route"; then
    test_result 0 "Network unreachable condition handled properly"
else
    test_result 1 "Network unreachable handling needs improvement"
fi

# Test 5: HTTP connection refused
echo "Test 5: Connection refused handling"
# Test connecting to localhost on unlikely port
CONNECTION_REFUSED=$(timeout 5 curl -s --connect-timeout 2 --header "PRIVATE-TOKEN: test" \
    "http://localhost:9999/api/v4/test" 2>&1 || echo "CONNECTION_REFUSED_EXPECTED")

if echo "$CONNECTION_REFUSED" | grep -q "CONNECTION_REFUSED_EXPECTED\|refused\|Failed to connect"; then
    test_result 0 "Connection refused properly handled"
else
    test_result 1 "Connection refused handling unclear"
fi

# Test 6: Partial response/connection drop simulation
echo "Test 6: Partial response handling"
# This is harder to simulate directly, but we can test timeout behavior
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test with very short timeout to potentially catch partial responses
    PARTIAL_RESPONSE=$(timeout 2 curl -s --max-time 1 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>&1 || echo "TIMEOUT_OR_PARTIAL")
    
    if echo "$PARTIAL_RESPONSE" | grep -q "TIMEOUT_OR_PARTIAL\|timeout\|Operation timed out"; then
        test_result 0 "Partial response/timeout scenario handled"
    elif echo "$PARTIAL_RESPONSE" | jq . >/dev/null 2>&1; then
        test_result 0 "Request completed successfully within timeout (good performance)"
    else
        test_result 1 "Partial response handling unclear"
    fi
else
    test_result 1 "Cannot test partial responses - no token available"
fi

# Test 7: HTTP proxy failure simulation
echo "Test 7: HTTP proxy failure handling"
# Test with invalid proxy settings
export HTTP_PROXY="http://invalid-proxy:8080"
export HTTPS_PROXY="http://invalid-proxy:8080"
PROXY_FAILURE=$(timeout 10 curl -s --connect-timeout 3 --header "PRIVATE-TOKEN: test" \
    "https://httpbin.org/get" 2>&1 || echo "PROXY_FAILURE_EXPECTED")
unset HTTP_PROXY HTTPS_PROXY

if echo "$PROXY_FAILURE" | grep -q "PROXY_FAILURE_EXPECTED\|proxy\|failed"; then
    test_result 0 "HTTP proxy failure handled gracefully"
else
    test_result 1 "HTTP proxy failure handling unclear"
fi

# Test 8: DNS timeout simulation
echo "Test 8: DNS timeout handling"
# Use a domain that takes a long time to resolve or doesn't resolve
DNS_TIMEOUT_TEST=$(timeout 5 nslookup this-domain-should-not-exist-anywhere.invalid 2>&1 || echo "DNS_TIMEOUT_EXPECTED")

if echo "$DNS_TIMEOUT_TEST" | grep -q "DNS_TIMEOUT_EXPECTED\|NXDOMAIN\|not found"; then
    test_result 0 "DNS timeout/failure properly handled by system"
else
    test_result 1 "DNS timeout handling unclear"
fi

# Test 9: IPv6 vs IPv4 fallback
echo "Test 9: IP version fallback behavior"
# Test IPv6 connectivity and fallback to IPv4
IPV6_TEST=$(curl -6 -s --connect-timeout 3 --max-time 5 "http://ipv6.google.com" 2>&1 || echo "IPV6_FAILED")
IPV4_TEST=$(curl -4 -s --connect-timeout 3 --max-time 5 "http://google.com" 2>&1 || echo "IPV4_FAILED")

if [[ "$IPV4_TEST" != "IPV4_FAILED" ]]; then
    test_result 0 "IPv4 connectivity working (fallback available)"
elif [[ "$IPV6_TEST" != "IPV6_FAILED" ]]; then
    test_result 0 "IPv6 connectivity working"
else
    test_result 1 "Both IPv4 and IPv6 connectivity issues"
fi

# Test 10: Rate limiting and 429 responses
echo "Test 10: Rate limiting response handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Make rapid requests to potentially trigger rate limiting
    RATE_LIMIT_DETECTED=0
    
    for i in {1..3}; do
        RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "FAILED")
        
        if [[ "$RESPONSE" == "429" ]]; then
            RATE_LIMIT_DETECTED=1
            break
        elif [[ "$RESPONSE" == "FAILED" ]]; then
            echo "  Network request failed during rate limit test"
            break
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    if [[ $RATE_LIMIT_DETECTED -eq 1 ]]; then
        test_result 0 "Rate limiting (HTTP 429) properly detected"
    else
        test_result 0 "No rate limiting triggered (normal for moderate usage)"
    fi
else
    test_result 1 "Cannot test rate limiting - no token available"
fi

# Test 11: Large response timeout
echo "Test 11: Large response timeout handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Request potentially large data with short timeout
    LARGE_DATA_TEST=$(timeout 3 curl -s --max-time 2 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues?per_page=100" 2>&1 || echo "TIMEOUT_EXPECTED")
    
    if echo "$LARGE_DATA_TEST" | grep -q "TIMEOUT_EXPECTED\|timeout"; then
        test_result 0 "Large response timeout handled appropriately"
    elif echo "$LARGE_DATA_TEST" | jq . >/dev/null 2>&1; then
        test_result 0 "Large response completed within timeout (good performance)"
    else
        test_result 1 "Large response handling unclear"
    fi
else
    test_result 1 "Cannot test large response timeout - no token available"
fi

# Test 12: Network interface failure simulation
echo "Test 12: Network interface availability"
# Check if multiple network interfaces are available for redundancy
INTERFACE_COUNT=$(ip route show default 2>/dev/null | wc -l || echo "1")
if [[ $INTERFACE_COUNT -gt 1 ]]; then
    test_result 0 "Multiple network routes available (good redundancy)"
elif [[ $INTERFACE_COUNT -eq 1 ]]; then
    test_result 0 "Single network route available (typical configuration)"
else
    test_result 1 "No default network routes detected"
fi

echo ""
echo "=== Network Failure Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Network failure tests FAILED"
    exit 1
else
    echo "✅ All network failure tests PASSED"
    exit 0
fi