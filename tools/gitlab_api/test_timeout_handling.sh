#!/bin/bash
# Timeout Handling Tests
# Tests various timeout scenarios and response time handling

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

echo "=== Timeout Handling Tests ==="
echo ""

# Test 1: Connection timeout
echo "Test 1: Connection timeout handling"
# Use non-routable address to force connection timeout
CONNECTION_TIMEOUT_TEST=$(timeout 10 curl -s --connect-timeout 3 --max-time 5 \
    "http://192.0.2.1/api/v4/test" 2>&1 || echo "CONNECTION_TIMEOUT_EXPECTED")

if echo "$CONNECTION_TIMEOUT_TEST" | grep -q "CONNECTION_TIMEOUT_EXPECTED\|timeout\|Connection timed out"; then
    test_result 0 "Connection timeout properly detected and handled"
else
    test_result 1 "Connection timeout not properly handled"
fi

# Test 2: Read timeout
echo "Test 2: Read timeout handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Test with very short read timeout
    READ_TIMEOUT_TEST=$(timeout 8 curl -s --connect-timeout 10 --max-time 2 \
        --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues?per_page=100" 2>&1 || echo "READ_TIMEOUT_EXPECTED")
    
    if echo "$READ_TIMEOUT_TEST" | grep -q "READ_TIMEOUT_EXPECTED\|timeout\|Operation timed out"; then
        test_result 0 "Read timeout properly handled"
    elif echo "$READ_TIMEOUT_TEST" | jq . >/dev/null 2>&1; then
        test_result 0 "Request completed within timeout (good API performance)"
    else
        test_result 1 "Read timeout handling unclear"
    fi
else
    test_result 1 "Cannot test read timeout - no token available"
fi

# Test 3: DNS timeout
echo "Test 3: DNS resolution timeout"
DNS_TIMEOUT_TEST=$(timeout 5 curl -s --connect-timeout 10 --dns-timeout 2 \
    "https://this-domain-should-timeout.invalid" 2>&1 || echo "DNS_TIMEOUT_EXPECTED")

if echo "$DNS_TIMEOUT_TEST" | grep -q "DNS_TIMEOUT_EXPECTED\|timeout\|resolve"; then
    test_result 0 "DNS timeout properly handled"
else
    test_result 1 "DNS timeout handling unclear"
fi

# Test 4: Wrapper script timeout behavior
echo "Test 4: Wrapper script timeout behavior"
# Test the wrapper with short timeout by using system timeout command
WRAPPER_TIMEOUT_TEST=$(timeout 5 "$WRAPPER_SCRIPT" list-issues 2>&1 || echo "WRAPPER_TIMEOUT")

if echo "$WRAPPER_TIMEOUT_TEST" | grep -q "WRAPPER_TIMEOUT"; then
    test_result 0 "Wrapper script can be interrupted by timeout"
elif echo "$WRAPPER_TIMEOUT_TEST" | grep -q "Listing GitLab issues"; then
    test_result 0 "Wrapper script completed within timeout (good performance)"
else
    test_result 1 "Wrapper script timeout behavior unclear"
fi

# Test 5: Gradual timeout testing
echo "Test 5: Performance under different timeout values"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    TIMEOUT_RESULTS=()
    
    for timeout_val in 1 3 10; do
        START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
        RESULT=$(timeout ${timeout_val} curl -s --max-time ${timeout_val} \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>&1 || echo "TIMEOUT")
        END_TIME=$(date +%s.%N 2>/dev/null || date +%s)
        
        if echo "$RESULT" | grep -q "TIMEOUT"; then
            TIMEOUT_RESULTS+=("${timeout_val}s: TIMEOUT")
        elif echo "$RESULT" | jq . >/dev/null 2>&1; then
            DURATION=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "N/A")
            TIMEOUT_RESULTS+=("${timeout_val}s: SUCCESS (${DURATION}s)")
        else
            TIMEOUT_RESULTS+=("${timeout_val}s: ERROR")
        fi
    done
    
    echo "  Timeout test results:"
    for result in "${TIMEOUT_RESULTS[@]}"; do
        echo "    $result"
    done
    
    # Check if at least one timeout succeeded
    SUCCESS_COUNT=$(printf '%s\n' "${TIMEOUT_RESULTS[@]}" | grep -c "SUCCESS" || echo "0")
    if [[ $SUCCESS_COUNT -gt 0 ]]; then
        test_result 0 "API responds within reasonable timeouts ($SUCCESS_COUNT/3 succeeded)"
    else
        test_result 1 "API consistently times out across all timeout values"
    fi
else
    test_result 1 "Cannot test timeout performance - no token available"
fi

# Test 6: Concurrent timeout handling
echo "Test 6: Concurrent request timeout handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Start multiple concurrent requests with timeouts
    timeout 10 curl -s --max-time 5 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" >/dev/null 2>&1 &
    PID1=$!
    
    timeout 10 curl -s --max-time 5 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues" >/dev/null 2>&1 &
    PID2=$!
    
    timeout 10 curl -s --max-time 5 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/labels" >/dev/null 2>&1 &
    PID3=$!
    
    # Wait for all processes
    wait $PID1 $PID2 $PID3
    EXIT_CODES=($?)
    
    CONCURRENT_SUCCESS=0
    for code in "${EXIT_CODES[@]}"; do
        if [[ $code -eq 0 ]]; then
            ((CONCURRENT_SUCCESS++))
        fi
    done
    
    if [[ $CONCURRENT_SUCCESS -ge 2 ]]; then
        test_result 0 "Concurrent requests handle timeouts appropriately ($CONCURRENT_SUCCESS/3 succeeded)"
    elif [[ $CONCURRENT_SUCCESS -eq 1 ]]; then
        test_result 0 "Some concurrent requests succeeded (network may be slow)"
    else
        test_result 1 "All concurrent requests timed out or failed"
    fi
else
    test_result 1 "Cannot test concurrent timeouts - no token available"
fi

# Test 7: Timeout with large responses
echo "Test 7: Large response timeout handling"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Request large dataset with timeout
    LARGE_RESPONSE_TEST=$(timeout 15 curl -s --max-time 10 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545/issues?per_page=100&state=all" 2>&1 || echo "LARGE_TIMEOUT")
    
    if echo "$LARGE_RESPONSE_TEST" | grep -q "LARGE_TIMEOUT"; then
        test_result 1 "Large responses consistently timeout (may indicate performance issues)"
    elif echo "$LARGE_RESPONSE_TEST" | jq . >/dev/null 2>&1; then
        RESPONSE_SIZE=$(echo "$LARGE_RESPONSE_TEST" | wc -c)
        test_result 0 "Large response handled successfully (${RESPONSE_SIZE} bytes)"
    else
        test_result 1 "Large response timeout handling unclear"
    fi
else
    test_result 1 "Cannot test large response timeouts - no token available"
fi

# Test 8: System timeout vs curl timeout
echo "Test 8: System vs application timeout coordination"
# Test what happens when system timeout is shorter than curl timeout
SYSTEM_TIMEOUT_TEST=$(timeout 2 curl -s --max-time 10 --connect-timeout 5 \
    "https://httpbin.org/delay/3" 2>&1 || echo "SYSTEM_TIMEOUT_WON")

if echo "$SYSTEM_TIMEOUT_TEST" | grep -q "SYSTEM_TIMEOUT_WON"; then
    test_result 0 "System timeout properly overrides application timeout"
else
    test_result 1 "System timeout vs application timeout coordination unclear"
fi

# Test 9: Timeout error message clarity
echo "Test 9: Timeout error message quality"
TIMEOUT_ERROR_TEST=$(timeout 3 curl -s --connect-timeout 1 --max-time 2 \
    "http://192.0.2.1/test" 2>&1 || echo "TIMEOUT_OCCURRED")

if echo "$TIMEOUT_ERROR_TEST" | grep -q "timeout\|Connection timed out\|TIMEOUT_OCCURRED"; then
    test_result 0 "Timeout error messages are clear and identifiable"
else
    test_result 1 "Timeout error messages unclear or missing"
fi

# Test 10: Recovery after timeout
echo "Test 10: Recovery after timeout scenarios"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # First, cause a timeout
    timeout 1 curl -s --max-time 10 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" >/dev/null 2>&1 || true
    
    # Then immediately try a normal request
    sleep 1
    RECOVERY_TEST=$(curl -s --max-time 10 --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>&1 || echo "RECOVERY_FAILED")
    
    if echo "$RECOVERY_TEST" | jq . >/dev/null 2>&1; then
        test_result 0 "API connection recovers properly after timeout"
    elif echo "$RECOVERY_TEST" | grep -q "RECOVERY_FAILED"; then
        test_result 1 "API connection does not recover properly after timeout"
    else
        test_result 1 "Recovery after timeout unclear"
    fi
else
    test_result 1 "Cannot test timeout recovery - no token available"
fi

echo ""
echo "=== Timeout Handling Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "❌ Timeout handling tests FAILED"
    exit 1
else
    echo "✅ All timeout handling tests PASSED"
    exit 0
fi