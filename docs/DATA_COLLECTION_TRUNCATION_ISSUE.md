# Data Collection Truncation Issue - October 2025

## Problem Summary

JSON output files (`results_summary.json`) from HPC experiments are being truncated during write operations, resulting in invalid JSON that cannot be parsed or loaded for post-processing.

## Affected Campaigns

### Confirmed Truncated (Invalid JSON)
1. **configs_20251006_160051/** (October 6, 2025) - **ALL 4 experiments truncated**
   - `lotka_volterra_4d_exp1_range0.4_20251006_160126/results_summary.json` ✗
   - `lotka_volterra_4d_exp2_range0.8_20251006_225802/results_summary.json` ✗
   - `lotka_volterra_4d_exp3_range1.2_20251006_225820/results_summary.json` ✗
   - `lotka_volterra_4d_exp4_range1.6_20251006_230001/results_summary.json` ✗

2. **configs_20250915_224434/** (September 15-16, 2025) - **ALL 4 experiments truncated**
   - `lotka_volterra_4d_exp1_range0.05_20250916_201933/results_summary.json` ✗
   - `lotka_volterra_4d_exp2_range0.1_20250916_201944/results_summary.json` ✗
   - `lotka_volterra_4d_exp3_range0.15_20250916_201953/results_summary.json` ✗
   - `lotka_volterra_4d_exp4_range0.2_20250916_202003/results_summary.json` ✗

### Valid JSON But Failed Experiments
3. **configs_20251005_105246/** (October 5, 2025) - **Valid JSON, but all experiments failed**
   - All 8 `results_summary.json` files are valid JSON ✓
   - However, ALL experiments failed with error: `ArgumentError("column name :val not found in the data frame")`
   - This is a different issue - structural problem, not truncation

## Truncation Pattern

Truncated files show consistent pattern:
```json
[
  {
    "worst_value": 38848.351868500475,
    "condition_number": 15.999999999999991,
    "computation_time": 59.47236204147339,
    "mean_value": 38848.351868500475,
    "critical_points": 1,
    "best_value": 38848.351868500475,
    "L2_norm": 40559.817085218136,
    "total_solutions": {
      "expressions": [
        {
          "ptr":
```

File ends abruptly mid-field, indicating write interruption or serialization failure.

## File Size Analysis

All truncated `results_summary.json` files are only **12 lines** long, while valid ones vary by degree complexity.

## Root Cause Hypotheses

### 1. Non-Serializable Objects in Summary Dict
The `total_solutions` field contains `expressions` with a `ptr` field. This strongly suggests:
- **HomotopyContinuation.jl** solution objects being included directly
- Pointer fields (`ptr`) cannot be serialized to JSON
- JSON3.pretty() likely fails when encountering these objects

### 2. Code Location
The write operation occurs in `globtimcore/src/StandardExperiment.jl:514-519`:
```julia
function save_experiment_summary(summary::Dict, output_dir::String)
    # Save JSON (human readable)
    json_path = joinpath(output_dir, "results_summary.json")
    open(json_path, "w") do f
        JSON3.pretty(f, summary)
    end
    # ...
end
```

### 3. Why Partial Write?
- JSON3.pretty() likely throws exception when encountering non-serializable type
- Exception occurs mid-write, leaving partial file
- Error may be silently caught or logged elsewhere
- File handle closes, preserving partial content

## Impact on Post-Processing

This truncation completely blocks the plotting/analysis pipeline:
1. `GlobtimPostProcessing.load_campaign_results()` cannot parse the JSON
2. All downstream analysis fails
3. No visualization possible for affected campaigns
4. Data from experiments is essentially lost

## Recommended Solution

### Immediate Fix
1. **Remove non-serializable objects from summary dict** before JSON write
2. **Add explicit error handling** around JSON3.pretty() call
3. **Add validation** after write to ensure file is complete and parseable
4. **Log errors** explicitly instead of silent failures

### Code Changes Needed in StandardExperiment.jl

```julia
function save_experiment_summary(summary::Dict, output_dir::String)
    # Remove non-serializable fields (HomotopyContinuation solution objects)
    summary_clean = sanitize_for_json(summary)

    # Save JSON (human readable)
    json_path = joinpath(output_dir, "results_summary.json")
    try
        open(json_path, "w") do f
            JSON3.pretty(f, summary_clean)
        end

        # Validate written file
        JSON3.read(read(json_path, String))
        println("✓ JSON validated: $json_path")
    catch e
        error("Failed to write valid JSON to $json_path: $e")
    end

    # Save JLD2 with Git provenance (can contain full objects)
    jld2_path = joinpath(output_dir, "results_summary.jld2")
    tagsave(jld2_path, summary)  # Original summary with all objects

    println("💾 Results saved:")
    println("   ├─ $json_path")
    println("   └─ $jld2_path (with Git provenance)")
end

function sanitize_for_json(d::Dict)
    # Recursively remove HomotopyContinuation solution objects
    # and other non-serializable types
    result = Dict{String, Any}()
    for (k, v) in d
        if k == "total_solutions" || k == "expressions"
            # Skip HomotopyContinuation solution objects
            continue
        elseif v isa Dict
            result[k] = sanitize_for_json(v)
        elseif v isa Vector && !isempty(v) && v[1] isa Dict
            result[k] = [sanitize_for_json(x) for x in v]
        else
            result[k] = v
        end
    end
    return result
end
```

## Action Items

- [ ] Fix StandardExperiment.jl to sanitize summary dict before JSON write
- [ ] Add validation after JSON write
- [ ] Add explicit error logging
- [ ] Re-run October 6 campaign experiments
- [ ] Re-run September 15 campaign experiments
- [ ] Verify fix with test campaign
- [ ] Update post-processing to handle both old (broken) and new (fixed) formats

## Priority

**CRITICAL** - This blocks all post-processing and visualization of experiment results.

---

*Documented: 2025-10-07*
*Analysis performed by: Claude Code investigation*
*Related Issues: Need to investigate why Oct 5 campaign has :val column errors*
