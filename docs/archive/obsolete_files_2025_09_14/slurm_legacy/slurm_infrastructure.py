#!/usr/bin/env python3

"""
SLURM Infrastructure - Technical Code Separation
===============================================

This module provides clean separation between SLURM technical infrastructure
and actual test/benchmark code. It handles all SLURM-related functionality
in a reusable, modular way.

Usage:
    from slurm_infrastructure import SLURMJobManager
    
    manager = SLURMJobManager()
    job_id = manager.submit_job(script_content, job_name="my_test")
"""

import subprocess
import uuid
import os
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import json

class SLURMJobManager:
    """Handles all SLURM job submission and management"""
    
    def __init__(self, fileserver_host="scholten@mack", cluster_host="scholten@falcon"):
        self.fileserver_host = fileserver_host
        self.cluster_host = cluster_host
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
        
        # Standard SLURM configurations
        self.standard_configs = {
            "quick": {
                "time_limit": "00:30:00",
                "memory": "8G",
                "cpus": 4,
                "partition": "batch"
            },
            "standard": {
                "time_limit": "02:00:00", 
                "memory": "16G",
                "cpus": 8,
                "partition": "batch"
            },
            "extended": {
                "time_limit": "04:00:00",
                "memory": "32G",
                "cpus": 16,
                "partition": "batch"
            },
            "bigmem": {
                "time_limit": "08:00:00",
                "memory": "64G",
                "cpus": 8,
                "partition": "bigmem"
            }
        }
    
    def create_slurm_header(self, job_name: str, config: Dict, output_dir: str) -> str:
        """Create standardized SLURM header"""
        return f"""#!/bin/bash
#SBATCH --job-name={job_name}
#SBATCH --partition={config['partition']}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={config['cpus']}
#SBATCH --mem={config['memory']}
#SBATCH --time={config['time_limit']}
#SBATCH --output={output_dir}/job_%j.out
#SBATCH --error={output_dir}/job_%j.err

echo "=== SLURM Job Information ==="
echo "Job Name: {job_name}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Partition: {config['partition']}"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"

# Change to working directory
cd {self.remote_dir}

echo "=== Environment ==="
echo "Working directory: $(pwd)"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""
"""
    
    def create_slurm_footer(self, output_dir: str) -> str:
        """Create standardized SLURM footer"""
        return f"""
echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Exit code: $?"

# Create job summary
cat > {output_dir}/slurm_job_summary.txt << EOF
# SLURM Job Summary
Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Start Time: $(date)
Duration: $SECONDS seconds
Exit Code: $?
CPUs: $SLURM_CPUS_PER_TASK
Memory: $SLURM_MEM_PER_NODE MB
Working Directory: $(pwd)
Julia Depot: $JULIA_DEPOT_PATH

# Generated Files:
$(ls -la {output_dir}/)
EOF

echo "✅ Job completed"
"""
    
    def submit_job(self, 
                   job_content: str, 
                   job_name: str,
                   config_name: str = "quick",
                   custom_config: Optional[Dict] = None) -> Tuple[Optional[str], str]:
        """
        Submit a job to SLURM
        
        Args:
            job_content: The main job content (Julia code, shell commands, etc.)
            job_name: Name for the SLURM job
            config_name: Standard config to use ("quick", "standard", "extended", "bigmem")
            custom_config: Custom configuration to override standard config
            
        Returns:
            Tuple of (slurm_job_id, test_id) or (None, test_id) if failed
        """
        test_id = str(uuid.uuid4())[:8]
        
        # Get configuration
        if custom_config:
            config = custom_config
        elif config_name in self.standard_configs:
            config = self.standard_configs[config_name]
        else:
            print(f"❌ Invalid config: {config_name}")
            return None, test_id
        
        # Create output directory
        output_dir = f"results/{job_name}_{test_id}"
        
        print(f"🚀 Submitting SLURM Job")
        print(f"Job Name: {job_name}")
        print(f"Test ID: {test_id}")
        print(f"Config: {config_name}")
        print(f"Resources: {config['cpus']} CPUs, {config['memory']} memory, {config['time_limit']}")
        print()
        
        try:
            # Create output directory
            print("📁 Creating output directory...")
            mkdir_cmd = f"ssh {self.fileserver_host} 'cd {self.remote_dir} && mkdir -p {output_dir}'"
            result = subprocess.run(mkdir_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Failed to create output directory: {result.stderr}")
                return None, test_id
            
            # Create complete SLURM script
            slurm_script = (
                self.create_slurm_header(job_name, config, output_dir) +
                "\n# === USER JOB CONTENT ===\n" +
                job_content +
                "\n# === SLURM FOOTER ===\n" +
                self.create_slurm_footer(output_dir)
            )
            
            # Submit job using /tmp for script (quota workaround)
            remote_script = f"/tmp/{job_name}_{test_id}.slurm"
            
            print("📤 Submitting job...")
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
                print(f"📁 Results will be in: {output_dir}/")
                print()
                
                print("📊 Monitoring Commands:")
                print(f"  Check status: ssh {self.fileserver_host} 'squeue -j {slurm_job_id}'")
                print(f"  View output:  ssh {self.fileserver_host} 'tail -f {self.remote_dir}/{output_dir}/job_{slurm_job_id}.out'")
                print(f"  Results dir:  ssh {self.fileserver_host} 'ls -la {self.remote_dir}/{output_dir}/'")
                
                return slurm_job_id, test_id
            else:
                print(f"❌ Job submission failed: {result.stderr}")
                return None, test_id
                
        except subprocess.TimeoutExpired:
            print("❌ Job submission timed out")
            return None, test_id
        except Exception as e:
            print(f"❌ Error during submission: {e}")
            return None, test_id
    
    def monitor_job(self, job_id: str, interval: int = 15) -> str:
        """Monitor job status"""
        monitor_cmd = f"ssh {self.fileserver_host} 'squeue -j {job_id}'"
        result = subprocess.run(monitor_cmd, shell=True, capture_output=True, text=True)
        return result.stdout
    
    def get_job_output(self, job_id: str, output_dir: str) -> Tuple[str, str]:
        """Get job output and error files"""
        out_cmd = f"ssh {self.fileserver_host} 'cat {self.remote_dir}/{output_dir}/job_{job_id}.out'"
        err_cmd = f"ssh {self.fileserver_host} 'cat {self.remote_dir}/{output_dir}/job_{job_id}.err'"
        
        out_result = subprocess.run(out_cmd, shell=True, capture_output=True, text=True)
        err_result = subprocess.run(err_cmd, shell=True, capture_output=True, text=True)
        
        return out_result.stdout, err_result.stdout


class TestJobBuilder:
    """Builds specific types of test jobs using the SLURM infrastructure"""
    
    def __init__(self, slurm_manager: SLURMJobManager):
        self.slurm = slurm_manager
    
    def create_julia_test_job(self, 
                             julia_code: str, 
                             job_name: str,
                             packages: List[str] = None,
                             modules: List[str] = None) -> str:
        """Create a Julia test job with package loading and module includes"""
        
        packages = packages or ["StaticArrays", "LinearAlgebra"]
        modules = modules or []
        
        # Create package loading section
        package_loading = ""
        if packages:
            package_loading = f"""
echo "📦 Loading Julia Packages..."
/sw/bin/julia -e '
packages = {packages}
for pkg in packages
    try
        eval(Meta.parse("using $pkg"))
        println("✅ $pkg loaded successfully")
    catch e
        println("❌ $pkg failed to load: $e")
        exit(1)
    end
end
println("✅ All packages loaded")
'
"""
        
        # Create module loading section
        module_loading = ""
        if modules:
            module_includes = "\n".join([f'include("{mod}")' for mod in modules])
            module_loading = f"""
echo "🧮 Loading Globtim Modules..."
/sw/bin/julia -e '
try
{module_includes}
    println("✅ All modules loaded successfully")
catch e
    println("❌ Module loading failed: $e")
    exit(1)
end
'
"""
        
        # Combine all sections
        job_content = f"""
echo "=== Julia Test Job: {job_name} ==="
{package_loading}
{module_loading}

echo "🚀 Running Julia Test..."
/sw/bin/julia -e '
{julia_code}
'

JULIA_EXIT_CODE=$?
echo "Julia exit code: $JULIA_EXIT_CODE"
exit $JULIA_EXIT_CODE
"""
        
        return job_content
    
    def submit_deuflhard_test(self, config_name: str = "quick") -> Tuple[Optional[str], str]:
        """Submit a Deuflhard benchmark test"""
        
        julia_code = '''
println("🧮 Deuflhard Benchmark Test")
println("Julia Version: ", VERSION)
println("Hostname: ", gethostname())
println()

# Load required modules
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")
println("✅ Globtim modules loaded")

# Test Deuflhard function
test_points = [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0], [-0.5, 0.5]]

println("🧮 Testing Deuflhard Function:")
for (i, point) in enumerate(test_points)
    value = Deuflhard(point)
    println("  $i: f($point) = $value")
end

println("✅ Deuflhard test completed successfully")
'''
        
        job_content = self.create_julia_test_job(
            julia_code=julia_code,
            job_name="deuflhard_test",
            packages=["StaticArrays", "LinearAlgebra"],
            modules=[]  # Modules loaded directly in Julia code
        )
        
        return self.slurm.submit_job(job_content, "deuflhard_test", config_name)
    
    def submit_basic_test(self, config_name: str = "quick") -> Tuple[Optional[str], str]:
        """Submit a basic functionality test"""
        
        julia_code = '''
println("🧮 Basic Functionality Test")
println("Julia Version: ", VERSION)
println("Hostname: ", gethostname())
println()

# Test basic math
x = rand(100)
y = sin.(x)
z = sum(y)
println("✅ Basic math test: sum = $z")

# Test StaticArrays
using StaticArrays
v = SVector(1.0, 2.0, 3.0)
println("✅ StaticArrays test: $v")

println("✅ Basic test completed successfully")
'''
        
        job_content = self.create_julia_test_job(
            julia_code=julia_code,
            job_name="basic_test",
            packages=["StaticArrays", "LinearAlgebra"]
        )
        
        return self.slurm.submit_job(job_content, "basic_test", config_name)


# Convenience functions for easy usage
def submit_deuflhard_test(config: str = "quick") -> Tuple[Optional[str], str]:
    """Quick function to submit Deuflhard test"""
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    return builder.submit_deuflhard_test(config)

def submit_basic_test(config: str = "quick") -> Tuple[Optional[str], str]:
    """Quick function to submit basic test"""
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    return builder.submit_basic_test(config)

def submit_custom_julia_job(julia_code: str, job_name: str, config: str = "quick") -> Tuple[Optional[str], str]:
    """Quick function to submit custom Julia job"""
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    job_content = builder.create_julia_test_job(julia_code, job_name)
    return manager.submit_job(job_content, job_name, config)


if __name__ == "__main__":
    # Example usage
    print("SLURM Infrastructure Module")
    print("Available functions:")
    print("  - submit_deuflhard_test()")
    print("  - submit_basic_test()")
    print("  - submit_custom_julia_job()")
    print()
    print("Example:")
    print("  from slurm_infrastructure import submit_deuflhard_test")
    print("  job_id, test_id = submit_deuflhard_test('quick')")
