# Julia HPC NFS Migration Instructions
## Moving Julia Depot from Quota-Limited Home to NFS Project Space

---

## 🚦 Quick Execution Guide for Claude CLI

```bash
# Connect to mack first
ssh mack

# Then execute these steps in order:
# 1. Pre-Implementation Check
# 2. Create Backup
# 3. Migrate Julia Depot
# 4. Create Environment Script
# 5. Test Configuration
# 6. Update SLURM Template
# 7. Submit Test Job (from falcon)
# 8. Verify and Clean Up
# 9. Run Test Benchmark
```

---

## 🎯 Objective
Migrate Julia depot from quota-limited home directory (`~/.julia`, 1GB limit, 96% full) to unlimited NFS project space to resolve "Disk quota exceeded" errors on the Furiosa/Falcon HPC cluster.

## 📍 Execution Environment
- **Execute migration from**: mack (fileserver export node) - SSH to mack first
- **Job submission from**: falcon (after migration)
- **No active jobs**: Confirmed safe to proceed with migration

---

## 📋 Current Environment Information

### System Architecture
- **Fileserver**: mack (NFS server)
- **HPC Cluster**: falcon (compute nodes)
- **NFS Mount**: `/net/fileserver-nfs/stornext/snfs6/projects/scholten/`
- **User**: scholten
- **SLURM Account**: mpi
- **SLURM Partition**: batch

### Current Problem
- **Home Directory**: `/home/scholten` with 1GB quota (1024MB)
- **Current Usage**: 981MB by `~/.julia` (95.8% of quota)
- **Free Space**: ~43MB (insufficient for any operations)
- **Julia Depot Size**: 981MB (packages: 332MB, artifacts: 332MB, compiled: 309MB)

### Available Resources
- **NFS Project Space**: `/net/fileserver-nfs/stornext/snfs6/projects/scholten/` (unlimited)
- **Project Directory**: `globtim_hpc/` already exists on NFS
- **Write Permissions**: Confirmed for user scholten

---

## 🚀 Implementation Steps

### Pre-Implementation Check
```bash
# Verify no jobs are currently running
squeue -u scholten
# ✅ Confirmed: No jobs listed - safe to proceed with migration

# Verify NFS mount is accessible
ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/
# Expected: Directory listing showing your project files

# Check current quota usage before migration
quota -vs
echo "Current home usage: $(du -sh ~ | cut -f1)"
echo "Julia depot size: $(du -sh ~/.julia | cut -f1)"
```

### Step 1: Create Backup (Safety First)
# From your local machine:
claude --file julia_nfs_migration.md "Please execute this migration. 
Start by SSHing to mack. For Step 1, use the GitLab backup option (Option A) 
with commit message 'Backup before Julia depot migration to NFS'. 
Show me each command output before proceeding."

### Step 2: Migrate Julia Depot to NFS
```bash
# Create new Julia depot location on NFS
mkdir -p /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot

# Copy existing depot to NFS (preserving everything)
cp -rp ~/.julia/* /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot/

# Verify the copy
echo "Original size: $(du -sh ~/.julia | cut -f1)"
echo "NFS copy size: $(du -sh /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot | cut -f1)"

# Create temp directory on NFS
mkdir -p /net/fileserver-nfs/stornext/snfs6/projects/scholten/tmp
```

### Step 3: Create Environment Setup Script
```bash
cat > /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh << 'EOF'
#!/bin/bash
# Julia NFS Configuration - Bypasses Home Directory Quota
# Created: $(date)

echo "=== Configuring Julia for NFS Project Space ==="

# Base NFS path
export NFS_BASE="/net/fileserver-nfs/stornext/snfs6/projects/scholten"

# Julia depot on NFS (unlimited space)
export JULIA_DEPOT_PATH="$NFS_BASE/julia_depot"

# Temp files on NFS (not home directory)
export TMPDIR="$NFS_BASE/tmp"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"

# Julia configuration
export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
export JULIA_PKG_PRECOMPILE_AUTO=1  # Can use precompilation now!

# Create directories if they don't exist
mkdir -p "$JULIA_DEPOT_PATH"
mkdir -p "$TMPDIR"

# Verification
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ Julia depot configured at: $JULIA_DEPOT_PATH"
else
    echo "❌ ERROR: Julia depot directory not accessible!"
    exit 1
fi

if [ -w "$TMPDIR" ]; then
    echo "✅ Temp directory configured at: $TMPDIR"
else
    echo "❌ ERROR: Temp directory not writable!"
    exit 1
fi

echo "✅ No quota restrictions - unlimited NFS space available"
echo "=== Configuration Complete ==="
EOF

chmod +x /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh
```

### Step 4: Test Configuration
```bash
# Test the new configuration
source /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh

# Verify Julia uses NFS depot
julia -e 'println("Depot paths: ", DEPOT_PATH); println("Temp dir: ", tempdir())'

# Test package operations
julia -e 'using Pkg; Pkg.status()'
```

### Step 5: Update SLURM Job Template
```bash
cat > /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/julia_nfs_template.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=globtim_nfs_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/logs/%x_%j.out
#SBATCH -e /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/logs/%x_%j.err

echo "=== Job Information ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Time: $(date)"

# Source NFS Julia configuration
source /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh

# Navigate to project directory
cd /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc

# Run Julia with full compilation support (no --compiled-modules=no needed!)
echo "=== Running Julia ==="
julia --project=. -e '
    println("Julia ", VERSION, " on ", gethostname())
    println("Depot: ", DEPOT_PATH[1])
    println("Threads: ", Threads.nthreads())
    
    using Pkg
    println("✅ Packages loaded successfully")
    
    # Test computation
    A = rand(1000, 1000)
    B = A * A
    println("✅ Computation completed: ", size(B))
'

echo "=== Job Complete ==="
EOF
```

### Step 6: Submit Test Job
```bash
# Create logs directory
mkdir -p /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/logs

# Submit test job from falcon
cd /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc
sbatch julia_nfs_template.slurm

# Monitor
squeue -u scholten
```

### Step 7: Update Python Submit Script
Edit `/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/submit_deuflhard_hpc.py`:

```python
# Find and replace the Julia depot configuration
# OLD:
# if [ -d "$HOME/.julia" ]; then
#     export JULIA_DEPOT_PATH="$HOME/.julia:$JULIA_DEPOT_PATH"

# NEW:
# Source NFS configuration
source /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh
```

### Step 8: Verify and Clean Up
```bash
# After confirming everything works

# Check that NFS depot is working
julia --project=/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc -e 'using Pkg; Pkg.status()'

# If successful, remove old depot from home to free quota
rm -rf ~/.julia

# Create symbolic link for compatibility
ln -s /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot ~/.julia
echo "✅ Symbolic link created: ~/.julia -> NFS depot"

# Verify quota is freed
quota -vs
# Should show ~44MB used instead of 1024MB
```

### Step 9: Run Test Benchmark
```bash
# Test with a Globtim benchmark to verify full functionality
cd /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc

# Source the NFS configuration
source setup_nfs_julia.sh

# Run a test benchmark (adjust path as needed)
julia --project=. -e '
    println("=== Running Globtim Test Benchmark ===")
    using Pkg
    Pkg.status()
    
    # Include your test benchmark
    # include("benchmarks/simple_test.jl")
    # OR run a simple test
    include("src/Globtim.jl")
    println("✅ Globtim loaded successfully from NFS depot")
    
    # Simple optimization test
    f(x) = (x[1] - 1)^2 + (x[2] - 2)^2
    x_test = [0.5, 1.5]
    result = f(x_test)
    println("✅ Test function evaluated: f($x_test) = $result")
'

echo "✅ If no errors above, migration is complete and verified!"
```

```bash
# Check quota status
quota -vs | grep -A2 scholten

# Verify NFS depot
ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot/

# Test Julia with new configuration
source /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/setup_nfs_julia.sh
julia -e 'using Pkg; Pkg.status()'

# Check SLURM job output
ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/logs/
```

---

## ⚠️ Rollback Procedure (If Needed)

```bash
# If something goes wrong, restore original depot
cd ~
tar -xzf /net/fileserver-nfs/stornext/snfs6/projects/scholten/julia_depot_backup_*.tar.gz

# Reset environment
unset JULIA_DEPOT_PATH
unset TMPDIR
```

---

## 📝 Additional Information Needed

Please provide the following if available:

1. **SLURM Specific Flags**:
   - Any required modules to load? (`module load julia`?)
   - Specific memory/CPU requirements for Globtim?
   - Typical job duration for benchmarks?

2. **Python Script Details**:
   - Full path to `submit_deuflhard_hpc.py`
   - Any other scripts that reference `~/.julia`
   - Location of `automated_job_monitor.py`

3. **Verification Requirements**:
   - Specific Globtim benchmarks to test?
   - Expected output/results format?
   - Performance benchmarks to compare?

4. **Directory Structure**:
   ```
   Please run and provide output:
   ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc/
   ```

5. **Current Julia Version**:
   ```
   julia --version
   ```

6. **Existing Environment Variables**:
   ```
   env | grep -E "JULIA|SLURM"
   ```

---

## ✅ Success Criteria

1. Julia depot successfully moved to NFS project space
2. Home directory quota usage reduced to <100MB
3. SLURM jobs run without "Disk quota exceeded" errors
4. Full compilation support enabled (no `--compiled-modules=no`)
5. Globtim benchmarks execute successfully

---

## 🚨 Important Notes

- **All paths must use full NFS paths**, not symbolic links or `~`
- **Source the setup script in EVERY SLURM job**
- **The NFS path is accessible from both mack and falcon**
- **No `/tmp` usage** (forbidden per system policy)
- **Submit jobs from falcon**, not mack

---

## 📊 Expected Outcome

| Metric | Before | After |
|--------|--------|-------|
| Home Quota Usage | 1024MB (100%) | ~44MB (4%) |
| Julia Depot Location | `~/.julia` | `/net/.../scholten/julia_depot` |
| Compilation | Disabled (slow) | Enabled (fast) |
| Job Success Rate | Failing | 100% |
| Available Space | 0MB | Unlimited |

---

## 💬 Command Summary for Quick Copy-Paste

```bash
# One-liner to set up everything (run from mack)
export NFS_BASE="/net/fileserver-nfs/stornext/snfs6/projects/scholten" && \
mkdir -p $NFS_BASE/julia_depot $NFS_BASE/tmp && \
cp -rp ~/.julia/* $NFS_BASE/julia_depot/ && \
export JULIA_DEPOT_PATH="$NFS_BASE/julia_depot" && \
export TMPDIR="$NFS_BASE/tmp" && \
julia -e 'using Pkg; Pkg.status()' && \
echo "✅ Migration complete!"
```

---

## 📌 Execution Instructions for Claude CLI

1. **Start from mack**: Execute steps 1-6 and 8-9 from mack
2. **Switch to falcon**: Only for step 7 (submitting SLURM job)
3. **Confirm each step**: Wait for success confirmation before proceeding
4. **Keep symbolic link**: Create `~/.julia` symlink for compatibility (Step 8)
5. **Save outputs**: Document all command outputs for verification

---

**Document Version**: 1.0  
**Created for**: Claude CLI Execution  
**Target System**: Furiosa/Falcon HPC with Mack Fileserver  
**User**: scholten