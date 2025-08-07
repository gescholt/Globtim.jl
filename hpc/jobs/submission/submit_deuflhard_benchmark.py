#!/usr/bin/env python3

"""
Deuflhard Benchmark Test Submission

Integrates with existing HPC infrastructure to submit comprehensive Deuflhard
polynomial construction and critical point finding tests.

Uses existing monitoring and job management systems.
"""

import argparse
import subprocess
import json
from pathlib import Path
from datetime import datetime
import uuid
import sys
import os

# Add monitoring to path - handle both relative and absolute paths
script_dir = Path(__file__).parent
monitoring_dir = script_dir.parent.parent / "monitoring" / "python"

# Try to add monitoring directory to path
if monitoring_dir.exists():
    sys.path.insert(0, str(monitoring_dir))
    try:
        from slurm_monitor import SlurmMonitor
        MONITORING_AVAILABLE = True
    except ImportError:
        print("⚠️  Warning: Could not import SlurmMonitor, monitoring will be limited")
        MONITORING_AVAILABLE = False
        SlurmMonitor = None
else:
    print("⚠️  Warning: Monitoring directory not found, monitoring will be limited")
    MONITORING_AVAILABLE = False
    SlurmMonitor = None

class DeuflhardBenchmarkSubmitter:
    def __init__(self, cluster_host="scholten@falcon", remote_dir="~/globtim_hpc"):
        self.cluster_host = cluster_host
        self.remote_dir = remote_dir
        self.monitor = SlurmMonitor(cluster_host, remote_dir) if MONITORING_AVAILABLE else None
        
        # Test configurations
        self.test_modes = {
            "quick": {
                "desc": "Quick test - basic parameters",
                "degrees": [4, 6],
                "sample_sizes": [50, 100],
                "sample_ranges": [1.2],
                "precision_types": ["Float64Precision"],
                "time": "00:30:00",
                "mem": "32G",
                "cpus": 12
            },
            "standard": {
                "desc": "Standard test - comprehensive coverage",
                "degrees": [4, 6, 8, 10],
                "sample_sizes": [100, 200],
                "sample_ranges": [1.2],
                "precision_types": ["Float64Precision", "AdaptivePrecision"],
                "time": "02:00:00",
                "mem": "64G",
                "cpus": 24
            },
            "thorough": {
                "desc": "Thorough test - all parameter combinations",
                "degrees": [4, 6, 8, 10, 12],
                "sample_sizes": [50, 100, 200, 400],
                "sample_ranges": [1.0, 1.2, 1.5],
                "precision_types": ["Float64Precision", "AdaptivePrecision"],
                "time": "04:00:00",
                "mem": "128G",
                "cpus": 24
            },
            "scaling": {
                "desc": "Scaling analysis - degree and sample size scaling",
                "degrees": [4, 6, 8, 10, 12, 14],
                "sample_sizes": [100, 200, 400, 800],
                "sample_ranges": [1.2],
                "precision_types": ["Float64Precision"],
                "time": "03:00:00",
                "mem": "96G",
                "cpus": 24
            }
        }
    
    def create_slurm_job(self, mode, custom_params=None, job_id=None):
        """Create SLURM job script for Deuflhard benchmark"""
        if job_id is None:
            job_id = str(uuid.uuid4())[:8]
        
        config = self.test_modes[mode].copy()
        if custom_params:
            config.update(custom_params)
        
        # Create Julia test script content
        julia_script = f'''
# Deuflhard Benchmark Test - Mode: {mode}
# Generated: {datetime.now()}
# Job ID: {job_id}

println("🚀 DEUFLHARD BENCHMARK TEST - MODE: {mode.upper()}")
println("=" ^ 60)
println("Job ID: {job_id}")
println("Started: $(now())")
println("Julia version: $(VERSION)")
println("Threads: $(Threads.nthreads())")
println()

# Load packages and setup
try
    using CSV, DataFrames, Parameters, ForwardDiff, StaticArrays, Distributions
    using DynamicPolynomials, MultivariatePolynomials, TimerOutputs, TOML
    using BenchmarkTools
    println("✅ Packages loaded")
    
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
    
    # Test configuration
    degrees = {config["degrees"]}
    sample_sizes = {config["sample_sizes"]}
    sample_ranges = {config["sample_ranges"]}
    precision_types = [Float64Precision, AdaptivePrecision]  # Map from strings
    
    println("📋 Test Configuration:")
    println("   Degrees: $degrees")
    println("   Sample sizes: $sample_sizes")
    println("   Sample ranges: $sample_ranges")
    println("   Precision types: $precision_types")
    println()
    
    # Results collection
    results = []
    test_count = 0
    total_tests = length(degrees) * length(sample_sizes) * length(sample_ranges) * length(precision_types)
    
    println("🧪 Running $total_tests tests...")
    println()
    
    for degree in degrees
        for samples in sample_sizes
            for sample_range in sample_ranges
                for precision_type in precision_types
                    test_count += 1
                    
                    println("[$test_count/$total_tests] Testing: degree=$degree, samples=$samples, range=$sample_range, precision=$precision_type")
                    
                    try
                        # Create test input
                        TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], 
                                      sample_range=sample_range, GN=samples, tolerance=nothing)
                        
                        # Polynomial construction with timing
                        construction_start = time()
                        pol = Constructor(TR, degree, precision=precision_type, verbose=0)
                        construction_time = time() - construction_start
                        
                        # Critical point finding
                        @polyvar x[1:2]
                        critical_start = time()
                        solutions = solve_polynomial_system(x, 2, degree, pol.coeffs)
                        df_critical = process_crit_pts(solutions, Deuflhard, TR)
                        df_enhanced, df_min = analyze_critical_points(Deuflhard, df_critical, TR, enable_hessian=false)
                        critical_time = time() - critical_start
                        
                        # Record results
                        result = Dict(
                            "job_id" => "{job_id}",
                            "test_mode" => "{mode}",
                            "timestamp" => string(now()),
                            "degree" => degree,
                            "samples" => samples,
                            "sample_range" => sample_range,
                            "precision_type" => string(precision_type),
                            "construction_time" => construction_time,
                            "l2_error" => pol.nrm,
                            "condition_number" => pol.cond_vandermonde,
                            "n_coefficients" => length(pol.coeffs),
                            "n_critical_points" => nrow(df_critical),
                            "n_local_minima" => nrow(df_min),
                            "critical_point_time" => critical_time,
                            "julia_version" => string(VERSION),
                            "threads" => Threads.nthreads(),
                            "hostname" => gethostname()
                        )
                        
                        push!(results, result)
                        
                        println("   ✅ Success: L2=$(@sprintf("%.2e", pol.nrm)), critical_pts=$(nrow(df_critical)), minima=$(nrow(df_min))")
                        
                    catch e
                        println("   ❌ Failed: $e")
                    end
                    
                    println()
                end
            end
        end
    end
    
    # Save results
    if !isempty(results)
        results_dir = "deuflhard_results_{job_id}"
        mkpath(results_dir)
        
        # Convert to DataFrame and save
        df = DataFrame(results)
        CSV.write("$results_dir/test_results.csv", df)
        
        # Save configuration
        open("$results_dir/test_config.txt", "w") do f
            println(f, "# Deuflhard Benchmark Test Configuration")
            println(f, "job_id: {job_id}")
            println(f, "mode: {mode}")
            println(f, "timestamp: $(now())")
            println(f, "degrees: $degrees")
            println(f, "sample_sizes: $sample_sizes")
            println(f, "sample_ranges: $sample_ranges")
            println(f, "julia_version: $(VERSION)")
            println(f, "threads: $(Threads.nthreads())")
            println(f, "hostname: $(gethostname())")
        end
        
        println("📊 RESULTS SUMMARY:")
        println("   Tests completed: $(length(results))/$total_tests")
        println("   Results saved to: $results_dir/")
        
        # Quick analysis
        construction_times = [r["construction_time"] for r in results]
        l2_errors = [r["l2_error"] for r in results]
        
        println("   Construction time: min=$(@sprintf("%.3f", minimum(construction_times)))s, max=$(@sprintf("%.3f", maximum(construction_times)))s")
        println("   L2 errors: min=$(@sprintf("%.2e", minimum(l2_errors))), max=$(@sprintf("%.2e", maximum(l2_errors)))")
        
        println("\\n🎉 DEUFLHARD BENCHMARK COMPLETED SUCCESSFULLY!")
    else
        println("❌ No tests completed successfully")
        exit(1)
    end
    
catch e
    println("❌ Benchmark failed: $e")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    exit(1)
end
'''
        
        # Create SLURM script
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=deuflhard_{mode}
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={config['cpus']}
#SBATCH --mem={config['mem']}
#SBATCH --time={config['time']}
#SBATCH --output=deuflhard_{mode}_%j.out
#SBATCH --error=deuflhard_{mode}_%j.err

echo "=== Deuflhard Benchmark Test ==="
echo "Mode: {mode}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

cd $HOME/globtim_hpc

# Run the benchmark
/sw/bin/julia --project=. -e '{julia_script}'

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
"""
        
        return slurm_script, job_id
    
    def submit_job(self, mode, custom_params=None, monitor=True):
        """Submit Deuflhard benchmark job"""
        print(f"🚀 Submitting Deuflhard benchmark test - Mode: {mode}")
        print(f"Description: {self.test_modes[mode]['desc']}")
        print()
        
        # Create job script
        slurm_script, job_id = self.create_slurm_job(mode, custom_params, job_id=None)
        
        # Write script to temporary file
        script_path = f"/tmp/deuflhard_{mode}_{job_id}.slurm"
        with open(script_path, 'w') as f:
            f.write(slurm_script)
        
        try:
            # Copy script to cluster
            scp_cmd = f"scp {script_path} {self.cluster_host}:/tmp/"
            subprocess.run(scp_cmd, shell=True, check=True)
            
            # Submit job
            submit_cmd = f'ssh {self.cluster_host} "sbatch /tmp/deuflhard_{mode}_{job_id}.slurm"'
            result = subprocess.run(submit_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Extract job ID from SLURM output
                slurm_job_id = result.stdout.strip().split()[-1]
                print(f"✅ Job submitted successfully!")
                print(f"SLURM Job ID: {slurm_job_id}")
                print(f"Test ID: {job_id}")
                print()
                
                if monitor:
                    if self.monitor:
                        print("👀 Starting job monitoring...")
                        print("Use Ctrl+C to stop monitoring")
                        try:
                            self.monitor.monitor_continuous(interval=30)
                        except KeyboardInterrupt:
                            print("\n👋 Monitoring stopped")
                    else:
                        print("👀 Monitoring not available, use manual monitoring:")
                        print(f"   ssh {self.cluster_host} 'squeue -j {slurm_job_id}'")
                        print(f"   ssh {self.cluster_host} 'tail -f deuflhard_*_{slurm_job_id}.out'")
                
                return slurm_job_id, job_id
            else:
                print(f"❌ Job submission failed: {result.stderr}")
                return None, None
                
        except Exception as e:
            print(f"❌ Error submitting job: {e}")
            return None, None
        finally:
            # Clean up temporary file
            if os.path.exists(script_path):
                os.remove(script_path)

def main():
    parser = argparse.ArgumentParser(description="Submit Deuflhard benchmark tests")
    parser.add_argument("--mode", choices=["quick", "standard", "thorough", "scaling"], 
                       default="standard", help="Test mode")
    parser.add_argument("--no-monitor", action="store_true", help="Don't monitor job progress")
    parser.add_argument("--list-modes", action="store_true", help="List available test modes")
    
    args = parser.parse_args()
    
    submitter = DeuflhardBenchmarkSubmitter()
    
    if args.list_modes:
        print("Available test modes:")
        for mode, config in submitter.test_modes.items():
            print(f"  {mode}: {config['desc']}")
            print(f"    Time: {config['time']}, Memory: {config['mem']}, CPUs: {config['cpus']}")
            print(f"    Degrees: {config['degrees']}")
            print(f"    Sample sizes: {config['sample_sizes']}")
            print()
        return
    
    # Submit job
    slurm_job_id, test_id = submitter.submit_job(args.mode, monitor=not args.no_monitor)
    
    if slurm_job_id:
        print(f"🎯 Job submitted successfully!")
        print(f"Use existing monitoring tools:")
        print(f"  python hpc/monitoring/python/slurm_monitor.py --job {slurm_job_id}")
        print(f"  Results will be in: ~/globtim_hpc/deuflhard_results_{test_id}/")

if __name__ == "__main__":
    main()
