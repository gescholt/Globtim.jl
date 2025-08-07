#!/usr/bin/env python3

"""
Basic Julia Test Submission Script
==================================

Simple, reliable script to submit basic Julia tests to the HPC cluster.
This isolates the input/run/output pipeline for debugging and validation.

Usage:
    python submit_basic_test.py [--mode MODE] [--no-monitor]
"""

import argparse
import subprocess
import json
import uuid
from pathlib import Path
from datetime import datetime
import tempfile
import os

class BasicTestSubmitter:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
        
    def create_input_config(self, test_id):
        """Create a simple input configuration"""
        config = {
            "test_id": test_id,
            "timestamp": datetime.now().isoformat(),
            "test_type": "basic_validation",
            "parameters": {
                "computation_size": 100,
                "output_format": "json"
            },
            "metadata": {
                "created_by": "submit_basic_test.py",
                "purpose": "HPC cluster validation"
            }
        }
        return config
    
    def create_slurm_script(self, test_id, mode="quick"):
        """Create SLURM job script"""
        
        # Configuration based on mode
        if mode == "quick":
            time_limit = "00:05:00"
            memory = "4G"
            cpus = 2
        elif mode == "standard":
            time_limit = "00:15:00"
            memory = "8G"
            cpus = 4
        else:
            time_limit = "00:30:00"
            memory = "16G"
            cpus = 8
        
        output_dir = f"basic_test_results_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=basic_test_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cpus}
#SBATCH --mem={memory}
#SBATCH --time={time_limit}
#SBATCH --output=basic_test_{test_id}_%j.out
#SBATCH --error=basic_test_{test_id}_%j.err

echo "=== Basic Julia Test - {mode.upper()} MODE ==="
echo "Test ID: {test_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup with quota workaround
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Available space: $(df -h . | tail -1 | awk '{{print $4}}')"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create input configuration
cat > {output_dir}/input_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "basic_validation",
  "slurm_job_id": "$SLURM_JOB_ID",
  "parameters": {{
    "computation_size": 100,
    "output_format": "json"
  }},
  "metadata": {{
    "created_by": "submit_basic_test.py",
    "purpose": "HPC cluster validation",
    "mode": "{mode}",
    "cpus": {cpus},
    "memory": "{memory}",
    "time_limit": "{time_limit}"
  }}
}}
EOF

echo "✅ Input configuration created"

# Run the basic Julia test (embedded in the script)
echo ""
echo "=== Running Basic Julia Test ==="

# Create a simple Julia script to avoid shell escaping issues
cat > test_script.jl << 'JULIA_EOF'
using Dates

println("🚀 Basic Julia Test Script Starting")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println()

output_dir = "{output_dir}"
println("📋 Configuration:")
println("  Output directory: ", output_dir)
println()

# Test 1: Basic computation
println("🧮 Test 1: Basic Mathematical Computation")
try
    x = rand(100)
    y = sin.(x)
    z = sum(y)

    println("  ✅ Generated 100 random numbers")
    println("  ✅ Computed sine values")
    println("  ✅ Sum of sine values: ", z)

    # Save results as simple text file
    open(joinpath(output_dir, "basic_math_results.txt"), "w") do f
        println(f, "Basic Math Test Results")
        println(f, "======================")
        println(f, "Timestamp: ", now())
        println(f, "Input size: ", length(x))
        println(f, "Sum result: ", z)
        println(f, "Mean result: ", z / length(x))
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
    end

    println("  ✅ Results saved to basic_math_results.txt")

catch e
    println("  ❌ Basic computation failed: ", e)
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
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
        println(f, "Working directory: ", pwd())
        println(f, "Threads: ", Threads.nthreads())
        println(f, "Timestamp: ", now())
        println(f, "")
        println(f, "Environment Variables:")
        println(f, "JULIA_NUM_THREADS: ", get(ENV, "JULIA_NUM_THREADS", "not_set"))
        println(f, "SLURM_JOB_ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
        println(f, "SLURM_CPUS_PER_TASK: ", get(ENV, "SLURM_CPUS_PER_TASK", "not_set"))
    end

    println("  ✅ System information collected and saved")

catch e
    println("  ❌ System info collection failed: ", e)
    exit(1)
end

println()
println("🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
println("End Time: ", now())
JULIA_EOF

# Run the Julia script
/sw/bin/julia test_script.jl

JULIA_EXIT_CODE=$?

# Clean up temporary script
rm -f test_script.jl

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Basic Julia Test Job Summary
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Mode: {mode}
Start Time: $(date)
Duration: $SECONDS seconds
Julia Exit Code: $JULIA_EXIT_CODE
CPUs: {cpus}
Memory: {memory}
Time Limit: {time_limit}

# Generated Files:
$(ls -la {output_dir}/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Basic test completed successfully"
    echo "📁 Results available in: {output_dir}/"
else
    echo "❌ Basic test failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, mode="quick", monitor=False, auto_collect=False):
        """Submit the basic test job using SLURM with /tmp script creation"""
        test_id = str(uuid.uuid4())[:8]

        if mode not in self.test_modes:
            print(f"❌ Invalid mode: {mode}")
            print(f"Available modes: {list(self.test_modes.keys())}")
            return None, None

        config = self.test_modes[mode]

        print(f"🚀 Submitting Basic Julia Test via SLURM")
        print(f"Mode: {mode}")
        print(f"Test ID: {test_id}")
        print()

        # Create SLURM script
        slurm_script = self.create_slurm_script(test_id, mode)

        try:
            # Use /tmp for script creation to avoid quota issues
            remote_script = f"/tmp/basic_test_{test_id}.slurm"

            print("📤 Submitting SLURM job (using /tmp for script)...")
            submit_cmd = f"""ssh {self.cluster_host} '
cd {self.remote_dir}
cat > {remote_script} << "EOF"
{slurm_script}
EOF
sbatch {remote_script}
rm {remote_script}
'"""

            result = subprocess.run(submit_cmd, shell=True, capture_output=True, text=True, timeout=60)

    def run_direct_test(self, test_id, mode, auto_collect=False):
        """Run basic test directly via SSH without creating any files"""

        # Create the Julia test command with proper output collection
        # Use /tmp for output to avoid quota issues
        output_dir = f"/tmp/basic_test_results_{test_id}"

        julia_test = f"""
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"
cd {self.remote_dir}

echo "🧮 Direct Basic Julia Test with Output Collection - {test_id}"
echo "Mode: {mode}"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Depot: $JULIA_DEPOT_PATH"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create input configuration
cat > {output_dir}/input_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "basic_validation_direct",
  "execution_mode": "direct_ssh",
  "parameters": {{
    "computation_size": 100000,
    "output_format": "json_and_txt"
  }},
  "metadata": {{
    "created_by": "submit_basic_test.py",
    "purpose": "HPC cluster validation with quota workaround",
    "mode": "{mode}",
    "depot_path": "{self.depot_path}"
  }}
}}
EOF

echo "✅ Input configuration created"

/sw/bin/julia -e '
using Dates

println("🚀 Basic Julia Test Script Starting")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println()

output_dir = "{output_dir}"
println("📋 Configuration:")
println("  Output directory: ", output_dir)
println()

# Test 1: Basic computation with file output
println("🧮 Test 1: Basic Mathematical Computation")
try
    x = rand(100)
    y = sin.(x)
    z = sum(y)

    println("  ✅ Generated 100 random numbers")
    println("  ✅ Computed sine values")
    println("  ✅ Sum of sine values: ", z)

    # Save results as simple text file
    open(joinpath(output_dir, "basic_math_results.txt"), "w") do f
        println(f, "Basic Math Test Results")
        println(f, "======================")
        println(f, "Timestamp: ", now())
        println(f, "Input size: ", length(x))
        println(f, "Sum result: ", z)
        println(f, "Mean result: ", z / length(x))
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
    end

    println("  ✅ Results saved to basic_math_results.txt")

catch e
    println("  ❌ Basic computation failed: ", e)
    exit(1)
end

println()

# Test 2: Package loading with file output
println("📦 Test 2: Package Loading and System Information")
try
    # Test package loading
    using StaticArrays, LinearAlgebra, TOML

    # Test StaticArrays functionality
    v = SVector(1.0, 2.0, 3.0)
    v_norm = norm(v)

    # Test TOML functionality
    test_data = Dict("test" => "success", "value" => 42)

    # Save system info as simple text file
    open(joinpath(output_dir, "system_info.txt"), "w") do f
        println(f, "System Information")
        println(f, "==================")
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
        println(f, "Working directory: ", pwd())
        println(f, "Threads: ", Threads.nthreads())
        println(f, "Timestamp: ", now())
        println(f, "Depot path: ", DEPOT_PATH[1])
        println(f, "")
        println(f, "Package Tests:")
        println(f, "StaticArrays: SUCCESS - vector norm = ", v_norm)
        println(f, "LinearAlgebra: SUCCESS")
        println(f, "TOML: SUCCESS")
        println(f, "")
        println(f, "Environment Variables:")
        println(f, "JULIA_NUM_THREADS: ", get(ENV, "JULIA_NUM_THREADS", "not_set"))
        println(f, "JULIA_DEPOT_PATH: ", get(ENV, "JULIA_DEPOT_PATH", "not_set"))
    end

    println("  ✅ StaticArrays loaded and tested: ", v, " (norm: ", v_norm, ")")
    println("  ✅ LinearAlgebra loaded successfully")
    println("  ✅ TOML loaded successfully")
    println("  ✅ System information collected and saved")

catch e
    println("  ❌ Package loading or system info failed: ", e)
    exit(1)
end

println()

# Test 3: Performance test with file output
println("⚡ Test 3: Performance Benchmark")
try
    start_time = time()
    result = sum(i^2 for i in 1:100000)
    end_time = time()
    computation_time = end_time - start_time

    println("  Sum of squares 1-100K: ", result)
    println("  Computation time: ", computation_time, " seconds")

    # Save performance results
    open(joinpath(output_dir, "performance_results.txt"), "w") do f
        println(f, "Performance Test Results")
        println(f, "========================")
        println(f, "Timestamp: ", now())
        println(f, "Test: Sum of squares 1-100000")
        println(f, "Result: ", result)
        println(f, "Computation time: ", computation_time, " seconds")
        println(f, "Operations per second: ", 100000 / computation_time)
        println(f, "Julia version: ", VERSION)
        println(f, "Threads: ", Threads.nthreads())
    end

    println("  ✅ Performance results saved")

catch e
    println("  ❌ Performance test failed: ", e)
    exit(1)
end

println()
println("🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
println("End Time: ", now())
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Test Summary ==="
echo "End time: $(date)"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Basic Julia Test Job Summary (Direct Execution)
Test ID: {test_id}
Execution Mode: Direct SSH (Quota Workaround)
Node: $(hostname)
Mode: {mode}
Start Time: $(date)
Julia Exit Code: $JULIA_EXIT_CODE
Depot Path: {self.depot_path}

# Generated Files:
$(ls -la {output_dir}/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Basic test completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Generated files:"
    ls -la {output_dir}/
else
    echo "❌ Basic test failed with exit code $JULIA_EXIT_CODE"
fi

echo ""
echo "✅ Direct basic test with output collection completed"
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Output directory: {output_dir}"
echo "Timestamp: $(date)"
"""

        print("🚀 Executing direct test via SSH...")

        try:
            # Run the test directly via SSH
            result = subprocess.run(
                ["ssh", self.cluster_host, julia_test],
                capture_output=True, text=True, timeout=180
            )

            print("📊 Test Output:")
            print("=" * 60)
            print(result.stdout)

            if result.stderr:
                print("\n⚠️  Warnings/Errors:")
                print(result.stderr)

            if result.returncode == 0:
                print(f"\n✅ DIRECT TEST SUCCESSFUL!")
                print(f"Test ID: {test_id}")
                print(f"Mode: {mode}")
                return f"direct_{test_id}", test_id
            else:
                print(f"\n❌ Test failed with return code: {result.returncode}")
                return None, None

        except subprocess.TimeoutExpired:
            print("❌ Test timed out after 3 minutes")
            return None, None
        except Exception as e:
            print(f"❌ Error during test execution: {e}")
            return None, None

def main():
    parser = argparse.ArgumentParser(description="Submit basic Julia test to HPC cluster")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"],
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--no-monitor", action="store_true",
                       help="Don't show monitoring commands")
    parser.add_argument("--auto-collect", action="store_true",
                       help="Automatically monitor job and collect outputs when complete")

    args = parser.parse_args()

    submitter = BasicTestSubmitter()
    slurm_job_id, test_id = submitter.submit_job(args.mode, monitor=not args.no_monitor, auto_collect=args.auto_collect)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Job submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: basic_test_results_{test_id}/")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
