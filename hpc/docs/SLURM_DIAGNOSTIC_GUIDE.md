# SLURM Diagnostic Guide

## Current Issue: Jobs Fail with Exit Code 0:53

**Problem**: All SLURM jobs fail immediately with `exit code 0:53` (RaisedSignal:53 - Real-time signal 19)

**Evidence**:
- Even simplest jobs (just `echo` commands) fail
- Runtime: 00:00:00 (jobs never start executing)
- Successful job found: 59774171 (deuflhard, completed 2025-08-07)
- Failed jobs: 59780275, 59780277, 59780280, 59780281, 59780283 (all with same 0:53 error)
- Quota issue: `mkdir` fails with "Disk quota exceeded" in ~/globtim_hpc

**Status**: BLOCKED - Need to resolve SLURM execution issue before proceeding

## Correct HPC Workflow

### Step 1: Prepare Code on Fileserver (mack)
```bash
# Upload/sync code to fileserver
ssh scholten@mack
cd ~/globtim_hpc

# Verify Julia environment
julia --project=. -e 'using Pkg; Pkg.status()'
```

### Step 2: Submit Jobs from Cluster (falcon)
```bash
# Connect to cluster for job submission
ssh scholten@falcon
cd ~/globtim_hpc

# Submit SLURM job (with required parameters)
sbatch --account=mpi --partition=batch your_job_script.slurm
```

### Step 3: Monitor and Collect
```bash
# Check job status
squeue -u scholten

# View job details
sacct -j <job_id> --format=JobID,JobName,State,ExitCode,Reason%30

# Collect results (accessible from both mack and falcon via NFS)
ls -la ~/globtim_hpc/results/
```

## Diagnostic Tests

### Test 1: Minimal Echo Job
```bash
ssh scholten@falcon '
cd ~/globtim_hpc
cat > /tmp/test_minimal.slurm << "EOF"
#!/bin/bash
#SBATCH --job-name=test_minimal
#SBATCH --partition=batch
#SBATCH --account=mpi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=test_minimal_%j.out

echo "Minimal test started"
echo "Job ID: $SLURM_JOB_ID"
echo "Working directory: $(pwd)"
sleep 5
echo "Minimal test completed"
EOF
sbatch --account=mpi --partition=batch /tmp/test_minimal.slurm
'
```

### Test 2: Julia Version Check
```bash
ssh scholten@falcon '
cd ~/globtim_hpc
cat > /tmp/test_julia.slurm << "EOF"
#!/bin/bash
#SBATCH --job-name=test_julia
#SBATCH --partition=batch
#SBATCH --account=mpi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=test_julia_%j.out

echo "Julia test started"
/sw/bin/julia --version
echo "Julia test completed"
EOF
sbatch --account=mpi --partition=batch /tmp/test_julia.slurm
'
```

### Test 3: NFS Access Check
```bash
ssh scholten@falcon '
cd ~/globtim_hpc
cat > /tmp/test_nfs.slurm << "EOF"
#!/bin/bash
#SBATCH --job-name=test_nfs
#SBATCH --partition=batch
#SBATCH --account=mpi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=test_nfs_%j.out

echo "NFS test started"
echo "Working directory: $(pwd)"
echo "Can read src/: $(ls src/ | head -n 3)"
echo "Can write to results/: $(mkdir -p results/test_nfs && echo "SUCCESS" || echo "FAILED")"
echo "NFS test completed"
EOF
sbatch --account=mpi --partition=batch /tmp/test_nfs.slurm
'
```

## Known Working Configuration

From successful job 59774171:
- **Account**: mpi
- **Partition**: batch  
- **Resources**: 12 CPUs, 32G memory
- **Runtime**: 00:00:26
- **Submit time**: 2025-08-07T10:25:35

## Troubleshooting Checklist

- [ ] Jobs submitted from falcon (not mack)
- [ ] Working directory is ~/globtim_hpc
- [ ] Account set to `--account=mpi`
- [ ] Partition set to `--partition=batch`
- [ ] Output files written to ~/globtim_hpc (not subdirectories that might hit quota)
- [ ] No modules required before submission?
- [ ] No special environment variables needed?

## Next Steps

1. Run diagnostic tests above
2. Compare successful vs failed job configurations
3. Check if quota issues prevent job startup (not just file writing)
4. Verify SLURM node access to NFS filesystem
5. Check if specific modules/environment setup required
