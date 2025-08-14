# Julia HPC Storage Issue Resolution - Part 2: Configuration
## Setting Up NFS-Only Operation and Testing

---

## 📋 Prerequisites
✅ Completed Part 1 (Diagnostics)
✅ Identified storage limitations and Julia errors
✅ Have access to `~/globtim_hpc/scripts/` directory

---

## Step 3: Configure Julia for NFS-Only Operation

### 3.1 Create Julia Environment Setup Script
This script forces all Julia operations to use NFS-mounted storage, avoiding local storage limits.

```bash
# Create comprehensive environment setup script
cat > ~/globtim_hpc/scripts/setup_julia_nfs_env.sh << 'EOF'
#!/bin/bash
# Force all Julia operations to NFS-mounted storage
# This script must be sourced in every SLURM job

echo "=== Configuring Julia for NFS-Only Operation ==="
echo "Timestamp: $(date)"

# Julia depot on NFS (home directory)
export JULIA_DEPOT_PATH="$HOME/.julia"
echo "Setting JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"

# Redirect ALL temp operations to NFS
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
echo "Setting temp directories to $TMPDIR"

# Create temp directory if it doesn't exist
if [ ! -d "$HOME/.julia_tmp" ]; then
    echo "Creating temp directory..."
    mkdir -p "$HOME/.julia_tmp"
    echo "✅ Temp directory created"
else
    echo "✅ Temp directory exists"
fi

# Julia-specific settings to minimize local storage use
export JULIA_HISTORY="$HOME/.julia_history"
export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_NUM_PRECOMPILE_TASKS=1
echo "Disabled automatic precompilation"

# Additional safety settings
export JULIA_PKG_DEVDIR="$HOME/.julia/dev"
export JULIA_PKG_SERVER=""  # Disable package server caching

# Verify settings
echo -e "\n=== Environment Configuration Summary ==="
echo "JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"
echo "TMPDIR: $TMPDIR"
echo "TEMP: $TEMP"
echo "TMP: $TMP"
echo "JULIA_PKG_PRECOMPILE_AUTO: $JULIA_PKG_PRECOMPILE_AUTO"
echo "Temp directory exists: $([ -d $TMPDIR ] && echo 'Yes ✅' || echo 'No ❌')"
echo "Julia depot exists: $([ -d $JULIA_DEPOT_PATH ] && echo 'Yes ✅' || echo 'No ❌')"

# Test temp directory write access
echo -e "\n=== Testing Write Access ==="
TEST_FILE="$TMPDIR/test_write_$$"
if echo "test" > "$TEST_FILE" 2>/dev/null; then
    echo "✅ Temp directory is writable"
    rm -f "$TEST_FILE"
else
    echo "❌ ERROR: Temp directory is not writable!"
    echo "   Please check permissions on $TMPDIR"
    return 1
fi

echo -e "\n=== Environment Setup Complete ✅ ==="
echo "You can now run Julia with NFS-only storage"
EOF

chmod +x ~/globtim_hpc/scripts/setup_julia_nfs_env.sh
```

### 3.2 Test Julia with NFS Configuration
```bash
# Create test script for NFS-configured Julia
cat > ~/globtim_hpc/scripts/test_julia_nfs.sh << 'EOF'
#!/bin/bash
echo "=== Testing Julia with NFS Configuration ==="
echo "Start time: $(date)"

# Source the NFS environment setup
echo -e "\n--- Sourcing NFS environment ---"
source ~/globtim_hpc/scripts/setup_julia_nfs_env.sh

# Load Julia module if needed
module load julia 2>/dev/null || echo "Julia module not needed/loaded"

echo -e "\n--- Environment Verification ---"
julia --project=~/globtim_hpc -e '
    println("=== Julia Environment Check ===")
    println("Julia version: ", VERSION)
    println("Depot paths: ", DEPOT_PATH)
    println("First depot: ", DEPOT_PATH[1])
    println("Temp directory: ", tempdir())
    
    # Test temp file creation
    println("\n=== Testing Temp File Creation ===")
    temp_result = try
        f = tempname()
        println("Creating temp file: ", f)
        write(f, "test data")
        content = read(f, String)
        rm(f)
        println("✅ Successfully created and removed temp file")
        true
    catch e
        println("❌ Error with temp file: ", e)
        false
    end
    
    println("Temp file test: ", temp_result ? "PASSED" : "FAILED")
'

echo -e "\n--- Basic Package Test ---"
julia --project=~/globtim_hpc --compiled-modules=no -e '
    println("=== Package Loading Test ===")
    println("Testing with --compiled-modules=no flag")
    
    # Test 1: Load Pkg
    pkg_loaded = try
        using Pkg
        println("✅ Pkg loaded successfully")
        true
    catch e
        println("❌ Pkg loading failed: ", e)
        false
    end
    
    # Test 2: Check package status
    if pkg_loaded
        println("\n=== Package Status ===")
        try
            Pkg.status()
            println("✅ Package status check completed")
        catch e
            println("❌ Package status failed: ", e)
        end
    end
    
    # Test 3: Check depot accessibility
    println("\n=== Depot Accessibility ===")
    depot_path = DEPOT_PATH[1]
    println("Checking depot at: ", depot_path)
    if isdir(depot_path)
        println("✅ Depot directory exists")
        subdirs = readdir(depot_path)
        println("Depot contains: ", join(subdirs[1:min(5,length(subdirs))], ", "), 
                length(subdirs) > 5 ? "..." : "")
    else
        println("❌ Depot directory not found!")
    end
'

echo -e "\n--- Storage Check ---"
df -h $HOME | grep -E "Filesystem|home"
echo "Julia temp directory usage:"
du -sh $HOME/.julia_tmp 2>/dev/null || echo "Temp directory empty/not found"

echo -e "\n=== NFS Configuration Test Complete ==="
echo "End time: $(date)"
EOF

chmod +x ~/globtim_hpc/scripts/test_julia_nfs.sh
```

### 3.3 Run NFS Configuration Test
```bash
# Create SLURM job for NFS configuration test
cat > ~/globtim_hpc/test_julia_nfs.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=julia_nfs_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o julia_nfs_%j.out
#SBATCH -e julia_nfs_%j.err

echo "=== SLURM Job Information ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Start time: $(date)"

cd $HOME/globtim_hpc
./scripts/test_julia_nfs.sh

echo "=== Job Complete ==="
echo "End time: $(date)"
EOF

# Submit the test
sbatch test_julia_nfs.slurm

echo "Job submitted. Monitor with: squeue -u $USER"
echo "Check output with: tail -f julia_nfs_*.out"
```

### ✅ **Verification Point 3**
Expected successful output:
- **Depot path** points to `$HOME/.julia` ✅
- **Temp directory** points to `$HOME/.julia_tmp` ✅
- **"Can write temp: true"** ✅
- **"✅ Pkg loaded successfully"** ✅
- **No quota errors** ✅

**Success Indicators:**
```
✅ Temp directory is writable
✅ Successfully created and removed temp file
✅ Pkg loaded successfully
✅ Package status check completed
✅ Depot directory exists
```

**✓ If all checks pass, proceed to Step 4**  
**✗ If errors persist, check environment variables and permissions**

---

## Step 4: Test Package Loading Without Compilation

### 4.1 Create Package Loading Test Script
This tests loading multiple packages without compilation to verify the workaround works.

```bash
# Create comprehensive package loading test
cat > ~/globtim_hpc/scripts/test_package_loading.sh << 'EOF'
#!/bin/bash
echo "=== Testing Package Loading Without Compilation ==="
echo "This test may take several minutes due to --compiled-modules=no"
echo "Start time: $(date)"

# Source NFS environment
echo -e "\n--- Setting up NFS environment ---"
source ~/globtim_hpc/scripts/setup_julia_nfs_env.sh

# Load Julia module if needed
module load julia 2>/dev/null

echo -e "\n--- Storage Before Test ---"
echo "Home directory usage:"
df -h ~ | grep -E "Filesystem|home"
echo "Julia depot size:"
du -sh ~/.julia 2>/dev/null || echo "Depot not found"

echo -e "\n--- Package Loading Test ---"
echo "Running Julia with --compiled-modules=no flag..."

# Main package loading test
julia --project=. --compiled-modules=no -e '
    println("=== Comprehensive Package Loading Test ===")
    println("Julia ", VERSION, " on ", gethostname())
    
    # Track results
    results = Dict{String, Bool}()
    
    # Test 1: Core package (Pkg)
    print("Loading Pkg... ")
    results["Pkg"] = try
        using Pkg
        println("✅ SUCCESS")
        true
    catch e
        println("❌ FAILED: ", e)
        false
    end
    
    # Test 2: Package status
    if results["Pkg"]
        print("Checking package status... ")
        results["Pkg.status"] = try
            Pkg.status()
            println("✅ SUCCESS")
            true
        catch e
            println("❌ FAILED: ", e)
            false
        end
    end
    
    # Test 3: Standard library (LinearAlgebra)
    print("Loading LinearAlgebra... ")
    results["LinearAlgebra"] = try
        using LinearAlgebra
        println("✅ SUCCESS")
        true
    catch e
        println("❌ FAILED: ", e)
        false
    end
    
    # Test 4: Common package (if available)
    print("Loading BenchmarkTools... ")
    results["BenchmarkTools"] = try
        using BenchmarkTools
        println("✅ SUCCESS")
        true
    catch e
        println("❌ FAILED (may not be installed): ", e)
        false
    end
    
    # Test 5: Basic computation
    print("Testing basic computation... ")
    results["Computation"] = try
        A = rand(100, 100)
        B = A * A
        sum(B)
        println("✅ SUCCESS")
        true
    catch e
        println("❌ FAILED: ", e)
        false
    end
    
    # Test 6: File I/O in temp directory
    print("Testing file I/O... ")
    results["File I/O"] = try
        tempfile = tempname()
        write(tempfile, "test data")
        data = read(tempfile, String)
        rm(tempfile)
        println("✅ SUCCESS")
        true
    catch e
        println("❌ FAILED: ", e)
        false
    end
    
    # Summary
    println("\n=== Test Results Summary ===")
    passed = 0
    failed = 0
    for (test, result) in results
        status = result ? "✅ PASS" : "❌ FAIL"
        println("  ", rpad(test, 20), " : ", status)
        result ? (passed += 1) : (failed += 1)
    end
    
    println("\nTotal: ", passed, " passed, ", failed, " failed")
    
    if failed == 0
        println("\n🎉 All tests passed! Package loading works without compilation.")
    elseif passed > failed
        println("\n⚠️  Most tests passed. Check failed tests above.")
    else
        println("\n❌ Multiple failures. Review configuration.")
    end
'

echo -e "\n--- Storage After Test ---"
echo "Home directory usage:"
df -h ~ | grep -E "Filesystem|home"
echo "Temp directory contents:"
ls -la $HOME/.julia_tmp 2>/dev/null | head -5 || echo "Temp directory empty"

echo -e "\n=== Package Loading Test Complete ==="
echo "End time: $(date)"
EOF

chmod +x ~/globtim_hpc/scripts/test_package_loading.sh
```

### 4.2 Run Package Loading Test
```bash
# Create SLURM job for package loading test
cat > ~/globtim_hpc/test_package_loading.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=package_loading_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:20:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o package_loading_%j.out
#SBATCH -e package_loading_%j.err

echo "=== Package Loading Test Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Start: $(date)"

cd $HOME/globtim_hpc
./scripts/test_package_loading.sh

echo "=== Job Complete ==="
echo "End: $(date)"
echo "Check for errors in stderr file"
EOF

# Submit the test
sbatch test_package_loading.slurm

echo "Job submitted. This test may take 10-20 minutes."
echo "Monitor with: squeue -u $USER"
echo "Watch output with: tail -f package_loading_*.out"
```

### ✅ **Verification Point 4**
Success indicators:
- **Packages load** (slowly) without errors ✅
- **No quota/PID errors** ✅
- **Storage usage stable** ✅
- **All or most tests pass** ✅

**Expected Summary:**
```
=== Test Results Summary ===
  Pkg                  : ✅ PASS
  Pkg.status           : ✅ PASS
  LinearAlgebra        : ✅ PASS
  BenchmarkTools       : ✅ PASS (or FAIL if not installed)
  Computation          : ✅ PASS
  File I/O             : ✅ PASS

Total: 5-6 passed, 0-1 failed
🎉 All tests passed! Package loading works without compilation.
```

**✓ If tests pass, proceed to Part 3 (Production Deployment)**  
**✗ If errors persist, troubleshoot with diagnostics below**

---

## 🔧 Troubleshooting Configuration Issues

### Common Problems and Solutions

#### Problem: "Temp directory not writable"
```bash
# Fix permissions
chmod 755 $HOME/.julia_tmp
# Verify
ls -ld $HOME/.julia_tmp
```

#### Problem: "Julia module not found"
```bash
# Check available modules
module avail 2>&1 | grep -i julia
# Load specific version if available
module load julia/1.9.0  # adjust version
```

#### Problem: "Packages still trying to compile"
```bash
# Ensure flag is used correctly
julia --compiled-modules=no --project=. -e 'println("Test")'
# Check environment
echo $JULIA_PKG_PRECOMPILE_AUTO  # Should be 0
```

#### Problem: "Depot not accessible"
```bash
# Check depot exists and permissions
ls -la ~/.julia
# Create if missing
mkdir -p ~/.julia
chmod 755 ~/.julia
```

---

## 📊 Configuration Summary

### What We've Configured
1. **Environment Variables**:
   - All Julia paths point to NFS (`$HOME`)
   - Temp operations redirected to `$HOME/.julia_tmp`
   - Automatic precompilation disabled

2. **Julia Flags**:
   - `--compiled-modules=no` prevents compilation
   - `--project=.` uses local project
   - `--history-file=no` avoids history writes

3. **Verified Functionality**:
   - Package loading works (slowly)
   - Temp files can be created
   - No quota errors occur

### Performance Impact
- **Package Loading**: 2-3x slower without compilation
- **First Run**: May take 5-10 minutes for complex packages
- **Subsequent Runs**: Still slow but consistent
- **Computation Speed**: Not affected once loaded

---

## 📝 Quick Reference Card

Save this for easy reference:

```bash
# Create quick reference
cat > ~/globtim_hpc/NFS_JULIA_SETUP.md << 'EOF'
# Julia NFS Configuration Quick Reference

## Environment Setup (add to every SLURM script):
```bash
export JULIA_DEPOT_PATH="$HOME/.julia"
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
mkdir -p "$HOME/.julia_tmp"
export JULIA_PKG_PRECOMPILE_AUTO=0
```

## Julia Command:
```bash
julia --project=. --compiled-modules=no --history-file=no script.jl
```

## Or source the setup script:
```bash
source ~/globtim_hpc/scripts/setup_julia_nfs_env.sh
```
EOF

echo "Quick reference saved to ~/globtim_hpc/NFS_JULIA_SETUP.md"
```

---

**Continue to Part 3: Production Deployment →**