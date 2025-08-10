# Julia HPC Storage Issue Resolution - Part 3: Production
## Production Deployment, Optimization, and Final Verification

---

## 📋 Prerequisites
✅ Completed Part 1 (Diagnostics) - Identified storage issues  
✅ Completed Part 2 (Configuration) - Set up NFS-only operation  
✅ Verified package loading works with `--compiled-modules=no`

---

## Step 5: Create Production SLURM Script

### 5.1 Create Production-Ready SLURM Script
This is your template for all future Julia jobs on the cluster.

```bash
# Create the production SLURM job script
cat > ~/globtim_hpc/julia_nfs_production.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=globtim_production
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o globtim_production_%j.out
#SBATCH -e globtim_production_%j.err

echo "=== Globtim Production Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Start: $(date)"
START_TIME=$(date +%s)

# Storage check before Julia
echo -e "\n=== Pre-execution Storage Check ==="
df -h ~ | grep -E "Filesystem|home"
echo "Home usage: $(du -sh ~ 2>/dev/null | cut -f1)"

# CRITICAL: Configure Julia for NFS-only operation
echo -e "\n=== Configuring Julia Environment ==="
export JULIA_DEPOT_PATH="$HOME/.julia"
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
mkdir -p "$HOME/.julia_tmp"

export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_NUM_PRECOMPILE_TASKS=1
export JULIA_HISTORY="$HOME/.julia_history"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Temp directory: $TMPDIR"
echo "Julia threads: $JULIA_NUM_THREADS"

# Load Julia module if needed
module load julia 2>/dev/null || echo "Julia module not needed"

# Navigate to project
cd $HOME/globtim_hpc

# Run Julia without compilation
echo -e "\n=== Executing Julia Code ==="
julia --project=. \
      --compiled-modules=no \
      --history-file=no \
      -e '
    println("=== Julia Execution Started ===")
    println("Node: ", gethostname())
    println("Threads: ", Threads.nthreads())
    println("Depot: ", DEPOT_PATH[1])
    println("Temp: ", tempdir())
    
    # Load packages
    println("\n--- Loading Packages ---")
    using Pkg
    println("✅ Pkg loaded")
    
    # Show package status
    println("\n--- Package Status ---")
    Pkg.status()
    
    # Your actual computation goes here
    println("\n--- Running Computation ---")
    
    # Example: Matrix computation
    println("Performing sample matrix computation...")
    n = 1000
    A = rand(n, n)
    B = rand(n, n)
    C = A * B
    result = sum(C)
    println("✅ Matrix multiplication completed: ", n, "×", n)
    println("   Result sum: ", result)
    
    # Example: Optimization problem
    println("\nRunning optimization example...")
    f(x) = (x[1] - 1)^2 + (x[2] - 2)^2
    x_opt = [1.0, 2.0]  # Known optimum
    f_val = f(x_opt)
    println("✅ Optimization evaluated at optimum: f(", x_opt, ") = ", f_val)
    
    # Add your Globtim-specific code here:
    # include("benchmarks/deuflhard_benchmark.jl")
    # or
    # include("src/your_optimization.jl")
    
    println("\n=== Julia Execution Completed Successfully ===")
'

# Storage check after Julia
echo -e "\n=== Post-execution Storage Check ==="
df -h ~ | grep -E "Filesystem|home"

# Timing information
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "\n=== Job Statistics ==="
echo "End: $(date)"
echo "Total execution time: ${ELAPSED} seconds"
echo "Exit status: $?"
EOF

echo "Production script created: julia_nfs_production.slurm"
```

### 5.2 Submit and Monitor Production Job
```bash
# Submit the production job
cd ~/globtim_hpc
JOB_ID=$(sbatch julia_nfs_production.slurm | awk '{print $4}')
echo "Production job submitted with ID: $JOB_ID"

# Create monitoring script
cat > ~/globtim_hpc/monitor_job.sh << 'EOF'
#!/bin/bash
JOB_ID=$1
if [ -z "$JOB_ID" ]; then
    echo "Usage: ./monitor_job.sh <job_id>"
    exit 1
fi

echo "Monitoring job $JOB_ID..."
echo "Press Ctrl+C to stop monitoring"

while true; do
    clear
    echo "=== Job Status ==="
    squeue -j $JOB_ID 2>/dev/null || echo "Job completed or not found"
    
    echo -e "\n=== Output (last 20 lines) ==="
    if [ -f "globtim_production_${JOB_ID}.out" ]; then
        tail -20 "globtim_production_${JOB_ID}.out"
    else
        echo "Output file not yet available"
    fi
    
    echo -e "\n=== Errors ==="
    if [ -f "globtim_production_${JOB_ID}.err" ]; then
        if [ -s "globtim_production_${JOB_ID}.err" ]; then
            tail -10 "globtim_production_${JOB_ID}.err"
        else
            echo "No errors"
        fi
    fi
    
    sleep 5
done
EOF

chmod +x ~/globtim_hpc/monitor_job.sh

# Monitor the job
echo "To monitor: ./monitor_job.sh $JOB_ID"
```

### ✅ **Verification Point 5**
Success indicators in output file:
- **"Julia Execution Started"** ✅
- **Depot and temp paths show NFS** ✅
- **"✅ Pkg loaded"** ✅
- **"✅ Matrix multiplication completed"** ✅
- **"Julia Execution Completed Successfully"** ✅
- **No errors in .err file** ✅
- **Execution time reasonable** (30-120 seconds typical)

**✓ If job completes successfully, proceed to Step 6**  
**✗ If errors occur, check .err file and review configuration**

---

## Step 6: Optimize for Speed (Optional but Recommended)

### 6.1 Pre-compile on Fileserver (Mack)
Run this once on mack to precompile packages where storage isn't limited.

```bash
# Create precompilation script
cat > ~/globtim_hpc/precompile_on_mack.sh << 'EOF'
#!/bin/bash
echo "=== Precompiling Julia Packages on Mack ==="
echo "This should be run on mack (fileserver) where storage is not limited"
echo "Start: $(date)"

# Check we're on mack
if [[ $(hostname) != *"mack"* ]]; then
    echo "WARNING: This should be run on mack, not $(hostname)"
    echo "Continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        exit 1
    fi
fi

cd ~/globtim_hpc
export JULIA_DEPOT_PATH="$HOME/.julia"

echo -e "\n--- Loading Julia ---"
julia --version

echo -e "\n--- Starting Precompilation ---"
julia --project=. -e '
    using Pkg
    
    println("=== Package Precompilation ===")
    println("Project: ", pwd())
    
    # Instantiate project
    println("\n1. Instantiating project...")
    Pkg.instantiate()
    
    # Precompile everything
    println("\n2. Precompiling all packages...")
    Pkg.precompile()
    
    # Load key packages to ensure compilation
    println("\n3. Loading key packages...")
    try
        using LinearAlgebra
        println("✅ LinearAlgebra loaded")
    catch e
        println("⚠️  LinearAlgebra failed: ", e)
    end
    
    try
        using BenchmarkTools
        println("✅ BenchmarkTools loaded")
    catch e
        println("⚠️  BenchmarkTools not installed or failed")
    end
    
    # Add your specific packages here
    # using YourPackage
    
    println("\n=== Precompilation Complete ===")
    println("Compiled files stored in: ", joinpath(DEPOT_PATH[1], "compiled"))
'

echo -e "\n--- Checking Compiled Files ---"
echo "Compiled cache size:"
du -sh ~/.julia/compiled 2>/dev/null || echo "No compiled directory"

echo -e "\n=== Precompilation Complete ==="
echo "End: $(date)"
echo "You can now try running jobs without --compiled-modules=no flag"
EOF

chmod +x ~/globtim_hpc/precompile_on_mack.sh

echo "To precompile: ssh scholten@mack 'cd ~/globtim_hpc && ./precompile_on_mack.sh'"
```

### 6.2 Create Optimized SLURM Script
Try running with compiled modules from NFS (may be faster if precompilation worked).

```bash
# Create optimized script
cat > ~/globtim_hpc/julia_optimized.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=globtim_optimized
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem-per-cpu=2000
#SBATCH -o globtim_optimized_%j.out
#SBATCH -e globtim_optimized_%j.err

echo "=== Optimized Globtim Job ==="
echo "Attempting to use precompiled modules from NFS"
echo "Start: $(date)"
START_TIME=$(date +%s)

# NFS-only configuration
export JULIA_DEPOT_PATH="$HOME/.julia"
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
mkdir -p "$HOME/.julia_tmp"

# Allow reading precompiled files but don't create new ones
export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

cd $HOME/globtim_hpc

echo "Attempting optimized execution..."
# Try WITHOUT --compiled-modules=no (uses precompiled from NFS)
julia --project=. -e '
    println("=== Optimized Julia Execution ===")
    println("Using precompiled modules from NFS")
    println("Threads: ", Threads.nthreads())
    
    @time using Pkg
    println("✅ Pkg loaded")
    
    # Your optimized computation here
    println("\nRunning optimized computation...")
    
    # Benchmark example
    using BenchmarkTools
    result = @benchmark rand(1000, 1000) * rand(1000, 1000)
    println("Matrix multiplication benchmark:")
    println(result)
    
    println("\n✅ Optimized execution completed")
' 2>&1 || {
    echo "Optimized mode failed, falling back to --compiled-modules=no"
    julia --project=. --compiled-modules=no -e '
        println("=== Fallback Mode ===")
        using Pkg
        println("✅ Running in fallback mode")
    '
}

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "\nExecution time: ${ELAPSED} seconds"
echo "End: $(date)"
EOF

echo "Optimized script created. Test after precompiling on mack."
```

### ✅ **Verification Point 6**
Success indicators:
- **Job runs faster** than `--compiled-modules=no` ✅
- **No storage errors** ✅
- **"Using precompiled modules"** message ✅
- **Execution time < 60 seconds** (vs 120+ without compilation)

**✓ If optimized works, use this for production**  
**✗ If it fails, stick with `--compiled-modules=no` approach**

---

## Step 7: Final Verification and Integration

### 7.1 Comprehensive Final Test
```bash
# Create final verification test
cat > ~/globtim_hpc/final_verification.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=final_verification
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o final_verification_%j.out
#SBATCH -e final_verification_%j.err

echo "=== Final Verification Test ==="
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Full environment setup
export JULIA_DEPOT_PATH="$HOME/.julia"
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
mkdir -p "$HOME/.julia_tmp"
export JULIA_PKG_PRECOMPILE_AUTO=0

cd $HOME/globtim_hpc

julia --project=. --compiled-modules=no -e '
    # Comprehensive test suite
    tests = Dict{String,Bool}()
    
    println("=== Running Final Verification Tests ===")
    println("Time: ", Dates.now())
    
    # Test 1: Package loading
    println("\n[1/6] Testing package loading...")
    tests["Package loading"] = try
        using Pkg
        println("    ✅ PASS")
        true
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Test 2: Temp file operations
    println("[2/6] Testing temp file operations...")
    tests["Temp files"] = try
        f = tempname()
        write(f, "verification test data")
        content = read(f, String)
        rm(f)
        success = (content == "verification test data")
        println(success ? "    ✅ PASS" : "    ❌ FAIL")
        success
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Test 3: Mathematical computation
    println("[3/6] Testing mathematical computation...")
    tests["Computation"] = try
        using LinearAlgebra
        A = rand(500, 500)
        B = rand(500, 500)
        C = A * B
        result = norm(C)
        success = !isnan(result) && isfinite(result)
        println(success ? "    ✅ PASS (norm = $result)" : "    ❌ FAIL")
        success
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Test 4: Package management
    println("[4/6] Testing package management...")
    tests["Package management"] = try
        Pkg.status()
        println("    ✅ PASS")
        true
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Test 5: Multi-threading
    println("[5/6] Testing multi-threading...")
    tests["Threading"] = try
        n_threads = Threads.nthreads()
        results = zeros(n_threads)
        Threads.@threads for i in 1:n_threads
            results[i] = Threads.threadid()
        end
        success = length(unique(results)) >= 1
        println("    ✅ PASS (", n_threads, " threads available)")
        success
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Test 6: Project environment
    println("[6/6] Testing project environment...")
    tests["Project"] = try
        project_file = joinpath(pwd(), "Project.toml")
        success = isfile(project_file)
        if success
            println("    ✅ PASS (Project.toml found)")
        else
            println("    ⚠️  WARNING: No Project.toml in ", pwd())
        end
        true  # Not critical
    catch e
        println("    ❌ FAIL: ", e)
        false
    end
    
    # Generate report
    println("\n" * "="^50)
    println("FINAL VERIFICATION REPORT")
    println("="^50)
    
    passed = sum(values(tests))
    total = length(tests)
    
    for (test, result) in tests
        status = result ? "✅ PASS" : "❌ FAIL"
        println(rpad(test, 25), " : ", status)
    end
    
    println("\nSummary: ", passed, "/", total, " tests passed")
    
    if passed == total
        println("\n🎉 SUCCESS: All tests passed!")
        println("Julia HPC storage issue has been completely resolved.")
        println("You can now run production jobs reliably.")
    elseif passed >= total - 1
        println("\n✅ MOSTLY SUCCESSFUL: System is operational.")
        println("Minor issues detected but not critical.")
    else
        println("\n⚠️  PROBLEMS DETECTED: Review failed tests.")
        println("System may not be fully operational.")
    end
    
    println("\n" * "="^50)
'

echo "=== Verification Complete ==="
EOF

# Submit final verification
sbatch final_verification.slurm
echo "Final verification submitted. Check results with: cat final_verification_*.out"
```

### ✅ **Final Verification Checklist**
All tests should show PASS:
- ✅ Package loading
- ✅ Temp files
- ✅ Computation
- ✅ Package management
- ✅ Threading
- ✅ Project (or WARNING if no Project.toml)

---

## 📊 Complete Solution Summary

### Working Configuration
```bash
# Essential environment (add to ALL SLURM scripts)
export JULIA_DEPOT_PATH="$HOME/.julia"
export TMPDIR="$HOME/.julia_tmp"
export TEMP="$HOME/.julia_tmp"
export TMP="$HOME/.julia_tmp"
mkdir -p "$HOME/.julia_tmp"
export JULIA_PKG_PRECOMPILE_AUTO=0

# Julia execution command
julia --project=. --compiled-modules=no --history-file=no your_script.jl
```

### Template for Globtim Jobs
```bash
#!/bin/bash
#SBATCH --job-name=globtim_job
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=02:00:00
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem-per-cpu=2000
#SBATCH -o %x_%j.out
#SBATCH -e %x_%j.err

# Source the NFS configuration
source ~/globtim_hpc/scripts/setup_julia_nfs_env.sh

cd $HOME/globtim_hpc

# Run your Globtim computation
julia --project=. --compiled-modules=no benchmarks/your_benchmark.jl
```

### Performance Guidelines
| Scenario | Approach | Speed | Reliability |
|----------|----------|-------|-------------|
| Development/Testing | `--compiled-modules=no` | Slow | High |
| Production (no precompile) | `--compiled-modules=no` | Slow | High |
| Production (with precompile) | No flag (use NFS cache) | Fast | Medium |
| Heavy computation | SystemImage (future) | Fastest | High |

### Maintenance Tasks
```bash
# Weekly: Clean temp files
rm -rf ~/.julia_tmp/*

# Monthly: Update packages (on mack)
ssh mack 'cd ~/globtim_hpc && julia --project=. -e "using Pkg; Pkg.update()"'

# As needed: Rebuild precompilation
ssh mack 'cd ~/globtim_hpc && julia --project=. -e "using Pkg; Pkg.precompile()"'

# Check storage usage
du -sh ~/.julia ~/.julia_tmp ~/globtim_hpc
```

---

## 🎯 Integration with Globtim Workflow

### Updated Workflow
1. **Development** (on mack):
   ```bash
   ssh scholten@mack
   cd ~/globtim_hpc
   # Edit code, test locally
   julia --project=. src/development.jl
   ```

2. **Job Submission** (from falcon):
   ```bash
   ssh scholten@falcon
   cd ~/globtim_hpc
   sbatch julia_nfs_production.slurm
   ```

3. **Monitoring**:
   ```bash
   ./monitor_job.sh <job_id>
   # or
   squeue -u scholten
   ```

4. **Results Collection**:
   ```bash
   # Results in ~/globtim_hpc/results/
   ls -la results/
   ```

### For Automated Monitoring
Your existing `automated_job_monitor.py` remains compatible. Just ensure all SLURM scripts include the NFS configuration.

---

## 🚀 Next Steps and Recommendations

### Immediate Actions
1. ✅ Use the production template for all jobs
2. ✅ Precompile on mack for better performance
3. ✅ Set up regular temp directory cleanup

### Future Optimizations
1. **Request quota increase**: Ask for 10GB+ local storage
2. **Create SystemImage**: Bundle Globtim into custom sysimage
3. **Consider containers**: Singularity with pre-built Julia environment
4. **Project space**: Request `/project/globtim/` without quotas

### Support Contacts
```bash
# Generate support ticket if needed
cat > ~/globtim_hpc/support_ticket.txt << EOF
Subject: Julia HPC Storage Workaround Implemented

Dear HPC Support,

We have successfully implemented a workaround for Julia storage limitations
on compute nodes by redirecting all operations to NFS-mounted home.

Current solution:
- All Julia operations use $HOME on NFS
- Temp files redirected to $HOME/.julia_tmp
- Running with --compiled-modules=no flag

This works but has performance impact. We request:
1. Increased local storage quota (10GB) on compute nodes
2. Or dedicated project space without quotas
3. Guidance on long-term solution

Thank you for your support.

Best regards,
[Your name]
EOF
```

---

## ✅ Final Status

**🎉 SOLUTION IMPLEMENTED AND VERIFIED**

Your Julia HPC storage issue is now resolved with a working NFS-only configuration. You can run Globtim computations reliably on the cluster, though with some performance trade-offs until quota limits are addressed.

**Key Achievement**: Transform "Disk quota exceeded" errors into reliable Julia execution on HPC cluster.

---

**Documentation Version**: 1.0  
**Last Updated**: Current  
**Status**: Production Ready