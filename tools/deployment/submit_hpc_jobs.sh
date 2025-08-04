#!/bin/bash

# Submit and manage Globtim HPC jobs via SLURM

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo -e "${BLUE}=== Globtim HPC Job Submission ===${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  sync          - Sync project to HPC cluster"
    echo "  test          - Submit basic test job"
    echo "  benchmark     - Submit benchmark job"
    echo "  status        - Check job status"
    echo "  logs          - View job logs"
    echo "  cancel        - Cancel jobs"
    echo "  interactive   - Start interactive session"
    echo ""
    echo "Examples:"
    echo "  $0 sync                    # Sync project files"
    echo "  $0 test                    # Submit test job"
    echo "  $0 benchmark               # Submit benchmark job"
    echo "  $0 status                  # Check all jobs"
    echo "  $0 logs 12345              # View logs for job 12345"
    echo "  $0 cancel 12345            # Cancel job 12345"
}

sync_project() {
    echo -e "${YELLOW}Syncing project to HPC cluster...${NC}"
    ./sync_fileserver_to_hpc.sh
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Project synced successfully${NC}"
        
        # Copy SLURM scripts to HPC
        echo -e "${YELLOW}Copying SLURM scripts...${NC}"
        scp -i "${SSH_KEY_PATH}" *.slurm "${CLUSTER_HOST}:globtim_hpc/"
        echo -e "${GREEN}✓ SLURM scripts copied${NC}"
    else
        echo -e "${RED}✗ Project sync failed${NC}"
        exit 1
    fi
}

submit_test_job() {
    echo -e "${YELLOW}Submitting test job to HPC cluster...${NC}"
    
    JOB_ID=$(ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "cd globtim_hpc && sbatch globtim_test.slurm" | grep -o '[0-9]\+')
    
    if [ -n "$JOB_ID" ]; then
        echo -e "${GREEN}✓ Test job submitted successfully${NC}"
        echo -e "${YELLOW}Job ID: ${JOB_ID}${NC}"
        echo -e "${YELLOW}Monitor with: $0 status${NC}"
        echo -e "${YELLOW}View logs with: $0 logs ${JOB_ID}${NC}"
    else
        echo -e "${RED}✗ Job submission failed${NC}"
        exit 1
    fi
}

submit_benchmark_job() {
    echo -e "${YELLOW}Submitting benchmark job to HPC cluster...${NC}"
    
    JOB_ID=$(ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "cd globtim_hpc && sbatch globtim_benchmark.slurm" | grep -o '[0-9]\+')
    
    if [ -n "$JOB_ID" ]; then
        echo -e "${GREEN}✓ Benchmark job submitted successfully${NC}"
        echo -e "${YELLOW}Job ID: ${JOB_ID}${NC}"
        echo -e "${YELLOW}Monitor with: $0 status${NC}"
        echo -e "${YELLOW}View logs with: $0 logs ${JOB_ID}${NC}"
    else
        echo -e "${RED}✗ Job submission failed${NC}"
        exit 1
    fi
}

check_status() {
    echo -e "${YELLOW}Checking job status on HPC cluster...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
        echo '=== Current Jobs ==='
        squeue -u \$USER
        echo ''
        echo '=== Recent Job History ==='
        sacct -u \$USER --format=JobID,JobName,State,ExitCode,Start,End,Elapsed -S \$(date -d '1 day ago' +%Y-%m-%d)
    "
}

view_logs() {
    local JOB_ID=$1
    if [ -z "$JOB_ID" ]; then
        echo -e "${RED}Error: Please provide a job ID${NC}"
        echo "Usage: $0 logs <job_id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Viewing logs for job ${JOB_ID}...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
        cd globtim_hpc
        echo '=== Standard Output ==='
        if [ -f globtim_*_${JOB_ID}.out ]; then
            cat globtim_*_${JOB_ID}.out
        else
            echo 'Output file not found'
        fi
        echo ''
        echo '=== Standard Error ==='
        if [ -f globtim_*_${JOB_ID}.err ]; then
            cat globtim_*_${JOB_ID}.err
        else
            echo 'Error file not found'
        fi
    "
}

cancel_job() {
    local JOB_ID=$1
    if [ -z "$JOB_ID" ]; then
        echo -e "${RED}Error: Please provide a job ID${NC}"
        echo "Usage: $0 cancel <job_id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Cancelling job ${JOB_ID}...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "scancel ${JOB_ID}"
    echo -e "${GREEN}✓ Job ${JOB_ID} cancelled${NC}"
}

interactive_session() {
    echo -e "${YELLOW}Starting interactive session on HPC cluster...${NC}"
    ssh -i "${SSH_KEY_PATH}" -t "${CLUSTER_HOST}" "cd globtim_hpc && bash -l"
}

# Main command handling
case "$1" in
    "sync")
        sync_project
        ;;
    "test")
        sync_project
        submit_test_job
        ;;
    "benchmark")
        sync_project
        submit_benchmark_job
        ;;
    "status")
        check_status
        ;;
    "logs")
        view_logs "$2"
        ;;
    "cancel")
        cancel_job "$2"
        ;;
    "interactive")
        interactive_session
        ;;
    *)
        show_usage
        ;;
esac
