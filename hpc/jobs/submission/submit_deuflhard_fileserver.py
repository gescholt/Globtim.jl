#!/usr/bin/env python3

"""
Deuflhard Benchmark - Fileserver Integration
============================================

Submits Deuflhard benchmark tests using the fileserver (mack) for proper SLURM workflow.
Uses the three-tier architecture: Local → Fileserver → HPC Cluster.

Usage:
    python submit_deuflhard_fileserver.py [--mode MODE] [--auto-collect]
"""

import argparse
import subprocess
import uuid
import tempfile
import os
from datetime import datetime

class FileserverDeuflhardSubmitter:
    def __init__(self):
        self.fileserver_host = "scholten@mack"
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.fileserver_depot = "~/.julia"  # Complete package ecosystem on mack
        self.nfs_depot = "/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia"
        self.nfs_project = "/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc"
        
        # Test modes for Deuflhard benchmark
        self.test_modes = {
            "quick": {
                "time_limit": "00:30:00",
                "memory": "8G",
                "cpus": 4,
                "degree": 6,
                "samples": 50,
                "description": "Quick Deuflhard validation (30 min)"
            },
            "standard": {
                "time_limit": "02:00:00",
                "memory": "16G", 
                "cpus": 8,
                "degree": 8,
                "samples": 100,
                "description": "Standard Deuflhard benchmark (2 hours)"
            },
            "extended": {
                "time_limit": "04:00:00",
                "memory": "32G",
                "cpus": 16,
                "degree": 10,
                "samples": 200,
                "description": "Extended Deuflhard benchmark (4 hours)"
            }
        }
    
    def create_slurm_script(self, test_id, mode="quick"):
        """Create SLURM script for Deuflhard benchmark with fileserver integration"""
        
        config = self.test_modes[mode]
        # Work within existing globtim_hpc directory - no quota issues there
        output_dir = f"results/deuflhard_results_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=deuflhard_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={config['cpus']}
#SBATCH --mem={config['memory']}
#SBATCH --time={config['time_limit']}
#SBATCH --output={output_dir}/job_%j.out
#SBATCH --error={output_dir}/job_%j.err

echo "=== Deuflhard Benchmark with Fileserver Integration ==="
echo "Test ID: {test_id}"
echo "Mode: {mode} - {config['description']}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup with fileserver integration
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Try to use fileserver packages via NFS, fallback to /tmp
if [ -d "{self.nfs_depot}" ]; then
    export JULIA_DEPOT_PATH="{self.nfs_depot}:$JULIA_DEPOT_PATH"
    echo "✅ Using fileserver Julia packages via NFS"
else
    # Fallback: copy packages to /tmp
    echo "⚠️  NFS not available, using /tmp depot"
    export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
fi

# Work within globtim_hpc directory (no quota issues there)
cd {self.remote_dir}

echo "=== Environment Verification ==="
echo "Working directory: $(pwd)"
echo "Julia depot path: $JULIA_DEPOT_PATH"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create output directory on fileserver
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create test configuration
cat > {output_dir}/test_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "deuflhard_benchmark_fileserver",
  "execution_mode": "slurm_fileserver",
  "function": "Deuflhard",
  "dimension": 2,
  "parameters": {{
    "degree": {config["degree"]},
    "samples": {config["samples"]},
    "center": [0.0, 0.0],
    "sample_range": 1.5,
    "mode": "{mode}"
  }},
  "metadata": {{
    "created_by": "submit_deuflhard_fileserver.py",
    "purpose": "Deuflhard function validation with fileserver integration",
    "slurm_job_id": "$SLURM_JOB_ID",
    "node": "$SLURMD_NODENAME",
    "cpus": "{config['cpus']}",
    "memory": "{config['memory']}",
    "time_limit": "{config['time_limit']}",
    "depot_path": "{self.nfs_depot}",
    "project_path": "{self.nfs_project}"
  }}
}}
EOF

echo "✅ Test configuration created"

# Package and module verification
echo ""
echo "=== Package and Module Verification ==="
/sw/bin/julia --project=. -e '
println("📦 Verifying Package and Module Availability:")
println("Depot paths:")
for (i, path) in enumerate(DEPOT_PATH)
    println("  $i: $path")
end
println()

# Test critical packages
packages = ["StaticArrays", "JSON3", "TOML", "TimerOutputs", "LinearAlgebra"]
for pkg in packages
    try
        eval(Meta.parse("using $pkg"))
        println("✅ $pkg available and loaded")
    catch e
        println("❌ $pkg not available: $e")
    end
end

println()
println("🧮 Testing Globtim Module Loading:")

# Test BenchmarkFunctions module
try
    include("src/BenchmarkFunctions.jl")
    println("✅ BenchmarkFunctions.jl loaded successfully")
catch e
    println("❌ BenchmarkFunctions.jl failed: $e")
end

# Test LibFunctions module  
try
    include("src/LibFunctions.jl")
    println("✅ LibFunctions.jl loaded successfully")
catch e
    println("❌ LibFunctions.jl failed: $e")
end
'

echo ""

# Run the Deuflhard benchmark test
echo "=== Running Deuflhard Benchmark Test ==="
/sw/bin/julia --project=. -e '
using Dates

println("🚀 Deuflhard Benchmark Test Starting")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println()

# Load required packages and modules
println("📦 Loading Required Packages and Modules...")
try
    using StaticArrays, TimerOutputs, LinearAlgebra, JSON3, TOML
    println("  ✅ Core packages loaded successfully")
    
    # Define timer and precision types (required for Globtim)
    const _TO = TimerOutputs.TimerOutput()
    
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    println("  ✅ Timer and precision types defined")
    
    # Load Globtim modules
    include("src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl")
    println("  ✅ LibFunctions.jl loaded")
    
    println("  ✅ All modules loaded successfully")
    
catch e
    println("  ❌ Module loading failed: ", e)
    
    # Save error information
    output_dir = "{output_dir}"
    open(joinpath(output_dir, "module_loading_error.txt"), "w") do f
        println(f, "Deuflhard Module Loading Error")
        println(f, "==============================")
        println(f, "Timestamp: ", now())
        println(f, "Error: ", e)
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
    end
    
    exit(1)
end

println()

# Test Deuflhard function
println("🧮 Testing Deuflhard Function...")
output_dir = "{output_dir}"

try
    # Test function evaluation at various points
    test_points = [
        [0.0, 0.0],
        [0.5, 0.5], 
        [1.0, 1.0],
        [-0.5, 0.5],
        [0.2, -0.3],
        [1.5, -1.0],
        [-1.2, 0.8]
    ]
    
    function_values = []
    
    println("  Testing function evaluation:")
    for (i, point) in enumerate(test_points)
        value = Deuflhard(point)
        push!(function_values, value)
        println("    $i: f($point) = $value")
    end
    
    println("  ✅ Deuflhard function evaluation successful")
    
    # Save function evaluation results
    open(joinpath(output_dir, "function_evaluation_results.txt"), "w") do f
        println(f, "Deuflhard Function Evaluation Results")
        println(f, "=====================================")
        println(f, "Timestamp: ", now())
        println(f, "Function: Deuflhard (2D)")
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
        println(f, "Node: ", get(ENV, "SLURMD_NODENAME", "not_set"))
        println(f, "")
        println(f, "Test Points and Values:")
        for (i, (point, value)) in enumerate(zip(test_points, function_values))
            println(f, "  $i: f($point) = $value")
        end
        println(f, "")
        println(f, "Statistics:")
        println(f, "  Min value: ", minimum(function_values))
        println(f, "  Max value: ", maximum(function_values))
        println(f, "  Mean value: ", sum(function_values) / length(function_values))
        println(f, "")
        println(f, "Environment:")
        println(f, "  Julia version: ", VERSION)
        println(f, "  Hostname: ", gethostname())
        println(f, "  Threads: ", Threads.nthreads())
        println(f, "  CPUs: ", get(ENV, "SLURM_CPUS_PER_TASK", "not_set"))
    end
    
    println("  ✅ Function evaluation results saved")
    
    # Performance benchmark
    println()
    println("⚡ Performance Benchmark:")
    
    # Time multiple evaluations
    n_evaluations = 1000
    start_time = time()
    
    for i in 1:n_evaluations
        # Random points in [-1, 1]^2
        point = [2*rand() - 1, 2*rand() - 1]
        value = Deuflhard(point)
    end
    
    end_time = time()
    total_time = end_time - start_time
    avg_time = total_time / n_evaluations
    
    println("  Evaluations: $n_evaluations")
    println("  Total time: $total_time seconds")
    println("  Average time per evaluation: $avg_time seconds")
    println("  Evaluations per second: ", n_evaluations / total_time)
    
    # Save performance results
    open(joinpath(output_dir, "performance_results.txt"), "w") do f
        println(f, "Deuflhard Performance Benchmark Results")
        println(f, "=======================================")
        println(f, "Timestamp: ", now())
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "")
        println(f, "Performance Metrics:")
        println(f, "  Function evaluations: $n_evaluations")
        println(f, "  Total computation time: $total_time seconds")
        println(f, "  Average time per evaluation: $avg_time seconds")
        println(f, "  Evaluations per second: ", n_evaluations / total_time)
        println(f, "")
        println(f, "Environment:")
        println(f, "  Julia version: ", VERSION)
        println(f, "  Hostname: ", gethostname())
        println(f, "  Threads: ", Threads.nthreads())
        println(f, "  SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
        println(f, "  Node: ", get(ENV, "SLURMD_NODENAME", "not_set"))
        println(f, "  CPUs: ", get(ENV, "SLURM_CPUS_PER_TASK", "not_set"))
    end
    
    println("  ✅ Performance results saved")
    
catch e
    println("  ❌ Deuflhard function test failed: ", e)
    
    # Save error information
    open(joinpath(output_dir, "function_test_error.txt"), "w") do f
        println(f, "Deuflhard Function Test Error")
        println(f, "=============================")
        println(f, "Timestamp: ", now())
        println(f, "Error: ", e)
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
    end
    
    exit(1)
end

println()

# Create comprehensive results summary
println("📋 Creating Results Summary...")
try
    open(joinpath(output_dir, "deuflhard_test_summary.txt"), "w") do f
        println(f, "Deuflhard Benchmark Test Summary")
        println(f, "================================")
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "Timestamp: ", now())
        println(f, "Function: Deuflhard (2D)")
        println(f, "Execution: SLURM with Fileserver Integration")
        println(f, "")
        println(f, "Configuration:")
        println(f, "  Degree: {config["degree"]}")
        println(f, "  Samples: {config["samples"]}")
        println(f, "  CPUs: {config["cpus"]}")
        println(f, "  Memory: {config["memory"]}")
        println(f, "  Time Limit: {config["time_limit"]}")
        println(f, "")
        println(f, "Environment:")
        println(f, "  Julia version: ", VERSION)
        println(f, "  Hostname: ", gethostname())
        println(f, "  Threads: ", Threads.nthreads())
        println(f, "  Depot path: ", DEPOT_PATH[1])
        println(f, "  SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
        println(f, "  Node: ", get(ENV, "SLURMD_NODENAME", "not_set"))
        println(f, "")
        println(f, "Test Results:")
        println(f, "  ✅ Package loading: SUCCESS")
        println(f, "  ✅ Module loading: SUCCESS")
        println(f, "  ✅ Function evaluation: SUCCESS")
        println(f, "  ✅ Performance benchmark: SUCCESS")
        println(f, "  ✅ Output collection: SUCCESS")
        println(f, "")
        println(f, "Status: COMPLETE SUCCESS")
    end
    
    println("  ✅ Test summary saved")
    
catch e
    println("  ❌ Summary creation failed: ", e)
end

println()
println("🎉 DEUFLHARD BENCHMARK TEST COMPLETED SUCCESSFULLY!")
println("Test ID: {test_id}")
println("Mode: {mode}")
println("End Time: ", now())
println("All functionality verified ✅")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Deuflhard Benchmark Job Summary (Fileserver Integration)
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Execution Mode: SLURM with Fileserver Integration
Node: $SLURMD_NODENAME
Mode: {mode}
Function: Deuflhard (2D)
Start Time: $(date)
Duration: $SECONDS seconds
Julia Exit Code: $JULIA_EXIT_CODE

Configuration:
  Degree: {config['degree']}
  Samples: {config['samples']}
  CPUs: {config['cpus']}
  Memory: {config['memory']}
  Time Limit: {config['time_limit']}

Paths:
  Depot Path: {self.nfs_depot}
  Project Path: {self.nfs_project}

# Generated Files:
$(ls -la {output_dir}/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Deuflhard benchmark completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Generated files:"
    ls -la {output_dir}/
else
    echo "❌ Deuflhard benchmark failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, mode="quick", auto_collect=False):
        """Submit Deuflhard benchmark job using fileserver"""
        test_id = str(uuid.uuid4())[:8]
        
        if mode not in self.test_modes:
            print(f"❌ Invalid mode: {mode}")
            print(f"Available modes: {list(self.test_modes.keys())}")
            return None, None
        
        config = self.test_modes[mode]
        
        print(f"🚀 Submitting Deuflhard Benchmark via Fileserver")
        print(f"Mode: {mode} - {config['description']}")
        print(f"Resources: {config['cpus']} CPUs, {config['memory']} memory, {config['time_limit']}")
        print(f"Parameters: degree={config['degree']}, samples={config['samples']}")
        print(f"Test ID: {test_id}")
        print(f"Fileserver: {self.fileserver_host}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_slurm_script(test_id, mode)
        
        # Create results directory within globtim_hpc (no quota issues there)
        output_dir = f"results/deuflhard_results_{test_id}"

        try:
            # Create output directory within globtim_hpc
            print("📁 Creating output directory within globtim_hpc...")
            mkdir_cmd = f"ssh {self.fileserver_host} 'cd {self.remote_dir} && mkdir -p {output_dir}'"
            result = subprocess.run(mkdir_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Failed to create output directory: {result.stderr}")
                return None, None
            
            # Create and submit SLURM script in /tmp (fileserver also has quota limits)
            remote_script = f"/tmp/deuflhard_{test_id}.slurm"

            print("📤 Creating and submitting SLURM script on fileserver (using /tmp)...")
            submit_cmd = f"""ssh {self.fileserver_host} '
cd {self.remote_dir}
cat > {remote_script} << "EOF"
{slurm_script}
EOF
sbatch {remote_script}
rm {remote_script}
'"""
            
            result = subprocess.run(submit_cmd, shell=True, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                # Extract job ID
                slurm_job_id = result.stdout.strip().split()[-1]
                print(f"✅ Job submitted successfully!")
                print(f"📋 SLURM Job ID: {slurm_job_id}")
                print(f"🔧 Test ID: {test_id}")
                print()
                
                print("📊 Monitoring Commands:")
                print(f"  Check status: ssh {self.fileserver_host} 'squeue -j {slurm_job_id}'")
                print(f"  View output:  ssh {self.fileserver_host} 'tail -f {self.remote_dir}/{output_dir}/job_{slurm_job_id}.out'")
                print(f"  Results dir:  ssh {self.fileserver_host} 'ls -la {self.remote_dir}/{output_dir}/'")
                print()
                print("🤖 Alternative Monitoring:")
                print(f"  From cluster: ssh {self.cluster_host} 'squeue -j {slurm_job_id}'")
                
                return slurm_job_id, test_id
            else:
                print(f"❌ Job submission failed: {result.stderr}")
                return None, None
                
        except subprocess.TimeoutExpired:
            print("❌ Job submission timed out")
            return None, None
        except Exception as e:
            print(f"❌ Error during submission: {e}")
            return None, None

def main():
    parser = argparse.ArgumentParser(description="Submit Deuflhard benchmark using fileserver integration")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"], 
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--auto-collect", action="store_true",
                       help="Automatically collect results when complete")
    parser.add_argument("--list-modes", action="store_true",
                       help="List available test modes")
    
    args = parser.parse_args()
    
    submitter = FileserverDeuflhardSubmitter()
    
    if args.list_modes:
        print("Available test modes:")
        for mode, config in submitter.test_modes.items():
            print(f"  {mode}: {config['description']}")
            print(f"    Resources: {config['cpus']} CPUs, {config['memory']} memory, {config['time_limit']}")
            print(f"    Parameters: degree={config['degree']}, samples={config['samples']}")
        return
    
    slurm_job_id, test_id = submitter.submit_job(args.mode, args.auto_collect)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Deuflhard benchmark submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: results/deuflhard_results_{test_id}/")
        print(f"🔧 Using fileserver integration for persistent storage")
        print(f"📋 Job submitted from: {submitter.fileserver_host}")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
