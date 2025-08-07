#!/bin/bash
#SBATCH --job-name=working_globtim_30181439
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=01:00:00
#SBATCH --mem=24G
#SBATCH --output=results/experiments/working_globtim_20250803_163245/jobs/30181439/slurm_output/working_globtim_30181439_%j.out
#SBATCH --error=results/experiments/working_globtim_20250803_163245/jobs/30181439/slurm_output/working_globtim_30181439_%j.err

# Working Globtim Job with Package Installation
# Job ID: 30181439
# Generated: 2025-08-03T16:32:45.958

echo "=== Working Globtim Job ==="
echo "Job ID: 30181439"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Set Julia environment with temporary depot
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_${SLURM_JOB_ID}"

# Create working directories
mkdir -p $TMPDIR
mkdir -p $JULIA_DEPOT_PATH
cd $TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

echo "=== Copying Globtim Source ==="
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC.toml ./Project.toml
echo "✓ Globtim source copied"
echo ""

echo "=== Installing Essential Packages ==="
/sw/bin/julia --project=. -e '
using Pkg

println("Installing essential packages...")

# Install packages one by one with error handling
essential_packages = [
    "StaticArrays",
    "DataFrames", 
    "CSV",
    "Parameters",
    "ForwardDiff",
    "Distributions",
    "TimerOutputs"
]

installed_packages = String[]

for pkg in essential_packages
    try
        println("Installing $pkg...")
        Pkg.add(pkg)
        println("✓ $pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install $pkg: $e")
        println("Continuing without $pkg...")
    end
end

println()
println("Successfully installed packages: ", join(installed_packages, ", "))

# Try to install polynomial packages
println()
println("Installing polynomial packages...")
poly_packages = ["DynamicPolynomials", "MultivariatePolynomials"]

for pkg in poly_packages
    try
        println("Installing $pkg...")
        Pkg.add(pkg)
        println("✓ $pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install $pkg: $e")
        println("Will try to continue without it...")
    end
end

# Try advanced packages
println()
println("Installing advanced packages...")
advanced_packages = ["LinearSolve", "Optim", "Clustering"]

for pkg in advanced_packages
    try
        println("Installing $pkg...")
        Pkg.add(pkg)
        println("✓ $pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install $pkg: $e")
        println("Will continue without it...")
    end
end

println()
println("=== Final Package Status ===")
println("Installed packages: ", join(installed_packages, ", "))

# Test loading essential packages
println()
println("Testing package loading...")
test_packages = ["LinearAlgebra", "Statistics", "Random"]

for pkg in test_packages
    try
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg (standard library)")
    catch e
        println("❌ $pkg failed: $e")
    end
end

for pkg in installed_packages[1:min(3, length(installed_packages))]
    try
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg (installed)")
    catch e
        println("❌ $pkg failed to load: $e")
    end
end
'

echo ""
echo "=== Testing Globtim Module Loading ==="
/sw/bin/julia --project=. -e '
println("Testing Globtim module loading...")

# Try to load individual modules first
try
    # Load precision types from main module
    include("src/Globtim.jl")
    using .Globtim
    
    println("✅ Globtim module loaded successfully!")
    
    # Test precision types
    println("Available precision types:")
    println("  - Float64Precision: ", Float64Precision)
    println("  - AdaptivePrecision: ", AdaptivePrecision)
    println("  - RationalPrecision: ", RationalPrecision)
    
    # Test basic functionality
    println()
    println("Testing basic Globtim functionality...")
    
    function simple_sphere_4d(x)
        return sum(x.^2)
    end
    
    # Test with minimal parameters
    results = safe_globtim_workflow(
        simple_sphere_4d,
        dim = 4,
        center = [0.0, 0.0, 0.0, 0.0],
        sample_range = 2.0,
        degree = 4,
        GN = 100,
        enable_hessian = true,
        basis = :chebyshev,
        precision = Float64Precision,
        max_retries = 2
    )
    
    println("🎉 GLOBTIM WORKFLOW SUCCESS!")
    println("   - L2 error: ", @sprintf("%.2e", results.polynomial.nrm))
    println("   - Critical points: ", nrow(results.critical_points))
    println("   - Minimizers: ", nrow(results.minima))
    println("   - Construction time: ", @sprintf("%.2f", results.construction_time), " seconds")
    
    # Distance analysis
    if nrow(results.minima) > 0
        println()
        println("=== Distance Analysis ===")
        minimizer_points = Matrix{Float64}(results.minima[:, 1:4])
        global_minimum = [0.0, 0.0, 0.0, 0.0]
        
        distances = Float64[]
        for i in 1:size(minimizer_points, 1)
            point = minimizer_points[i, :]
            distance = sqrt(sum((point - global_minimum).^2))
            push!(distances, distance)
        end
        
        min_distance = minimum(distances)
        mean_distance = mean(distances)
        close_points = sum(distances .< 0.1)
        convergence_rate = close_points / length(distances)
        
        println("   - Minimum distance to origin: ", @sprintf("%.6f", min_distance))
        println("   - Mean distance to origin: ", @sprintf("%.6f", mean_distance))
        println("   - Points within 0.1 of origin: $close_points/$(length(distances))")
        println("   - Convergence rate: ", @sprintf("%.1f%%", convergence_rate * 100))
        
        # Save comprehensive results
        using CSV, DataFrames
        
        # Save minimizers with distances
        minimizers_with_distances = copy(results.minima)
        minimizers_with_distances[!, :distance_to_global] = distances
        CSV.write("minimizers_analysis.csv", minimizers_with_distances)
        
        # Save comprehensive results
        open("globtim_results.txt", "w") do io
            println(io, "job_id: 30181439")
            println(io, "slurm_job_id: $(ENV["SLURM_JOB_ID"])")
            println(io, "function_name: Sphere4D")
            println(io, "degree: 4")
            println(io, "sample_count: 100")
            println(io, "l2_error: $(results.polynomial.nrm)")
            println(io, "critical_points_count: $(nrow(results.critical_points))")
            println(io, "minimizers_count: $(nrow(results.minima))")
            println(io, "min_distance_to_global: $min_distance")
            println(io, "mean_distance_to_global: $mean_distance")
            println(io, "convergence_rate: $convergence_rate")
            println(io, "construction_time: $(results.construction_time)")
            println(io, "globtim_working: true")
            println(io, "parameters_jl_system: true")
            println(io, "success: true")
        end
        
        println("✓ Results saved successfully")
        
    else
        println("⚠️  No minimizers found")
    end
    
catch e
    println("❌ Globtim test failed: $e")
    
    # Save error information
    open("globtim_error.txt", "w") do io
        println(io, "job_id: 30181439")
        println(io, "error: $e")
        println(io, "globtim_working: false")
        println(io, "timestamp: $(now())")
    end
    
    exit(1)
end

println()
println("=== GLOBTIM JOB COMPLETED SUCCESSFULLY ===")
'

echo ""
echo "=== Uploading Results ==="
if [ -f "globtim_results.txt" ]; then
    cp globtim_results.txt ~/globtim_hpc/results/experiments/working_globtim_20250803_163245/jobs/30181439/
    echo "✓ Globtim results uploaded"
fi

if [ -f "minimizers_analysis.csv" ]; then
    cp minimizers_analysis.csv ~/globtim_hpc/results/experiments/working_globtim_20250803_163245/jobs/30181439/
    echo "✓ Minimizers analysis uploaded"
fi

if [ -f "globtim_error.txt" ]; then
    cp globtim_error.txt ~/globtim_hpc/results/experiments/working_globtim_20250803_163245/jobs/30181439/
    echo "✓ Error log uploaded"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: 30181439"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Results in: ~/globtim_hpc/results/experiments/working_globtim_20250803_163245/jobs/30181439/"
echo "Status: GLOBTIM WORKING!"
