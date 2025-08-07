#!/usr/bin/env python3

"""
Parametric Test Submission System

Easy-to-use system for submitting parametric benchmark tests to HPC cluster.
Automatically generates SLURM jobs, submits them, and tracks results.
"""

import argparse
import subprocess
import json
from pathlib import Path
from datetime import datetime
import uuid

class ParametricTestSubmitter:
    def __init__(self, cluster_host="scholten@falcon", remote_dir="~/globtim_hpc"):
        self.cluster_host = cluster_host
        self.remote_dir = remote_dir
        
        # Available functions and parameter sets
        self.functions = {
            "Sphere4D": "Simple quadratic function with single global minimum",
            "Rosenbrock4D": "Extended Rosenbrock with narrow curved valley", 
            "Rastrigin4D": "Highly multimodal with many local minima"
        }
        
        self.parameter_sets = {
            "quick_test": {"desc": "Fast test - low accuracy", "time": "00:05:00", "mem": "2G"},
            "standard_test": {"desc": "Balanced accuracy/speed", "time": "00:15:00", "mem": "4G"},
            "high_accuracy": {"desc": "High accuracy - slower", "time": "00:30:00", "mem": "8G"},
            "stress_test": {"desc": "Large-scale performance test", "time": "01:00:00", "mem": "16G"},
            "off_center": {"desc": "Off-center sampling test", "time": "00:20:00", "mem": "4G"}
        }
    
    def create_slurm_job(self, function_name, parameter_set, job_id=None):
        """Create SLURM job script for parametric test"""
        if job_id is None:
            job_id = str(uuid.uuid4())[:8]
        
        params = self.parameter_sets[parameter_set]
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=param_{function_name}_{parameter_set}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem={params['mem']}
#SBATCH --time={params['time']}
#SBATCH --output=param_{function_name}_{parameter_set}_{job_id}_%j.out
#SBATCH --error=param_{function_name}_{parameter_set}_{job_id}_%j.err

echo "🎯 Parametric Benchmark Test"
echo "============================="
echo "Function: {function_name}"
echo "Parameter Set: {parameter_set}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo ""

# Set up Julia environment
export JULIA_DEPOT_PATH="/tmp/julia_depot_59771288"
if [ ! -d "$JULIA_DEPOT_PATH" ]; then
    export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
    mkdir -p "$JULIA_DEPOT_PATH"
fi

echo "📦 Julia depot: $JULIA_DEPOT_PATH"

# Use system Julia
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo ""

echo "📁 Working directory: $(pwd)"
echo ""

# Activate project and install packages
echo "📦 Installing/updating packages..."
julia --project=. -e "
using Pkg
Pkg.instantiate()
if !haskey(Pkg.project().dependencies, \\"JSON3\\")
    Pkg.add(\\"JSON3\\")
end
Pkg.precompile()
println(\\"✅ Package setup complete\\")
"

echo ""
echo "🚀 Running parametric test..."
echo ""

# Run the parametric test
julia --project=. parametric_test_framework.jl {function_name} {parameter_set}

echo ""
echo "✅ Parametric test completed"
echo "Finished: $(date)"
"""
        
        return slurm_script, job_id
    
    def submit_test(self, function_name, parameter_set, dry_run=False):
        """Submit parametric test to cluster"""
        print(f"🎯 Submitting Parametric Test")
        print(f"Function: {function_name}")
        print(f"Parameter Set: {parameter_set}")
        print(f"Description: {self.parameter_sets[parameter_set]['desc']}")
        print()
        
        # Create job script
        slurm_script, job_id = self.create_slurm_job(function_name, parameter_set)
        script_filename = f"param_{function_name}_{parameter_set}_{job_id}.slurm"
        
        # Save locally
        with open(script_filename, 'w') as f:
            f.write(slurm_script)
        print(f"✅ Created job script: {script_filename}")
        
        if dry_run:
            print("🔍 DRY RUN - Job script created but not submitted")
            print(f"📄 Review: {script_filename}")
            return None, job_id
        
        # Upload framework and job script
        print("📤 Uploading files to cluster...")
        try:
            subprocess.run([
                "rsync", "-avz", 
                "parametric_test_framework.jl", script_filename,
                f"{self.cluster_host}:{self.remote_dir}/"
            ], check=True, capture_output=True)
            print("✅ Files uploaded successfully")
        except subprocess.CalledProcessError as e:
            print(f"❌ Upload failed: {e}")
            return None, job_id
        
        # Submit job
        print("🚀 Submitting job to SLURM...")
        try:
            result = subprocess.run([
                "ssh", self.cluster_host, 
                f"cd {self.remote_dir} && sbatch {script_filename}"
            ], capture_output=True, text=True, check=True)
            
            # Extract job ID from output
            slurm_job_id = result.stdout.strip().split()[-1]
            print(f"✅ Job submitted successfully!")
            print(f"📋 SLURM Job ID: {slurm_job_id}")
            print(f"🔍 Monitor with: python3 hpc/monitoring/python/slurm_monitor.py --analyze {slurm_job_id}")
            
            return slurm_job_id, job_id
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Job submission failed: {e}")
            print(f"Error output: {e.stderr}")
            return None, job_id
    
    def submit_batch(self, test_configs, dry_run=False):
        """Submit multiple tests as a batch"""
        print(f"🎯 Batch Parametric Test Submission")
        print(f"Tests to submit: {len(test_configs)}")
        print()
        
        submitted_jobs = []
        
        for i, (function_name, parameter_set) in enumerate(test_configs, 1):
            print(f"📋 Test {i}/{len(test_configs)}: {function_name} with {parameter_set}")
            
            slurm_job_id, job_id = self.submit_test(function_name, parameter_set, dry_run)
            
            if slurm_job_id:
                submitted_jobs.append({
                    "function": function_name,
                    "parameter_set": parameter_set,
                    "slurm_job_id": slurm_job_id,
                    "internal_job_id": job_id,
                    "submission_time": datetime.now().isoformat()
                })
            
            print()
        
        if submitted_jobs and not dry_run:
            # Save batch info
            batch_file = f"batch_submission_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(batch_file, 'w') as f:
                json.dump(submitted_jobs, f, indent=2)
            
            print(f"📋 Batch submission complete!")
            print(f"💾 Batch info saved to: {batch_file}")
            print(f"✅ Successfully submitted: {len(submitted_jobs)} jobs")
            
            # Print monitoring commands
            print(f"\n🔍 Monitor all jobs:")
            for job in submitted_jobs:
                print(f"   python3 hpc/monitoring/python/slurm_monitor.py --analyze {job['slurm_job_id']}")
        
        return submitted_jobs
    
    def list_options(self):
        """List available functions and parameter sets"""
        print("📚 AVAILABLE BENCHMARK FUNCTIONS")
        print("=" * 40)
        for name, desc in self.functions.items():
            print(f"🎯 {name}: {desc}")
        
        print(f"\n⚙️  AVAILABLE PARAMETER SETS")
        print("=" * 40)
        for name, info in self.parameter_sets.items():
            print(f"🔧 {name}: {info['desc']}")
            print(f"   Time: {info['time']}, Memory: {info['mem']}")
        print()

def main():
    parser = argparse.ArgumentParser(description="Submit parametric benchmark tests to HPC cluster")
    parser.add_argument("function", nargs='?', help="Benchmark function name")
    parser.add_argument("parameter_set", nargs='?', help="Parameter set name")
    parser.add_argument("--list", action="store_true", help="List available options")
    parser.add_argument("--batch", help="Submit batch from JSON file")
    parser.add_argument("--dry-run", action="store_true", help="Create job scripts but don't submit")
    parser.add_argument("--quick", action="store_true", help="Submit quick test with Sphere4D")
    
    args = parser.parse_args()
    
    submitter = ParametricTestSubmitter()
    
    if args.list:
        submitter.list_options()
        return
    
    if args.quick:
        print("🚀 Quick Test Mode")
        submitter.submit_test("Sphere4D", "quick_test", args.dry_run)
        return
    
    if args.batch:
        with open(args.batch, 'r') as f:
            test_configs = json.load(f)
        submitter.submit_batch(test_configs, args.dry_run)
        return
    
    if args.function and args.parameter_set:
        submitter.submit_test(args.function, args.parameter_set, args.dry_run)
        return
    
    # Interactive mode
    print("🎯 Interactive Parametric Test Submission")
    print("=" * 50)
    submitter.list_options()
    
    print("Examples:")
    print("  python3 submit_parametric_test.py Sphere4D quick_test")
    print("  python3 submit_parametric_test.py --quick")
    print("  python3 submit_parametric_test.py --list")

if __name__ == "__main__":
    main()
