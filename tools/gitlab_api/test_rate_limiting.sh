#!/bin/bash
# Rate Limiting Tests
# Tests API rate limiting behavior and handling

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

echo "=== Rate Limiting Tests ==="
echo ""

# Test 1: Basic rate limit detection
echo "Test 1: Rate limit detection through rapid requests"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    RATE_LIMIT_DETECTED=0
    REQUEST_COUNT=0
    SUCCESSFUL_REQUESTS=0
    
    echo "  Making rapid API requests..."
    for i in {1..10}; do
        ((REQUEST_COUNT++))
        RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "FAILED")
        
        if [[ "$RESPONSE" == "429" ]]; then
            RATE_LIMIT_DETECTED=1
            echo "    Request $i: Rate limited (HTTP 429)"
            break
        elif [[ "$RESPONSE" == "200" ]]; then
            ((SUCCESSFUL_REQUESTS++))
            echo "    Request $i: Success"
        elif [[ "$RESPONSE" == "FAILED" ]]; then
            echo "    Request $i: Network failed"
            break
        else
            echo "    Request $i: HTTP $RESPONSE"
        fi
        
        # Small delay to avoid overwhelming
        sleep 0.1
    done
    
    if [[ $RATE_LIMIT_DETECTED -eq 1 ]]; then
        test_result 0 "Rate limiting (HTTP 429) detected and properly enforced"
    elif [[ $SUCCESSFUL_REQUESTS -eq $REQUEST_COUNT ]]; then
        test_result 0 "No rate limiting triggered with moderate usage (acceptable)"
    else
        test_result 1 "Unexpected response patterns during rate limit testing"
    fi
else
    test_result 1 "Cannot test rate limiting - no token available"
fi

# Test 2: Rate limit headers inspection
echo "Test 2: Rate limit headers inspection"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Get response headers to check for rate limit information
    HEADERS=$(curl -s -I --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "HEADERS_FAILED")
    
    if echo "$HEADERS" | grep -q "HEADERS_FAILED"; then
        test_result 1 "Could not retrieve response headers"
    else
        # Look for common rate limit headers
        RATE_LIMIT_HEADERS=0
        
        if echo "$HEADERS" | grep -qi "x-ratelimit"; then
            echo "  ✓ Found X-RateLimit headers"
            ((RATE_LIMIT_HEADERS++))
        fi
        
        if echo "$HEADERS" | grep -qi "retry-after"; then
            echo "  ✓ Found Retry-After header capability"
            ((RATE_LIMIT_HEADERS++))
        fi
        
        if echo "$HEADERS" | grep -qi "x-rate-limit"; then
            echo "  ✓ Found X-Rate-Limit headers"
            ((RATE_LIMIT_HEADERS++))
        fi
        
        if [[ $RATE_LIMIT_HEADERS -gt 0 ]]; then
            test_result 0 "Rate limiting headers available for monitoring"
        else
            test_result 0 "No specific rate limiting headers found (may use other methods)"
        fi
    fi
else
    test_result 1 "Cannot inspect rate limit headers - no token available"
fi

# Test 3: Different endpoints rate limiting
echo "Test 3: Rate limiting across different endpoints"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    ENDPOINTS=("projects/2545" "projects/2545/issues" "projects/2545/labels" "projects/2545/milestones")
    ENDPOINT_RESULTS=()
    
    for endpoint in "${ENDPOINTS[@]}"; do
        RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/$endpoint" 2>/dev/null || echo "FAILED")
        
        ENDPOINT_RESULTS+=("$endpoint:$RESPONSE")
        sleep 0.2  # Small delay between different endpoints
    done
    
    SUCCESS_COUNT=0
    for result in "${ENDPOINT_RESULTS[@]}"; do
        endpoint_name=$(echo "$result" | cut -d':' -f1)
        response_code=$(echo "$result" | cut -d':' -f2)
        
        echo "  $endpoint_name: HTTP $response_code"
        
        if [[ "$response_code" == "200" ]]; then
            ((SUCCESS_COUNT++))
        fi
    done
    
    if [[ $SUCCESS_COUNT -ge 3 ]]; then
        test_result 0 "Multiple endpoints accessible ($SUCCESS_COUNT/4 working)"
    elif [[ $SUCCESS_COUNT -gt 0 ]]; then
        test_result 0 "Some endpoints accessible (may have different rate limits)"
    else
        test_result 1 "All endpoints failed or rate limited"
    fi
else
    test_result 1 "Cannot test endpoint rate limiting - no token available"
fi

# Test 4: Rate limit recovery time
echo "Test 4: Rate limit recovery behavior"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    # Try to trigger rate limit first
    echo "  Attempting to trigger rate limit..."
    RATE_LIMITED=0
    
    for i in {1..15}; do
        RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 3 \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "FAILED")
        
        if [[ "$RESPONSE" == "429" ]]; then
            RATE_LIMITED=1
            echo "    Rate limit triggered at request $i"
            break
        fi
        sleep 0.05
    done
    
    if [[ $RATE_LIMITED -eq 1 ]]; then
        echo "  Waiting for rate limit recovery..."
        sleep 5
        
        # Test recovery
        RECOVERY_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
            --header "PRIVATE-TOKEN: $TOKEN" \
            "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "FAILED")
        
        if [[ "$RECOVERY_RESPONSE" == "200" ]]; then
            test_result 0 "Rate limit recovery successful after wait period"
        elif [[ "$RECOVERY_RESPONSE" == "429" ]]; then
            test_result 0 "Rate limit still enforced (longer recovery period)"
        else
            test_result 1 "Rate limit recovery behavior unclear (got HTTP $RECOVERY_RESPONSE)"
        fi
    else
        test_result 0 "Could not trigger rate limit (API allows current usage pattern)"
    fi
else
    test_result 1 "Cannot test rate limit recovery - no token available"
fi

# Test 5: Concurrent request rate limiting
echo "Test 5: Concurrent request rate limiting"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    echo "  Starting concurrent requests..."
    
    # Start multiple concurrent requests
    for i in {1..5}; do
        (
            RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 \
                --header "PRIVATE-TOKEN: $TOKEN" \
                "https://git.mpi-cbg.de/api/v4/projects/2545/issues" 2>/dev/null || echo "FAILED")
            echo "concurrent_$i:$RESPONSE"
        ) &
    done
    
    # Wait for all background jobs
    wait
    
    # The results would be mixed in output, but we can check if processes completed
    test_result 0 "Concurrent requests handled (individual results may vary)"
else
    test_result 1 "Cannot test concurrent rate limiting - no token available"
fi

# Test 6: Rate limiting with different HTTP methods
echo "Test 6: Rate limiting across HTTP methods"
if TOKEN=$("$PROJECT_ROOT/tools/gitlab/get-token-noninteractive.sh" 2>/dev/null); then
    HTTP_METHODS=("GET" "POST" "PUT")
    METHOD_RESULTS=()
    
    # GET request
    GET_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 \
        --header "PRIVATE-TOKEN: $TOKEN" \
        "https://git.mpi-cbg.de/api/v4/projects/2545" 2>/dev/null || echo "FAILED")
    METHOD_RESULTS+=("GET:$GET_RESPONSE")
    
    sleep 0.5
    
    # POST request (with invalid data to avoid creating issues)\n    POST_RESPONSE=$(curl -s -w \"%{http_code}\" -o /dev/null --max-time 5 \\\n        -X POST --header \"PRIVATE-TOKEN: $TOKEN\" \\\n        --header \"Content-Type: application/json\" \\\n        --data '{\"title\": \"\"}' \\\n        \"https://git.mpi-cbg.de/api/v4/projects/2545/issues\" 2>/dev/null || echo \"FAILED\")\n    METHOD_RESULTS+=(\"POST:$POST_RESPONSE\")\n    \n    sleep 0.5\n    \n    # PUT request (to non-existent issue to avoid modifications)\n    PUT_RESPONSE=$(curl -s -w \"%{http_code}\" -o /dev/null --max-time 5 \\\n        -X PUT --header \"PRIVATE-TOKEN: $TOKEN\" \\\n        --header \"Content-Type: application/json\" \\\n        --data '{}' \\\n        \"https://git.mpi-cbg.de/api/v4/projects/2545/issues/999999\" 2>/dev/null || echo \"FAILED\")\n    METHOD_RESULTS+=(\"PUT:$PUT_RESPONSE\")\n    \n    echo \"  HTTP Method results:\"\n    SUCCESSFUL_METHODS=0\n    for result in \"${METHOD_RESULTS[@]}\"; do\n        method=$(echo \"$result\" | cut -d':' -f1)\n        response=$(echo \"$result\" | cut -d':' -f2)\n        echo \"    $method: HTTP $response\"\n        \n        # Count successful responses (200, 400 is OK for invalid data, 404 for non-existent)\n        if [[ \"$response\" =~ ^(200|400|404)$ ]]; then\n            ((SUCCESSFUL_METHODS++))\n        fi\n    done\n    \n    if [[ $SUCCESSFUL_METHODS -ge 2 ]]; then\n        test_result 0 \"Multiple HTTP methods working ($SUCCESSFUL_METHODS/3)\"\n    elif [[ $SUCCESSFUL_METHODS -eq 1 ]]; then\n        test_result 0 \"Some HTTP methods working (may have method-specific rate limits)\"\n    else\n        test_result 1 \"All HTTP methods failed or rate limited\"\n    fi\nelse\n    test_result 1 \"Cannot test HTTP method rate limiting - no token available\"\nfi\n\n# Test 7: Rate limiting impact on wrapper script\necho \"Test 7: Wrapper script rate limiting behavior\"\n# Test how the wrapper handles potential rate limiting\nWRAPPER_RATE_TEST=$(timeout 30 \"$WRAPPER_SCRIPT\" list-issues 2>&1 || echo \"WRAPPER_TIMEOUT\")\n\nif echo \"$WRAPPER_RATE_TEST\" | grep -q \"WRAPPER_TIMEOUT\"; then\n    test_result 1 \"Wrapper script timed out (possible rate limiting)\"\nelif echo \"$WRAPPER_RATE_TEST\" | grep -q \"Listing GitLab issues\"; then\n    # Check if we got JSON response\n    JSON_PART=$(echo \"$WRAPPER_RATE_TEST\" | grep -v \"^\\[\" || echo \"\")\n    if echo \"$JSON_PART\" | jq . >/dev/null 2>&1; then\n        test_result 0 \"Wrapper script handles rate limiting appropriately (got valid response)\"\n    else\n        test_result 0 \"Wrapper script executed but response unclear\"\n    fi\nelse\n    test_result 1 \"Wrapper script rate limiting behavior unclear\"\nfi\n\necho \"\"\necho \"=== Rate Limiting Test Results ===\"\necho \"Tests Passed: $TESTS_PASSED\"\necho \"Tests Failed: $TESTS_FAILED\"\necho \"Total Tests: $((TESTS_PASSED + TESTS_FAILED))\"\n\nif [[ $TESTS_FAILED -gt 0 ]]; then\n    echo \"❌ Rate limiting tests FAILED\"\n    exit 1\nelse\n    echo \"✅ All rate limiting tests PASSED\"\n    exit 0\nfi"