#!/bin/bash
#SBATCH --job-name=basic_test_quick
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=basic_test_cd943d4b_%j.out
#SBATCH --error=basic_test_cd943d4b_%j.err

echo "=== Basic Julia Test - QUICK MODE ==="
echo "Test ID: cd943d4b"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create output directory
mkdir -p basic_test_results_cd943d4b
echo "✅ Output directory created: basic_test_results_cd943d4b"

# Create input configuration
cat > basic_test_results_cd943d4b/input_config.json << 'EOF'
{
  "test_id": "cd943d4b",
  "timestamp": "$(date -Iseconds)",
  "test_type": "basic_validation",
  "slurm_job_id": "$SLURM_JOB_ID",
  "parameters": {
    "computation_size": 100,
    "output_format": "json"
  },
  "metadata": {
    "created_by": "submit_basic_test.py",
    "purpose": "HPC cluster validation",
    "mode": "quick",
    "cpus": 2,
    "memory": "4G",
    "time_limit": "00:05:00"
  }
}
EOF

echo "✅ Input configuration created"

# Run the basic Julia test (embedded in the script)
echo ""
echo "=== Running Basic Julia Test ==="
/sw/bin/julia -e '
using Dates

println("🚀 Basic Julia Test Script Starting")
println("=" ^ 50)
println("Julia Version: $(VERSION)")
println("Start Time: $(now())")
println("Hostname: $(gethostname())")
println("Working Directory: $(pwd())")
println("Available Threads: $(Threads.nthreads())")
println()

output_dir = "basic_test_results_cd943d4b"
println("📋 Configuration:")
println("  Output directory: $output_dir")
println()

# Test 1: Basic computation
println("🧮 Test 1: Basic Mathematical Computation")
try
    x = rand(100)
    y = sin.(x)
    z = sum(y)

    println("  ✅ Generated 100 random numbers")
    println("  ✅ Computed sine values")
    println("  ✅ Sum of sine values: $z")

    # Save results as simple text file
    open(joinpath(output_dir, "basic_math_results.txt"), "w") do f
        println(f, "Basic Math Test Results")
        println(f, "======================")
        println(f, "Timestamp: $(now())")
        println(f, "Input size: $(length(x))")
        println(f, "Sum result: $z")
        println(f, "Mean result: $(z / length(x))")
        println(f, "Julia version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
    end

    println("  ✅ Results saved to basic_math_results.txt")

catch e
    println("  ❌ Basic computation failed: $e")
    exit(1)
end

println()

# Test 2: System info
println("🖥️  Test 2: System Information Collection")
try
    # Save system info as simple text file
    open(joinpath(output_dir, "system_info.txt"), "w") do f
        println(f, "System Information")
        println(f, "==================")
        println(f, "Julia version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
        println(f, "Working directory: $(pwd())")
        println(f, "Threads: $(Threads.nthreads())")
        println(f, "Timestamp: $(now())")
        println(f, "")
        println(f, "Environment Variables:")
        println(f, "JULIA_NUM_THREADS: $(get(ENV, "JULIA_NUM_THREADS", "not_set"))")
        println(f, "SLURM_JOB_ID: $(get(ENV, "SLURM_JOB_ID", "not_set"))")
        println(f, "SLURM_CPUS_PER_TASK: $(get(ENV, "SLURM_CPUS_PER_TASK", "not_set"))")
    end

    println("  ✅ System information collected and saved")

catch e
    println("  ❌ System info collection failed: $e")
    exit(1)
end

println()
println("🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
println("End Time: $(now())")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > basic_test_results_cd943d4b/job_summary.txt << EOF
# Basic Julia Test Job Summary
Test ID: cd943d4b
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Mode: quick
Start Time: $(date)
Duration: $SECONDS seconds
Julia Exit Code: $JULIA_EXIT_CODE
CPUs: 2
Memory: 4G
Time Limit: 00:05:00

# Generated Files:
$(ls -la basic_test_results_cd943d4b/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Basic test completed successfully"
    echo "📁 Results available in: basic_test_results_cd943d4b/"
else
    echo "❌ Basic test failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
