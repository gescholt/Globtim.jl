#!/bin/bash

# Globtim Project Upload Script
# Automatically syncs project to fileserver and runs tests

set -e  # Exit on any error

# Configuration - Load from environment or config file
# Create a file called 'cluster_config.sh' (gitignored) with your settings:
# export REMOTE_HOST="your_username@your_server"
# export REMOTE_PATH="~/globtim"
# export SSH_KEY_PATH="~/.ssh/id_ed25519"

if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Warning: cluster_config.sh not found. Using defaults."
    echo "Create cluster_config.sh with your server configuration."
fi

REMOTE_HOST="${REMOTE_HOST:-scholten@fileserver-ssh}"
REMOTE_PATH="${REMOTE_PATH:-~/globtim}"
LOCAL_PATH="${LOCAL_PATH:-$(pwd)}"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_ed25519}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Globtim upload to cluster...${NC}"

# Security checks
echo -e "${YELLOW}Running security checks...${NC}"

# Check SSH key permissions
if [ -f "${SSH_KEY_PATH}" ]; then
    KEY_PERMS=$(stat -f "%A" "${SSH_KEY_PATH}" 2>/dev/null || stat -c "%a" "${SSH_KEY_PATH}" 2>/dev/null)
    if [ "$KEY_PERMS" != "600" ]; then
        echo -e "${RED}Warning: SSH key has insecure permissions ($KEY_PERMS). Should be 600.${NC}"
        echo "Run: chmod 600 ${SSH_KEY_PATH}"
    fi
else
    echo -e "${RED}Warning: SSH key not found at ${SSH_KEY_PATH}${NC}"
fi

# Check for sensitive files that shouldn't be uploaded
SENSITIVE_FILES=$(find . -name "*.key" -o -name "*.pem" -o -name "*password*" -o -name "*secret*" | head -5)
if [ -n "$SENSITIVE_FILES" ]; then
    echo -e "${RED}Warning: Found potentially sensitive files:${NC}"
    echo "$SENSITIVE_FILES"
    echo -e "${YELLOW}These will be excluded from upload${NC}"
fi

# Sync project files (excluding large/unnecessary files)
echo -e "${YELLOW}Syncing project files...${NC}"
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
    "${LOCAL_PATH}/" "${REMOTE_HOST}:${REMOTE_PATH}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Upload completed successfully${NC}"
else
    echo -e "${RED}✗ Upload failed${NC}"
    exit 1
fi

# Optional: Run remote commands
if [ "$1" = "--test" ]; then
    echo -e "${YELLOW}Running tests on remote server (using ${JULIA_THREADS} threads)...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "cd ${REMOTE_PATH} && JULIA_NUM_THREADS=${JULIA_THREADS} julia --project=${JULIA_PROJECT} -e 'using Pkg; Pkg.instantiate(); Pkg.test()'"
fi

if [ "$1" = "--setup" ]; then
    echo -e "${YELLOW}Setting up Julia environment on remote server (using ${JULIA_THREADS} threads)...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "cd ${REMOTE_PATH} && JULIA_NUM_THREADS=${JULIA_THREADS} julia --project=${JULIA_PROJECT} -e 'using Pkg; Pkg.instantiate()'"
fi

echo -e "${GREEN}✓ All operations completed${NC}"
