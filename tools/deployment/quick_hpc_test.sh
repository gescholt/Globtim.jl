#!/bin/bash

# Quick HPC Test - Test Julia on the cluster using home directory
# Use this while waiting for /projects space approval

set -e

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

echo -e "${BLUE}=== Quick HPC Test for Globtim ===${NC}"

# Use home directory temporarily (since /projects/globtim doesn't exist yet)
TEMP_CLUSTER_PATH="~/globtim_test"

echo -e "${YELLOW}Syncing small test to HPC cluster home directory...${NC}"
rsync -avz --progress \
    -e "ssh -i ${SSH_KEY_PATH}" \
    --exclude='docs/' \
    --exclude='experiments/' \
    --exclude='.git/' \
    --exclude='*.log' \
    --exclude='*.tmp' \
    --exclude='cluster_config.sh' \
    --include='src/' \
    --include='test/' \
    --include='Project.toml' \
    --include='Manifest.toml' \
    --exclude='*' \
    "${LOCAL_PATH}/" "${CLUSTER_HOST}:${TEMP_CLUSTER_PATH}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Sync completed${NC}"
else
    echo -e "${RED}✗ Sync failed${NC}"
    exit 1
fi

# Test Julia on the cluster
echo -e "${YELLOW}Testing Julia on HPC cluster...${NC}"
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    cd ${TEMP_CLUSTER_PATH}
    echo 'Testing Julia installation...'
    /sw/bin/julia --version
    echo ''
    echo 'Testing Julia with threading...'
    JULIA_NUM_THREADS=auto /sw/bin/julia -e 'println(\"Julia \", VERSION, \" with \", Threads.nthreads(), \" threads\")'
    echo ''
    echo 'Testing basic Julia package operations...'
    JULIA_NUM_THREADS=auto /sw/bin/julia --project=. -e '
        using Pkg
        println(\"Current project: \", Base.active_project())
        println(\"Instantiating packages...\")
        Pkg.instantiate()
        println(\"Package status:\")
        Pkg.status()
    '
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Julia test completed successfully!${NC}"
    echo -e "${YELLOW}Julia is working on the HPC cluster${NC}"
else
    echo -e "${RED}✗ Julia test failed${NC}"
fi

echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo "1. Email hpcsupport for /projects/globtim space"
echo "2. Once approved, run: ./setup_hpc_project_space.sh --configure"
echo "3. Then use: ./deploy_to_hpc.sh for full deployment"
echo ""
echo -e "${YELLOW}For now, you can work in the test directory:${NC}"
echo "ssh ${CLUSTER_HOST} 'cd ${TEMP_CLUSTER_PATH} && /sw/bin/julia --project=.'"
