#!/bin/bash

# Setup SSH keys from fileserver to HPC cluster
# This allows the fileserver to directly sync to HPC

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

echo -e "${BLUE}=== Setting up Fileserver → HPC SSH Keys ===${NC}"

echo -e "${YELLOW}Step 1: Creating SSH key on fileserver...${NC}"
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    # Create SSH key on fileserver if it doesn't exist
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo 'Generating SSH key on fileserver...'
        ssh-keygen -t ed25519 -C 'fileserver-to-hpc' -f ~/.ssh/id_ed25519 -N ''
        echo 'SSH key generated'
    else
        echo 'SSH key already exists on fileserver'
    fi
    
    # Show the public key
    echo 'Public key to copy to HPC:'
    cat ~/.ssh/id_ed25519.pub
"

echo -e "${YELLOW}Step 2: Copying fileserver public key to HPC cluster...${NC}"

# Get the public key from fileserver
FILESERVER_PUBKEY=$(ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "cat ~/.ssh/id_ed25519.pub")

# Add it to HPC cluster authorized_keys
ssh -i "${SSH_KEY_PATH}" "${CLUSTER_HOST}" "
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Add fileserver key to authorized_keys if not already there
    if ! grep -q '${FILESERVER_PUBKEY}' ~/.ssh/authorized_keys 2>/dev/null; then
        echo '${FILESERVER_PUBKEY}' >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo 'Fileserver public key added to HPC authorized_keys'
    else
        echo 'Fileserver public key already in HPC authorized_keys'
    fi
"

echo -e "${YELLOW}Step 3: Testing fileserver → HPC connection...${NC}"
ssh -i "${SSH_KEY_PATH}" "${FILESERVER_HOST}" "
    echo 'Testing connection from fileserver to HPC...'
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${CLUSTER_HOST} 'echo \"Connection successful from fileserver to HPC!\"'
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Fileserver → HPC SSH setup completed successfully!${NC}"
    echo -e "${YELLOW}Now you can use: ./sync_fileserver_to_hpc.sh${NC}"
else
    echo -e "${RED}✗ SSH setup failed${NC}"
    echo -e "${YELLOW}You can still use direct sync as fallback${NC}"
fi

echo -e "\n${BLUE}=== Workflow Summary ===${NC}"
echo "1. Local → Fileserver (backup)"
echo "2. Fileserver → HPC (computation)"
echo "3. All your data is safely backed up on fileserver"
echo "4. HPC gets clean copy for computation"
