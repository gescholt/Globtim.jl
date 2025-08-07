#!/usr/bin/env python3

"""
Simple HPC Dependencies Installation Script
===========================================

Simplified version to install missing Julia packages on the HPC cluster.

Usage:
    python install_hpc_dependencies_simple.py [--mode MODE]
"""

import argparse
import subprocess
import uuid
import tempfile
import os

class SimpleHPCInstaller:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
    
    def create_installation_script(self, test_id, mode="minimal"):
        """Create SLURM script for dependency installation"""
        
        if mode == "minimal":
            time_limit = "00:15:00"
            memory = "8G"
            cpus = 2
        else:
            time_limit = "00:30:00"
            memory = "16G"
            cpus = 4
        
        output_dir = f"dependency_install_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=hpc_deps_simple
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cpus}
#SBATCH --mem={memory}
#SBATCH --time={time_limit}
#SBATCH --output=hpc_deps_{test_id}_%j.out
#SBATCH --error=hpc_deps_{test_id}_%j.err

echo "=== HPC Dependencies Installation ==="
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia version: $(/sw/bin/julia --version)"
echo "Available space: $(df -h . | tail -1 | awk '{{print $4}}')"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Use minimal HPC project file
if [ -f "Project_HPC_Minimal.toml" ]; then
    cp Project_HPC_Minimal.toml Project.toml
    echo "✅ Using Project_HPC_Minimal.toml"
else
    echo "⚠️  Project_HPC_Minimal.toml not found, using existing Project.toml"
fi

echo ""
echo "=== Installing Missing Packages ==="

# Install packages one by one with error handling
/sw/bin/julia --project=. -e '
using Pkg

println("🚀 Installing Missing Dependencies")
println("Julia Version: $(VERSION)")
println()

# List of packages to install
packages = ["StaticArrays", "JSON3", "TimerOutputs", "TOML", "Printf"]

successful = String[]
failed = String[]

for pkg in packages
    println("Installing $pkg...")
    try
        Pkg.add(pkg)
        push!(successful, pkg)
        println("  ✅ $pkg installed successfully")
    catch e
        push!(failed, pkg)
        println("  ❌ $pkg failed: $e")
    end
    println()
end

println("📊 INSTALLATION SUMMARY:")
println("Successful: $(length(successful))")
for pkg in successful
    println("  ✅ $pkg")
end

if !isempty(failed)
    println("Failed: $(length(failed))")
    for pkg in failed
        println("  ❌ $pkg")
    end
end

# Save results
open("{output_dir}/installation_results.txt", "w") do f
    println(f, "HPC Dependencies Installation Results")
    println(f, "====================================")
    println(f, "Timestamp: $(now())")
    println(f, "Julia version: $(VERSION)")
    println(f, "")
    println(f, "Successful packages:")
    for pkg in successful
        println(f, "  ✅ $pkg")
    end
    println(f, "")
    println(f, "Failed packages:")
    for pkg in failed
        println(f, "  ❌ $pkg")
    end
end

if isempty(failed)
    println("🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!")
    exit(0)
else
    println("❌ SOME PACKAGES FAILED")
    exit(1)
end
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Installation Complete ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Test the installation by trying to load Globtim modules
if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=== Testing Globtim Module Loading ==="
    /sw/bin/julia --project=. -e '
    try
        include("src/BenchmarkFunctions.jl")
        println("✅ BenchmarkFunctions.jl loaded successfully")
        
        include("src/LibFunctions.jl")
        println("✅ LibFunctions.jl loaded successfully")
        
        include("src/Samples.jl")
        println("✅ Samples.jl loaded successfully")
        
        include("src/Structures.jl")
        println("✅ Structures.jl loaded successfully")
        
        println("🎉 ALL GLOBTIM MODULES LOADED SUCCESSFULLY!")
        
        # Save success status
        open("{output_dir}/module_test_results.txt", "w") do f
            println(f, "Globtim Module Loading Test")
            println(f, "===========================")
            println(f, "Timestamp: $(now())")
            println(f, "Status: SUCCESS")
            println(f, "All modules loaded successfully")
        end
        
    catch e
        println("❌ Module loading failed: $e")
        
        # Save error status
        open("{output_dir}/module_test_error.txt", "w") do f
            println(f, "Globtim Module Loading Error")
            println(f, "============================")
            println(f, "Timestamp: $(now())")
            println(f, "Error: $e")
        end
        
        exit(1)
    end
    '
    
    MODULE_TEST_EXIT_CODE=$?
    
    if [ $MODULE_TEST_EXIT_CODE -eq 0 ]; then
        echo "✅ Dependencies installation and module testing completed successfully"
    else
        echo "❌ Dependencies installed but module testing failed"
    fi
else
    echo "❌ Dependencies installation failed"
fi

# Create final summary
cat > {output_dir}/job_summary.txt << EOF
# HPC Dependencies Installation Summary
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Mode: {mode}
Start Time: $(date)
Duration: $SECONDS seconds
Installation Exit Code: $JULIA_EXIT_CODE
Module Test Exit Code: $MODULE_TEST_EXIT_CODE

# Generated Files:
$(ls -la {output_dir}/)
EOF

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, mode="minimal"):
        """Submit dependency installation job"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🚀 Submitting Simple HPC Dependencies Installation")
        print(f"Mode: {mode}")
        print(f"Test ID: {test_id}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_installation_script(test_id, mode)
        
        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.slurm', delete=False) as f:
            f.write(slurm_script)
            temp_script_path = f.name
        
        try:
            # Copy script to cluster
            remote_script = f"hpc_deps_simple_{test_id}.slurm"
            remote_path = f"{self.remote_dir}/{remote_script}"
            scp_cmd = ["scp", temp_script_path, f"{self.cluster_host}:{remote_path}"]
            
            print("📤 Copying script to cluster...")
            result = subprocess.run(scp_cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Failed to copy script: {result.stderr}")
                return None, None
            
            # Submit job
            print("🚀 Submitting job to SLURM...")
            submit_cmd = ["ssh", self.cluster_host, f"cd {self.remote_dir} && sbatch {remote_script}"]
            result = subprocess.run(submit_cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Extract job ID
                slurm_job_id = result.stdout.strip().split()[-1]
                print(f"✅ Job submitted successfully!")
                print(f"📋 SLURM Job ID: {slurm_job_id}")
                print(f"🔧 Test ID: {test_id}")
                print()
                
                print("📊 Monitoring Commands:")
                print(f"  Check status: ssh {self.cluster_host} 'squeue -j {slurm_job_id}'")
                print(f"  View output:  ssh {self.cluster_host} 'tail -f hpc_deps_{test_id}_{slurm_job_id}.out'")
                print(f"  Results dir:  ssh {self.cluster_host} 'ls -la {self.remote_dir}/dependency_install_{test_id}/'")
                
                return slurm_job_id, test_id
            else:
                print(f"❌ Job submission failed: {result.stderr}")
                return None, None
                
        except Exception as e:
            print(f"❌ Error during submission: {e}")
            return None, None
        finally:
            # Clean up temporary file
            if os.path.exists(temp_script_path):
                os.remove(temp_script_path)

def main():
    parser = argparse.ArgumentParser(description="Install HPC dependencies for Globtim (simple version)")
    parser.add_argument("--mode", choices=["minimal", "standard"], 
                       default="minimal", help="Installation mode (default: minimal)")
    
    args = parser.parse_args()
    
    installer = SimpleHPCInstaller()
    slurm_job_id, test_id = installer.submit_job(args.mode)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Job submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: dependency_install_{test_id}/")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
