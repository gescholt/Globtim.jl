# Recovery Rate Plot Improvements

## Changes Made

### 1. Single Domain Recovery Rates (`plot_recovery_rates`)
- **Added legend** with clear labels:
  - Blue line: "All Critical Points"
  - Red line: "Min+Min Points Only"  
  - Gray dashed line: "90% Target"
- Legend positioned at bottom-right with frame
- Plot title is displayed at top of axis

### 2. Subdivision Recovery Rates (`plot_subdivision_recovery_rates`)
- **Split into two subplots** for clarity:
  - Top subplot: "All Critical Points Recovery"
  - Bottom subplot: "Min+Min Points Only Recovery"
- **Added informative text** on each subplot:
  - Shows number of subdomains being plotted
  - Clarifies that lines are overlapping (e.g., "16 subdomains (blue lines overlapping)")
- Each subplot has its own title explaining what's being shown
- 90% target reference line on both subplots

### 3. L2-Norm Convergence for Subdivisions (`plot_subdivision_convergence`)
- **Fixed disconnected nodes issue**:
  - Results are now sorted by degree before plotting
  - Uses `lines!` for connected trajectories + `scatter!` for visible points
- **Added 16 distinct colors** for each subdomain
- Each subdomain trajectory is now clearly connected and distinguishable
- Tolerance reference line labeled as "L² Tolerance"

## Visual Clarity Improvements

1. **Color Usage**:
   - Single domain: Blue (all points), Red (min+min), Gray (reference)
   - Subdivisions: 16 distinct colors from a distinguishable color palette
   
2. **Text Annotations**:
   - Subplot titles clearly state what's being measured
   - Annotations show how many subdomains are plotted
   - Y-axis always labeled as "Success Rate (%)"

3. **Legend Positioning**:
   - Single domain plots have traditional legend at bottom-right
   - Subdivision plots use titles and text annotations instead of legends (due to many overlapping lines)

## Usage Notes

The plots now clearly distinguish between:
- **Whole domain analysis**: Single trajectory with legend
- **Subdivision analysis**: Multiple overlapping trajectories with informative titles and annotations

This makes it immediately clear whether you're looking at a single domain result or a comparison across multiple subdomains.