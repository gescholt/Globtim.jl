#!/bin/bash
#SBATCH --job-name=julia_nfs_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:10:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem-per-cpu=2000
#SBATCH -o /stornext/snfs3/home/scholten/julia_nfs_test_%j.out
#SBATCH -e /stornext/snfs3/home/scholten/julia_nfs_test_%j.err

echo "=== Job Information ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Time: $(date)"

# Configure Julia for NFS depot
echo "=== Configuring Julia for NFS ==="
export NFS_BASE="/stornext/snfs3/home/scholten"
export JULIA_DEPOT_PATH="$NFS_BASE/julia_depot_nfs"
export TMPDIR="$NFS_BASE/tmp_nfs"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-2}
export JULIA_PKG_PRECOMPILE_AUTO=1

# Create temp directory if needed
mkdir -p "$TMPDIR"

echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Temp dir: $TMPDIR"

# Test Julia with NFS configuration
echo "=== Testing Julia ==="
julia --startup-file=no -e '
    println("Julia ", VERSION, " on ", gethostname())
    println("Depot: ", DEPOT_PATH[1])
    println("Temp: ", tempdir())
    println("Threads: ", Threads.nthreads())
    
    # Test basic computation
    A = rand(100, 100)
    B = A * A
    println("✅ Matrix computation successful: ", size(B))
    
    # Test package loading (if available)
    try
        using LinearAlgebra
        println("✅ LinearAlgebra loaded successfully")
    catch e
        println("⚠️  Package loading issue: ", e)
    end
'

echo "=== Job Complete ==="
