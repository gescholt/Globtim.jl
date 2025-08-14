#!/bin/bash
#SBATCH --job-name=julia_multi_user
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o julia_job_%j.out
#SBATCH -e julia_job_%j.err

# Multi-User Julia HPC Template
# Created: August 11, 2025
# Compatible with the Julia NFS migration infrastructure

echo "=== Multi-User Julia Job Template ==="
echo "Job ID: $SLURM_JOB_ID"
echo "User: $(whoami)"
echo "Node: $(hostname)"
echo "Start time: $(date)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo ""

# Function to detect and configure Julia environment
configure_julia_environment() {
    local user=$(whoami)
    local hostname=$(hostname)
    
    echo "=== Configuring Julia Environment ==="
    echo "User: $user"
    echo "Node type: $hostname"
    
    # Set basic Julia configuration
    export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
    export JULIA_PKG_PRECOMPILE_AUTO=1
    
    # User-specific depot configuration
    if [[ $hostname == c* ]]; then
        # Compute node - use local depot
        echo "Detected compute node"
        export JULIA_DEPOT_PATH="$HOME/.julia_local"
        export TMPDIR="$HOME/tmp_julia"
        
        # Create user-specific depot if it doesn't exist
        if [ ! -d "$HOME/.julia_local" ]; then
            echo "Creating local Julia depot for user $user..."
            mkdir -p "$HOME/.julia_local"
            
            # Try to copy from user's NFS depot if available
            if [ -d "$HOME/.julia" ]; then
                echo "Copying packages from NFS depot..."
                cp -r $HOME/.julia/* $HOME/.julia_local/ 2>/dev/null || echo "Creating fresh depot"
            fi
        fi
    else
        # Login node - use NFS depot (if available) or local
        echo "Detected login node"
        if [ -L "$HOME/.julia" ] && [ -d "$HOME/.julia" ]; then
            export JULIA_DEPOT_PATH="$HOME/.julia"
            echo "Using NFS depot via symbolic link"
        else
            export JULIA_DEPOT_PATH="$HOME/.julia_local"
            echo "Using local depot (NFS not available)"
        fi
        export TMPDIR="$HOME/tmp_julia"
    fi
    
    # Create temp directory
    mkdir -p "$TMPDIR" 2>/dev/null || true
    export TEMP="$TMPDIR"
    export TMP="$TMPDIR"
    
    echo "✅ Julia depot: $JULIA_DEPOT_PATH"
    echo "✅ Temp directory: $TMPDIR"
    echo "✅ Threads: $JULIA_NUM_THREADS"
    echo "=== Configuration Complete ==="
}

# Function to verify Julia installation
verify_julia() {
    echo "=== Verifying Julia Installation ==="
    
    if command -v julia >/dev/null 2>&1; then
        echo "✅ Julia found: $(which julia)"
        julia --version
        
        # Test basic functionality
        julia --startup-file=no -e 'println("✅ Julia basic functionality working")' 2>/dev/null || {
            echo "❌ Julia basic test failed"
            return 1
        }
        
        # Test depot accessibility
        julia --startup-file=no -e 'println("✅ Depot accessible: ", isdir(DEPOT_PATH[1]))' 2>/dev/null || {
            echo "❌ Julia depot not accessible"
            return 1
        }
        
        echo "✅ Julia verification complete"
        return 0
    else
        echo "❌ Julia not found in PATH"
        return 1
    fi
}

# Function to run user's Julia code
run_julia_code() {
    echo "=== Running Julia Code ==="
    
    # Check if user provided a Julia script
    if [ -n "$JULIA_SCRIPT" ]; then
        echo "Running user script: $JULIA_SCRIPT"
        julia --project=. "$JULIA_SCRIPT"
    elif [ -n "$JULIA_CODE" ]; then
        echo "Running inline Julia code"
        julia --project=. -e "$JULIA_CODE"
    else
        echo "Running default Julia test"
        julia --project=. -e '
            println("=== Default Julia Test ===")
            println("Julia ", VERSION, " on ", gethostname())
            println("User: ", ENV["USER"])
            println("Depot: ", DEPOT_PATH[1])
            println("Threads: ", Threads.nthreads())
            
            # Test basic computation
            A = rand(100, 100)
            B = A * A
            println("✅ Matrix computation successful: ", size(B))
            
            # Test package loading
            try
                using Pkg
                println("✅ Pkg loaded successfully")
            catch e
                println("⚠️  Pkg loading issue: ", e)
            end
            
            println("=== Test Complete ===")
        '
    fi
}

# Main execution
main() {
    # Configure Julia environment
    configure_julia_environment
    
    # Verify Julia installation
    if ! verify_julia; then
        echo "❌ Julia verification failed - aborting job"
        exit 1
    fi
    
    # Run Julia code
    run_julia_code
    
    echo ""
    echo "=== Job Summary ==="
    echo "End time: $(date)"
    echo "Duration: $SECONDS seconds"
    echo "User: $(whoami)"
    echo "Node: $(hostname)"
    echo "✅ Job completed successfully"
}

# Execute main function
main

# Usage Instructions (commented out):
# 
# To use this template:
# 1. Copy to your project directory
# 2. Customize the SBATCH parameters as needed
# 3. Set environment variables for your Julia code:
#    export JULIA_SCRIPT="path/to/your/script.jl"
#    # OR
#    export JULIA_CODE="println(\"Hello from Julia!\")"
# 4. Submit with: sbatch multi_user_julia_template.slurm
#
# Example customization:
# #SBATCH --time=02:00:00        # Increase time limit
# #SBATCH -c 8                   # Use 8 CPUs
# #SBATCH --mem-per-cpu=4000     # Use 4GB per CPU
# #SBATCH --partition=long       # Use long partition
