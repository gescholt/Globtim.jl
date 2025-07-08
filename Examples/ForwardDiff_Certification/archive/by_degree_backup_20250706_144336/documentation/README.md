# By-Degree Analysis Documentation

This directory contains comprehensive documentation for the by-degree analysis framework, which analyzes polynomial approximation performance across spatial subdomains of the 4D Deuflhard function.

## Latest Updates (Enhanced Analysis V2)

The analysis has been significantly improved to focus on local minimizer recovery rather than all critical points:
- **9 true minimizers** tracked from CSV file instead of theoretical tensor products
- **Enhanced visualizations** with quartile bands and global comparison
- **Cleaner metrics** focused on minimizer recovery rates

## Documentation Files

### 1. [subdivided_analysis_workflow.md](subdivided_analysis_workflow.md)
**Overview of the complete analysis pipeline**
- Domain setup and subdivision strategy
- Key functions and their roles
- Input/output descriptions
- Performance considerations
- Current insights from the implementation

### 2. [function_io_reference.md](function_io_reference.md)
**Detailed function specifications**
- Input parameters and types
- Output structures and fields
- Mathematical formulas used
- Performance bottlenecks
- Error handling strategies

### 3. [critical_code_decisions.md](critical_code_decisions.md)
**Key design decisions and their rationale**
- Why analyze empty subdomains
- Point matching algorithm choice
- Dual-scale plotting strategy
- Color scheme philosophy
- Data reorganization logic
- Grid resolution trade-offs

### 4. [data_flow_diagram.md](data_flow_diagram.md)
**Visual representation of data transformations**
- ASCII flow diagram of the complete pipeline
- Data structure evolution through stages
- Critical data points and counts
- Key insights highlighted

## Quick Start Guide

To understand the subdivided analysis example:

1. **Start with the workflow** ([subdivided_analysis_workflow.md](subdivided_analysis_workflow.md)) to get the big picture
2. **Refer to function I/O** ([function_io_reference.md](function_io_reference.md)) for specific implementation details
3. **Understand design choices** ([critical_code_decisions.md](critical_code_decisions.md)) for why things work as they do
4. **Follow the data flow** ([data_flow_diagram.md](data_flow_diagram.md)) to see how information transforms

## Key Concepts

### Spatial Subdivision
The (+,-,+,-) orthant `[0,1]×[-1,0]×[0,1]×[-1,0]` is divided into 16 subdomains by splitting each dimension at its midpoint. Each subdomain is labeled with a 4-bit string (e.g., "1010") indicating upper/lower half selection.

### Theoretical Point Distribution
All 9 theoretical critical points (1 min+min, 2 min+saddle, 2 saddle+min, 4 saddle+saddle) fall within subdomain "1010". This concentration explains why:
- L²-norm plots show 16 curves (all subdomains analyzed)
- Min+min distance plots show 1 curve (only subdomain 1010 has data)

### Analysis Strategy
Each subdomain receives independent polynomial approximation at degrees [2,3,4,5,6]. Results are aggregated to understand:
- Spatial patterns in approximation difficulty
- Convergence rates across the domain
- Critical point recovery success

## Common Questions

**Q: Why are all L²-norm curves the same color?**
A: They measure the same quantity (approximation error), so using the same color with transparency shows the pattern of convergence rates across spatial regions.

**Q: Why do some degree/subdomain combinations have gaps?**
A: Polynomial construction can fail due to timeouts or numerical issues, especially at higher degrees or in difficult regions.

**Q: Why analyze subdomains without theoretical points?**
A: L²-norm convergence provides valuable information about approximation quality even without known critical points to compare against.

## Related Files

- **Example script**: `examples/02_subdivided_fixed.jl`
- **Shared utilities**: `shared/` directory
- **Outputs**: `outputs/HH-MM/` timestamped directories
- **Verification**: `VERIFICATION_SUMMARY.md` in parent directory