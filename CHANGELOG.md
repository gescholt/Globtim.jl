# Changelog

All notable changes to Globtim.jl will be documented in this file.

## [Unreleased]

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