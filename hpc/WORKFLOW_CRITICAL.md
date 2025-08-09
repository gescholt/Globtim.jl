# 🚨 CRITICAL: HPC Workflow Guide - READ FIRST 🚨

**This is the FIRST document you must read before working with the HPC cluster.**

## 🎯 The Golden Rule

**Code Management**: mack (fileserver) ONLY  
**Job Submission**: falcon (cluster) ONLY

## 📋 Step-by-Step Workflow

### Step 1: Code Management (via mack)
```bash
# Connect to fileserver for ALL code operations
ssh scholten@mack
cd ~/globtim_hpc

# Upload code files
scp -r local_changes/* scholten@mack:~/globtim_hpc/

# Upload large files (5GB+) - use mack (dedicated export node)
scp large_dataset.h5 scholten@mack:~/globtim_hpc/data/
rsync -avz --progress large_files/ scholten@mack:~/globtim_hpc/data/

# Install Julia packages (302 packages available)
julia --project=. -e 'using Pkg; Pkg.add("NewPackage")'

# Modify code, prepare data, organize files
# ALL file operations must happen here!
```

### Step 2: Job Submission (via falcon)
```bash
# Connect to cluster for job submission ONLY
ssh scholten@falcon
cd ~/globtim_hpc

# Submit SLURM jobs (required parameters)
sbatch --account=mpi --partition=batch your_job.slurm

# Monitor jobs
squeue -u scholten
sacct -j <job_id>
```

### Step 3: Results Collection
```bash
# Results are accessible from both locations
# Via cluster:
ssh scholten@falcon 'ls -la ~/globtim_hpc/results/'

# Via fileserver:
ssh scholten@mack 'ls -la ~/globtim_hpc/results/'

# Download results locally (use mack for large files):
scp -r scholten@mack:~/globtim_hpc/results/experiment_* ./local_results/
rsync -avz --progress scholten@mack:~/globtim_hpc/results/ ./local_results/
```

## ⚠️ Critical Warnings

### NEVER DO THESE:
- ❌ Install packages on falcon (1GB quota limit)
- ❌ Run jobs from `/tmp` (forbidden)
- ❌ Submit jobs from mack (no SLURM scheduler)
- ❌ Store large files in falcon home directory
- ❌ Modify code directly on falcon

### ALWAYS DO THESE:
- ✅ Upload code via mack
- ✅ Submit jobs via falcon
- ✅ Use `--account=mpi --partition=batch`
- ✅ Work in `~/globtim_hpc` directory
- ✅ Keep falcon home directory clean (only globtim_hpc)

## 🔧 Architecture Overview

```
Local Development
       ↓ (scp/rsync)
mack (fileserver)
  • Code storage
  • Package management  
  • Data preparation
  • Results collection
       ↓ (NFS mount)
falcon (cluster)
  • Job submission
  • SLURM scheduler
  • Job monitoring
       ↓ (SLURM execution)
Compute Nodes
  • Job execution
  • Access mack via NFS
  • Write results to mack
```

## 📊 Quota Information

- **falcon home**: 1GB limit (CRITICAL - keep minimal!)
- **mack**: Generous storage for code and results
- **NFS**: Compute nodes access mack storage seamlessly

## 🚀 Quick Commands

```bash
# Check falcon quota
ssh scholten@falcon 'quota -u scholten'

# Check job status
ssh scholten@falcon 'squeue -u scholten'

# View recent job results
ssh scholten@falcon 'sacct -u scholten --starttime=today'

# Clean falcon home (keep only globtim_hpc)
ssh scholten@falcon 'cd ~ && ls -la | grep -v globtim_hpc'

# Upload code to fileserver
scp -r ./src/* scholten@mack:~/globtim_hpc/src/
```

## 📚 Related Documentation

- `hpc/README.md` - Detailed HPC infrastructure guide
- `hpc/docs/HPC_STATUS_SUMMARY.md` - Current status and troubleshooting
- `hpc/docs/SLURM_DIAGNOSTIC_GUIDE.md` - SLURM troubleshooting
- `hpc/jobs/submission/` - Job submission scripts

## 🆘 Emergency Procedures

### If falcon quota exceeded:
```bash
ssh scholten@falcon 'cd ~ && rm -f *.out *.err *.log *.slurm'
```

### If jobs fail with exit code 0:53:
- Check falcon quota: `quota -u scholten`
- Clean old files from falcon home
- Ensure working in `~/globtim_hpc`
- Verify `--account=mpi` in SLURM script

### If packages missing:
- Install on mack: `ssh scholten@mack`
- Never install on falcon

---

**Remember**: mack for code, falcon for jobs. Follow this rule and everything works smoothly! 🎯
