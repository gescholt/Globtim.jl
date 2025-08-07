#!/usr/bin/env python3

"""
Submit Full Globtim Parametric Test

Submits comprehensive Globtim workflow test using minimal dependencies
to avoid plotting conflicts while maintaining full computational capabilities.
"""

import subprocess
import uuid
from pathlib import Path

def create_full_globtim_script(function_name, parameter_set, job_id):
    """Create SLURM script for full Globtim test"""
    
    script_content = f"""#!/bin/bash
#SBATCH --job-name=globtim_{function_name}_{parameter_set}
#SBATCH --output=globtim_{function_name}_{parameter_set}_{job_id}.out
#SBATCH --error=globtim_{function_name}_{parameter_set}_{job_id}.err
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --partition=batch

echo "🎯 Full Globtim Parametric Test"
echo "==============================="
echo "Function: {function_name}"
echo "Parameter Set: {parameter_set}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "📦 Setting up minimal Globtim environment..."
# Copy Globtim source and use minimal Project.toml
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC_Minimal.toml ./Project.toml

echo "📦 Installing essential packages..."
julia --project=. -e '
using Pkg
println("Installing core Globtim dependencies...")

# Install essential packages with error handling
essential_packages = [
    "DataFrames", "DynamicPolynomials", "ForwardDiff", 
    "HomotopyContinuation", "Optim", "LinearAlgebra",
    "Statistics", "Distributions", "Parameters"
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
echo "🚀 Running full Globtim parametric test..."
julia --project=. full_globtim_parametric_test.jl {function_name} {parameter_set}

echo
echo "✅ Full Globtim test completed"
echo "Finished: $(date)"
"""
    
    script_filename = f"globtim_{function_name}_{parameter_set}_{job_id}.slurm"
    with open(script_filename, 'w') as f:
        f.write(script_content)
    
    return script_filename

def submit_full_globtim_test(function_name="Sphere4D", parameter_set="quick_test"):
    """Submit full Globtim parametric test to cluster"""
    
    print("🚀 Submitting Full Globtim Parametric Test")
    print(f"Function: {function_name}")
    print(f"Parameter Set: {parameter_set}")
    print()
    
    # Generate job ID
    job_id = str(uuid.uuid4())[:8]
    
    # Create SLURM script
    script_file = create_full_globtim_script(function_name, parameter_set, job_id)
    print(f"✅ Created job script: {script_file}")
    
    # Upload files to cluster
    print("📤 Uploading files to cluster...")
    files_to_upload = [
        script_file, 
        "full_globtim_parametric_test.jl",
        "Project_HPC_Minimal.toml"
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
    
    parser = argparse.ArgumentParser(description="Submit full Globtim parametric test")
    parser.add_argument("function", nargs="?", default="Sphere4D", 
                       help="Function name (default: Sphere4D)")
    parser.add_argument("parameter_set", nargs="?", default="quick_test",
                       help="Parameter set (default: quick_test)")
    parser.add_argument("--quick", action="store_true",
                       help="Quick test mode")
    
    args = parser.parse_args()
    
    if args.quick:
        print("🚀 Quick Test Mode")
        submit_full_globtim_test("Sphere4D", "quick_test")
    else:
        submit_full_globtim_test(args.function, args.parameter_set)
