"""
Diagnostic Test for HPC Infrastructure

Very simple test to diagnose what's working and what's not.
"""

using Dates
using UUIDs

println("=== Creating Diagnostic Test ===")

# Create test directory
experiment_name = "diagnostic_" * Dates.format(now(), "yyyymmdd_HHMMSS")
job_id = string(uuid4())[1:8]
base_dir = "results/experiments/$experiment_name"
job_dir = "$base_dir/jobs/$job_id"

mkpath("$job_dir/slurm_output")

println("✓ Experiment: $experiment_name")
println("✓ Job ID: $job_id")

# Create diagnostic SLURM script
slurm_content = """#!/bin/bash
#SBATCH --job-name=diagnostic_""" * job_id * """
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --output=""" * job_dir * """/slurm_output/diagnostic_%j.out
#SBATCH --error=""" * job_dir * """/slurm_output/diagnostic_%j.err

echo "=== Diagnostic Test ==="
echo "Job ID: """ * job_id * """"
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Start time: \$(date)"
echo ""

# Set environment
export JULIA_NUM_THREADS=4
export JULIA_DEPOT_PATH="/tmp/julia_depot_\${USER}_\${SLURM_JOB_ID}"
export TMPDIR="/tmp/diagnostic_\${SLURM_JOB_ID}"

mkdir -p \$TMPDIR
cd \$TMPDIR

echo "=== Environment Check ==="
echo "Julia path: \$(which julia)"
echo "Julia version:"
/sw/bin/julia --version
echo ""

echo "=== Basic Julia Test ==="
/sw/bin/julia -e 'println("Julia is working!")'
echo ""

echo "=== Package Test ==="
/sw/bin/julia -e '
println("Testing basic packages...")
try
    using LinearAlgebra
    println("✓ LinearAlgebra loaded")
catch e
    println("✗ LinearAlgebra failed: \$e")
end

try
    using Statistics
    println("✓ Statistics loaded")
catch e
    println("✗ Statistics failed: \$e")
end

try
    using Random
    println("✓ Random loaded")
catch e
    println("✗ Random failed: \$e")
end
'
echo ""

echo "=== Globtim Source Test ==="
cp -r ~/globtim_hpc/src .
cp ~/globtim_hpc/Project_HPC.toml ./Project.toml

echo "Files copied:"
ls -la

echo ""
echo "=== Globtim Loading Test ==="
/sw/bin/julia --project=. -e '
println("Testing Globtim loading...")
try
    include("src/Structures.jl")
    println("✓ Structures.jl loaded")
catch e
    println("✗ Structures.jl failed: \$e")
end

try
    include("src/BenchmarkFunctions.jl")
    println("✓ BenchmarkFunctions.jl loaded")
catch e
    println("✗ BenchmarkFunctions.jl failed: \$e")
end

try
    include("src/LibFunctions.jl")
    println("✓ LibFunctions.jl loaded")
catch e
    println("✗ LibFunctions.jl failed: \$e")
end
'

echo ""
echo "=== Simple Math Test ==="
/sw/bin/julia -e '
using LinearAlgebra
println("Testing basic math...")
A = rand(3,3)
b = rand(3)
x = A \\ b
println("✓ Linear solve works: ||Ax - b|| = \$(norm(A*x - b))")
'

echo ""
echo "=== Results ==="
echo "Diagnostic completed at: \$(date)"
echo "Working directory was: \$(pwd)"
echo "Files created:"
ls -la

# Save a simple result
echo "diagnostic_success" > diagnostic_result.txt
cp diagnostic_result.txt ~/globtim_hpc/""" * job_dir * """/

echo ""
echo "=== Cleanup ==="
cd /
rm -rf \$TMPDIR
rm -rf \$JULIA_DEPOT_PATH

echo "Diagnostic test completed!"
"""

# Write script
script_path = "$job_dir/diagnostic.sh"
open(script_path, "w") do io
    write(io, slurm_content)
end
chmod(script_path, 0o755)

# Create helper
helper_content = """#!/bin/bash
case "\$1" in
    "submit")
        echo "Submitting diagnostic test..."
        sbatch """ * job_dir * """/diagnostic.sh
        ;;
    "status")
        squeue -u \$USER --name=diagnostic_*
        ;;
    "results")
        echo "=== Diagnostic Results ==="
        if [ -f \"""" * job_dir * """/diagnostic_result.txt\" ]; then
            echo "✓ Diagnostic completed successfully"
            cat """ * job_dir * """/diagnostic_result.txt
        else
            echo "No results yet"
        fi
        echo ""
        echo "=== Output Log ==="
        find """ * job_dir * """/slurm_output -name "*.out" -exec cat {} \\;
        echo ""
        echo "=== Error Log ==="
        find """ * job_dir * """/slurm_output -name "*.err" -exec cat {} \\;
        ;;
    *)
        echo "Usage: \$0 {submit|status|results}"
        ;;
esac
"""

helper_path = "$base_dir/diagnostic.sh"
open(helper_path, "w") do io
    write(io, helper_content)
end
chmod(helper_path, 0o755)

println("✓ Created diagnostic test: $helper_path")
println()
println("🔍 **Run diagnostic with:**")
println("   $helper_path submit")
println("   $helper_path results")
println()
println("This will test:")
println("• Julia installation and basic functionality")
println("• Package loading (LinearAlgebra, Statistics, Random)")
println("• Globtim source file loading")
println("• Basic mathematical operations")
println()
println("✅ **Diagnostic ready!**")
