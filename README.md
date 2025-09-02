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


> 🚀 **QUICK START: GlobTim HPC Execution** 🚀
>
> **Direct r04n02 Access with tmux (No SLURM Required)**
> ```bash
> # 1. Connect directly to compute node
> ssh scholten@r04n02
>
> # 2. Navigate to GlobTim repository
> cd /home/scholten/globtim  # NOTE: Use /home/scholten, NOT /tmp
>
> # 3. Pull latest changes
> git pull origin main
>
> # 4. Run 4D experiment with memory allocation
> ./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12
> # This automatically uses: julia --heap-size-hint=50G
>
> # 5. Monitor in tmux
> tmux attach -t globtim_*  # Ctrl+B then D to detach
> ```
>
> **⚠️ CRITICAL for Large Problems:**
> - **Memory**: Always use `--heap-size-hint=50G` for 4D+ problems
> - **Packages**: Ensure CSV, JSON are installed
> - **Path**: Use `Pkg.activate(dirname(dirname(@__DIR__)))` in scripts
>
> **Key Resources:**
> - **Julia**: Version 1.11.6 via juliaup (no module system needed)
> - **Memory Guide**: See formula in `docs/hpc/HPC_EXECUTION_GUIDE.md`
> - **Troubleshooting**: `docs/hpc/4D_EXPERIMENT_LESSONS_LEARNED.md`
> - **Repository**: `/home/scholten/globtim` (permanent storage)

### 🚀 Quick Start - HPC Execution with tmux

#### Step 1: Connect and Prepare
```bash
# Connect directly to compute node (no login node needed)
ssh scholten@r04n02
cd /home/scholten/globtim
git pull origin main
```

#### Step 2: Run Experiments
```bash
# Run 4D polynomial optimization (auto-handles memory)
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# For custom experiments requiring large memory:
julia --project=. --heap-size-hint=100G your_script.jl
```

#### Step 3: Monitor and Collect
```bash
# List active experiments
tmux ls | grep globtim

# Attach to monitor progress
tmux attach -t globtim_4d-model_*

# Results saved in:
ls -la hpc_results/globtim_*/
# Files: critical_points.csv, timing_report.txt, summary.txt
```

#### Memory Requirements by Problem Size
| Dims | Degree | Memory Needed | Heap Hint |
|------|--------|--------------|----------|
| 4    | 12     | 2.3 GB       | 50G      |
| 4    | 15     | 5.2 GB       | 100G     |
| 5    | 10     | 12.9 GB      | 100G     |
| 5    | 12     | 29.7 GB      | 200G     |

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

## 🎯 HPC Workflow - tmux-Based Execution ✅

### Prerequisites
```bash
# Ensure packages are installed on r04n02
ssh scholten@r04n02
cd /home/scholten/globtim
julia --project=. -e 'using Pkg; Pkg.add(["CSV", "JSON", "Statistics"])'
```

### Running Experiments
```bash
# Standard 4D optimization experiment
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# Custom parameters (samples_per_dim, degree)
./hpc/experiments/robust_experiment_runner.sh 4d-model 8 15

# Check status
./hpc/experiments/robust_experiment_runner.sh status
```

### Monitoring
```bash
# Real-time output monitoring
tail -f hpc_results/globtim_*/output.log

# Check for errors
cat hpc_results/globtim_*/error.log

# Memory usage
htop -u scholten
```

### Results Collection
```bash
# Results are automatically saved as:
# - critical_points.csv: DataFrame of optimized critical points
# - critical_points.json: JSON format for parsing
# - timing_report.txt: Performance breakdown
# - summary.txt: Human-readable summary
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

### ✅ tmux-Based Execution Framework (PRODUCTION STANDARD)
- **Direct Execution**: No scheduling delays, immediate start on r04n02
- **Persistent Sessions**: Survives SSH disconnection via tmux
- **Memory Management**: Automatic `--heap-size-hint` for large problems
- **Results Storage**: Persistent at `/home/scholten/globtim/hpc_results/`
- **Interactive Monitoring**: Attach/detach to running experiments at will

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
