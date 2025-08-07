#!/usr/bin/env python3

"""
Deuflhard Critical Points - Working HPC Version
===============================================

Runs the complete Deuflhard critical points computation on HPC using
the exact workflow from the local test suite (runtests.jl).

This version avoids Julia syntax issues and uses the proven approach.

Usage:
    python run_deuflhard_critical_points.py [--degree DEGREE] [--samples SAMPLES]
"""

import argparse
import subprocess
import uuid
from datetime import datetime

class DeuflhardCriticalPointsRunner:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
    
    def run_computation(self, degree=22, samples=120):
        """Run the complete critical points computation"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🧮 Deuflhard Critical Points Computation")
        print(f"Degree: {degree}")
        print(f"Samples: {samples} x {samples} = {samples**2} total")
        print(f"Test ID: {test_id}")
        print()
        
        # Create output directory
        output_dir = f"/tmp/deuflhard_critical_points_{test_id}"
        
        # Create Julia script file to avoid shell escaping issues
        julia_script = f"""
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
    using StaticArrays, LinearAlgebra
    using DataFrames, CSV
    using DynamicPolynomials
    using TimerOutputs
    using LinearSolve
    println("  ✅ Core packages loaded successfully")

    # Initialize timer (required for Globtim functions)
    global _TO = TimerOutputs.TimerOutput()
    println("  ✅ Timer initialized")

    # Define precision types (required for Structures.jl)
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    println("  ✅ Precision types defined")

    # Load Globtim modules (use absolute paths in dependency order)
    include("/home/scholten/globtim_hpc/src/config.jl")
    println("  ✅ config.jl loaded")

    include("/home/scholten/globtim_hpc/src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")

    include("/home/scholten/globtim_hpc/src/LibFunctions.jl")
    println("  ✅ LibFunctions.jl loaded")

    include("/home/scholten/globtim_hpc/src/Structures.jl")
    println("  ✅ Structures.jl loaded")

    include("/home/scholten/globtim_hpc/src/scaling_utils.jl")
    println("  ✅ scaling_utils.jl loaded")

    include("/home/scholten/globtim_hpc/src/Samples.jl")
    println("  ✅ Samples.jl loaded")

    include("/home/scholten/globtim_hpc/src/l2_norm.jl")
    println("  ✅ l2_norm.jl loaded")

    include("/home/scholten/globtim_hpc/src/ApproxConstruct.jl")
    println("  ✅ ApproxConstruct.jl loaded")

    include("/home/scholten/globtim_hpc/src/lambda_vandermonde_anisotropic.jl")
    println("  ✅ lambda_vandermonde_anisotropic.jl loaded")

    include("/home/scholten/globtim_hpc/src/OrthogonalInterface.jl")
    println("  ✅ OrthogonalInterface.jl loaded")

    include("/home/scholten/globtim_hpc/src/cheb_pol.jl")
    println("  ✅ cheb_pol.jl loaded")

    include("/home/scholten/globtim_hpc/src/Main_Gen.jl")
    println("  ✅ Main_Gen.jl loaded")
    
    println("  ✅ All modules loaded successfully")
    
catch e
    println("  ❌ Module loading failed: ", e)
    exit(1)
end

println()

# Step 1: Create test input (following runtests.jl exactly)
println("🔧 Step 1: Creating Test Input...")

# Define variables at global scope
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
global TR = nothing
try
    global TR = test_input(
        f,
        dim = n,
        center = [0.0, 0.0],
        GN = SMPL,
        sample_range = scale_factor,
        tolerance = nothing
    )

    println("  ✅ Test input created successfully")
    println("  ✅ Sampling grid generated: ", SMPL^n, " points")

catch e
    println("  ❌ Test input creation failed: ", e)
    exit(1)
end

println()

# Step 2: Construct polynomial approximation
println("🔧 Step 2: Constructing Polynomial Approximation...")

global pol_cheb = nothing
try
    time_construct = @elapsed begin
        global pol_cheb = Constructor(TR, d, basis = :chebyshev, normalized = false)
    end

    println("  ✅ Chebyshev polynomial constructed")
    println("  ⏱️  Construction time: ", time_construct, " seconds")
    println("  📊 Coefficient count: ", length(pol_cheb.coeffs))

catch e
    println("  ❌ Polynomial construction failed: ", e)
    exit(1)
end

println()

# Step 3: Solve polynomial system for critical points
println("🔧 Step 3: Solving Polynomial System for Critical Points...")

global real_pts_cheb = nothing
try
    @polyvar(x[1:n]) # Define polynomial ring

    time_solve = @elapsed begin
        global real_pts_cheb = solve_polynomial_system(
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
    else
        println("  ⚠️  No critical points found")
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
        
        # Find global minimum
        min_f_idx = argmin(df_cheb.f_value)
        min_point = [df_cheb[min_f_idx, :x1], df_cheb[min_f_idx, :x2]]
        min_f_value = df_cheb[min_f_idx, :f_value]
        
        println("  🎯 Global minimum found:")
        println("    Point: [", min_point[1], ", ", min_point[2], "]")
        println("    f_value: ", min_f_value)
        
        # Save summary
        open(joinpath(output_dir, "critical_points_summary.txt"), "w") do f
            println(f, "Deuflhard Critical Points Summary")
            println(f, "=================================")
            println(f, "Test ID: {test_id}")
            println(f, "Degree: {degree}")
            println(f, "Samples: {samples} x {samples} = {samples**2}")
            println(f, "Critical points found: ", nrow(df_cheb))
            println(f, "")
            println(f, "Global minimum:")
            println(f, "  Point: [", min_point[1], ", ", min_point[2], "]")
            println(f, "  f_value: ", min_f_value)
            println(f, "")
            println(f, "Performance:")
            println(f, "  Construction: ", time_construct, " seconds")
            println(f, "  Solving: ", time_solve, " seconds")
            println(f, "  Processing: ", time_process, " seconds")
            println(f, "  Total: ", time_construct + time_solve + time_process, " seconds")
        end
        
        println("  ✅ Summary saved")
    else
        println("  ⚠️  No critical points found in DataFrame")
    end
    
catch e
    println("  ❌ Critical points processing failed: ", e)
    exit(1)
end

println()
println("🎉 DEUFLHARD CRITICAL POINTS COMPUTATION COMPLETED!")
println("Test ID: {test_id}")
println("End Time: ", now())
println("Results saved to: ", output_dir)
"""
        
        # Create the complete command
        julia_command = f"""
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"
cd {self.remote_dir}

echo "🧮 Deuflhard Critical Points - {test_id}"
echo "Degree: {degree}, Samples: {samples}"
echo "Timestamp: $(date)"
echo ""

# Create output directory
mkdir -p {output_dir}

# Create Julia script to avoid shell escaping
cat > /tmp/deuflhard_script_{test_id}.jl << 'JULIA_EOF'
{julia_script}
JULIA_EOF

# Run the Julia script
/sw/bin/julia --project=. /tmp/deuflhard_script_{test_id}.jl

JULIA_EXIT_CODE=$?

# Clean up script
rm -f /tmp/deuflhard_script_{test_id}.jl

# Create final summary
cat > {output_dir}/computation_summary.txt << EOF
# Deuflhard Critical Points Computation Summary
Test ID: {test_id}
Degree: {degree}
Samples: {samples} x {samples} = {samples**2}
Timestamp: $(date)
Julia Exit Code: $JULIA_EXIT_CODE
Depot Path: {self.depot_path}
Output Directory: {output_dir}

Status: $([ $JULIA_EXIT_CODE -eq 0 ] && echo "SUCCESS" || echo "FAILED")

# Generated Files:
$(ls -la {output_dir}/ 2>/dev/null || echo "No files generated")
EOF

echo ""
echo "=== Final Summary ==="
echo "Julia exit code: $JULIA_EXIT_CODE"
echo "Test ID: {test_id}"
echo "Output: {output_dir}"

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Critical points computation successful"
    echo "📁 Results:"
    ls -la {output_dir}/
else
    echo "❌ Critical points computation failed"
fi
"""
        
        print("🚀 Executing critical points computation...")
        
        try:
            result = subprocess.run(
                ["ssh", self.cluster_host, julia_command],
                capture_output=True, text=True, timeout=1800
            )
            
            print("📊 Computation Output:")
            print("=" * 60)
            print(result.stdout)
            
            if result.stderr:
                print("\n⚠️  Warnings/Errors:")
                print(result.stderr)
            
            return result.returncode == 0, test_id, output_dir
            
        except subprocess.TimeoutExpired:
            print("❌ Computation timed out")
            return False, test_id, None
        except Exception as e:
            print(f"❌ Error: {e}")
            return False, test_id, None

def main():
    parser = argparse.ArgumentParser(description="Run Deuflhard critical points computation")
    parser.add_argument("--degree", type=int, default=22, help="Polynomial degree (default: 22)")
    parser.add_argument("--samples", type=int, default=120, help="Samples per dimension (default: 120)")
    
    args = parser.parse_args()
    
    runner = DeuflhardCriticalPointsRunner()
    success, test_id, output_dir = runner.run_computation(args.degree, args.samples)
    
    if success:
        print(f"\n🎯 SUCCESS! Critical points computed")
        print(f"Test ID: {test_id}")
        print(f"Results: {output_dir}")
    else:
        print(f"\n❌ FAILED! Computation unsuccessful")
        exit(1)

if __name__ == "__main__":
    main()
