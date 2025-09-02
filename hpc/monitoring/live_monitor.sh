#!/bin/bash
# Live Monitoring Script for GlobTim HPC Experiments
# Monitors both SLURM jobs and Screen sessions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default settings
REFRESH_INTERVAL=${REFRESH_INTERVAL:-10}  # seconds between updates
GLOBTIM_DIR="${GLOBTIM_DIR:-/globtim}"

function print_header() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                  GlobTim Job Live Monitor                        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

function monitor_job() {
    local job_id=$1
    
    if [ -z "$job_id" ]; then
        echo "Usage: $0 <job_id>"
        exit 1
    fi
    
    echo -e "${GREEN}Starting live monitoring for Job ID: $job_id${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}\n"
    
    # Main monitoring loop
    while true; do
        clear
        print_header
        echo -e "${BLUE}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "${BLUE}Job ID:${NC} $job_id\n"
        
        # Check if job is still running
        if squeue -j $job_id 2>/dev/null | grep -q $job_id; then
            echo -e "${GREEN}▶ JOB STATUS: RUNNING${NC}"
            echo "─────────────────────────────────────────────────"
            
            # Show job details
            squeue -j $job_id --format="%.18i %.9P %.30j %.8u %.2t %.10M %.6D %R"
            echo ""
            
            # Show resource usage
            echo -e "${BLUE}RESOURCE USAGE:${NC}"
            echo "─────────────────────────────────────────────────"
            sstat -j $job_id --format=JobID,MaxRSS,MaxVMSize,AveCPU,TotalCPU 2>/dev/null || echo "Resource stats not yet available"
            echo ""
            
            # Show latest output from log files
            LOG_FILE="$GLOBTIM_DIR/slurm_logs/*_${job_id}.out"
            if ls $LOG_FILE 1> /dev/null 2>&1; then
                echo -e "${BLUE}LATEST OUTPUT (last 15 lines):${NC}"
                echo "─────────────────────────────────────────────────"
                tail -n 15 $LOG_FILE 2>/dev/null | sed 's/^/  /'
            fi
            
            # Check for result files being generated
            RESULTS_DIR="$GLOBTIM_DIR/hpc_results/*_job${job_id}"
            if ls -d $RESULTS_DIR 1> /dev/null 2>&1; then
                echo ""
                echo -e "${BLUE}RESULT FILES:${NC}"
                echo "─────────────────────────────────────────────────"
                for dir in $RESULTS_DIR; do
                    if [ -d "$dir" ]; then
                        file_count=$(ls -1 "$dir" 2>/dev/null | wc -l)
                        echo "  📁 $(basename $dir): $file_count files"
                        # Show recent files
                        ls -lt "$dir" 2>/dev/null | head -5 | tail -4 | sed 's/^/     /'
                    fi
                done
            fi
            
        else
            # Job has finished
            echo -e "${YELLOW}▶ JOB STATUS: COMPLETED/STOPPED${NC}"
            echo "─────────────────────────────────────────────────"
            
            # Show final job statistics
            sacct -j $job_id --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS,TotalCPU
            
            # Show final output
            LOG_FILE="$GLOBTIM_DIR/slurm_logs/*_${job_id}.out"
            if ls $LOG_FILE 1> /dev/null 2>&1; then
                echo ""
                echo -e "${BLUE}FINAL OUTPUT (last 30 lines):${NC}"
                echo "─────────────────────────────────────────────────"
                tail -n 30 $LOG_FILE 2>/dev/null
            fi
            
            # Check for errors
            ERR_FILE="$GLOBTIM_DIR/slurm_logs/*_${job_id}.err"
            if ls $ERR_FILE 1> /dev/null 2>&1; then
                if [ -s "$(ls $ERR_FILE)" ]; then
                    echo ""
                    echo -e "${RED}ERRORS DETECTED:${NC}"
                    echo "─────────────────────────────────────────────────"
                    tail -n 20 $ERR_FILE 2>/dev/null
                fi
            fi
            
            echo ""
            echo -e "${GREEN}Monitoring complete. Job has finished.${NC}"
            break
        fi
        
        # Show refresh countdown
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "Refreshing in $REFRESH_INTERVAL seconds... (Press Ctrl+C to stop)"
        sleep $REFRESH_INTERVAL
    done
}

# Function to monitor Screen sessions
function monitor_screen() {
    local session_name=$1
    
    if [ -z "$session_name" ]; then
        echo "Active GlobTim Screen sessions:"
        screen -ls | grep globtim || echo "No sessions found"
        return
    fi
    
    echo -e "${GREEN}▶ SCREEN SESSION: $session_name${NC}"
    echo "─────────────────────────────────────────────────"
    
    # Check if session exists
    if screen -ls | grep -q "$session_name"; then
        echo "Status: RUNNING"
        echo "To attach: screen -r $session_name"
        
        # Check for log files
        LOG_DIR="$GLOBTIM_DIR/hpc_results/${session_name}"
        if [ -d "$LOG_DIR" ]; then
            echo ""
            echo -e "${BLUE}LATEST OUTPUT:${NC}"
            if [ -f "$LOG_DIR/output.log" ]; then
                tail -n 20 "$LOG_DIR/output.log"
            fi
        fi
    else
        echo "Session not found or completed"
    fi
}

# Function to monitor all experiments (Screen + SLURM)
function monitor_all() {
    while true; do
        clear
        print_header
        echo -e "${BLUE}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
        
        echo -e "${BLUE}ACTIVE SCREEN SESSIONS:${NC}"
        echo "─────────────────────────────────────────────────"
        screen -ls | grep globtim || echo "No active Screen sessions"
        
        echo ""
        echo -e "${BLUE}JULIA PROCESSES:${NC}"
        echo "─────────────────────────────────────────────────"
        ps aux | grep julia | grep -v grep | head -5 || echo "No Julia processes"
        
        echo ""
        echo -e "${BLUE}LATEST RESULTS:${NC}"
        echo "─────────────────────────────────────────────────"
        ls -lt $GLOBTIM_DIR/hpc_results/ 2>/dev/null | head -6 | tail -5
        
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo "Options: Enter session name to monitor, or Ctrl+C to exit"
        echo -e "Refreshing in $REFRESH_INTERVAL seconds..."
        
        # Wait for input with timeout
        read -t $REFRESH_INTERVAL -p "Session name: " session_input
        if [ ! -z "$session_input" ]; then
            monitor_screen $session_input
            read -p "Press Enter to continue..."
        fi
    done
}

# Main script logic
case "${1:-}" in
    "")
        # No arguments - monitor all jobs
        monitor_all
        ;;
    *)
        # Job ID provided - monitor specific job
        monitor_job "$1"
        ;;
esac