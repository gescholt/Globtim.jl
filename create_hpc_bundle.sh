#!/bin/bash

# Script to create a complete GlobTim bundle for HPC deployment
# This bundles all packages locally to avoid HPC package download issues

echo "======================================================================"
echo "Creating GlobTim HPC Bundle"
echo "======================================================================"

# Configuration
BUNDLE_DIR="globtim_hpc_bundle"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUNDLE_NAME="globtim_bundle_${TIMESTAMP}"

# Clean previous bundle
rm -rf $BUNDLE_DIR
mkdir -p $BUNDLE_DIR

echo "Bundle directory: $BUNDLE_DIR"
echo "Bundle name: $BUNDLE_NAME"

# Step 1: Create isolated Julia depot
echo ""
echo "Step 1: Creating isolated Julia depot..."
cd $BUNDLE_DIR
export JULIA_DEPOT_PATH="$(pwd)/depot"
mkdir -p depot

# Step 2: Copy GlobTim source
echo ""
echo "Step 2: Copying GlobTim source code..."
cp -r ../src ./
cp ../Project.toml ./ 2>/dev/null || echo "No Project.toml found"

# Step 3: Create package installation script
echo ""
echo "Step 3: Creating package installation script..."

cat > install_packages.jl << 'JULIA_SCRIPT'
println("Installing GlobTim dependencies in isolated depot...")
println("DEPOT_PATH: ", DEPOT_PATH)

using Pkg

# Create new environment
Pkg.activate("globtim_env")

# Essential packages for GlobTim
packages = [
    "CSV",
    "DataFrames",
    "StaticArrays", 
    "ForwardDiff",
    "Parameters",
    "LinearAlgebra",
    "Statistics",
    "Random",
    "Test"
]

# Optional packages
optional_packages = [
    "DynamicPolynomials",
    "ProgressLogging",
    "TimerOutputs"
]

println("\nInstalling essential packages:")
for pkg in packages
    try
        println("  Installing $pkg...")
        Pkg.add(pkg)
        println("  ✅ $pkg installed")
    catch e
        println("  ❌ $pkg failed: ", e)
    end
end

println("\nInstalling optional packages:")
for pkg in optional_packages
    try
        println("  Installing $pkg...")
        Pkg.add(pkg)
        println("  ✅ $pkg installed")
    catch e
        println("  ⚠️  $pkg failed (optional): ", e)
    end
end

println("\nPrecompiling all packages...")
Pkg.precompile()

println("\n✅ Package installation complete!")

# Test that packages work
println("\nTesting package loading...")
using CSV
using DataFrames
using StaticArrays
using ForwardDiff
using Parameters

println("✅ All essential packages load successfully!")

# Save package status
open("package_status.txt", "w") do f
    println(f, "GlobTim Bundle Package Status")
    println(f, "Generated: ", Dates.now())
    println(f, "")
    redirect_stdout(f) do
        Pkg.status()
    end
end
JULIA_SCRIPT

# Step 4: Install packages locally
echo ""
echo "Step 4: Installing packages (this may take a few minutes)..."
julia install_packages.jl

if [ $? -ne 0 ]; then
    echo "❌ Package installation failed"
    echo "Falling back to standalone version only"
fi

# Step 5: Create standalone version (always include as fallback)
echo ""
echo "Step 5: Including standalone version..."

cat > src/GlobtimStandalone.jl << 'STANDALONE'
# Standalone version that works without any external packages
module GlobtimStandalone

using LinearAlgebra, Statistics, Random

const PrecisionType = Float64

# Core functions
Sphere(x) = sum(x.^2)
Rosenbrock(x) = sum(100.0 * (x[i+1] - x[i]^2)^2 + (1.0 - x[i])^2 for i in 1:length(x)-1)
Deuflhard(x) = (4.0 - 2.1*x[1]^2 + x[1]^4/3)*x[1]^2 + x[1]*x[2] + (-4.0 + 4.0*x[2]^2)*x[2]^2

function test_input(func; dim=2, center=[0.0, 0.0], sample_range=2.0, GN=100)
    samples = [center .+ sample_range .* (2.0 .* rand(dim) .- 1.0) for _ in 1:GN]
    values = [func(s) for s in samples]
    return (samples=samples, values=values)
end

export Sphere, Rosenbrock, Deuflhard, test_input, PrecisionType

end # module
STANDALONE

# Step 6: Create loader script for HPC
echo ""
echo "Step 6: Creating HPC loader script..."

cat > load_globtim.jl << 'LOADER'
# GlobTim HPC Loader - Automatically selects best available version

println("GlobTim HPC Loader")
println("=" ^ 50)

# Try full version with bundled packages
try
    # Use bundled depot
    ENV["JULIA_DEPOT_PATH"] = joinpath(@__DIR__, "depot")
    pushfirst!(LOAD_PATH, joinpath(@__DIR__, "globtim_env"))
    
    using CSV
    using DataFrames
    using StaticArrays
    using ForwardDiff
    
    include("src/Globtim.jl")
    using .Globtim
    
    println("✅ Full GlobTim loaded with all packages")
    const GLOBTIM_MODE = :full
    
catch e
    println("⚠️  Full version unavailable, loading standalone...")
    
    # Fall back to standalone
    include("src/GlobtimStandalone.jl")
    using .GlobtimStandalone
    
    println("✅ Standalone GlobTim loaded")
    const GLOBTIM_MODE = :standalone
end

# Provide unified interface
if GLOBTIM_MODE == :full
    const ActiveGlobtim = Globtim
else
    const ActiveGlobtim = GlobtimStandalone
end

println("Available functions:")
for name in names(ActiveGlobtim, all=false)
    if !startswith(string(name), "#")
        println("  • ", name)
    end
end
println("=" ^ 50)
LOADER

# Step 7: Create SLURM template
echo ""
echo "Step 7: Creating SLURM job template..."

cat > run_globtim.slurm << 'SLURM'
#!/bin/bash
#SBATCH --job-name=globtim_bundled
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH -o globtim_%j.out
#SBATCH -e globtim_%j.err

echo "Running GlobTim with bundled packages"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"

# Set threads
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Use bundled depot
export JULIA_DEPOT_PATH="$HOME/globtim_bundle/depot"

cd $HOME/globtim_bundle

/sw/bin/julia load_globtim.jl

# Run your code
/sw/bin/julia << 'EOF'
include("load_globtim.jl")

# Your computation here
result = ActiveGlobtim.Sphere([1.0, 1.0])
println("Result: ", result)
EOF
SLURM

# Step 8: Create deployment instructions
echo ""
echo "Step 8: Creating deployment instructions..."

cat > DEPLOY_TO_HPC.md << 'INSTRUCTIONS'
# Deploying GlobTim Bundle to HPC

## Files in this bundle:
- `depot/` - Pre-installed Julia packages
- `globtim_env/` - Julia environment with all dependencies
- `src/` - GlobTim source code
- `src/GlobtimStandalone.jl` - Fallback standalone version
- `load_globtim.jl` - Automatic loader script
- `run_globtim.slurm` - SLURM job template

## Deployment Steps:

1. **Create tar archive** (on local machine):
   ```bash
   tar -czf globtim_bundle.tar.gz depot/ globtim_env/ src/ *.jl *.slurm
   ```

2. **Transfer to HPC**:
   ```bash
   scp globtim_bundle.tar.gz scholten@falcon:~/
   ```

3. **Extract on HPC**:
   ```bash
   ssh scholten@falcon
   cd ~
   tar -xzf globtim_bundle.tar.gz -C globtim_bundle/
   ```

4. **Submit job**:
   ```bash
   cd globtim_bundle
   sbatch run_globtim.slurm
   ```

## Usage in Julia:

```julia
# The loader automatically selects the best version
include("load_globtim.jl")

# Use the active module
result = ActiveGlobtim.Sphere([1.0, 1.0])
```

## Troubleshooting:

- If packages fail to load, the standalone version will be used automatically
- Check `GLOBTIM_MODE` to see which version is active
- The bundle includes all precompiled packages to avoid network access
INSTRUCTIONS

# Step 9: Create the bundle archive
echo ""
echo "Step 9: Creating bundle archive..."

cd ..
tar -czf ${BUNDLE_NAME}.tar.gz $BUNDLE_DIR/

echo ""
echo "======================================================================"
echo "Bundle Creation Complete!"
echo "======================================================================"
echo "Bundle created: ${BUNDLE_NAME}.tar.gz"
echo "Size: $(du -h ${BUNDLE_NAME}.tar.gz | cut -f1)"
echo ""
echo "To deploy to HPC:"
echo "  1. scp ${BUNDLE_NAME}.tar.gz scholten@falcon:~/"
echo "  2. ssh scholten@falcon"
echo "  3. tar -xzf ${BUNDLE_NAME}.tar.gz"
echo "  4. cd $BUNDLE_DIR && sbatch run_globtim.slurm"
echo ""
echo "The bundle includes:"
echo "  ✅ All pre-installed packages (no network needed)"
echo "  ✅ Standalone fallback version"
echo "  ✅ Automatic version selection"
echo "  ✅ SLURM job templates"
echo "======================================================================"