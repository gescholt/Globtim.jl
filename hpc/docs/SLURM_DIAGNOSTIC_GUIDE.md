# SLURM Diagnostic Guide

## ✅ RESOLVED: SLURM Configuration Issues

**Root Cause Identified**: Exit code 53 was caused by incorrect SLURM parameter format

**Solution**: Use simplified SLURM parameter format without `--account=mpi` and `--partition=batch`

**Evidence**:
- Jobs 59786176, 59786177 completed successfully with simplified format
- Working parameters: `-J`, `-t`, `-n`, `-c`, `--mem-per-cpu`, `-o`, `-e`
- NFS file transfer approach works perfectly

**Status**: ✅ WORKING - Use simplified SLURM parameter format

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

# Submit SLURM job (using simplified format)
sbatch your_job_script.slurm
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

### Test 1: Minimal Echo Job ✅ WORKING
```bash
# Create locally and copy via NFS (avoids SSH escaping issues)
cat > minimal_test.slurm << "EOF"
#!/bin/bash
#SBATCH -J minimal_test
#SBATCH -t 00:02:00
#SBATCH -n 1
#SBATCH -c 1
#SBATCH --mem-per-cpu=1000
#SBATCH -o minimal_test.out
#SBATCH -e minimal_test.err

echo "Minimal test started on $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
sleep 5
echo "Minimal test completed"
EOF

# Copy to falcon and submit
scp minimal_test.slurm falcon:~/minimal_test.slurm
ssh falcon "sbatch ~/minimal_test.slurm"
```

### Test 2: Julia Version Check ✅ WORKING
```bash
# Create locally and copy via NFS
cat > julia_test.slurm << "EOF"
#!/bin/bash
#SBATCH -J julia_test
#SBATCH -t 00:02:00
#SBATCH -n 1
#SBATCH -c 1
#SBATCH --mem-per-cpu=1000
#SBATCH -o julia_test.out
#SBATCH -e julia_test.err

echo "Julia test starting on $(hostname) at $(date)"
julia -e 'println("Julia works! Version: ", VERSION)'
echo "Julia test completed"
EOF

# Copy and submit
scp julia_test.slurm falcon:~/julia_test.slurm
ssh falcon "sbatch ~/julia_test.slurm"
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

## ✅ Known Working Configuration

From successful jobs 59786176, 59786177:
- **Format**: Simplified SLURM flags (`-J`, `-t`, `-n`, `-c`, `--mem-per-cpu`, `-o`, `-e`)
- **No account parameter needed** (was causing exit code 53)
- **No partition parameter needed** (default batch works)
- **File transfer**: Use NFS approach (scp to falcon, then sbatch)
- **Resources**: Minimal allocation works (1 CPU, 1GB memory)
- **Runtime**: Jobs complete successfully

## ✅ Working Configuration Checklist

- [x] Jobs submitted from falcon (not mack)
- [x] Scripts created locally and copied via NFS (avoids SSH escaping)
- [x] Use simplified SLURM parameter format
- [ ] ❌ DO NOT use `--account=mpi` (causes exit code 53)
- [ ] ❌ DO NOT use `--partition=batch` (default works)
- [x] Output files written to falcon home directory
- [x] No modules required before submission
- [x] No special environment variables needed

## Next Steps

1. Run diagnostic tests above
2. Compare successful vs failed job configurations
3. Check if quota issues prevent job startup (not just file writing)
4. Verify SLURM node access to NFS filesystem
5. Check if specific modules/environment setup required
