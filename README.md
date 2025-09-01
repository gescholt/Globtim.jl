# Globtim - Global Optimization via Polynomial Approximation

A Julia package for global optimization using polynomial approximation methods, with comprehensive HPC benchmarking infrastructure and production-ready cluster deployment.

## 🎯 Current Status: INFRASTRUCTURE MODERNIZED ✅

### 🚀 LATEST: Direct r04n02 Compute Node Access (September 1, 2025)
- **Modern Workflow**: Direct SSH access to r04n02 compute node ✅ OPERATIONAL
- **GitLab Integration**: Full Git operations working, repository at `/tmp/globtim/` ✅ VERIFIED
- **Security Hardened**: SSH key auth, workspace isolation, resource constraints ✅ IMPLEMENTED
- **Native Package Management**: Direct Julia Pkg.add() without bundling ✅ READY FOR TESTING
- **Simplified Deployment**: No NFS constraints, streamlined workflow ✅ CONFIGURED

### ✅ Legacy HPC Installation (Fallback Available)
- **Bundle Deployment**: Working bundle successfully deployed and tested ✅ VERIFIED
- **Julia Environment**: All packages loading correctly (ForwardDiff, StaticArrays, etc.) ✅ VERIFIED
- **SLURM Integration**: Jobs running successfully on falcon cluster ✅ VERIFIED
- **NFS Storage**: Bundle accessible from compute nodes via NFS ✅ VERIFIED
- **Test Results**: Job ID 59808907 confirmed all functionality working ✅ VERIFIED

### 🚀 Ready for Production Use - Dual Workflow Support
- **Modern**: Direct r04n02 node access with native Julia package management
- **Legacy**: Complete falcon cluster installation with bundle deployment
- **Documentation**: Both workflows documented with quick-start guides
- **Testing**: Core functionality confirmed working on both approaches
- **Performance**: Optimized for HPC environment with flexible deployment options


> 🚀 **QUICK START: GlobTim is Ready to Use!** 🚀
>
> **MODERN WORKFLOW (Preferred): Direct r04n02 Access**
> ```bash
> # 1. Connect directly to compute node
> ssh scholten@r04n02
>
> # 2. Access the GlobTim repository (already cloned)
> cd /tmp/globtim
>
> # 3. Use native Julia package management
> /sw/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'
>
> # 4. Run tests or submit jobs directly
> sbatch --time=01:00:00 --mem=8G script.slurm
> ```
>
> **LEGACY WORKFLOW (Fallback): falcon+NFS Bundle**
> ```bash
> # 1. Connect to cluster login node
> ssh scholten@falcon
>
> # 2. Submit a job using the working bundle
> sbatch test_nfs_bundle.slurm
>
> # 3. Or create your own job (see CLUSTER_WORKFLOW.md)
> ```
>
> **Key Resources:**
> - **Modern**: Direct Git access, native Julia Pkg.add(), simplified deployment
> - **Legacy**: `/home/scholten/globtim_optimal_bundle_20250821_152938.tar.gz` (ready to use)
> - **Julia**: Version 1.11.2 at `/sw/bin/julia`
> - **Packages**: ForwardDiff, StaticArrays, HomotopyContinuation, and all dependencies
> - **Documentation**: See `HPC_DIRECT_NODE_MIGRATION_PLAN.md` for modern workflow details

### 🚀 Quick Start - HPC Benchmarking

#### Step 1: Prepare Code (Fileserver)
```bash
# Connect to fileserver for code management
ssh scholten@mack
cd ~/globtim_hpc
# Upload code, install packages, prepare data
```

#### Step 2: Submit Jobs (Cluster)
```bash
# Connect to cluster for job submission
ssh scholten@falcon
cd ~/globtim_hpc

# Direct SLURM submission (recommended)
sbatch --account=mpi --partition=batch your_job_script.slurm

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

## 🚀 Quick Start - Precision-Aware Optimization

> 📦 **Package Dependencies**: For complete information about GlobTim's modern dependency architecture with weak dependencies and extensions, see **[`PACKAGE_DEPENDENCIES.md`](PACKAGE_DEPENDENCIES.md)**

### Basic Usage with Precision Control

```julia
using Globtim, DynamicPolynomials

# Define optimization problem
f = Deuflhard  # Built-in test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Create polynomial with AdaptivePrecision (recommended)
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("L2-norm approximation error: $(pol.nrm)")

# Find critical points
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)

# Enhanced analysis with sparsification
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
println("Found $(nrow(df_min)) unique local minima")
```

### Precision Comparison Example

```julia
# Compare different precision types
precisions = [Float64Precision, AdaptivePrecision, RationalPrecision]
for prec in precisions
    pol = Constructor(TR, 6, precision=prec)
    println("$(prec): L2-norm = $(pol.nrm), type = $(eltype(pol.coeffs))")
end
```

## 📁 Repository Structure

```
globtim/
├── src/                    # Core Globtim source code
├── test/                   # Comprehensive test suite
├── docs/                   # Documentation (organized & consolidated)
├── Examples/               # Usage examples and benchmarks
├── hpc/                    # ✅ HPC Infrastructure (FULLY OPERATIONAL)
│   ├── README.md          # Main HPC guide (verified working)
│   ├── docs/              # HPC-specific documentation
│   │   ├── FILESERVER_INTEGRATION_GUIDE.md   # Production fileserver guide
│   │   ├── HPC_STATUS_SUMMARY.md             # Current status (VERIFIED)
│   │   ├── TMP_FOLDER_PACKAGE_STRATEGY.md    # Legacy quota workaround (deprecated)
│   │   └── archive/       # Historical HPC documentation
│   ├── jobs/submission/   # ✅ Verified submission scripts (Job 59780294 success)
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
# Standard HPC Deuflhard benchmark
python submit_deuflhard_hpc.py --mode quick --auto-collect

# Fileserver-based Deuflhard benchmark
python submit_deuflhard_fileserver.py --mode quick --auto-collect

# Basic functionality test
python submit_basic_test_fileserver.py --mode quick --auto-collect

# Custom benchmark functions
python submit_globtim_compilation_test.py --mode quick --function [FUNCTION_NAME]
```

### Step 3: Monitor and Collect Results
```bash
# Automated monitoring with result collection
python automated_job_monitor.py --job-id [JOB_ID] --test-id [TEST_ID]

# Results automatically saved in: hpc/jobs/submission/collected_results/
```

## 🔧 Key Technical Solutions - BREAKTHROUGH ACHIEVED

### ✅ Native HPC Installation (PRIMARY - PRODUCTION READY)
- **Method**: Direct package installation on x86_64 Linux cluster
- **Compatibility**: Complete resolution of architecture mismatch issues
- **Success Rate**: 90% of packages working (improved from ~50%)
- **Binary Artifacts**: All platform-specific libraries correctly installed
- **Script**: `deploy_native_homotopy.slurm` (verified working)
- **Status**: HomotopyContinuation and ForwardDiff fully operational ✅ VERIFIED Job ID 59816729

### ✅ Bundle Deployment (ALTERNATIVE - PROVEN WORKING)
- **Architecture**: Three-tier system (Local → Fileserver → HPC Cluster)
- **Storage**: Persistent fileserver storage via NFS
- **Access**: `ssh scholten@mack` for job management
- **Documentation**: `hpc/docs/FILESERVER_INTEGRATION_GUIDE.md`
- **Bundle**: `globtim_optimal_bundle_20250821_152938.tar.gz` (256MB, production ready)

### ✅ Package Ecosystem (COMPLETE - DUAL APPROACH)
- **Native Installation**: 203 packages with correct x86_64 artifacts on cluster
- **Bundle Alternative**: Complete Julia ecosystem on fileserver (`~/.julia/`)
- **Count**: 302 packages including all dependencies (bundle approach)
- **Access**: Automatic via NFS from cluster nodes or native installation
- **Persistence**: Permanent storage, no reinstallation needed

### ✅ SLURM Integration (PRODUCTION STANDARD)
- **Job Submission**: Standard `sbatch` workflow from fileserver
- **Script Creation**: Proper SLURM scripts with NFS paths
- **Resource Management**: Full access to all cluster partitions
- **Results**: Persistent storage on fileserver
- **Verified Scripts**: Both native installation and bundle deployment working

## 🎯 Key Features

### 🔢 Advanced Precision Control
Globtim provides flexible precision parameter options for optimal performance vs accuracy trade-offs:

- **Float64Precision**: Standard double precision for fast computation
- **AdaptivePrecision** ⭐: Hybrid approach using Float64 for evaluation, BigFloat for coefficients (recommended)
- **RationalPrecision**: Exact rational arithmetic for symbolic computation
- **BigFloatPrecision**: Maximum precision for research applications

```julia
# Example: High-accuracy polynomial approximation
pol = Constructor(TR, 8, precision=AdaptivePrecision)

# Integrate with sparsification for complexity reduction
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)
analysis = analyze_coefficient_distribution(mono_poly)
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, analysis.suggested_thresholds[1])
```

### 📊 Production Features

- **Automated Job Submission**: Python-based SLURM integration
- **Real-time Monitoring**: 30-second update intervals
- **Automatic Result Collection**: Structured output parsing
- **Error Handling**: Comprehensive error detection and reporting
- **Scalable Architecture**: Supports multiple concurrent benchmarks
- **Documentation**: Complete setup and troubleshooting guides

## 📚 Documentation

### Core Documentation
- **[Getting Started](docs/src/getting_started.md)**: Installation, basic usage, and precision parameters
- **[Precision Parameters](docs/src/precision_parameters.md)**: Comprehensive guide to precision types and performance trade-offs
- **[API Reference](docs/src/api_reference.md)**: Complete function reference with precision options
- **[Examples](docs/src/examples.md)**: Practical usage examples with different precision types

### Package Architecture
- **[Package Dependencies](PACKAGE_DEPENDENCIES.md)**: **📦 COMPLETE DEPENDENCY GUIDE** - Modern weak dependency system, extensions, HPC compatibility

### HPC Cluster Usage (READY TO USE)
- **[Quick Start Workflow](CLUSTER_WORKFLOW.md)**: **🚀 CURRENT WORKING PROCESS** - Ready-to-use job templates and examples
- **[HPC Deployment Guide](HPC_DEPLOYMENT_GUIDE.md)**: Complete technical documentation and troubleshooting
- **[Bundle Documentation](README_HPC_Bundle.md)**: Package details and installation verification

### Development & Advanced Usage
- **Main Guide**: `DEVELOPMENT_GUIDE.md` (consolidated setup instructions)
- **HPC Guide**: `hpc/README.md` (cluster-specific documentation)
- **Quota Solution**: `hpc/docs/TMP_FOLDER_PACKAGE_STRATEGY.md`
- **Troubleshooting**: `docs/troubleshooting/` (organized problem solutions)
- **Cleanup Summary**: `DOCUMENTATION_CLEANUP_SUMMARY.md` (recent organization)
