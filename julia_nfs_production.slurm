#!/bin/bash
#SBATCH --job-name=julia_nfs_production
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o ~/julia_nfs_production_%j.out
#SBATCH -e ~/julia_nfs_production_%j.err

echo "=== Julia NFS Production Job Start: $(date) ==="
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CPUs: $SLURM_CPUS_PER_TASK"

# Navigate to project directory
cd ~/globtim_hpc

# Source NFS Julia configuration
echo "=== Configuring Julia for NFS ==="
source ./setup_nfs_julia.sh

# Verify Julia configuration
echo "=== Verifying Julia Configuration ==="
julia --startup-file=no -e '
    println("Julia ", VERSION, " on ", gethostname())
    println("Depot: ", DEPOT_PATH[1])
    println("Temp: ", tempdir())
    println("Threads: ", Threads.nthreads())
    
    # Verify NFS depot is accessible
    depot_path = DEPOT_PATH[1]
    if isdir(depot_path)
        println("✅ NFS depot accessible: ", depot_path)
    else
        println("❌ NFS depot not accessible: ", depot_path)
        exit(1)
    end
'

# Test package operations
echo "=== Testing Package Operations ==="
julia --project=. -e '
    using Pkg
    println("=== Package Status ===")
    Pkg.status()
    
    # Test basic computation
    println("=== Testing Computation ===")
    A = rand(1000, 1000)
    B = A * A
    println("✅ Matrix computation successful: ", size(B))
    
    # Test file I/O to NFS
    println("=== Testing NFS File I/O ===")
    using Dates
    test_file = "/stornext/snfs3/home/scholten/globtim_results/production_test_$(Dates.now()).txt"
    write(test_file, "Production test successful at $(Dates.now())")
    if isfile(test_file)
        println("✅ File written to NFS: ", test_file)
    else
        println("❌ Failed to write to NFS")
        exit(1)
    end
'

echo "=== Job Complete: $(date) ==="
