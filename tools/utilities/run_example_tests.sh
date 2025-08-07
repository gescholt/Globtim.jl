#!/bin/bash

# Run HPC Example Tests
# Submits test job and monitors progress

echo "🧪 Globtim HPC Examples Test Runner"
echo "===================================="
echo ""

# Check if we're on the cluster
if [[ "$HOSTNAME" == *"falcon"* ]] || [[ "$HOSTNAME" == *"furiosa"* ]]; then
    echo "✅ Running on HPC cluster"
    CLUSTER_MODE=true
else
    echo "🔗 Running from local machine - will SSH to cluster"
    CLUSTER_MODE=false
fi

echo ""

# Function to run on cluster
run_on_cluster() {
    echo "📁 Changing to project directory..."
    cd /projects/globtim || { echo "❌ Failed to change to /projects/globtim"; exit 1; }
    
    echo "📋 Current directory: $(pwd)"
    echo ""
    
    # Check if test files exist
    if [[ ! -f "test_hpc_examples.jl" ]]; then
        echo "❌ test_hpc_examples.jl not found"
        echo "Make sure files are synced to cluster"
        exit 1
    fi
    
    if [[ ! -f "test_examples.slurm" ]]; then
        echo "❌ test_examples.slurm not found"
        echo "Make sure files are synced to cluster"
        exit 1
    fi
    
    echo "✅ Test files found"
    echo ""
    
    # Submit the job
    echo "🚀 Submitting test job..."
    JOB_ID=$(sbatch test_examples.slurm | grep -o '[0-9]*')
    
    if [[ -z "$JOB_ID" ]]; then
        echo "❌ Failed to submit job"
        exit 1
    fi
    
    echo "✅ Job submitted with ID: $JOB_ID"
    echo ""
    
    # Monitor the job
    echo "👀 Monitoring job progress..."
    echo "Press Ctrl+C to stop monitoring (job will continue running)"
    echo ""
    
    while true; do
        # Check job status
        STATUS=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null)
        
        if [[ -z "$STATUS" ]]; then
            echo "✅ Job $JOB_ID completed"
            break
        fi
        
        echo "📊 Job $JOB_ID status: $STATUS ($(date '+%H:%M:%S'))"
        
        # If job is running, show some output
        if [[ "$STATUS" == "RUNNING" ]]; then
            if [[ -f "test_examples_${JOB_ID}.out" ]]; then
                echo "📄 Latest output:"
                tail -5 "test_examples_${JOB_ID}.out" | sed 's/^/   /'
                echo ""
            fi
        fi
        
        sleep 10
    done
    
    echo ""
    echo "📋 Final Results:"
    echo "=================="
    
    # Show output file
    if [[ -f "test_examples_${JOB_ID}.out" ]]; then
        echo "📄 Output file: test_examples_${JOB_ID}.out"
        echo ""
        cat "test_examples_${JOB_ID}.out"
    else
        echo "❌ Output file not found"
    fi
    
    echo ""
    
    # Show error file if it exists and has content
    if [[ -f "test_examples_${JOB_ID}.err" ]] && [[ -s "test_examples_${JOB_ID}.err" ]]; then
        echo "⚠️  Error file: test_examples_${JOB_ID}.err"
        echo ""
        cat "test_examples_${JOB_ID}.err"
        echo ""
    fi
    
    echo "🎯 Test job $JOB_ID completed"
}

# Run based on mode
if [[ "$CLUSTER_MODE" == "true" ]]; then
    run_on_cluster
else
    # SSH to cluster and run
    echo "🔗 Connecting to HPC cluster..."
    ssh -t scholten@falcon "$(declare -f run_on_cluster); run_on_cluster"
fi

echo ""
echo "✅ Example testing completed"
