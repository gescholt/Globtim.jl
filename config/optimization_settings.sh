#!/bin/bash
# Julia HPC Optimization Settings
# Created: August 11, 2025

# Performance optimization settings for sustained operation

echo "=== Julia HPC Optimization Settings ==="

# Julia Performance Tuning
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-$(nproc)}
export JULIA_PKG_PRECOMPILE_AUTO=1
export JULIA_PKG_USE_CLI_GIT=true

# Memory optimization
export JULIA_GC_HEURISTICS_WEAK_TENURE=1
export JULIA_GC_HEURISTICS_YOUNG_COLLECTION_THRESHOLD=0.5

# Compilation optimization
export JULIA_LLVM_ARGS="-enable-gvn-hoist"
export JULIA_CPU_TARGET="generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)"

# Network optimization for package downloads
export JULIA_PKG_SERVER="https://pkg.julialang.org"
export JULIA_PKG_SERVER_REGISTRY_PREFERENCE="eager"

# Depot optimization
if [[ $(hostname) == c* ]]; then
    # Compute node optimizations
    echo "Applying compute node optimizations..."
    
    # Use local depot for better I/O performance
    export JULIA_DEPOT_PATH="$HOME/.julia_local"
    
    # Optimize temp directory location
    export TMPDIR="$HOME/tmp_julia"
    export JULIA_TEMP="$TMPDIR"
    
    # Precompilation cache optimization
    export JULIA_PKG_PRECOMPILE_AUTO=1
    export JULIA_COMPILED_MODULES=yes
    
else
    # Login node optimizations
    echo "Applying login node optimizations..."
    
    # Use NFS depot with caching
    export JULIA_DEPOT_PATH="$HOME/.julia"
    
    # Optimize for interactive use
    export JULIA_HISTORY_FILE="$HOME/.julia_history"
    export JULIA_LOAD_PATH="@:@v#.#:@stdlib"
fi

# I/O optimization
export JULIA_IO_BUFFER_SIZE=65536

# Logging optimization
export JULIA_DEBUG=""  # Disable debug logging for performance

# Package compilation optimization
export JULIA_PKG_PRESERVE_TIERED_INSTALLED=true

# Function to optimize Julia depot
optimize_depot() {
    echo "=== Optimizing Julia Depot ==="
    
    local depot_path="$JULIA_DEPOT_PATH"
    
    if [ -d "$depot_path" ]; then
        echo "Depot path: $depot_path"
        
        # Clean up old precompilation cache
        echo "Cleaning old precompilation cache..."
        find "$depot_path/compiled" -name "*.ji" -mtime +30 -delete 2>/dev/null || true
        
        # Clean up old package downloads
        echo "Cleaning old package downloads..."
        find "$depot_path/packages" -name "*.tmp" -delete 2>/dev/null || true
        
        # Optimize package loading order
        if [ -f "$depot_path/environments/v$(julia -e 'print(VERSION.major, ".", VERSION.minor)')/Project.toml" ]; then
            echo "Environment file found - depot optimized for current Julia version"
        fi
        
        echo "✅ Depot optimization complete"
    else
        echo "⚠️  Depot path not found: $depot_path"
    fi
}

# Function to set up performance monitoring
setup_monitoring() {
    echo "=== Setting up Performance Monitoring ==="
    
    # Create monitoring directories
    mkdir -p "$HOME/julia_monitoring/logs"
    mkdir -p "$HOME/julia_monitoring/reports"
    
    # Set monitoring environment variables
    export JULIA_MONITOR_DIR="$HOME/julia_monitoring"
    export JULIA_PERFORMANCE_LOG="$JULIA_MONITOR_DIR/logs/performance.log"
    
    echo "✅ Monitoring setup complete"
}

# Function to apply HPC-specific optimizations
apply_hpc_optimizations() {
    echo "=== Applying HPC-Specific Optimizations ==="
    
    # SLURM integration
    if [ -n "$SLURM_JOB_ID" ]; then
        echo "Running in SLURM job: $SLURM_JOB_ID"
        
        # Use SLURM-provided resources
        export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
        
        # Optimize for batch processing
        export JULIA_BANNER=no
        export JULIA_STARTUP_FILE=no
        
        # Set job-specific temp directory
        export TMPDIR="/tmp/julia_job_$SLURM_JOB_ID"
        mkdir -p "$TMPDIR"
        
        echo "✅ SLURM optimizations applied"
    else
        echo "Running interactively - applying interactive optimizations"
        
        # Interactive optimizations
        export JULIA_BANNER=yes
        export JULIA_HISTORY_FILE="$HOME/.julia_history"
        
        echo "✅ Interactive optimizations applied"
    fi
}

# Function to verify optimizations
verify_optimizations() {
    echo "=== Verifying Optimizations ==="
    
    # Check Julia configuration
    julia --startup-file=no -e '
        println("Julia version: ", VERSION)
        println("Threads: ", Threads.nthreads())
        println("Depot: ", DEPOT_PATH[1])
        println("Temp: ", tempdir())
        
        # Check if optimizations are working
        if Threads.nthreads() > 1
            println("✅ Multi-threading enabled")
        else
            println("⚠️  Single-threaded mode")
        end
        
        if isdir(DEPOT_PATH[1])
            println("✅ Depot accessible")
        else
            println("❌ Depot not accessible")
        end
    ' 2>/dev/null && echo "✅ Optimization verification complete" || echo "❌ Optimization verification failed"
}

# Main optimization function
main() {
    echo "Applying Julia HPC optimizations..."
    echo "Node: $(hostname)"
    echo "User: $(whoami)"
    echo "Date: $(date)"
    echo ""
    
    # Apply optimizations
    optimize_depot
    setup_monitoring
    apply_hpc_optimizations
    
    # Verify everything is working
    verify_optimizations
    
    echo ""
    echo "=== Optimization Summary ==="
    echo "Julia threads: $JULIA_NUM_THREADS"
    echo "Depot path: $JULIA_DEPOT_PATH"
    echo "Temp directory: $TMPDIR"
    echo "Precompilation: $JULIA_PKG_PRECOMPILE_AUTO"
    echo "✅ All optimizations applied successfully"
}

# Run optimizations if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
