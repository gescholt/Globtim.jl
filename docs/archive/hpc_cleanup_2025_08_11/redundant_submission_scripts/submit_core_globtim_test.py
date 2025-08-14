#!/usr/bin/env python3

"""
Submit Core Globtim Benchmarking Test

Submits comprehensive benchmarking test using extracted core Globtim functionality
without any plotting or complex dependencies.
"""

import subprocess
import uuid
from pathlib import Path

def create_core_globtim_script(function_name, parameter_set, job_id):
    """Create SLURM script for core Globtim benchmarking test"""
    
    script_content = f"""#!/bin/bash
#SBATCH --job-name=core_globtim_{function_name}_{parameter_set}
#SBATCH --output=core_globtim_{function_name}_{parameter_set}_{job_id}.out
#SBATCH --error=core_globtim_{function_name}_{parameter_set}_{job_id}.err
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --partition=batch

echo "🎯 Core Globtim Benchmarking Test"
echo "================================="
echo "Function: {function_name}"
echo "Parameter Set: {parameter_set}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment with temporary depot to avoid quota issues
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
export PATH="/sw/bin:$PATH"

echo "🔧 Julia environment setup:"
echo "   JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"
mkdir -p "$JULIA_DEPOT_PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "📦 Installing essential packages..."
julia -e '
using Pkg
println("Installing core dependencies...")

# Install essential packages with error handling
essential_packages = [
    "DataFrames", "DynamicPolynomials", "ForwardDiff", 
    "HomotopyContinuation", "Optim", "Parameters", "Distributions"
]

for pkg in essential_packages
    try
        println("Installing $pkg...")
        Pkg.add(pkg)
        println("✓ $pkg installed")
    catch e
        println("⚠️  Failed to install $pkg: $e")
    end
end

println("📦 Package installation complete")
'

echo
echo "🧪 Testing core dependencies..."
julia -e '
println("Testing package loading...")
try
    using DataFrames, DynamicPolynomials, ForwardDiff
    using HomotopyContinuation, Optim, Parameters, Distributions
    using LinearAlgebra, Statistics, Dates, Printf
    println("✅ All core dependencies loaded successfully")
catch e
    println("❌ Dependency loading failed: $e")
    exit(1)
end
'

echo
echo "🚀 Running core Globtim benchmarking test..."
julia core_globtim_benchmarking.jl {function_name} {parameter_set}

echo
echo "✅ Core Globtim benchmarking test completed"
echo "Finished: $(date)"
"""
    
    script_filename = f"core_globtim_{function_name}_{parameter_set}_{job_id}.slurm"
    with open(script_filename, 'w') as f:
        f.write(script_content)
    
    return script_filename

def submit_core_globtim_test(function_name="Sphere4D", parameter_set="quick_test"):
    """Submit core Globtim benchmarking test to cluster"""
    
    print("🚀 Submitting Core Globtim Benchmarking Test")
    print(f"Function: {function_name}")
    print(f"Parameter Set: {parameter_set}")
    print()
    
    # Generate job ID
    job_id = str(uuid.uuid4())[:8]
    
    # Create SLURM script
    script_file = create_core_globtim_script(function_name, parameter_set, job_id)
    print(f"✅ Created job script: {script_file}")
    
    # Upload files to cluster
    print("📤 Uploading files to cluster...")
    files_to_upload = [
        script_file, 
        "core_globtim_benchmarking.jl"
    ]
    
    for file in files_to_upload:
        if not Path(file).exists():
            print(f"❌ File not found: {file}")
            return
    
    # Upload files
    try:
        cmd = ["rsync", "-avz"] + files_to_upload + ["scholten@falcon:~/globtim_hpc/"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("✅ Files uploaded successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Upload failed: {e}")
        return
    
    # Submit job
    print("🚀 Submitting job to SLURM...")
    try:
        cmd = ["ssh", "scholten@falcon", f"cd ~/globtim_hpc && sbatch {script_file}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        # Extract job ID from output
        output_lines = result.stdout.strip().split('\\n')
        for line in output_lines:
            if "Submitted batch job" in line:
                slurm_job_id = line.split()[-1]
                print("✅ Job submitted successfully!")
                print(f"📋 SLURM Job ID: {slurm_job_id}")
                print(f"🔍 Monitor with: python3 hpc/monitoring/python/slurm_monitor.py --analyze {slurm_job_id}")
                return slurm_job_id
        
        print("⚠️  Job submitted but couldn't extract job ID")
        print(f"Output: {result.stdout}")
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Job submission failed: {e}")
        print(f"Error output: {e.stderr}")
    
    # Cleanup local script file
    try:
        Path(script_file).unlink()
    except:
        pass

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Submit core Globtim benchmarking test")
    parser.add_argument("function", nargs="?", default="Sphere4D", 
                       help="Function name (default: Sphere4D)")
    parser.add_argument("parameter_set", nargs="?", default="quick_test",
                       help="Parameter set (default: quick_test)")
    parser.add_argument("--quick", action="store_true",
                       help="Quick test mode")
    
    args = parser.parse_args()
    
    if args.quick:
        print("🚀 Quick Test Mode")
        submit_core_globtim_test("Sphere4D", "quick_test")
    else:
        submit_core_globtim_test(args.function, args.parameter_set)
