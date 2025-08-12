#!/bin/bash
# deploy_to_hpc_robust.sh - Robust deployment with diagnostics and fallback options
# Usage: ./deploy_to_hpc_robust.sh [bundle_file]

set -e  # Exit on any error

# Configuration
BUNDLE_FILE=${1:-julia_depot_bundle_hpc_$(date +%Y%m%d).tar.gz}
SSH_KEY="$HOME/.ssh/id_ed25519"
FILESERVER_HOSTS=("scholten@fileserver-ssh" "scholten@mack")
CLUSTER="scholten@falcon"
TARGET_DIR="~/globtim_hpc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Globtim HPC Bundle Deployment (Robust) ===${NC}"
echo "Bundle file: $BUNDLE_FILE"
echo "SSH key: $SSH_KEY"
echo "Date: $(date)"
echo ""

# Function to test SSH connectivity
test_ssh_connection() {
    local host=$1
    local timeout=10
    
    echo -e "${YELLOW}Testing SSH connection to $host...${NC}"
    
    # Test basic connectivity
    if ! ping -c 1 -W 3 $(echo $host | cut -d'@' -f2) >/dev/null 2>&1; then
        echo -e "${RED}❌ Host $(echo $host | cut -d'@' -f2) is not reachable via ping${NC}"
        return 1
    fi
    
    # Test SSH port
    if ! nc -zv $(echo $host | cut -d'@' -f2) 22 2>/dev/null; then
        echo -e "${RED}❌ SSH port 22 is not accessible on $host${NC}"
        return 1
    fi
    
    # Test SSH authentication
    if ssh -i "$SSH_KEY" -o ConnectTimeout=$timeout -o BatchMode=yes "$host" "echo 'SSH test successful'" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH connection to $host successful${NC}"
        return 0
    else
        echo -e "${RED}❌ SSH authentication failed for $host${NC}"
        return 1
    fi
}

# Function to deploy to a specific host
deploy_to_host() {
    local host=$1
    
    echo -e "${BLUE}Deploying to $host...${NC}"
    
    # Transfer bundle
    echo "Transferring bundle..."
    if rsync -avz --progress -e "ssh -i $SSH_KEY" "$BUNDLE_FILE" "$host:$TARGET_DIR/"; then
        echo -e "${GREEN}✅ Bundle transferred successfully${NC}"
    else
        echo -e "${RED}❌ Bundle transfer failed${NC}"
        return 1
    fi
    
    # Transfer scripts
    echo "Transferring installation scripts..."
    if rsync -avz --progress -e "ssh -i $SSH_KEY" \
        install_bundle_hpc.sh test_hpc_bundle.slurm README_HPC_Bundle.md bundle_manifest_hpc.txt \
        "$host:$TARGET_DIR/"; then
        echo -e "${GREEN}✅ Scripts transferred successfully${NC}"
    else
        echo -e "${RED}❌ Script transfer failed${NC}"
        return 1
    fi
    
    # Install bundle
    echo "Installing bundle on remote host..."
    if ssh -i "$SSH_KEY" "$host" "cd $TARGET_DIR && chmod +x install_bundle_hpc.sh && ./install_bundle_hpc.sh $BUNDLE_FILE"; then
        echo -e "${GREEN}✅ Bundle installed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Bundle installation failed${NC}"
        return 1
    fi
}

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
    exit 1
fi

echo -e "${YELLOW}Bundle size: $(ls -lh "$BUNDLE_FILE" | awk '{print $5}')${NC}"
echo ""

# Test connections and find working host
WORKING_HOST=""
for host in "${FILESERVER_HOSTS[@]}"; do
    if test_ssh_connection "$host"; then
        WORKING_HOST="$host"
        break
    fi
done

if [ -z "$WORKING_HOST" ]; then
    echo -e "${RED}❌ No working SSH connections found${NC}"
    echo ""
    echo -e "${YELLOW}Possible solutions:${NC}"
    echo "1. Check if you're connected to the correct network/VPN"
    echo "2. Verify SSH services are running on the remote hosts"
    echo "3. Check if hostnames have changed"
    echo "4. Try connecting manually: ssh -i $SSH_KEY scholten@fileserver-ssh"
    echo ""
    echo -e "${BLUE}Manual deployment instructions:${NC}"
    echo "1. Copy bundle manually when connection is available:"
    echo "   scp -i $SSH_KEY $BUNDLE_FILE scholten@fileserver-ssh:$TARGET_DIR/"
    echo "2. Copy scripts:"
    echo "   scp -i $SSH_KEY install_bundle_hpc.sh test_hpc_bundle.slurm README_HPC_Bundle.md bundle_manifest_hpc.txt scholten@fileserver-ssh:$TARGET_DIR/"
    echo "3. Install on remote host:"
    echo "   ssh -i $SSH_KEY scholten@fileserver-ssh"
    echo "   cd $TARGET_DIR && ./install_bundle_hpc.sh $BUNDLE_FILE"
    exit 1
fi

# Deploy to working host
echo -e "${GREEN}Using working host: $WORKING_HOST${NC}"
if deploy_to_host "$WORKING_HOST"; then
    echo ""
    echo -e "${GREEN}=== Deployment Successful ===${NC}"
    echo "Bundle deployed to: $WORKING_HOST:$TARGET_DIR"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. SSH to host: ssh -i $SSH_KEY $WORKING_HOST"
    echo "2. Test installation: cd $TARGET_DIR && sbatch test_hpc_bundle.slurm"
    echo "3. Check results: cat test_globtim_hpc_*.out"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
