#!/bin/bash
#SBATCH --job-name=deuflhard_critical_points_54b099bc
#SBATCH --output=~/globtim_hpc/results/critical_points_54b099bc/slurm_%j.out
#SBATCH --error=~/globtim_hpc/results/critical_points_54b099bc/slurm_%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4
#SBATCH --partition=batch

echo "🚀 Deuflhard Critical Points Computation - Fileserver Integration"
echo "=================================================================="
echo "Test ID: 54b099bc"
echo "Timestamp: $(date -Iseconds)"
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 8G"
echo ""

# Setup environment
export JULIA_DEPOT_PATH="/globtim_hpc/julia_depot"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Create output directory
mkdir -p ~/globtim_hpc/results/critical_points_54b099bc
cd ~/globtim_hpc

# Create test configuration
cat > ~/globtim_hpc/results/critical_points_54b099bc/critical_points_config.json << 'EOF'
{
  "test_id": "54b099bc",
  "timestamp": "$(date -Iseconds)",
  "test_type": "deuflhard_critical_points_fileserver",
  "execution_mode": "slurm_fileserver_nfs",
  "function": "Deuflhard",
  "dimension": 2,
  "parameters": {
    "degree": 8,
    "samples": 50,
    "total_samples": 2500,
    "center": [0.0, 0.0],
    "sample_range": 1.4,
    "basis": "chebyshev",
    "normalized": false
  },
  "metadata": {
    "created_by": "submit_deuflhard_critical_points_fileserver.py",
    "purpose": "Fileserver-integrated critical points computation",
    "results_base": "~/globtim_hpc/results",
    "depot_path": "/globtim_hpc/julia_depot",
    "expected_runtime": "00:30:00"
  }
}
EOF

echo "📋 Configuration saved to ~/globtim_hpc/results/critical_points_54b099bc/critical_points_config.json"

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

println("📦 Packages loaded successfully")

# Test parameters
n = 2
d = 8
f = Deuflhard
output_dir = "~/globtim_hpc/results/critical_points_54b099bc"

println("🎯 Test Parameters:")
println("  Function: Deuflhard")
println("  Dimension: \$n")
println("  Degree: \$d")
println("  Samples: 50")
println("  Output: \$output_dir")
println()

# Step 1: Create test input
println("🔧 Step 1: Creating Test Input...")
try
    global TR = test_input(
        f,
        dim = n,
        center = [0.0, 0.0],
        sample_range = 1.4
    )
    println("  ✅ Test input created successfully")
    println("  📊 Dimension: ", TR.dim)
    println("  📍 Center: ", TR.center)
    println("  📏 Sample range: ", TR.sample_range)
catch e
    println("  ❌ Test input creation failed: ", e)
    exit(1)
end

# Step 2: Construct polynomial approximation
println("\n🔧 Step 2: Constructing Polynomial Approximation...")
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
    
    println("  ✅ Polynomial constructed successfully")
    println("  ⏱️  Construction time: ", time_construct, " seconds")
    println("  📊 L2 error: ", pol_cheb.nrm)
    println("  📈 Condition number: ", pol_cheb.cond_vandermonde)
    println("  🎯 Final degree: ", pol_cheb.degree)
catch e
    println("  ❌ Polynomial construction failed: ", e)
    exit(1)
end

# Step 3: Solve polynomial system for critical points
println("\n🔧 Step 3: Solving Polynomial System for Critical Points...")
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

# Step 4: Process critical points into DataFrame
println("\n🔧 Step 4: Processing Critical Points...")
try
    time_process = @elapsed begin
        global df_cheb = process_crit_pts(real_pts_cheb, f, TR; skip_filtering = false)
    end
    
    println("  ✅ Critical points processed into DataFrame")
    println("  ⏱️  Processing time: ", time_process, " seconds")
    println("  📊 DataFrame rows: ", nrow(df_cheb))
    println("  📋 DataFrame columns: ", names(df_cheb))
    
    if nrow(df_cheb) > 0
        println("  📍 Sample critical point data:")
        println("    x1: ", df_cheb[1, :x1])
        println("    x2: ", df_cheb[1, :x2])
        println("    z: ", df_cheb[1, :z])
        
        # Save critical points to CSV
        CSV.write(joinpath(output_dir, "critical_points.csv"), df_cheb)
        println("  ✅ Critical points saved to CSV")
        
        # Find best point (minimum function value)
        min_idx = argmin(df_cheb.z)
        best_point = [df_cheb[min_idx, :x1], df_cheb[min_idx, :x2]]
        best_value = df_cheb[min_idx, :z]
        
        println("  🎯 Best critical point: ", best_point)
        println("  📊 Best function value: ", best_value)
        
        # Distance to origin (known global minimum for Deuflhard)
        distance_to_origin = norm(best_point)
        println("  📏 Distance to origin: ", distance_to_origin)
        
    else
        println("  ⚠️  No valid critical points after processing")
    end
    
catch e
    println("  ❌ Critical points processing failed: ", e)
    exit(1)
end

# Step 5: Create validation summary
println("\n🔧 Step 5: Creating Validation Summary...")
try
    summary = Dict(
        "test_id" => "54b099bc",
        "timestamp" => string(now()),
        "success" => true,
        "parameters" => Dict(
            "degree" => pol_cheb.degree,
            "samples" => 50,
            "dimension" => n
        ),
        "results" => Dict(
            "l2_error" => pol_cheb.nrm,
            "condition_number" => pol_cheb.cond_vandermonde,
            "num_critical_points" => length(real_pts_cheb),
            "num_processed_points" => nrow(df_cheb)
        )
    )
    
    if nrow(df_cheb) > 0
        summary["results"]["best_point"] = best_point
        summary["results"]["best_value"] = best_value
        summary["results"]["distance_to_origin"] = distance_to_origin
        summary["results"]["accuracy_check"] = distance_to_origin < 0.1
    end
    
    # Save summary as JSON
    open(joinpath(output_dir, "validation_summary.json"), "w") do f
        JSON3.pretty(f, summary)
    end
    
    # Save human-readable summary
    open(joinpath(output_dir, "validation_results.txt"), "w") do f
        println(f, "Deuflhard Critical Points Validation Results")
        println(f, "===========================================")
        println(f, "Test ID: 54b099bc")
        println(f, "Timestamp: ", string(now()))
        println(f, "")
        println(f, "Parameters:")
        println(f, "  Degree: ", pol_cheb.degree)
        println(f, "  Samples: 50")
        println(f, "  Dimension: ", n)
        println(f, "")
        println(f, "Results:")
        println(f, "  L2 Error: ", pol_cheb.nrm)
        println(f, "  Condition Number: ", pol_cheb.cond_vandermonde)
        println(f, "  Critical Points Found: ", length(real_pts_cheb))
        println(f, "  Processed Points: ", nrow(df_cheb))
        
        if nrow(df_cheb) > 0
            println(f, "  Best Point: ", best_point)
            println(f, "  Best Value: ", best_value)
            println(f, "  Distance to Origin: ", distance_to_origin)
            println(f, "  Accuracy Check (< 0.1): ", distance_to_origin < 0.1)
        end
    end
    
    println("  ✅ Validation summary saved")
    
catch e
    println("  ❌ Validation summary creation failed: ", e)
    exit(1)
end

println("\n🎉 Critical points computation completed successfully!")
println("📁 Results saved to: \$output_dir")
"

echo "✅ Julia computation completed with exit code: $?"
echo "📁 Final results:"
ls -la ~/globtim_hpc/results/critical_points_54b099bc/

echo "🎯 Critical points computation finished!"
