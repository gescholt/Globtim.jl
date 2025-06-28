# Archive - Experimental and Legacy Files

This folder contains experimental, debugging, and legacy files that were created during the development of the 4D Deuflhard analysis. These files are preserved for reference but are no longer part of the main workflow.

## Folder Structure

### `/experimental/`
Contains experimental implementations and development versions:
- `deuflhard_4d_orthants_demo.jl` - Earlier version of orthant decomposition (superseded by `deuflhard_4d_complete.jl`)
- `deuflhard_4d_bfgs_demo.jl` - BFGS demonstration on subset of orthants
- `deuflhard_4d_orthants.jl` - Legacy orthant analysis
- `orthant_clarification_demo.jl` - Educational demo explaining 2^4 = 16 orthants
- `simple_orthant_example.jl` - Simple quadratic orthant example
- `test_orthant_decomposition.jl` - Comprehensive test suite for orthant decomposition

### `/comparisons/`
Contains various comparison scripts between raw and refined critical points:
- `deuflhard_4d_full_comparison.jl` - Comprehensive comparison across all orthants
- `deuflhard_4d_comparison_fast.jl` - Fast comparison with reduced computational requirements
- `deuflhard_4d_simple_comparison.jl` - Basic raw vs refined comparison
- `deuflhard_4d_raw_refined_comparison.jl` - Single orthant comparison
- `final_raw_refined_comparison.jl` - Final comparison script

### `/debugging/`
Contains minimal debugging and testing tools:
- `deuflhard_4d_minimal_comparison.jl` - Smallest possible comparison script
- `quick_raw_refined_demo.jl` - Quick debugging demo

## Consolidation Notes

All functionality from these experimental files has been consolidated into the main production files:

- **`deuflhard_4d_complete.jl`** - Single definitive file combining all best practices
- **`deuflhard_4d_analysis.jl`** - Original comprehensive analysis
- **`deuflhard_4d_analysis_msolve.jl`** - Alternative solver version
- **`deuflhard_4d_analysis_high_precision.jl`** - High-precision enhancement

These archived files remain available for:
- Historical reference
- Understanding the development process
- Extracting specific experimental features if needed
- Educational purposes

## Usage

To use any archived file, simply copy it back to the main directory. However, we recommend using the consolidated `deuflhard_4d_complete.jl` for new work as it represents the best practices from all experimental versions.