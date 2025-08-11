#!/usr/bin/env python3

"""
HPC Dependencies Installation - Quota Workaround
================================================

Installs Julia packages using alternative storage locations to bypass
home directory quota limits (Error -122: EDQUOT).

Root Cause: User has hit 1GB home directory quota, preventing package installation.
Solution: Use /tmp or /lustre storage for Julia depot.

Usage:
    python install_deps_quota_workaround.py [--storage-type TYPE]
"""

import argparse
import subprocess
import uuid
import tempfile
import os

class QuotaWorkaroundInstaller:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        
        # Storage options (in order of preference)
        self.storage_options = {
            "tmp": {
                "path": "/tmp/julia_depot_scholten",
                "description": "Local /tmp storage (99GB available)",
                "cleanup": True
            },
            "lustre": {
                "path": "/lustre/scholten_julia_depot",
                "description": "Lustre filesystem (1.1PB available)", 
                "cleanup": False
            },
            "scratch": {
                "path": "/scratch/scholten_julia_depot",
                "description": "Scratch filesystem (if available)",
                "cleanup": True
            }
        }
    
    def create_installation_script(self, test_id, storage_type="tmp"):
        """Create SLURM script with quota workaround"""
        
        storage_config = self.storage_options[storage_type]
        depot_path = storage_config["path"]
        
        output_dir = f"quota_workaround_install_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=quota_workaround
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=quota_workaround_{test_id}_%j.out
#SBATCH --error=quota_workaround_{test_id}_%j.err

echo "=== HPC Dependencies Installation - Quota Workaround ==="
echo "Test ID: {test_id}"
echo "Storage type: {storage_type}"
echo "Depot path: {depot_path}"
echo "Job ID: $SLURM_JOB_ID"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
cd $HOME/globtim_hpc

echo "=== Quota Analysis ==="
echo "Home directory quota status:"
quota -u scholten 2>/dev/null || echo "Quota command not available"
echo ""
echo "Home directory usage:"
du -sh ~/.julia 2>/dev/null || echo "No ~/.julia directory"
echo ""
echo "Available storage:"
df -h {depot_path.split('/')[1] if depot_path.startswith('/') else '/tmp'} | tail -1
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

echo "=== Setting Up Alternative Julia Depot ==="

# Create alternative depot directory
DEPOT_PATH="{depot_path}"
mkdir -p "$DEPOT_PATH"
echo "✅ Created depot directory: $DEPOT_PATH"

# Set Julia depot path to bypass home directory quota
export JULIA_DEPOT_PATH="$DEPOT_PATH:$JULIA_DEPOT_PATH"
echo "✅ Julia depot path set to: $JULIA_DEPOT_PATH"

# Verify depot is writable
touch "$DEPOT_PATH/test_write" && rm "$DEPOT_PATH/test_write"
if [ $? -eq 0 ]; then
    echo "✅ Depot directory is writable"
else
    echo "❌ Depot directory is not writable"
    exit 1
fi

echo ""
echo "=== Installing Packages with Alternative Depot ==="

/sw/bin/julia -e '
using Pkg

println("🚀 Installing Dependencies with Quota Workaround")
println("Julia Version: $(VERSION)")
println("Depot paths:")
for (i, path) in enumerate(DEPOT_PATH)
    println("  $i: $path")
end
println()

# Check depot writability
depot_path = DEPOT_PATH[1]
println("Primary depot: $depot_path")

try
    # Test depot writability
    test_file = joinpath(depot_path, "test_write.txt")
    open(test_file, "w") do f
        println(f, "test")
    end
    rm(test_file)
    println("✅ Depot is writable")
catch e
    println("❌ Depot write test failed: $e")
    exit(1)
end

println()

# Install packages one by one
packages = ["StaticArrays", "JSON3", "TimerOutputs", "TOML"]
successful = String[]
failed = String[]

for pkg in packages
    println("Installing $pkg to alternative depot...")
    try
        Pkg.add(pkg)
        
        # Verify installation by trying to load
        eval(Meta.parse("using $pkg"))
        
        push!(successful, pkg)
        println("  ✅ $pkg installed and verified successfully")
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

# Save depot information for future use
depot_info = Dict(
    "depot_path" => depot_path,
    "successful_packages" => successful,
    "failed_packages" => failed,
    "julia_version" => string(VERSION),
    "timestamp" => string(now())
)

open("{output_dir}/depot_info.txt", "w") do f
    println(f, "Alternative Julia Depot Information")
    println(f, "===================================")
    println(f, "Depot path: $(depot_info["depot_path"])")
    println(f, "Julia version: $(depot_info["julia_version"])")
    println(f, "Timestamp: $(depot_info["timestamp"])")
    println(f, "")
    println(f, "Successful packages:")
    for pkg in depot_info["successful_packages"]
        println(f, "  ✅ $pkg")
    end
    println(f, "")
    println(f, "Failed packages:")
    for pkg in depot_info["failed_packages"]
        println(f, "  ❌ $pkg")
    end
    println(f, "")
    println(f, "Usage Instructions:")
    println(f, "export JULIA_DEPOT_PATH=\"$(depot_info["depot_path"]):\$JULIA_DEPOT_PATH\"")
    println(f, "/sw/bin/julia --project=.")
end

if isempty(failed)
    println("🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!")
    exit(0)
else
    println("⚠️  SOME PACKAGES FAILED")
    exit(1)
end
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Testing Globtim Module Loading ==="

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "Testing Globtim modules with new depot..."
    /sw/bin/julia -e '
    try
        include("src/BenchmarkFunctions.jl")
        println("✅ BenchmarkFunctions.jl loaded successfully")
        
        # Test a simple function
        result = Sphere([0.0, 0.0])
        println("✅ Sphere function test: f([0,0]) = $result")
        
        open("{output_dir}/globtim_test_success.txt", "w") do f
            println(f, "Globtim Module Test - SUCCESS")
            println(f, "=============================")
            println(f, "BenchmarkFunctions.jl loaded successfully")
            println(f, "Sphere function test result: $result")
            println(f, "Timestamp: $(now())")
        end
        
    catch e
        println("❌ Globtim module loading failed: $e")
        
        open("{output_dir}/globtim_test_error.txt", "w") do f
            println(f, "Globtim Module Test - ERROR")
            println(f, "===========================")
            println(f, "Error: $e")
            println(f, "Timestamp: $(now())")
        end
    end
    '
fi

echo ""
echo "=== Final Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create usage instructions
cat > {output_dir}/usage_instructions.txt << EOF
# How to Use the Alternative Julia Depot

## Problem Solved
- Home directory quota exceeded (1GB limit reached)
- Error -122 (EDQUOT) prevented package installation
- Solution: Use alternative depot in {depot_path}

## Usage Instructions

### For SLURM Jobs:
Add to your job script:
export JULIA_DEPOT_PATH="{depot_path}:\$JULIA_DEPOT_PATH"
/sw/bin/julia --project=.

### For Interactive Sessions:
ssh scholten@falcon
export JULIA_DEPOT_PATH="{depot_path}:\$JULIA_DEPOT_PATH"
cd ~/globtim_hpc
/sw/bin/julia --project=.

### Verification:
julia> println(DEPOT_PATH[1])
Should show: {depot_path}

## Cleanup {'(Automatic)' if storage_config['cleanup'] else '(Manual)'}
{f"Files in {depot_path} will be cleaned up automatically" if storage_config['cleanup'] else f"Files in {depot_path} persist across sessions"}

## Storage Details
- Type: {storage_type}
- Path: {depot_path}  
- Description: {storage_config['description']}
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Quota workaround installation completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Usage instructions: {output_dir}/usage_instructions.txt"
else
    echo "❌ Installation failed"
fi

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, storage_type="tmp"):
        """Submit quota workaround installation job"""
        test_id = str(uuid.uuid4())[:8]
        
        if storage_type not in self.storage_options:
            print(f"❌ Invalid storage type: {storage_type}")
            print(f"Available options: {list(self.storage_options.keys())}")
            return None, None
        
        storage_config = self.storage_options[storage_type]
        
        print(f"🚀 Submitting Quota Workaround Installation")
        print(f"Storage type: {storage_type}")
        print(f"Storage path: {storage_config['path']}")
        print(f"Description: {storage_config['description']}")
        print(f"Test ID: {test_id}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_installation_script(test_id, storage_type)
        
        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.slurm', delete=False) as f:
            f.write(slurm_script)
            temp_script_path = f.name
        
        try:
            # Copy script to cluster
            remote_script = f"quota_workaround_{test_id}.slurm"
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
                print(f"  View output:  ssh {self.cluster_host} 'tail -f quota_workaround_{test_id}_{slurm_job_id}.out'")
                print(f"  Results dir:  ssh {self.cluster_host} 'ls -la {self.remote_dir}/quota_workaround_install_{test_id}/'")
                print()
                print("🤖 Automated Monitoring:")
                print(f"  python automated_job_monitor.py --job-id {slurm_job_id} --test-id {test_id}")
                
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
    parser = argparse.ArgumentParser(description="Install HPC dependencies with quota workaround")
    parser.add_argument("--storage-type", choices=["tmp", "lustre", "scratch"], 
                       default="tmp", help="Storage type for Julia depot (default: tmp)")
    parser.add_argument("--list-storage", action="store_true",
                       help="List available storage options")
    
    args = parser.parse_args()
    
    installer = QuotaWorkaroundInstaller()
    
    if args.list_storage:
        print("Available storage options:")
        for key, config in installer.storage_options.items():
            print(f"  {key}: {config['description']}")
            print(f"    Path: {config['path']}")
            print(f"    Cleanup: {'Yes' if config['cleanup'] else 'No'}")
        return
    
    slurm_job_id, test_id = installer.submit_job(args.storage_type)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Job submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: quota_workaround_install_{test_id}/")
        print(f"\n💡 This workaround bypasses the home directory quota limit")
        print(f"📋 Usage instructions will be provided in the results")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
