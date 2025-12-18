# Legendre vs Chebyshev Basis Comparison

## Overview

This campaign tests Legendre polynomial basis as an alternative to Chebyshev for the Lotka-Volterra 4D extended degree experiments (degrees 4-18).

## Experiment Configuration

### Common Parameters
- **Domain**: ±0.3 around equilibrium point
- **GN (samples/dim)**: 16
- **Degree range**: 4-18
- **True parameters**: [0.2, 0.3, 0.5, 0.6]
- **Model**: Lotka-Volterra 4D (define_daisy_ex3_model_4D)

### Experiments

1. **Chebyshev Basis** (baseline)
   - Session: `lv4d_deg18_domain03`
   - Script: `launch_deg18_experiment.jl`
   - Launcher: `launch_deg18_campaign.sh`
   - Results: `hpc_results/lv4d_deg18_domain0.3_GN16_*`

2. **Legendre Basis** (comparison)
   - Session: `lv4d_deg18_legendre_domain03`
   - Script: `launch_deg18_legendre_experiment.jl`
   - Launcher: `launch_deg18_legendre_campaign.sh`
   - Results: `hpc_results/lv4d_deg18_legendre_domain0.3_GN16_*`

## Theoretical Differences

### Chebyshev Polynomials
- **Weight function**: w(x) = 1/√(1-x²)
- **Nodes**: Extrema of T_n(x) at cos(kπ/n)
- **Properties**:
  - Minimax property: minimize maximum interpolation error
  - Non-uniform node distribution (clustered at boundaries)
  - Often better for approximating smooth functions
  - Standard choice in many numerical methods

### Legendre Polynomials
- **Weight function**: w(x) = 1 (uniform)
- **Nodes**: Roots of P_n(x)
- **Properties**:
  - Orthogonal with uniform weight on [-1,1]
  - More uniform node distribution
  - May have better conditioning for some problems
  - Standard in Gauss-Legendre quadrature

## Expected Outcomes

### Metrics for Comparison

1. **Approximation Quality**
   - L2 norm convergence as degree increases
   - Compare: `results_summary.json` → `L2_norm` field

2. **Numerical Conditioning**
   - Condition number of Vandermonde matrix
   - Compare: `results_summary.json` → `condition_number` field

3. **Critical Points**
   - Number and quality of critical points found
   - Compare: `critical_points_deg_*.csv` files
   - Best objective values at each degree

4. **Computation Time**
   - Time per degree
   - Compare: `results_summary.json` → `computation_time` field

## Running the Experiments

### Recommended: Standardized Infrastructure

The Legendre experiment uses the `launch_experiments.jl` tool for consistent output tracking.

#### Launch Legendre Experiment on HPC
```bash
cd /Users/ghscholt/GlobalOptim/globtimcore

# Method 1: Using the wrapper script
./experiments/lv4d_campaign_2025/launch_legendre_deg18_standardized.sh

# Method 2: Direct call to standardized tool
julia --project=. tools/launch_experiments.jl \
    --config experiments/lv4d_campaign_2025/configs_legendre_deg18/master_config.json \
    --target hpc \
    --hpc-host r04n02 \
    --hpc-user scholten
```

### Local Small Test (deg 4-6)
```bash
# Test Legendre locally with reduced parameters
julia --project=. experiments/lv4d_campaign_2025/launch_legendre_test.jl
```

### Note on Chebyshev Baseline
The Chebyshev experiment is already running using the simple bash script approach.
Both methods produce compatible outputs for comparison.

## Monitoring Progress

### Check Active Sessions
```bash
ssh scholten@r04n02 'tmux list-sessions'
```

### Attach to Sessions
```bash
# Chebyshev
ssh scholten@r04n02 -t 'tmux attach -t lv4d_deg18_domain03'

# Legendre
ssh scholten@r04n02 -t 'tmux attach -t lv4d_deg18_legendre_domain03'
```

### Check Latest Output
```bash
# Chebyshev
ssh scholten@r04n02 'tmux capture-pane -t lv4d_deg18_domain03 -p | tail -30'

# Legendre
ssh scholten@r04n02 'tmux capture-pane -t lv4d_deg18_legendre_domain03 -p | tail -30'
```

## Analysis After Completion

### Collect Results
```bash
# Use Julia infrastructure
cd /Users/ghscholt/GlobalOptim/globtimcore
julia --project=. scripts/analysis/collect_cluster_experiments.jl
```

### Compare Results
The comparison analysis should examine:

1. **Convergence Behavior**
   ```julia
   # Load both experiments
   cheb_results = JSON.parsefile("hpc_results/lv4d_deg18_domain0.3_GN16_*/results_summary.json")
   leg_results = JSON.parsefile("hpc_results/lv4d_deg18_legendre_domain0.3_GN16_*/results_summary.json")

   # Compare L2 norms
   cheb_l2 = [r["L2_norm"] for r in cheb_results]
   leg_l2 = [r["L2_norm"] for r in leg_results]
   ```

2. **Conditioning Comparison**
   ```julia
   cheb_cond = [r["condition_number"] for r in cheb_results]
   leg_cond = [r["condition_number"] for r in leg_results]
   ```

3. **Critical Points Quality**
   - Compare best objective values found
   - Check if different bases find different local minima

## Key Questions

1. **Does Legendre achieve better L2 convergence?**
   - Look for lower L2 norms at high degrees

2. **Does Legendre have better conditioning?**
   - Compare condition numbers, especially at high degrees

3. **Does the basis choice affect critical point discovery?**
   - Different polynomial systems may have different real roots

4. **Is there a computational cost difference?**
   - Compare total computation times

## Files Created

- `launch_legendre_test.jl` - Small local test (deg 4-6, GN=8)
- `launch_deg18_legendre_experiment.jl` - Full experiment (deg 4-18, GN=16)
- `launch_deg18_legendre_campaign.sh` - HPC launcher script
- `LEGENDRE_VS_CHEBYSHEV.md` - This documentation

## Notes

- Both experiments use identical parameters except for the `basis` field
- All configuration is saved in `experiment_config.json` for reproducibility
- Results are directly comparable due to matched experimental design
- Small test verified Legendre basis works correctly with all pipeline components
