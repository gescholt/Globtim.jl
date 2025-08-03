#!/bin/bash

# Backup Restoration Script
# Restores a specific backup from the fileserver

set -e

# Load configuration
if [ -f "cluster_config.sh" ]; then
    source cluster_config.sh
else
    echo "Error: cluster_config.sh not found. Please create it first."
    exit 1
fi

BACKUP_DIR="globtim_backups"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_ed25519}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Globtim Backup Restoration ===${NC}"

# List available backups
echo -e "${YELLOW}Available backups on server:${NC}"
ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "
    cd ${BACKUP_DIR} 2>/dev/null || { echo 'No backups found'; exit 1; }
    ls -lah globtim_backup_*.tar.gz | nl
"

# Get user selection
echo -e "${YELLOW}Enter the number of the backup to restore (or 'q' to quit):${NC}"
read -r SELECTION

if [ "$SELECTION" = "q" ]; then
    echo "Restoration cancelled."
    exit 0
fi

# Get the selected backup filename
BACKUP_FILE=$(ssh -i "${SSH_KEY_PATH}" "${REMOTE_HOST}" "
    cd ${BACKUP_DIR}
    ls -t globtim_backup_*.tar.gz | sed -n '${SELECTION}p'
")

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

echo -e "${YELLOW}Selected backup: ${BACKUP_FILE}${NC}"
echo -e "${YELLOW}This will restore to: ./restored_backup/${NC}"
echo -e "${RED}Continue? (y/N):${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Restoration cancelled."
    exit 0
fi

# Create restoration directory
mkdir -p restored_backup

# Download and extract backup
echo -e "${YELLOW}Downloading backup...${NC}"
scp -i "${SSH_KEY_PATH}" "${REMOTE_HOST}:${BACKUP_DIR}/${BACKUP_FILE}" "/tmp/"

echo -e "${YELLOW}Extracting backup...${NC}"
tar -xzf "/tmp/${BACKUP_FILE}" -C restored_backup --strip-components=1

# Clean up
rm "/tmp/${BACKUP_FILE}"

echo -e "${GREEN}✓ Backup restored to ./restored_backup/${NC}"
echo -e "${YELLOW}Remember to copy any needed files to your current project${NC}"
