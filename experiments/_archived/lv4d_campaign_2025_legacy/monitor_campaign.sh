#!/bin/bash

# Real-time monitoring dashboard for LV4D experiment campaign

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}LV4D EXPERIMENT CAMPAIGN MONITOR${NC}"
echo -e "${BLUE}=============================================${NC}"
echo "Last Update: $(date)"
echo ""

# Check tmux sessions
echo -e "${YELLOW}Active Tmux Sessions:${NC}"
echo "---------------------"

# List all lv4d sessions
sessions=$(tmux ls 2>/dev/null | grep "lv4d_" || echo "")

if [ -z "$sessions" ]; then
    echo -e "${RED}No active experiments found${NC}"
else
    while IFS= read -r line; do
        session_name=$(echo "$line" | cut -d: -f1)
        echo -e "  ${GREEN}●${NC} $session_name"
    done <<< "$sessions"
fi

echo ""

# Check experiment directories
echo -e "${YELLOW}Experiment Progress:${NC}"
echo "--------------------"

# Array of configurations
domains=(0.05 0.1 0.15 0.2)
precisions=("float64" "adaptive")

for precision in "${precisions[@]}"; do
    echo ""
    echo -e "${BLUE}$precision experiments:${NC}"
    for domain in "${domains[@]}"; do
        # Format domain for directory name
        domain_str="${domain}"

        # Find matching directory
        exp_dir=$(ls -d hpc_results/lv4d_${precision}_${domain}_GN16_* 2>/dev/null | sort | tail -1)

        if [ -z "$exp_dir" ]; then
            echo -e "  Domain ±${domain}: ${YELLOW}Not started${NC}"
        else
            # Count completed degrees
            completed=$(ls "$exp_dir"/critical_points_deg_*.csv 2>/dev/null | wc -l)

            # Check if results summary exists
            if [ -f "$exp_dir/results_summary.json" ]; then
                # Experiment complete
                total_time=$(python3 -c "import json; data=json.load(open('$exp_dir/results_summary.json')); print(f'{data[\"total_time\"]:.1f}')")
                successful=$(python3 -c "import json; data=json.load(open('$exp_dir/results_summary.json')); print(data['successful_degrees'])")
                echo -e "  Domain ±${domain}: ${GREEN}✓ Complete${NC} (${successful}/9 degrees, ${total_time}s)"
            else
                # Still running
                echo -e "  Domain ±${domain}: ${YELLOW}Running${NC} (${completed}/9 degrees)"

                # Show current degree if log exists
                log_file="experiments/lv4d_campaign_2025/tracking/lv4d_${precision}_${domain//./}*.log"
                latest_log=$(ls $log_file 2>/dev/null | sort | tail -1)
                if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
                    current_deg=$(grep "Processing Degree" "$latest_log" 2>/dev/null | tail -1 | awk '{print $3}')
                    if [ -n "$current_deg" ]; then
                        echo -e "      Currently processing degree: ${current_deg}"
                    fi
                fi
            fi
        fi
    done
done

echo ""

# Summary statistics
echo -e "${YELLOW}Overall Statistics:${NC}"
echo "-------------------"

# Count total completed experiments
total_complete=0
total_running=0
total_not_started=0

for precision in "${precisions[@]}"; do
    for domain in "${domains[@]}"; do
        exp_dir=$(ls -d hpc_results/lv4d_${precision}_${domain}_GN16_* 2>/dev/null | sort | tail -1)
        if [ -z "$exp_dir" ]; then
            ((total_not_started++))
        elif [ -f "$exp_dir/results_summary.json" ]; then
            ((total_complete++))
        else
            ((total_running++))
        fi
    done
done

echo -e "  Complete:    ${GREEN}$total_complete/8${NC}"
echo -e "  Running:     ${YELLOW}$total_running/8${NC}"
echo -e "  Not Started: ${RED}$total_not_started/8${NC}"

# Calculate total computation time
total_time=0
for exp_dir in hpc_results/lv4d_*_GN16_*/results_summary.json; do
    if [ -f "$exp_dir" ]; then
        exp_time=$(python3 -c "import json; print(json.load(open('$exp_dir'))['total_time'])" 2>/dev/null || echo "0")
        total_time=$(echo "$total_time + $exp_time" | bc)
    fi
done

if (( $(echo "$total_time > 0" | bc -l) )); then
    echo ""
    echo -e "  Total Computation Time: ${BLUE}$(printf "%.1f" $total_time)s${NC}"
    echo -e "  Average Time per Experiment: ${BLUE}$(echo "scale=1; $total_time / $total_complete" | bc)s${NC}"
fi

echo ""
echo -e "${BLUE}=============================================${NC}"
echo ""
echo "Commands:"
echo "  Attach to session:  tmux attach -t <session_name>"
echo "  View logs:          tail -f experiments/lv4d_campaign_2025/tracking/*.log"
echo "  Refresh monitor:    ./experiments/lv4d_campaign_2025/monitor_campaign.sh"
echo "  Collect results:    julia --project=. collect_cluster_experiments.jl"
echo ""