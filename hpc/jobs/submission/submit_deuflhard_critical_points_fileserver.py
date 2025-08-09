#!/usr/bin/env python3

"""
Deuflhard Critical Points Computation - Fileserver Integration
=============================================================

Fileserver-integrated version of the critical points computation script.
Uses NFS depot and fileserver results path for systematic HPC workflow.

This script runs the complete pipeline:
1. Create test input with sampling
2. Construct polynomial approximation  
3. Solve polynomial system for critical points
4. Process and validate results
5. Save to fileserver results directory

Usage:
    python submit_deuflhard_critical_points_fileserver.py [--mode MODE] [--degree DEGREE] [--samples SAMPLES] [--results-base PATH]
"""

import argparse
import subprocess
import uuid
import os
from datetime import datetime
from pathlib import Path

class DeuflhardCriticalPointsFileserverSubmitter:
    def __init__(self, results_base=None):
        self.cluster_host = "scholten@falcon"
        self.fileserver_host = "scholten@mack"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/globtim_hpc/julia_depot"  # NFS depot path
        
        # Results base path - use provided or default to safe location
        self.results_base = results_base or "~/globtim_hpc/results"
        
        # Test configurations for critical point computation
        self.test_modes = {
            "quick": {
                "degree": 8,
                "samples": 50,
                "time_limit": "00:30:00",
                "memory": "8G",
                "cpus": 4,
                "description": "Quick critical points (degree 8, 50^2 samples)"
            },
            "standard": {
                "degree": 12,
                "samples": 80,
                "time_limit": "01:00:00",
                "memory": "16G",
                "cpus": 8,
                "description": "Standard critical points (degree 12, 80^2 samples)"
            },
            "extended": {
                "degree": 16,
                "samples": 120,
                "time_limit": "02:00:00",
                "memory": "32G",
                "cpus": 16,
                "description": "Extended critical points (degree 16, 120^2 samples)"
            }
        }

    def create_slurm_script(self, test_id, config, degree, samples):
        """Create SLURM script for critical points computation"""
        
        output_dir = f"{self.results_base}/critical_points_{test_id}"
        
        script_content = f"""#!/bin/bash
#SBATCH --job-name=deuflhard_critical_points_{test_id}
#SBATCH --output={output_dir}/slurm_%j.out
#SBATCH --error={output_dir}/slurm_%j.err
#SBATCH --time={config['time_limit']}
#SBATCH --mem={config['memory']}
#SBATCH --cpus-per-task={config['cpus']}
#SBATCH --partition=batch

echo "🚀 Deuflhard Critical Points Computation - Fileserver Integration"
echo "=================================================================="
echo "Test ID: {test_id}"
echo "Timestamp: $(date -Iseconds)"
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: {config['memory']}"
echo ""

# Setup environment
export JULIA_DEPOT_PATH="{self.depot_path}"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Create output directory
mkdir -p {output_dir}
cd {self.remote_dir}

# Create test configuration
cat > {output_dir}/critical_points_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "deuflhard_critical_points_fileserver",
  "execution_mode": "slurm_fileserver_nfs",
  "function": "Deuflhard",
  "dimension": 2,
  "parameters": {{
    "degree": {degree},
    "samples": {samples},
    "total_samples": {samples**2},
    "center": [0.0, 0.0],
    "sample_range": 1.4,
    "basis": "chebyshev",
    "normalized": false
  }},
  "metadata": {{
    "created_by": "submit_deuflhard_critical_points_fileserver.py",
    "purpose": "Fileserver-integrated critical points computation",
    "results_base": "{self.results_base}",
    "depot_path": "{self.depot_path}",
    "expected_runtime": "{config['time_limit']}"
  }}
}}
EOF

echo "📋 Configuration saved to {output_dir}/critical_points_config.json"

# Run Julia computation
echo "🔧 Starting Julia critical points computation..."
julia --project=. -e "
using Pkg
Pkg.instantiate()

using Globtim
using DynamicPolynomials
using CSV
using DataFrames
using LinearAlgebra
using JSON3

println(\"📦 Packages loaded successfully\")

# Test parameters
n = 2
d = {degree}
f = Deuflhard
output_dir = \"{output_dir}\"

println(\"🎯 Test Parameters:\")
println(\"  Function: Deuflhard\")
println(\"  Dimension: \$n\")
println(\"  Degree: \$d\")
println(\"  Samples: {samples}\")
println(\"  Output: \$output_dir\")
println()

# Step 1: Create test input
println(\"🔧 Step 1: Creating Test Input...\")
try
    global TR = test_input(
        f,
        dim = n,
        center = [0.0, 0.0],
        sample_range = 1.4
    )
    println(\"  ✅ Test input created successfully\")
    println(\"  📊 Dimension: \", TR.dim)
    println(\"  📍 Center: \", TR.center)
    println(\"  📏 Sample range: \", TR.sample_range)
catch e
    println(\"  ❌ Test input creation failed: \", e)
    exit(1)
end

# Step 2: Construct polynomial approximation
println(\"\\n🔧 Step 2: Constructing Polynomial Approximation...\")
try
    time_construct = @elapsed begin
        global pol_cheb = Constructor(
            TR,
            d,
            basis = :chebyshev,
            normalized = false,
            verbose = 1
        )
    end
    
    println(\"  ✅ Polynomial constructed successfully\")
    println(\"  ⏱️  Construction time: \", time_construct, \" seconds\")
    println(\"  📊 L2 error: \", pol_cheb.nrm)
    println(\"  📈 Condition number: \", pol_cheb.cond_vandermonde)
    println(\"  🎯 Final degree: \", pol_cheb.degree)
catch e
    println(\"  ❌ Polynomial construction failed: \", e)
    exit(1)
end

# Step 3: Solve polynomial system for critical points
println(\"\\n🔧 Step 3: Solving Polynomial System for Critical Points...\")
try
    @polyvar(x[1:n])
    
    time_solve = @elapsed begin
        global real_pts_cheb = solve_polynomial_system(
            x,
            n,
            pol_cheb.degree,  # Use actual degree from constructor
            pol_cheb.coeffs;
            basis = :chebyshev,
            normalized = false
        )
    end
    
    println(\"  ✅ Polynomial system solved\")
    println(\"  ⏱️  Solving time: \", time_solve, \" seconds\")
    println(\"  📊 Critical points found: \", length(real_pts_cheb))
    
    if !isempty(real_pts_cheb)
        println(\"  📍 First critical point: \", real_pts_cheb[1])
        
        # Validate dimensions
        dimensions_correct = all(p -> length(p) == TR.dim, real_pts_cheb)
        println(\"  ✅ All points have correct dimension: \", dimensions_correct)
    else
        println(\"  ⚠️  No critical points found\")
    end
    
catch e
    println(\"  ❌ Polynomial system solving failed: \", e)
    exit(1)
end

# Step 4: Process critical points into DataFrame
println(\"\\n🔧 Step 4: Processing Critical Points...\")
try
    time_process = @elapsed begin
        global df_cheb = process_crit_pts(real_pts_cheb, f, TR; skip_filtering = false)
    end

    println(\"  ✅ Critical points processed into DataFrame\")
    println(\"  ⏱️  Processing time: \", time_process, \" seconds\")
    println(\"  📊 DataFrame rows: \", nrow(df_cheb))
    println(\"  📋 DataFrame columns: \", names(df_cheb))

    if nrow(df_cheb) > 0
        println(\"  📍 Sample critical point data:\")
        println(\"    x1: \", df_cheb[1, :x1])
        println(\"    x2: \", df_cheb[1, :x2])
        println(\"    z: \", df_cheb[1, :z])

        # Save critical points to CSV
        CSV.write(joinpath(output_dir, \"critical_points.csv\"), df_cheb)
        println(\"  ✅ Critical points saved to CSV\")

        # Find best point (minimum function value)
        min_idx = argmin(df_cheb.z)
        best_point = [df_cheb[min_idx, :x1], df_cheb[min_idx, :x2]]
        best_value = df_cheb[min_idx, :z]

        println(\"  🎯 Best critical point: \", best_point)
        println(\"  📊 Best function value: \", best_value)

        # Distance to origin (known global minimum for Deuflhard)
        distance_to_origin = norm(best_point)
        println(\"  📏 Distance to origin: \", distance_to_origin)

    else
        println(\"  ⚠️  No valid critical points after processing\")
    end

catch e
    println(\"  ❌ Critical points processing failed: \", e)
    exit(1)
end

# Step 4.5: Comprehensive Verification and Validation
println(\"\\n🔧 Step 4.5: Comprehensive Verification and Validation...\")
verification_results = Dict()

try
    # Type verification
    println(\"  🔍 Type Verification:\")

    # Check critical points type and structure
    if !isempty(real_pts_cheb)
        points_type_valid = all(p -> isa(p, Vector{Float64}), real_pts_cheb)
        points_dimension_valid = all(p -> length(p) == n, real_pts_cheb)
        points_finite_valid = all(p -> all(isfinite.(p)), real_pts_cheb)

        println(\"    ✅ Critical points type check: \", points_type_valid)
        println(\"    ✅ Critical points dimension check: \", points_dimension_valid)
        println(\"    ✅ Critical points finite check: \", points_finite_valid)

        verification_results[\"points_type_valid\"] = points_type_valid
        verification_results[\"points_dimension_valid\"] = points_dimension_valid
        verification_results[\"points_finite_valid\"] = points_finite_valid
    else
        println(\"    ⚠️  No critical points to verify\")
        verification_results[\"points_type_valid\"] = false
        verification_results[\"points_dimension_valid\"] = false
        verification_results[\"points_finite_valid\"] = false
    end

    # DataFrame verification
    if nrow(df_cheb) > 0
        df_types_valid = all(col -> eltype(df_cheb[!, col]) <: Real, [:x1, :x2, :z])
        df_finite_valid = all(isfinite.(df_cheb.z))
        df_dimension_consistent = nrow(df_cheb) <= length(real_pts_cheb)

        println(\"    ✅ DataFrame types check: \", df_types_valid)
        println(\"    ✅ DataFrame finite values check: \", df_finite_valid)
        println(\"    ✅ DataFrame consistency check: \", df_dimension_consistent)

        verification_results[\"df_types_valid\"] = df_types_valid
        verification_results[\"df_finite_valid\"] = df_finite_valid
        verification_results[\"df_dimension_consistent\"] = df_dimension_consistent
    end

    # Accuracy verification using ForwardDiff
    println(\"  🎯 Accuracy Verification:\")

    if nrow(df_cheb) > 0
        using ForwardDiff

        gradient_checks = []
        accuracy_threshold = 1e-6

        for i in 1:min(5, nrow(df_cheb))  # Check first 5 points
            point = [df_cheb[i, :x1], df_cheb[i, :x2]]

            # Compute gradient at the point
            gradient = ForwardDiff.gradient(f, point)
            gradient_norm = norm(gradient)
            is_critical = gradient_norm < accuracy_threshold

            push!(gradient_checks, Dict(
                \"point_index\" => i,
                \"point\" => point,
                \"gradient_norm\" => gradient_norm,
                \"is_critical\" => is_critical
            ))

            status_symbol = is_critical ? \"✅\" : \"❌\"
            println(\"    \$status_symbol Point \$i gradient norm: \", gradient_norm, \" (critical: \", is_critical, \")\")
        end

        critical_points_valid = all(check -> check[\"is_critical\"], gradient_checks)
        avg_gradient_norm = mean([check[\"gradient_norm\"] for check in gradient_checks])

        println(\"    📊 Average gradient norm: \", avg_gradient_norm)
        println(\"    ✅ All checked points are critical: \", critical_points_valid)

        verification_results[\"gradient_checks\"] = gradient_checks
        verification_results[\"critical_points_valid\"] = critical_points_valid
        verification_results[\"avg_gradient_norm\"] = avg_gradient_norm
        verification_results[\"accuracy_threshold\"] = accuracy_threshold
    else
        println(\"    ⚠️  No critical points to verify accuracy\")
        verification_results[\"critical_points_valid\"] = false
    end

    # Domain verification
    println(\"  📏 Domain Verification:\")

    if !isempty(real_pts_cheb)
        domain_bounds = [-1.0, 1.0]  # Normalized domain
        points_in_domain = all(p -> all(domain_bounds[1] .<= p .<= domain_bounds[2]), real_pts_cheb)

        println(\"    ✅ All points in normalized domain [-1,1]^n: \", points_in_domain)
        verification_results[\"points_in_domain\"] = points_in_domain

        # Check distribution of points
        if length(real_pts_cheb) > 1
            distances = [norm(p1 - p2) for p1 in real_pts_cheb for p2 in real_pts_cheb if p1 != p2]
            min_distance = minimum(distances)
            max_distance = maximum(distances)

            println(\"    📊 Point separation - min: \", min_distance, \", max: \", max_distance)
            verification_results[\"min_point_separation\"] = min_distance
            verification_results[\"max_point_separation\"] = max_distance
        end
    end

    # Overall verification status
    overall_success = all([
        get(verification_results, \"points_type_valid\", false),
        get(verification_results, \"points_dimension_valid\", false),
        get(verification_results, \"points_finite_valid\", false),
        get(verification_results, \"critical_points_valid\", false),
        get(verification_results, \"points_in_domain\", false)
    ])

    verification_results[\"overall_verification_success\"] = overall_success

    println(\"  🎯 Overall verification status: \", overall_success ? \"✅ PASSED\" : \"❌ FAILED\")

catch e
    println(\"  ❌ Verification failed: \", e)
    verification_results[\"verification_error\"] = string(e)
    verification_results[\"overall_verification_success\"] = false
end

# Step 5: Create validation summary
println(\"\\n🔧 Step 5: Creating Validation Summary...\")
try
    # Determine overall job success based on verification results
    job_success = verification_results[\"overall_verification_success\"] && nrow(df_cheb) > 0

    summary = Dict(
        \"test_id\" => \"{test_id}\",
        \"timestamp\" => string(now()),
        \"success\" => job_success,
        \"parameters\" => Dict(
            \"degree\" => pol_cheb.degree,
            \"samples\" => {samples},
            \"dimension\" => n,
            \"function\" => \"Deuflhard\",
            \"center\" => [0.0, 0.0],
            \"sample_range\" => 1.4
        ),
        \"results\" => Dict(
            \"l2_error\" => pol_cheb.nrm,
            \"condition_number\" => pol_cheb.cond_vandermonde,
            \"num_critical_points\" => length(real_pts_cheb),
            \"num_processed_points\" => nrow(df_cheb)
        ),
        \"verification\" => verification_results
    )

    if nrow(df_cheb) > 0
        summary[\"results\"][\"best_point\"] = best_point
        summary[\"results\"][\"best_value\"] = best_value
        summary[\"results\"][\"distance_to_origin\"] = distance_to_origin
        summary[\"results\"][\"accuracy_check\"] = distance_to_origin < 0.1

        # Add quality assessment
        quality_score = 0
        max_score = 100

        # Mathematical accuracy (40 points)
        if distance_to_origin < 0.01
            quality_score += 40
        elseif distance_to_origin < 0.1
            quality_score += 25
        elseif distance_to_origin < 0.5
            quality_score += 10
        end

        # Approximation quality (30 points)
        if pol_cheb.nrm < 0.001
            quality_score += 30
        elseif pol_cheb.nrm < 0.01
            quality_score += 20
        elseif pol_cheb.nrm < 0.1
            quality_score += 10
        end

        # Critical point count (20 points)
        if length(real_pts_cheb) >= 5
            quality_score += 20
        elseif length(real_pts_cheb) >= 2
            quality_score += 15
        elseif length(real_pts_cheb) >= 1
            quality_score += 10
        end

        # Verification success (10 points)
        if verification_results[\"overall_verification_success\"]
            quality_score += 10
        end

        summary[\"quality_assessment\"] = Dict(
            \"score\" => quality_score,
            \"max_score\" => max_score,
            \"percentage\" => round(quality_score / max_score * 100, digits=1),
            \"grade\" => quality_score >= 80 ? \"Excellent\" :
                       quality_score >= 60 ? \"Good\" :
                       quality_score >= 40 ? \"Acceptable\" : \"Poor\"
        )

        println(\"  📊 Quality Score: \", quality_score, \"/\", max_score, \" (\",
                round(quality_score / max_score * 100, digits=1), \"%) - \",
                summary[\"quality_assessment\"][\"grade\"])
    else
        summary[\"quality_assessment\"] = Dict(
            \"score\" => 0,
            \"max_score\" => 100,
            \"percentage\" => 0.0,
            \"grade\" => \"Failed\"
        )
    end
    
    # Save summary as JSON
    open(joinpath(output_dir, \"validation_summary.json\"), \"w\") do f
        JSON3.pretty(f, summary)
    end
    
    # Save human-readable summary
    open(joinpath(output_dir, \"validation_results.txt\"), \"w\") do f
        println(f, \"Deuflhard Critical Points Validation Results\")
        println(f, \"===========================================\")
        println(f, \"Test ID: {test_id}\")
        println(f, \"Timestamp: \", string(now()))
        println(f, \"Overall Success: \", job_success)
        println(f, \"\")
        println(f, \"Parameters:\")
        println(f, \"  Function: Deuflhard\")
        println(f, \"  Degree: \", pol_cheb.degree)
        println(f, \"  Samples: {samples}\")
        println(f, \"  Dimension: \", n)
        println(f, \"  Center: [0.0, 0.0]\")
        println(f, \"  Sample Range: 1.4\")
        println(f, \"\")
        println(f, \"Computational Results:\")
        println(f, \"  L2 Error: \", pol_cheb.nrm)
        println(f, \"  Condition Number: \", pol_cheb.cond_vandermonde)
        println(f, \"  Critical Points Found: \", length(real_pts_cheb))
        println(f, \"  Processed Points: \", nrow(df_cheb))

        if nrow(df_cheb) > 0
            println(f, \"  Best Point: \", best_point)
            println(f, \"  Best Value: \", best_value)
            println(f, \"  Distance to Origin: \", distance_to_origin)
            println(f, \"  Accuracy Check (< 0.1): \", distance_to_origin < 0.1)

            # Quality assessment
            qa = summary[\"quality_assessment\"]
            println(f, \"\")
            println(f, \"Quality Assessment:\")
            println(f, \"  Score: \", qa[\"score\"], \"/\", qa[\"max_score\"], \" (\", qa[\"percentage\"], \"%)\")
            println(f, \"  Grade: \", qa[\"grade\"])
        end

        println(f, \"\")
        println(f, \"Verification Results:\")
        println(f, \"  Type Verification: \", get(verification_results, \"points_type_valid\", false))
        println(f, \"  Dimension Verification: \", get(verification_results, \"points_dimension_valid\", false))
        println(f, \"  Finite Values Check: \", get(verification_results, \"points_finite_valid\", false))
        println(f, \"  Critical Points Valid: \", get(verification_results, \"critical_points_valid\", false))
        println(f, \"  Domain Verification: \", get(verification_results, \"points_in_domain\", false))
        println(f, \"  Overall Verification: \", verification_results[\"overall_verification_success\"])

        if haskey(verification_results, \"avg_gradient_norm\")
            println(f, \"  Average Gradient Norm: \", verification_results[\"avg_gradient_norm\"])
            println(f, \"  Accuracy Threshold: \", verification_results[\"accuracy_threshold\"])
        end
    end
    
    println(\"  ✅ Validation summary saved\")
    
catch e
    println(\"  ❌ Validation summary creation failed: \", e)
    exit(1)
end

println(\"\\n🎉 Critical points computation completed successfully!\")
println(\"📁 Results saved to: \$output_dir\")
"

echo "✅ Julia computation completed with exit code: $?"
echo "📁 Final results:"
ls -la {output_dir}/

echo "🎯 Critical points computation finished!"
"""
        
        script_filename = f"critical_points_{test_id}.slurm"
        with open(script_filename, 'w') as f:
            f.write(script_content)
        
        return script_filename

    def run_critical_points_test(self, mode="quick", custom_degree=None, custom_samples=None):
        """Run critical points computation test"""
        
        if mode not in self.test_modes:
            print(f"❌ Invalid mode: {mode}")
            print(f"Available modes: {list(self.test_modes.keys())}")
            return False, None, None
        
        config = self.test_modes[mode]
        degree = custom_degree or config["degree"]
        samples = custom_samples or config["samples"]
        
        print("🚀 Deuflhard Critical Points Computation - Fileserver Integration")
        print("=" * 70)
        print(f"Mode: {mode}")
        print(f"Description: {config['description']}")
        print(f"Degree: {degree}")
        print(f"Samples: {samples}")
        print(f"Results base: {self.results_base}")
        print()
        
        # Generate test ID
        test_id = str(uuid.uuid4())[:8]
        
        # Create SLURM script
        script_file = self.create_slurm_script(test_id, config, degree, samples)
        print(f"✅ Created SLURM script: {script_file}")
        
        # Create results directory on fileserver
        output_dir = f"{self.results_base}/critical_points_{test_id}"
        print(f"📁 Creating results directory: {output_dir}")
        
        try:
            subprocess.run([
                "ssh", self.fileserver_host,
                f"mkdir -p {output_dir}"
            ], check=True)
            print("✅ Results directory created on fileserver")
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to create results directory: {e}")
            return False, None, None
        
        # Upload script to cluster
        print("📤 Uploading script to cluster...")
        try:
            subprocess.run([
                "scp", script_file, f"{self.cluster_host}:{self.remote_dir}/"
            ], check=True)
            print("✅ Script uploaded successfully")
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to upload script: {e}")
            return False, None, None
        
        # Submit job
        print("🚀 Submitting job to SLURM...")
        try:
            cmd = ["ssh", self.cluster_host, f"cd {self.remote_dir} && sbatch {script_file}"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            # Extract job ID from output
            output_lines = result.stdout.strip().split('\n')
            slurm_job_id = None
            for line in output_lines:
                if "Submitted batch job" in line:
                    slurm_job_id = line.split()[-1]
                    break
            
            if slurm_job_id:
                print("✅ Job submitted successfully!")
                print(f"📋 SLURM Job ID: {slurm_job_id}")
                print(f"🔍 Test ID: {test_id}")
                print(f"📁 Results will be saved to: {output_dir}")
                print(f"🔍 Monitor with: python3 hpc/monitoring/python/automated_job_monitor.py --job-id {slurm_job_id} --test-id {test_id}")
                
                # Clean up local script file
                os.remove(script_file)
                
                return True, test_id, slurm_job_id
            else:
                print("⚠️  Job submitted but couldn't extract job ID")
                print(f"Output: {result.stdout}")
                return False, test_id, None
                
        except subprocess.CalledProcessError as e:
            print(f"❌ Job submission failed: {e}")
            if e.stderr:
                print(f"Error: {e.stderr}")
            return False, test_id, None

def main():
    parser = argparse.ArgumentParser(description="Run Deuflhard critical points computation with fileserver integration")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"],
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--degree", type=int, help="Custom polynomial degree")
    parser.add_argument("--samples", type=int, help="Custom samples per dimension")
    parser.add_argument("--results-base", type=str, help="Base path for results on fileserver")
    parser.add_argument("--auto-collect", action="store_true",
                       help="Automatically start monitoring and collection after job submission")
    parser.add_argument("--monitor-interval", type=int, default=30,
                       help="Monitoring check interval in seconds (default: 30)")
    parser.add_argument("--max-wait", type=int, default=7200,
                       help="Maximum wait time for job completion in seconds (default: 7200 = 2 hours)")

    args = parser.parse_args()
    
    submitter = DeuflhardCriticalPointsFileserverSubmitter(results_base=args.results_base)
    success, test_id, slurm_job_id = submitter.run_critical_points_test(
        args.mode, args.degree, args.samples
    )
    
    if success:
        print("\n🎉 Critical points computation submitted successfully!")
        print(f"📋 Test ID: {test_id}")
        print(f"📋 SLURM Job ID: {slurm_job_id}")
        print(f"📁 Results will be saved to: {submitter.results_base}/critical_points_{test_id}/")

        if args.auto_collect and slurm_job_id:
            print(f"\n🤖 Starting automated monitoring and collection...")
            print(f"   Monitor interval: {args.monitor_interval} seconds")
            print(f"   Maximum wait time: {args.max_wait} seconds")

            # Start automated monitoring
            import subprocess
            import os

            # Get the directory containing this script
            script_dir = os.path.dirname(os.path.abspath(__file__))
            monitor_script = os.path.join(script_dir, "automated_job_monitor.py")

            # Build monitoring command
            monitor_cmd = [
                "python3", monitor_script,
                "--job-id", str(slurm_job_id),
                "--test-id", test_id,
                "--interval", str(args.monitor_interval),
                "--max-wait", str(args.max_wait)
            ]

            print(f"🚀 Launching monitor: {' '.join(monitor_cmd)}")

            try:
                # Start monitoring in the background
                monitor_process = subprocess.Popen(
                    monitor_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )

                print(f"✅ Automated monitoring started (PID: {monitor_process.pid})")
                print(f"📊 Monitor will check every {args.monitor_interval} seconds")
                print(f"⏰ Maximum wait time: {args.max_wait} seconds")
                print(f"📁 Results will be collected automatically when job completes")
                print(f"\\n💡 Monitor process is running in the background.")
                print(f"   You can check its status or kill it if needed.")

            except Exception as e:
                print(f"❌ Failed to start automated monitoring: {e}")
                print(f"🔍 Manual monitoring: python3 automated_job_monitor.py --job-id {slurm_job_id} --test-id {test_id}")
        else:
            print(f"🔍 Manual monitoring: python3 automated_job_monitor.py --job-id {slurm_job_id} --test-id {test_id}")
            if not args.auto_collect:
                print(f"💡 Use --auto-collect to enable automatic monitoring and collection")
    else:
        print("\n❌ Critical points computation submission failed!")
        exit(1)

if __name__ == "__main__":
    main()
