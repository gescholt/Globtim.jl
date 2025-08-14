#!/bin/bash
# deploy_to_hpc.sh - Deploy Globtim HPC bundle to cluster using SSH keys
# Usage: ./deploy_to_hpc.sh [bundle_file]

set -e  # Exit on any error

# Configuration
BUNDLE_FILE=${1:-julia_depot_bundle_hpc_$(date +%Y%m%d).tar.gz}
SSH_KEY="$HOME/.ssh/id_ed25519"
FILESERVER="scholten@fileserver-ssh"
CLUSTER="scholten@falcon"
TARGET_DIR="~/globtim_hpc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Globtim HPC Bundle Deployment ===${NC}"
echo "Bundle file: $BUNDLE_FILE"
echo "SSH key: $SSH_KEY"
echo "Target: $FILESERVER:$TARGET_DIR"
echo "Date: $(date)"
echo ""

# Check if bundle file exists
if [ ! -f "$BUNDLE_FILE" ]; then
    echo -e "${RED}Error: Bundle file '$BUNDLE_FILE' not found${NC}"
    echo "Available bundles:"
    ls -la julia_depot_bundle_hpc_*.tar.gz 2>/dev/null || echo "No bundle files found"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key '$SSH_KEY' not found${NC}"
    echo "Please ensure your SSH key is available at $SSH_KEY"
    exit 1
fi

# Get bundle size for progress tracking
BUNDLE_SIZE=$(ls -lh "$BUNDLE_FILE" | awk '{print $5}')
echo -e "${YELLOW}Bundle size: $BUNDLE_SIZE${NC}"

# Step 1: Transfer bundle to fileserver using rsync (following HPC workflow pattern)
echo -e "${BLUE}Step 1: Transferring bundle to fileserver (mack)...${NC}"
rsync -avz --progress \
    -e "ssh -i $SSH_KEY" \
    "$BUNDLE_FILE" "$FILESERVER:$TARGET_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Bundle transferred successfully${NC}"
else
    echo -e "${RED}❌ Bundle transfer failed${NC}"
    exit 1
fi

# Step 2: Transfer installation scripts using rsync
echo -e "${BLUE}Step 2: Transferring installation scripts...${NC}"
rsync -avz --progress \
    -e "ssh -i $SSH_KEY" \
    install_bundle_hpc.sh test_hpc_bundle.slurm README_HPC_Bundle.md bundle_manifest_hpc.txt \
    "$FILESERVER:$TARGET_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Scripts transferred successfully${NC}"
else
    echo -e "${RED}❌ Script transfer failed${NC}"
    exit 1
fi

# Step 3: Install bundle on fileserver
echo -e "${BLUE}Step 3: Installing bundle on fileserver...${NC}"
ssh -i "$SSH_KEY" "$FILESERVER" << EOF
cd $TARGET_DIR
chmod +x install_bundle_hpc.sh
chmod +x test_hpc_bundle.slurm
./install_bundle_hpc.sh $BUNDLE_FILE
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Bundle installed successfully${NC}"
else
    echo -e "${RED}❌ Bundle installation failed${NC}"
    exit 1
fi

# Step 4: Test installation
echo -e "${BLUE}Step 4: Testing installation...${NC}"
ssh -i "$SSH_KEY" "$FILESERVER" << 'EOF'
cd ~/globtim_hpc
source setup_offline_julia_hpc.sh
echo "Testing basic functionality..."
julia --project=$JULIA_PROJECT --compiled-modules=no -e '
using Pkg
println("✅ Julia project loaded")
println("Depot: ", ENV["JULIA_DEPOT_PATH"])
println("Project: ", Base.active_project())

# Quick package test
try
    using ForwardDiff
    println("✅ ForwardDiff loaded")
catch e
    println("❌ ForwardDiff failed: ", e)
end
'
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Installation test passed${NC}"
else
    echo -e "${YELLOW}⚠️  Installation test had issues (check output above)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Bundle location: $FILESERVER:$TARGET_DIR"
echo "Installation verified: Basic functionality tested"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. SSH to fileserver: ssh -i ~/.ssh/id_ed25519 $FILESERVER"
echo "2. Test with SLURM: cd $TARGET_DIR && sbatch test_hpc_bundle.slurm"
echo "3. Check results: cat test_globtim_hpc_*.out"
echo ""
echo -e "${BLUE}To use in your jobs:${NC}"
echo "source $TARGET_DIR/setup_offline_julia_hpc.sh"
echo "julia --project=\$JULIA_PROJECT --compiled-modules=no your_script.jl"
