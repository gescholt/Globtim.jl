# Julia Offline Depot Bundle Instructions
## Creating a Complete Package Bundle for Air-Gapped HPC Clusters

---

## 📋 Overview

This guide helps you create a complete, self-contained Julia depot with all packages and dependencies that can be transferred to an HPC cluster without internet access.

**Problem**: HPC compute nodes have no internet → Can't download packages  
**Solution**: Create complete depot bundle locally → Transfer to cluster → Use offline

---

## 🎯 Prerequisites

### On Your Local Machine (with internet):
- Julia installed (same version as cluster if possible)
- Git access to your project
- ~10GB free disk space (for large package collections)
- `rsync` or `scp` for file transfer

### Check Julia Versions:
```bash
# Local machine
julia --version

# On cluster
ssh falcon "julia --version"
# If versions differ significantly, consider using juliaup to match versions
```

---

## 📦 Step 1: Prepare Local Environment

### 1.1 Create a Clean Workspace
```bash
# Create working directory
mkdir -p ~/julia_offline_prep
cd ~/julia_offline_prep

# Clone your project
git clone <your-globtim-repo> globtim_hpc
cd globtim_hpc

# Check current dependencies
cat Project.toml
```

### 1.2 Document Current Package List
```bash
# Create package inventory
julia --project=. -e '
    using Pkg
    deps = Pkg.dependencies()
    open("package_list.txt", "w") do io
        for (uuid, dep) in deps
            println(io, dep.name, " ", dep.version)
        end
    end
    println("Found ", length(deps), " packages")
'
```

---

## 📦 Step 2: Create Isolated Depot

### 2.1 Set Up Clean Depot Environment
```bash
# Create isolated depot directory
export JULIA_DEPOT_OFFLINE="$HOME/julia_offline_prep/depot"
mkdir -p $JULIA_DEPOT_OFFLINE

# Create setup script
cat > setup_offline_depot.jl << 'EOF'
# setup_offline_depot.jl
println("=== Creating Offline Julia Depot ===")
println("Depot location: ", ENV["JULIA_DEPOT_PATH"])

using Pkg

# Update registry first (needs internet)
println("\n1. Updating package registry...")
Pkg.Registry.update()

# Show current project
println("\n2. Current project: ", Base.active_project())

# Instantiate project dependencies
println("\n3. Installing all dependencies...")
Pkg.instantiate(verbose=true)

# Add commonly needed stdlib packages
println("\n4. Adding standard libraries...")
using LinearAlgebra
using SparseArrays
using Random
using Statistics
using Distributed
using SharedArrays
using Dates
using DelimitedFiles

println("\n5. Precompiling all packages...")
Pkg.precompile()

# List all installed packages
println("\n6. Installed packages:")
Pkg.status()

println("\n=== Depot Creation Complete ===")
EOF
```

### 2.2 Run Depot Creation
```bash
# Set environment to use isolated depot
export JULIA_DEPOT_PATH="$JULIA_DEPOT_OFFLINE"

# Run setup
cd ~/julia_offline_prep/globtim_hpc
julia --project=. setup_offline_depot.jl 2>&1 | tee depot_creation.log

# Check for errors
grep -i error depot_creation.log
```

---

## 📦 Step 3: Handle Complex Dependencies

### 3.1 Create Dependency Analyzer
```julia
# analyze_dependencies.jl
using Pkg
using TOML

println("=== Analyzing Package Dependencies ===")

# Get all dependencies including indirect ones
function get_all_deps()
    deps = Pkg.dependencies()
    
    # Categorize packages
    stdlib_pkgs = String[]
    regular_pkgs = String[]
    binary_pkgs = String[]
    
    for (uuid, dep) in deps
        if dep.is_stdlib
            push!(stdlib_pkgs, dep.name)
        elseif contains(string(dep.name), "_jll")
            push!(binary_pkgs, dep.name)
        else
            push!(regular_pkgs, dep.name)
        end
    end
    
    return (stdlib=stdlib_pkgs, regular=regular_pkgs, binary=binary_pkgs)
end

pkgs = get_all_deps()

println("\n📚 Standard Library Packages (", length(pkgs.stdlib), "):")
for p in sort(pkgs.stdlib)
    println("  - ", p)
end

println("\n📦 Regular Packages (", length(pkgs.regular), "):")
for p in sort(pkgs.regular)
    println("  - ", p)
end

println("\n⚙️ Binary Dependencies (", length(pkgs.binary), "):")
for p in sort(pkgs.binary)
    println("  - ", p)
end

println("\n📊 Total packages: ", length(pkgs.stdlib) + length(pkgs.regular) + length(pkgs.binary))

# Save to file for reference
open("dependency_analysis.txt", "w") do io
    println(io, "Dependency Analysis - $(Dates.now())")
    println(io, "=====================================")
    println(io, "\nStandard Library: ", join(pkgs.stdlib, ", "))
    println(io, "\nRegular Packages: ", join(pkgs.regular, ", "))
    println(io, "\nBinary Dependencies: ", join(pkgs.binary, ", "))
end
```

### 3.2 Handle Problem Packages
```julia
# handle_problem_packages.jl
using Pkg

# Common problematic packages for offline use
problem_packages = [
    "CairoMakie",  # Heavy graphics dependencies
    "PlotlyJS",    # Requires internet for assets
    "WebIO",       # Web dependencies
    "IJulia",      # Jupyter dependencies
]

println("=== Handling Problematic Packages ===")

for pkg in problem_packages
    if pkg in keys(Pkg.project().dependencies)
        println("⚠️  Found problematic package: $pkg")
        println("   This may require special handling for offline use")
        
        # Try to download all artifacts
        try
            Pkg.build(pkg)
            println("   ✅ Built successfully")
        catch e
            println("   ❌ Build failed: ", e)
        end
    end
end

# Force download of all artifacts
println("\n=== Downloading All Artifacts ===")
using Pkg.Artifacts

for (uuid, dep) in Pkg.dependencies()
    if !dep.is_stdlib
        try
            # This forces artifact download
            Pkg.build(dep.name)
        catch
            # Some packages don't need building
        end
    end
end
```

---

## 📦 Step 4: Verify Completeness

### 4.1 Create Verification Script
```julia
# verify_depot.jl
using Pkg

println("=== Verifying Offline Depot Completeness ===")

# Temporarily disable network
ENV["JULIA_NO_NETWORK"] = "1"

# Test loading all packages
println("\n📋 Testing package loading...")
failed_packages = String[]

for (uuid, dep) in Pkg.dependencies()
    if !dep.is_stdlib
        try
            print("Loading $(dep.name)... ")
            eval(Meta.parse("using $(dep.name)"))
            println("✅")
        catch e
            println("❌")
            push!(failed_packages, dep.name)
        end
    end
end

if isempty(failed_packages)
    println("\n✅ All packages load successfully!")
else
    println("\n⚠️  Failed packages:")
    for pkg in failed_packages
        println("  - ", pkg)
    end
end

# Test specific functionality
println("\n🧪 Testing specific functionality...")
try
    # Add your specific package tests here
    # For Globtim:
    include("src/Globtim.jl")
    println("✅ Globtim loads successfully")
catch e
    println("❌ Globtim failed: ", e)
end
```

### 4.2 Check Depot Size and Contents
```bash
# Check depot size
du -sh $JULIA_DEPOT_OFFLINE

# Count files
find $JULIA_DEPOT_OFFLINE -type f | wc -l

# Check structure
ls -la $JULIA_DEPOT_OFFLINE/

# Expected directories:
# - artifacts/   (binary dependencies)
# - compiled/    (precompiled cache)
# - packages/    (package source)
# - registries/  (package registry)
```

---

## 📦 Step 5: Create Bundle

### 5.1 Create the Archive
```bash
cd ~/julia_offline_prep

# Create comprehensive bundle
tar -czf julia_depot_bundle_$(date +%Y%m%d).tar.gz \
    depot/ \
    globtim_hpc/ \
    --exclude='*.git' \
    --exclude='*.DS_Store'

# Check size
ls -lh julia_depot_bundle_*.tar.gz

# Create manifest
cat > bundle_manifest.txt << EOF
Julia Offline Depot Bundle
Created: $(date)
Julia Version: $(julia --version)
Project: globtim_hpc
Depot Size: $(du -sh depot | cut -f1)
Package Count: $(find depot/packages -maxdepth 1 -type d | wc -l)
Bundle File: julia_depot_bundle_$(date +%Y%m%d).tar.gz
EOF
```

### 5.2 Create Installation Script
```bash
cat > install_bundle.sh << 'EOF'
#!/bin/bash
# install_bundle.sh - Run on HPC cluster

BUNDLE_FILE=$1
TARGET_DIR="/stornext/snfs3/home/scholten"

if [ -z "$BUNDLE_FILE" ]; then
    echo "Usage: ./install_bundle.sh julia_depot_bundle_YYYYMMDD.tar.gz"
    exit 1
fi

echo "=== Installing Julia Offline Bundle ==="
echo "Bundle: $BUNDLE_FILE"
echo "Target: $TARGET_DIR"

# Extract bundle
cd $TARGET_DIR
tar -xzf $BUNDLE_FILE

# Set up environment
cat > setup_offline_julia.sh << 'INNER_EOF'
#!/bin/bash
# Source this file to use offline Julia depot

export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/depot"
export JULIA_PROJECT="/stornext/snfs3/home/scholten/globtim_hpc"

# Disable package server (offline mode)
export JULIA_PKG_SERVER=""
export JULIA_NO_NETWORK="1"

echo "Julia configured for offline use"
echo "Depot: $JULIA_DEPOT_PATH"
echo "Project: $JULIA_PROJECT"
INNER_EOF

chmod +x setup_offline_julia.sh

echo "=== Installation Complete ==="
echo "To use: source $TARGET_DIR/setup_offline_julia.sh"
EOF

chmod +x install_bundle.sh
```

---

## 📦 Step 6: Transfer to Cluster

### 6.1 Transfer Bundle
```bash
# Using scp
scp julia_depot_bundle_*.tar.gz mack:/stornext/snfs3/home/scholten/

# Or using rsync (better for large files)
rsync -avP julia_depot_bundle_*.tar.gz mack:/stornext/snfs3/home/scholten/

# Also transfer installation script
scp install_bundle.sh mack:/stornext/snfs3/home/scholten/
```

### 6.2 Install on Cluster
```bash
# On fileserver (mack)
ssh mack
cd /stornext/snfs3/home/scholten
./install_bundle.sh julia_depot_bundle_YYYYMMDD.tar.gz

# Source the environment
source setup_offline_julia.sh
```

---

## 📦 Step 7: Test on Cluster

### 7.1 Create Test Script
```bash
cat > test_offline_depot.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=test_offline
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:10:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o test_offline_%j.out

# Use offline depot
source /stornext/snfs3/home/scholten/setup_offline_julia.sh

echo "=== Testing Offline Julia Depot ==="
echo "Depot: $JULIA_DEPOT_PATH"
echo "Project: $JULIA_PROJECT"

cd $JULIA_PROJECT

julia --project=. -e '
    println("Julia version: ", VERSION)
    
    # Test package loading
    using Pkg
    println("\n=== Installed Packages ===")
    Pkg.status()
    
    # Test your specific packages
    println("\n=== Testing Package Loading ===")
    using LinearAlgebra
    println("✅ LinearAlgebra")
    
    # Add more package tests
    
    println("\n=== Test Complete ===")
'
EOF

sbatch test_offline_depot.slurm
```

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Issue: "Package not found" errors
```julia
# On local machine, ensure package is added
julia --project=. -e 'using Pkg; Pkg.add("MissingPackage")'
# Recreate bundle
```

#### Issue: Binary artifacts missing
```julia
# Force artifact download
using Pkg.Artifacts
Pkg.instantiate()
Pkg.build()  # Build all packages
```

#### Issue: Registry out of date
```julia
# Update registry before creating bundle
Pkg.Registry.update()
```

#### Issue: Version conflicts
```julia
# Clear and rebuild
Pkg.resolve()
Pkg.instantiate()
```

---

## 📋 Maintenance Workflow

### Adding New Packages
1. On local machine: Add package to project
2. Rebuild offline depot
3. Create new bundle
4. Transfer to cluster
5. Extract and test

### Updating Packages
```bash
# Local machine
julia --project=. -e 'using Pkg; Pkg.update()'
# Recreate bundle with updated packages
```

---

## ✅ Verification Checklist

Before considering bundle complete:

- [ ] All packages in Project.toml are installed
- [ ] All packages load without errors
- [ ] Depot contains: artifacts/, compiled/, packages/, registries/
- [ ] Bundle size is reasonable (typically 1-5GB)
- [ ] Test script runs successfully on cluster
- [ ] No network calls when using offline depot
- [ ] Performance is acceptable (precompiled packages load fast)

---

## 📊 Expected Sizes

| Component | Typical Size | Your Size |
|-----------|-------------|-----------|
| Registry | 50-100 MB | ___ MB |
| Packages | 500MB-2GB | ___ GB |
| Artifacts | 1-5GB | ___ GB |
| Compiled | 200MB-1GB | ___ MB |
| **Total Bundle** | **2-8GB** | **___ GB** |

---

## 🚀 Quick Reference

```bash
# Complete workflow
# 1. Local: Create bundle
export JULIA_DEPOT_PATH="$HOME/julia_offline_prep/depot"
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
tar -czf bundle.tar.gz depot/ globtim_hpc/

# 2. Transfer
scp bundle.tar.gz mack:/path/

# 3. Cluster: Extract and use
tar -xzf bundle.tar.gz
export JULIA_DEPOT_PATH="/path/to/depot"
julia --project=/path/to/globtim_hpc
```

---

**Important**: This process creates a snapshot of packages. You'll need to recreate the bundle when adding new packages or updating existing ones.