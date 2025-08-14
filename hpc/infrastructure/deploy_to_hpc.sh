#!/bin/bash

# Deploy Globtim to HPC Cluster
# Syncs to both fileserver (backup) and HPC cluster (computation)

set -e

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found. Please create it first."
    exit 1
fi

# Configuration
LOCAL_PATH="$(pwd)"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_ed25519}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Globtim HPC Deployment ===${NC}"

# Security checks
echo -e "${YELLOW}Running security checks...${NC}"
if [ -f "${SSH_KEY_PATH}" ]; then
    KEY_PERMS=$(stat -f "%A" "${SSH_KEY_PATH}" 2>/dev/null || stat -c "%a" "${SSH_KEY_PATH}" 2>/dev/null)
    if [ "$KEY_PERMS" != "600" ]; then
        echo -e "${RED}Warning: SSH key has insecure permissions ($KEY_PERMS). Should be 600.${NC}"
    fi
else
    echo -e "${RED}Warning: SSH key not found at ${SSH_KEY_PATH}${NC}"
fi

# Function to sync to a remote host
sync_to_remote() {
    local HOST=$1
    local PATH=$2
    local PURPOSE=$3
    
    echo -e "${YELLOW}Syncing to ${PURPOSE} (${HOST})...${NC}"
    rsync -avz --progress \
        -e "ssh -i ${SSH_KEY_PATH}" \
        --exclude='docs/build/' \
        --exclude='docs/node_modules/' \
        --exclude='.git/' \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='experiments/*/output/' \
        --exclude='cluster_config.sh' \
        --exclude='*_server_connect.sh' \
        --exclude='*.key' \
        --exclude='*.pem' \
        "${LOCAL_PATH}/" "${HOST}:${PATH}/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Sync to ${PURPOSE} completed${NC}"
        return 0
    else
        echo -e "${RED}✗ Sync to ${PURPOSE} failed${NC}"
        return 1
    fi
}

# Sync to fileserver (backup)
if [ "$1" != "--cluster-only" ]; then
    sync_to_remote "${FILESERVER_HOST}" "${FILESERVER_PATH}" "fileserver (backup)"
fi

# Sync to HPC cluster (computation)
sync_to_remote "${CLUSTER_HOST}" "${CLUSTER_PATH}" "HPC cluster"

# Handle command line options
case "$1" in
    "--setup")
        echo -e "${YELLOW}Setting up Julia environment on HPC cluster...${NC}"
        ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "cd ${CLUSTER_PATH} && module load julia 2>/dev/null || echo 'No module system found, checking for Julia...' && which julia || echo 'Julia not found in PATH'"
        ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "cd ${CLUSTER_PATH} && JULIA_NUM_THREADS=${JULIA_THREADS} julia --project=${JULIA_PROJECT} -e 'using Pkg; Pkg.instantiate()'"
        ;;
    "--test")
        echo -e "${YELLOW}Running tests on HPC cluster (using ${JULIA_THREADS} threads)...${NC}"
        ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "cd ${CLUSTER_PATH} && module load julia 2>/dev/null || true && JULIA_NUM_THREADS=${JULIA_THREADS} julia --project=${JULIA_PROJECT} -e 'using Pkg; Pkg.instantiate(); Pkg.test()'"
        ;;
    "--interactive")
        echo -e "${YELLOW}Starting interactive session on HPC cluster...${NC}"
        ssh -i "${SSH_KEY_PATH}" -t "${CLUSTER_HOST}" "cd ${CLUSTER_PATH} && bash -l"
        ;;
    "--julia")
        echo -e "${YELLOW}Starting Julia on HPC cluster...${NC}"
        ssh -i "${SSH_KEY_PATH}" -t "${CLUSTER_HOST}" "cd ${CLUSTER_PATH} && module load julia 2>/dev/null || true && JULIA_NUM_THREADS=${JULIA_THREADS} julia --project=${JULIA_PROJECT}"
        ;;
esac

echo -e "${GREEN}✓ HPC deployment completed${NC}"
