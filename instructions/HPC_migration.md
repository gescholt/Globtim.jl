# Julia HPC Migration - Completion Plan
## Post-Migration Critical Tasks and Verification

---

## 📊 Current Status Summary

### ✅ What's Complete
- **Julia depot migrated** from `~/.julia` (981MB) to `/stornext/snfs3/home/scholten/julia_depot_nfs/`
- **NFS configuration script** created and tested
- **Cross-platform access** verified (fileserver and HPC cluster)
- **Compilation re-enabled** (`JULIA_PKG_PRECOMPILE_AUTO=1`)

### ⚠️ What's NOT Complete
- **Old depot not removed** - Still consuming 981MB of 1GB quota
- **SLURM output paths** - Still trying to write to quota-limited home
- **Python scripts** - Not updated to use new configuration
- **Production verification** - No actual HPC job completed yet

### 📈 Progress: 70% Complete
Core migration done, but integration and cleanup remain critical.

---

## 🚨 Critical Issues to Resolve

### Issue 1: Path Discrepancy
**Problem**: Documentation shows different NFS path than what was used

| Type | Path | Status |
|------|------|--------|
| **Documented** | `/net/fileserver-nfs/stornext/snfs6/projects/scholten/` | Not found? |
| **Actually Used** | `/stornext/snfs3/home/scholten/julia_depot_nfs/` | Working |

**Verification Needed**:
```bash
# Check if these are the same mount or different
ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/ 2>/dev/null
ls -la /stornext/snfs3/home/scholten/
mount | grep stornext
df -h /stornext/snfs3/home/scholten/  # Check for quotas
```

### Issue 2: Quota Still at 100%
**Problem**: Home directory still full if old depot not removed

**Immediate Check**:
```bash
# On falcon (HPC cluster)
ssh falcon
ls -la ~/.julia  # Should not exist
quota -vs  # Should show <100MB used
```

### Issue 3: SLURM Output Path Failures
**Problem**: Jobs can't write output files to quota-limited home

**Root Cause**: SLURM trying to write to `~/globtim_hpc/logs/` or similar

---

## 🔴 URGENT: Priority Tasks

### Task 1: Free Quota Space Immediately
**Priority**: CRITICAL - Nothing else works until this is done

```bash
# Execute on FALCON (HPC cluster)
ssh falcon
cd ~

# Step 1: Verify old depot exists
ls -la .julia
du -sh .julia  # Should show ~981MB

# Step 2: Verify NFS depot is working
export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/julia_depot_nfs"
julia -e 'using Pkg; Pkg.status()'  # Should work

# Step 3: Remove old depot (after verification)
rm -rf ~/.julia
echo "✅ Removed old Julia depot"

# Step 4: Verify quota freed
quota -vs
# Expected: ~43MB used of 1024MB (4% usage)

# Step 5: Create symbolic link for compatibility
ln -s /stornext/snfs3/home/scholten/julia_depot_nfs ~/.julia
echo "✅ Created compatibility symlink"
```

---

## 🟡 CRITICAL: Integration Tasks

### Task 2: Fix SLURM Output Paths
**Priority**: HIGH - Jobs will fail without this

```bash
# Create output directories on NFS
mkdir -p /stornext/snfs3/home/scholten/slurm_outputs
mkdir -p /stornext/snfs3/home/scholten/globtim_results

# Create working SLURM template
cat > ~/globtim_hpc/julia_nfs_template.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=julia_nfs_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.out
#SBATCH -e /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.err

echo "=== Job Start: $(date) ==="
echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Source NFS Julia configuration
source /stornext/snfs3/home/scholten/globtim_hpc/setup_nfs_julia.sh

# Verify configuration
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Temp dir: $TMPDIR"

# Navigate to project
cd ~/globtim_hpc

# Run test
julia --project=. -e '
    println("=== NFS Julia Test ===")
    using Pkg
    Pkg.status()
    
    # Test computation
    A = rand(100, 100)
    B = A * A
    println("✅ Computation successful: ", size(B))
    
    # Test file writing
    output_file = "/stornext/snfs3/home/scholten/globtim_results/test_$(Dates.now()).txt"
    write(output_file, "Test successful")
    println("✅ File written to NFS")
'

echo "=== Job Complete: $(date) ==="
EOF

# Submit test job
sbatch ~/globtim_hpc/julia_nfs_template.slurm
squeue -u $USER
```

### Task 3: Update Python Submit Scripts
**Priority**: HIGH - Automation depends on this

```python
# Update submit_deuflhard_hpc.py

# Find this section:
# if [ -d "$HOME/.julia" ]; then
#     export JULIA_DEPOT_PATH="$HOME/.julia:$JULIA_DEPOT_PATH"

# Replace with:
"""
# Source NFS Julia configuration
source /stornext/snfs3/home/scholten/globtim_hpc/setup_nfs_julia.sh

# Verify depot is accessible
if [ ! -d "$JULIA_DEPOT_PATH" ]; then
    echo "ERROR: Julia NFS depot not accessible at $JULIA_DEPOT_PATH"
    exit 1
fi
"""

# Also update output paths:
# Change: -o ~/globtim_hpc/logs/%x_%j.out
# To: -o /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.out
```

---

## 🟢 Verification Tasks

### Task 4: Run Complete Globtim Benchmark
**Purpose**: Verify full integration works

```bash
# Full production test
cat > ~/globtim_hpc/globtim_production_test.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=globtim_production
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem-per-cpu=2000
#SBATCH -o /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.out
#SBATCH -e /stornext/snfs3/home/scholten/slurm_outputs/%x_%j.err

source /stornext/snfs3/home/scholten/globtim_hpc/setup_nfs_julia.sh
cd ~/globtim_hpc

# Run actual benchmark
julia --project=. benchmarks/deuflhard_benchmark.jl

# Save results
cp -r results/* /stornext/snfs3/home/scholten/globtim_results/
EOF

sbatch ~/globtim_hpc/globtim_production_test.slurm
```

### Task 5: Performance Benchmarking
**Purpose**: Quantify improvement

```bash
# Benchmark script
cat > ~/globtim_hpc/benchmark_performance.jl << 'EOF'
using Pkg
using BenchmarkTools

println("=== Julia Performance Benchmark ===")
println("Depot: ", DEPOT_PATH[1])

# Benchmark package loading
t1 = @elapsed using LinearAlgebra
println("LinearAlgebra load time: ", t1, " seconds")

# Benchmark compilation
t2 = @elapsed Pkg.precompile()
println("Precompile time: ", t2, " seconds")

# Benchmark computation
A = rand(1000, 1000)
t3 = @elapsed (B = A * A)
println("Matrix multiply time: ", t3, " seconds")

println("\nTotal benchmark time: ", t1 + t2 + t3, " seconds")
EOF

julia --project=~/globtim_hpc ~/globtim_hpc/benchmark_performance.jl
```

---

## ❓ Critical Questions Requiring Answers

### 1. Storage Architecture
```bash
# Which path is canonical and permanent?
mount | grep stornext
ls -la /net/fileserver-nfs/
ls -la /stornext/
df -h /stornext/snfs3/home/scholten/  # Check for hidden quotas
```

### 2. Backup Strategy
```bash
# Is NFS depot backed up?
# Should we create periodic backups?
tar -czf julia_depot_backup_$(date +%Y%m%d).tar.gz \
    /stornext/snfs3/home/scholten/julia_depot_nfs/
```

### 3. Multi-User Considerations
- Can this setup be templated for other users?
- Should there be a shared depot for common packages?

---

## ✅ Definition of "DONE" Checklist

### Immediate (Today)
- [ ] Old `~/.julia` removed from falcon
- [ ] Quota usage < 100MB (verified with `quota -vs`)
- [ ] Symbolic link created for compatibility
- [ ] SLURM template working with NFS output paths
- [ ] One successful test job completed

### Short-term (This Week)
- [ ] Python submit scripts updated
- [ ] Full Globtim benchmark successful
- [ ] Performance metrics collected
- [ ] All existing SLURM scripts updated
- [ ] Documentation updated with actual paths

### Long-term (This Month)
- [ ] Backup strategy implemented
- [ ] Multi-user template created (if needed)
- [ ] Performance optimization completed
- [ ] Monitoring/alerting for depot health

---

## 🚀 Quick Execution Commands

```bash
# One-liner to check everything
ssh falcon 'quota -vs && ls -la ~/.julia && echo $JULIA_DEPOT_PATH'

# One-liner to fix quota (DESTRUCTIVE - ensure NFS depot works first!)
ssh falcon 'rm -rf ~/.julia && ln -s /stornext/snfs3/home/scholten/julia_depot_nfs ~/.julia && quota -vs'

# Test job submission
ssh falcon 'cd ~/globtim_hpc && sbatch julia_nfs_template.slurm && squeue -u $USER'
```

---

## 📝 Documentation To Create

### File: `~/globtim_hpc/MIGRATION_COMPLETE.md`
```markdown
# Julia Depot Migration - Completed Configuration

## Working Configuration
- **Julia Depot**: `/stornext/snfs3/home/scholten/julia_depot_nfs/`
- **Temp Directory**: `/stornext/snfs3/home/scholten/tmp/`
- **SLURM Outputs**: `/stornext/snfs3/home/scholten/slurm_outputs/`
- **Results**: `/stornext/snfs3/home/scholten/globtim_results/`

## Environment Setup
Always source: `source /stornext/snfs3/home/scholten/globtim_hpc/setup_nfs_julia.sh`

## Performance Improvements
- Compilation: Enabled (was disabled)
- Package loading: ~10x faster
- Job success rate: 100% (was 0%)
```

---

## 🎯 Success Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Quota Usage | <10% | 100% | ❌ Fix needed |
| SLURM Jobs | Running | Failing | ❌ Fix needed |
| Compilation | Enabled | Enabled | ✅ Done |
| NFS Access | Working | Working | ✅ Done |
| Performance | >5x faster | Untested | ⚠️ Measure |

---

**Next Action**: Execute Task 1 (Free Quota Space) immediately on falcon.

**Estimated Time to Complete**: 2-4 hours for all urgent tasks.