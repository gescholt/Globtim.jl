# Globtim - Global Optimization via Polynomial Approximation

A Julia package for global optimization using polynomial approximation methods, with comprehensive HPC benchmarking infrastructure and production-ready cluster deployment.

## 🎯 Current Status: PRODUCTION READY ✅

### ✅ Fully Functional HPC Integration with Fileserver
- **Three-Tier Architecture**: Local → Fileserver (mack) → HPC Cluster (falcon)
- **Complete Package Ecosystem**: 302 Julia packages on fileserver
- **Persistent Storage**: All results and packages stored on fileserver
- **NFS Integration**: Cluster nodes access fileserver packages seamlessly
- **Proper SLURM Workflow**: Jobs submitted from fileserver using standard practices

### 🚀 Quick Start - HPC Benchmarking

#### Step 1: Access Fileserver
```bash
# Connect to fileserver for job management
ssh scholten@mack
cd ~/globtim_hpc
```

#### Step 2: Submit Jobs
```bash
# Direct SLURM submission (recommended)
sbatch your_job_script.slurm

# Or use updated Python scripts
python submit_deuflhard_fileserver.py --mode quick
python submit_basic_test_fileserver.py --mode quick
```

#### Step 3: Monitor and Collect
```bash
# Monitor jobs from anywhere
squeue -u scholten

# Results automatically saved to fileserver
ls -la ~/globtim_hpc/results/
```

## 📁 Repository Structure

```
globtim/
├── src/                    # Core Globtim source code
├── test/                   # Comprehensive test suite
├── docs/                   # Documentation (organized & consolidated)
├── Examples/               # Usage examples and benchmarks
├── hpc/                    # 🆕 HPC Infrastructure (FILESERVER INTEGRATED)
│   ├── README.md          # Main HPC guide (updated for fileserver)
│   ├── docs/              # HPC-specific documentation
│   │   ├── FILESERVER_INTEGRATION_GUIDE.md   # Production fileserver guide
│   │   ├── TMP_FOLDER_PACKAGE_STRATEGY.md    # Legacy quota workaround (deprecated)
│   │   └── archive/       # Historical HPC documentation
│   ├── jobs/submission/   # ✅ Fileserver-integrated submission scripts
│   │   ├── submit_deuflhard_fileserver.py    # Fileserver-based Deuflhard benchmark
│   │   ├── submit_basic_test_fileserver.py   # Fileserver-based basic tests
│   │   ├── working_quota_workaround.py       # Legacy (deprecated)
│   │   └── FILESERVER_MIGRATION_GUIDE.md     # Migration documentation
│   ├── monitoring/python/ # ✅ Working Python monitoring tools
│   └── config/            # Configuration management
├── tools/                  # Development and maintenance tools
└── environments/          # Dual environment support (local/HPC)
```

## 🎯 HPC Workflow - PRODUCTION READY ✅

### Step 1: Environment Setup
```bash
# One-time setup: Install dependencies with quota workaround
cd hpc/jobs/submission
python working_quota_workaround.py --install-all
```

### Step 2: Run Benchmarks
```bash
# Validated Deuflhard benchmark
python submit_deuflhard_with_quota_workaround.py --mode quick --auto-collect

# Basic functionality test
python submit_basic_test.py --mode quick --auto-collect

# Custom benchmark functions
python submit_globtim_compilation_test.py --mode quick --function [FUNCTION_NAME]
```

### Step 3: Monitor and Collect Results
```bash
# Automated monitoring with result collection
python automated_job_monitor.py --job-id [JOB_ID] --test-id [TEST_ID]

# Results automatically saved in: hpc/jobs/submission/collected_results/
```

## 🔧 Key Technical Solutions

### ✅ Fileserver Integration (PRODUCTION)
- **Architecture**: Three-tier system (Local → Fileserver → HPC Cluster)
- **Storage**: Persistent fileserver storage via NFS
- **Access**: `ssh scholten@mack` for job management
- **Documentation**: `hpc/docs/FILESERVER_INTEGRATION_GUIDE.md`

### ✅ Package Ecosystem (COMPLETE)
- **Location**: Complete Julia ecosystem on fileserver (`~/.julia/`)
- **Count**: 302 packages including all dependencies
- **Access**: Automatic via NFS from cluster nodes
- **Persistence**: Permanent storage, no reinstallation needed

### ✅ SLURM Integration (STANDARD)
- **Job Submission**: Standard `sbatch` workflow from fileserver
- **Script Creation**: Proper SLURM scripts with NFS paths
- **Resource Management**: Full access to all cluster partitions
- **Results**: Persistent storage on fileserver

## 📊 Production Features

- **Automated Job Submission**: Python-based SLURM integration
- **Real-time Monitoring**: 30-second update intervals
- **Automatic Result Collection**: Structured output parsing
- **Error Handling**: Comprehensive error detection and reporting
- **Scalable Architecture**: Supports multiple concurrent benchmarks
- **Documentation**: Complete setup and troubleshooting guides

## 📚 Documentation

- **Main Guide**: `DEVELOPMENT_GUIDE.md` (consolidated setup instructions)
- **HPC Guide**: `hpc/README.md` (cluster-specific documentation)
- **Quota Solution**: `hpc/docs/TMP_FOLDER_PACKAGE_STRATEGY.md`
- **Troubleshooting**: `docs/troubleshooting/` (organized problem solutions)
- **Cleanup Summary**: `DOCUMENTATION_CLEANUP_SUMMARY.md` (recent organization)
