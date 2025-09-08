# Changelog

All notable changes to Globtim.jl will be documented in this file.

## [Unreleased]

### 🧹 Legacy Infrastructure Cleanup COMPLETED (September 8, 2025)
- **✅ ISSUE #56 RESOLVED**: Remove Legacy SLURM Infrastructure - Complete deprecation of obsolete scheduling system
- **Validation Scripts Modernized**: Updated `tools/validation/test_hpc_access.sh` and `validate_infrastructure.sh` to use direct execution checks instead of SLURM
- **Deployment Script Deprecation**: Added clear deprecation notices to `submit_minimal_job.sh`, `submit_hpc_jobs.sh`, and `run_custom_hpc_test.sh` with guidance to use `robust_experiment_runner.sh`
- **Template Cleanup**: Deprecated `globtim_custom.slurm.template` with legacy cluster designation
- **Error Resolution**: Eliminated SLURM parsing errors ("i: command not found", "point: command not found", "value: command not found") from job logs
- **Direct Execution Migration**: All active scripts now use tmux-based direct execution on r04n02, no functional SLURM dependencies remain
- **User Experience**: Clear guidance provided for users to migrate from legacy SLURM workflows to modern direct execution patterns

### 🚨 Package Management & Resource Issues RESOLVED (September 8, 2025)
- **✅ ISSUE #54 CLOSED**: Disk Quota Exceeded During Package Precompilation - RESOLVED as secondary effect
- **Root Cause Identified**: Disk quota failures were cascading effects of package dependency issues (#53)
- **Technical Resolution**: Pkg.instantiate() improvements in experiment runners resolved both dependency and quota issues
- **Validation Results**: 4D computational pipeline operational without disk limitations (156G available)
- **System Status**: MKL/LinearSolve precompilation working correctly, active 4D computation sessions running successfully
- **Impact Resolution**: No longer blocks mathematical operations, all 4D Lotka-Volterra computations operational

### 🏆 HPC Hook System Integration SUCCESSFULLY RESOLVED (September 8, 2025)
- **✅ ISSUE #58 CLOSED**: Complete resolution of all HPC Hook System failures on r04n02 node
- **Production Validation**: Full orchestrated pipeline completing successfully with proper lifecycle state transitions
- **Lifecycle Manager Resolution**: Fixed invalid phase transition errors - proper initialization → validation → preparation → execution → monitoring → completion flow operational
- **Environment-Aware Path Translation**: Hook orchestrator automatically translates paths between macOS development and HPC production environments
- **Integration Layer Success**: Streamlined orchestrator integration eliminates competing lifecycle states
- **Strategic Hook Integration Complete**: Production-ready 5-phase pipeline managing 4D mathematical computation workloads
- **Technical Implementation**: Commits 229c98e, 1f64dfe, and c246551 with comprehensive lifecycle and path fixes validated
- **Sub-Issues Resolved**: All debugging sub-issues (#59-62) closed with confirmed component-level stability
- **Cross-Environment Compatibility**: Single hook registry working consistently in both macOS development and HPC production
- **State Management**: Proper experiment archiving and lifecycle management fully operational
- **Result**: Strategic hook integration foundation fully operational and production-ready

### 🎨 Plotting System Resolution (September 7, 2025)
- **GLMakie Extension Fully Resolved**: Complete resolution of all plotting functionality issues (GitLab #45)
- **Deuflhard Notebook Fix**: Resolved plotting function call requiring module prefix `Globtim.cairo_plot_polyapprox_levelset()`
- **Documentation Updates**: Updated plotting backend documentation with proper usage patterns and module prefixes
- **Contour Plot Functionality**: Confirmed CairoMakie plotting generates contour plots with critical points and minimizers

### 🔧 Code Quality Improvements (September 2, 2025)
- **API Streamlining**: Reduced public exports from 258 to 164 for cleaner, more maintainable API
- **Aqua.jl Quality Checks**: Resolved all code quality issues including undefined exports, stale dependencies, and excessive exports
- **Internal Functions**: Made 80+ internal helper functions private (validation, grid utils, analysis helpers)
- **Test Environment Fix**: Resolved test environment configuration issues ensuring correct local package usage

### 🎯 PHASE 4: Advanced Project Management & Mathematical Refinement (September 1, 2025)
- **Task Extraction Milestone Achieved**: Successfully extracted and classified 1,168 tasks from entire repository
- **Comprehensive Task Analysis**: Automated categorization by status (1,033 not started, 113 completed, 21 in progress), priority (28 Critical, 18 High, 1,064 Medium, 58 Low), and epic classification
- **GitLab Integration Preparation**: Tasks structured for deployment to GitLab visual tracking system with project boards and milestone management
- **Project Management Advancement**: Transitioned from infrastructure focus to advanced workflow management and mathematical algorithm excellence
- **Epic Classification Complete**: Tasks organized across 7 major epics (mathematical-core, performance, test-framework, HPC deployment, visualization, documentation, advanced features)

### 🚀 MAJOR INFRASTRUCTURE MODERNIZATION: Direct r04n02 Compute Node Access (September 1, 2025)
- **Infrastructure Migration Completed**: Successfully migrated from legacy NFS-constrained workflow to direct HPC compute node access
- **Direct SSH Access**: r04n02 compute node connection established and verified with SSH key authentication
- **GitLab Integration**: Full Git operations working on compute node, repository cloned at `/tmp/globtim/`
- **Security Hardening**: Implemented SSH key auth, workspace isolation, resource constraints, and principle of least privilege
- **HPC Agent Modernized**: Updated `.claude/agents/hpc-cluster-operator.md` for dual workflow support (direct + legacy)
- **Migration Documentation**: Created comprehensive `HPC_DIRECT_NODE_MIGRATION_PLAN.md` with complete implementation roadmap

### 🎉 MAJOR BREAKTHROUGH: Complete HPC Deployment Solution (August 29, 2025)
- **HomotopyContinuation Fully Working**: Complete resolution of architecture compatibility issues between macOS development and x86_64 Linux cluster deployment
- **Native Installation Success**: 203 packages with correct binary artifacts installed and verified on falcon cluster (Job ID 59816729)
- **Package Success Rate**: Improved from ~50% to ~90% with native installation approach
- **Production-Ready Deployment**: Two verified working approaches (native installation primary, bundle deployment alternative)
- **Complete Documentation**: Created HPC_BUNDLE_SOLUTIONS.md and HOMOTOPY_SOLUTION_SUMMARY.md with comprehensive deployment guides

### Added
- **HPC Infrastructure (PRODUCTION READY)**
  - Native cluster installation script (`deploy_native_homotopy.slurm`)
  - Cross-platform bundle creation with architecture-specific artifacts
  - Comprehensive testing suite for HomotopyContinuation verification
  - NFS deployment workflow with quota management
  - Complete HPC documentation set

- **Polynomial Sparsification and Exact Arithmetic**
  - Convert polynomials from orthogonal bases to exact monomial form
  - Intelligent sparsification with configurable thresholds (relative/absolute)
  - Multiple L²-norm computation methods (Vandermonde, grid-based, exact)
  - Track approximation quality during sparsification
  - Analyze sparsity vs accuracy tradeoffs
  - New `BoxDomain` type for integration domains
  
- **New Functions**
  - `to_exact_monomial_basis` - Convert to monomial basis with exact coefficients
  - `sparsify_polynomial` - Remove small coefficients with L²-norm tracking
  - `truncate_polynomial` - Truncate with quality metrics
  - `compute_l2_norm_vandermonde` - Efficient L²-norm computation
  - `analyze_sparsification_tradeoff` - Systematic sparsity analysis
  - `verify_truncation_quality` - Verify L²-norm preservation
  
- **Dependencies**
  - Added MultivariatePolynomials.jl for polynomial manipulation

### Fixed
- **Architecture Compatibility**: Resolved all cross-platform deployment issues between macOS and Linux
- **HomotopyContinuation Deployment**: Complete solution for polynomial system solving on HPC clusters
- **Package Installation**: Native installation eliminates artifact compatibility problems
- **Repository Organization**: Removed 25+ obsolete scripts and consolidated documentation

## [1.1.0] - 2025-01-16

### Added
- **Hessian-Based Critical Point Classification**
  - Automatic classification of critical points (minimum, maximum, saddle, degenerate)
  - Complete eigenvalue analysis with numerical validation
  - ForwardDiff.jl integration for robust Hessian computation
  - New visualization functions for Hessian analysis

- **Enhanced Statistical Analysis for Critical Points**
  - Publication-quality ASCII tables for critical point statistics
  - Comprehensive statistical summaries by point type
  - Export capabilities for documentation and reporting
  - Condition number analysis for numerical stability assessment

- **Function Value Error Analysis**
  - New module for analyzing function value errors
  - Enhanced accuracy metrics and validation

- **Improved Polynomial Display**
  - Better formatting for polynomial coefficients
  - Enhanced readability in notebook environments

### Changed
- Updated weak dependencies system for Makie visualization
- Improved msolve parser to handle negative rational numbers
- Enhanced plotting functionality with better defaults
- Removed unnecessary dependencies (JuliaFormatter, Documenter, OrdinaryDiffEq)

### Fixed
- Fixed regex in msolve parser for negative rational numbers
- Improved handling of degenerate critical points
- Better error handling in eigenvalue computations

## [1.0.4] - Previous Release

### Features
- Core polynomial approximation algorithm
- Chebyshev and Legendre basis support
- HomotopyContinuation.jl integration
- Msolve support for exact solving
- Basic critical point finding and analysis