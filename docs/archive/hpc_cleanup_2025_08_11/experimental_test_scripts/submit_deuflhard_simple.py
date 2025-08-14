#!/usr/bin/env python3

"""
Simple Deuflhard Benchmark Submission

Standalone script for submitting Deuflhard benchmark tests without dependencies
on the monitoring system. Creates and submits jobs directly.
"""

import argparse
import subprocess
import json
from pathlib import Path
from datetime import datetime
import uuid
import sys
import os

class SimpleDeuflhardSubmitter:
    def __init__(self, cluster_host="scholten@falcon", remote_dir="~/globtim_hpc"):
        self.cluster_host = cluster_host
        self.remote_dir = remote_dir
        
        # Test configurations
        self.test_modes = {
            "quick": {
                "desc": "Quick test - basic parameters (30 min)",
                "degrees": [4, 6],
                "sample_sizes": [50, 100],
                "time": "00:30:00",
                "mem": "32G",
                "cpus": 12
            },
            "standard": {
                "desc": "Standard test - comprehensive coverage (2 hours)",
                "degrees": [4, 6, 8, 10],
                "sample_sizes": [100, 200],
                "time": "02:00:00",
                "mem": "64G",
                "cpus": 24
            },
            "thorough": {
                "desc": "Thorough test - all combinations (4 hours)",
                "degrees": [4, 6, 8, 10, 12],
                "sample_sizes": [50, 100, 200, 400],
                "time": "04:00:00",
                "mem": "128G",
                "cpus": 24
            }
        }
    
    def create_julia_script(self, mode, job_id):
        """Create Julia script for the benchmark"""
        config = self.test_modes[mode]
        
        return f'''
println("🚀 DEUFLHARD BENCHMARK - MODE: {mode.upper()}")
println("Job ID: {job_id}")

try
    # Use robust package manager for reliable installation
    include("tools/utilities/robust_package_manager.jl")

    # Essential packages for the benchmark
    required_packages = [
        "CSV", "DataFrames", "Parameters", "ForwardDiff",
        "StaticArrays", "Distributions", "TimerOutputs", "TOML",
        "DynamicPolynomials", "MultivariatePolynomials"
    ]

    println("🔧 Ensuring packages are available...")
    robust_package_install(required_packages, verbose=true)

    # Load packages
    using Dates
    using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
    using TimerOutputs, TOML
    using DynamicPolynomials, MultivariatePolynomials
    println("Started: $(now())")
    println("✅ All packages loaded successfully")

    # Import @polyvar macro
    using DynamicPolynomials: @polyvar
    
    # Define PrecisionType enum
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    global _TO = TimerOutputs.TimerOutput()
    
    # Load Globtim modules
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    println("✅ Globtim modules loaded")

    # Test @polyvar macro availability
    @polyvar test_var
    println("✅ @polyvar macro confirmed working")
    
    # Test configuration
    degrees = {config["degrees"]}
    sample_sizes = {config["sample_sizes"]}
    sample_range = 1.2
    precision_types = [Float64Precision, AdaptivePrecision]
    
    println("📋 Configuration: degrees=$degrees, samples=$sample_sizes")
    
    # Results collection
    results = []
    test_count = 0
    total_tests = length(degrees) * length(sample_sizes) * length(precision_types)
    
    println("🧪 Running $total_tests tests...")
    
    for degree in degrees
        for samples in sample_sizes
            for precision_type in precision_types
                test_count += 1
                println("[$test_count/$total_tests] degree=$degree, samples=$samples, precision=$precision_type")
                
                try
                    # Create test input
                    TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], 
                                  sample_range=sample_range, GN=samples, tolerance=nothing)
                    
                    # Polynomial construction
                    start_time = time()
                    pol = Constructor(TR, degree, precision=precision_type, verbose=0)
                    construction_time = time() - start_time
                    
                    # Critical point finding
                    @polyvar x[1:2]
                    crit_start = time()
                    solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
                    df_critical = process_crit_pts(solutions, Deuflhard, TR)
                    df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, TR, enable_hessian=false)
                    crit_time = time() - crit_start
                    
                    # Record result
                    result = Dict(
                        "job_id" => "{job_id}",
                        "mode" => "{mode}",
                        "degree" => degree,
                        "samples" => samples,
                        "precision" => string(precision_type),
                        "construction_time" => construction_time,
                        "l2_error" => pol.nrm,
                        "n_critical" => nrow(df_critical),
                        "n_minima" => nrow(df_min),
                        "critical_time" => crit_time,
                        "timestamp" => string(now())
                    )
                    push!(results, result)
                    
                    println("   ✅ L2=$(@sprintf("%.2e", pol.nrm)), critical=$(nrow(df_critical)), minima=$(nrow(df_min))")
                    
                catch e
                    println("   ❌ Failed: $e")
                end
            end
        end
    end
    
    # Save results
    if !isempty(results)
        results_dir = "deuflhard_results_{job_id}"
        mkpath(results_dir)
        
        df = DataFrame(results)
        CSV.write("$results_dir/results.csv", df)
        
        println("📊 SUMMARY: $(length(results))/$total_tests tests completed")
        println("📁 Results saved to: $results_dir/")
        
        # Quick stats
        if length(results) > 0
            times = [r["construction_time"] for r in results]
            errors = [r["l2_error"] for r in results]
            println("   Construction time: $(@sprintf("%.3f", minimum(times)))-$(@sprintf("%.3f", maximum(times)))s")
            println("   L2 errors: $(@sprintf("%.2e", minimum(errors)))-$(@sprintf("%.2e", maximum(errors)))")
        end
        
        println("🎉 DEUFLHARD BENCHMARK COMPLETED!")
    else
        println("❌ No tests completed")
        exit(1)
    end
    
catch e
    println("❌ Benchmark failed: $e")
    exit(1)
end
'''
    
    def create_slurm_script(self, mode, job_id):
        """Create SLURM job script"""
        config = self.test_modes[mode]
        julia_script = self.create_julia_script(mode, job_id)
        
        return f'''#!/bin/bash
#SBATCH --job-name=deuflhard_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={config["cpus"]}
#SBATCH --mem={config["mem"]}
#SBATCH --time={config["time"]}
#SBATCH --output=deuflhard_{mode}_%j.out
#SBATCH --error=deuflhard_{mode}_%j.err

echo "=== Deuflhard Benchmark - {mode} ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Test ID: {job_id}"
echo "Node: $SLURMD_NODENAME"
echo "Start: $(date)"

export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

cd $HOME/globtim_hpc

/sw/bin/julia --project=. -e '{julia_script}'

echo "End: $(date)"
echo "Duration: $SECONDS seconds"
'''
    
    def submit_job(self, mode):
        """Submit the benchmark job"""
        if mode not in self.test_modes:
            print(f"❌ Unknown mode: {mode}")
            print(f"Available: {list(self.test_modes.keys())}")
            return None
        
        job_id = str(uuid.uuid4())[:8]
        config = self.test_modes[mode]
        
        print(f"🚀 Submitting Deuflhard benchmark - {mode}")
        print(f"Description: {config['desc']}")
        print(f"Test ID: {job_id}")
        print()
        
        # Create SLURM script
        slurm_script = self.create_slurm_script(mode, job_id)
        script_path = f"/tmp/deuflhard_{mode}_{job_id}.slurm"
        
        with open(script_path, 'w') as f:
            f.write(slurm_script)
        
        try:
            # Copy to cluster
            print("📤 Copying job script to cluster...")
            scp_cmd = f"scp {script_path} {self.cluster_host}:/tmp/"
            subprocess.run(scp_cmd, shell=True, check=True, capture_output=True)
            
            # Submit job
            print("🎯 Submitting job...")
            submit_cmd = f'ssh {self.cluster_host} "sbatch /tmp/deuflhard_{mode}_{job_id}.slurm"'
            result = subprocess.run(submit_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                slurm_job_id = result.stdout.strip().split()[-1]
                print(f"✅ Job submitted successfully!")
                print(f"SLURM Job ID: {slurm_job_id}")
                print()
                print("📊 Monitoring commands:")
                print(f"   ssh {self.cluster_host} 'squeue -j {slurm_job_id}'")
                print(f"   ssh {self.cluster_host} 'tail -f deuflhard_{mode}_{slurm_job_id}.out'")
                print()
                print("📁 Results will be in:")
                print(f"   ssh {self.cluster_host} 'ls ~/globtim_hpc/deuflhard_results_{job_id}/'")
                
                return slurm_job_id, job_id
            else:
                print(f"❌ Job submission failed: {result.stderr}")
                return None, None
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return None, None
        finally:
            if os.path.exists(script_path):
                os.remove(script_path)

def main():
    parser = argparse.ArgumentParser(description="Submit Deuflhard benchmark tests (simple version)")
    parser.add_argument("--mode", choices=["quick", "standard", "thorough"], 
                       default="standard", help="Test mode")
    parser.add_argument("--list", action="store_true", help="List available modes")
    
    args = parser.parse_args()
    
    submitter = SimpleDeuflhardSubmitter()
    
    if args.list:
        print("Available test modes:")
        for mode, config in submitter.test_modes.items():
            print(f"  {mode}: {config['desc']}")
            print(f"    Degrees: {config['degrees']}")
            print(f"    Samples: {config['sample_sizes']}")
            print(f"    Time: {config['time']}, Memory: {config['mem']}")
            print()
        return
    
    # Submit job
    slurm_job_id, test_id = submitter.submit_job(args.mode)
    
    if slurm_job_id:
        print("🎉 Job submitted successfully!")
        print("Use the monitoring commands above to track progress.")

if __name__ == "__main__":
    main()
