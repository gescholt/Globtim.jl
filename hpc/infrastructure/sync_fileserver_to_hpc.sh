#!/bin/bash

# Sync from Fileserver to HPC Cluster
# Uses fileserver as the central repository and syncs to HPC for computation

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

echo -e "${BLUE}=== Fileserver → HPC Sync Workflow ===${NC}"

# Step 1: Sync local changes to fileserver (backup)
echo -e "${YELLOW}Step 1: Syncing local changes to fileserver...${NC}"
cd "${LOCAL_PATH}"
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
    ./ "${FILESERVER_HOST}:${FILESERVER_PATH}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Local → Fileserver sync completed${NC}"
else
    echo -e "${RED}✗ Local → Fileserver sync failed${NC}"
    exit 1
fi

# Step 2: Sync from fileserver to HPC cluster (lightweight version)
echo -e "${YELLOW}Step 2: Syncing fileserver to HPC cluster (excluding visualization)...${NC}"

# Use temporary path in home directory until /projects/globtim is available
HPC_TARGET_PATH="~/globtim_hpc"

# Create a script to run on the fileserver that syncs to HPC
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    cd ${FILESERVER_PATH}
    echo 'Syncing lightweight version to HPC cluster...'
    rsync -avz --progress \
        -e 'ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no' \
        --exclude='docs/' \
        --exclude='Examples/Notebooks/' \
        --exclude='Examples/**/*.png' \
        --exclude='Examples/**/*.pdf' \
        --exclude='Examples/**/*.ipynb' \
        --exclude='experiments/' \
        --exclude='wiki/' \
        --exclude='reports/' \
        --exclude='bib/' \
        --exclude='scripts/' \
        --exclude='ext/' \
        --exclude='.git/' \
        --exclude='.github/' \
        --exclude='.gitlab/' \
        --exclude='.vscode/' \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='cluster_config.sh' \
        --exclude='*_server_connect.sh' \
        --exclude='*.key' \
        --exclude='*.pem' \
        --exclude='*deploy*.sh' \
        --exclude='*backup*.sh' \
        --exclude='*security*.sh' \
        --exclude='*ssh*.sh' \
        --exclude='Manifest.toml' \
        --include='src/' \
        --include='test/' \
        --include='data/' \
        --include='Project.toml' \
        --include='README.md' \
        --include='LICENSE' \
        ./ ${CLUSTER_HOST}:${HPC_TARGET_PATH}/

    echo 'Copying HPC-specific Project.toml...'
    scp -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no Project_HPC.toml ${CLUSTER_HOST}:${HPC_TARGET_PATH}/Project.toml
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Fileserver → HPC sync completed${NC}"
else
    echo -e "${RED}✗ Fileserver → HPC sync failed${NC}"
    echo -e "${YELLOW}Trying direct sync instead...${NC}"
    
    # Fallback: Direct lightweight sync from local to HPC
    cd "${LOCAL_PATH}"
    echo "Using direct sync fallback (lightweight version)..."
    rsync -avz --progress \
        -e "ssh -i ${SSH_KEY_PATH}" \
        --exclude='docs/' \
        --exclude='Examples/Notebooks/' \
        --exclude='Examples/**/*.png' \
        --exclude='Examples/**/*.pdf' \
        --exclude='Examples/**/*.ipynb' \
        --exclude='experiments/' \
        --exclude='wiki/' \
        --exclude='reports/' \
        --exclude='bib/' \
        --exclude='scripts/' \
        --exclude='ext/' \
        --exclude='.git/' \
        --exclude='.github/' \
        --exclude='.gitlab/' \
        --exclude='.vscode/' \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='cluster_config.sh' \
        --exclude='*_server_connect.sh' \
        --exclude='*.key' \
        --exclude='*.pem' \
        --exclude='*deploy*.sh' \
        --exclude='*backup*.sh' \
        --exclude='*security*.sh' \
        --exclude='*ssh*.sh' \
        --exclude='Manifest.toml' \
        --include='src/' \
        --include='test/' \
        --include='data/' \
        --include='README.md' \
        --include='LICENSE' \
        ./ "${CLUSTER_HOST}:${HPC_TARGET_PATH}/"

    # Copy HPC-specific Project.toml
    scp -i "${SSH_KEY_PATH}" Project_HPC.toml "${CLUSTER_HOST}:${HPC_TARGET_PATH}/Project.toml"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Direct local → HPC sync completed${NC}"
    else
        echo -e "${RED}✗ All sync methods failed${NC}"
        exit 1
    fi
fi

# Step 3: Test Julia on HPC
if [ "$1" = "--test" ]; then
    echo -e "${YELLOW}Step 3: Testing lightweight Julia setup on HPC cluster...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
        cd ${HPC_TARGET_PATH}
        echo 'Testing Julia setup...'
        /sw/bin/julia --version
        echo 'Julia with threading:'
        JULIA_NUM_THREADS=auto /sw/bin/julia -e 'println(\"Julia \", VERSION, \" with \", Threads.nthreads(), \" threads\")'
        echo 'Testing basic packages:'
        JULIA_NUM_THREADS=auto /sw/bin/julia -e 'using LinearAlgebra, Statistics; println(\"Basic packages work!\")'
        echo 'Package instantiation (lightweight):'
        JULIA_NUM_THREADS=auto /sw/bin/julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.status()'
        echo 'Testing Globtim module:'
        JULIA_NUM_THREADS=auto /sw/bin/julia --project=. -e 'using Globtim; println(\"Globtim loaded successfully!\")'
    "
fi

# Step 4: Interactive session
if [ "$1" = "--interactive" ]; then
    echo -e "${YELLOW}Starting interactive HPC session...${NC}"
    ssh -i "${SSH_KEY_PATH}" -t "${CLUSTER_HOST}" "cd ${HPC_TARGET_PATH} && bash -l"
fi

# Step 5: Julia session
if [ "$1" = "--julia" ]; then
    echo -e "${YELLOW}Starting Julia on HPC cluster...${NC}"
    ssh -i "${SSH_KEY_PATH}" -t "${CLUSTER_HOST}" "cd ${HPC_TARGET_PATH} && JULIA_NUM_THREADS=auto /sw/bin/julia --project=."
fi

echo -e "${GREEN}✓ Lightweight HPC sync workflow completed${NC}"
echo -e "${YELLOW}Your project is now available on:${NC}"
echo "• Fileserver (full): ${FILESERVER_HOST}:${FILESERVER_PATH}"
echo "• HPC Cluster (lightweight): ${CLUSTER_HOST}:${HPC_TARGET_PATH}"
echo ""
echo -e "${YELLOW}HPC version excludes:${NC}"
echo "• Visualization packages (Makie, ProfileView, Colors)"
echo "• Documentation, notebooks, examples with plots"
echo "• Large binary files and build artifacts"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "• Test Julia: ./sync_fileserver_to_hpc.sh --test"
echo "• Interactive: ./sync_fileserver_to_hpc.sh --interactive"
echo "• Julia REPL: ./sync_fileserver_to_hpc.sh --julia"
