# Data Flow Diagram: Subdivided Analysis

## Overview
This diagram shows how data flows through the subdivided analysis pipeline, from initial domain setup to final visualizations.

```
┌─────────────────────────────────────────────────────────────────┐
│                     INITIALIZATION PHASE                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  Domain: (+,-,+,-) orthant [0,1]×[-1,0]×[0,1]×[-1,0]          │
│  Function: deuflhard_4d_composite                               │
│  Degrees: [2, 3, 4, 5, 6]                                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│           generate_16_subdivisions_orthant()                    │
├─────────────────────────────────────────────────────────────────┤
│  Creates 16 Subdomain objects:                                 │
│  - Label: "0000" to "1111" (4-bit strings)                     │
│  - Center: e.g., [0.25, -0.75, 0.25, -0.75]                   │
│  - Range: 0.25 (constant for all)                              │
│  - Bounds: [(min₁,max₁), ..., (min₄,max₄)]                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────────┐
│   THEORETICAL POINTS FLOW   │ │      ANALYSIS LOOP              │
└─────────────────────────────┘ └─────────────────────────────────┘
                │                               │
                ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────────┐
│ load_2d_critical_points_    │ │  For each degree in [2,3,4,5,6]:│
│        orthant()            │ │    For each subdomain:          │
├─────────────────────────────┤ │      - Load theoretical points  │
│ Input: CSV file             │ │      - Run analyze_single_degree│
│ Output:                     │ │      - Store result             │
│ - points_2d: [[x,y],...]    │ └─────────────────────────────────┘
│ - types_2d: ["min",...]     │                 │
└─────────────────────────────┘                 ▼
                │               ┌─────────────────────────────────┐
                ▼               │    analyze_single_degree()      │
┌─────────────────────────────┐ ├─────────────────────────────────┤
│ generate_4d_tensor_products_│ │ Inputs:                         │
│        orthant()            │ │ - f: Function                   │
├─────────────────────────────┤ │ - degree: Int                   │
│ Creates 9 4D points:        │ │ - center: [x₁,x₂,x₃,x₄]        │
│ - 1 min+min                 │ │ - range: 0.25                   │
│ - 2 min+saddle              │ │ - theoretical_points            │
│ - 2 saddle+min              │ │ - theoretical_types             │
│ - 4 saddle+saddle           │ ├─────────────────────────────────┤
└─────────────────────────────┘ │ Process:                        │
                │               │ 1. Construct polynomial         │
                ▼               │ 2. Solve for critical points    │
┌─────────────────────────────┐ │ 3. Classify via Hessian         │
│ load_theoretical_points_for_│ │ 4. Match to theoretical         │
│    subdomain_orthant()      │ │ 5. Compute L²-norm              │
├─────────────────────────────┤ ├─────────────────────────────────┤
│ Filters points by bounds:   │ │ Output: DegreeAnalysisResult    │
│ - Subdomain 1010: 9 points  │ └─────────────────────────────────┘
│ - Other subdomains: 0 points│                 │
└─────────────────────────────┘                 ▼
                                ┌─────────────────────────────────┐
                                │        STORAGE STRUCTURE        │
                                ├─────────────────────────────────┤
                                │ all_results[degree][subdomain]  │
                                │   = DegreeAnalysisResult        │
                                └─────────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATA REORGANIZATION PHASE                     │
└─────────────────────────────────────────────────────────────────┘
                                                │
                                                ▼
                ┌───────────────────────────────────────────────┐
                │         Reorganize by Subdomain               │
                ├───────────────────────────────────────────────┤
                │ From: all_results[degree][subdomain]          │
                │ To:   combined_results[subdomain] = [...]     │
                │                                               │
                │ for (degree, degree_results) in all_results:  │
                │     for (label, result) in degree_results:    │
                │         push!(combined_results[label], result)│
                └───────────────────────────────────────────────┘
                                                │
                                                ▼
                ┌───────────────────────────────────────────────┐
                │          Convert to Enhanced Format           │
                ├───────────────────────────────────────────────┤
                │ For each result:                              │
                │ - Add subdomain_label                         │
                │ - Calculate min_min_distances                 │
                │ - Determine capture_methods                   │
                │ - Compute aggregate statistics                │
                │                                               │
                │ enhanced_results[subdomain] =                 │
                │   [EnhancedDegreeAnalysisResult, ...]         │
                └───────────────────────────────────────────────┘
                                                │
                ┌───────────────────────┬───────┴────────┬──────────────┐
                ▼                       ▼                ▼              ▼
┌─────────────────────────┐ ┌──────────────────┐ ┌─────────────┐ ┌──────────┐
│ plot_l2_convergence_    │ │ plot_critical_   │ │ plot_min_   │ │ CSV      │
│    dual_scale()         │ │ point_recovery_  │ │ min_        │ │ Export   │
├─────────────────────────┤ │   histogram()    │ │ distances() │ ├──────────┤
│ Shows:                  │ ├──────────────────┤ ├─────────────┤ │ Columns: │
│ - Left: Subdomain L²    │ │ 3-layer bars:    │ │ Only shows  │ │ - degree │
│ - Right: Full domain L² │ │ - Min+min found  │ │ subdomain   │ │ - label  │
│ - Pattern of convergence│ │ - Other found    │ │ 1010 data   │ │ - l2_norm│
└─────────────────────────┘ │ - Not found      │ └─────────────┘ │ - ...    │
                            └──────────────────┘                  └──────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         KEY INSIGHTS                             │
├─────────────────────────────────────────────────────────────────┤
│ 1. All 9 theoretical points fall in subdomain "1010"            │
│ 2. Other 15 subdomains analyzed for L²-norm only               │
│ 3. Data must be reorganized from degree-first to                │
│    subdomain-first for plotting                                 │
│ 4. Enhanced format adds metrics for sophisticated plots         │
└─────────────────────────────────────────────────────────────────┘
```

## Data Structure Evolution

### Stage 1: Raw Results
```
all_results = {
    2: {"0000": result, "0001": result, ..., "1111": result},
    3: {"0000": result, "0001": result, ..., "1111": result},
    ...
}
```

### Stage 2: Reorganized by Subdomain
```
combined_results = {
    "0000": [result_deg2, result_deg3, ...],
    "0001": [result_deg2, result_deg3, ...],
    ...
}
```

### Stage 3: Enhanced Format
```
enhanced_results = {
    "0000": [enhanced_deg2, enhanced_deg3, ...],
    "0001": [enhanced_deg2, enhanced_deg3, ...],
    ...
}
```

## Critical Data Points

- **Input**: 16 subdomains × 5 degrees = 80 analyses
- **Theoretical points**: 9 total, all in subdomain "1010"
- **Output plots**: 4 types (L²-norm, recovery, min+min, capture)
- **CSV rows**: 80 (one per degree/subdomain combination)