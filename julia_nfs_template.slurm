#!/bin/bash
#SBATCH --job-name=julia_nfs_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.out
#SBATCH -e /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.err

echo "=== Job Start: $(date) ==="
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Source NFS Julia configuration
source /stornext/snfs3/home/scholten/globtim_hpc/setup_nfs_julia.sh

# Verify configuration
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Temp dir: $TMPDIR"

# Navigate to project
cd ~/globtim_hpc

# Run test
julia --project=. -e '
    println("=== NFS Julia Test ===")
    using Pkg
    Pkg.status()
    
    # Test computation
    A = rand(100, 100)
    B = A * A
    println("✅ Computation successful: ", size(B))
    
    # Test file writing
    using Dates
    output_file = "/stornext/snfs3/home/scholten/globtim_results/test_$(Dates.now()).txt"
    write(output_file, "Test successful")
    println("✅ File written to NFS")
'

echo "=== Job Complete: $(date) ==="
