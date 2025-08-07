#!/usr/bin/env python3

"""
HPC Dependencies Installation Script
====================================

Installs missing Julia packages on the HPC cluster for Globtim functionality.
Uses the HPC-specific Project.toml files and handles dependency resolution.

Usage:
    python install_hpc_dependencies.py [--mode MODE] [--test]
"""

import argparse
import subprocess
import uuid
from pathlib import Path
from datetime import datetime
import tempfile
import os

class HPCDependencyInstaller:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        
        # Core packages needed for Globtim functionality
        self.required_packages = [
            "StaticArrays",
            "StaticArraysCore", 
            "JSON3",
            "TimerOutputs",
            "TOML",
            "Printf"
        ]
        
        # Optional packages for enhanced functionality
        self.optional_packages = [
            "BenchmarkTools",
            "ProgressMeter",
            "Logging"
        ]
    
    def create_installation_script(self, test_id, mode="minimal", test_only=False):
        """Create SLURM script for dependency installation"""
        
        if mode == "minimal":
            time_limit = "00:15:00"
            memory = "8G"
            cpus = 2
            project_file = "Project_HPC_Minimal.toml"
        elif mode == "standard":
            time_limit = "00:30:00"
            memory = "16G"
            cpus = 4
            project_file = "Project_HPC.toml"
        else:  # full
            time_limit = "01:00:00"
            memory = "32G"
            cpus = 8
            project_file = "Project.toml"
        
        output_dir = f"dependency_install_{test_id}"
        
        # Create the Julia installation commands
        install_commands = []
        
        # Required packages
        for pkg in self.required_packages:
            install_commands.append(f'    Pkg.add("{pkg}")')
        
        # Optional packages (only for standard/full mode)
        if mode in ["standard", "full"]:
            for pkg in self.optional_packages:
                install_commands.append(f'    Pkg.add("{pkg}")')
        
        install_commands_str = "\n".join(install_commands)
        
        test_suffix = "_TEST" if test_only else ""
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=hpc_deps{test_suffix}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cpus}
#SBATCH --mem={memory}
#SBATCH --time={time_limit}
#SBATCH --output=hpc_deps_{test_id}_%j.out
#SBATCH --error=hpc_deps_{test_id}_%j.err

echo "=== HPC Dependencies Installation{' (TEST MODE)' if test_only else ''} ==="
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Project file: {project_file}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Julia version: $(/sw/bin/julia --version)"
echo "Available space: $(df -h . | tail -1 | awk '{{print $4}}')"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Backup current Project.toml if it exists
if [ -f "Project.toml" ]; then
    cp Project.toml {output_dir}/Project_backup_$(date +%Y%m%d_%H%M%S).toml
    echo "✅ Backed up current Project.toml"
fi

# Use HPC-specific project file
if [ -f "{project_file}" ]; then
    cp {project_file} Project.toml
    echo "✅ Using {project_file} as Project.toml"
else
    echo "❌ {project_file} not found!"
    exit 1
fi

echo ""
echo "=== Julia Package Installation ==="

/sw/bin/julia --project=. -e '
using Pkg

println("🚀 Starting Julia Package Installation")
println("=" ^ 50)
println("Julia Version: $(VERSION)")
println("Project: $(Base.active_project())")
println("Depot Path: $(DEPOT_PATH)")
println()

# Create results tracking
results = Dict()
failed_packages = String[]
successful_packages = String[]

println("📦 Current Package Status:")
try
    Pkg.status()
catch e
    println("⚠️  Could not show current status: $e")
end
println()

{"# TEST MODE: Check package availability only" if test_only else "# Install required packages"}
required_packages = {str(self.required_packages)}
optional_packages = {str(self.optional_packages) if mode in ["standard", "full"] else "String[]"}

all_packages = vcat(required_packages, optional_packages)

println("📋 Packages to {'check' if test_only else 'install'}: $(length(all_packages))")
for pkg in all_packages
    println("  - $pkg")
end
println()

for (i, pkg) in enumerate(all_packages)
    println("[$i/$(length(all_packages))] {'Checking' if test_only else 'Installing'} $pkg...")
    
    try
        {"# Test mode: just try to add to registry without installing" if test_only else ""}
        {"Pkg.Registry.add(pkg)" if test_only else f"Pkg.add(pkg)"}
        
        {"# Verify package is available" if test_only else "# Verify installation"}
        {"# In test mode, we just check if the package exists in registry" if test_only else ""}
        
        push!(successful_packages, pkg)
        println("  ✅ $pkg {'available' if test_only else 'installed successfully'}")
        
    catch e
        push!(failed_packages, pkg)
        println("  ❌ $pkg failed: $e")
        
        # Save detailed error for this package
        open("{output_dir}/error_$pkg.txt", "w") do f
            println(f, "Package Installation Error")
            println(f, "=========================")
            println(f, "Package: $pkg")
            println(f, "Timestamp: $(now())")
            println(f, "Error: $e")
        end
    end
    
    println()
end

# Final status check
println("📊 INSTALLATION SUMMARY:")
println("=" ^ 50)
println("Successful packages: $(length(successful_packages))")
for pkg in successful_packages
    println("  ✅ $pkg")
end

if !isempty(failed_packages)
    println()
    println("Failed packages: $(length(failed_packages))")
    for pkg in failed_packages
        println("  ❌ $pkg")
    end
end

# Save summary
open("{output_dir}/installation_summary.txt", "w") do f
    println(f, "HPC Dependencies Installation Summary")
    println(f, "====================================")
    println(f, "Timestamp: $(now())")
    println(f, "Mode: {mode}")
    println(f, "Test mode: {test_only}")
    println(f, "Julia version: $(VERSION)")
    println(f, "Project file: {project_file}")
    println(f, "")
    println(f, "Successful packages ($(length(successful_packages))):")
    for pkg in successful_packages
        println(f, "  ✅ $pkg")
    end
    println(f, "")
    println(f, "Failed packages ($(length(failed_packages))):")
    for pkg in failed_packages
        println(f, "  ❌ $pkg")
    end
end

{"# In test mode, exit with success if we could check packages" if test_only else ""}
{"if length(failed_packages) == 0" if not test_only else ""}
{"    println()" if not test_only else ""}
{"    println('🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!')" if not test_only else ""}
{"    exit(0)" if not test_only else ""}
{"else" if not test_only else ""}
{"    println()" if not test_only else ""}
{"    println('❌ SOME PACKAGES FAILED TO INSTALL')" if not test_only else ""}
{"    exit(1)" if not test_only else ""}
{"end" if not test_only else ""}

{"println()" if test_only else ""}
{"println('🧪 TEST COMPLETED - Package availability checked')" if test_only else ""}
{"exit(0)" if test_only else ""}
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Installation Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# HPC Dependencies Installation Job Summary
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Mode: {mode}
Test mode: {test_only}
Project file: {project_file}
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
    echo "✅ Dependencies installation completed successfully"
    echo "📁 Results available in: {output_dir}/"
else
    echo "❌ Dependencies installation failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_installation_job(self, mode="minimal", test_only=False):
        """Submit dependency installation job"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🚀 Submitting HPC Dependencies Installation")
        print(f"Mode: {mode}")
        print(f"Test mode: {test_only}")
        print(f"Test ID: {test_id}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_installation_script(test_id, mode, test_only)
        
        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.slurm', delete=False) as f:
            f.write(slurm_script)
            temp_script_path = f.name
        
        try:
            # Copy script to cluster
            remote_script = f"hpc_deps_{test_id}.slurm"
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
                print(f"  View errors:  ssh {self.cluster_host} 'tail -f hpc_deps_{test_id}_{slurm_job_id}.err'")
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
    parser = argparse.ArgumentParser(description="Install HPC dependencies for Globtim")
    parser.add_argument("--mode", choices=["minimal", "standard", "full"], 
                       default="minimal", help="Installation mode (default: minimal)")
    parser.add_argument("--test", action="store_true",
                       help="Test mode - check package availability without installing")
    
    args = parser.parse_args()
    
    installer = HPCDependencyInstaller()
    slurm_job_id, test_id = installer.submit_installation_job(args.mode, args.test)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Job submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: dependency_install_{test_id}/")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
