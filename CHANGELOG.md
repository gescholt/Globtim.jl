# Changelog

All notable changes to Globtim.jl will be documented in this file.

## [Unreleased]

### Added
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