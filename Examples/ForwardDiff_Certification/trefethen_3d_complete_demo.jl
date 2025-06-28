# Trefethen 3D Phase 2 Hessian Analysis Demo
# 
# This example demonstrates the enhanced Phase 2 Hessian classification
# features using the challenging 3D Trefethen function.

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))

# Force reload to avoid stale session issues
try
    # Try reloading if already loaded
    Base.reload("Globtim")
catch
    # If that fails, just continue with normal loading
end

using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using Statistics
using StaticArrays  # Required for SVector in LevelSetViz

# LevelSetViz functions are loaded through the GLMakie extension

# Explicitly import DataFrames functions to avoid conflicts
import DataFrames: combine, groupby

# Verify that tref_3d is available
if !isdefined(Main, :tref_3d)
    @warn "tref_3d not found in Main namespace, trying to access via Globtim module"
    f = Globtim.tref_3d
else
    f = tref_3d
end

# Optional visualization (comment out if not needed)
# using CairoMakie

println("=== Trefethen 3D Phase 2 Hessian Analysis Demo ===\n")

# Problem setup
const n, a, b = 3, 20, 100 
const scale_factor = a / b   # Scaling factor for domain
# f is already defined above with error handling

println("Function: tref_3d (3D challenging test function)")
println("Scale factor: $scale_factor")
println("Expected critical points: Multiple local minima and saddle points\n")

# Domain and approximation setup
center = [0.0, 0.0, 0.0]
d = 20  # Polynomial degree
SMPL = 30  # Number of samples per dimension

println("=== Phase 1: Polynomial Approximation ===")
TR = test_input(f, 
                dim=n,
                center=center,
                GN=SMPL, 
                sample_range=scale_factor, 
                degree_max=d+4)

println("Creating Chebyshev polynomial approximation...")
pol_cheb = Constructor(TR, d, basis=:chebyshev, verbose=true)

# Define polynomial variables and solve critical point system
@polyvar(x[1:n])

println("\n=== Solving Critical Point System ===")
println("Finding critical points using HomotopyContinuation.jl...")
pts_cheb = solve_polynomial_system(x, TR.dim, d, pol_cheb.coeffs; basis=:chebyshev)
df_raw = process_crit_pts(pts_cheb, f, TR)

println("Raw critical points found: $(nrow(df_raw))")
println("Function value range: [$(minimum(df_raw.z)), $(maximum(df_raw.z))]")

# Sort by function value for better analysis
sort!(df_raw, :z, rev=false)

println("\n=== Phase 2: Enhanced Analysis with Hessian Classification ===")
println("Performing comprehensive critical point analysis...")
println("This includes:")
println("  • BFGS refinement")
println("  • Clustering and proximity analysis") 
println("  • Hessian matrix computation")
println("  • Eigenvalue decomposition and classification")
println("  • Statistical analysis")

# Perform enhanced analysis with Phase 2 Hessian features
df_enhanced, df_min = analyze_critical_points(
    f, df_raw, TR,
    enable_hessian=true,
    hessian_tol_zero=1e-8,
    tol_dist=0.025,
    verbose=true
)

println("\n=== Analysis Results ===")
println("Enhanced DataFrame dimensions: $(size(df_enhanced))")
println("Available columns: $(length(names(df_enhanced)))")
println("Unique minimizers found: $(nrow(df_min))")

# Phase 1 Statistics
println("\n--- Phase 1 Enhanced Statistics ---")
println("Converged points: $(sum(df_enhanced.converged))/$(nrow(df_enhanced)) ($(round(100*mean(df_enhanced.converged), digits=1))%)")
println("Points close to boundary: $(sum(df_enhanced.close))")
println("Unique spatial regions: $(length(unique(df_enhanced.region_id)))")
println("Function value clusters: $(length(unique(df_enhanced.function_value_cluster)))")

# Gradient analysis
valid_gradients = filter(!isnan, df_enhanced.gradient_norm)
println("Gradient norm statistics:")
println("  • Mean: $(round(mean(valid_gradients), digits=6))")
println("  • Std:  $(round(std(valid_gradients), digits=6))")
println("  • Max:  $(round(maximum(valid_gradients), digits=6))")

# Phase 2 Hessian Classification Results
println("\n--- Phase 2 Hessian Classification ---")
classification_counts = combine(groupby(df_enhanced, :critical_point_type), nrow => :count)
println("Critical point classification:")
for row in eachrow(classification_counts)
    percentage = round(100 * row.count / nrow(df_enhanced), digits=1)
    println("  • $(row.critical_point_type): $(row.count) points ($(percentage)%)")
end

# Detailed analysis by type
println("\n--- Detailed Analysis by Critical Point Type ---")

# Minima analysis
minima_mask = df_enhanced.critical_point_type .== :minimum
if any(minima_mask)
    minima_count = sum(minima_mask)
    println("\nLOCAL MINIMA ANALYSIS ($minima_count points):")
    
    # Function values at minima
    minima_values = df_enhanced.z[minima_mask]
    println("  Function value range: [$(round(minimum(minima_values), digits=4)), $(round(maximum(minima_values), digits=4))]")
    
    # Eigenvalue validation
    min_eigenvals = filter(!isnan, df_enhanced.smallest_positive_eigenval[minima_mask])
    if !isempty(min_eigenvals)
        println("  Smallest positive eigenvalues:")
        println("    • Mean: $(round(mean(min_eigenvals), digits=4))")
        println("    • Range: [$(round(minimum(min_eigenvals), digits=4)), $(round(maximum(min_eigenvals), digits=4))]")
    end
    
    # Hessian properties
    hessian_norms = filter(!isnan, df_enhanced.hessian_norm[minima_mask])
    condition_numbers = filter(!isnan, df_enhanced.hessian_condition_number[minima_mask])
    
    if !isempty(hessian_norms)
        println("  Hessian norms:")
        println("    • Mean: $(round(mean(hessian_norms), digits=2))")
        println("    • Range: [$(round(minimum(hessian_norms), digits=2)), $(round(maximum(hessian_norms), digits=2))]")
    end
    
    if !isempty(condition_numbers)
        well_conditioned = sum(condition_numbers .< 1e12)
        println("  Numerical stability:")
        println("    • Well-conditioned (κ < 1e12): $well_conditioned/$(length(condition_numbers)) ($(round(100*well_conditioned/length(condition_numbers), digits=1))%)")
        println("    • Condition number range: [$(round(minimum(condition_numbers), digits=1)), $(round(maximum(condition_numbers), sigdigits=3))]")
    end
end

# Saddle points analysis
saddle_mask = df_enhanced.critical_point_type .== :saddle
if any(saddle_mask)
    saddle_count = sum(saddle_mask)
    println("\nSADDLE POINTS ANALYSIS ($saddle_count points):")
    
    saddle_values = df_enhanced.z[saddle_mask]
    println("  Function value range: [$(round(minimum(saddle_values), digits=4)), $(round(maximum(saddle_values), digits=4))]")
    
    # Hessian properties for saddles
    saddle_norms = filter(!isnan, df_enhanced.hessian_norm[saddle_mask])
    saddle_conditions = filter(!isnan, df_enhanced.hessian_condition_number[saddle_mask])
    
    if !isempty(saddle_norms)
        println("  Hessian norm statistics:")
        println("    • Mean: $(round(mean(saddle_norms), digits=2))")
        println("    • Range: [$(round(minimum(saddle_norms), digits=2)), $(round(maximum(saddle_norms), digits=2))]")
    end
end

# Maxima analysis
maxima_mask = df_enhanced.critical_point_type .== :maximum
if any(maxima_mask)
    maxima_count = sum(maxima_mask)
    println("\nLOCAL MAXIMA ANALYSIS ($maxima_count points):")
    
    # Eigenvalue validation for maxima
    max_eigenvals = filter(!isnan, df_enhanced.largest_negative_eigenval[maxima_mask])
    if !isempty(max_eigenvals)
        println("  Largest negative eigenvalues:")
        println("    • Mean: $(round(mean(max_eigenvals), digits=4))")
        println("    • Range: [$(round(minimum(max_eigenvals), digits=4)), $(round(maximum(max_eigenvals), digits=4))]")
    end
end

# Error handling analysis
error_mask = df_enhanced.critical_point_type .== :error
if any(error_mask)
    error_count = sum(error_mask)
    println("\nERROR ANALYSIS ($error_count points):")
    println("  Points where Hessian computation failed")
    println("  This may indicate numerical instability or boundary effects")
end

# Global statistics
println("\n--- Global Hessian Statistics ---")
all_hessian_norms = filter(!isnan, df_enhanced.hessian_norm)
all_condition_numbers = filter(!isnan, df_enhanced.hessian_condition_number)
all_determinants = filter(!isnan, df_enhanced.hessian_determinant)

if !isempty(all_hessian_norms)
    println("Hessian norm distribution:")
    println("  • Mean ± Std: $(round(mean(all_hessian_norms), digits=2)) ± $(round(std(all_hessian_norms), digits=2))")
    println("  • Median: $(round(median(all_hessian_norms), digits=2))")
    println("  • Range: [$(round(minimum(all_hessian_norms), digits=2)), $(round(maximum(all_hessian_norms), digits=2))]")
end

if !isempty(all_condition_numbers)
    # Condition number quality assessment
    excellent = sum(all_condition_numbers .< 1e3)
    good = sum(1e3 .<= all_condition_numbers .< 1e6) 
    fair = sum(1e6 .<= all_condition_numbers .< 1e9)
    poor = sum(1e9 .<= all_condition_numbers .< 1e12)
    critical = sum(all_condition_numbers .>= 1e12)
    
    println("Condition number quality breakdown:")
    println("  • Excellent (< 1e3):     $excellent ($(round(100*excellent/length(all_condition_numbers), digits=1))%)")
    println("  • Good (1e3-1e6):        $good ($(round(100*good/length(all_condition_numbers), digits=1))%)")
    println("  • Fair (1e6-1e9):        $fair ($(round(100*fair/length(all_condition_numbers), digits=1))%)")
    println("  • Poor (1e9-1e12):       $poor ($(round(100*poor/length(all_condition_numbers), digits=1))%)")
    println("  • Critical (≥ 1e12):     $critical ($(round(100*critical/length(all_condition_numbers), digits=1))%)")
end

# Minimizer analysis
if nrow(df_min) > 0
    println("\n=== Unique Minimizers Analysis ===")
    println("Number of unique local minimizers: $(nrow(df_min))")
    println("Global minimum value: $(round(minimum(df_min.value), digits=6))")
    
    # Sort minimizers by function value
    sort!(df_min, :value)
    println("Top 5 minimizers (by function value):")
    for i in 1:min(5, nrow(df_min))
        coords = [round(df_min[i, Symbol("x$j")], digits=4) for j in 1:n]
        value = round(df_min[i, :value], digits=6)
        captured = df_min[i, :captured] ? "✓" : "✗"
        println("  $i. f($(coords)) = $value (captured: $captured)")
    end
    
    # Basin analysis
    if :basin_points in names(df_min)
        total_basin_points = sum(df_min.basin_points)
        println("Basin of attraction analysis:")
        println("  • Total points in basins: $total_basin_points")
        println("  • Average basin size: $(round(mean(df_min.basin_points), digits=1))")
        println("  • Largest basin: $(maximum(df_min.basin_points))")
    end
end

# Eigenvalue Distribution Analysis
println("\n=== Eigenvalue Distribution Analysis ===")

# Function to extract all eigenvalues for a given critical point type
function extract_all_eigenvalues(df, point_type)
    mask = df.critical_point_type .== point_type
    if !any(mask)
        return Float64[]
    end
    
    eigenvalues = Float64[]
    for i in findall(mask)
        # Extract min and max eigenvalues (we don't store individual eigenvalues)
        min_eig = df.hessian_eigenvalue_min[i]
        max_eig = df.hessian_eigenvalue_max[i]
        
        if !isnan(min_eig) && !isnan(max_eig)
            push!(eigenvalues, min_eig)
            push!(eigenvalues, max_eig)
            
            # For 3D problems, estimate the middle eigenvalue using trace
            # trace = λ₁ + λ₂ + λ₃, so λ₂ ≈ trace - λ₁ - λ₃
            trace_val = df.hessian_trace[i]
            if !isnan(trace_val)
                middle_eig = trace_val - min_eig - max_eig
                push!(eigenvalues, middle_eig)
            end
        end
    end
    return eigenvalues
end

# Function to create text-based histogram
function text_histogram(values, title, bins=10)
    if isempty(values)
        println("$title: No data available")
        return
    end
    
    println("$title:")
    println("  Count: $(length(values))")
    println("  Range: [$(round(minimum(values), digits=4)), $(round(maximum(values), digits=4))]")
    println("  Mean ± Std: $(round(mean(values), digits=4)) ± $(round(std(values), digits=4))")
    println("  Median: $(round(median(values), digits=4))")
    
    # Create histogram bins
    min_val, max_val = extrema(values)
    if min_val ≈ max_val
        println("  Distribution: All values approximately equal")
        return
    end
    
    bin_edges = range(min_val, max_val, length=bins+1)
    bin_counts = zeros(Int, bins)
    
    for val in values
        bin_idx = min(bins, max(1, floor(Int, (val - min_val) / (max_val - min_val) * bins) + 1))
        bin_counts[bin_idx] += 1
    end
    
    # Display histogram
    max_count = maximum(bin_counts)
    max_bar_length = 40
    
    println("  Histogram:")
    for i in 1:bins
        left_edge = bin_edges[i]
        right_edge = bin_edges[i+1]
        count = bin_counts[i]
        
        # Create bar visualization
        bar_length = max_count > 0 ? round(Int, count / max_count * max_bar_length) : 0
        bar = "█" ^ bar_length
        
        range_str = "[$(round(left_edge, digits=3)), $(round(right_edge, digits=3)))"
        println("    $(rpad(range_str, 20)) │$bar ($count)")
    end
    println()
end

# Analyze eigenvalues for each critical point type
for point_type in [:minimum, :saddle, :maximum]
    eigenvals = extract_all_eigenvalues(df_enhanced, point_type)
    text_histogram(eigenvals, "$(uppercase(string(point_type))) EIGENVALUES")
end

# Combined eigenvalue analysis
println("=== Combined Eigenvalue Statistics ===")

all_min_eigenvals = extract_all_eigenvalues(df_enhanced, :minimum)
all_saddle_eigenvals = extract_all_eigenvalues(df_enhanced, :saddle)  
all_max_eigenvals = extract_all_eigenvalues(df_enhanced, :maximum)

if !isempty(all_min_eigenvals) || !isempty(all_saddle_eigenvals) || !isempty(all_max_eigenvals)
    println("Eigenvalue sign analysis:")
    
    # Count positive, negative, and near-zero eigenvalues by type
    zero_tol = 1e-8
    
    for (name, eigenvals) in [("Minima", all_min_eigenvals), ("Saddle", all_saddle_eigenvals), ("Maxima", all_max_eigenvals)]
        if !isempty(eigenvals)
            positive = sum(eigenvals .> zero_tol)
            negative = sum(eigenvals .< -zero_tol) 
            near_zero = sum(abs.(eigenvals) .<= zero_tol)
            
            total = length(eigenvals)
            println("  $name eigenvalues ($total total):")
            println("    • Positive: $positive ($(round(100*positive/total, digits=1))%)")
            println("    • Negative: $negative ($(round(100*negative/total, digits=1))%)")
            println("    • Near-zero: $near_zero ($(round(100*near_zero/total, digits=1))%)")
        end
    end
    
    # Mathematical validation
    println("\nMathematical validation:")
    if !isempty(all_min_eigenvals)
        min_positive_rate = sum(all_min_eigenvals .> zero_tol) / length(all_min_eigenvals)
        println("  • Minima positive eigenvalue rate: $(round(100*min_positive_rate, digits=1))% (should be ~100%)")
    end
    if !isempty(all_max_eigenvals)
        max_negative_rate = sum(all_max_eigenvals .< -zero_tol) / length(all_max_eigenvals)
        println("  • Maxima negative eigenvalue rate: $(round(100*max_negative_rate, digits=1))% (should be ~100%)")
    end
    if !isempty(all_saddle_eigenvals)
        saddle_mixed = (sum(all_saddle_eigenvals .> zero_tol) > 0) && (sum(all_saddle_eigenvals .< -zero_tol) > 0)
        println("  • Saddle points have mixed signs: $(saddle_mixed ? "✓" : "✗") (should be ✓)")
    end
end

println("\n=== Computational Performance ===")
println("Phase 2 adds comprehensive Hessian analysis including:")
println("  • Automatic differentiation for Hessian computation")  
println("  • Eigenvalue decomposition for classification")
println("  • Statistical analysis of matrix properties")
println("  • Numerical stability assessment")

println("\nDataFrame columns added by Phase 2:")
phase2_columns = [
    "critical_point_type", "smallest_positive_eigenval", "largest_negative_eigenval",
    "hessian_norm", "hessian_eigenvalue_min", "hessian_eigenvalue_max", 
    "hessian_condition_number", "hessian_determinant", "hessian_trace"
]
for col in phase2_columns
    if col in string.(names(df_enhanced))
        println("  ✓ $col")
    end
end

# Display the 5 smallest minimizers found
println("\n=== Sample Enhanced DataFrame: 5 Smallest Minimizers ===")
if nrow(df_enhanced) > 0
    # Filter for minima only
    minima_mask = df_enhanced.critical_point_type .== :minimum
    
    if any(minima_mask)
        minima_df = df_enhanced[minima_mask, :]
        
        # Sort by function value (ascending) to get smallest minimizers
        sort!(minima_df, :z)
        
        sample_cols = [:x1, :x2, :x3, :z, :critical_point_type, :hessian_norm, :hessian_condition_number, :smallest_positive_eigenval]
        available_cols = intersect(sample_cols, Symbol.(names(minima_df)))
        sample_size = min(5, nrow(minima_df))
        
        println("5 smallest minimizers (sorted by function value):")
        println(minima_df[1:sample_size, available_cols])
        
        # Also show some summary statistics for these minimizers
        if sample_size > 1
            smallest_values = minima_df.z[1:sample_size]
            println("\nSummary of 5 smallest minimizers:")
            println("  • Global minimum value: $(round(minimum(smallest_values), digits=6))")
            println("  • Value range: [$(round(minimum(smallest_values), digits=6)), $(round(maximum(smallest_values), digits=6))]")
            println("  • Average spacing: $(round((maximum(smallest_values) - minimum(smallest_values))/(sample_size-1), digits=6))")
        end
    else
        println("No local minima found in the analysis.")
    end
else
    println("No data available in enhanced DataFrame.")
end

println("\n=== Demo Complete ===")
println("The enhanced analysis provides:")
println("  • Rigorous mathematical classification of critical points")
println("  • Eigenvalue-based validation of minima/maxima")  
println("  • Numerical stability assessment")
println("  • Comprehensive statistical analysis")
println("  • Ready for Phase 3 visualization improvements")

# Optional visualization section (comment out if visualization causes issues)
# This section demonstrates Phase 2 visualizations

# NOTE: Using GLMakie for interactive 3D visualization (avoid loading CairoMakie simultaneously)
println("\n=== Phase 2 Visualizations ===")
using GLMakie  # Required for 3D interactive level set visualization

# Comment out CairoMakie-based plots to avoid backend conflicts
# To use these plots, comment out GLMakie above and uncomment CairoMakie below:
# using CairoMakie

# # Hessian norm analysis
# # fig1 = plot_hessian_norms(df_enhanced)
# # display(fig1)

# # # Condition number analysis  
# # fig2 = plot_condition_numbers(df_enhanced)
# # display(fig2)

# # # Critical eigenvalue analysis
# # fig3 = plot_critical_eigenvalues(df_enhanced)
# # display(fig3)

# # Enhanced: All eigenvalues visualization (NEW!)
# println("\n=== Enhanced All-Eigenvalues Visualization ===")
# println("This new visualization shows ALL 3 eigenvalues for each critical point")
# println("Separate subplots for each critical point type (minimum, saddle, maximum)")
# println("Colors: Red (λ₁), Blue (λ₂), Green (λ₃)")
# println("Stroke colors: Green (minimum), Orange (saddle), Red (maximum)")
# println("Eigenvalues are vertically aligned with dotted connecting lines")

# println("\n1. Standard magnitude plot (preserves eigenvalue signs):")
# fig_all = plot_all_eigenvalues(f, df_enhanced, sort_by=:magnitude)
# display(fig_all)

# println("\n2. Absolute magnitude plot (compares magnitudes only):")
# fig_abs = plot_all_eigenvalues(f, df_enhanced, sort_by=:abs_magnitude)
# display(fig_abs)

# println("\n3. Eigenvalue spread plot (ordered by eigenvalue range):")
# fig_spread = plot_all_eigenvalues(f, df_enhanced, sort_by=:spread)
# display(fig_spread)

println("NOTE: CairoMakie-based plots are commented out to avoid conflicts with GLMakie")
println("To use Phase 2 static plots, comment out GLMakie and uncomment CairoMakie section above")

# =============================================================================
# NEW: 3D Level Set Visualization
# =============================================================================
println("\n=== 3D Interactive Level Set Visualization ===")
println("Creating interactive 3D level set visualization with critical points...")
println("This visualization allows you to:")
println("  • Interactively explore level sets using a slider")
println("  • See critical points highlighted as diamonds")
println("  • Navigate through function value ranges")
println("  • Visualize how critical points relate to level sets")

# Create 3D grid for level set visualization
println("\n1. Generating 3D visualization grid...")
grid_resolution = 25  # 26×26×26 = 17,576 points (good balance of detail vs performance)
vis_grid = generate_grid_small_n(3, grid_resolution)  # Optimized for 3D

# Transform grid to match problem domain
vis_scale_factor = scale_factor  # Use same scale as problem
vis_center = center              # Use same center as problem

# Transform from [-1,1]³ to problem domain
transformed_vis_grid = Array{SVector{3,Float64}}(undef, size(vis_grid))
for i in eachindex(vis_grid)
    transformed_vis_grid[i] = SVector{3}(vis_scale_factor .* vis_grid[i] .+ vis_center)
end

println("   Grid dimensions: $(size(transformed_vis_grid))")
println("   Total grid points: $(length(transformed_vis_grid))")
println("   Domain: [$(minimum(minimum(p) for p in transformed_vis_grid)), $(maximum(maximum(p) for p in transformed_vis_grid))]³")

# Prepare critical points DataFrame for visualization
# Level set visualization expects columns: x1, x2, x3, z
vis_df = select(df_enhanced, :x1, :x2, :x3, :z)

# Calculate function value range for level set slider
println("\n2. Computing function value range...")
z_values_sample = [f(transformed_vis_grid[i]) for i in 1:min(1000, length(transformed_vis_grid))]
filter!(isfinite, z_values_sample)

if !isempty(z_values_sample)
    z_min_sample = minimum(z_values_sample)
    z_max_sample = maximum(z_values_sample)
    
    # Expand range slightly and include critical point values
    crit_z_min = minimum(df_enhanced.z)
    crit_z_max = maximum(df_enhanced.z)
    
    z_range_viz = (
        min(z_min_sample, crit_z_min) - 0.1 * abs(crit_z_max - crit_z_min),
        max(z_max_sample, crit_z_max) + 0.1 * abs(crit_z_max - crit_z_min)
    )
    
    println("   Function range on grid sample: [$(round(z_min_sample, digits=4)), $(round(z_max_sample, digits=4))]")
    println("   Critical points range: [$(round(crit_z_min, digits=4)), $(round(crit_z_max, digits=4))]")
    println("   Visualization range: [$(round(z_range_viz[1], digits=4)), $(round(z_range_viz[2], digits=4))]")
    
    # Create interactive level set visualization
    println("\n3. Creating interactive 3D level set visualization...")
    println("   This may take a moment to compute function values on the grid...")
    
    # Set visualization parameters
    viz_params = VisualizationParameters{Float64}(
        point_tolerance=0.05,     # Tolerance for level set detection
        point_window=0.1,         # Window for point visibility
        fig_size=(1200, 900)      # Larger figure for better visibility
    )
    
    try
        # Create the interactive visualization
        fig_levelset = create_level_set_visualization(
            f,
            transformed_vis_grid,
            vis_df,
            z_range_viz,
            viz_params
        )
        
        println("   ✓ Interactive level set visualization created successfully!")
        println("   Use the slider to explore different level sets")
        println("   Orange diamonds show critical points near the current level")
        println("   Blue points show the level set surface")
        
        display(fig_levelset)
        
    catch e
        @warn "Level set visualization failed" exception=e
        println("   ✗ Level set visualization failed: $e")
        println("   This might be due to:")
        println("     • Grid resolution too high (try reducing grid_resolution)")
        println("     • Function evaluation issues")
        println("     • GLMakie backend problems")
    end
else
    @warn "Could not compute function value range for level set visualization"
    println("   ✗ Could not sample function values for level set range")
end

println("\n=== Level Set Visualization Complete ===")
println("The 3D level set visualization provides:")
println("  • Interactive exploration of function level sets")
println("  • Real-time critical point highlighting")
println("  • Intuitive understanding of function topology")
println("  • Visual validation of critical point classifications")

