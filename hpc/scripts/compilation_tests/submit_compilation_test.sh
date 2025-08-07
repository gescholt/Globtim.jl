#!/bin/bash

# Submit Globtim Compilation Test to HPC Cluster
# 
# This script submits compilation tests with different configurations
# and provides monitoring and result collection capabilities.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
MODE="standard"
TIME_LIMIT="00:30:00"
CPUS=24
MEMORY="32G"
PARTITION="batch"
MONITOR=false
COLLECT_RESULTS=true

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Submit Globtim compilation test to HPC cluster

OPTIONS:
    --mode MODE         Test mode: quick, standard, thorough (default: standard)
    --time TIME         Time limit in HH:MM:SS format (default: 00:30:00)
    --cpus CPUS         Number of CPUs (default: 24)
    --memory MEM        Memory allocation (default: 32G)
    --partition PART    SLURM partition (default: batch)
    --monitor           Monitor job progress after submission
    --no-collect        Don't collect results after completion
    --help              Show this help message

EXAMPLES:
    $0                                    # Standard test
    $0 --mode quick                       # Quick test (10 min)
    $0 --mode thorough --time 01:00:00    # Thorough test (1 hour)
    $0 --monitor                          # Submit and monitor
    
TEST MODES:
    quick      - Fast compilation check (5-10 minutes)
    standard   - Complete compilation test (30 minutes)
    thorough   - Exhaustive testing (1 hour)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
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
        --no-collect)
            COLLECT_RESULTS=false
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

# Adjust time limits based on mode if not explicitly set
if [[ "$TIME_LIMIT" == "00:30:00" ]]; then
    case $MODE in
        quick)
            TIME_LIMIT="00:10:00"
            CPUS=4
            MEMORY="16G"
            ;;
        standard)
            TIME_LIMIT="00:30:00"
            ;;
        thorough)
            TIME_LIMIT="01:00:00"
            ;;
    esac
fi

echo -e "${BLUE}🚀 Submitting Globtim Compilation Test${NC}"
echo "=================================="
echo "Mode: $MODE"
echo "Time limit: $TIME_LIMIT"
echo "CPUs: $CPUS"
echo "Memory: $MEMORY"
echo "Partition: $PARTITION"
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
TEMP_JOB_SCRIPT="/tmp/compilation_test_${MODE}_$$.slurm"

# Copy base template and customize
cp "$SCRIPT_DIR/compilation_test.slurm" "$TEMP_JOB_SCRIPT"

# Update job parameters (macOS compatible)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires empty string after -i
    sed -i "" "s/#SBATCH --job-name=globtim_compilation_test/#SBATCH --job-name=globtim_compilation_test_${MODE}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --time=00:30:00/#SBATCH --time=${TIME_LIMIT}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --cpus-per-task=24/#SBATCH --cpus-per-task=${CPUS}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --mem=32G/#SBATCH --mem=${MEMORY}/" "$TEMP_JOB_SCRIPT"
    sed -i "" "s/#SBATCH --partition=batch/#SBATCH --partition=${PARTITION}/" "$TEMP_JOB_SCRIPT"
else
    # Linux sed
    sed -i "s/#SBATCH --job-name=globtim_compilation_test/#SBATCH --job-name=globtim_compilation_test_${MODE}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --time=00:30:00/#SBATCH --time=${TIME_LIMIT}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --cpus-per-task=24/#SBATCH --cpus-per-task=${CPUS}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --mem=32G/#SBATCH --mem=${MEMORY}/" "$TEMP_JOB_SCRIPT"
    sed -i "s/#SBATCH --partition=batch/#SBATCH --partition=${PARTITION}/" "$TEMP_JOB_SCRIPT"
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
    echo "Job name: globtim_compilation_test_${MODE}"
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
        echo "  View output:     tail -f compilation_test_${JOB_ID}.out"
        echo "  View errors:     tail -f compilation_test_${JOB_ID}.err"
    else
        echo "  Monitor job:     ssh $CLUSTER_HOST 'squeue -j $JOB_ID'"
        echo "  Cancel job:      ssh $CLUSTER_HOST 'scancel $JOB_ID'"
        echo "  View output:     ssh $CLUSTER_HOST 'tail -f compilation_test_${JOB_ID}.out'"
        echo "  View errors:     ssh $CLUSTER_HOST 'tail -f compilation_test_${JOB_ID}.err'"
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
            
            sleep 10
        done
        
        # Collect results if job completed successfully
        if [[ "$STATUS" == "COMPLETED" && "$COLLECT_RESULTS" == true ]]; then
            echo ""
            echo -e "${BLUE}📥 Collecting results...${NC}"
            
            # Create local results directory
            RESULTS_DIR="$REPO_ROOT/hpc_results/compilation_test_${JOB_ID}"
            mkdir -p "$RESULTS_DIR"
            
            if [[ "$ON_CLUSTER" == true ]]; then
                # Copy output files
                cp "compilation_test_${JOB_ID}.out" "$RESULTS_DIR/" 2>/dev/null || true
                cp "compilation_test_${JOB_ID}.err" "$RESULTS_DIR/" 2>/dev/null || true
            else
                # Copy via SSH
                scp "${CLUSTER_HOST}:compilation_test_${JOB_ID}.out" "$RESULTS_DIR/" 2>/dev/null || true
                scp "${CLUSTER_HOST}:compilation_test_${JOB_ID}.err" "$RESULTS_DIR/" 2>/dev/null || true
            fi
            
            echo -e "${GREEN}✅ Results collected in: $RESULTS_DIR${NC}"
            
            # Show summary if output file exists
            if [[ -f "$RESULTS_DIR/compilation_test_${JOB_ID}.out" ]]; then
                echo ""
                echo -e "${BLUE}📋 Test Summary:${NC}"
                grep -E "(SUCCESS|FAILED|Tests passed|Success rate)" "$RESULTS_DIR/compilation_test_${JOB_ID}.out" | tail -5 || true
            fi
        fi
    fi
    
else
    echo -e "${RED}❌ Failed to submit job${NC}"
    echo "Output: $JOB_OUTPUT"
    exit 1
fi

echo ""
echo -e "${GREEN}🎯 Compilation test submission complete!${NC}"
