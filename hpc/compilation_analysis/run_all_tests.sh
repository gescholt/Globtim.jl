#!/bin/bash
# run_all_tests.sh - Submit all compilation diagnostic tests

echo "=== GlobTim HPC Compilation Diagnostics ==="
echo "Submitting diagnostic test suite..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track job IDs
JOB_IDS=()

# Test 1: Bundle Verification (if exists)
if [ -f "../jobs/submission/test_bundle_verification.slurm" ]; then
    echo -e "${YELLOW}Submitting Test 1: Bundle Verification${NC}"
    scp ../jobs/submission/test_bundle_verification.slurm scholten@falcon:~/
    JOB_ID=$(ssh scholten@falcon 'sbatch test_bundle_verification.slurm' | awk '{print $4}')
    echo -e "${GREEN}Submitted as job $JOB_ID${NC}"
    JOB_IDS+=("bundle:$JOB_ID")
    echo ""
else
    echo -e "${RED}Bundle verification script not found${NC}"
fi

# Test 2: Toy Compilation
echo -e "${YELLOW}Submitting Test 2: Toy Package Compilation${NC}"
scp toy_compilation_test.slurm scholten@falcon:~/
JOB_ID=$(ssh scholten@falcon 'sbatch toy_compilation_test.slurm' | awk '{print $4}')
echo -e "${GREEN}Submitted as job $JOB_ID${NC}"
JOB_IDS+=("toy:$JOB_ID")
echo ""

# Test 3: Bottleneck Analysis
echo -e "${YELLOW}Submitting Test 3: Bottleneck Analysis${NC}"
scp bottleneck_analysis.slurm scholten@falcon:~/
JOB_ID=$(ssh scholten@falcon 'sbatch bottleneck_analysis.slurm' | awk '{print $4}')
echo -e "${GREEN}Submitted as job $JOB_ID${NC}"
JOB_IDS+=("bottleneck:$JOB_ID")
echo ""

# Show summary
echo "=== Submitted Jobs ==="
for job in "${JOB_IDS[@]}"; do
    echo "  $job"
done
echo ""

# Monitor function
monitor_jobs() {
    echo "Monitoring jobs (press Ctrl+C to stop)..."
    while true; do
        clear
        echo "=== Job Status at $(date) ==="
        ssh scholten@falcon 'squeue -u scholten --format="%.10i %.20j %.8T %.10M %.6D %R"'
        echo ""
        echo "Jobs submitted:"
        for job in "${JOB_IDS[@]}"; do
            echo "  $job"
        done
        echo ""
        echo "Refreshing in 10 seconds..."
        sleep 10
    done
}

# Ask if user wants to monitor
echo -e "${YELLOW}Do you want to monitor the jobs? (y/n)${NC}"
read -r response
if [[ "$response" == "y" ]]; then
    monitor_jobs
else
    echo "To monitor manually, run:"
    echo "  ssh scholten@falcon 'squeue -u scholten'"
    echo ""
    echo "To collect results later:"
    echo "  ./collect_test_results.sh"
fi