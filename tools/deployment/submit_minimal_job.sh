#!/bin/bash

# DEPRECATED - SLURM-based submission script
# This script is for the legacy falcon cluster that uses SLURM scheduling
# 
# For current r04n02 cluster execution, use instead:
# ./hpc/experiments/robust_experiment_runner.sh
# or
# ./node_experiments/runners/experiment_runner.sh
#
# Issue #56: Legacy SLURM infrastructure removal

echo "⚠️  DEPRECATED SCRIPT"
echo "This SLURM-based script is no longer used on r04n02"  
echo ""
echo "Use direct execution instead:"
echo "  ./hpc/experiments/robust_experiment_runner.sh 2d-test"
echo "  ./node_experiments/runners/experiment_runner.sh test-2d"
echo ""
echo "Exiting to prevent confusion with legacy SLURM workflow"
exit 1

# First, clean up home directory to free space
echo -e "${YELLOW}Cleaning up home directory...${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    echo 'Before cleanup:'
    du -sh ~/*
    echo ''
    
    # Remove old globtim directories
    rm -rf ~/globtim_from_fileserver ~/globtim_hpc ~/globtim_test ~/globtim
    
    echo 'After cleanup:'
    du -sh ~/* 2>/dev/null || echo 'Home directory is now clean'
    echo ''
    echo 'Available space:'
    df -h ~ | tail -1
"

# Copy just the SLURM script
echo -e "${YELLOW}Copying minimal SLURM script...${NC}"
scp -i "${SSH_KEY_PATH}" globtim_minimal.slurm "${CLUSTER_HOST}:~/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SLURM script copied${NC}"
else
    echo -e "${RED}✗ Failed to copy SLURM script${NC}"
    exit 1
fi

# Submit the job
echo -e "${YELLOW}Submitting minimal job...${NC}"
JOB_OUTPUT=$(ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "sbatch globtim_minimal.slurm")
JOB_ID=$(echo "$JOB_OUTPUT" | grep -o '[0-9]\+')

if [ -n "$JOB_ID" ]; then
    echo -e "${GREEN}✓ Job submitted successfully${NC}"
    echo -e "${YELLOW}Job ID: ${JOB_ID}${NC}"
    echo ""
    echo -e "${BLUE}Monitor your job:${NC}"
    echo "• Check status: ssh ${CLUSTER_HOST} 'squeue -u \$USER'"
    echo "• View output: ssh ${CLUSTER_HOST} 'cat globtim_minimal_${JOB_ID}.out'"
    echo "• View errors: ssh ${CLUSTER_HOST} 'cat globtim_minimal_${JOB_ID}.err'"
    echo ""
    echo -e "${YELLOW}Checking initial job status...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "squeue -u \$USER"
else
    echo -e "${RED}✗ Job submission failed${NC}"
    echo "Output: $JOB_OUTPUT"
    exit 1
fi
