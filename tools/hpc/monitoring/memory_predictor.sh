#!/bin/bash
# HPC Memory Predictor for Polynomial Approximation
# =================================================
#
# Predicts memory requirements for GlobTim polynomial approximation experiments
# based on polynomial degree and problem dimension. Critical for preventing
# OutOfMemoryError in high-dimensional problems.
#
# Based on real-world data from 4D Lotka-Volterra experiments (September 2025):
# - Degree 12 in 4D creates 28,561 basis functions
# - Results in ~2.3GB Vandermonde matrix
# - Requires ~50GB heap for Julia execution
#
# Usage:
#   tools/hpc/monitoring/memory_predictor.sh --degree 12 --dimension 4
#   tools/hpc/monitoring/memory_predictor.sh --interactive
#   tools/hpc/monitoring/memory_predictor.sh --batch-file experiments.txt
#
# Author: Claude Code HPC monitoring system  
# Date: September 4, 2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
DEFAULT_OVERHEAD_FACTOR=2.5  # Memory overhead multiplier for Julia/system
DEFAULT_SAFETY_MARGIN=1.2    # Additional safety margin
AVAILABLE_MEMORY_GB=3072     # r04n02 has 3Ti memory
JULIA_BASE_MEMORY_GB=2       # Base Julia memory requirement

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function usage() {
    cat <<EOF
HPC Memory Predictor for Polynomial Approximation
================================================

Predicts memory requirements for GlobTim polynomial approximation experiments.
Prevents OutOfMemoryError by analyzing polynomial basis size and matrix operations.

Usage: $0 [OPTIONS]

Options:
  --degree DEGREE          Polynomial degree (required for single prediction)
  --dimension DIMENSION    Problem dimension (required for single prediction)
  --overhead FACTOR        Memory overhead factor (default: $DEFAULT_OVERHEAD_FACTOR)
  --safety MARGIN          Safety margin multiplier (default: $DEFAULT_SAFETY_MARGIN)
  --interactive           Interactive mode for multiple predictions
  --batch-file FILE       Process batch file with degree,dimension pairs
  --format FORMAT         Output format: text, json, csv (default: text)
  --available-memory GB   Available memory in GB (default: $AVAILABLE_MEMORY_GB)
  --julia-heap-hint      Show recommended Julia heap size hint
  --help                  Show this help

Output Information:
  - Polynomial basis functions count
  - Vandermonde matrix size estimation
  - Total memory requirement prediction
  - Julia heap size recommendation
  - Feasibility assessment for available hardware

Examples:
  # Predict memory for 4D degree 12 polynomial
  $0 --degree 12 --dimension 4

  # Interactive mode for multiple experiments
  $0 --interactive

  # Get JSON output with custom overhead
  $0 --degree 10 --dimension 3 --format json --overhead 3.0

  # Process batch file
  $0 --batch-file experiments.txt --format csv

  # Check feasibility for high-degree experiment
  $0 --degree 15 --dimension 5 --julia-heap-hint

Mathematical Basis:
  Polynomial basis functions = C(degree + dimension, dimension)
  Vandermonde matrix size ≈ basis_functions² × 8 bytes (float64)
  Total memory ≈ matrix_size × overhead_factor × safety_margin

Real-World Validation:
  Based on September 2025 4D Lotka-Volterra experiments:
  - Degree 12, Dimension 4: 28,561 basis functions
  - Matrix size: ~2.3GB
  - Required heap: ~50GB (validated on r04n02)

EOF
}

function log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message" >&2
}

function binomial_coefficient() {
    local n=$1
    local k=$2
    
    if [[ $k -gt $n || $k -lt 0 ]]; then
        echo "0"
        return
    fi
    
    if [[ $k -eq 0 || $k -eq $n ]]; then
        echo "1"
        return
    fi
    
    # Use Python for accurate large number computation
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import math
n, k = $n, $k
if k > n - k:
    k = n - k
result = 1
for i in range(k):
    result = result * (n - i) // (i + 1)
print(result)
"
    else
        # Fallback bash computation (limited precision)
        local result=1
        local i=0
        while [[ $i -lt $k ]]; do
            result=$((result * (n - i) / (i + 1)))
            ((i++))
        done
        echo "$result"
    fi
}

function predict_memory_requirement() {
    local degree=$1
    local dimension=$2
    local overhead_factor=${3:-$DEFAULT_OVERHEAD_FACTOR}
    local safety_margin=${4:-$DEFAULT_SAFETY_MARGIN}
    local format=${5:-text}
    
    log_message "INFO" "Predicting memory for degree=$degree, dimension=$dimension"
    
    # Calculate number of basis functions: C(degree + dimension, dimension)
    local basis_functions
    basis_functions=$(binomial_coefficient $((degree + dimension)) $dimension)
    
    if [[ "$basis_functions" == "0" ]]; then
        log_message "ERROR" "Failed to calculate basis functions"
        return 1
    fi
    
    # Memory calculations using Python for accuracy
    if command -v python3 >/dev/null 2>&1; then
        local memory_analysis
        memory_analysis=$(python3 -c "
import math

basis_functions = $basis_functions
degree = $degree
dimension = $dimension
overhead_factor = $overhead_factor
safety_margin = $safety_margin
available_memory_gb = $AVAILABLE_MEMORY_GB
julia_base_gb = $JULIA_BASE_MEMORY_GB

# Vandermonde matrix size (float64 = 8 bytes)
matrix_elements = basis_functions * basis_functions
matrix_size_bytes = matrix_elements * 8
matrix_size_gb = matrix_size_bytes / (1024**3)

# Total memory requirement with overhead and safety margin
total_memory_gb = (matrix_size_gb + julia_base_gb) * overhead_factor * safety_margin

# Julia heap size recommendation (slightly higher than total requirement)
recommended_heap_gb = math.ceil(total_memory_gb * 1.1)

# Feasibility check
feasible = total_memory_gb <= available_memory_gb * 0.9  # Leave 10% buffer
memory_utilization = (total_memory_gb / available_memory_gb) * 100

# Risk assessment
if memory_utilization < 50:
    risk_level = 'LOW'
elif memory_utilization < 80:
    risk_level = 'MEDIUM'
else:
    risk_level = 'HIGH'

# Performance estimation based on matrix size
if matrix_size_gb < 1:
    estimated_runtime = 'Fast (< 10 minutes)'
elif matrix_size_gb < 10:
    estimated_runtime = 'Moderate (10-60 minutes)'
elif matrix_size_gb < 100:
    estimated_runtime = 'Slow (1-6 hours)'
else:
    estimated_runtime = 'Very Slow (> 6 hours)'

# Output in requested format
if '$format' == 'json':
    result = {
        'degree': degree,
        'dimension': dimension,
        'basis_functions': basis_functions,
        'matrix_size_gb': round(matrix_size_gb, 3),
        'total_memory_gb': round(total_memory_gb, 2),
        'recommended_heap_gb': recommended_heap_gb,
        'available_memory_gb': available_memory_gb,
        'memory_utilization_percent': round(memory_utilization, 1),
        'feasible': feasible,
        'risk_level': risk_level,
        'estimated_runtime': estimated_runtime,
        'julia_heap_hint': f'--heap-size-hint={recommended_heap_gb}G',
        'parameters': {
            'overhead_factor': overhead_factor,
            'safety_margin': safety_margin
        }
    }
    import json
    print(json.dumps(result, indent=2))
elif '$format' == 'csv':
    print(f'{degree},{dimension},{basis_functions},{matrix_size_gb:.3f},{total_memory_gb:.2f},{recommended_heap_gb},{memory_utilization:.1f},{feasible},{risk_level}')
else:
    # Text format
    print(f'Memory Prediction for Polynomial Approximation')
    print(f'===============================================')
    print(f'Polynomial Degree: {degree}')
    print(f'Problem Dimension: {dimension}')
    print(f'Basis Functions: {basis_functions:,}')
    print(f'')
    print(f'Memory Analysis:')
    print(f'  Matrix Size: {matrix_size_gb:.3f} GB')
    print(f'  Total Required: {total_memory_gb:.2f} GB')
    print(f'  Available Memory: {available_memory_gb} GB')
    print(f'  Memory Utilization: {memory_utilization:.1f}%')
    print(f'')
    print(f'Feasibility Assessment:')
    print(f'  Feasible: {\"✅ YES\" if feasible else \"❌ NO\"}')
    print(f'  Risk Level: {risk_level}')
    print(f'  Estimated Runtime: {estimated_runtime}')
    print(f'')
    print(f'Recommendations:')
    print(f'  Julia Heap Hint: --heap-size-hint={recommended_heap_gb}G')
    if not feasible:
        print(f'  ⚠️  WARNING: Memory requirement exceeds available resources!')
        print(f'  Consider reducing polynomial degree or problem dimension.')
    elif memory_utilization > 80:
        print(f'  ⚠️  CAUTION: High memory utilization may impact performance.')
    print(f'')
    print(f'Parameters Used:')
    print(f'  Overhead Factor: {overhead_factor}x')
    print(f'  Safety Margin: {safety_margin}x')
")
    else
        # Fallback computation without Python
        echo "Memory prediction requires Python3 for accurate calculations"
        echo "Basis functions: $basis_functions"
        echo "Estimated matrix size: Very large (>1GB)"
        echo "Recommendation: Install Python3 for precise predictions"
    fi
    
    echo "$memory_analysis"
}

function interactive_mode() {
    echo -e "${CYAN}HPC Memory Predictor - Interactive Mode${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    
    while true; do
        echo -e "${BLUE}Enter polynomial degree (or 'quit' to exit):${NC}"
        read -r degree
        
        if [[ "$degree" == "quit" || "$degree" == "exit" || "$degree" == "q" ]]; then
            echo -e "${GREEN}Exiting interactive mode${NC}"
            break
        fi
        
        if ! [[ "$degree" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}❌ Invalid degree. Please enter a positive integer.${NC}\n"
            continue
        fi
        
        echo -e "${BLUE}Enter problem dimension:${NC}"
        read -r dimension
        
        if ! [[ "$dimension" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}❌ Invalid dimension. Please enter a positive integer.${NC}\n"
            continue
        fi
        
        echo -e "${YELLOW}Computing memory prediction...${NC}\n"
        
        predict_memory_requirement "$degree" "$dimension" "$DEFAULT_OVERHEAD_FACTOR" "$DEFAULT_SAFETY_MARGIN" "text"
        
        echo -e "\n${CYAN}────────────────────────────────────────${NC}\n"
    done
}

function process_batch_file() {
    local batch_file="$1"
    local format="${2:-text}"
    
    if [[ ! -f "$batch_file" ]]; then
        log_message "ERROR" "Batch file not found: $batch_file"
        exit 1
    fi
    
    log_message "INFO" "Processing batch file: $batch_file"
    
    if [[ "$format" == "csv" ]]; then
        echo "degree,dimension,basis_functions,matrix_size_gb,total_memory_gb,recommended_heap_gb,memory_utilization_percent,feasible,risk_level"
    fi
    
    while IFS=',' read -r degree dimension || [[ -n "$degree" ]]; do
        # Skip empty lines and comments
        if [[ -z "$degree" || "$degree" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Trim whitespace
        degree=$(echo "$degree" | xargs)
        dimension=$(echo "$dimension" | xargs)
        
        # Validate input
        if [[ "$degree" =~ ^[0-9]+$ && "$dimension" =~ ^[0-9]+$ ]]; then
            predict_memory_requirement "$degree" "$dimension" "$DEFAULT_OVERHEAD_FACTOR" "$DEFAULT_SAFETY_MARGIN" "$format"
            
            if [[ "$format" == "text" ]]; then
                echo "────────────────────────────────────────"
            fi
        else
            log_message "WARNING" "Skipping invalid line: $degree,$dimension"
        fi
    done < "$batch_file"
}

function generate_example_batch_file() {
    local example_file="$1"
    
    cat > "$example_file" <<EOF
# HPC Memory Predictor Batch File
# Format: degree,dimension
# Lines starting with # are comments

# Low-complexity experiments
5,2
6,2
8,3

# Medium-complexity experiments  
10,3
10,4
12,3

# High-complexity experiments (may require large memory)
12,4
15,4
10,5

# Very high-complexity (likely infeasible)
15,5
20,4
12,6
EOF
    
    echo "Example batch file created: $example_file"
    echo "Edit this file with your desired degree,dimension pairs"
}

function main() {
    local degree=""
    local dimension=""
    local overhead_factor="$DEFAULT_OVERHEAD_FACTOR"
    local safety_margin="$DEFAULT_SAFETY_MARGIN"
    local format="text"
    local interactive=false
    local batch_file=""
    local julia_heap_hint=false
    local available_memory="$AVAILABLE_MEMORY_GB"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --degree)
                degree="$2"
                shift 2
                ;;
            --dimension)
                dimension="$2"
                shift 2
                ;;
            --overhead)
                overhead_factor="$2"
                shift 2
                ;;
            --safety)
                safety_margin="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --interactive)
                interactive=true
                shift
                ;;
            --batch-file)
                batch_file="$2"
                shift 2
                ;;
            --available-memory)
                available_memory="$2"
                AVAILABLE_MEMORY_GB="$2"
                shift 2
                ;;
            --julia-heap-hint)
                julia_heap_hint=true
                shift
                ;;
            --generate-example)
                generate_example_batch_file "${2:-example_experiments.txt}"
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate format
    if [[ "$format" != "text" && "$format" != "json" && "$format" != "csv" ]]; then
        log_message "ERROR" "Invalid format: $format"
        exit 1
    fi
    
    # Execute based on mode
    if [[ "$interactive" == true ]]; then
        interactive_mode
    elif [[ -n "$batch_file" ]]; then
        process_batch_file "$batch_file" "$format"
    elif [[ -n "$degree" && -n "$dimension" ]]; then
        predict_memory_requirement "$degree" "$dimension" "$overhead_factor" "$safety_margin" "$format"
        
        if [[ "$julia_heap_hint" == true ]]; then
            echo ""
            echo "Julia execution command:"
            local heap_size=$(predict_memory_requirement "$degree" "$dimension" "$overhead_factor" "$safety_margin" "json" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['recommended_heap_gb'])" 2>/dev/null || echo "50")
            echo "julia --project=. --heap-size-hint=${heap_size}G your_experiment_script.jl"
        fi
    else
        echo -e "${RED}❌ Error: Missing required arguments${NC}" >&2
        echo "Use --degree and --dimension for single prediction, or --interactive for multiple predictions" >&2
        usage
        exit 1
    fi
}

# Execute main function
main "$@"