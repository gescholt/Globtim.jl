#!/usr/bin/env python3

"""
Simple Julia Test - HPC Workflow Verification
==============================================

Runs a basic Julia test to verify the HPC workflow works end-to-end.
Tests package loading, basic computations, and file I/O.

Usage:
    python submit_simple_julia_test.py [--auto-collect]
"""

import argparse
import subprocess
import uuid
import tempfile
import os
from datetime import datetime

class SimpleJuliaTestSubmitter:
    def __init__(self):
        self.fileserver_host = "scholten@mack"
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        
    def submit_job(self, auto_collect=False):
        """Submit simple Julia test job"""
        test_id = str(uuid.uuid4())[:8]
        
        print("🚀 Submitting Simple Julia Test")
        print(f"Test ID: {test_id}")
        print(f"Cluster: {self.cluster_host}")
        print()
        
        # Create SLURM script
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=simple_julia_test
#SBATCH --partition=batch
#SBATCH --account=mpi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --output=simple_julia_test_{test_id}_%j.out
#SBATCH --error=simple_julia_test_{test_id}_%j.err

echo "=== Simple Julia Test ==="
echo "Test ID: {test_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup with NFS Julia configuration
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Source NFS Julia configuration script
echo "=== Configuring Julia for NFS ==="
source ./setup_nfs_julia.sh

# Verify NFS depot is accessible
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ NFS Julia depot configured: $JULIA_DEPOT_PATH"
else
    echo "❌ NFS Julia depot not accessible: $JULIA_DEPOT_PATH"
    exit 1
fi

# Work in globtim_hpc directory
cd {self.remote_dir}

echo "=== Environment Verification ==="
echo "Working directory: $(pwd)"
echo "Julia depot path: $JULIA_DEPOT_PATH"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create results directory
mkdir -p results/simple_julia_test_{test_id}

echo "=== Running Simple Julia Test ==="
/sw/bin/julia test_julia_hpc.jl

echo ""
echo "=== Test Summary ==="
echo "End time: $(date)"
echo "Test completed"
"""

        try:
            print("📤 Creating and submitting SLURM script on cluster...")

            # Create SLURM script on cluster and submit
            script_name = f"simple_julia_test_{test_id}.slurm"
            cmd = [
                "ssh", self.cluster_host,
                f"""cd {self.remote_dir} && cat > /tmp/{script_name} << 'EOF'
{slurm_script}
EOF
sbatch --account=mpi --partition=batch /tmp/{script_name}"""
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            
            if result.returncode == 0:
                # Extract job ID from output
                output_lines = result.stdout.strip().split('\n')
                job_line = [line for line in output_lines if 'Submitted batch job' in line]
                if job_line:
                    slurm_job_id = job_line[0].split()[-1]
                else:
                    print(f"❌ Could not extract job ID from: {result.stdout}")
                    return None, None
                
                print(f"✅ Job submitted successfully!")
                print(f"📋 SLURM Job ID: {slurm_job_id}")
                print(f"🔧 Test ID: {test_id}")
                print()
                
                print("📊 Monitoring Commands:")
                print(f"  Check status: ssh {self.cluster_host} 'squeue -j {slurm_job_id}'")
                print(f"  View output:  ssh {self.cluster_host} 'cd {self.remote_dir} && tail -f simple_julia_test_{test_id}_{slurm_job_id}.out'")
                print(f"  Check results: ssh {self.cluster_host} 'ls -la {self.remote_dir}/results/simple_julia_test_{test_id}/'")
                
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
    parser = argparse.ArgumentParser(description="Submit simple Julia test to verify HPC workflow")
    parser.add_argument("--auto-collect", action="store_true",
                       help="Automatically collect results when complete")

    args = parser.parse_args()

    submitter = SimpleJuliaTestSubmitter()
    slurm_job_id, test_id = submitter.submit_job(args.auto_collect)

    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Simple Julia test submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: {submitter.remote_dir}/results/simple_julia_test_{test_id}/")
        print(f"📋 Job submitted from: {submitter.cluster_host}")
        
        if args.auto_collect:
            print(f"\n🤖 Starting automated monitoring...")
            print(f"Run: python3 hpc/jobs/submission/automated_job_monitor.py --job-id {slurm_job_id} --test-id {test_id}")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
