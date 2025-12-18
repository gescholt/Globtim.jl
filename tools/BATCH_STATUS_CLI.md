# BatchManifest CLI Tools - check_batch_status.jl

Command-line tool for monitoring batch experiment progress and validating completeness.

---

## Quick Start

```bash
cd globtimcore

# Basic usage - check batch status
julia tools/check_batch_status.jl \
  --batch-dir experiments/lotka_volterra_4d_study/configs_20251009_153009

# Verbose mode - show detailed experiment info
julia tools/check_batch_status.jl \
  --batch-dir experiments/lotka_volterra_4d_study/configs_20251009_153009 \
  --verbose

# Explicit results directory
julia tools/check_batch_status.jl \
  --batch-dir experiments/lotka_volterra_4d_study/configs_20251009_153009 \
  --results-dir hpc_results \
  --verbose --show-errors
```

---

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--batch-dir DIR` | `-b` | Path to batch directory containing `batch_manifest.json` (required) |
| `--results-dir DIR` | `-r` | Path to results directory (default: auto-detect) |
| `--verbose` | `-v` | Show detailed experiment status |
| `--show-errors` | | Show detailed error information |
| `--help` | `-h` | Show help message |

---

## Exit Codes

- `0` - Batch is complete, all experiments successful
- `1` - Batch is incomplete or has errors

---

## Output Examples

### Summary View (Default)

```
================================================================================
BATCH STATUS SUMMARY
================================================================================
Batch ID: lv4d_20251009_153010
Batch Status: RUNNING
Created: 2025-10-09T15:30:10.415

Experiments: 4
  ✓ Completed: 4
  ⏳ Running: 0
  ⏸  Pending: 0
  ✗ Failed: 0
================================================================================

VALIDATION RESULTS:
--------------------------------------------------------------------------------
Total Experiments: 4
Complete Experiments: 4
Batch Complete: YES ✓
--------------------------------------------------------------------------------

✓ No errors detected

✅ Batch lv4d_20251009_153010 is COMPLETE
```

### Verbose Mode (`--verbose`)

Adds detailed information for each experiment:

```
EXPERIMENT DETAILS:
--------------------------------------------------------------------------------
✓ exp_1 [COMPLETED]
  Script: lotka_volterra_4d_exp1.jl
  Config: experiment_1_config.json
  Started: 2025-10-09T15:34:20.073
  Ended: 2025-10-09T15:45:12.456
  Duration: 652383 milliseconds

⏳ exp_2 [RUNNING]
  Script: lotka_volterra_4d_exp2.jl
  Config: experiment_2_config.json
  Started: 2025-10-09T15:34:20.237
  Elapsed: 1234567 milliseconds

✗ exp_3 [FAILED]
  Script: lotka_volterra_4d_exp3.jl
  Config: experiment_3_config.json
  Error: Optimization failed to converge
```

### Error Report (`--show-errors`)

```
ERROR REPORT:
--------------------------------------------------------------------------------
Found 2 error(s):

✗ exp_3
  Type: optimization_failure
  Message: Failed to find critical point within max_time
  Detected: 2025-10-09T15:38:45.123
  Degree at failure: 12

✗ exp_5
  Type: missing_output
  Message: Results file not found
  Detected: 2025-10-09T16:00:00.000
--------------------------------------------------------------------------------
```

---

## Pattern-Based Directory Discovery

The tool automatically handles dynamic timestamp patterns in experiment directories.

**Example:**

Manifest specifies:
```
lotka_volterra_4d_exp1_range0.4_{timestamp_placeholder}
```

Tool discovers actual directory:
```
lotka_volterra_4d_exp1_range0.4_20251009_153420
```

This enables validation even when exact directory names aren't known in advance.

---

## Use Cases

### 1. Monitor Running Batch

```bash
# Check progress periodically
watch -n 60 'julia tools/check_batch_status.jl -b experiments/my_batch -v'
```

### 2. Validate Completed Batch

```bash
julia tools/check_batch_status.jl \
  --batch-dir experiments/my_batch \
  --results-dir hpc_results

# Exit code indicates success/failure
if [ $? -eq 0 ]; then
  echo "Batch complete - ready for analysis"
else
  echo "Batch incomplete - review errors"
fi
```

### 3. CI/CD Integration

```bash
#!/bin/bash
# validate_batch.sh

BATCH_DIR=$1
RESULTS_DIR=${2:-"hpc_results"}

julia tools/check_batch_status.jl \
  --batch-dir "$BATCH_DIR" \
  --results-dir "$RESULTS_DIR" \
  --verbose --show-errors

exit $?
```

### 4. Debug Failed Experiments

```bash
julia tools/check_batch_status.jl \
  -b experiments/my_batch \
  -r hpc_results \
  --verbose --show-errors
```

---

## Troubleshooting

### Results Directory Not Found

**Problem:**
```
⚠️  Results directory not found: /path/to/results
```

**Solution:** Specify results directory explicitly:
```bash
julia tools/check_batch_status.jl -b experiments/my_batch -r hpc_results
```

### Pattern Not Matching

**Problem:** Validation shows 0 complete experiments despite files existing.

**Solution:** Check directory naming:
```bash
# List actual directories
ls hpc_results/

# Compare with manifest patterns
cat experiments/my_batch/batch_manifest.json | grep output_dir
```

### Batch Manifest Not Found

**Problem:**
```
ERROR: Batch manifest not found: /path/batch_manifest.json
```

**Solution:** Verify directory contains `batch_manifest.json`:
```bash
ls experiments/my_batch/
# Should contain: batch_manifest.json
```

---

## Integration Workflow

### 1. Create Batch
```julia
using BatchManifest
manifest = create_batch_manifest("my_batch", "parameter_sweep", configs)
save_batch_manifest(manifest, "experiments/my_batch")
```

### 2. Run Experiments
```bash
for exp in experiments/*.jl; do julia "$exp" & done
```

### 3. Monitor Progress
```bash
julia tools/check_batch_status.jl -b experiments/my_batch -v
```

### 4. Validate Completion
```bash
julia tools/check_batch_status.jl -b experiments/my_batch --show-errors
# Exit code 0 = success
```

---

## Related Documentation

- [Integration Test Results](../../INTEGRATION_TEST_RESULTS.md)
- [BatchManifest.jl Source](../src/BatchManifest.jl)
