#!/bin/bash
# Test Framework for Defensive CSV Loading and Result Validation - Issue #84
# Test-First Implementation: Comprehensive CSV validation and error handling
# Addresses interface bugs like df_critical.val vs df_critical.z

set -e

# Test configuration
TEST_NAME="defensive_csv_validation"
TEST_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test environment setup
TEMP_DIR=$(mktemp -d)
TEST_CSV_DIR="$TEMP_DIR/test_csv_files"
TEST_LOGS_DIR="$TEMP_DIR/test_logs"

mkdir -p "$TEST_CSV_DIR" "$TEST_LOGS_DIR"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test logging functions
test_log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$TEST_NAME] [$level] $message" | tee -a "$TEST_LOGS_DIR/test.log"
}

test_info() {
    test_log "INFO" "$@"
    echo -e "${BOLD}${GREEN}[CSV-TEST-INFO]${NC} $*"
}

test_warning() {
    test_log "WARN" "$@"
    echo -e "${BOLD}${YELLOW}[CSV-TEST-WARNING]${NC} $*"
}

test_error() {
    test_log "ERROR" "$@"
    echo -e "${BOLD}${RED}[CSV-TEST-ERROR]${NC} $*"
}

test_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        test_log "DEBUG" "$@"
        echo -e "${BOLD}${BLUE}[CSV-TEST-DEBUG]${NC} $*"
    fi
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        test_error "  Expected: '$expected'"
        test_error "  Actual: '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"

    if [[ -f "$file_path" ]]; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        return 1
    fi
}

assert_validation_success() {
    local validator_script="$1"
    local csv_file="$2"
    local message="${3:-CSV validation should succeed}"

    if "$validator_script" "$csv_file" >/dev/null 2>&1; then
        test_info "✅ PASS: $message"
        return 0
    else
        test_error "❌ FAIL: $message"
        return 1
    fi
}

assert_validation_failure() {
    local validator_script="$1"
    local csv_file="$2"
    local expected_error="$3"
    local message="${4:-CSV validation should fail with expected error}"

    local output
    if output=$("$validator_script" "$csv_file" 2>&1); then
        test_error "❌ FAIL: $message (validation unexpectedly succeeded)"
        return 1
    else
        if echo "$output" | grep -q "$expected_error"; then
            test_info "✅ PASS: $message"
            return 0
        else
            test_error "❌ FAIL: $message (wrong error message)"
            test_error "  Expected error pattern: '$expected_error'"
            test_error "  Actual output: '$output'"
            return 1
        fi
    fi
}

# Create mock defensive CSV validator
create_defensive_csv_validator() {
    local validator_script="$TEMP_DIR/defensive_csv_validator.sh"

    cat > "$validator_script" << 'EOF'
#!/bin/bash
# Defensive CSV Validator for Robust Job Management - Issue #84
# Validates CSV structure, headers, and data integrity

set -e

CSV_FILE="${1:-}"
VALIDATION_MODE="${2:-strict}"

if [[ -z "$CSV_FILE" ]]; then
    echo "ERROR: CSV file path required"
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: CSV file not found: $CSV_FILE"
    exit 1
fi

# Check file is not empty
if [[ ! -s "$CSV_FILE" ]]; then
    echo "ERROR: CSV file is empty: $CSV_FILE"
    exit 1
fi

# Validate CSV format based on expected patterns
validate_critical_points_csv() {
    local file="$1"
    local header=$(head -n1 "$file")

    # Check for correct header format (Issue #84: df_critical.val vs df_critical.z)
    case "$header" in
        "degree,critical_points,l2_norm"|"degree,critical_points,z")
            # Valid headers
            ;;
        "degree,critical_points,val")
            echo "ERROR: Interface bug detected - using 'val' instead of 'z' (Issue #84 pattern)"
            exit 1
            ;;
        *)
            echo "ERROR: Invalid CSV header format"
            echo "Expected: degree,critical_points,l2_norm or degree,critical_points,z"
            echo "Found: $header"
            exit 1
            ;;
    esac

    # Validate data rows
    local line_num=1
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip header
        if [[ $line_num -eq 2 ]]; then
            continue
        fi

        # Check for empty lines
        if [[ -z "$line" ]]; then
            if [[ "$VALIDATION_MODE" == "strict" ]]; then
                echo "ERROR: Empty line found at line $line_num"
                exit 1
            else
                continue
            fi
        fi

        # Validate field count
        local field_count=$(echo "$line" | tr ',' '\n' | wc -l)
        if [[ $field_count -ne 3 ]]; then
            echo "ERROR: Invalid field count at line $line_num"
            echo "Expected: 3 fields, Found: $field_count"
            echo "Line: $line"
            exit 1
        fi

        # Validate field types
        local degree=$(echo "$line" | cut -d',' -f1)
        local critical_points=$(echo "$line" | cut -d',' -f2)
        local l2_norm=$(echo "$line" | cut -d',' -f3)

        # Check degree is integer
        if ! [[ "$degree" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid degree value at line $line_num: '$degree' (should be integer)"
            exit 1
        fi

        # Check critical_points is integer
        if ! [[ "$critical_points" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid critical_points value at line $line_num: '$critical_points' (should be integer)"
            exit 1
        fi

        # Check l2_norm is number (integer or float)
        if ! [[ "$l2_norm" =~ ^[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
            echo "ERROR: Invalid l2_norm value at line $line_num: '$l2_norm' (should be number)"
            exit 1
        fi

    done < <(tail -n +2 "$file")

    echo "CSV validation passed: $file"
}

validate_experiment_config_json() {
    local file="$1"

    # Basic JSON validation
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        echo "ERROR: Invalid JSON format in $file"
        exit 1
    fi

    # Check required fields
    local required_fields=("experiment_id" "timestamp" "parameters")
    for field in "${required_fields[@]}"; do
        if ! grep -q "\"$field\"" "$file"; then
            echo "ERROR: Missing required field '$field' in $file"
            exit 1
        fi
    done

    echo "JSON validation passed: $file"
}

# Determine validation type based on file extension
case "$CSV_FILE" in
    *.csv)
        validate_critical_points_csv "$CSV_FILE"
        ;;
    *.json)
        validate_experiment_config_json "$CSV_FILE"
        ;;
    *)
        echo "ERROR: Unsupported file type: $CSV_FILE"
        exit 1
        ;;
esac
EOF

    chmod +x "$validator_script"
    echo "$validator_script"
}

# Test data creation functions
create_valid_csv() {
    local csv_file="$1"

    cat > "$csv_file" << 'EOF'
degree,critical_points,l2_norm
4,28,0.001234
5,35,0.002456
6,42,0.001789
7,49,0.003012
8,56,0.002345
EOF
}

create_interface_bug_csv() {
    local csv_file="$1"

    # Create CSV with interface bug (val instead of z)
    cat > "$csv_file" << 'EOF'
degree,critical_points,val
4,28,0.001234
5,35,0.002456
6,42,0.001789
EOF
}

create_invalid_header_csv() {
    local csv_file="$1"

    cat > "$csv_file" << 'EOF'
invalid,header,format
4,28,0.001234
5,35,0.002456
EOF
}

create_corrupted_data_csv() {
    local csv_file="$1"

    cat > "$csv_file" << 'EOF'
degree,critical_points,l2_norm
4,28,0.001234
not_a_number,35,0.002456
6,invalid_data,0.001789
7,49,not_a_float
EOF
}

create_incomplete_csv() {
    local csv_file="$1"

    cat > "$csv_file" << 'EOF'
degree,critical_points,l2_norm
4,28
5,35,0.002456,extra_field
6
EOF
}

create_empty_csv() {
    local csv_file="$1"
    touch "$csv_file"
}

create_valid_json() {
    local json_file="$1"

    cat > "$json_file" << 'EOF'
{
    "experiment_id": "test_experiment_20250927_123456",
    "timestamp": "2025-09-27T12:34:56Z",
    "parameters": {
        "degree_range": [4, 8],
        "sample_count": 12,
        "domain_size": 0.1
    },
    "environment": "hpc",
    "status": "completed"
}
EOF
}

create_invalid_json() {
    local json_file="$1"

    cat > "$json_file" << 'EOF'
{
    "experiment_id": "test_experiment_20250927_123456",
    "timestamp": "2025-09-27T12:34:56Z",
    "parameters": {
        "degree_range": [4, 8],
        "sample_count": 12,
        "domain_size": 0.1
    },
    "environment": "hpc",
    "status": "completed"
    # Missing closing brace - invalid JSON
EOF
}

# Test cases for defensive CSV validation

test_valid_csv_validation() {
    test_info "🧪 Testing validation of valid CSV files"

    local validator=$(create_defensive_csv_validator)
    local valid_csv="$TEST_CSV_DIR/valid_critical_points.csv"

    create_valid_csv "$valid_csv"

    assert_validation_success "$validator" "$valid_csv" "Valid CSV should pass validation"

    test_info "✅ Valid CSV validation test passed"
}

test_interface_bug_detection() {
    test_info "🧪 Testing detection of interface bugs (Issue #84 pattern)"

    local validator=$(create_defensive_csv_validator)
    local buggy_csv="$TEST_CSV_DIR/interface_bug_critical_points.csv"

    create_interface_bug_csv "$buggy_csv"

    assert_validation_failure "$validator" "$buggy_csv" "Interface bug detected.*val.*instead of.*z" \
        "CSV with interface bug should be detected and rejected"

    test_info "✅ Interface bug detection test passed"
}

test_invalid_header_detection() {
    test_info "🧪 Testing detection of invalid CSV headers"

    local validator=$(create_defensive_csv_validator)
    local invalid_csv="$TEST_CSV_DIR/invalid_header.csv"

    create_invalid_header_csv "$invalid_csv"

    assert_validation_failure "$validator" "$invalid_csv" "Invalid CSV header format" \
        "CSV with invalid header should be rejected"

    test_info "✅ Invalid header detection test passed"
}

test_data_corruption_detection() {
    test_info "🧪 Testing detection of corrupted data in CSV files"

    local validator=$(create_defensive_csv_validator)
    local corrupted_csv="$TEST_CSV_DIR/corrupted_data.csv"

    create_corrupted_data_csv "$corrupted_csv"

    assert_validation_failure "$validator" "$corrupted_csv" "Invalid.*value" \
        "CSV with corrupted data should be rejected"

    test_info "✅ Data corruption detection test passed"
}

test_incomplete_data_detection() {
    test_info "🧪 Testing detection of incomplete data rows"

    local validator=$(create_defensive_csv_validator)
    local incomplete_csv="$TEST_CSV_DIR/incomplete_data.csv"

    create_incomplete_csv "$incomplete_csv"

    assert_validation_failure "$validator" "$incomplete_csv" "Invalid field count" \
        "CSV with incomplete data should be rejected"

    test_info "✅ Incomplete data detection test passed"
}

test_empty_file_detection() {
    test_info "🧪 Testing detection of empty CSV files"

    local validator=$(create_defensive_csv_validator)
    local empty_csv="$TEST_CSV_DIR/empty_file.csv"

    create_empty_csv "$empty_csv"

    assert_validation_failure "$validator" "$empty_csv" "CSV file is empty" \
        "Empty CSV file should be rejected"

    test_info "✅ Empty file detection test passed"
}

test_missing_file_detection() {
    test_info "🧪 Testing detection of missing CSV files"

    local validator=$(create_defensive_csv_validator)
    local missing_csv="$TEST_CSV_DIR/nonexistent_file.csv"

    assert_validation_failure "$validator" "$missing_csv" "CSV file not found" \
        "Missing CSV file should be detected"

    test_info "✅ Missing file detection test passed"
}

test_json_validation() {
    test_info "🧪 Testing JSON configuration file validation"

    local validator=$(create_defensive_csv_validator)
    local valid_json="$TEST_CSV_DIR/valid_config.json"
    local invalid_json="$TEST_CSV_DIR/invalid_config.json"

    create_valid_json "$valid_json"
    create_invalid_json "$invalid_json"

    assert_validation_success "$validator" "$valid_json" "Valid JSON should pass validation"
    assert_validation_failure "$validator" "$invalid_json" "Invalid JSON format" \
        "Invalid JSON should be rejected"

    test_info "✅ JSON validation test passed"
}

test_validation_modes() {
    test_info "🧪 Testing different validation modes (strict vs permissive)"

    local validator=$(create_defensive_csv_validator)
    local csv_with_empty_lines="$TEST_CSV_DIR/csv_with_empty_lines.csv"

    cat > "$csv_with_empty_lines" << 'EOF'
degree,critical_points,l2_norm
4,28,0.001234

5,35,0.002456

6,42,0.001789
EOF

    # Test strict mode (should fail due to empty lines)
    if "$validator" "$csv_with_empty_lines" "strict" 2>&1 | grep -q "Empty line found"; then
        test_info "✅ Strict mode correctly rejects empty lines"
    else
        test_error "❌ Strict mode should reject empty lines"
        return 1
    fi

    # Test permissive mode (should pass despite empty lines)
    if "$validator" "$csv_with_empty_lines" "permissive" >/dev/null 2>&1; then
        test_info "✅ Permissive mode correctly allows empty lines"
    else
        test_error "❌ Permissive mode should allow empty lines"
        return 1
    fi

    test_info "✅ Validation modes test passed"
}

test_comprehensive_csv_patterns() {
    test_info "🧪 Testing comprehensive CSV pattern validation"

    local validator=$(create_defensive_csv_validator)

    # Test alternative valid header (z instead of l2_norm)
    local alt_header_csv="$TEST_CSV_DIR/alternative_header.csv"
    cat > "$alt_header_csv" << 'EOF'
degree,critical_points,z
4,28,0.001234
5,35,0.002456
EOF

    assert_validation_success "$validator" "$alt_header_csv" \
        "Alternative valid header (z) should be accepted"

    # Test scientific notation in l2_norm
    local scientific_csv="$TEST_CSV_DIR/scientific_notation.csv"
    cat > "$scientific_csv" << 'EOF'
degree,critical_points,l2_norm
4,28,1.234e-05
5,35,2.456E+02
6,42,3.789e10
EOF

    assert_validation_success "$validator" "$scientific_csv" \
        "Scientific notation in l2_norm should be accepted"

    # Test edge case values
    local edge_case_csv="$TEST_CSV_DIR/edge_cases.csv"
    cat > "$edge_case_csv" << 'EOF'
degree,critical_points,l2_norm
0,0,0
1,1,0.0
100,9999,1e-10
EOF

    assert_validation_success "$validator" "$edge_case_csv" \
        "Edge case values should be accepted"

    test_info "✅ Comprehensive CSV patterns test passed"
}

# Main test runner
run_all_tests() {
    test_info "🚀 Starting Defensive CSV Validation Tests"
    test_info "Test Version: $TEST_VERSION"
    test_info "Temporary Directory: $TEMP_DIR"
    test_info "====================================================="

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # List of test functions
    local tests=(
        "test_valid_csv_validation"
        "test_interface_bug_detection"
        "test_invalid_header_detection"
        "test_data_corruption_detection"
        "test_incomplete_data_detection"
        "test_empty_file_detection"
        "test_missing_file_detection"
        "test_json_validation"
        "test_validation_modes"
        "test_comprehensive_csv_patterns"
    )

    for test_func in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        test_info ""
        test_info "Running test: $test_func"
        test_info "---------------------------------------------------"

        if $test_func; then
            passed_tests=$((passed_tests + 1))
            test_info "✅ Test $test_func PASSED"
        else
            failed_tests=$((failed_tests + 1))
            test_error "❌ Test $test_func FAILED"
        fi
    done

    # Test summary
    test_info ""
    test_info "====================================================="
    test_info "🏁 CSV Validation Test Results Summary"
    test_info "====================================================="
    test_info "Total Tests: $total_tests"
    test_info "Passed: $passed_tests"
    test_info "Failed: $failed_tests"

    if [[ $failed_tests -eq 0 ]]; then
        test_info "🎉 ALL CSV VALIDATION TESTS PASSED! 🎉"
        test_info "Defensive CSV validation system ready for implementation."
        return 0
    else
        test_error "💥 $failed_tests CSV VALIDATION TESTS FAILED"
        test_error "Please fix test failures before implementing system."
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi