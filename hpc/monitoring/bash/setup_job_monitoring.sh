#!/bin/bash

# Setup Job Monitoring System
# Creates comprehensive monitoring tools for tracking HPC job progress

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Setting Up Job Monitoring System ===${NC}"
echo ""

# ============================================================================
# STEP 1: Create Real-Time Job Monitor
# ============================================================================

echo -e "${YELLOW}Step 1: Creating real-time job monitor...${NC}"

cat > monitor_globtim_jobs.sh << 'EOF'
#!/bin/bash

# Real-Time Globtim Job Monitor
# Tracks all Globtim-related jobs with detailed status and progress

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to get job status with colors
get_job_status() {
    local status=$1
    case $status in
        "RUNNING"|"R")
            echo -e "${GREEN}RUNNING${NC}"
            ;;
        "PENDING"|"PD")
            echo -e "${YELLOW}PENDING${NC}"
            ;;
        "COMPLETED"|"CD")
            echo -e "${GREEN}COMPLETED${NC}"
            ;;
        "FAILED"|"F")
            echo -e "${RED}FAILED${NC}"
            ;;
        "CANCELLED"|"CA")
            echo -e "${RED}CANCELLED${NC}"
            ;;
        *)
            echo -e "${CYAN}$status${NC}"
            ;;
    esac
}

# Function to format time duration
format_duration() {
    local seconds=$1
    if [ -z "$seconds" ] || [ "$seconds" = "Unknown" ]; then
        echo "Unknown"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%02d:%02d:%02d" $hours $minutes $secs
    else
        printf "%02d:%02d" $minutes $secs
    fi
}

echo -e "${BLUE}=== Globtim Job Monitor ===${NC}"
echo "Timestamp: $(date)"
echo ""

# Check current queue status
echo -e "${CYAN}=== Current Queue Status ===${NC}"
squeue -u $USER --format="%.10i %.12P %.20j %.8u %.2t %.10M %.6D %R" | head -20

echo ""
echo -e "${CYAN}=== Recent Globtim Jobs (Last 24 Hours) ===${NC}"

# Get recent jobs with detailed info
sacct -u $USER --starttime=$(date -d '1 day ago' +%Y-%m-%d) \
      --format=JobID,JobName,State,ExitCode,Start,End,Elapsed,MaxRSS,ReqMem,ReqCPUS \
      --parsable2 | grep -E "(globtim|working_|params_)" | while IFS='|' read -r jobid jobname state exitcode start end elapsed maxrss reqmem reqcpus; do
    
    if [[ "$jobid" == *".batch" ]] || [[ "$jobid" == *".extern" ]]; then
        continue  # Skip sub-jobs
    fi
    
    status_colored=$(get_job_status "$state")
    
    echo -e "${BLUE}Job ID:${NC} $jobid"
    echo -e "${BLUE}Name:${NC} $jobname"
    echo -e "${BLUE}Status:${NC} $status_colored"
    echo -e "${BLUE}Exit Code:${NC} $exitcode"
    echo -e "${BLUE}Start:${NC} $start"
    echo -e "${BLUE}End:${NC} $end"
    echo -e "${BLUE}Duration:${NC} $elapsed"
    echo -e "${BLUE}Memory:${NC} $reqmem (Max: $maxrss)"
    echo -e "${BLUE}CPUs:${NC} $reqcpus"
    echo ""
done

echo -e "${CYAN}=== Job Results Summary ===${NC}"

# Check for result files
result_count=0
for exp_dir in results/experiments/*/; do
    if [ -d "$exp_dir" ]; then
        exp_name=$(basename "$exp_dir")
        
        # Check for success files
        success_files=$(find "$exp_dir" -name "*success*.txt" -o -name "*results*.txt" 2>/dev/null | wc -l)
        error_files=$(find "$exp_dir" -name "*error*.txt" 2>/dev/null | wc -l)
        
        if [ $success_files -gt 0 ] || [ $error_files -gt 0 ]; then
            echo -e "${BLUE}Experiment:${NC} $exp_name"
            if [ $success_files -gt 0 ]; then
                echo -e "  ${GREEN}✓ $success_files successful jobs${NC}"
            fi
            if [ $error_files -gt 0 ]; then
                echo -e "  ${RED}✗ $error_files failed jobs${NC}"
            fi
            result_count=$((result_count + 1))
        fi
    fi
done

if [ $result_count -eq 0 ]; then
    echo "No completed jobs with results found yet."
fi

echo ""
echo -e "${CYAN}=== System Resources ===${NC}"
echo -e "${BLUE}Available partitions:${NC}"
sinfo --format="%.10P %.5a %.10l %.6D %.6t %.8C %.8G %.10m %.20N" | head -10

echo ""
echo -e "${BLUE}Disk usage:${NC}"
df -h . | tail -1 | awk '{print "  Available space: " $4 " (" $5 " used)"}'

echo ""
echo -e "${YELLOW}Monitor refreshed. Run again to update status.${NC}"
EOF

chmod +x monitor_globtim_jobs.sh

echo "✓ Real-time job monitor created: monitor_globtim_jobs.sh"

# ============================================================================
# STEP 2: Create Continuous Monitoring Script
# ============================================================================

echo -e "${YELLOW}Step 2: Creating continuous monitoring script...${NC}"

cat > watch_globtim_jobs.sh << 'EOF'
#!/bin/bash

# Continuous Globtim Job Watcher
# Automatically refreshes job status every 30 seconds

echo "=== Continuous Globtim Job Monitor ==="
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    ./monitor_globtim_jobs.sh
    echo ""
    echo "Next update in 30 seconds... (Ctrl+C to stop)"
    sleep 30
done
EOF

chmod +x watch_globtim_jobs.sh

echo "✓ Continuous monitor created: watch_globtim_jobs.sh"

# ============================================================================
# STEP 3: Create Job Result Checker
# ============================================================================

echo -e "${YELLOW}Step 3: Creating job result checker...${NC}"

cat > check_job_results.sh << 'EOF'
#!/bin/bash

# Check Job Results
# Detailed analysis of completed job results

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Job Results Analysis ===${NC}"
echo ""

# Function to analyze a single job result
analyze_job_result() {
    local job_dir=$1
    local job_id=$(basename "$job_dir")
    
    echo -e "${CYAN}Job ID: $job_id${NC}"
    
    # Check for success file
    if [ -f "$job_dir/globtim_success.txt" ]; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        echo "Results:"
        while IFS=': ' read -r key value; do
            case $key in
                "l2_error")
                    echo -e "  ${BLUE}L2 Error:${NC} $value"
                    ;;
                "minimizers_count")
                    echo -e "  ${BLUE}Minimizers Found:${NC} $value"
                    ;;
                "convergence_rate")
                    echo -e "  ${BLUE}Convergence Rate:${NC} $(echo "$value * 100" | bc -l | cut -d. -f1)%"
                    ;;
                "construction_time")
                    echo -e "  ${BLUE}Construction Time:${NC} ${value}s"
                    ;;
                "min_distance_to_global")
                    echo -e "  ${BLUE}Min Distance to Global:${NC} $value"
                    ;;
            esac
        done < "$job_dir/globtim_success.txt"
        
        # Check for CSV results
        if [ -f "$job_dir/minimizers_analysis.csv" ]; then
            local csv_lines=$(wc -l < "$job_dir/minimizers_analysis.csv")
            echo -e "  ${BLUE}CSV Data:${NC} $((csv_lines - 1)) minimizer records"
        fi
        
    elif [ -f "$job_dir/globtim_error.txt" ]; then
        echo -e "${RED}❌ FAILED${NC}"
        echo "Error:"
        cat "$job_dir/globtim_error.txt" | head -3
        
    elif [ -f "$job_dir/results_summary.txt" ]; then
        echo -e "${GREEN}✅ COMPLETED${NC}"
        echo "Summary:"
        cat "$job_dir/results_summary.txt" | head -5
        
    else
        echo -e "${YELLOW}⏳ IN PROGRESS or NO RESULTS${NC}"
        
        # Check SLURM output files
        local slurm_out=$(find "$job_dir/slurm_output" -name "*.out" 2>/dev/null | head -1)
        if [ -n "$slurm_out" ] && [ -f "$slurm_out" ]; then
            echo "Latest output:"
            tail -3 "$slurm_out" | sed 's/^/  /'
        fi
    fi
    
    echo ""
}

# Analyze all job results
total_jobs=0
successful_jobs=0
failed_jobs=0
pending_jobs=0

for exp_dir in results/experiments/*/; do
    if [ -d "$exp_dir" ]; then
        for job_dir in "$exp_dir"/jobs/*/; do
            if [ -d "$job_dir" ]; then
                analyze_job_result "$job_dir"
                total_jobs=$((total_jobs + 1))
                
                if [ -f "$job_dir/globtim_success.txt" ] || [ -f "$job_dir/results_summary.txt" ]; then
                    successful_jobs=$((successful_jobs + 1))
                elif [ -f "$job_dir/globtim_error.txt" ]; then
                    failed_jobs=$((failed_jobs + 1))
                else
                    pending_jobs=$((pending_jobs + 1))
                fi
            fi
        done
    fi
done

echo -e "${CYAN}=== Summary ===${NC}"
echo -e "${BLUE}Total Jobs:${NC} $total_jobs"
echo -e "${GREEN}Successful:${NC} $successful_jobs"
echo -e "${RED}Failed:${NC} $failed_jobs"
echo -e "${YELLOW}Pending/In Progress:${NC} $pending_jobs"

if [ $total_jobs -gt 0 ]; then
    success_rate=$(echo "scale=1; $successful_jobs * 100 / $total_jobs" | bc -l)
    echo -e "${BLUE}Success Rate:${NC} ${success_rate}%"
fi
EOF

chmod +x check_job_results.sh

echo "✓ Job result checker created: check_job_results.sh"

# ============================================================================
# STEP 4: Create Job Alert System
# ============================================================================

echo -e "${YELLOW}Step 4: Creating job alert system...${NC}"

cat > setup_job_alerts.sh << 'EOF'
#!/bin/bash

# Setup Job Alerts
# Creates alerts for job completion/failure

echo "=== Job Alert System ==="

# Create alert checker
cat > check_job_alerts.sh << 'ALERT_EOF'
#!/bin/bash

# Check for new job completions and send alerts

ALERT_FILE="$HOME/.globtim_job_alerts"
touch "$ALERT_FILE"

# Get current completed jobs
current_jobs=$(sacct -u $USER --starttime=today --state=COMPLETED,FAILED --format=JobID,JobName,State --parsable2 | grep -E "(globtim|working_|params_)" | grep -v ".batch\|.extern")

echo "$current_jobs" | while IFS='|' read -r jobid jobname state; do
    if [ -n "$jobid" ] && ! grep -q "$jobid" "$ALERT_FILE"; then
        echo "$jobid" >> "$ALERT_FILE"
        
        echo "=== JOB ALERT ==="
        echo "Job $jobid ($jobname) completed with status: $state"
        echo "Time: $(date)"
        
        # Try to find and display results
        for exp_dir in results/experiments/*/jobs/*/; do
            if [[ "$exp_dir" == *"$jobid"* ]] || find "$exp_dir" -name "*$jobid*" >/dev/null 2>&1; then
                echo "Results directory: $exp_dir"
                if [ -f "$exp_dir/globtim_success.txt" ]; then
                    echo "✅ SUCCESS - Results available"
                elif [ -f "$exp_dir/globtim_error.txt" ]; then
                    echo "❌ FAILED - Check error log"
                fi
                break
            fi
        done
        echo "==================="
        echo ""
    fi
done
ALERT_EOF

chmod +x check_job_alerts.sh

echo "✓ Job alert checker created"
echo "Run './check_job_alerts.sh' to check for new completions"
EOF

chmod +x setup_job_alerts.sh

echo "✓ Job alert system created: setup_job_alerts.sh"

# ============================================================================
# STEP 5: Create Master Monitoring Dashboard
# ============================================================================

echo -e "${YELLOW}Step 5: Creating master monitoring dashboard...${NC}"

cat > globtim_dashboard.sh << 'EOF'
#!/bin/bash

# Globtim Monitoring Dashboard
# Comprehensive view of all Globtim jobs and results

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║                    GLOBTIM DASHBOARD                         ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Quick status
echo -e "${CYAN}📊 Quick Status:${NC}"
running_jobs=$(squeue -u $USER --name=*globtim*,*working_*,*params_* --noheader | wc -l)
recent_completed=$(sacct -u $USER --starttime=today --state=COMPLETED --format=JobID --parsable2 | grep -E "(globtim|working_|params_)" | grep -v ".batch\|.extern" | wc -l)
recent_failed=$(sacct -u $USER --starttime=today --state=FAILED --format=JobID --parsable2 | grep -E "(globtim|working_|params_)" | grep -v ".batch\|.extern" | wc -l)

echo -e "  ${YELLOW}⏳ Running/Pending:${NC} $running_jobs"
echo -e "  ${GREEN}✅ Completed Today:${NC} $recent_completed"
echo -e "  ${RED}❌ Failed Today:${NC} $recent_failed"
echo ""

# Current active jobs
if [ $running_jobs -gt 0 ]; then
    echo -e "${CYAN}🔄 Active Jobs:${NC}"
    squeue -u $USER --name=*globtim*,*working_*,*params_* --format="  %.10i %.15j %.8T %.10M %.6D %R"
    echo ""
fi

# Recent results
echo -e "${CYAN}📈 Recent Results:${NC}"
result_found=false
for exp_dir in results/experiments/*/; do
    if [ -d "$exp_dir" ]; then
        exp_name=$(basename "$exp_dir")
        
        # Find the most recent result
        latest_success=$(find "$exp_dir" -name "*success*.txt" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
        latest_error=$(find "$exp_dir" -name "*error*.txt" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
        
        if [ -n "$latest_success" ]; then
            echo -e "  ${GREEN}✅ $exp_name${NC}"
            # Extract key metrics
            if grep -q "convergence_rate" "$latest_success"; then
                conv_rate=$(grep "convergence_rate" "$latest_success" | cut -d: -f2 | tr -d ' ')
                echo -e "     Convergence: $(echo "$conv_rate * 100" | bc -l | cut -d. -f1)%"
            fi
            result_found=true
        elif [ -n "$latest_error" ]; then
            echo -e "  ${RED}❌ $exp_name${NC}"
            result_found=true
        fi
    fi
done

if [ "$result_found" = false ]; then
    echo "  No results available yet"
fi

echo ""
echo -e "${CYAN}🛠️  Available Commands:${NC}"
echo -e "  ${BLUE}./monitor_globtim_jobs.sh${NC}     - Detailed job status"
echo -e "  ${BLUE}./watch_globtim_jobs.sh${NC}       - Continuous monitoring"
echo -e "  ${BLUE}./check_job_results.sh${NC}        - Analyze results"
echo -e "  ${BLUE}./check_job_alerts.sh${NC}         - Check for new completions"
echo ""
echo -e "${YELLOW}Dashboard updated: $(date)${NC}"
EOF

chmod +x globtim_dashboard.sh

echo "✓ Master dashboard created: globtim_dashboard.sh"

echo ""
echo -e "${GREEN}✅ Job Monitoring System Setup Complete!${NC}"
echo ""
echo -e "${CYAN}Available Monitoring Tools:${NC}"
echo -e "  ${BLUE}1. globtim_dashboard.sh${NC}        - Master dashboard overview"
echo -e "  ${BLUE}2. monitor_globtim_jobs.sh${NC}     - Detailed job status"
echo -e "  ${BLUE}3. watch_globtim_jobs.sh${NC}       - Continuous monitoring (auto-refresh)"
echo -e "  ${BLUE}4. check_job_results.sh${NC}        - Analyze completed job results"
echo -e "  ${BLUE}5. setup_job_alerts.sh${NC}         - Setup completion alerts"
echo ""
echo -e "${YELLOW}Quick Start:${NC}"
echo -e "  ${GREEN}./globtim_dashboard.sh${NC}         # Quick overview"
echo -e "  ${GREEN}./watch_globtim_jobs.sh${NC}        # Start continuous monitoring"
echo ""
echo -e "${BLUE}🎯 Ready to monitor job 59770436 and future jobs!${NC}"
