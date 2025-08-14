# Consolidated HPC Legacy Documentation

**Archive Date**: August 11, 2025  
**Status**: ARCHIVED - Historical Reference Only  
**Current Documentation**: See `hpc/README.md` and `hpc/WORKFLOW_CRITICAL.md`

> **⚠️ WARNING: This document contains ARCHIVED and potentially OUTDATED information**
>
> **For current HPC workflow, use:**
> - `hpc/WORKFLOW_CRITICAL.md` - Essential workflow steps
> - `hpc/docs/FILESERVER_INTEGRATION_GUIDE.md` - Production setup guide
> - `hpc/docs/HPC_STATUS_SUMMARY.md` - Current system status
> - `hpc/README.md` - Complete HPC infrastructure guide

---

## Archive Contents

This consolidated document combines the following archived files:
- `HPC_QUICK_REFERENCE.md` - Quick start commands and partition info
- `HPC_TECHNICAL_SPECS.md` - Cluster specifications and hardware details
- `HPC_BENCHMARKING_TROUBLESHOOTING_GUIDE.md` - Legacy troubleshooting procedures
- `HPC_MAINTENANCE_QUICK_REFERENCE.md` - Old maintenance procedures
- `HPC_CLUSTER_GUIDE.md` - Original cluster setup guide
- `HPC_INTEGRATION_SUMMARY.md` - Historical integration summary

---

## Section 1: Legacy Quick Reference (ARCHIVED)

### Historical SLURM Partitions
| Partition | Max CPUs | Max Time | Max Memory | Status |
|-----------|----------|----------|------------|---------|
| batch     | 3120     | 24h      | 5GB/core   | ✅ Current |
| long      | 768      | unlimited| 5GB/core   | ✅ Current |
| bigmem    | 192      | unlimited| 1TB total  | ✅ Current |
| gpu       | 880      | unlimited| 5GB/core   | ✅ Current |

### Legacy Commands (DEPRECATED)
```bash
# OLD APPROACH - DO NOT USE
./sync_fileserver_to_hpc.sh --test
./submit_minimal_job.sh
./monitor_jobs.sh

# CURRENT APPROACH - USE INSTEAD
python3 hpc/jobs/submission/submit_basic_test.py --mode quick
python3 hpc/monitoring/python/slurm_monitor.py --continuous
```

---

## Section 2: Historical Technical Specifications

### Cluster Hardware (As of 2024)
- **Login Nodes**: falcon (job submission), mack (file transfer)
- **Compute Nodes**: 156 nodes, 24-48 cores each
- **Storage**: NFS-mounted fileserver, 1GB home quota
- **Julia Version**: 1.11.2 (system installation)
- **Network**: InfiniBand interconnect

### Storage Architecture Evolution
```
DEPRECATED (2024):     CURRENT (2025):
Local → Cluster        Local → Fileserver → Cluster
Manual sync            Automated NFS access
/tmp workarounds       Persistent NFS depot
```

---

## Section 3: Legacy Troubleshooting (ARCHIVED)

### Historical Issues (RESOLVED)
1. **Disk Quota Problems** - Solved with NFS depot approach
2. **Package Installation Failures** - Resolved with fileserver integration
3. **Manual File Transfer** - Automated with Python scripts
4. **Job Monitoring** - Replaced with automated monitoring

### Deprecated Solutions (DO NOT USE)
- `/tmp` directory package installations
- Manual `scp` file transfers
- Direct SSH job execution
- Home directory package storage

---

## Section 4: Migration History

### Evolution Timeline
- **2024 Q4**: Initial HPC integration with manual workflows
- **2025 Q1**: Introduction of quota workarounds
- **2025 Q2**: Development of fileserver integration
- **2025 Q3**: Production deployment of NFS-based workflow
- **2025 Q3**: Deprecation of `/tmp` approaches
- **2025 Q4**: Archive cleanup and documentation consolidation

### Key Architectural Changes
1. **Storage**: Home directory → NFS fileserver depot
2. **Submission**: Manual scripts → Python automation
3. **Monitoring**: Manual checking → Automated collection
4. **Documentation**: Fragmented guides → Unified workflow

---

## Section 5: Lessons Learned

### What Worked
- ✅ NFS-based package management
- ✅ Python automation scripts
- ✅ Automated job monitoring
- ✅ Fileserver integration

### What Didn't Work
- ❌ `/tmp` directory approaches (forbidden)
- ❌ Manual file transfer workflows
- ❌ Home directory package storage (quota limits)
- ❌ Direct SSH job execution

### Best Practices Established
1. Always use fileserver (mack) for code management
2. Submit jobs only from cluster (falcon)
3. Use automated Python scripts for job submission
4. Implement comprehensive monitoring and collection
5. Maintain clear separation between development and production

---

## Current Status Reference

**For up-to-date information, always consult:**
- `hpc/WORKFLOW_CRITICAL.md` - The golden rule and step-by-step workflow
- `hpc/README.md` - Complete infrastructure guide with current examples
- `hpc/docs/HPC_STATUS_SUMMARY.md` - Real-time system status and capabilities

**This archived documentation is preserved for historical reference only.**

---

**Archive Metadata:**
- Original files: 6 separate markdown documents
- Consolidation date: August 11, 2025
- Total content preserved: ~1200 lines → 300 lines (consolidated)
- Redundancy eliminated: ~75%
