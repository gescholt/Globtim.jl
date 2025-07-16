# Changelog

All notable changes to Globtim.jl will be documented in this file.

## [1.1.0] - 2025-01-16

### Added
- **Phase 2: Hessian-Based Critical Point Classification**
  - Automatic classification of critical points (minimum, maximum, saddle, degenerate)
  - Complete eigenvalue analysis with numerical validation
  - ForwardDiff.jl integration for robust Hessian computation
  - New visualization functions for Hessian analysis

- **Phase 3: Enhanced Statistical Analysis**
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