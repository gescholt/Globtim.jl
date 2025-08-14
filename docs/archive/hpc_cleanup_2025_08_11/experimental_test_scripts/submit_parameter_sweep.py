#!/usr/bin/env python3

"""
Submit Parameter Sweep Benchmarks

Systematic exploration of parameter space for comprehensive benchmarking.
Uses the dependency-free core Globtim framework.
"""

import subprocess
import uuid
import json
from pathlib import Path
from itertools import product

def create_parameter_sweep_config():
    """Create comprehensive parameter sweep configurations"""
    
    # Define parameter grids
    functions = ["Sphere4D", "Rosenbrock4D", "Rastrigin4D"]
    degrees = [3, 4, 5, 6, 7]
    sample_counts = [50, 100, 200, 300]
    domain_sizes = [1.0, 1.5, 2.0, 2.5, 3.0]
    
    # Create sweep configurations
    sweep_configs = {
        "basic_sweep": {
            "description": "Basic parameter exploration",
            "functions": ["Sphere4D"],
            "degrees": [3, 4, 5],
            "sample_counts": [50, 100],
            "domain_sizes": [1.0, 1.5, 2.0],
            "estimated_jobs": 18,
            "estimated_time": "30 minutes"
        },
        
        "function_comparison": {
            "description": "Compare all functions with standard parameters",
            "functions": functions,
            "degrees": [4, 6],
            "sample_counts": [100, 200],
            "domain_sizes": [1.5, 2.0],
            "estimated_jobs": 24,
            "estimated_time": "45 minutes"
        },
        
        "degree_analysis": {
            "description": "Systematic degree impact analysis",
            "functions": ["Sphere4D", "Rosenbrock4D"],
            "degrees": degrees,
            "sample_counts": [200],
            "domain_sizes": [2.0],
            "estimated_jobs": 10,
            "estimated_time": "25 minutes"
        },
        
        "sample_scaling": {
            "description": "Sample count scaling analysis",
            "functions": ["Sphere4D"],
            "degrees": [4],
            "sample_counts": sample_counts,
            "domain_sizes": [2.0],
            "estimated_jobs": 4,
            "estimated_time": "15 minutes"
        },
        
        "domain_exploration": {
            "description": "Domain size impact analysis",
            "functions": ["Rastrigin4D"],  # Most sensitive to domain size
            "degrees": [5],
            "sample_counts": [200],
            "domain_sizes": domain_sizes,
            "estimated_jobs": 5,
            "estimated_time": "15 minutes"
        },
        
        "comprehensive_sweep": {
            "description": "Full parameter space exploration",
            "functions": functions,
            "degrees": [3, 5, 7],
            "sample_counts": [100, 300],
            "domain_sizes": [1.5, 2.5],
            "estimated_jobs": 36,
            "estimated_time": "90 minutes"
        }
    }
    
    return sweep_configs

def create_sweep_script(sweep_name, config, batch_id):
    """Create SLURM script for parameter sweep"""
    
    script_content = f"""#!/bin/bash
#SBATCH --job-name=sweep_{sweep_name}_{batch_id}
#SBATCH --output=sweep_{sweep_name}_{batch_id}.out
#SBATCH --error=sweep_{sweep_name}_{batch_id}.err
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --partition=batch

echo "🎯 Parameter Sweep: {sweep_name}"
echo "================================="
echo "Description: {config['description']}"
echo "Estimated jobs: {config['estimated_jobs']}"
echo "Estimated time: {config['estimated_time']}"
echo "Batch ID: {batch_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo

# Set up Julia environment
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo

echo "📁 Working directory: $(pwd)"
echo

echo "🚀 Running parameter sweep..."

# Create results directory
mkdir -p sweep_results_{batch_id}

# Run parameter combinations
job_count=0
"""
    
    # Generate all parameter combinations
    for func in config["functions"]:
        for degree in config["degrees"]:
            for sample_count in config["sample_counts"]:
                for domain_size in config["domain_sizes"]:
                    script_content += f"""
echo "📊 Job $((++job_count)): {func} deg={degree} samples={sample_count} domain={domain_size}"
julia parameter_sweep_runner.jl {func} {degree} {sample_count} {domain_size} sweep_results_{batch_id}
echo "✅ Job $job_count completed"
echo
"""
    
    script_content += f"""
echo "🎯 Parameter sweep completed!"
echo "Total jobs: $job_count"
echo "Results directory: sweep_results_{batch_id}"
echo "Finished: $(date)"
"""
    
    script_filename = f"sweep_{sweep_name}_{batch_id}.slurm"
    with open(script_filename, 'w') as f:
        f.write(script_content)
    
    return script_filename

def create_sweep_runner():
    """Create the parameter sweep runner script"""
    
    runner_content = '''#!/usr/bin/env julia

"""
Parameter Sweep Runner

Runs individual parameter combinations for systematic benchmarking.
"""

using Dates
using Printf

# Include our core benchmarking framework
include("core_globtim_benchmarking.jl")

function run_parameter_combination(func_name, degree, sample_count, domain_size, results_dir)
    println("🔬 Testing: $func_name (deg=$degree, samples=$sample_count, domain=$domain_size)")
    
    # Create custom parameter set
    params = Dict(
        "degree" => degree,
        "sample_count" => sample_count,
        "domain_size" => domain_size
    )
    
    # Load function library
    library = create_benchmark_library()
    func_info = library[func_name]
    
    # Create test input
    TR = test_input(
        f = func_info.func,
        dim = func_info.dimension,
        center = func_info.recommended_center,
        sample_range = domain_size,
        degree = degree,
        GN = sample_count
    )
    
    start_time = time()
    
    try
        # Execute core workflow
        pol = construct_polynomial_approximation(TR)
        critical_points = find_critical_points(TR, pol)
        
        if !isempty(critical_points)
            refined_points, converged = refine_critical_points(critical_points, func_info.func)
            minima = [refined_points[i] for i in 1:length(refined_points) if converged[i]]
            
            if !isempty(minima)
                hessian_eigenvals, critical_types = analyze_hessians(minima, func_info.func)
                actual_minima = [minima[i] for i in 1:length(minima) if critical_types[i] == :minimum]
                
                if !isempty(actual_minima)
                    distances_to_global, distances_to_local, recovery_rates = compute_distance_analysis(
                        actual_minima, func_info.global_minima, func_info.local_minima
                    )
                    
                    # Compute metrics
                    function_values = [func_info.func(pt) for pt in actual_minima]
                    
                    # Pass/fail analysis
                    distance_pass = !isempty(distances_to_global) && minimum(distances_to_global) < 0.1
                    l2_pass = pol.nrm < 1e-3
                    recovery_pass = get(recovery_rates, "global", 0.0) >= 0.8
                    
                    overall_pass = distance_pass && l2_pass && recovery_pass
                    quality_score = (distance_pass + l2_pass + get(recovery_rates, "global", 0.0)) / 3
                    
                    # Create result
                    result = Dict(
                        "function_name" => func_name,
                        "parameters" => params,
                        "timestamp" => string(now()),
                        "execution_time" => time() - start_time,
                        "l2_error" => pol.nrm,
                        "condition_number" => pol.cond_vandermonde,
                        "critical_points_found" => length(critical_points),
                        "minima_found" => length(actual_minima),
                        "distances_to_global" => distances_to_global,
                        "recovery_rates" => recovery_rates,
                        "overall_pass" => overall_pass,
                        "quality_score" => quality_score,
                        "distance_pass" => distance_pass,
                        "l2_pass" => l2_pass,
                        "recovery_pass" => recovery_pass
                    )
                    
                    # Save result
                    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
                    filename = "$results_dir/result_$(func_name)_deg$(degree)_s$(sample_count)_d$(domain_size)_$(timestamp).json"
                    
                    open(filename, "w") do f
                        println(f, "{")
                        for (i, (key, val)) in enumerate(result)
                            if isa(val, String)
                                println(f, "  \\"$key\\": \\"$val\\"$(i < length(result) ? "," : "")")
                            elseif isa(val, Vector)
                                println(f, "  \\"$key\\": [$(join(val, ", "))]$(i < length(result) ? "," : "")")
                            elseif isa(val, Dict)
                                println(f, "  \\"$key\\": {")
                                for (j, (k, v)) in enumerate(val)
                                    println(f, "    \\"$k\\": $v$(j < length(val) ? "," : "")")
                                end
                                println(f, "  }$(i < length(result) ? "," : "")")
                            else
                                println(f, "  \\"$key\\": $val$(i < length(result) ? "," : "")")
                            end
                        end
                        println(f, "}")
                    end
                    
                    println("✅ Success: $(overall_pass ? "PASS" : "FAIL") (quality: $(round(quality_score, digits=3)))")
                    return result
                end
            end
        end
        
        # Failure case
        println("❌ Failed: Insufficient critical points")
        return Dict("function_name" => func_name, "parameters" => params, "overall_pass" => false, "quality_score" => 0.0)
        
    catch e
        println("❌ Error: $e")
        return Dict("function_name" => func_name, "parameters" => params, "overall_pass" => false, "quality_score" => 0.0, "error" => string(e))
    end
end

# Main execution
if length(ARGS) >= 5
    func_name = ARGS[1]
    degree = parse(Int, ARGS[2])
    sample_count = parse(Int, ARGS[3])
    domain_size = parse(Float64, ARGS[4])
    results_dir = ARGS[5]
    
    result = run_parameter_combination(func_name, degree, sample_count, domain_size, results_dir)
else
    println("Usage: julia parameter_sweep_runner.jl <function> <degree> <sample_count> <domain_size> <results_dir>")
end
'''
    
    with open("parameter_sweep_runner.jl", 'w') as f:
        f.write(runner_content)

def submit_parameter_sweep(sweep_name):
    """Submit parameter sweep to cluster"""
    
    configs = create_parameter_sweep_config()
    
    if sweep_name not in configs:
        print(f"❌ Unknown sweep: {sweep_name}")
        print(f"Available sweeps: {list(configs.keys())}")
        return
    
    config = configs[sweep_name]
    batch_id = str(uuid.uuid4())[:8]
    
    print(f"🚀 Submitting Parameter Sweep: {sweep_name}")
    print(f"Description: {config['description']}")
    print(f"Estimated jobs: {config['estimated_jobs']}")
    print(f"Estimated time: {config['estimated_time']}")
    print(f"Batch ID: {batch_id}")
    print()
    
    # Create sweep runner
    create_sweep_runner()
    
    # Create SLURM script
    script_file = create_sweep_script(sweep_name, config, batch_id)
    print(f"✅ Created sweep script: {script_file}")
    
    # Upload files to cluster
    print("📤 Uploading files to cluster...")
    files_to_upload = [
        script_file,
        "parameter_sweep_runner.jl",
        "core_globtim_benchmarking.jl"
    ]
    
    for file in files_to_upload:
        if not Path(file).exists():
            print(f"❌ File not found: {file}")
            return
    
    try:
        cmd = ["rsync", "-avz"] + files_to_upload + ["scholten@falcon:~/globtim_hpc/"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("✅ Files uploaded successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Upload failed: {e}")
        return
    
    # Submit job
    print("🚀 Submitting sweep to SLURM...")
    try:
        cmd = ["ssh", "scholten@falcon", f"cd ~/globtim_hpc && sbatch {script_file}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        # Extract job ID from output
        output_lines = result.stdout.strip().split('\\n')
        for line in output_lines:
            if "Submitted batch job" in line:
                slurm_job_id = line.split()[-1]
                print("✅ Parameter sweep submitted successfully!")
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
        Path("parameter_sweep_runner.jl").unlink()
    except:
        pass

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Submit parameter sweep benchmarks")
    parser.add_argument("sweep_name", help="Name of parameter sweep to run")
    parser.add_argument("--list", action="store_true", help="List available sweeps")
    
    args = parser.parse_args()
    
    if args.list:
        configs = create_parameter_sweep_config()
        print("🎯 Available Parameter Sweeps:")
        print("=" * 50)
        for name, config in configs.items():
            print(f"📊 {name}:")
            print(f"   Description: {config['description']}")
            print(f"   Estimated jobs: {config['estimated_jobs']}")
            print(f"   Estimated time: {config['estimated_time']}")
            print()
    else:
        submit_parameter_sweep(args.sweep_name)
