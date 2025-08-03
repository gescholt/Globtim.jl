#!/bin/bash

# Setup Automated Weekly Backups
# Configures cron job for automatic weekly backups

PROJECT_DIR="$(pwd)"
BACKUP_SCRIPT="${PROJECT_DIR}/weekly_backup.sh"
LOG_FILE="${PROJECT_DIR}/backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Setting Up Weekly Automated Backups ===${NC}"

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo -e "${RED}Error: weekly_backup.sh not found${NC}"
    exit 1
fi

# Make scripts executable
chmod +x weekly_backup.sh restore_backup.sh

# Create cron job entry
CRON_ENTRY="0 2 * * 0 cd ${PROJECT_DIR} && ${BACKUP_SCRIPT} >> ${LOG_FILE} 2>&1"

echo -e "${YELLOW}Proposed cron job (runs every Sunday at 2 AM):${NC}"
echo "$CRON_ENTRY"
echo ""

echo -e "${YELLOW}This will:${NC}"
echo "• Run backup every Sunday at 2:00 AM"
echo "• Log output to: ${LOG_FILE}"
echo "• Keep last 8 weeks of backups"
echo "• Automatically clean up old backups"
echo ""

echo -e "${YELLOW}Add this cron job? (y/N):${NC}"
read -r CONFIRM

if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    
    echo -e "${GREEN}✓ Weekly backup cron job added${NC}"
    echo -e "${YELLOW}Current crontab:${NC}"
    crontab -l | grep -E "(globtim|weekly_backup)" || echo "No matching entries found"
    
    # Create initial log file
    touch "$LOG_FILE"
    echo "$(date): Weekly backup cron job configured" >> "$LOG_FILE"
    
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo -e "${YELLOW}To check backup logs: tail -f ${LOG_FILE}${NC}"
    echo -e "${YELLOW}To test backup now: ./weekly_backup.sh${NC}"
    
else
    echo "Setup cancelled. You can run backups manually with: ./weekly_backup.sh"
fi

echo -e "\n${BLUE}=== Backup Management Commands ===${NC}"
echo "• Manual backup:     ./weekly_backup.sh"
echo "• Restore backup:    ./restore_backup.sh"
echo "• View backup logs:  tail -f backup.log"
echo "• Remove cron job:   crontab -e (then delete the line)"
