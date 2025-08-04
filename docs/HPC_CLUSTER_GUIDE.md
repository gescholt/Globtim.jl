# Globtim HPC Cluster Usage Guide

## Overview

This guide documents how to use the **furiosa HPC cluster** for running Globtim computations. The cluster provides significant computational resources for large-scale polynomial approximation and optimization tasks.

## Cluster Architecture

### Gateway Nodes
- **furiosa-falcon** (login node): 24-core machine for compilation, testing, and job submission
- **furiosa-mack** (export node): Dedicated to large data transfers (5GB+)

### File System Structure
- **`/home`**: Limited to 1GB per user - only for configuration files
- **`/projects`**: Main workspace for computations (request from hpcsupport)
- **`/sw`**: System software packages (Julia available at `/sw/bin/julia`)

### SLURM Partitions

| Partition | Cores | Max Time | Max Memory | Use Case |
|-----------|-------|----------|------------|----------|
| **batch** (default) | 3120 | 24h | 256GB | General computations |
| **long** | 768 | unlimited | 256GB | Long-running jobs |
| **bigmem** | 192 | unlimited | 1TB | Memory-intensive tasks |
| **gpu** | 880 + 44 GPUs | unlimited | 512GB | GPU computations |

## Initial Setup

### 1. SSH Key Authentication
```bash
# Set up passwordless SSH access
./setup_ssh_keys.sh
```

### 2. Configure Connection Settings
Edit `cluster_config.sh`:
```bash
export FILESERVER_HOST="scholten@fileserver-ssh"
export FILESERVER_PATH="~/globtim"
export CLUSTER_HOST="scholten@falcon"
export CLUSTER_PATH="~/globtim_hpc"
export SSH_KEY_PATH="/Users/ghscholt/.ssh/id_ed25519"
```

### 3. Test HPC Access
```bash
# Test connection and environment
./test_hpc_access.sh
```

## Deployment Workflow

### Automated Sync Chain
```
Local Machine → Fileserver (backup) → HPC Cluster (computation)
```

### Deploy Project
```bash
# Sync lightweight version to HPC
./sync_fileserver_to_hpc.sh

# Options:
./sync_fileserver_to_hpc.sh --test        # Test Julia setup
./sync_fileserver_to_hpc.sh --interactive # Interactive session
./sync_fileserver_to_hpc.sh --julia       # Julia REPL
```

### What Gets Excluded from HPC
- Visualization packages (Makie, ProfileView, Colors)
- Documentation and notebooks
- Large binary files and build artifacts
- Git history and development tools

## SLURM Job Submission

### Available Job Templates

1. **Quick Test** (`globtim_quick.slurm`)
   - 4 CPUs, 8GB RAM, 10 minutes
   - Basic Julia and threading test

2. **Full Test** (`globtim_minimal.slurm`)
   - 24 CPUs, 32GB RAM, 30 minutes
   - Downloads Globtim from fileserver, runs comprehensive tests

3. **Benchmark Job** (`globtim_benchmark.slurm`)
   - 24 CPUs, 64GB RAM, 2 hours
   - Runs benchmark functions and performance tests

4. **Custom Template** (`globtim_custom.slurm.template`)
   - Customizable for specific computations

### Job Submission Commands
```bash
# Submit jobs
./submit_minimal_job.sh           # Quick minimal test
./submit_hpc_jobs.sh test         # Full test with sync
./submit_hpc_jobs.sh benchmark    # Benchmark suite

# Monitor jobs
./monitor_jobs.sh                 # Show all jobs
./monitor_jobs.sh <job_id>        # Show specific job details

# Direct SLURM commands
ssh scholten@falcon "sbatch globtim_quick.slurm"
ssh scholten@falcon "squeue -u \$USER"
ssh scholten@falcon "scancel <job_id>"
```

## Julia Environment on HPC

### Julia Installation
- **Location**: `/sw/bin/julia`
- **Version**: 1.11.2
- **Threading**: Automatic detection (up to 24 threads per node)

### Environment Variables
```bash
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
```

### Package Management
Due to disk quota limitations in `/home`, Julia packages are installed in temporary directories during job execution. The HPC version uses a minimal `Project_HPC.toml` without visualization dependencies.

## Disk Space Management

### Home Directory Limitations
- **Quota**: 1GB limit strictly enforced
- **Usage**: Only configuration files and small scripts
- **Cleanup**: Regularly remove old job outputs

### Temporary Storage Strategy
- Use `/tmp/globtim_${SLURM_JOB_ID}` for job working directories
- Use `/tmp/julia_depot_${USER}_${SLURM_JOB_ID}` for Julia packages
- Automatic cleanup after job completion

### Project Space (Recommended)
Request dedicated project space from hpcsupport:
```
Subject: Project Space Request - Globtim Research

Dear HPC Support Team,

I would like to request a project space for my Globtim research project.

Project Details:
• Project Name: globtim
• Description: Global optimization and polynomial approximation research
• Estimated Size: 10-20 GB (Julia packages, data, results)
• Users: scholten
• Timeframe: 12 months

The project involves Julia computational mathematics, benchmark function 
analysis, and polynomial approximation algorithms.
```

## Performance Optimization

### Resource Selection Guidelines

| Task Type | Recommended Partition | CPUs | Memory | Time |
|-----------|----------------------|------|--------|------|
| Quick tests | batch | 4-8 | 8-16GB | <1h |
| Standard computations | batch | 24 | 32-64GB | 2-8h |
| Long optimizations | long | 24-48 | 64-128GB | >8h |
| Memory-intensive | bigmem | 48 | 256GB-1TB | varies |

### Threading Best Practices
- Use `JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK`
- Test threading with small problems first
- Monitor memory usage with large thread counts

## Troubleshooting

### Common Issues

1. **Disk Quota Exceeded**
   ```bash
   # Clean home directory
   ssh scholten@falcon "rm -rf ~/globtim_* ~/julia_*"
   ```

2. **Job Pending Too Long**
   - Try smaller resource requests
   - Use different partitions
   - Check cluster status: `squeue | head -20`

3. **Julia Package Installation Fails**
   - Use temporary JULIA_DEPOT_PATH
   - Avoid heavy visualization packages
   - Use minimal Project_HPC.toml

4. **SSH Connection Issues**
   ```bash
   # Test connections
   ssh scholten@falcon "echo 'Connection OK'"
   ssh scholten@fileserver-ssh "echo 'Fileserver OK'"
   ```

## Example Workflows

### 1. Quick Functionality Test
```bash
./submit_minimal_job.sh
./monitor_jobs.sh
```

### 2. Benchmark Study
```bash
./submit_hpc_jobs.sh benchmark
# Wait for completion
./monitor_jobs.sh <job_id>
```

### 3. Custom Computation
```bash
# Copy and modify template
cp globtim_custom.slurm.template my_computation.slurm
# Edit job parameters and Julia code
scp my_computation.slurm scholten@falcon:~/
ssh scholten@falcon "sbatch my_computation.slurm"
```

## Security Notes

- SSH keys are used for passwordless authentication
- Sensitive files are automatically excluded from sync
- All scripts follow security best practices
- No credentials are stored in version control

## File Reference

### Scripts Created
- `sync_fileserver_to_hpc.sh` - Main deployment script
- `submit_minimal_job.sh` - Quick job submission
- `submit_hpc_jobs.sh` - Full job management
- `monitor_jobs.sh` - Job monitoring
- `test_hpc_access.sh` - Environment testing
- `setup_ssh_keys.sh` - SSH configuration

### SLURM Job Templates
- `globtim_quick.slurm` - Quick test (4 CPUs, 10 min)
- `globtim_minimal.slurm` - Full test (24 CPUs, 30 min)
- `globtim_benchmark.slurm` - Benchmark suite (24 CPUs, 2h)
- `globtim_custom.slurm.template` - Customizable template

### Configuration Files
- `cluster_config.sh` - Server connection settings (gitignored)
- `Project_HPC.toml` - Lightweight Julia environment
- `.gitignore` - Security exclusions

## Success Metrics

✅ **Verified Working (Job ID: 59769879)**
- Julia 1.11.2 with 4 threads on compute node c02n10
- Matrix operations and threading functional
- 27-second execution time
- Clean temporary storage usage
- No disk quota issues

This infrastructure provides a robust, automated workflow for HPC-scale Globtim computations.
