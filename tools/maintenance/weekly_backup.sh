#!/bin/bash

# Weekly Backup Script for Globtim Project
# Automatically backs up project to fileserver with versioning

set -e

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found. Please create it first."
    exit 1
fi

# Configuration
BACKUP_DIR="globtim_backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="globtim_backup_${DATE}"
LOCAL_PATH="$(pwd)"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_ed25519}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Globtim Weekly Backup ===${NC}"
echo -e "${YELLOW}Starting backup: ${BACKUP_NAME}${NC}"

# Create backup directory on remote server
echo -e "${YELLOW}Creating backup directory on server...${NC}"
ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "mkdir -p ${BACKUP_DIR}"

# Create local temporary backup (excluding unnecessary files)
echo -e "${YELLOW}Creating compressed backup...${NC}"
tar -czf "/tmp/${BACKUP_NAME}.tar.gz" \
    --exclude='.git' \
    --exclude='docs/build' \
    --exclude='docs/node_modules' \
    --exclude='*.log' \
    --exclude='*.tmp' \
    --exclude='experiments/*/output' \
    --exclude='cluster_config.sh' \
    --exclude='*_server_connect.sh' \
    --exclude='*.key' \
    --exclude='*.pem' \
    -C "$(dirname "$LOCAL_PATH")" "$(basename "$LOCAL_PATH")"

# Get backup size
BACKUP_SIZE=$(du -h "/tmp/${BACKUP_NAME}.tar.gz" | cut -f1)
echo -e "${GREEN}✓ Backup created: ${BACKUP_SIZE}${NC}"

# Upload backup to server
echo -e "${YELLOW}Uploading backup to server...${NC}"
scp -i "${SSH_KEY_PATH}" "/tmp/${BACKUP_NAME}.tar.gz" "${REMOTE_HOST}:${BACKUP_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup uploaded successfully${NC}"
    
    # Clean up local temporary file
    rm "/tmp/${BACKUP_NAME}.tar.gz"
    
    # Create backup manifest on server
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "
        cd ${BACKUP_DIR}
        echo '${DATE}: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})' >> backup_manifest.txt
        echo 'Backup created from: ${LOCAL_PATH}' >> backup_manifest.txt
        echo '---' >> backup_manifest.txt
    "
    
    # Clean up old backups (keep last 8 weeks)
    echo -e "${YELLOW}Cleaning up old backups (keeping last 8 weeks)...${NC}"
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "
        cd ${BACKUP_DIR}
        ls -t globtim_backup_*.tar.gz | tail -n +9 | xargs -r rm -f
        echo 'Old backups cleaned up'
    "
    
    # Show backup status
    echo -e "${BLUE}=== Backup Status ===${NC}"
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "
        cd ${BACKUP_DIR}
        echo 'Available backups:'
        ls -lah globtim_backup_*.tar.gz | tail -8
        echo ''
        echo 'Total backup space used:'
        du -sh .
    "
    
    echo -e "${GREEN}✓ Weekly backup completed successfully!${NC}"
    
else
    echo -e "${RED}✗ Backup upload failed${NC}"
    rm "/tmp/${BACKUP_NAME}.tar.gz"
    exit 1
fi
