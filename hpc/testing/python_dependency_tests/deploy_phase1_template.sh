#!/bin/bash
# Deployment script template for Phase 1 Python dependency test
# This runs on the fileserver (mack) to deploy and execute the test

set -e

echo "=== Deploying Phase 1 Python Dependency Test ==="
echo "Current location: $(pwd)"
echo "Current user: $(whoami)"
echo "Current time: $(date)"

# Check if we're on the fileserver
if [[ $(hostname) != *"mack"* ]]; then
    echo "⚠️  Warning: Not on fileserver (mack), proceeding anyway..."
fi

# Create work directory on fileserver (using home directory like existing Julia scripts)
WORK_DIR="$HOME/globtim_hpc/python_dependency_tests/phase1_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy files from the deployment directory
DEPLOY_DIR_NAME=$(basename $OLDPWD)
cp "$HOME/$DEPLOY_DIR_NAME/phase1_direct_install_test.slurm" .
cp "$HOME/$DEPLOY_DIR_NAME/requirements.txt" .

echo "Files prepared in: $WORK_DIR"
ls -la

# Submit job to cluster
echo ""
echo "=== Submitting job to cluster ==="
JOB_ID=$(sbatch phase1_direct_install_test.slurm | grep -o '[0-9]*')
echo "Job submitted with ID: $JOB_ID"

# Monitor job
echo ""
echo "=== Monitoring job ==="
echo "Job status monitoring (will check every 30 seconds)..."

while true; do
    STATUS=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null || echo "COMPLETED")
    echo "$(date): Job $JOB_ID status: $STATUS"
    
    if [[ "$STATUS" == "COMPLETED" ]] || [[ "$STATUS" == "" ]]; then
        echo "Job completed!"
        break
    elif [[ "$STATUS" == "FAILED" ]] || [[ "$STATUS" == "CANCELLED" ]]; then
        echo "Job failed or was cancelled!"
        break
    fi
    
    sleep 30
done

# Show results
echo ""
echo "=== Job Results ==="
echo "Output files in: $WORK_DIR"
ls -la python_deps_phase1_*.out python_deps_phase1_*.err 2>/dev/null || echo "No output files found yet"

if [[ -f "python_deps_phase1_${JOB_ID}.out" ]]; then
    echo ""
    echo "=== Job Output ==="
    cat "python_deps_phase1_${JOB_ID}.out"
fi

if [[ -f "python_deps_phase1_${JOB_ID}.err" ]]; then
    echo ""
    echo "=== Job Errors ==="
    cat "python_deps_phase1_${JOB_ID}.err"
fi

echo ""
echo "=== Phase 1 Test Complete ==="
echo "Results location: $WORK_DIR"
echo "Next steps:"
echo "1. Review the output above"
echo "2. If Phase 1 succeeded, document the working approach"
echo "3. If Phase 1 failed, proceed to Phase 2 offline bundling"
