# GlobTim Project Memory

## 🚨 CRITICAL TEST ENVIRONMENT ISSUES - MUST READ FIRST

### Julia Test Environment Configuration (RESOLVED September 2, 2025)
**Problem**: `Pkg.test()` was using old registered Globtim v0.1.3 instead of local development version
**Root Cause**: test/Project.toml included Globtim as a dependency, causing Julia to fetch from registry
**Solution**: 
1. Remove `Globtim = "00da9514-6261-47e9-8848-33640cb1e528"` from test/Project.toml
2. Remove test/Manifest.toml to force regeneration
3. Clear any cached packages: `rm -rf ~/.julia/packages/Globtim ~/.julia/compiled/v1.11/Globtim`
4. Now `Pkg.test()` correctly uses local version: `Globtim v1.1.2 ~/globtim`

### Conda Environment Interference (RESOLVED September 2, 2025)
**Problem**: Conda environment causes binary incompatibilities with Julia packages
**Symptoms**: 
- LinearSolve/Sparspak precompilation errors
- "TypeError: in new, expected Union{}, got a value of type SparseArrays.SparseMatrixCSC"
**Solution**:
1. Run Julia without conda: Use `julia-clean` or `julia-globtim` aliases
2. Aliases added to both .zshrc and .bash_profile for shell compatibility
3. Clear precompilation cache when switching environments
4. Created start_julia.sh script for clean Julia execution

### Test Syntax Fixes (RESOLVED September 2, 2025)
**GitLab Issue #18**: test_aqua.jl had invalid @test macro syntax
**Fixed**:
- Removed string messages from @test macros (Julia's Test.jl doesn't support inline messages)
- Fixed runtests.jl: Removed `tolerance = nothing` to use default value
- Fixed test_aqua.jl: Removed call to non-existent `test_project_toml_formatting` function
- Core tests now pass successfully

### Remaining Aqua Quality Issues (TO BE ADDRESSED)
**Non-critical failures in code quality checks**:
1. **Undefined exports** - 13 valley-related symbols exported but not defined
2. **Stale dependency** - Aqua should be in test dependencies only, not main deps
3. **Export count** - 258 exports exceeds reasonable limit (test expects < 200)

## 🚨 CRITICAL HPC KNOWLEDGE - READ FIRST FOR ALL CLUSTER TASKS

### Direct r04n02 Compute Node Access (CURRENT APPROACH)
**Direct SSH access to r04n02 compute node with full capabilities**

**Connection**: 
```bash
ssh scholten@r04n02
```

**Key Capabilities**:
- **Direct Git Access**: Clone repositories directly on compute node
- **Native Julia Packages**: Use Pkg.add() without bundling complexity
- **Internet Access**: Full connectivity for package downloads
- **Repository Location**: `/home/scholten/globtim` (permanent, NOT /tmp)
- **Julia version**: 1.11.6 (via juliaup at ~/.juliaup/bin/julia, no module system)
- **Architecture**: x86_64 Linux
- **Execution Framework**: tmux for persistent sessions (no SLURM needed for single-user r04n02)

### Package Loading Reality Check ✅ FINAL STATUS Aug 29, 2025
- **Success rate**: ~90% of packages now work with native installation (improved from ~50%)
- **Always working**: LinearAlgebra, DataFrames, StaticArrays, Test
- **NOW WORKING**: ✅ **ForwardDiff, HomotopyContinuation, DynamicPolynomials** (via native installation)
- **All 11 critical packages verified**: Complete GlobTim dependency chain operational
- **Sometimes failing**: CSV (depending on bundle approach)
- **Strategies**: Native installation (primary and recommended) or Bundle approach with Manifest.toml (fallback)

**MILESTONE ACHIEVED:** Architecture compatibility challenges between macOS development and x86_64 Linux cluster deployment have been completely resolved.

## 🎉 BREAKTHROUGH: HomotopyContinuation FULLY WORKING ✅ COMPLETED
**Date Achieved:** August 29, 2025 - Job ID 59816729  
**Status:** ✅ **ARCHITECTURE COMPATIBILITY ISSUES FULLY RESOLVED**

### Native Installation Success - PRODUCTION READY
- ✅ **HomotopyContinuation v2.15.0** installed and functional on x86_64 Linux cluster
- ✅ **ForwardDiff v0.10.38** installed and functional  
- ✅ **203 packages** successfully installed with correct x86_64 artifacts
- ✅ **All binary artifacts** (OpenBLAS32_jll, OpenSpecFun_jll) working correctly
- ✅ **Polynomial system solving** verified and tested on cluster
- ✅ **11 critical packages** confirmed working on cluster (August 29, 2025)
- ✅ **GlobTim package** now production-ready for HPC deployment

**Key Breakthrough:** Native installation on cluster eliminates all cross-platform issues between macOS development and Linux deployment.

**Project Status Update:** Repository has been comprehensively cleaned up with 25+ obsolete scripts removed and all changes committed to GitLab (commit ad76b40).

### Current HPC Solution

**Direct r04n02 Compute Node Access**
- Native Julia package installation via Pkg.add()
- Direct GitLab repository cloning on compute node  
- Full native environment (203+ packages working)
- Repository location: `/home/scholten/globtim` (permanent storage)
- Simplified deployment without bundling complexity
- Tmux-based persistent execution framework (no SLURM needed)

**Documentation:** 
- Infrastructure: `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`
- Execution Framework: `docs/hpc/ROBUST_WORKFLOW_GUIDE.md`

## HPC Execution Framework Status

### ✅ NEW FRAMEWORK: Tmux-Based Persistent Execution (CURRENT)
**Date Implemented:** September 2, 2025  
**Status:** PRODUCTION READY - Optimized for single-user r04n02 node

The GlobTim HPC deployment now uses **tmux for persistent execution** without SLURM overhead, perfectly suited for single-user compute node access.

**Current Working Configuration:**
```bash
# Connect to r04n02
ssh scholten@r04n02
cd /home/scholten/globtim

# Julia is in PATH via juliaup (no module needed)

# Start experiment in tmux session (automated)
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# Monitor progress
./hpc/monitoring/tmux_monitor.sh

# Attach to running session
tmux attach -t globtim_*
```

**Framework Features (September 2, 2025):**
- ✅ **Persistent execution**: Survives SSH disconnection via tmux
- ✅ **Automated management**: robust_experiment_runner.sh handles sessions
- ✅ **Checkpointing**: Julia-based experiment_manager.jl for recovery
- ✅ **Live monitoring**: tmux_monitor.sh tracks tmux sessions
- ✅ **Remote initiation**: Can start experiments via hpc-cluster-operator agent
- ✅ **No SLURM overhead**: Direct execution without scheduling delays
- ✅ **Integrated monitoring**: tmux_monitor.sh tracks sessions and Julia processes
- ✅ **Repository location**: `/home/scholten/globtim` (NOT /tmp, permanent storage)

## HPC Compilation Approaches

## Current Test Execution Status

### ⚠️ PARTIAL: Original @test Suite Execution  
**Status:** Limited due to package dependency failures

**What's Currently Running:**
- ✅ Embedded test suite (comprehensive mathematical functionality)
- ✅ Core package tests (LinearAlgebra, DataFrames, StaticArrays)
- ✅ Manual implementations (finite differences, polynomial evaluation)
- ❌ Original `/test/runtests.jl` suite (fails due to ForwardDiff/HomotopyContinuation dependencies)

**Package Dependency Status (Updated Aug 29, 2025):**
- ForwardDiff: ✅ **NOW WORKING** (via native installation)
- HomotopyContinuation: ✅ **NOW WORKING** (via native installation)  
- DynamicPolynomials: ✅ **NOW WORKING** (via native installation)
- CSV: ⚠️ Sometimes fails (bundle-dependent)

**Updated Recommendation:** The native installation approach resolves most package compatibility issues. Original test suite execution is now achievable with the correct installation method.

### 🎯 CURRENT APPROACH: Native Installation + Full Package Support
**Date Updated:** August 29, 2025  
**Status:** ✅ **Full external package support achieved**

**Why Native Installation is Superior:**
1. **Complete Compatibility**: All packages work with correct architecture
2. **No Workarounds Needed**: Original test suites can run unmodified  
3. **Maintainability**: Standard Julia package ecosystem, no custom fallbacks
4. **Performance**: Optimized precompilation for target architecture
5. **Future-Proof**: Handles new package dependencies automatically

**Fallback**: Embedded alternatives available if needed, but no longer required for most packages.

**Coverage Comparison:**
| Test Category | Original @test | Current Embedded | Status |
|---------------|----------------|------------------|---------|
| Linear Algebra | ✅ | ✅ | Equivalent |
| Differentiation | ForwardDiff | Manual finite diff | ✅ Functional |
| Optimization | External packages | Manual gradient descent | ✅ Functional |
| Polynomials | DynamicPolynomials | Manual evaluation | ✅ Functional |
| Benchmark Functions | External deps | Embedded functions | ✅ Equivalent |

### ✅ CORRECT APPROACH: Proper Package Management

GlobTim must be compiled with its full dependency chain using one of these methods:

1. **Offline Bundle Creation** (for air-gapped clusters):
   - Create a complete Julia depot locally with all dependencies
   - Transfer the depot bundle to the HPC cluster
   - Use the offline depot for compilation

2. **Direct Package Installation** (if cluster has internet):
   - Use `Pkg.instantiate()` to install all dependencies
   - Ensure proper JULIA_DEPOT_PATH configuration
   - Handle precompilation appropriately

3. **Container-Based Deployment**:
   - Use Singularity/Apptainer containers with pre-installed dependencies
   - Ensures reproducible environment across different HPC systems

## Key Lessons Learned & Major Accomplishments

### Technical Breakthroughs Achieved:
- ✅ **FULLY RESOLVED:** Architecture compatibility issues between macOS development and x86_64 Linux cluster
- ✅ **PRODUCTION READY:** GlobTim package now fully operational on HPC cluster
- ✅ **NATIVE INSTALLATION SUCCESS:** 203 packages with correct binary artifacts working on cluster
- ✅ **COMPREHENSIVE CLEANUP:** Repository streamlined with 60+ obsolete files removed (Phase 3 complete)
- ✅ **DOCUMENTATION COMPLETE:** docs/hpc/HPC_BUNDLE_SOLUTIONS.md and docs/hpc/HOMOTOPY_SOLUTION_SUMMARY.md created
- ✅ **PACKAGE SUCCESS RATE:** Improved from ~50% to ~90% with native installation approach
- ✅ **TEST SUITE EXCELLENCE:** All 64 convenience method tests now passing, 1D scalar function handling fixed
- ✅ **REPOSITORY HEALTH:** .gitignore enhanced, clutter eliminated, excellent maintainability achieved

### Core Technical Principles:
- Always verify that external dependencies are available and loadable
- Test actual GlobTim functionality, not just basic Julia operations
- Document dependency requirements clearly in Project.toml
- Use proper package management even if it's more complex to set up initially
- Native cluster installation eliminates cross-platform compilation issues
- Work in `/tmp/` on r04n02 for isolation and no quota constraints

**PROJECT STATUS UPDATE (September 1, 2025):** All major HPC deployment and repository hygiene challenges have been resolved. The GlobTim package is production-ready for cluster deployment with 624 passing tests on r04n02. **Phase 4 visual project management implementation is now underway with 1,168 tasks extracted and classified.**

**PHASE COMPLETION STATUS:**
- Phase 1: HPC Infrastructure ✅ COMPLETED
- Phase 2: Julia Environment ✅ COMPLETED  
- Phase 3: Repository Hygiene ✅ COMPLETED
- Phase 4: Advanced Project Management & Mathematical Refinement 🔄 **ACTIVE PROGRESS** 
  - ✅ **Task Extraction Milestone**: 1,168 tasks extracted and classified (September 1, 2025)
  - 🔄 **GitLab Visual Tracking**: Integration with project boards and milestone system in progress
  - ✅ **Agent Configuration Review**: GitLab issue FULLY COMPLETED - Comprehensive agent optimization with 5 agents refactored (September 2, 2025)
  - ⏳ **Mathematical Algorithm Review**: Deep analysis planned for mathematical correctness validation

**FOCUS EVOLUTION:** Successfully transitioned from infrastructure foundation (COMPLETE) to advanced project management systems and mathematical excellence (ACTIVE DEVELOPMENT).

## 🚀 HPC Execution Framework - PRODUCTION READY

### Comprehensive Remote Experiment Management
- ✅ **Direct Node Execution**: Fully automated remote experiment start via SSH
- ✅ **Live Monitoring**: Integrated `live_monitor.sh` for real-time experiment tracking
- ✅ **Checkpointing**: `experiment_manager.jl` enables robust experiment state management
- ✅ **4D Model Workflow**: Seamless execution and monitoring on r04n02
- ✅ **tmux-Based Framework**: Replaces legacy SLURM job submission
- ✅ **Workflow Flexibility**: Supports single-user and multi-experiment scenarios

**Key Capabilities:**
1. Start experiments remotely with single SSH command
2. Real-time monitoring of computational progress
3. Automatic checkpointing and state recovery
4. Simplified workflow without complex job scheduling
5. Full compatibility with native Julia package ecosystem

## 🚀 BREAKTHROUGH: HPC Infrastructure Modernization ✅ COMPLETED
**Date Achieved:** September 1, 2025  
**Status:** ✅ **DIRECT r04n02 COMPUTE NODE ACCESS OPERATIONAL**

### Infrastructure Migration Success - PRODUCTION READY  
- ✅ **Direct SSH Access**: r04n02 compute node connection established and verified
- ✅ **GitLab Integration**: SSH keys configured, full Git operations working on compute node
- ✅ **Repository Access**: GlobTim repository successfully cloned at `/tmp/globtim/` with full branch access
- ✅ **Security Hardened**: SSH key authentication, workspace isolation, resource constraints implemented
- ✅ **HPC Agent Modernized**: Updated `.claude/agents/hpc-cluster-operator.md` for dual workflow support
- ✅ **Migration Planning**: Comprehensive migration plan documented in `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`

**Key Infrastructure Advantages Achieved:**
1. **NFS Constraints Eliminated**: No 1GB home directory quota limitation
2. **Direct Git Operations**: Clone repositories directly on compute node
3. **Native Package Management**: Use Julia Pkg.add() without complex bundling
4. **Simplified Deployment**: Streamlined workflow replacing complex file transfers
5. **Enhanced Security**: Modern security practices with SSH keys and workspace isolation

**Project Status Update:** Legacy NFS-constrained workflow superseded by modern direct node access approach.

**Phase 2 Complete - Major Validation Success (September 1, 2025):**
- ✅ **GlobTim Compilation**: Successfully compiled with native package management
- ✅ **Native Julia Environment**: 203+ packages installed including HomotopyContinuation v2.15.0
- ✅ **Test Suite Validation**: 624 passing tests across core mathematical operations
- ✅ **HomotopyContinuation**: Fully operational for polynomial system solving
- ✅ **ForwardDiff**: Complete automatic differentiation functionality (30/30 tests passed)
- ✅ **UUIDs Version Fix**: Resolved compatibility issue with Julia 1.11.6 sysimage

**Phase 3 Complete - Repository Hygiene Success (September 1, 2025):**
✅ **REPOSITORY CLEANUP COMPLETED** - 60+ obsolete files removed, repository health excellent
✅ **TEST SUITE FIXED** - All 64 convenience method tests now pass (fixed 1D scalar function handling)
✅ **ISSUE CLASSIFICATION COMPLETE** - Infrastructure work complete, focus on mathematical core

**CURRENT PRIORITY TASKS (Phase 4 - Advanced Project Management & Mathematical Refinement):**

**🎉 RECENT MILESTONE: GitLab Integration Complete (September 1, 2025)**
- ✅ **Secure GitLab API Configuration**: Automated token management without manual copy/pasting
- ✅ **8 Strategic Issues Created**: High-level project tracking instead of 1,168 granular tasks
- ✅ **Production Ready Integration**: All GitLab operations now fully automated and secure
- ✅ **Issue Tracking Active**: GitLab project boards ready for visual project management

**📋 IMPORTANT: Project Terminology**
- **"Issue"** = GitLab issue in the project management system (not a problem/bug)
- When discussing "an issue" or "the issue", this refers to tracked GitLab project management items
- GitLab issues are used for features, tasks, improvements, and bug tracking

**Task Distribution Analysis:**
- **Total Tasks**: 1,168 across 7 epics (mathematical-core, performance, test-framework, etc.)
- **Status Breakdown**: 1,033 not started, 113 completed, 21 in progress, 1 cancelled
- **Priority Distribution**: 28 Critical, 18 High, 1,064 Medium, 58 Low priority tasks
- **Epic Categories**: Comprehensive coverage across mathematical core, HPC deployment, performance, testing, and visualization

**Active Priorities:**
1. **📈 HIGH PRIORITY: GitLab Visual Project Management** - Deploy extracted tasks to GitLab boards and milestone system ✅ COMPLETED
2. **🔬 Mathematical Algorithm Review** - Deep dive into homotopy continuation mathematical correctness
2. **🔬 Mathematical Algorithm Review** - Deep dive into homotopy continuation mathematical correctness
3. **🎯 Optimization Algorithm Refinement** - Improve numerical stability and convergence properties  
4. **📊 Performance Benchmarking** - Comprehensive performance analysis across different problem types
5. **📋 SLURM Infrastructure** - Create direct node job scheduling templates (lower priority)
6. **📁 Example Architecture** - Organize GlobTim example management system (lower priority)

## 📚 HPC Documentation References - COMPLETE SOLUTION SET
- **`docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`** - Current infrastructure migration to direct r04n02 access ✅ OPERATIONAL
- **`docs/hpc/HOMOTOPY_SOLUTION_SUMMARY.md`** - Technical analysis of HomotopyContinuation deployment approaches ✅ CREATED
- **`docs/hpc/HPC_BUNDLE_SOLUTIONS.md`** - Historical bundle creation solutions (legacy) ✅ ARCHIVED
- **Legacy Scripts** - Bundle-based deployment scripts removed as part of infrastructure modernization

### Repository Status (September 1, 2025):
**✅ HPC INFRASTRUCTURE PHASE COMPLETE:**
- ✅ **Infrastructure Modernized**: Direct r04n02 compute node access operational
- ✅ **Security Implemented**: SSH keys, workspace isolation, resource constraints configured
- ✅ **Git Integration**: Full GitLab connectivity established on compute node
- ✅ **Agent Updated**: HPC cluster operator agent modernized for dual workflow support
- ✅ **Mathematical Validation**: 624 passing tests confirming core functionality

**📈 CURRENT PRIORITY: Advanced Project Management & Mathematical Excellence**
✅ **Repository Hygiene Complete**: 60+ clutter files removed, .gitignore enhanced, excellent repository health achieved
✅ **Test Suite Excellence**: All 64 convenience method tests passing, scalar function handling fixed
✅ **Infrastructure Work Complete**: All HPC deployment challenges resolved, focus shifted to mathematical core
🔄 **NEW FOCUS**: Advanced GitLab visual tracking features and mathematical algorithm refinement