#!/bin/bash

# Auto-Pull Daemon for JSON-Tracked Results
# Can be run as a cron job or background process to automatically pull completed results

set -e

# Configuration
GLOBTIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="$GLOBTIM_DIR/hpc/infrastructure/.auto_pull.log"
LOCK_FILE="$GLOBTIM_DIR/hpc/infrastructure/.auto_pull.lock"
MAX_LOG_LINES=1000

# Colors for output (only if running interactively)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" | tee -a "$LOG_FILE"
    
    # Rotate log if it gets too large
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
            tail -n $((MAX_LOG_LINES / 2)) "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated" >> "$LOG_FILE"
        fi
    fi
}

cleanup() {
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# Check for lock file (prevent multiple instances)
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        log_message "${YELLOW}Auto-pull daemon already running (PID: $LOCK_PID)${NC}"
        exit 0
    else
        log_message "${YELLOW}Removing stale lock file${NC}"
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Change to Globtim directory
cd "$GLOBTIM_DIR"

log_message "${BLUE}🤖 Auto-pull daemon starting${NC}"
log_message "Working directory: $GLOBTIM_DIR"
log_message "Log file: $LOG_FILE"

# Check if job tracker exists
if [ ! -f "hpc/infrastructure/job_tracker.py" ]; then
    log_message "${RED}❌ Job tracker not found: hpc/infrastructure/job_tracker.py${NC}"
    exit 1
fi

# Run auto-pull check
log_message "${YELLOW}🔍 Checking for completed jobs...${NC}"

# Capture output from job tracker
TRACKER_OUTPUT=$(python3 hpc/infrastructure/job_tracker.py --auto-pull 2>&1)
TRACKER_EXIT=$?

if [ $TRACKER_EXIT -eq 0 ]; then
    # Parse the output for summary information
    CHECKED=$(echo "$TRACKER_OUTPUT" | grep "Jobs checked:" | grep -o "[0-9]*" || echo "0")
    PULLED=$(echo "$TRACKER_OUTPUT" | grep "Results pulled:" | grep -o "[0-9]*" || echo "0")
    FAILED=$(echo "$TRACKER_OUTPUT" | grep "Pull failures:" | grep -o "[0-9]*" || echo "0")
    
    if [ "$PULLED" -gt 0 ]; then
        log_message "${GREEN}✅ Successfully pulled $PULLED result(s)${NC}"
        
        # Log which computations were pulled
        echo "$TRACKER_OUTPUT" | grep "Successfully pulled results for" | while read -r line; do
            COMP_ID=$(echo "$line" | grep -o "[a-zA-Z0-9]*$")
            log_message "   📥 Pulled computation: $COMP_ID"
        done
    elif [ "$CHECKED" -gt 0 ]; then
        log_message "${BLUE}ℹ️  Checked $CHECKED job(s), none ready for pulling${NC}"
    else
        log_message "${BLUE}ℹ️  No pending jobs to check${NC}"
    fi
    
    if [ "$FAILED" -gt 0 ]; then
        log_message "${YELLOW}⚠️  $FAILED pull attempt(s) failed${NC}"
    fi
else
    log_message "${RED}❌ Auto-pull check failed (exit code: $TRACKER_EXIT)${NC}"
    log_message "Output: $TRACKER_OUTPUT"
fi

log_message "${BLUE}🤖 Auto-pull daemon completed${NC}"

# If running interactively, show recent activity
if [ -t 1 ]; then
    echo ""
    echo -e "${BLUE}📊 Recent Activity (last 10 entries):${NC}"
    tail -n 10 "$LOG_FILE" | grep -v "Auto-pull daemon completed" | grep -v "Auto-pull daemon starting"
    
    echo ""
    echo -e "${YELLOW}💡 Setup Tips:${NC}"
    echo "  # Run every 5 minutes via cron:"
    echo "  */5 * * * * cd $GLOBTIM_DIR && ./hpc/infrastructure/auto_pull_daemon.sh >/dev/null 2>&1"
    echo ""
    echo "  # Run as background daemon (checks every 5 minutes):"
    echo "  nohup bash -c 'while true; do ./hpc/infrastructure/auto_pull_daemon.sh; sleep 300; done' &"
    echo ""
    echo "  # View live log:"
    echo "  tail -f $LOG_FILE"
fi
