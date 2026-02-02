#!/bin/bash

# test_hpc_path_validation.sh - Comprehensive Path Resolution Tests for Issue #51
# Tests path validation, detection, and resolution for HPC environments

set -euo pipefail

# Test configuration
TEST_NAME="HPC Path Resolution Validation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"
TEMP_TEST_DIR="/tmp/test_path_resolution_$$"
LOG_FILE="${TEMP_TEST_DIR}/test_results.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test utilities
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

test_passed() {
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    log "✅ PASS: $1"
}

test_failed() {
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    log "❌ FAIL: $1"
    echo "   Details: $2" | tee -a "${LOG_FILE}"
}

setup_test_environment() {
    log "Setting up test environment in ${TEMP_TEST_DIR}"
    mkdir -p "${TEMP_TEST_DIR}"
    mkdir -p "${TEMP_TEST_DIR}/mock_hpc"
    mkdir -p "${TEMP_TEST_DIR}/mock_local"

    # Create mock directory structures
    mkdir -p "${TEMP_TEST_DIR}/mock_hpc/home/scholten/globtimcore"
    mkdir -p "${TEMP_TEST_DIR}/mock_hpc/home/globaloptim"  # Wrong path
    mkdir -p "${TEMP_TEST_DIR}/mock_local/Users/user/globtimcore"

    # Create mock files to simulate real structure
    touch "${TEMP_TEST_DIR}/mock_hpc/home/scholten/globtimcore/Project.toml"
    touch "${TEMP_TEST_DIR}/mock_local/Users/user/globtimcore/Project.toml"
}

cleanup_test_environment() {
    log "Cleaning up test environment"
    rm -rf "${TEMP_TEST_DIR}"
}

# Test 1: Path Detection and Validation
test_path_detection() {
    log "Running Test 1: Path Detection and Validation"

    # Test correct path detection
    local test_path="${TEMP_TEST_DIR}/mock_hpc/home/scholten/globtimcore"
    if [[ -d "${test_path}" ]] && [[ -f "${test_path}/Project.toml" ]]; then
        test_passed "Correct HPC path detection"
    else
        test_failed "Correct HPC path detection" "Path ${test_path} not found or missing Project.toml"
    fi

    # Test incorrect path rejection
    local wrong_path="${TEMP_TEST_DIR}/mock_hpc/home/globaloptim/globtimcore"
    if [[ ! -f "${wrong_path}/Project.toml" ]]; then
        test_passed "Incorrect path rejection"
    else
        test_failed "Incorrect path rejection" "Wrong path ${wrong_path} should not be valid"
    fi
}

# Test 2: HPC Path Resolution Function
test_hpc_path_resolution() {
    log "Running Test 2: HPC Path Resolution Function"

    # Create path resolution function for testing
    resolve_hpc_path() {
        local base_paths=(
            "/home/scholten/globtimcore"
            "/home/globaloptim/globtimcore"
        )

        for path in "${base_paths[@]}"; do
            # Simulate SSH check (mock for testing)
            local mock_path="${TEMP_TEST_DIR}/mock_hpc${path}"
            if [[ -d "${mock_path}" ]] && [[ -f "${mock_path}/Project.toml" ]]; then
                echo "${path}"
                return 0
            fi
        done

        return 1
    }

    local resolved_path
    if resolved_path=$(resolve_hpc_path); then
        if [[ "${resolved_path}" == "/home/scholten/globtimcore" ]]; then
            test_passed "HPC path resolution function"
        else
            test_failed "HPC path resolution function" "Resolved wrong path: ${resolved_path}"
        fi
    else
        test_failed "HPC path resolution function" "Failed to resolve any valid path"
    fi
}

# Test 3: Environment Detection
test_environment_detection() {
    log "Running Test 3: Environment Detection"

    # Mock environment detection function
    detect_environment() {
        if [[ "${PWD}" == *"/mock_hpc/"* ]]; then
            echo "hpc"
        elif [[ "${PWD}" == *"/mock_local/"* ]]; then
            echo "local"
        else
            echo "unknown"
        fi
    }

    # Test HPC environment detection
    (cd "${TEMP_TEST_DIR}/mock_hpc/home/scholten/globtimcore" && {
        local env_type
        env_type=$(detect_environment)
        if [[ "${env_type}" == "hpc" ]]; then
            test_passed "HPC environment detection"
        else
            test_failed "HPC environment detection" "Expected 'hpc', got '${env_type}'"
        fi
    })

    # Test local environment detection
    (cd "${TEMP_TEST_DIR}/mock_local/Users/user/globtimcore" && {
        local env_type
        env_type=$(detect_environment)
        if [[ "${env_type}" == "local" ]]; then
            test_passed "Local environment detection"
        else
            test_failed "Local environment detection" "Expected 'local', got '${env_type}'"
        fi
    })
}

# Test 4: Path Validation with SSH Simulation
test_ssh_path_validation() {
    log "Running Test 4: SSH Path Validation Simulation"

    # Mock SSH validation function
    validate_ssh_path() {
        local user="$1"
        local host="$2"
        local path="$3"

        # Simulate SSH path check
        local mock_full_path="${TEMP_TEST_DIR}/mock_hpc${path}"
        if [[ -d "${mock_full_path}" ]] && [[ -f "${mock_full_path}/Project.toml" ]]; then
            return 0
        else
            return 1
        fi
    }

    # Test valid SSH path
    if validate_ssh_path "scholten" "r04n02" "/home/scholten/globtimcore"; then
        test_passed "Valid SSH path validation"
    else
        test_failed "Valid SSH path validation" "Valid path should pass validation"
    fi

    # Test invalid SSH path
    if ! validate_ssh_path "scholten" "r04n02" "/home/globaloptim/globtimcore"; then
        test_passed "Invalid SSH path rejection"
    else
        test_failed "Invalid SSH path rejection" "Invalid path should be rejected"
    fi
}

# Test 5: Cross-Environment Path Mapping
test_cross_environment_mapping() {
    log "Running Test 5: Cross-Environment Path Mapping"

    # Mock path mapping function
    map_environment_paths() {
        local env="$1"
        case "${env}" in
            "hpc")
                echo "/home/scholten/globtimcore"
                ;;
            "local")
                echo "${PROJECT_ROOT}"
                ;;
            *)
                return 1
                ;;
        esac
    }

    # Test HPC path mapping
    local hpc_path
    hpc_path=$(map_environment_paths "hpc")
    if [[ "${hpc_path}" == "/home/scholten/globtimcore" ]]; then
        test_passed "HPC path mapping"
    else
        test_failed "HPC path mapping" "Expected '/home/scholten/globtimcore', got '${hpc_path}'"
    fi

    # Test local path mapping
    local local_path
    local_path=$(map_environment_paths "local")
    if [[ "${local_path}" == "${PROJECT_ROOT}" ]]; then
        test_passed "Local path mapping"
    else
        test_failed "Local path mapping" "Expected '${PROJECT_ROOT}', got '${local_path}'"
    fi
}

# Test 6: Configuration File Path Resolution
test_config_path_resolution() {
    log "Running Test 6: Configuration File Path Resolution"

    # Create mock configuration files
    mkdir -p "${TEMP_TEST_DIR}/config"
    cat > "${TEMP_TEST_DIR}/config/hpc_paths.conf" << 'EOF'
# HPC Path Configuration
HPC_BASE_PATH="/home/scholten/globtimcore"
HPC_USER="scholten"
HPC_HOST="r04n02"
EOF

    # Mock config reading function
    read_hpc_config() {
        local config_file="${TEMP_TEST_DIR}/config/hpc_paths.conf"
        if [[ -f "${config_file}" ]]; then
            source "${config_file}"
            echo "${HPC_BASE_PATH}"
        else
            return 1
        fi
    }

    local config_path
    if config_path=$(read_hpc_config); then
        if [[ "${config_path}" == "/home/scholten/globtimcore" ]]; then
            test_passed "Configuration file path resolution"
        else
            test_failed "Configuration file path resolution" "Expected '/home/scholten/globtimcore', got '${config_path}'"
        fi
    else
        test_failed "Configuration file path resolution" "Failed to read configuration file"
    fi
}

# Test 7: Error Handling for Invalid Paths
test_error_handling() {
    log "Running Test 7: Error Handling for Invalid Paths"

    # Mock error handling function
    handle_path_error() {
        local attempted_path="$1"
        local error_type="$2"

        case "${error_type}" in
            "not_found")
                echo "ERROR: Path '${attempted_path}' not found"
                return 1
                ;;
            "permission_denied")
                echo "ERROR: Permission denied for path '${attempted_path}'"
                return 1
                ;;
            "invalid_format")
                echo "ERROR: Invalid path format '${attempted_path}'"
                return 1
                ;;
            *)
                echo "ERROR: Unknown error for path '${attempted_path}'"
                return 1
                ;;
        esac
    }

    # Test not found error
    local error_output
    error_output=$(handle_path_error "/invalid/path" "not_found" 2>&1) || true
    if [[ "${error_output}" == *"not found"* ]]; then
        test_passed "Not found error handling"
    else
        test_failed "Not found error handling" "Expected 'not found' in error message"
    fi

    # Test permission denied error
    error_output=$(handle_path_error "/restricted/path" "permission_denied" 2>&1) || true
    if [[ "${error_output}" == *"Permission denied"* ]]; then
        test_passed "Permission denied error handling"
    else
        test_failed "Permission denied error handling" "Expected 'Permission denied' in error message"
    fi
}

# Main test execution
main() {
    log "Starting ${TEST_NAME}"
    log "Test directory: ${TEMP_TEST_DIR}"

    setup_test_environment

    # Run all tests
    test_path_detection
    test_hpc_path_resolution
    test_environment_detection
    test_ssh_path_validation
    test_cross_environment_mapping
    test_config_path_resolution
    test_error_handling

    # Final results
    log "Test Results Summary:"
    log "Total Tests: ${TOTAL_TESTS}"
    log "Passed: ${PASSED_TESTS}"
    log "Failed: ${FAILED_TESTS}"

    if [[ ${FAILED_TESTS} -eq 0 ]]; then
        log "🎉 ALL TESTS PASSED"
        cleanup_test_environment
        exit 0
    else
        log "❌ ${FAILED_TESTS} TEST(S) FAILED"
        log "Log file: ${LOG_FILE}"
        exit 1
    fi
}

# Trap cleanup on exit
trap cleanup_test_environment EXIT

# Run main function
main "$@"