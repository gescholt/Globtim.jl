#!/usr/bin/env python3

"""
Globtim Compilation Test Submission Script
==========================================

Tests basic Globtim functionality on the HPC cluster using the validated
input/output infrastructure from the basic test.

Usage:
    python submit_globtim_compilation_test.py [--mode MODE] [--function FUNC]
"""

import argparse
import subprocess
import uuid
from pathlib import Path
from datetime import datetime
import tempfile
import os

class GlobtimCompilationTestSubmitter:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        
        # Available test functions
        self.test_functions = {
            "sphere": {
                "name": "Sphere",
                "dim": 2,
                "center": [0.0, 0.0],
                "sample_range": 2.0,
                "description": "Simple bowl-shaped function"
            },
            "rosenbrock": {
                "name": "Rosenbrock", 
                "dim": 2,
                "center": [1.0, 1.0],
                "sample_range": 2.0,
                "description": "Classic banana function"
            },
            "deuflhard": {
                "name": "Deuflhard",
                "dim": 2, 
                "center": [0.0, 0.0],
                "sample_range": 1.5,
                "description": "Deuflhard benchmark function"
            }
        }
    
    def create_slurm_script(self, test_id, mode="quick", function="sphere"):
        """Create SLURM job script for Globtim compilation test"""
        
        # Configuration based on mode
        if mode == "quick":
            time_limit = "00:10:00"
            memory = "8G"
            cpus = 4
            degree = 4
            samples = 50
        elif mode == "standard":
            time_limit = "00:20:00"
            memory = "16G"
            cpus = 8
            degree = 6
            samples = 100
        else:  # extended
            time_limit = "00:30:00"
            memory = "32G"
            cpus = 12
            degree = 8
            samples = 200
        
        func_config = self.test_functions[function]
        output_dir = f"globtim_compilation_test_{test_id}"
        
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=globtim_comp_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cpus}
#SBATCH --mem={memory}
#SBATCH --time={time_limit}
#SBATCH --output=globtim_comp_{test_id}_%j.out
#SBATCH --error=globtim_comp_{test_id}_%j.err

echo "=== Globtim Compilation Test - {mode.upper()} MODE ==="
echo "Test ID: {test_id}"
echo "Function: {func_config['name']}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Available space: $(df -h . | tail -1 | awk '{{print $4}}')"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create input configuration
cat > {output_dir}/input_config.txt << 'EOF'
# Globtim Compilation Test Configuration
test_id: {test_id}
timestamp: $(date -Iseconds)
test_type: globtim_compilation
slurm_job_id: $SLURM_JOB_ID
function_name: {func_config['name']}
dimension: {func_config['dim']}
center: {func_config['center']}
sample_range: {func_config['sample_range']}
degree: {degree}
samples: {samples}
mode: {mode}
cpus: {cpus}
memory: {memory}
time_limit: {time_limit}
EOF

echo "✅ Input configuration created"

# Run the Globtim compilation test
echo ""
echo "=== Running Globtim Compilation Test ==="
/sw/bin/julia -e '
using Dates

println("🚀 Globtim Compilation Test Starting")
println("=" ^ 50)
println("Julia Version: $(VERSION)")
println("Start Time: $(now())")
println("Hostname: $(gethostname())")
println("Working Directory: $(pwd())")
println("Available Threads: $(Threads.nthreads())")
println()

output_dir = "{output_dir}"
function_name = "{func_config["name"]}"
dimension = {func_config["dim"]}
center = {func_config["center"]}
sample_range = {func_config["sample_range"]}
degree = {degree}
samples = {samples}

println("📋 Test Configuration:")
println("  Function: $function_name")
println("  Dimension: $dimension")
println("  Center: $center")
println("  Sample range: $sample_range")
println("  Degree: $degree")
println("  Samples: $samples")
println("  Output directory: $output_dir")
println()

# Test 1: Basic module loading
println("📦 Test 1: Module Loading")
try
    # Test basic Julia packages first
    using LinearAlgebra
    println("  ✅ LinearAlgebra loaded")
    
    using Statistics
    println("  ✅ Statistics loaded")
    
    # Try to load Globtim modules
    include("src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl") 
    println("  ✅ LibFunctions.jl loaded")
    
    include("src/Samples.jl")
    println("  ✅ Samples.jl loaded")
    
    include("src/Structures.jl")
    println("  ✅ Structures.jl loaded")
    
    # Save module loading results
    open(joinpath(output_dir, "module_loading_results.txt"), "w") do f
        println(f, "Module Loading Test Results")
        println(f, "===========================")
        println(f, "Timestamp: $(now())")
        println(f, "Julia Version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
        println(f, "")
        println(f, "Successfully loaded modules:")
        println(f, "- LinearAlgebra")
        println(f, "- Statistics") 
        println(f, "- BenchmarkFunctions.jl")
        println(f, "- LibFunctions.jl")
        println(f, "- Samples.jl")
        println(f, "- Structures.jl")
    end
    
    println("  ✅ Module loading test completed successfully")
    
catch e
    println("  ❌ Module loading failed: $e")
    
    # Save error info
    open(joinpath(output_dir, "module_loading_error.txt"), "w") do f
        println(f, "Module Loading Error")
        println(f, "===================")
        println(f, "Timestamp: $(now())")
        println(f, "Error: $e")
    end
    
    exit(1)
end

println()

# Test 2: Function evaluation
println("🧮 Test 2: Function Evaluation")
try
    # Get the function
    test_func = eval(Symbol(function_name))
    
    # Test function evaluation at center
    test_point = center
    func_value = test_func(test_point)
    
    println("  ✅ Function $function_name evaluated at $test_point")
    println("  ✅ Function value: $func_value")
    
    # Test function evaluation at a few random points
    test_results = []
    for i in 1:5
        random_point = center .+ (rand(dimension) .- 0.5) .* sample_range
        value = test_func(random_point)
        push!(test_results, (random_point, value))
        println("  ✅ f($random_point) = $value")
    end
    
    # Save function evaluation results
    open(joinpath(output_dir, "function_evaluation_results.txt"), "w") do f
        println(f, "Function Evaluation Test Results")
        println(f, "===============================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Dimension: $dimension")
        println(f, "")
        println(f, "Function value at center $center: $func_value")
        println(f, "")
        println(f, "Random point evaluations:")
        for (i, (point, value)) in enumerate(test_results)
            println(f, "  Point $i: $point -> $value")
        end
    end
    
    println("  ✅ Function evaluation test completed successfully")
    
catch e
    println("  ❌ Function evaluation failed: $e")
    
    # Save error info
    open(joinpath(output_dir, "function_evaluation_error.txt"), "w") do f
        println(f, "Function Evaluation Error")
        println(f, "========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Error: $e")
    end
    
    exit(1)
end

println()

# Test 3: Basic test_input creation (if possible)
println("🔧 Test 3: Test Input Creation")
try
    test_func = eval(Symbol(function_name))
    
    # Try to create test input
    TR = test_input(test_func, 
                   dim=dimension,
                   center=center,
                   sample_range=sample_range,
                   GN=samples)
    
    println("  ✅ test_input created successfully")
    println("  ✅ Sample count: $(length(TR.sample_points))")
    println("  ✅ Function values computed: $(length(TR.function_values))")
    
    # Save test input results
    open(joinpath(output_dir, "test_input_results.txt"), "w") do f
        println(f, "Test Input Creation Results")
        println(f, "==========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Dimension: $dimension")
        println(f, "Center: $center")
        println(f, "Sample range: $sample_range")
        println(f, "Number of samples: $samples")
        println(f, "")
        println(f, "Results:")
        println(f, "Sample points generated: $(length(TR.sample_points))")
        println(f, "Function values computed: $(length(TR.function_values))")
        println(f, "Min function value: $(minimum(TR.function_values))")
        println(f, "Max function value: $(maximum(TR.function_values))")
        println(f, "Mean function value: $(sum(TR.function_values) / length(TR.function_values))")
    end
    
    println("  ✅ Test input creation completed successfully")
    
catch e
    println("  ❌ Test input creation failed: $e")
    
    # Save error info  
    open(joinpath(output_dir, "test_input_error.txt"), "w") do f
        println(f, "Test Input Creation Error")
        println(f, "========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Error: $e")
    end
    
    # This is not a fatal error for compilation test
    println("  ⚠️  Continuing despite test_input failure...")
end

println()
println("🎉 GLOBTIM COMPILATION TEST COMPLETED!")
println("End Time: $(now())")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Globtim Compilation Test Job Summary
Test ID: {test_id}
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Function: {func_config['name']}
Mode: {mode}
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
    echo "✅ Globtim compilation test completed successfully"
    echo "📁 Results available in: {output_dir}/"
else
    echo "❌ Globtim compilation test failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
"""
        
        return slurm_script
    
    def submit_job(self, mode="quick", function="sphere"):
        """Submit the Globtim compilation test job"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🚀 Submitting Globtim Compilation Test")
        print(f"Mode: {mode}")
        print(f"Function: {self.test_functions[function]['name']} ({self.test_functions[function]['description']})")
        print(f"Test ID: {test_id}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_slurm_script(test_id, mode, function)
        
        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.slurm', delete=False) as f:
            f.write(slurm_script)
            temp_script_path = f.name
        
        try:
            # Copy script to cluster
            remote_script = f"globtim_comp_{test_id}.slurm"
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
                print(f"  View output:  ssh {self.cluster_host} 'tail -f globtim_comp_{test_id}_{slurm_job_id}.out'")
                print(f"  View errors:  ssh {self.cluster_host} 'tail -f globtim_comp_{test_id}_{slurm_job_id}.err'")
                print(f"  Results dir:  ssh {self.cluster_host} 'ls -la {self.remote_dir}/globtim_compilation_test_{test_id}/'")
                
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
    parser = argparse.ArgumentParser(description="Submit Globtim compilation test to HPC cluster")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"], 
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--function", choices=["sphere", "rosenbrock", "deuflhard"],
                       default="sphere", help="Test function (default: sphere)")
    parser.add_argument("--list-functions", action="store_true",
                       help="List available test functions")
    
    args = parser.parse_args()
    
    submitter = GlobtimCompilationTestSubmitter()
    
    if args.list_functions:
        print("Available test functions:")
        for key, config in submitter.test_functions.items():
            print(f"  {key}: {config['name']} - {config['description']}")
            print(f"    Dimension: {config['dim']}, Center: {config['center']}, Range: {config['sample_range']}")
        return
    
    slurm_job_id, test_id = submitter.submit_job(args.mode, args.function)
    
    if slurm_job_id:
        print(f"\n🎯 SUCCESS! Job submitted with ID: {slurm_job_id}")
        print(f"📁 Results will be in: globtim_compilation_test_{test_id}/")
    else:
        print(f"\n❌ FAILED! Job submission unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
