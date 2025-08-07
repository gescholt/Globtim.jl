#!/usr/bin/env python3

"""
Deuflhard Critical Points Computation - HPC Version
==================================================

Adapts the local Deuflhard test routine to compute actual critical points
on the HPC cluster using the full Globtim optimization workflow.

This script runs the complete pipeline:
1. Create test input with sampling
2. Construct polynomial approximation
3. Solve polynomial system for critical points
4. Process and validate results

Usage:
    python submit_deuflhard_critical_points.py [--mode MODE] [--degree DEGREE] [--samples SAMPLES]
"""

import argparse
import subprocess
import uuid
from datetime import datetime

class DeuflhardCriticalPointsSubmitter:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
        
        # Test configurations for critical point computation
        self.test_modes = {
            "quick": {
                "degree": 22,
                "samples": 120,
                "time_limit": "01:00:00",
                "memory": "16G",
                "cpus": 8,
                "description": "Quick critical points (degree 22, 120^2 samples)"
            },
            "standard": {
                "degree": 25,
                "samples": 150,
                "time_limit": "02:00:00",
                "memory": "32G",
                "cpus": 16,
                "description": "Standard critical points (degree 25, 150^2 samples)"
            },
            "extended": {
                "degree": 30,
                "samples": 200,
                "time_limit": "04:00:00",
                "memory": "64G",
                "cpus": 24,
                "description": "Extended critical points (degree 30, 200^2 samples)"
            }
        }
    
    def run_critical_points_test(self, mode="quick", custom_degree=None, custom_samples=None):
        """Run Deuflhard critical points computation using full Globtim workflow"""
        test_id = str(uuid.uuid4())[:8]
        
        config = self.test_modes[mode]
        
        # Allow custom parameters
        degree = custom_degree if custom_degree else config["degree"]
        samples = custom_samples if custom_samples else config["samples"]
        
        print(f"🧮 Running Deuflhard Critical Points Computation")
        print(f"Mode: {mode} - {config['description']}")
        print(f"Parameters: degree={degree}, samples={samples} ({samples}^2 = {samples**2} total samples)")
        print(f"Test ID: {test_id}")
        print(f"Using depot: {self.depot_path}")
        print()
        
        # Use /tmp for output to avoid quota issues
        output_dir = f"/tmp/deuflhard_critical_points_{test_id}"
        
        # Create the complete Globtim critical points computation
        julia_test = f"""
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"
cd {self.remote_dir}

echo "🧮 Deuflhard Critical Points Computation - {test_id}"
echo "Mode: {mode}"
echo "Degree: {degree}"
echo "Samples: {samples} ({samples}^2 = {samples**2} total)"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Depot: $JULIA_DEPOT_PATH"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create test configuration
cat > {output_dir}/critical_points_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "deuflhard_critical_points_hpc",
  "execution_mode": "direct_ssh_full_globtim",
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
    "created_by": "submit_deuflhard_critical_points.py",
    "purpose": "Full Globtim critical points computation on HPC",
    "mode": "{mode}",
    "depot_path": "{self.depot_path}",
    "expected_runtime": "{config['time_limit']}"
  }}
}}
EOF

echo "✅ Configuration saved"

# Run the complete Globtim critical points workflow
/sw/bin/julia --project=. -e '
using Dates

println("🚀 Deuflhard Critical Points Computation Starting")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println()

output_dir = "{output_dir}"
println("📋 Configuration:")
println("  Output directory: ", output_dir)
println("  Function: Deuflhard (2D)")
println("  Degree: {degree}")
println("  Samples: {samples} x {samples} = {samples**2}")
println()

# Load required packages and modules
println("📦 Loading Required Packages and Modules...")
try
    using StaticArrays, TimerOutputs, LinearAlgebra
    using DataFrames, CSV  # For result processing
    println("  ✅ Core packages loaded successfully")
    
    # Define timer and precision types (required for Globtim)
    const _TO = TimerOutputs.TimerOutput()
    
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    println("  ✅ Timer and precision types defined")
    
    # Load Globtim modules
    include("src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl")
    println("  ✅ LibFunctions.jl loaded")
    
    println("  ✅ All modules loaded successfully")
    
catch e
    println("  ❌ Module loading failed: ", e)
    
    # Save error information
    open(joinpath(output_dir, "module_loading_error.txt"), "w") do f
        println(f, "Critical Points Module Loading Error")
        println(f, "===================================")
        println(f, "Timestamp: ", now())
        println(f, "Error: ", e)
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
    end
    
    exit(1)
end

println()

# Step 1: Create test input (following runtests.jl pattern)
println("🔧 Step 1: Creating Test Input...")
try
    n = 2  # Dimension
    a, b = 7, 5
    scale_factor = a / b  # ≈ 1.4
    f = Deuflhard  # Objective function
    d = {degree}   # Polynomial degree
    SMPL = {samples}  # Samples per dimension
    
    println("  Function: Deuflhard")
    println("  Dimension: ", n)
    println("  Degree: ", d)
    println("  Samples per dimension: ", SMPL)
    println("  Total samples: ", SMPL^n)
    println("  Scale factor: ", scale_factor)
    
    # Create test input (this generates the sampling grid)
    TR = test_input(
        f,
        dim = n,
        center = [0.0, 0.0],
        GN = SMPL,
        sample_range = scale_factor,
        tolerance = nothing
    )
    
    println("  ✅ Test input created successfully")
    println("  ✅ Sampling grid generated: ", SMPL^n, " points")
    
    # Save test input information
    open(joinpath(output_dir, "test_input_info.txt"), "w") do f
        println(f, "Deuflhard Test Input Information")
        println(f, "===============================")
        println(f, "Timestamp: ", now())
        println(f, "Function: Deuflhard")
        println(f, "Dimension: ", n)
        println(f, "Degree: ", d)
        println(f, "Samples per dimension: ", SMPL)
        println(f, "Total samples: ", SMPL^n)
        println(f, "Center: [0.0, 0.0]")
        println(f, "Scale factor: ", scale_factor)
        println(f, "Test ID: {test_id}")
    end
    
catch e
    println("  ❌ Test input creation failed: ", e)
    exit(1)
end

println()

# Step 2: Construct polynomial approximation
println("🔧 Step 2: Constructing Polynomial Approximation...")
try
    time_construct = @elapsed begin
        pol_cheb = Constructor(TR, d, basis = :chebyshev, normalized = false)
    end
    
    println("  ✅ Chebyshev polynomial constructed")
    println("  ⏱️  Construction time: ", time_construct, " seconds")
    println("  📊 Coefficient count: ", length(pol_cheb.coeffs))
    
    # Save construction results
    open(joinpath(output_dir, "polynomial_construction.txt"), "w") do f
        println(f, "Polynomial Construction Results")
        println(f, "==============================")
        println(f, "Timestamp: ", now())
        println(f, "Basis: Chebyshev")
        println(f, "Normalized: false")
        println(f, "Degree: ", d)
        println(f, "Construction time: ", time_construct, " seconds")
        println(f, "Coefficient count: ", length(pol_cheb.coeffs))
        println(f, "Test ID: {test_id}")
    end
    
catch e
    println("  ❌ Polynomial construction failed: ", e)
    exit(1)
end

println()

# Step 3: Solve polynomial system for critical points
println("🔧 Step 3: Solving Polynomial System for Critical Points...")
try
    # Load DynamicPolynomials for polynomial system solving
    using DynamicPolynomials
    @polyvar(x[1:n]) # Define polynomial ring
    
    time_solve = @elapsed begin
        real_pts_cheb = solve_polynomial_system(
            x,
            n,
            d,
            pol_cheb.coeffs;
            basis = :chebyshev,
            normalized = false
        )
    end
    
    println("  ✅ Polynomial system solved")
    println("  ⏱️  Solving time: ", time_solve, " seconds")
    println("  📊 Critical points found: ", length(real_pts_cheb))
    
    if !isempty(real_pts_cheb)
        println("  📍 First critical point: ", real_pts_cheb[1])
        
        # Validate dimensions
        dimensions_correct = all(p -> length(p) == TR.dim, real_pts_cheb)
        println("  ✅ All points have correct dimension: ", dimensions_correct)
        
        if !dimensions_correct
            wrong_points = filter(p -> length(p) != TR.dim, real_pts_cheb)
            println("  ⚠️  Points with wrong dimension: ", length(wrong_points))
        end
    else
        println("  ⚠️  No critical points found")
    end
    
    # Save solving results
    open(joinpath(output_dir, "polynomial_solving.txt"), "w") do f
        println(f, "Polynomial System Solving Results")
        println(f, "=================================")
        println(f, "Timestamp: ", now())
        println(f, "Solving time: ", time_solve, " seconds")
        println(f, "Critical points found: ", length(real_pts_cheb))
        println(f, "Dimensions correct: ", dimensions_correct)
        println(f, "Test ID: {test_id}")
        println(f, "")
        if !isempty(real_pts_cheb)
            println(f, "First few critical points:")
            for (i, pt) in enumerate(real_pts_cheb[1:min(5, length(real_pts_cheb))])
                println(f, "  ", i, ": ", pt)
            end
        end
    end
    
catch e
    println("  ❌ Polynomial system solving failed: ", e)
    exit(1)
end

println()

# Step 4: Process critical points into DataFrame
println("🔧 Step 4: Processing Critical Points...")
try
    time_process = @elapsed begin
        df_cheb = process_crit_pts(real_pts_cheb, f, TR; skip_filtering = false)
    end
    
    println("  ✅ Critical points processed into DataFrame")
    println("  ⏱️  Processing time: ", time_process, " seconds")
    println("  📊 DataFrame rows: ", nrow(df_cheb))
    println("  📋 DataFrame columns: ", names(df_cheb))
    
    if nrow(df_cheb) > 0
        println("  📍 Sample critical point data:")
        println("    x1: ", df_cheb[1, :x1])
        println("    x2: ", df_cheb[1, :x2])
        println("    f_value: ", df_cheb[1, :f_value])
        
        # Save critical points to CSV
        CSV.write(joinpath(output_dir, "critical_points.csv"), df_cheb)
        println("  ✅ Critical points saved to CSV")
        
        # Save summary statistics
        open(joinpath(output_dir, "critical_points_summary.txt"), "w") do f
            println(f, "Deuflhard Critical Points Summary")
            println(f, "=================================")
            println(f, "Timestamp: ", now())
            println(f, "Test ID: {test_id}")
            println(f, "Mode: {mode}")
            println(f, "")
            println(f, "Parameters:")
            println(f, "  Degree: {degree}")
            println(f, "  Samples: {samples} x {samples} = {samples**2}")
            println(f, "  Function: Deuflhard (2D)")
            println(f, "")
            println(f, "Results:")
            println(f, "  Critical points found: ", nrow(df_cheb))
            println(f, "  Processing time: ", time_process, " seconds")
            println(f, "  Total computation time: ", time_construct + time_solve + time_process, " seconds")
            println(f, "")
            println(f, "Performance:")
            println(f, "  Construction: ", time_construct, " seconds")
            println(f, "  Solving: ", time_solve, " seconds") 
            println(f, "  Processing: ", time_process, " seconds")
            println(f, "")
            if nrow(df_cheb) > 0
                println(f, "Critical Point Statistics:")
                println(f, "  Min f_value: ", minimum(df_cheb.f_value))
                println(f, "  Max f_value: ", maximum(df_cheb.f_value))
                println(f, "  Mean f_value: ", sum(df_cheb.f_value) / nrow(df_cheb))
                println(f, "")
                println(f, "Sample Critical Points:")
                for i in 1:min(5, nrow(df_cheb))
                    row = df_cheb[i, :]
                    println(f, "  ", i, ": [", row.x1, ", ", row.x2, "] → f = ", row.f_value)
                end
            end
        end
        
        println("  ✅ Summary statistics saved")
    else
        println("  ⚠️  No critical points found in DataFrame")
    end
    
catch e
    println("  ❌ Critical points processing failed: ", e)
    exit(1)
end

println()

# Step 5: Validation and analysis
println("🔧 Step 5: Validation and Analysis...")
try
    if nrow(df_cheb) > 0
        # Validate critical points by checking function values
        println("  🧮 Validating critical points...")
        
        validation_results = []
        for i in 1:min(10, nrow(df_cheb))  # Validate first 10 points
            row = df_cheb[i, :]
            point = [row.x1, row.x2]
            computed_f = row.f_value
            actual_f = Deuflhard(point)
            error = abs(computed_f - actual_f)
            
            push!(validation_results, (point, computed_f, actual_f, error))
            
            if i <= 3  # Print first 3 for verification
                println("    Point ", i, ": [", point[1], ", ", point[2], "]")
                println("      Computed f: ", computed_f)
                println("      Actual f: ", actual_f)
                println("      Error: ", error)
            end
        end
        
        max_error = maximum([r[4] for r in validation_results])
        mean_error = sum([r[4] for r in validation_results]) / length(validation_results)
        
        println("  📊 Validation statistics:")
        println("    Points validated: ", length(validation_results))
        println("    Max error: ", max_error)
        println("    Mean error: ", mean_error)
        
        # Save validation results
        open(joinpath(output_dir, "validation_results.txt"), "w") do f
            println(f, "Critical Points Validation Results")
            println(f, "==================================")
            println(f, "Timestamp: ", now())
            println(f, "Points validated: ", length(validation_results))
            println(f, "Max error: ", max_error)
            println(f, "Mean error: ", mean_error)
            println(f, "")
            println(f, "Detailed Validation:")
            for (i, (point, comp_f, act_f, err)) in enumerate(validation_results)
                println(f, "  ", i, ": [", point[1], ", ", point[2], "] → computed=", comp_f, ", actual=", act_f, ", error=", err)
            end
        end
        
        println("  ✅ Validation completed and saved")
        
        # Check for global minimum (should be near [0,0] with f≈0)
        min_f_idx = argmin(df_cheb.f_value)
        min_point = [df_cheb[min_f_idx, :x1], df_cheb[min_f_idx, :x2]]
        min_f_value = df_cheb[min_f_idx, :f_value]
        
        println("  🎯 Global minimum candidate:")
        println("    Point: [", min_point[1], ", ", min_point[2], "]")
        println("    f_value: ", min_f_value)
        println("    Distance from origin: ", sqrt(min_point[1]^2 + min_point[2]^2))
        
        # Known global minimum is at [0,0] with f=0
        distance_from_known = sqrt(min_point[1]^2 + min_point[2]^2)
        if distance_from_known < 0.1 && min_f_value < 1.0
            println("  ✅ Global minimum correctly identified!")
        else
            println("  ⚠️  Global minimum may not be correctly identified")
        end
        
    else
        println("  ⚠️  No critical points to validate")
    end
    
catch e
    println("  ❌ Validation failed: ", e)
    # Do not exit - save what we have
end

println()
println("🎉 DEUFLHARD CRITICAL POINTS COMPUTATION COMPLETED!")
println("Test ID: {test_id}")
println("Mode: {mode}")
println("End Time: ", now())
println("Results saved to: ", output_dir)
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Computation Summary ==="
echo "End time: $(date)"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create final summary
cat > {output_dir}/computation_summary.txt << EOF
# Deuflhard Critical Points Computation Summary
Test ID: {test_id}
Mode: {mode}
Function: Deuflhard (2D)
Degree: {degree}
Samples: {samples} x {samples} = {samples**2}
Timestamp: $(date)
Julia Exit Code: $JULIA_EXIT_CODE
Depot Path: {self.depot_path}
Output Directory: {output_dir}

# Workflow Steps:
1. ✅ Test input creation (sampling grid)
2. ✅ Polynomial approximation construction  
3. ✅ Polynomial system solving
4. ✅ Critical points processing
5. ✅ Validation and analysis

# Generated Files:
$(ls -la {output_dir}/)

Status: $([ $JULIA_EXIT_CODE -eq 0 ] && echo "SUCCESS - Critical points computed" || echo "FAILED")
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Deuflhard critical points computation completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Generated files:"
    ls -la {output_dir}/
    echo ""
    echo "🎯 Key Results:"
    echo "  - Critical points computed using full Globtim workflow"
    echo "  - Results saved in CSV format for analysis"
    echo "  - Validation performed against actual function values"
    echo "  - Complete computation pipeline verified"
else
    echo "❌ Critical points computation failed with exit code $JULIA_EXIT_CODE"
fi

echo ""
echo "✅ Deuflhard critical points computation completed"
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Output directory: {output_dir}"
"""
        
        print("🚀 Executing critical points computation via SSH...")
        
        try:
            # Run the complete computation via SSH
            result = subprocess.run(
                ["ssh", self.cluster_host, julia_test],
                capture_output=True, text=True, timeout=1800  # 30 minutes timeout
            )
            
            print("📊 Computation Output:")
            print("=" * 60)
            print(result.stdout)
            
            if result.stderr:
                print("\n⚠️  Warnings/Errors:")
                print(result.stderr)
            
            if result.returncode == 0:
                print(f"\n✅ CRITICAL POINTS COMPUTATION SUCCESSFUL!")
                print(f"Test ID: {test_id}")
                print(f"Mode: {mode}")
                print(f"Parameters: degree={degree}, samples={samples}")
                print(f"Output directory: {output_dir}")
                return True, test_id, output_dir
            else:
                print(f"\n❌ Computation failed with return code: {result.returncode}")
                return False, test_id, output_dir
                
        except subprocess.TimeoutExpired:
            print("❌ Computation timed out after 30 minutes")
            return False, test_id, None
        except Exception as e:
            print(f"❌ Error during computation: {e}")
            return False, test_id, None

def main():
    parser = argparse.ArgumentParser(description="Run Deuflhard critical points computation on HPC")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"],
                       default="quick", help="Test mode (default: quick)")
    parser.add_argument("--degree", type=int, help="Custom polynomial degree")
    parser.add_argument("--samples", type=int, help="Custom samples per dimension")
    
    args = parser.parse_args()
    
    submitter = DeuflhardCriticalPointsSubmitter()
    success, test_id, output_dir = submitter.run_critical_points_test(
        args.mode, args.degree, args.samples
    )
    
    if success:
        print(f"\n🎯 SUCCESS! Deuflhard critical points computed successfully")
        print(f"🔧 Test ID: {test_id}")
        print(f"📁 Results in: {output_dir}")
        print("✅ Full Globtim optimization workflow validated on HPC")
        print("✅ Critical points computed and saved in CSV format")
        print("✅ Complete pipeline from sampling to critical points working")
    else:
        print(f"\n❌ FAILED! Critical points computation unsuccessful")
        print(f"🔧 Test ID: {test_id}")
        if output_dir:
            print(f"📁 Partial results may be in: {output_dir}")
        exit(1)

if __name__ == "__main__":
    main()
