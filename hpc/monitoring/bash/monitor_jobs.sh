#!/bin/bash

# Monitor SLURM jobs on HPC cluster

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

echo -e "${BLUE}=== Globtim HPC Job Monitor ===${NC}"

# Check current job status
echo -e "${YELLOW}Current Jobs:${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "squeue -u \$USER"

echo ""
echo -e "${YELLOW}Recent Job History:${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "sacct -u \$USER --format=JobID,JobName,State,ExitCode,Start,End,Elapsed -S \$(date -d '2 hours ago' +%Y-%m-%d-%H:%M)"

echo ""
echo -e "${YELLOW}Checking for Output Files:${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    echo 'Available output files:'
    ls -la globtim_*_*.out globtim_*_*.err 2>/dev/null || echo 'No output files found yet'
"

# If job ID provided, show specific job details
if [ -n "$1" ]; then
    JOB_ID=$1
    echo ""
    echo -e "${YELLOW}Details for Job ${JOB_ID}:${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
        echo '=== Job Control Info ==='
        scontrol show job ${JOB_ID} 2>/dev/null || echo 'Job not found or completed'
        
        echo ''
        echo '=== Output Files ==='
        if [ -f globtim_*_${JOB_ID}.out ]; then
            echo 'Standard Output:'
            cat globtim_*_${JOB_ID}.out
        else
            echo 'No output file found'
        fi
        
        echo ''
        if [ -f globtim_*_${JOB_ID}.err ]; then
            echo 'Standard Error:'
            cat globtim_*_${JOB_ID}.err
        else
            echo 'No error file found'
        fi
    "
fi

echo ""
echo -e "${BLUE}Usage:${NC}"
echo "  $0           - Show all jobs"
echo "  $0 <job_id>  - Show details for specific job"
