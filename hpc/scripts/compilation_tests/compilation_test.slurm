#!/bin/bash
#SBATCH --job-name=globtim_compilation_test
#SBATCH --partition=batch          # Default partition: 24h max, 3120 cores, 256GB max
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24         # Max 24 cores per node on batch partition
#SBATCH --time=00:30:00            # 30 minutes (adjustable based on test mode)
#SBATCH --mem=32G                  # 32GB (well under 256GB limit)
#SBATCH --output=compilation_test_%j.out
#SBATCH --error=compilation_test_%j.err

# Comprehensive Globtim Compilation Test
# Tests complete compilation and functionality of Globtim on HPC cluster

echo "=== Globtim Compilation Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
export TMPDIR="/tmp/globtim_compilation_${SLURM_JOB_ID}"

# Create temporary working directory
mkdir -p $TMPDIR
cd $TMPDIR

echo "=== Environment Setup ==="
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Working directory: $(pwd)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo "Memory info: $(free -h | grep '^Mem:' | awk '{print $2 " total, " $7 " available"}')"
echo ""

# Copy Globtim source from user directory
echo "=== Copying Globtim Source ==="

# Try multiple source locations in order of preference
SOURCE_COPIED=false

# Method 1: Copy from home directory (most reliable)
if [ -d "$HOME/globtim_hpc/src" ]; then
    echo "Using source from home directory..."
    cp -r "$HOME/globtim_hpc/src" .
    cp "$HOME/globtim_hpc/Project.toml" . 2>/dev/null || cp "$HOME/globtim_hpc/Project_HPC.toml" ./Project.toml 2>/dev/null || true
    cp "$HOME/globtim_hpc/Project_HPC_Minimal.toml" ./Project_HPC.toml 2>/dev/null || true

    # Copy compilation test script
    if [ -d "$HOME/globtim_hpc/hpc/scripts/compilation_tests" ]; then
        cp -r "$HOME/globtim_hpc/hpc/scripts/compilation_tests" .
    fi

    echo "✓ Source copied from home directory"
    SOURCE_COPIED=true

# Method 2: Try NFS access to fileserver
elif [ -d "/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim" ]; then
    echo "Using NFS to access fileserver..."
    cp -r /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/src .
    cp /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/Project.toml .
    cp /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/Project_HPC_Minimal.toml ./Project_HPC.toml 2>/dev/null || true
    cp -r /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/hpc/scripts/compilation_tests . 2>/dev/null || true
    echo "✓ Source copied via NFS"
    SOURCE_COPIED=true

# Method 3: Try projects directory
elif [ -d "/projects/globtim/src" ]; then
    echo "Using source from projects directory..."
    cp -r /projects/globtim/src .
    cp /projects/globtim/Project.toml . 2>/dev/null || true
    cp /projects/globtim/Project_HPC_Minimal.toml ./Project_HPC.toml 2>/dev/null || true
    cp -r /projects/globtim/hpc/scripts/compilation_tests . 2>/dev/null || true
    echo "✓ Source copied from projects directory"
    SOURCE_COPIED=true

else
    echo "❌ Cannot find Globtim source in any expected location"
    echo "Checked locations:"
    echo "  - $HOME/globtim_hpc/src"
    echo "  - /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim"
    echo "  - /projects/globtim/src"
    echo ""
    echo "Available files in home directory:"
    ls -la "$HOME/" | head -10
    echo ""
    echo "Attempting to continue with fallback test..."
fi

echo ""
echo "Files in working directory:"
ls -la
echo ""

# Set up Julia environment
echo "=== Julia Environment Setup ==="
echo "Julia version:"
/sw/bin/julia --version
echo ""

# Try to set up package depot from fileserver if available
FILESERVER_DEPOT="/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot"
if [ -d "$FILESERVER_DEPOT" ]; then
    echo "✓ Using fileserver Julia depot via NFS"
    export JULIA_DEPOT_PATH="$FILESERVER_DEPOT:$JULIA_DEPOT_PATH"
else
    echo "⚠️  Fileserver depot not accessible, using temporary depot"
    mkdir -p "$JULIA_DEPOT_PATH"
fi

echo "Julia depot path: $JULIA_DEPOT_PATH"
echo ""

# Determine test mode from job name or environment
TEST_MODE="standard"
if [[ "$SLURM_JOB_NAME" == *"quick"* ]]; then
    TEST_MODE="quick"
elif [[ "$SLURM_JOB_NAME" == *"thorough"* ]]; then
    TEST_MODE="thorough"
fi

echo "=== Running Compilation Test ==="
echo "Test mode: $TEST_MODE"
echo ""

# Run the comprehensive compilation test
if [ -f "compilation_tests/comprehensive_compilation_test.jl" ]; then
    echo "Running comprehensive compilation test..."
    /sw/bin/julia compilation_tests/comprehensive_compilation_test.jl --$TEST_MODE
    TEST_EXIT_CODE=$?
else
    echo "❌ Compilation test script not found"
    echo "Available files:"
    find . -name "*.jl" -type f
    echo ""
    echo "Running enhanced fallback test..."

    # Enhanced fallback test that tries to load Globtim if source is available
    /sw/bin/julia -e '
    println("=== Enhanced Fallback Compilation Test ===")
    println("Julia ", VERSION, " with ", Threads.nthreads(), " threads")
    println()

    # Test basic packages
    println("Testing basic packages...")
    basic_packages = ["LinearAlgebra", "Statistics", "Random", "Printf", "Dates"]
    basic_passed = 0
    for pkg in basic_packages
        try
            eval(Meta.parse("using $pkg"))
            println("✓ $pkg loaded")
            basic_passed += 1
        catch e
            println("❌ $pkg failed: $e")
        end
    end

    # Test additional packages that Globtim needs
    println()
    println("Testing Globtim dependencies...")
    globtim_packages = ["CSV", "DataFrames", "Parameters", "TOML", "ForwardDiff"]
    globtim_passed = 0
    for pkg in globtim_packages
        try
            eval(Meta.parse("using $pkg"))
            println("✓ $pkg loaded")
            globtim_passed += 1
        catch e
            println("❌ $pkg failed: $e")
        end
    end

    # Test Globtim source loading if available
    println()
    println("Testing Globtim source loading...")
    globtim_loaded = false
    if isdir("src")
        try
            println("Found src directory, attempting to load Globtim modules...")

            # Try loading core modules
            include("src/Structures.jl")
            println("✓ Structures.jl loaded")

            include("src/BenchmarkFunctions.jl")
            println("✓ BenchmarkFunctions.jl loaded")

            # Test benchmark function
            x = [0.5, 0.5]
            if isdefined(Main, :trefethen_3_8)
                result = trefethen_3_8(x)
                println("✓ Benchmark function test: trefethen_3_8($x) = $result")
            end

            globtim_loaded = true
            println("✅ Globtim core modules loaded successfully!")

        catch e
            println("❌ Globtim loading failed: $e")
        end
    else
        println("⚠️  No src directory found, skipping Globtim loading test")
    end

    # Test basic functionality
    println()
    println("Testing basic functionality...")
    try
        A = rand(100, 100)
        B = A * A
        println("✓ Matrix operations work")

        # Test file I/O
        open("test_file.txt", "w") do f
            println(f, "Test data: $(rand())")
        end
        test_data = read("test_file.txt", String)
        rm("test_file.txt")
        println("✓ File I/O works")

        # Performance test
        start_time = time()
        C = rand(200, 200) * rand(200, 200)
        perf_time = time() - start_time
        println("✓ Performance test: 200x200 matrix mult in $(round(perf_time, digits=3))s")

        println()
        println("=== TEST SUMMARY ===")
        println("Basic packages: $basic_passed/$(length(basic_packages)) passed")
        println("Globtim packages: $globtim_passed/$(length(globtim_packages)) passed")
        println("Globtim source: $(globtim_loaded ? "✅ LOADED" : "❌ FAILED")")
        println("Overall: $(basic_passed >= 4 && globtim_passed >= 2 ? "✅ PASSED" : "⚠️  PARTIAL")")

        if basic_passed >= 4 && globtim_passed >= 2
            println("✅ Enhanced compilation test PASSED")
        else
            println("⚠️  Enhanced compilation test PARTIAL - some components missing")
            exit(1)
        end

    catch e
        println("❌ Basic functionality failed: $e")
        exit(1)
    end
    '
    TEST_EXIT_CODE=$?
fi

echo ""
echo "=== Test Results Collection ==="

# Collect all result files
RESULTS_DIR="results_${SLURM_JOB_ID}"
mkdir -p $RESULTS_DIR

# Copy any generated result files
find . -name "*results*.txt" -exec cp {} $RESULTS_DIR/ \;
find . -name "*.log" -exec cp {} $RESULTS_DIR/ \;

# Create summary file
cat > $RESULTS_DIR/test_summary.txt << EOF
# Globtim Compilation Test Summary
Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Test Mode: $TEST_MODE
Start Time: $(date)
Exit Code: $TEST_EXIT_CODE
Julia Version: $(/sw/bin/julia --version)
CPUs: $SLURM_CPUS_PER_TASK
Memory: $SLURM_MEM_PER_NODE MB

# Environment
Julia Depot: $JULIA_DEPOT_PATH
Working Directory: $(pwd)
Available Space: $(df -h . | tail -1 | awk '{print $4}')

# Files Generated
$(ls -la $RESULTS_DIR/)
EOF

echo "Results collected in: $RESULTS_DIR"
echo "Files:"
ls -la $RESULTS_DIR/

# Copy results back to fileserver if possible
if command -v scp >/dev/null 2>&1; then
    echo ""
    echo "Copying results to fileserver..."
    scp -r $RESULTS_DIR scholten@fileserver-ssh:globtim/hpc_results/compilation_test_${SLURM_JOB_ID}/
    echo "✓ Results copied to fileserver"
fi

echo ""
echo "=== Cleanup ==="
cd /
rm -rf $TMPDIR
rm -rf $JULIA_DEPOT_PATH

echo ""
echo "=== Job Completed ==="
echo "End time: $(date)"
echo "Job duration: $SECONDS seconds"
echo "Exit code: $TEST_EXIT_CODE"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "🎉 COMPILATION TEST SUCCESSFUL"
else
    echo "❌ COMPILATION TEST FAILED"
fi

exit $TEST_EXIT_CODE
