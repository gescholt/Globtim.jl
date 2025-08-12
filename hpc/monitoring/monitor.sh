#!/bin/bash
# HPC Job Monitoring Wrapper Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_PY="$SCRIPT_DIR/job_monitor.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_help() {
    echo "HPC Job Monitor for GlobTim"
    echo "============================"
    echo ""
    echo "Usage: ./monitor.sh [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  test          Submit and monitor a compilation test"
    echo "  monitor ID    Monitor a specific job by ID"
    echo "  check ID      Check if compilation was successful for job ID"
    echo "  report IDs    Generate report for multiple job IDs"
    echo "  status        Show status of all recent jobs"
    echo "  clean         Clean up old result files"
    echo ""
    echo "Examples:"
    echo "  ./monitor.sh test                    # Submit and monitor test job"
    echo "  ./monitor.sh monitor 12345           # Monitor job 12345"
    echo "  ./monitor.sh check 12345             # Check compilation success"
    echo "  ./monitor.sh report 12345 12346      # Generate report for multiple jobs"
    echo "  ./monitor.sh status                  # Show all recent job statuses"
}

function check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is required${NC}"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}Error: SSH is required${NC}"
        exit 1
    fi
}

function submit_test() {
    echo -e "${GREEN}🚀 Submitting GlobTim compilation test...${NC}"
    python3 "$MONITOR_PY" --submit --interval 20
}

function monitor_job() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Job ID required${NC}"
        echo "Usage: ./monitor.sh monitor JOB_ID"
        exit 1
    fi
    
    echo -e "${GREEN}📊 Monitoring job $1...${NC}"
    python3 "$MONITOR_PY" --monitor "$1" --interval 20
}

function check_job() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Job ID required${NC}"
        echo "Usage: ./monitor.sh check JOB_ID"
        exit 1
    fi
    
    echo -e "${YELLOW}🔍 Checking compilation status for job $1...${NC}"
    python3 "$MONITOR_PY" --check "$1"
}

function generate_report() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: At least one job ID required${NC}"
        echo "Usage: ./monitor.sh report JOB_ID1 [JOB_ID2 ...]"
        exit 1
    fi
    
    echo -e "${GREEN}📊 Generating report for jobs: $@${NC}"
    python3 "$MONITOR_PY" --report "$@"
}

function show_status() {
    echo -e "${YELLOW}📋 Recent Job Status${NC}"
    echo "===================="
    
    # Get recent jobs from squeue
    ssh scholten@falcon "squeue -u scholten --format='%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R' | head -20"
    
    echo ""
    echo -e "${YELLOW}📁 Recent Results${NC}"
    echo "================"
    
    # Show recent result files
    if [ -d "$SCRIPT_DIR/results" ]; then
        ls -lt "$SCRIPT_DIR/results" | head -10
    else
        echo "No results directory found"
    fi
}

function clean_results() {
    echo -e "${YELLOW}🧹 Cleaning old result files...${NC}"
    
    if [ -d "$SCRIPT_DIR/results" ]; then
        # Remove files older than 7 days
        find "$SCRIPT_DIR/results" -type f -mtime +7 -delete
        echo -e "${GREEN}✅ Cleaned old result files${NC}"
    else
        echo "No results directory found"
    fi
}

function batch_test() {
    echo -e "${GREEN}🔬 Running batch compilation tests...${NC}"
    
    # Submit multiple test jobs
    for i in {1..3}; do
        echo -e "${YELLOW}Submitting test $i of 3...${NC}"
        job_id=$(python3 "$MONITOR_PY" --submit 2>&1 | grep "Submitted job" | awk '{print $3}')
        
        if [ -n "$job_id" ]; then
            echo "Job $job_id submitted"
            JOB_IDS+=("$job_id")
            sleep 5  # Small delay between submissions
        fi
    done
    
    # Monitor all jobs
    if [ ${#JOB_IDS[@]} -gt 0 ]; then
        echo -e "${GREEN}Monitoring ${#JOB_IDS[@]} jobs: ${JOB_IDS[@]}${NC}"
        
        # Wait for all jobs to complete
        for job_id in "${JOB_IDS[@]}"; do
            python3 "$MONITOR_PY" --monitor "$job_id" --interval 30
        done
        
        # Generate report
        echo -e "${GREEN}Generating batch report...${NC}"
        python3 "$MONITOR_PY" --report "${JOB_IDS[@]}"
    fi
}

# Main script logic
check_dependencies

case "$1" in
    test)
        submit_test
        ;;
    monitor)
        monitor_job "$2"
        ;;
    check)
        check_job "$2"
        ;;
    report)
        shift
        generate_report "$@"
        ;;
    status)
        show_status
        ;;
    clean)
        clean_results
        ;;
    batch)
        batch_test
        ;;
    help|--help|-h)
        print_help
        ;;
    *)
        if [ -z "$1" ]; then
            print_help
        else
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            print_help
        fi
        exit 1
        ;;
esac