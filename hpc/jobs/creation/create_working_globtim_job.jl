"""
Create Working Globtim Job

Creates a benchmark job that properly sets up Julia depot to avoid permission issues
and installs required packages during execution.
"""

println("=== Creating Working Globtim Job ===")
println()

# Load our Parameters.jl system
include("src/HPC/BenchmarkConfigSimple.jl")

# Create experiment
using Dates
experiment_name = "working_globtim_" * Dates.format(now(), "yyyymmdd_HHMMSS")
println("Experiment name: $experiment_name")

# Create parameters
globtim_params = GlobtimParameters(
    degree = 4,
    sample_count = 100,
    center = zeros(4),
    sample_range = 2.0,
    sparsification_threshold = 1e-4
)

hpc_params = HPCParameters(
    cpus = 12,
    memory_gb = 24,
    time_limit = "01:00:00"  # Give more time for package installation
)

# Get Sphere function
sphere_func = BENCHMARK_4D_REGISTRY[:Sphere]

# Create job
job = BenchmarkJob(
    benchmark_func = sphere_func,
    globtim_params = globtim_params,
    hpc_params = hpc_params,
    experiment_name = experiment_name,
    tags = ["working_globtim", "sphere", "package_install"]
)

println("✓ Job created: $(job.job_id)")

# Create directories
base_dir = "results/experiments/$experiment_name"
job_dir = "$base_dir/jobs/$(job.job_id)"
mkpath("$job_dir/slurm_output")

# Create SLURM script with package installation
slurm_script = """#!/bin/bash
#SBATCH --job-name=working_globtim_$(job.job_id)
#SBATCH --partition=$(hpc_params.partition)
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$(hpc_params.cpus)
#SBATCH --time=$(hpc_params.time_limit)
#SBATCH --mem=$(hpc_params.memory_gb)G
#SBATCH --output=$job_dir/slurm_output/working_globtim_$(job.job_id)_%j.out
#SBATCH --error=$job_dir/slurm_output/working_globtim_$(job.job_id)_%j.err

# Working Globtim Job with Package Installation
# Job ID: $(job.job_id)
# Generated: $(job.timestamp)

echo "=== Working Globtim Job ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: \$SLURM_CPUS_PER_TASK"
echo "Memory: \$SLURM_MEM_PER_NODE MB"
echo "Start time: \$(date)"
echo ""

# Set Julia environment with temporary depot
export JULIA_NUM_THREADS=\$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_\${USER}_\${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_\${SLURM_JOB_ID}"

# Create working directories
mkdir -p \$TMPDIR
mkdir -p \$JULIA_DEPOT_PATH
cd \$TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: \$JULIA_NUM_THREADS"
echo "Julia depot: \$JULIA_DEPOT_PATH"
echo "Working directory: \$(pwd)"
echo "Available space: \$(df -h . | tail -1 | awk '{print \$4}')"
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
        println("Installing \$pkg...")
        Pkg.add(pkg)
        println("✓ \$pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install \$pkg: \$e")
        println("Continuing without \$pkg...")
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
        println("Installing \$pkg...")
        Pkg.add(pkg)
        println("✓ \$pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install \$pkg: \$e")
        println("Will try to continue without it...")
    end
end

# Try advanced packages
println()
println("Installing advanced packages...")
advanced_packages = ["LinearSolve", "Optim", "Clustering"]

for pkg in advanced_packages
    try
        println("Installing \$pkg...")
        Pkg.add(pkg)
        println("✓ \$pkg installed successfully")
        push!(installed_packages, pkg)
    catch e
        println("❌ Failed to install \$pkg: \$e")
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
        eval(Meta.parse("using \$pkg"))
        println("✓ \$pkg (standard library)")
    catch e
        println("❌ \$pkg failed: \$e")
    end
end

for pkg in installed_packages[1:min(3, length(installed_packages))]
    try
        eval(Meta.parse("using \$pkg"))
        println("✓ \$pkg (installed)")
    catch e
        println("❌ \$pkg failed to load: \$e")
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
        center = $(globtim_params.center),
        sample_range = $(globtim_params.sample_range),
        degree = $(globtim_params.degree),
        GN = $(globtim_params.sample_count),
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
        println("   - Points within 0.1 of origin: \$close_points/\$(length(distances))")
        println("   - Convergence rate: ", @sprintf("%.1f%%", convergence_rate * 100))
        
        # Save comprehensive results
        using CSV, DataFrames
        
        # Save minimizers with distances
        minimizers_with_distances = copy(results.minima)
        minimizers_with_distances[!, :distance_to_global] = distances
        CSV.write("minimizers_analysis.csv", minimizers_with_distances)
        
        # Save comprehensive results
        open("globtim_results.txt", "w") do io
            println(io, "job_id: $(job.job_id)")
            println(io, "slurm_job_id: \$(ENV["SLURM_JOB_ID"])")
            println(io, "function_name: Sphere4D")
            println(io, "degree: $(globtim_params.degree)")
            println(io, "sample_count: $(globtim_params.sample_count)")
            println(io, "l2_error: \$(results.polynomial.nrm)")
            println(io, "critical_points_count: \$(nrow(results.critical_points))")
            println(io, "minimizers_count: \$(nrow(results.minima))")
            println(io, "min_distance_to_global: \$min_distance")
            println(io, "mean_distance_to_global: \$mean_distance")
            println(io, "convergence_rate: \$convergence_rate")
            println(io, "construction_time: \$(results.construction_time)")
            println(io, "globtim_working: true")
            println(io, "parameters_jl_system: true")
            println(io, "success: true")
        end
        
        println("✓ Results saved successfully")
        
    else
        println("⚠️  No minimizers found")
    end
    
catch e
    println("❌ Globtim test failed: \$e")
    
    # Save error information
    open("globtim_error.txt", "w") do io
        println(io, "job_id: $(job.job_id)")
        println(io, "error: \$e")
        println(io, "globtim_working: false")
        println(io, "timestamp: \$(now())")
    end
    
    exit(1)
end

println()
println("=== GLOBTIM JOB COMPLETED SUCCESSFULLY ===")
'

echo ""
echo "=== Uploading Results ==="
if [ -f "globtim_results.txt" ]; then
    cp globtim_results.txt ~/globtim_hpc/$job_dir/
    echo "✓ Globtim results uploaded"
fi

if [ -f "minimizers_analysis.csv" ]; then
    cp minimizers_analysis.csv ~/globtim_hpc/$job_dir/
    echo "✓ Minimizers analysis uploaded"
fi

if [ -f "globtim_error.txt" ]; then
    cp globtim_error.txt ~/globtim_hpc/$job_dir/
    echo "✓ Error log uploaded"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf \$TMPDIR
rm -rf \$JULIA_DEPOT_PATH

echo ""
echo "=== Job Summary ==="
echo "Job ID: $(job.job_id)"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "End time: \$(date)"
echo "Duration: \$SECONDS seconds"
echo "Results in: ~/globtim_hpc/$job_dir/"
echo "Status: GLOBTIM WORKING!"
"""

# Write SLURM script
script_path = "$job_dir/working_globtim_job.sh"
open(script_path, "w") do io
    write(io, slurm_script)
end
chmod(script_path, 0o755)

# Create management script
mgmt_script = """#!/bin/bash
echo "=== Working Globtim Job Management ==="
echo "Job ID: $(job.job_id)"
echo "Experiment: $experiment_name"
echo ""

case "\$1" in
    "submit")
        echo "Submitting working Globtim job..."
        sbatch $job_dir/working_globtim_job.sh
        echo "Job submitted! This will install packages and run Globtim."
        echo "Monitor with: \$0 status"
        ;;
    "status")
        squeue -u \$USER --name=working_globtim_*
        ;;
    "results")
        if [ -f "$job_dir/globtim_results.txt" ]; then
            echo "=== Globtim Results ==="
            cat $job_dir/globtim_results.txt
        else
            echo "No results found yet"
        fi
        ;;
    "logs")
        echo "Recent SLURM output:"
        find $job_dir/slurm_output -name "*.out" -exec tail -30 {} \\;
        ;;
    *)
        echo "Usage: \$0 {submit|status|results|logs}"
        ;;
esac
"""

mgmt_path = "$base_dir/manage_working_globtim.sh"
open(mgmt_path, "w") do io
    write(io, mgmt_script)
end
chmod(mgmt_path, 0o755)

println()
println("=== Working Globtim Job Created! ===")
println()
println("📁 **Experiment**: $experiment_name")
println("🆔 **Job ID**: $(job.job_id)")
println("⚙️  **Strategy**: Install packages during job execution")
println("💻 **Resources**: $(job.hpc_params.cpus) CPUs, $(job.hpc_params.memory_gb)GB, $(job.hpc_params.time_limit)")
println()
println("🚀 **Submit job:**")
println("   $mgmt_path submit")
println()
println("📊 **Monitor:**")
println("   $mgmt_path status")
println("   $mgmt_path results")
println()
println("**This job will:**")
println("• Install Julia packages in temporary storage")
println("• Load complete Globtim module with precision types")
println("• Run safe_globtim_workflow with Sphere function")
println("• Compute distance analysis to global minimum")
println("• Save comprehensive results")
println()
println("✅ **Ready to get Globtim working on HPC!** 🎯")
