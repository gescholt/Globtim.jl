# Clean Directory Structure - by_degree

After cleanup (January 2025), the directory has been streamlined to focus on production code:

```
by_degree/
├── README.md                                    # Main documentation
├── ENHANCED_ANALYSIS_SUMMARY.md                 # V2 implementation details
├── CLEANUP_PLAN_2025.md                        # Cleanup documentation
├── CLEANUP_SUMMARY.md                          # Cleanup results
├── DIRECTORY_STRUCTURE.md                      # This file
├── run_all_examples.jl                         # Main entry point
│
├── examples/                                    # Analysis implementations
│   ├── README.md                               # Examples documentation
│   └── degree_convergence_analysis_enhanced_v2.jl  # Current implementation
│
├── shared/                                      # Shared utilities
│   ├── Common4DDeuflhard.jl                    # Function definitions
│   └── SubdomainManagement.jl                  # Domain utilities
│
├── points_deufl/                               # Reference data
│   ├── 2d_coords.csv                          # 2D critical points
│   └── 4d_min_min_domain.csv                  # 9 true 4D minimizers
│
├── documentation/                              # Detailed documentation
│   ├── README.md                              # Documentation index
│   ├── subdivided_analysis_workflow.md        # Workflow details
│   ├── function_io_reference.md               # Function reference
│   ├── critical_code_decisions.md             # Design decisions
│   └── data_flow_diagram.md                   # Data flow visualization
│
├── outputs/                                    # Analysis outputs
│   └── enhanced_v2_*/                         # Timestamped results
│
└── archived/                                   # Historical files
    ├── 2025_01_cleanup/                       # Recent cleanup
    │   ├── README.md                          # Archive documentation
    │   ├── analysis_v1/                       # Previous versions
    │   ├── debug_tests/                       # Debug scripts
    │   ├── analysis_scripts/                  # Analysis utilities
    │   ├── tests/                             # Test files
    │   ├── verification/                      # Verification scripts
    │   ├── utilities/                         # Helper scripts
    │   ├── comparisons/                       # Comparison scripts
    │   └── old_docs/                          # Outdated documentation
    └── archived_outputs/                       # Historical outputs
```

## Key Production Files

1. **Entry Point**: `run_all_examples.jl`
2. **Main Implementation**: `examples/degree_convergence_analysis_enhanced_v2.jl`
3. **Core Utilities**: `shared/Common4DDeuflhard.jl`, `shared/SubdomainManagement.jl`
4. **Reference Data**: `points_deufl/4d_min_min_domain.csv`

## Cleanup Statistics

- **Before**: 51+ Julia files, 35+ markdown files
- **After**: 1 main Julia file, 5 documentation files
- **Archived**: ~70+ files organized by category
- **Reduction**: ~85% fewer files in main directory

The cleanup preserves all development history while maintaining a clear, production-ready structure.