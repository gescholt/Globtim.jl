#!/bin/bash
# Result Collection and Analysis Script for 4D Model Experiments
# Purpose: Monitor job status and collect results from SLURM jobs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

function print_info() {
    echo -e "${YELLOW}➤${NC} $1"
}

function print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

function print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check job status
function check_job_status() {
    local job_id=$1
    if [ -z "$job_id" ]; then
        echo "Usage: $0 check <job_id>"
        return 1
    fi
    
    print_header "Job Status for $job_id"
    
    # Check if job is running
    if squeue -j $job_id 2>/dev/null | grep -q $job_id; then
        print_info "Job $job_id is currently RUNNING"
        squeue -j $job_id
    else
        # Check if job completed
        if sacct -j $job_id --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS 2>/dev/null | grep -q $job_id; then
            print_info "Job $job_id has COMPLETED"
            sacct -j $job_id --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS
        else
            print_error "Job $job_id not found"
            return 1
        fi
    fi
}

# Collect results from a completed job
function collect_results() {
    local job_id=$1
    if [ -z "$job_id" ]; then
        echo "Usage: $0 collect <job_id>"
        return 1
    fi
    
    print_header "Collecting Results for Job $job_id"
    
    # Standard locations to check
    RESULT_DIRS=(
        "/tmp/globtim_results/4d_exp_*_job${job_id}"
        "/tmp/globtim_${job_id}/results_*"
        "/home/scholten/globtim_results/4d_exp_*_job${job_id}"
    )
    
    FOUND=false
    for pattern in "${RESULT_DIRS[@]}"; do
        for dir in $pattern; do
            if [ -d "$dir" ]; then
                FOUND=true
                print_success "Found results in: $dir"
                
                # Display key files
                if [ -f "$dir/comparison_4d.txt" ]; then
                    print_info "Comparison summary:"
                    cat "$dir/comparison_4d.txt"
                fi
                
                if [ -f "$dir/conditioning_info.txt" ]; then
                    print_info "Conditioning information:"
                    cat "$dir/conditioning_info.txt"
                fi
                
                if [ -f "$dir/timing_4d.txt" ]; then
                    print_info "Timing information:"
                    tail -n 20 "$dir/timing_4d.txt"
                fi
                
                # List all files
                print_info "All result files:"
                ls -lh "$dir"/
                
                # Offer to copy results locally
                read -p "Copy results to current directory? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    LOCAL_DIR="./results_job_${job_id}"
                    mkdir -p "$LOCAL_DIR"
                    cp -r "$dir"/* "$LOCAL_DIR"/
                    print_success "Results copied to $LOCAL_DIR"
                fi
            fi
        done
    done
    
    if [ "$FOUND" = false ]; then
        print_error "No results found for job $job_id"
        print_info "Check SLURM output logs:"
        echo "  /tmp/globtim_${job_id}/slurm_${job_id}.out"
        echo "  /tmp/globtim_${job_id}/slurm_${job_id}.err"
    fi
}

# Monitor running jobs
function monitor_jobs() {
    print_header "Monitoring GlobTim Jobs"
    
    # Check for running jobs
    RUNNING_JOBS=$(squeue -u $USER --name=globtim_4d_model,test_2d_deuflhard --noheader | wc -l)
    
    if [ $RUNNING_JOBS -gt 0 ]; then
        print_info "Found $RUNNING_JOBS running GlobTim job(s):"
        squeue -u $USER --name=globtim_4d_model,test_2d_deuflhard
    else
        print_info "No running GlobTim jobs found"
    fi
    
    # Check recent completed jobs
    print_info "Recent completed jobs (last 24 hours):"
    sacct -S $(date -d '1 day ago' +%Y-%m-%d) \
          --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS \
          --name=globtim_4d_model,test_2d_deuflhard
}

# Analyze multiple experiment results
function analyze_experiments() {
    local results_dir=${1:-"/tmp/globtim_results"}
    
    print_header "Analyzing All Experiments in $results_dir"
    
    if [ ! -d "$results_dir" ]; then
        print_error "Results directory not found: $results_dir"
        return 1
    fi
    
    # Find all 4D experiment directories
    for exp_dir in $results_dir/4d_exp_*/; do
        if [ -d "$exp_dir" ]; then
            exp_name=$(basename "$exp_dir")
            print_info "Experiment: $exp_name"
            
            # Extract key metrics
            if [ -f "$exp_dir/comparison_4d.txt" ]; then
                grep -E "Critical points:|Condition number:|Sparsity:" "$exp_dir/comparison_4d.txt" | sed 's/^/  /'
            fi
            
            # Check job configuration
            if [ -f "$exp_dir/job_config.txt" ]; then
                grep -E "Samples per dimension:|Total grid points:" "$exp_dir/job_config.txt" | sed 's/^/  /'
            fi
            echo
        fi
    done
}

# Main script logic
case "${1:-}" in
    check)
        check_job_status "$2"
        ;;
    collect)
        collect_results "$2"
        ;;
    monitor)
        monitor_jobs
        ;;
    analyze)
        analyze_experiments "$2"
        ;;
    *)
        echo "GlobTim HPC Result Collection Tool"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  check <job_id>    - Check status of a specific job"
        echo "  collect <job_id>  - Collect results from completed job"
        echo "  monitor           - Monitor all running GlobTim jobs"
        echo "  analyze [dir]     - Analyze all experiments in directory"
        echo ""
        echo "Examples:"
        echo "  $0 check 12345"
        echo "  $0 collect 12345"
        echo "  $0 monitor"
        echo "  $0 analyze /tmp/globtim_results"
        exit 1
        ;;
esac