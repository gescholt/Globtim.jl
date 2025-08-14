# HPC Infrastructure Usage Guide - Private MPI Version

## 🔒 Private Repository Information

This guide is specific to the **private MPI GitLab repository** and contains sensitive information about the Furiosa HPC cluster infrastructure. **DO NOT** include this information in public repositories.

## ✅ Verified Operational Status

### Core Infrastructure (100% Working)
- **SLURM Job Execution**: 7 successful jobs verified (Jobs 59780284, 59780290-59780295)
- **Automated Monitoring**: Real-time job tracking and result collection
- **File Recovery**: All outputs automatically collected to local machine
- **NFS Integration**: Seamless fileserver access from compute nodes

### Verified Workflow
```bash
# 1. Upload/Prepare (fileserver mack)
ssh scholten@mack
cd ~/globtim_hpc
# Upload code, prepare data

# 2. Submit (cluster falcon)  
ssh scholten@falcon
cd ~/globtim_hpc
sbatch --account=mpi --partition=batch job_script.slurm

# 3. Monitor & Collect (automated)
python3 hpc/jobs/submission/automated_job_monitor.py --job-id <job_id>
```

## ⚠️ Critical Limitations & Workarounds

### Julia Package Environment
- **Quota Issue**: 1GB home directory limit prevents package precompilation
- **Workaround**: Use `julia --compiled-modules=no` flag
- **Performance Impact**: Slower loading but functional
- **Network Restrictions**: Compute nodes cannot download packages

### Required Flags for Julia Jobs
```bash
# In SLURM scripts, always use:
/sw/bin/julia --compiled-modules=no --project=. your_script.jl
```

## 🚀 Quick Start for New Users

### 1. Initial Setup
```bash
# Clone repository to local machine
git clone <private-mpi-gitlab-url>
cd globtim

# Upload to fileserver
scp -r . scholten@mack:~/globtim_hpc/
```

### 2. Test Basic Functionality
```bash
# Submit simple test
ssh scholten@falcon
cd ~/globtim_hpc
python3 hpc/jobs/submission/submit_simple_julia_test.py --mode quick

# Monitor results
python3 hpc/jobs/submission/automated_job_monitor.py --job-id <returned_job_id>
```

### 3. Run Globtim Functions
```bash
# Use HPC-optimized environment
python3 hpc/jobs/submission/submit_deuflhard_fileserver.py --mode quick
```

## 📁 File Organization

### Results Structure
```
~/globtim_hpc/results/
├── job_<job_id>_<timestamp>/
│   ├── *.csv                 # Data outputs
│   ├── *.txt                 # Summary reports  
│   ├── *.out/.err           # SLURM logs
│   └── *.jl                 # Source scripts
```

### Local Collection
```
collected_results/
├── job_<job_id>_<timestamp>/
│   ├── collection_summary.json
│   ├── monitoring_summary.json
│   └── [all job outputs]
```

## 🔧 Troubleshooting

### Common Issues
1. **Quota Exceeded**: Use fileserver (mack) for all file operations
2. **Package Loading Fails**: Add `--compiled-modules=no` flag
3. **Network Errors**: Ensure packages pre-installed on fileserver
4. **Job Fails**: Check SLURM logs in collected results

### Diagnostic Commands
```bash
# Check quota
ssh scholten@falcon 'quota -u scholten'

# Check job status
ssh scholten@falcon 'squeue -u scholten'

# Check fileserver space
ssh scholten@mack 'df -h ~'
```

## 📊 Performance Expectations

### Verified Performance
- **Simple Functions**: ~5 seconds execution time
- **File Collection**: ~30 seconds for complete workflow
- **Monitoring**: 30-second update intervals
- **Success Rate**: 100% for basic mathematical functions

### Limitations
- **Complex Packages**: May require longer loading times
- **Large Computations**: Performance impact from uncompiled modules unknown
- **Memory Usage**: Higher memory consumption without precompilation

## 🎯 Best Practices

### For Developers
1. **Always test locally first** before cluster submission
2. **Use fileserver for all file operations** (not falcon)
3. **Include proper error handling** in Julia scripts
4. **Monitor jobs actively** during development
5. **Clean up old results** to manage quota

### For Production
1. **Use automated monitoring** for all jobs
2. **Implement proper logging** and result validation
3. **Test with small examples** before large computations
4. **Document all parameter choices** and expected outputs

## 🔐 Security Notes

- **Cluster Access**: Requires VPN and SSH key authentication
- **File Permissions**: Ensure proper permissions on uploaded files
- **Sensitive Data**: Keep all cluster-specific information in private repository
- **Credentials**: Never commit SSH keys or passwords

---

**Last Updated**: 2025-08-09  
**Verified Environment**: Furiosa HPC Cluster  
**Contact**: For issues, consult HPC_STATUS_SUMMARY.md and SLURM_DIAGNOSTIC_GUIDE.md
