#!/bin/bash

# Submit Deuflhard Benchmark Test to HPC Cluster
# 
# Comprehensive testing infrastructure for polynomial construction and critical point finding

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
MODE="standard"
TIME_LIMIT="02:00:00"
CPUS=24
MEMORY="64G"
PARTITION="batch"
MONITOR=false
CUSTOM_DEGREE=""
CUSTOM_SAMPLES=""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Submit Deuflhard benchmark test to HPC cluster for polynomial construction and critical point finding

OPTIONS:
    --mode MODE         Test mode: quick, standard, thorough (default: standard)
    --degree DEGREE     Custom degree to test (overrides mode defaults)
    --samples SAMPLES   Custom sample size to test (overrides mode defaults)
    --time TIME         Time limit in HH:MM:SS format (default: 02:00:00)
    --cpus CPUS         Number of CPUs (default: 24)
    --memory MEM        Memory allocation (default: 64G)
    --partition PART    SLURM partition (default: batch)
    --monitor           Monitor job progress after submission
    --help              Show this help message

EXAMPLES:
    $0                                    # Standard test suite
    $0 --mode quick                       # Quick test (minimal parameters)
    $0 --mode thorough --time 04:00:00    # Thorough test (4 hours)
    $0 --degree 8 --samples 200           # Custom single test
    $0 --monitor                          # Submit and monitor
    
TEST MODES:
    quick      - Fast test with basic parameters (30 min)
    standard   - Complete test suite with multiple configurations (2 hours)
    thorough   - Exhaustive testing with all parameter combinations (4+ hours)

CUSTOM PARAMETERS:
    --degree   - Test specific polynomial degree (4, 6, 8, 10, 12, etc.)
    --samples  - Test specific sample size (50, 100, 200, 400, etc.)
    
OUTPUT:
    Results saved to ~/globtim_hpc/benchmark_results_[JOB_ID]/
    - test_results.csv: Main results table with all parameters and metrics
    - test_config.txt: Test configuration and metadata
    - benchmark_data.txt: Detailed BenchmarkTools results (if enabled)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --degree)
            CUSTOM_DEGREE="$2"
            shift 2
            ;;
        --samples)
            CUSTOM_SAMPLES="$2"
            shift 2
            ;;
        --time)
            TIME_LIMIT="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --partition)
            PARTITION="$2"
            shift 2
            ;;
        --monitor)
            MONITOR=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validate mode
if [[ ! "$MODE" =~ ^(quick|standard|thorough)$ ]]; then
    echo -e "${RED}Error: Invalid mode '$MODE'. Must be quick, standard, or thorough.${NC}"
    exit 1
fi

# Adjust time limits and resources based on mode if not explicitly set
if [[ "$TIME_LIMIT" == "02:00:00" ]]; then
    case $MODE in
        quick)
            TIME_LIMIT="00:30:00"
            CPUS=12
            MEMORY="32G"
            ;;
        standard)
            TIME_LIMIT="02:00:00"
            ;;
        thorough)
            TIME_LIMIT="04:00:00"
            MEMORY="128G"
            ;;
    esac
fi

echo -e "${BLUE}🚀 Submitting Deuflhard Benchmark Test${NC}"
echo "======================================="
echo "Mode: $MODE"
echo "Time limit: $TIME_LIMIT"
echo "CPUs: $CPUS"
echo "Memory: $MEMORY"
echo "Partition: $PARTITION"
if [[ -n "$CUSTOM_DEGREE" ]]; then
    echo "Custom degree: $CUSTOM_DEGREE"
fi
if [[ -n "$CUSTOM_SAMPLES" ]]; then
    echo "Custom samples: $CUSTOM_SAMPLES"
fi
echo ""

# Check if we're on the cluster or need to SSH
if command -v sbatch >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Running on HPC cluster${NC}"
    ON_CLUSTER=true
else
    echo -e "${YELLOW}⚠️  Not on HPC cluster - will attempt SSH submission${NC}"
    ON_CLUSTER=false
    
    # Check for cluster configuration
    if [[ -f "$REPO_ROOT/hpc/config/cluster_config.sh" ]]; then
        source "$REPO_ROOT/hpc/config/cluster_config.sh"
        echo "Using cluster config: $CLUSTER_HOST"
    else
        echo -e "${RED}Error: No cluster configuration found${NC}"
        echo "Please create hpc/config/cluster_config.sh with CLUSTER_HOST variable"
        exit 1
    fi
fi

# Create temporary job script with custom parameters
TEMP_JOB_SCRIPT="/tmp/deuflhard_benchmark_${MODE}_$$.slurm"

# Copy base template and customize
cp "$SCRIPT_DIR/deuflhard_benchmark.slurm" "$TEMP_JOB_SCRIPT"

# Update job parameters (macOS compatible)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires empty string after -i
    sed -i "" "s/#SBATCH --job-name=deuflhard_benchmark/#SBATCH --job-name=deuflhard_benchmark_${MODE}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --time=02:00:00/#SBATCH --time=${TIME_LIMIT}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --cpus-per-task=24/#SBATCH --cpus-per-task=${CPUS}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --mem=64G/#SBATCH --mem=${MEMORY}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --partition=batch/#SBATCH --partition=${PARTITION}/" "$TEMP_JOB_SCRIPT"
else
    # Linux sed
    sed -i "s/#SBATCH --job-name=deuflhard_benchmark/#SBATCH --job-name=deuflhard_benchmark_${MODE}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --time=02:00:00/#SBATCH --time=${TIME_LIMIT}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --cpus-per-task=24/#SBATCH --cpus-per-task=${CPUS}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --mem=64G/#SBATCH --mem=${MEMORY}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --partition=batch/#SBATCH --partition=${PARTITION}/" "$TEMP_JOB_SCRIPT"
fi

# Add custom parameters as environment variables
if [[ -n "$CUSTOM_DEGREE" ]]; then
    echo "export BENCHMARK_DEGREE=$CUSTOM_DEGREE" >> "$TEMP_JOB_SCRIPT"
fi
if [[ -n "$CUSTOM_SAMPLES" ]]; then
    echo "export BENCHMARK_SAMPLES=$CUSTOM_SAMPLES" >> "$TEMP_JOB_SCRIPT"
fi

echo -e "${BLUE}📋 Job Configuration:${NC}"
echo "Job script: $TEMP_JOB_SCRIPT"
echo ""

# Submit job
if [[ "$ON_CLUSTER" == true ]]; then
    echo -e "${BLUE}📤 Submitting job to SLURM...${NC}"
    JOB_OUTPUT=$(sbatch "$TEMP_JOB_SCRIPT")
    JOB_ID=$(echo "$JOB_OUTPUT" | grep -o '[0-9]\+')
else
    echo -e "${BLUE}📤 Submitting job via SSH...${NC}"
    # Copy job script to cluster and submit
    scp "$TEMP_JOB_SCRIPT" "${CLUSTER_HOST}:/tmp/"
    JOB_OUTPUT=$(ssh "$CLUSTER_HOST" "sbatch /tmp/$(basename $TEMP_JOB_SCRIPT)")
    JOB_ID=$(echo "$JOB_OUTPUT" | grep -o '[0-9]\+')
fi

# Clean up temporary script
rm "$TEMP_JOB_SCRIPT"

if [[ -n "$JOB_ID" ]]; then
    echo -e "${GREEN}✅ Job submitted successfully!${NC}"
    echo "Job ID: $JOB_ID"
    echo "Job name: deuflhard_benchmark_${MODE}"
    echo ""
    
    # Show job status
    if [[ "$ON_CLUSTER" == true ]]; then
        echo -e "${BLUE}📊 Current job status:${NC}"
        squeue -j "$JOB_ID" --format="%.10i %.20j %.8T %.10M %.6D %.20R" || true
    else
        echo -e "${BLUE}📊 Current job status:${NC}"
        ssh "$CLUSTER_HOST" "squeue -j $JOB_ID --format='%.10i %.20j %.8T %.10M %.6D %.20R'" || true
    fi
    
    echo ""
    echo -e "${YELLOW}📝 Useful commands:${NC}"
    if [[ "$ON_CLUSTER" == true ]]; then
        echo "  Monitor job:     squeue -j $JOB_ID"
        echo "  Cancel job:      scancel $JOB_ID"
        echo "  View output:     tail -f deuflhard_benchmark_${JOB_ID}.out"
        echo "  View errors:     tail -f deuflhard_benchmark_${JOB_ID}.err"
        echo "  Results:         ls ~/globtim_hpc/benchmark_results_${JOB_ID}/"
    else
        echo "  Monitor job:     ssh $CLUSTER_HOST 'squeue -j $JOB_ID'"
        echo "  Cancel job:      ssh $CLUSTER_HOST 'scancel $JOB_ID'"
        echo "  View output:     ssh $CLUSTER_HOST 'tail -f deuflhard_benchmark_${JOB_ID}.out'"
        echo "  View errors:     ssh $CLUSTER_HOST 'tail -f deuflhard_benchmark_${JOB_ID}.err'"
        echo "  Results:         ssh $CLUSTER_HOST 'ls ~/globtim_hpc/benchmark_results_${JOB_ID}/'"
    fi
    
    # Monitor job if requested
    if [[ "$MONITOR" == true ]]; then
        echo ""
        echo -e "${BLUE}👀 Monitoring job progress...${NC}"
        echo "Press Ctrl+C to stop monitoring (job will continue running)"
        echo ""
        
        while true; do
            if [[ "$ON_CLUSTER" == true ]]; then
                STATUS=$(squeue -j "$JOB_ID" --noheader --format="%T" 2>/dev/null || echo "COMPLETED")
            else
                STATUS=$(ssh "$CLUSTER_HOST" "squeue -j $JOB_ID --noheader --format='%T'" 2>/dev/null || echo "COMPLETED")
            fi
            
            case $STATUS in
                "PENDING")
                    echo -e "${YELLOW}⏳ Job is pending...${NC}"
                    ;;
                "RUNNING")
                    echo -e "${BLUE}🏃 Job is running...${NC}"
                    ;;
                "COMPLETED"|"")
                    echo -e "${GREEN}✅ Job completed!${NC}"
                    break
                    ;;
                "FAILED"|"CANCELLED"|"TIMEOUT")
                    echo -e "${RED}❌ Job failed with status: $STATUS${NC}"
                    break
                    ;;
                *)
                    echo -e "${YELLOW}📊 Job status: $STATUS${NC}"
                    ;;
            esac
            
            sleep 30
        done
        
        # Show results summary if job completed successfully
        if [[ "$STATUS" == "COMPLETED" ]]; then
            echo ""
            echo -e "${BLUE}📊 Results Summary:${NC}"
            
            if [[ "$ON_CLUSTER" == true ]]; then
                if [ -f "deuflhard_benchmark_${JOB_ID}.out" ]; then
                    echo "Job output (last 10 lines):"
                    tail -10 "deuflhard_benchmark_${JOB_ID}.out"
                fi
            else
                ssh "$CLUSTER_HOST" "tail -10 deuflhard_benchmark_${JOB_ID}.out 2>/dev/null" || echo "Output file not accessible"
            fi
        fi
    fi
    
else
    echo -e "${RED}❌ Failed to submit job${NC}"
    echo "Output: $JOB_OUTPUT"
    exit 1
fi

echo ""
echo -e "${GREEN}🎯 Deuflhard benchmark test submission complete!${NC}"
echo ""
echo -e "${YELLOW}📋 What happens next:${NC}"
echo "1. Job will run polynomial construction tests on Deuflhard function"
echo "2. Tests multiple degrees, sample sizes, and precision types"
echo "3. Finds and analyzes critical points for each configuration"
echo "4. Collects detailed timing and accuracy metrics"
echo "5. Results saved with full parameter tracking for reproducibility"
echo ""
echo -e "${BLUE}📁 Expected outputs:${NC}"
echo "- test_results.csv: Complete results table"
echo "- test_config.txt: Test parameters and metadata"
echo "- benchmark_data.txt: Detailed performance metrics"
