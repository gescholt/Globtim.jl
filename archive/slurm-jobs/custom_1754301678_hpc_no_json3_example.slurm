#!/bin/bash
#SBATCH --job-name=custom_hpc_no_json3_example
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --output=custom_1754301678_hpc_no_json3_example_%j.out
#SBATCH --error=custom_1754301678_hpc_no_json3_example_%j.err

echo "🚀 Custom HPC Test: hpc_no_json3_example.jl"
echo "=================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: 2"
echo "Memory: 4G"
echo "Started: $(date)"
echo ""

# Set up Julia environment
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
mkdir -p "$JULIA_DEPOT_PATH"

echo "📦 Julia depot: $JULIA_DEPOT_PATH"
echo ""

# Use system Julia
export PATH="/sw/bin:$PATH"

echo "🔧 Julia version:"
julia --version
echo ""

echo "📁 Working directory: $(pwd)"
echo ""

# Setup project if Project.toml exists
if [ -f "Project_HPC.toml" ]; then
    echo "📦 Using HPC project configuration..."
    cp Project_HPC.toml Project.toml
elif [ ! -f "Project.toml" ]; then
    echo "📦 Creating minimal project..."
    echo 'name = "CustomTest"' > Project.toml
fi

echo "📦 Installing packages..."
julia --project=. -e "
using Pkg
Pkg.instantiate()
Pkg.precompile()
println(\"✅ Package setup complete\")
"

echo ""
echo "🚀 Running: hpc_no_json3_example.jl  --light"
echo "=================================="
julia --project=. hpc_no_json3_example.jl  --light

echo ""
echo "✅ Custom test completed"
echo "Finished: $(date)"
