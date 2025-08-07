#!/bin/bash
#SBATCH --job-name=hpc_deps_simple
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --output=hpc_deps_99ecbfe7_%j.out
#SBATCH --error=hpc_deps_99ecbfe7_%j.err

echo "=== HPC Dependencies Installation ==="
echo "Test ID: 99ecbfe7"
echo "Mode: minimal"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia version: $(/sw/bin/julia --version)"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo ""

# Create output directory
mkdir -p dependency_install_99ecbfe7
echo "✅ Output directory created: dependency_install_99ecbfe7"

# Use minimal HPC project file
if [ -f "Project_HPC_Minimal.toml" ]; then
    cp Project_HPC_Minimal.toml Project.toml
    echo "✅ Using Project_HPC_Minimal.toml"
else
    echo "⚠️  Project_HPC_Minimal.toml not found, using existing Project.toml"
fi

echo ""
echo "=== Installing Missing Packages ==="

# Install packages one by one with error handling
/sw/bin/julia --project=. -e '
using Pkg

println("🚀 Installing Missing Dependencies")
println("Julia Version: $(VERSION)")
println()

# List of packages to install
packages = ["StaticArrays", "JSON3", "TimerOutputs", "TOML", "Printf"]

successful = String[]
failed = String[]

for pkg in packages
    println("Installing $pkg...")
    try
        Pkg.add(pkg)
        push!(successful, pkg)
        println("  ✅ $pkg installed successfully")
    catch e
        push!(failed, pkg)
        println("  ❌ $pkg failed: $e")
    end
    println()
end

println("📊 INSTALLATION SUMMARY:")
println("Successful: $(length(successful))")
for pkg in successful
    println("  ✅ $pkg")
end

if !isempty(failed)
    println("Failed: $(length(failed))")
    for pkg in failed
        println("  ❌ $pkg")
    end
end

# Save results
open("dependency_install_99ecbfe7/installation_results.txt", "w") do f
    println(f, "HPC Dependencies Installation Results")
    println(f, "====================================")
    println(f, "Timestamp: $(now())")
    println(f, "Julia version: $(VERSION)")
    println(f, "")
    println(f, "Successful packages:")
    for pkg in successful
        println(f, "  ✅ $pkg")
    end
    println(f, "")
    println(f, "Failed packages:")
    for pkg in failed
        println(f, "  ❌ $pkg")
    end
end

if isempty(failed)
    println("🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!")
    exit(0)
else
    println("❌ SOME PACKAGES FAILED")
    exit(1)
end
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Installation Complete ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Test the installation by trying to load Globtim modules
if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=== Testing Globtim Module Loading ==="
    /sw/bin/julia --project=. -e '
    try
        include("src/BenchmarkFunctions.jl")
        println("✅ BenchmarkFunctions.jl loaded successfully")
        
        include("src/LibFunctions.jl")
        println("✅ LibFunctions.jl loaded successfully")
        
        include("src/Samples.jl")
        println("✅ Samples.jl loaded successfully")
        
        include("src/Structures.jl")
        println("✅ Structures.jl loaded successfully")
        
        println("🎉 ALL GLOBTIM MODULES LOADED SUCCESSFULLY!")
        
        # Save success status
        open("dependency_install_99ecbfe7/module_test_results.txt", "w") do f
            println(f, "Globtim Module Loading Test")
            println(f, "===========================")
            println(f, "Timestamp: $(now())")
            println(f, "Status: SUCCESS")
            println(f, "All modules loaded successfully")
        end
        
    catch e
        println("❌ Module loading failed: $e")
        
        # Save error status
        open("dependency_install_99ecbfe7/module_test_error.txt", "w") do f
            println(f, "Globtim Module Loading Error")
            println(f, "============================")
            println(f, "Timestamp: $(now())")
            println(f, "Error: $e")
        end
        
        exit(1)
    end
    '
    
    MODULE_TEST_EXIT_CODE=$?
    
    if [ $MODULE_TEST_EXIT_CODE -eq 0 ]; then
        echo "✅ Dependencies installation and module testing completed successfully"
    else
        echo "❌ Dependencies installed but module testing failed"
    fi
else
    echo "❌ Dependencies installation failed"
fi

# Create final summary
cat > dependency_install_99ecbfe7/job_summary.txt << EOF
# HPC Dependencies Installation Summary
Test ID: 99ecbfe7
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Mode: minimal
Start Time: $(date)
Duration: $SECONDS seconds
Installation Exit Code: $JULIA_EXIT_CODE
Module Test Exit Code: $MODULE_TEST_EXIT_CODE

# Generated Files:
$(ls -la dependency_install_99ecbfe7/)
EOF

exit $JULIA_EXIT_CODE
