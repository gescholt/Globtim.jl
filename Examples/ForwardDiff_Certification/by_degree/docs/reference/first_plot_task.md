

# First Plot Task - COMPLETED

## Original Plan
Get rid of adaptive algorithm and focus on the basic polynomial construction and analysis.
We only need one type of behavior for constructing the approximant:

Once we have divided the domain into 16 subdomains, we use the same number of samples `GN` for each subdomain and each degree `d`.
We increase the degree through the whole range of degrees specified on every sub-domain.
For each subdomain, we record the estimated L²-norm of the approximation error as degree increases.
This would give us 16 individual L2-norm convergence plots; we expect them to converge in similar ways. Hence we display them all in one plot, and one color (make it slightly transparent red), in a different color and on the right y-axis, we display the L²-norm of the approximants constructed on the full domain.

In Histograms, for the distances to points: We only care about convergence to local minimizers. (those 4d points we have constructed in the first step). So we could do a histogram by degree where we have bars colored with two colors --> the height of the bar in the number of local minimizers BFGS has converged to, and the contained bar of a different color (which is always smaller) is the number of these local minimizers who are less than the tolerance away from one of the actual critical points of the approximant.

Another mutliplot would be the plot of minimal distance to from all local minimizers to the critical points of the approximant, as a function of degree. This should also converge to zero.
We could also display multiple lines in one plot, one for each subdomain, and one for the full domain.

## Implementation Status - UPDATED

### Completed:
1. **L²-norm Convergence Plot**: 
   - Shows 16 semi-transparent red curves for subdomains
   - Blue curve for full domain
   - Green dashed line for tolerance threshold
   - All curves on the same y-axis (log scale)

2. **Minimizer Separation Distance Plot**:
   - **NEW APPROACH**: Instead of individual subdomain curves, now shows average separation distance
   - Computes distance from all 9 theoretical minimizers to ALL critical points across ALL 16 subdomains
   - Shows average with error bars and min-max envelope
   - More meaningful metric for global convergence behavior

### Changes from Original Plan:
- **Histogram plot**: Removed per user request
- **Distance plot**: Changed from per-subdomain distances to average separation distance approach
- **Visualization**: Simplified to show only the two most important plots

### Current Implementation:
- File: `simplified_subdomain_analysis_new_distance.jl`
- Runner: `run_all_examples.jl`
- Key functions:
  - `collect_all_critical_points_for_degree()`: Gathers all critical points from 16 subdomains
  - `compute_minimizer_separation_distances()`: Computes average separation from 9 minimizers
  - `plot_minimizer_separation_convergence()`: Creates the new simplified visualization
