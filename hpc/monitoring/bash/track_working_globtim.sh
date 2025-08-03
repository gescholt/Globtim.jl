#!/bin/bash

# Track Working Globtim Job
# Specifically monitors job 59770436 (working_globtim_30181439)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

JOB_ID="59770436"
JOB_NAME="working_globtim_30181439"
EXPERIMENT_DIR="results/experiments/working_globtim_20250803_163245"

echo -e "${BLUE}=== Tracking Working Globtim Job ===${NC}"
echo -e "${CYAN}Job ID:${NC} $JOB_ID"
echo -e "${CYAN}Job Name:${NC} $JOB_NAME"
echo -e "${CYAN}Timestamp:${NC} $(date)"
echo ""

# Check current status in queue
echo -e "${YELLOW}Queue Status:${NC}"
queue_status=$(squeue -j $JOB_ID --noheader 2>/dev/null)
if [ -n "$queue_status" ]; then
    echo "$queue_status" | awk '{
        status = $5
        time = $6
        reason = $8
        
        if (status == "PD") {
            printf "  🟡 PENDING - Waiting %s (%s)\n", time, reason
        } else if (status == "R") {
            printf "  🟢 RUNNING - Runtime %s\n", time
        } else {
            printf "  🔵 %s - Time %s\n", status, time
        }
    }'
else
    echo -e "  ${GREEN}✅ Job completed or not in queue${NC}"
    
    # Check completion status
    completion_status=$(sacct -j $JOB_ID --format=State,ExitCode,End --parsable2 --noheader 2>/dev/null | head -1)
    if [ -n "$completion_status" ]; then
        IFS='|' read -r state exitcode endtime <<< "$completion_status"
        echo -e "  ${BLUE}Final Status:${NC} $state"
        echo -e "  ${BLUE}Exit Code:${NC} $exitcode"
        echo -e "  ${BLUE}End Time:${NC} $endtime"
    fi
fi

echo ""

# Check for results
echo -e "${YELLOW}Results Check:${NC}"
if [ -d "$EXPERIMENT_DIR" ]; then
    echo -e "  ${BLUE}Experiment Directory:${NC} $EXPERIMENT_DIR"
    
    # Check for success file
    success_file=$(find "$EXPERIMENT_DIR" -name "*success*.txt" 2>/dev/null | head -1)
    error_file=$(find "$EXPERIMENT_DIR" -name "*error*.txt" 2>/dev/null | head -1)
    
    if [ -n "$success_file" ]; then
        echo -e "  ${GREEN}🎉 SUCCESS! Results found:${NC}"
        echo -e "     ${CYAN}File:${NC} $success_file"
        
        # Show key results
        if grep -q "l2_error" "$success_file"; then
            l2_error=$(grep "l2_error" "$success_file" | cut -d: -f2 | tr -d ' ')
            echo -e "     ${BLUE}L2 Error:${NC} $l2_error"
        fi
        
        if grep -q "minimizers_count" "$success_file"; then
            min_count=$(grep "minimizers_count" "$success_file" | cut -d: -f2 | tr -d ' ')
            echo -e "     ${BLUE}Minimizers Found:${NC} $min_count"
        fi
        
        if grep -q "convergence_rate" "$success_file"; then
            conv_rate=$(grep "convergence_rate" "$success_file" | cut -d: -f2 | tr -d ' ')
            conv_percent=$(echo "$conv_rate * 100" | bc -l 2>/dev/null | cut -d. -f1)
            echo -e "     ${BLUE}Convergence Rate:${NC} ${conv_percent}%"
        fi
        
        if grep -q "construction_time" "$success_file"; then
            const_time=$(grep "construction_time" "$success_file" | cut -d: -f2 | tr -d ' ')
            echo -e "     ${BLUE}Construction Time:${NC} ${const_time}s"
        fi
        
        # Check for CSV data
        csv_file=$(find "$EXPERIMENT_DIR" -name "*.csv" 2>/dev/null | head -1)
        if [ -n "$csv_file" ]; then
            csv_lines=$(wc -l < "$csv_file" 2>/dev/null)
            echo -e "     ${BLUE}CSV Data:${NC} $((csv_lines - 1)) records in $(basename "$csv_file")"
        fi
        
    elif [ -n "$error_file" ]; then
        echo -e "  ${RED}❌ FAILED - Error found:${NC}"
        echo -e "     ${CYAN}File:${NC} $error_file"
        echo -e "     ${RED}Error:${NC}"
        head -3 "$error_file" 2>/dev/null | sed 's/^/       /'
        
    else
        echo -e "  ${YELLOW}⏳ No results yet${NC}"
        
        # Check SLURM output
        slurm_out=$(find "$EXPERIMENT_DIR" -name "*.out" 2>/dev/null | head -1)
        if [ -n "$slurm_out" ] && [ -f "$slurm_out" ]; then
            echo -e "     ${CYAN}Latest SLURM output:${NC}"
            tail -3 "$slurm_out" 2>/dev/null | sed 's/^/       /'
        fi
    fi
    
else
    echo -e "  ${RED}❌ Experiment directory not found${NC}"
fi

echo ""

# Show next steps
echo -e "${CYAN}Next Steps:${NC}"
if [ -n "$queue_status" ]; then
    echo -e "  • Job is still in queue - wait for execution"
    echo -e "  • Run this script again in a few minutes"
    echo -e "  • Use ${BLUE}./watch_globtim_jobs.sh${NC} for continuous monitoring"
elif [ -n "$success_file" ]; then
    echo -e "  • ${GREEN}Job completed successfully!${NC}"
    echo -e "  • Review results in: $success_file"
    echo -e "  • Check CSV data for detailed analysis"
    echo -e "  • Ready to create more benchmark jobs"
elif [ -n "$error_file" ]; then
    echo -e "  • ${RED}Job failed${NC} - review error log: $error_file"
    echo -e "  • Debug and create a new job if needed"
else
    echo -e "  • Check SLURM output files for progress"
    echo -e "  • Wait a bit longer for results to appear"
fi

echo ""
echo -e "${BLUE}Monitoring completed at $(date)${NC}"
