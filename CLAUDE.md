# GlobTim Project Memory

## 🎯 Current Project Status (September 2025)

**Infrastructure**: ✅ HPC Direct Node Access Operational (r04n02)  
**Mathematical Core**: ✅ All packages working (HomotopyContinuation, ForwardDiff, etc.) + Lambda size computation pipeline operational  
**L2 Norm & Memory**: ✅ **CRITICAL BREAKTHROUGH** - L2 norm computation fixes complete, memory usage optimized (100% success rate achieved)  
**Automation**: ✅ Hook Integration System Active  
**Performance Tracking**: ✅ Comprehensive Performance Optimization & Benchmarking Operational  
**Post-Processing**: ✅ Comprehensive Analysis Infrastructure Operational (Issues #64/#65/#66 - quality metrics, reporting, HPC integration)  
**Visualization Framework**: ✅ Extensible Plotting Architecture Operational (with Makie integration support)  
**Project Management**: ✅ GitLab Issues & Visual Tracking Operational

## 🤖 Claude Code Agent Usage Guide

**When to Use Each Agent:**

- **`hpc-cluster-operator`**: For all HPC tasks on r04n02 - SSH access, job execution, monitoring
- **`project-task-updater`**: Automatically triggered after completing features/milestones - updates GitLab issues
- **`julia-test-architect`**: Automatically triggered after implementing new features - creates comprehensive tests  
- **`julia-documenter-expert`**: Automatically triggered after feature completion - maintains documentation sync
- **`julia-repo-guardian`**: For repository maintenance, consistency checks, cleanup tasks

## 🔗 Hook System Architecture

**Security & Validation Hooks:**
- **SSH Security Hook**: `tools/hpc/ssh-security-hook.sh` - Validates all HPC connections
- **Node Security Hook**: `tools/hpc/node-security-hook.sh` - HPC-specific security policies  
- **Pre-Execution Validation**: `tools/hpc/validation/` - Script discovery, package validation

**Resource Monitoring:**
- **HPC Resource Monitor**: `/Users/ghscholt/.claude/hooks/hpc-resource-monitor.sh` - Live experiment tracking
- **GitLab Integration**: `tools/gitlab/gitlab-security-hook.sh` - Secure GitLab operations

**Automation Pipeline:**
```
Pre-Execution → Hook Orchestrator → Computation → Resource Monitor → Post-Processing
      ↓               ↓                 ↓              ↓               ↓
   Validation      Security        HPC Examples    Live Tracking    GitLab Updates
```

**Current Status**: ✅ STRATEGIC HOOK INTEGRATION COMPLETE - Full HPC workflow orchestration operational on r04n02, all critical hook system failures resolved (Issue #58 CLOSED), production-ready 5-phase pipeline successfully managing 4D mathematical computation workloads

## 🔬 L2 Norm & Memory Optimization (September 2025)

**CRITICAL BREAKTHROUGH ACHIEVED** - Issue #70 resolved with dramatic success rate improvement:

**Root Cause & Resolution:**
- **Problem**: Grid generation memory exhaustion due to parameter misinterpretation
- **Cause**: Scripts used `GN = samples_per_dim^4` but `generate_grid(n, GN)` interpreted GN as points per dimension
- **Result**: Created `(samples_per_dim^4 + 1)^4` grid points instead of `samples_per_dim^4`
- **Impact**: Memory usage of hundreds of GB causing OutOfMemoryError in 88.2% of experiments

**Technical Fixes Applied:**
- **Memory Estimation**: Corrected `src/Main_Gen.jl` to target grid generation bottleneck (`samples_per_dim^n`)
- **L2 Norm Computation**: Fixed `src/scaling_utils.jl` compute_norm functions to use proper SVector exact matching
- **Parameter Validation**: Added safety checks with 4D-specific recommendations (≤12 samples per dim)
- **Fallback Removal**: Eliminated all fallback mechanisms - proper computation only
- **Script Updates**: Corrected experiment runners with safe default parameters

**Validated Safe Parameters for 4D Problems:**
```
GN = 12 samples per dimension (total: 12^4 = 20,736 samples)
Degree range: 4-8 (recommended: 6)
Memory usage: 0.001-0.078 GB (vs. hundreds of GB previously)
Grid generation: 13^4 = 28,561 points (manageable)
```

**Performance Impact:**
- **Success Rate**: 11.8% → **100%** for polynomial approximation phase
- **Memory Efficiency**: 1000x reduction in memory usage
- **Grid Generation**: No OutOfMemoryError failures
- **L2 Norm**: Proper discrete Riemann sum computation without fallbacks

## 📊 Post-Processing Infrastructure Usage

**Comprehensive Analysis Framework** (Issues #64/#65/#66 COMPLETED):
- **Quality Metrics**: Automated L2 norm analysis, condition number assessment, polynomial degree optimization
- **Efficiency Analysis**: Sample-to-dimension ratios, computational resource utilization 
- **Collection Analytics**: Multi-experiment comparison, success pattern identification
- **Report Generation**: Automated comprehensive analysis reports with optimization recommendations

**How to Use Post-Processing Tools:**
```bash
# On HPC node r04n02 - analyze individual results
cd /home/scholten/globtim
julia --project=. -e "
using Globtim
include(\"src/PostProcessing.jl\")
analyze_experiment_results(\"path/to/results.json\")
"

# Analyze experiment collections
julia --project=. -e "
include(\"comprehensive_collection_analysis.jl\")
generate_optimization_report(\"hpc_results/collection_summary.json\")
"

# Generate reports locally after HPC runs
julia --project=. Examples/post_processing_example.jl
```

**Key Capabilities:**
- **Quality Classification**: Automatic categorization (Excellent <1e-4, Good <0.1, Poor >0.1)
- **Performance Benchmarking**: Cross-experiment efficiency comparisons
- **Optimization Guidance**: Specific parameter recommendations based on success patterns
- **Failure Analysis**: Systematic identification of infrastructure issues and solutions

**Integration Points:**
- **HPC Automation**: Automatic post-processing via robust_experiment_runner.sh
- **GitLab Updates**: Results automatically documented in project issues
- **Report Generation**: Comprehensive analysis reports with actionable insights

## 📋 GitLab Project Management

**API Access:**
```bash
# Get GitLab token
export GITLAB_TOKEN="$(./tools/gitlab/get-token.sh)"
export GITLAB_PROJECT_ID="2545"

# Use GitLab API
./tools/gitlab/gitlab-api.sh list-issues
./tools/gitlab/gitlab-api.sh update-issue <issue_id> --labels "priority:high,type:feature"
```

**Issue Management:**
- **Project URL**: https://git.mpi-cbg.de/scholten/globtim/-/issues
- **Visual Boards**: GitLab project boards with milestone tracking
- **Automation**: project-task-updater agent handles automatic issue updates

**Key Issues:**
- **#11**: HPC Performance Optimization & Benchmarking (✅ CLOSED - COMPLETED: Comprehensive performance tracking infrastructure implemented with Julia best practices, automated baseline establishment, regression detection, and HPC integration operational)
- **#16**: 4D Model Experiments: HPC Workflow Validation (✅ CRITICAL MILESTONE ACHIEVED - Lambda size computation bugs resolved, 4D mathematical pipeline fully operational on r04n02)
- **#27**: Pre-Execution Validation System (50% complete)
- **#28**: Advanced Workflow Automation (planned)
- **#29**: AI-Driven Experiment Management (planned)
- **#41**: Strategic Hook Integration (✅ CLOSED - Production-ready strategic hook orchestrator operational, 5-phase pipeline managing 4D workloads successfully)
- **#44**: Sparsification Study Framework (complete)
- **#45**: GLMakie Extension Loading Failures (✅ CLOSED - All plotting functionality operational, valley walking validation complete)
- **#47**: Momentum-Enhanced Valley Walking Algorithm (✅ COMPLETED - Algorithm enhancement successful: 6 points→201 points per direction, iterative valley tracking operational, dynamic manifold following implemented)
- **#48**: Valley Walking Educational Materials (✅ NEW - Interactive notebooks and comprehensive examples)
- **#49**: Valley Walking Performance Comparison (✅ NEW - Systematic algorithm benchmarking study)
- **#50**: Advanced Interactive Visualization Features (✅ NEW - Enhanced GLMakie capabilities for mathematical algorithms)
- **#51**: Valley Walking Algorithm Premature Termination (✅ CLOSED - Resolved as duplicate of #47, all curved manifold following limitations eliminated)
- **#52**: Truncation Tests Returning Errors (✅ CLOSED - Fixed export statements in src/Globtim.jl, all 34 truncation tests now passing)
- **#53**: Package Dependency Failures - StaticArrays Missing (✅ CLOSED - RESOLVED: Fixed missing Pkg.instantiate() in experiment runners, all 4D mathematical computations operational on r04n02)
- **#54**: Disk Quota Exceeded During Package Precompilation (✅ CLOSED - RESOLVED: Secondary effect of #53, fixed by Pkg.instantiate() improvements, 4D computational pipeline fully operational without disk quota limitations)
- **#23**: 4D Experiment Package Activation Error (✅ CLOSED - CRITICAL FIX: Fixed temp script path calculation, 4D experiments operational)
- **#24**: 4D Experiment Objective Function Access Error (✅ CLOSED - CRITICAL FIX: Fixed GlobTim API field access, parameter estimation functional)
- **#25**: 4D Experiment Debugging Workflow Documentation (✅ CLOSED - VALIDATED: Complete debugging session documented, all fixes verified in codebase, production-ready status confirmed)
- **#55**: Variable Scope Issues in Monitoring Workflows (⚠️ MEDIUM PRIORITY - Related to 88% experiment failure rate identified in post-processing analysis)
- **#56**: Remove Legacy SLURM Infrastructure (✅ CLOSED - All legacy SLURM infrastructure deprecated and replaced with direct execution patterns. All validation scripts updated, deployment scripts deprecated with clear guidance, no active SLURM parsing errors remain)
- **#57**: Comprehensive HPC Testing Framework (⚡ ENHANCEMENT - Systematic testing based on error analysis)
- **#58**: HPC Hook System Failures on r04n02 (✅ CLOSED - SUCCESSFULLY RESOLVED - All critical fixes validated and deployed: lifecycle state management operational, path resolution working cross-environment, full orchestrated pipeline completing successfully on HPC node)
- **#59**: Hook Environment Auto-Detection System (✅ CLOSED - Individual component working correctly)
- **#60**: GitLab Integration Hook HPC Compatibility (✅ CLOSED - Individual component working correctly)
- **#61**: Lifecycle State Management Stabilization (✅ CLOSED - Individual component working correctly)
- **#62**: Hook Registry Path Resolution (✅ CLOSED - Individual component working correctly)
- **#63**: Fix project-task-updater agent GitLab API communication (✅ CLOSED - RESOLVED: Comprehensive testing revealed GitLab API communication is fully functional, all originally reported problems have been addressed)
- **#64**: Implement lightweight post-processing metrics for standardized examples (✅ CLOSED - COMPLETED: Comprehensive post-processing metrics system implemented with 618 tests, L2 norm quality classification, critical point distance computation, sampling efficiency metrics, and real data validation - production-ready infrastructure operational)
- **#65**: Create minimal computational results reporting (✅ CLOSED - COMPLETED: Executable Julia report generation system implemented with comprehensive post-processing metrics, numerical output formatting, and production-ready infrastructure operational)
- **#66**: Integrate post-processing with robust experiment runner (✅ CLOSED - COMPLETED: Post-processing integration successfully implemented with automatic result detection, tmux session integration, optional disable flag, and comprehensive testing - HPC automation pipeline enhanced with seamless post-processing workflow)
- **#67**: Prepare visualization framework for future plotting capabilities (✅ CLOSED - COMPLETED: Extensible visualization framework implemented with abstract plotting interface, data preparation functions for L2-degree analysis, optional dependency handling, Makie integration points, comprehensive documentation, and working examples - production-ready infrastructure operational)
- **#69**: Implement local logging system for HPC file launch tracking (🚀 NEW FEATURE - Comprehensive audit trail system for tracking all HPC operations, file transfers, experiment metadata, and integration with existing hook orchestrator - enhances debugging, reproducibility, and operational monitoring)
- **#70**: Critical: Improve HPC experiment success rate from 11.8% to 80% (✅ CLOSED - **BREAKTHROUGH ACHIEVED Sept 9, 2025** - Success rate improved from 11.8% → **100%**! Root cause identified: parameter misinterpretation causing memory exhaustion. L2 norm computation fixes implemented, memory usage reduced 1000x, all experiment scripts corrected with safe 4D parameters. Production-ready HPC mathematical computation pipeline operational)

## 🔧 Git Configuration

**SSH Key Setup:**
- **HPC Access**: SSH keys configured for r04n02 compute node
- **GitLab Integration**: SSH authentication for git.mpi-cbg.de
- **Security**: Ed25519 keys with security hook validation

**Repository Access:**
```bash
# HPC repository location (permanent)
ssh scholten@r04n02
cd /home/scholten/globtim

# Local development
git remote get-url origin  # git.mpi-cbg.de/scholten/globtim.git
```

**Branch Management:**
- **Main Branch**: `main` (development)
- **Clean Version**: `clean-version` (for PRs)
- **SSH Authentication**: Automatic via configured keys

## 🔥 Critical HPC Knowledge

**r04n02 Direct Access:**
```bash
# Connect to compute node
ssh scholten@r04n02
cd /home/scholten/globtim

# Julia available via juliaup (no modules needed)
julia --project=. --heap-size-hint=50G
```

**Package Management:**
- **Native Installation**: All 203+ packages working via Pkg.add()
- **Critical Packages**: HomotopyContinuation, ForwardDiff, DynamicPolynomials all operational
- **Architecture**: x86_64 Linux with correct binary artifacts

**Execution Framework:**
- **tmux Sessions**: Persistent execution via robust_experiment_runner.sh
- **Resource Monitoring**: Live tracking via HPC Resource Monitor Hook
- **No SLURM**: Direct execution without scheduling overhead


## 📚 Documentation References

**For detailed information, see:**
- **HPC Infrastructure**: `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`
- **Hook Integration**: `docs/hpc/HOOK_INTEGRATION_GUIDE.md` 
- **Post-Processing Analysis**: `POST_PROCESSING_ANALYSIS_REPORT.md` - Comprehensive analysis of recent HPC experiments
- **GitLab Management**: `docs/project-management/GITLAB_VISUAL_MANAGEMENT_STATUS.md`
- **Security Framework**: `docs/hpc/SSH_SECURITY_SYSTEM_DOCUMENTATION.md`
- **Historical Milestones**: `docs/project-management/MILESTONE_HISTORY.md`