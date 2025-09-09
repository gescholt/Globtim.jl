#!/bin/bash

# Test HPC Access and Environment
# Quick check of what's available on the cluster

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

echo -e "${BLUE}=== Testing HPC Access (falcon) ===${NC}"

ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    echo '=== System Information ==='
    hostname
    uname -a
    
    echo -e '\n=== Directory Structure ==='
    echo 'Home directory (1GB limit):'
    pwd
    df -h ~ | head -2
    
    echo -e '\nChecking /projects:'
    ls -la /projects/ 2>/dev/null || echo '/projects not accessible'
    
    echo -e '\nChecking /sw:'
    ls -la /sw/ 2>/dev/null | head -5 || echo '/sw not accessible'
    
    echo -e '\n=== Module System ==='
    which module || echo 'No module command found'
    module avail 2>&1 | head -10 || echo 'Module system not available'
    
    echo -e '\n=== Julia Check ==='
    which julia || echo 'Julia not in PATH'
    julia --version 2>/dev/null || echo 'Julia not available'
    
    echo -e '\n=== Direct Execution Check ==='
    echo 'Using direct execution (tmux) - no SLURM scheduler on r04n02'
    
    echo -e '\n=== Available Space ==='
    df -h | grep -E '(Filesystem|/home|/projects|/sw)' || df -h | head -5
"

echo -e "${GREEN}✓ HPC access test completed${NC}"
