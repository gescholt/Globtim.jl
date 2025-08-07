#!/usr/bin/env python3

"""
Basic Test Submission - Fileserver Integration
==============================================

Submits basic Julia tests using the fileserver (mack) for proper SLURM workflow.
Uses the three-tier architecture: Local → Fileserver → HPC Cluster.

Usage:
    python submit_basic_test_fileserver.py [--mode MODE] [--auto-collect]
"""

import argparse
import subprocess
import uuid
import tempfile
import os
from datetime import datetime

class FileserverBasicTestSubmitter:
    def __init__(self):
        self.fileserver_host = "scholten@mack"
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.fileserver_depot = "~/.julia"  # Complete package ecosystem on mack
        self.nfs_depot = "/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia"
        self.nfs_project = "/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc"
        
        # Test modes
        self.test_modes = {
            "quick": {
                "time_limit": "00:15:00",
                "memory": "4G",
                "cpus": 2,
                "description": "Quick validation test (15 min)"
            },
            "standard": {
                "time_limit": "01:00:00",
                "memory": "8G", 
                "cpus": 4,
                "description": "Standard comprehensive test (1 hour)"
            },
            "extended": {
                "time_limit": "02:00:00",
                "memory": "16G",
                "cpus": 8,
                "description": "Extended validation test (2 hours)"
            }
        }
    
    def create_slurm_script(self, test_id, mode="quick"):
        """Create SLURM script for basic test with fileserver integration"""
        
        config = self.test_modes[mode]
        output_dir = f"results/basic_test_results_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=basic_test_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={config['cpus']}
#SBATCH --mem={config['memory']}
#SBATCH --time={config['time_limit']}
#SBATCH --output={output_dir}/job_%j.out
#SBATCH --error={output_dir}/job_%j.err

echo "=== Basic Julia Test with Fileserver Integration ==="
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
export JULIA_DEPOT_PATH="{self.nfs_depot}:$JULIA_DEPOT_PATH"

# Change to project directory (NFS mount)
cd {self.nfs_project}

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
cat > {output_dir}/input_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "basic_validation_fileserver",
  "execution_mode": "slurm_fileserver",
  "parameters": {{
    "computation_size": 100000,
    "output_format": "json_and_txt",
    "mode": "{mode}"
  }},
  "metadata": {{
    "created_by": "submit_basic_test_fileserver.py",
    "purpose": "HPC cluster validation with fileserver integration",
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

# Package verification
echo ""
echo "=== Package Verification ==="
/sw/bin/julia -e '
println("📦 Verifying Package Availability:")
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
'

echo ""

# Run the basic Julia test
echo "=== Running Basic Julia Test ==="
/sw/bin/julia --project=. -e '
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

    # Save results
    open(joinpath(output_dir, "basic_math_results.txt"), "w") do f
        println(f, "Basic Math Test Results")
        println(f, "======================")
        println(f, "Timestamp: ", now())
        println(f, "Input size: ", length(x))
        println(f, "Sum result: ", z)
        println(f, "Mean result: ", z / length(x))
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
        println(f, "SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
    end

    println("  ✅ Results saved to basic_math_results.txt")

catch e
    println("  ❌ Basic computation failed: ", e)
    exit(1)
end

println()

# Test 2: Package loading and system info
println("📦 Test 2: Package Loading and System Information")
try
    # Test package loading
    using StaticArrays, LinearAlgebra, TOML, JSON3
    
    # Test StaticArrays functionality
    v = SVector(1.0, 2.0, 3.0)
    v_norm = norm(v)
    
    # Save system info
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
        println(f, "SLURM Environment:")
        println(f, "  Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
        println(f, "  Node: ", get(ENV, "SLURMD_NODENAME", "not_set"))
        println(f, "  CPUs: ", get(ENV, "SLURM_CPUS_PER_TASK", "not_set"))
        println(f, "  Memory: ", get(ENV, "SLURM_MEM_PER_NODE", "not_set"))
        println(f, "")
        println(f, "Package Tests:")
        println(f, "  StaticArrays: SUCCESS - vector norm = ", v_norm)
        println(f, "  LinearAlgebra: SUCCESS")
        println(f, "  TOML: SUCCESS")
        println(f, "  JSON3: SUCCESS")
    end

    println("  ✅ All packages loaded successfully")
    println("  ✅ StaticArrays test: ", v, " (norm: ", v_norm, ")")
    println("  ✅ System information saved")

catch e
    println("  ❌ Package loading failed: ", e)
    exit(1)
end

println()

# Test 3: Performance benchmark
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
        println(f, "Node: ", gethostname())
        println(f, "SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
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
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Basic Julia Test Job Summary (Fileserver Integration)
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Execution Mode: SLURM with Fileserver Integration
Node: $SLURMD_NODENAME
Mode: {mode}
Start Time: $(date)
Duration: $SECONDS seconds
Julia Exit Code: $JULIA_EXIT_CODE
CPUs: {config['cpus']}
Memory: {config['memory']}
Time Limit: {config['time_limit']}
Depot Path: {self.nfs_depot}
Project Path: {self.nfs_project}

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

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, mode="quick", auto_collect=False):
        """Submit basic test job using fileserver"""
        test_id = str(uuid.uuid4())[:8]
        
        if mode not in self.test_modes:
            print(f"❌ Invalid mode: {mode}")
            print(f"Available modes: {list(self.test_modes.keys())}")
            return None, None
        
        config = self.test_modes[mode]
        
        print(f"🚀 Submitting Basic Julia Test via Fileserver")
        print(f"Mode: {mode} - {config['description']}")
        print(f"Resources: {config['cpus']} CPUs, {config['memory']} memory, {config['time_limit']}")
        print(f"Test ID: {test_id}")
        print(f"Fileserver: {self.fileserver_host}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_slurm_script(test_id, mode)
        
        # Create results directory on fileserver first
        output_dir = f"results/basic_test_results_{test_id}"
        
        try:
            # Create output directory on fileserver
            print("📁 Creating output directory on fileserver...")
            mkdir_cmd = f"ssh {self.fileserver_host} 'cd {self.remote_dir} && mkdir -p {output_dir}'"
            result = subprocess.run(mkdir_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Failed to create output directory: {result.stderr}")
                return None, None
            
            # Create and submit SLURM script on fileserver
            remote_script = f"slurm_scripts/basic_test_{test_id}.slurm"
            
            print("📤 Creating and submitting SLURM script on fileserver...")
            submit_cmd = f"""ssh {self.fileserver_host} '
cd {self.remote_dir}
mkdir -p slurm_scripts
cat > {remote_script} << "EOF"
{slurm_script}
EOF
sbatch {remote_script}
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
    parser = argparse.ArgumentParser(description="Submit basic test using fileserver integration")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"], 
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--auto-collect", action="store_true",
                       help="Automatically collect results when complete")
    parser.add_argument("--list-modes", action="store_true",
                       help="List available test modes")
    
    args = parser.parse_args()
    
    submitter = FileserverBasicTestSubmitter()
    
    if args.list_modes:
        print("Available test modes:")
        for mode, config in submitter.test_modes.items():
            print(f"  {mode}: {config['description']}")
            print(f"    Resources: {config['cpus']} CPUs, {config['memory']} memory, {config['time_limit']}")
        return
    
    slurm_job_id, test_id = submitter.submit_job(args.mode, args.auto_collect)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Basic test submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: results/basic_test_results_{test_id}/")
        print(f"🔧 Using fileserver integration for persistent storage")
        print(f"📋 Job submitted from: {submitter.fileserver_host}")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
