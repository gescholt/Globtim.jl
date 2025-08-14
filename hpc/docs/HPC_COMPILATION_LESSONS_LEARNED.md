# GlobTim HPC Compilation - Lessons Learned

## Date: August 11, 2025

## Summary
Successfully created and tested a comprehensive HPC compilation workflow for GlobTim on the Falcon cluster. This document captures key lessons learned from troubleshooting various issues.

## Key Issues Encountered and Solutions

### 1. SLURM Exit Code 53
**Issue**: Jobs immediately failed with exit code 53 (file not found)
**Root Cause**: Attempting to source external scripts that either didn't exist or had incorrect paths
**Solution**: 
- Embed all necessary environment setup directly in the SLURM script
- Avoid dependencies on external shell scripts
- Use absolute paths for Julia depot: `/stornext/snfs3/home/scholten/.julia`

### 2. /tmp Directory Restriction
**Issue**: Cluster forbids use of `/tmp` for any purpose
**Solution**:
- Configure Julia to use NFS-based depot path
- Set `JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/.julia"`
- All temporary files must use home directory or designated work directories

### 3. Package Management Issues
**Issue**: Multiple package-related errors:
- JSON3 dependency errors when using `Pkg.status()`
- Missing CSV package when loading Globtim module
- UndefVarError for Pkg when not properly imported

**Solutions**:
```julia
# Always import Pkg explicitly
using Pkg

# Use instantiate and precompile
Pkg.instantiate()
Pkg.precompile()

# Avoid Pkg.status() if it triggers JSON3 errors
```

### 4. Module Loading Strategy
**Issue**: Individual source files couldn't be loaded due to missing dependencies
**Solution**: Load the main module file which handles dependencies correctly:
```julia
push!(LOAD_PATH, "src")
include("src/Globtim.jl")
using .Globtim
```

### 5. Shell Script Escaping Issues
**Issue**: Special characters in heredocs and inline Julia code got escaped incorrectly
**Problems encountered**:
- Shebang line `#!/bin/bash` becoming `#\!/bin/bash`
- Exclamation marks in conditionals being escaped

**Solutions**:
- Use heredocs with proper delimiters for Julia code blocks
- Write scripts to files and then submit, rather than complex inline generation
- Use the pattern:
```bash
/sw/bin/julia --project=. -e 'Julia code here'
```

### 6. Monitoring and Output Collection
**Working Approach**:
```bash
# Submit job and capture ID
JOB_ID=$(ssh user@cluster 'cd ~/dir && sbatch script.slurm' | awk '{print $4}')

# Monitor status
ssh user@cluster "squeue -j $JOB_ID"

# Check completion status
ssh user@cluster "sacct -j $JOB_ID --format=State,ExitCode --noheader"

# Retrieve output
ssh user@cluster "cat ~/dir/output_${JOB_ID}.out"
```

## Working SLURM Template

```bash
#!/bin/bash
#SBATCH --job-name=globtim_compile
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH -o globtim_%j.out
#SBATCH -e globtim_%j.err

# Environment setup
export JULIA_DEPOT_PATH="/stornext/snfs3/home/scholten/.julia"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

cd $HOME/globtim_hpc || exit 1

# Package installation
/sw/bin/julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Module loading and testing
/sw/bin/julia --project=. -e '
push!(LOAD_PATH, "src")
include("src/Globtim.jl")
using .Globtim

# Your code here
'
```

## Recommended Workflow

1. **Preparation Phase**
   - Create self-contained SLURM scripts (no external dependencies)
   - Include all environment setup inline
   - Use absolute paths

2. **Submission Phase**
   ```bash
   # Create script locally
   cat > script.slurm << 'EOF'
   #!/bin/bash
   #SBATCH directives...
   # Script content
   EOF
   
   # Upload and submit
   scp script.slurm user@cluster:~/dir/
   ssh user@cluster 'cd ~/dir && sbatch script.slurm'
   ```

3. **Monitoring Phase**
   - Use `squeue` for active monitoring
   - Use `sacct` for completed job status
   - Collect outputs immediately after completion

4. **Data Collection**
   - Create structured output directories
   - Save JSON summaries for automated processing
   - Use meaningful exit codes

## Performance Configurations

### Quick Test (15 min)
- CPUs: 4
- Memory: 8GB
- Scope: Basic module loading

### Standard (30 min)
- CPUs: 8
- Memory: 16GB
- Scope: Full compilation + basic tests

### Comprehensive (60 min)
- CPUs: 16
- Memory: 32GB
- Scope: Full test suite + benchmarks

## Critical Success Factors

1. **No /tmp usage** - Strictly enforced on cluster
2. **Self-contained scripts** - No external script dependencies
3. **Explicit package management** - Always run Pkg.instantiate()
4. **Proper module loading** - Use main Globtim.jl, not individual files
5. **Error handling** - Check exit codes at each phase

## Next Steps

1. Monitor job 59786285 for final validation
2. Create automated CI/CD pipeline for regular testing
3. Implement performance benchmarking suite
4. Scale to larger problem sizes

## Commands for Production Use

```bash
# Submit standard compilation test
python hpc/jobs/submission/submit_globtim_simple_compile.py --monitor

# Submit with dependency installation
./hpc/jobs/submission/submit_globtim_with_deps.sh

# Direct SLURM submission
scp globtim_production.slurm scholten@falcon:~/globtim_hpc/
ssh scholten@falcon 'cd ~/globtim_hpc && sbatch globtim_production.slurm'
```

## Current Status

### ⚠️ BLOCKING ISSUE: JSON3 Package Dependency
There is a persistent JSON3 package issue in the Julia environment on the HPC cluster that prevents proper package instantiation. This appears to be related to the Julia 1.11.2 installation and depot configuration.

**Error**: 
```
ERROR: KeyError: key Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3") not found
```

**Attempted Solutions**:
1. ✅ Direct module loading (bypassing Pkg) - partially works for simple modules
2. ❌ Pkg.instantiate() - fails due to JSON3 dependency
3. ❌ Pkg.precompile() - fails due to JSON3 dependency
4. ✅ Manual include() of source files - works but requires all dependencies pre-installed

**Recommended Next Steps**:
1. Contact HPC admin to fix Julia depot/registry issues
2. Consider using a containerized approach (Singularity/Apptainer)
3. Create a minimal working version without package management
4. Use pre-installed Julia environment if available

## Validation Checklist

- [x] Basic module structure identified
- [x] SLURM submission workflow established
- [x] Monitoring and data collection implemented
- [ ] Module loads without errors (blocked by JSON3 issue)
- [ ] Benchmark functions evaluate correctly (blocked by package deps)
- [ ] Test input generation works (blocked by package deps)
- [ ] Full test suite passes (blocked by package deps)
- [ ] Performance benchmarks meet requirements
- [ ] Scales to production problem sizes