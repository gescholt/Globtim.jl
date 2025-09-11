# Cluster Report Generator

Simple tool for generating automated reports from HPC cluster computation outputs.

## Quick Start

```bash
# Generate report for JSON results
julia scripts/simple_cluster_report.jl 4d_results

# Generate report for specific job
julia scripts/simple_cluster_report.jl job_59780294

# Generate report for all jobs from a date
julia scripts/simple_cluster_report.jl 20250809
```

## Features

- **Incremental**: Start with basic reports, build on top
- **Automated**: Takes tag/identifier, automatically finds and processes outputs
- **Test-first**: Built incrementally with testing at each step
- **Minimal new code**: Leverages existing post-processing infrastructure
- **Multiple patterns**: Handles JSON files, job directories, date-based searches

## Output Types

### JSON File Analysis
For files like `4d_results.json`:
- Dimensional analysis (4D, degree 8)
- L2 norm quality assessment (Poor/Good/Excellent)
- Condition number stability analysis
- Sample/monomial ratio efficiency
- Parameter information (center, range)

### Job Directory Analysis  
For job directories like `job_59780294_20250809_142058`:
- Job status and duration
- Exit codes and completion status
- File inventory with sizes
- Automatic analysis of any computational result JSON files

### Batch Analysis
For date/pattern searches like `20250809`:
- Multiple job overview
- Success/failure summary across jobs
- Quick identification of completed vs failed experiments

## Usage Examples

### Individual Result Analysis
```bash
julia scripts/simple_cluster_report.jl 4d_results
```
Output:
```
📐 Dimension: 4
📊 Degree: 8  
📈 L2 Norm: 1.07e-02 (log₁₀: -1.97)
⚠️  Quality: 🔴 POOR
🧮 Condition Number: 1.60e+01
✅ Stability: 🟢 GOOD
⚖️  Sample/Monomial Ratio: 0.024
⚠️  Sampling: 🔴 UNDERDETERMINED (insufficient samples)
```

### Job Status Check
```bash
julia scripts/simple_cluster_report.jl job_59780294
```
Output:
```
## Job Status
- Job ID: 59780294
- Status: COMPLETED
- Exit Code: 0:0
- Duration: 00:00:05

## Available Files
- function_evaluation_results.csv (0.5 KB)
- function_evaluation_summary.txt (0.9 KB)
- test_function_evaluation.jl (3.5 KB)
```

### Batch Overview
```bash
julia scripts/simple_cluster_report.jl 20250809
```
Shows status for 16 jobs from that date, with quick overview of which completed vs failed.

## Supported Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| File name | Direct JSON result files | `4d_results` |
| Job ID | Specific job directories | `job_59780294` |
| Date | All jobs from specific date | `20250809` |
| Partial match | Any substring match | `deuflhard` |

## Integration

### In Julia Scripts
```julia
# Add to end of computation
run(`julia scripts/simple_cluster_report.jl my_experiment_results`)
```

### In Shell Scripts
```bash
#!/bin/bash
# Run computation
julia my_experiment.jl

# Generate report
julia scripts/simple_cluster_report.jl $(basename $PWD)
```

### As Make Target
```makefile
report:
	julia scripts/simple_cluster_report.jl $(TAG)
```

## File Structure

The tool searches in:
- Current directory (`./`)
- `collected_results/`
- `hpc/jobs/submission/collected_results/`

And recognizes:
- Direct JSON files (`tag.json`)
- Job directories (`job_<id>_<date>_<time>`)
- Any directory containing the tag

## Quality Classifications

| L2 Norm | Quality | Emoji |
|---------|---------|-------|
| < 1e-10 | Excellent | 🟢 |
| < 1e-6 | Good | 🟡 |
| < 1e-3 | Acceptable | 🟠 |
| > 1e-3 | Poor | 🔴 |

| Condition Number | Stability | Emoji |
|------------------|-----------|-------|
| < 1e8 | Good | 🟢 |
| < 1e12 | Moderate | 🟠 |
| > 1e12 | Poor | 🔴 |

| Sample Ratio | Sampling | Emoji |
|--------------|----------|-------|
| > 2.0 | Well-conditioned | 🟢 |
| > 1.0 | Marginal | 🟠 |
| < 1.0 | Underdetermined | 🔴 |

## Incremental Enhancement

This tool is designed for incremental improvement:

1. **Phase 1** ✅: Basic tag-based report generation
2. **Phase 2** (future): Add visualization support
3. **Phase 3** (future): Statistical comparisons across experiments  
4. **Phase 4** (future): Integration with existing post-processing dashboard

The minimal approach allows testing and validation at each step while building on the comprehensive post-processing infrastructure already implemented.