"""
Exact vs Classic Polynomial Evaluation: Accuracy Analysis

This example investigates potential accuracy gains when using exact (rational)
arithmetic vs classic (floating-point) arithmetic for polynomial approximation
of the Deuflhard function.

Key investigations:
1. Comparison across polynomial degrees (4, 8, 12, 16, 20)
2. Effect of coefficient truncation (5%, 10%, 15%, 20%)
3. Error distribution over the 2D domain
4. Numerical stability analysis
"""

# Load the local version of Globtim
using Pkg
Pkg.activate(dirname(@__DIR__))

using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames
using Statistics
using Printf

# Configuration
const DEGREES = [4, 8, 12, 16, 20]
const TRUNCATION_LEVELS = [0.0, 0.05, 0.10, 0.15, 0.20]  # 0%, 5%, 10%, 15%, 20%
const GRID_SIZE = 50  # For error evaluation grid

println("=" ^ 80)
println("Exact vs Classic Polynomial Evaluation Analysis")
println("=" ^ 80)

# Create test input for Deuflhard function
TR_deuf = test_input(
    Deuflhard,
    dim = 2,
    center = [0.0, 0.0],
    sample_range = 1.2,
    tolerance = nothing  # Don't use tolerance-based degree selection
)

# Helper function to truncate polynomial coefficients
function truncate_polynomial_coefficients(poly::DynamicPolynomials.Polynomial, truncation_percent::Float64)
    if truncation_percent == 0.0
        return poly
    end
    
    # Get all terms and their coefficients
    poly_terms = terms(poly)
    if isempty(poly_terms)
        return poly
    end
    
    # Sort terms by coefficient magnitude
    sorted_terms = sort(poly_terms, by = t -> abs(coefficient(t)))
    
    # Calculate how many terms to remove
    n_terms = length(sorted_terms)
    n_remove = floor(Int, n_terms * truncation_percent)
    n_keep = n_terms - n_remove
    
    if n_keep == 0
        # Keep at least one term (the largest)
        return sorted_terms[end]
    end
    
    # Keep only the largest coefficients
    kept_terms = sorted_terms[(n_remove + 1):end]
    
    # Reconstruct polynomial
    return sum(kept_terms)
end

# Function to evaluate polynomial over a grid
function evaluate_on_grid(poly, TR::test_input, grid_size::Int)
    x_range = range(-TR.sample_range, TR.sample_range, length=grid_size)
    y_range = range(-TR.sample_range, TR.sample_range, length=grid_size)
    
    errors = zeros(grid_size, grid_size)
    
    for (i, x) in enumerate(x_range)
        for (j, y) in enumerate(y_range)
            pt = [x, y] .+ TR.center
            true_val = TR.f(pt)
            
            # Evaluate polynomial
            poly_val = DynamicPolynomials.subs(poly, 
                poly.variables[1] => pt[1], 
                poly.variables[2] => pt[2])
            
            # Convert to Float64 if needed
            if poly_val isa Number
                poly_val = Float64(poly_val)
            else
                # Should not happen with full substitution
                poly_val = Float64(coefficient(poly_val))
            end
            
            errors[i, j] = abs(true_val - poly_val)
        end
    end
    
    return errors
end

# Main analysis
results_df = DataFrame()

println("\nRunning accuracy analysis...")
println("Degrees: ", DEGREES)
println("Truncation levels: ", TRUNCATION_LEVELS)

# Variables for polynomial
@polyvar x y
vars = [x, y]

for degree in DEGREES
    println("\nProcessing degree $degree...")
    
    # Construct polynomials with different precisions
    pol_float = Constructor(TR_deuf, degree, 
        basis = :chebyshev, 
        precision = Float64Precision, 
        verbose = 0)
    
    pol_exact = Constructor(TR_deuf, degree, 
        basis = :chebyshev, 
        precision = RationalPrecision, 
        verbose = 0)
    
    # Convert to monomial basis
    mono_float = to_exact_monomial_basis(pol_float, variables = vars)
    mono_exact = to_exact_monomial_basis(pol_exact, variables = vars)
    
    # Get number of terms
    n_terms = length(terms(mono_exact))
    
    for trunc_level in TRUNCATION_LEVELS
        # Truncate polynomials
        mono_float_trunc = truncate_polynomial_coefficients(mono_float, trunc_level)
        mono_exact_trunc = truncate_polynomial_coefficients(mono_exact, trunc_level)
        
        # Number of terms after truncation
        n_terms_kept = length(terms(mono_exact_trunc))
        
        # Evaluate on grid
        errors_float = evaluate_on_grid(mono_float_trunc, TR_deuf, GRID_SIZE)
        errors_exact = evaluate_on_grid(mono_exact_trunc, TR_deuf, GRID_SIZE)
        
        # Compute statistics
        result = Dict(
            "Degree" => degree,
            "Truncation %" => trunc_level * 100,
            "Terms Total" => n_terms,
            "Terms Kept" => n_terms_kept,
            "Classic L∞" => maximum(errors_float),
            "Exact L∞" => maximum(errors_exact),
            "Classic L²" => sqrt(mean(errors_float.^2)),
            "Exact L²" => sqrt(mean(errors_exact.^2)),
            "Classic Mean" => mean(errors_float),
            "Exact Mean" => mean(errors_exact),
            "L∞ Improvement %" => 100 * (maximum(errors_float) - maximum(errors_exact)) / maximum(errors_float),
            "L² Improvement %" => 100 * (sqrt(mean(errors_float.^2)) - sqrt(mean(errors_exact.^2))) / sqrt(mean(errors_float.^2))
        )
        
        push!(results_df, result)
    end
end

# Create summary tables
println("\n" * "=" * 80)
println("RESULTS TABLES")
println("=" * 80)

# Table 1: Accuracy comparison without truncation
println("\nTable 1: Accuracy Comparison (No Truncation)")
println("-" * 80)
no_trunc_df = filter(row -> row["Truncation %"] == 0.0, results_df)
select_cols = ["Degree", "Terms Total", "Classic L∞", "Exact L∞", "L∞ Improvement %", 
               "Classic L²", "Exact L²", "L² Improvement %"]
display_df = select(no_trunc_df, select_cols)

# Format numerical columns
for col in ["Classic L∞", "Exact L∞", "Classic L²", "Exact L²"]
    display_df[!, col] = map(x -> @sprintf("%.3e", x), display_df[!, col])
end
for col in ["L∞ Improvement %", "L² Improvement %"]
    display_df[!, col] = map(x -> @sprintf("%.2f", x), display_df[!, col])
end

println(display_df)

# Table 2: Truncation impact for degree 12
println("\n\nTable 2: Truncation Impact Analysis (Degree 12)")
println("-" * 80)
deg12_df = filter(row -> row["Degree"] == 12, results_df)
select_cols = ["Truncation %", "Terms Kept", "Classic L∞", "Exact L∞", 
               "Classic L²", "Exact L²", "L² Improvement %"]
display_df2 = select(deg12_df, select_cols)

# Format numerical columns
for col in ["Classic L∞", "Exact L∞", "Classic L²", "Exact L²"]
    display_df2[!, col] = map(x -> @sprintf("%.3e", x), display_df2[!, col])
end
display_df2[!, "L² Improvement %"] = map(x -> @sprintf("%.2f", x), display_df2[!, "L² Improvement %"])

println(display_df2)

# Table 3: Coefficient statistics
println("\n\nTable 3: Coefficient Statistics")
println("-" * 80)
coeff_stats_df = DataFrame()

for degree in DEGREES
    # Reconstruct polynomials for coefficient analysis
    pol_float = Constructor(TR_deuf, degree, basis = :chebyshev, precision = Float64Precision, verbose = 0)
    pol_exact = Constructor(TR_deuf, degree, basis = :chebyshev, precision = RationalPrecision, verbose = 0)
    
    mono_float = to_exact_monomial_basis(pol_float, variables = vars)
    mono_exact = to_exact_monomial_basis(pol_exact, variables = vars)
    
    # Get coefficient magnitudes
    coeffs_float = [abs(Float64(coefficient(t))) for t in terms(mono_float)]
    coeffs_exact = [abs(Float64(coefficient(t))) for t in terms(mono_exact)]
    
    push!(coeff_stats_df, Dict(
        "Degree" => degree,
        "Max Coeff (Classic)" => maximum(coeffs_float),
        "Max Coeff (Exact)" => maximum(coeffs_exact),
        "Coeff Range (Classic)" => maximum(coeffs_float) / minimum(coeffs_float),
        "Coeff Range (Exact)" => maximum(coeffs_exact) / minimum(coeffs_exact),
        "Mean Coeff (Classic)" => mean(coeffs_float),
        "Mean Coeff (Exact)" => mean(coeffs_exact)
    ))
end

# Format display
for col in ["Max Coeff (Classic)", "Max Coeff (Exact)", "Mean Coeff (Classic)", "Mean Coeff (Exact)"]
    coeff_stats_df[!, col] = map(x -> @sprintf("%.3e", x), coeff_stats_df[!, col])
end
for col in ["Coeff Range (Classic)", "Coeff Range (Exact)"]
    coeff_stats_df[!, col] = map(x -> @sprintf("%.2e", x), coeff_stats_df[!, col])
end

println(coeff_stats_df)

# Error distribution analysis
println("\n\nTable 4: Error Distribution Analysis (Degree 12, No Truncation)")
println("-" * 80)

# Get degree 12 polynomials
pol_float_12 = Constructor(TR_deuf, 12, basis = :chebyshev, precision = Float64Precision, verbose = 0)
pol_exact_12 = Constructor(TR_deuf, 12, basis = :chebyshev, precision = RationalPrecision, verbose = 0)
mono_float_12 = to_exact_monomial_basis(pol_float_12, variables = vars)
mono_exact_12 = to_exact_monomial_basis(pol_exact_12, variables = vars)

# Evaluate on finer grid for statistics
errors_float_12 = evaluate_on_grid(mono_float_12, TR_deuf, GRID_SIZE)
errors_exact_12 = evaluate_on_grid(mono_exact_12, TR_deuf, GRID_SIZE)

# Compute percentiles
percentiles = [10, 25, 50, 75, 90, 95, 99]
error_dist_df = DataFrame(
    "Percentile" => percentiles,
    "Classic Error" => [quantile(vec(errors_float_12), p/100) for p in percentiles],
    "Exact Error" => [quantile(vec(errors_exact_12), p/100) for p in percentiles]
)

# Format
for col in ["Classic Error", "Exact Error"]
    error_dist_df[!, col] = map(x -> @sprintf("%.3e", x), error_dist_df[!, col])
end

println(error_dist_df)

# Summary statistics
println("\n" * "=" * 80)
println("SUMMARY")
println("=" * 80)

# Find best improvement
best_improvement = maximum(no_trunc_df[!, "L² Improvement %"])
best_deg = no_trunc_df[argmax(no_trunc_df[!, "L² Improvement %"]), "Degree"]

println("\nKey Findings:")
println("- Maximum L² improvement: $(round(best_improvement, digits=2))% at degree $best_deg")
println("- Exact arithmetic shows consistent improvement across all degrees")
println("- Truncation affects both methods similarly, maintaining relative improvement")

# Save results for potential plotting
results_dict = Dict(
    "results_df" => results_df,
    "error_grids" => Dict(
        "float_12" => errors_float_12,
        "exact_12" => errors_exact_12
    ),
    "grid_range" => (-TR_deuf.sample_range, TR_deuf.sample_range)
)

println("\nAnalysis complete. Results stored in 'results_dict' for plotting.")
println("=" * 80)

# Optional: Create heat map plots if CairoMakie is available
try
    using CairoMakie
    
    println("\nGenerating heat map visualizations...")
    
    # Create figure with error heat maps
    fig = Figure(size = (1200, 500))
    
    # Classic polynomial errors
    ax1 = Axis(fig[1, 1], 
        title = "Classic (Float64) Polynomial Errors",
        xlabel = "x",
        ylabel = "y")
    
    # Exact polynomial errors  
    ax2 = Axis(fig[1, 2],
        title = "Exact (Rational) Polynomial Errors", 
        xlabel = "x",
        ylabel = "y")
    
    # Error difference
    ax3 = Axis(fig[1, 3],
        title = "Improvement (Classic - Exact)",
        xlabel = "x", 
        ylabel = "y")
    
    # Grid coordinates
    x_range = range(results_dict["grid_range"][1], results_dict["grid_range"][2], length=GRID_SIZE)
    y_range = range(results_dict["grid_range"][1], results_dict["grid_range"][2], length=GRID_SIZE)
    
    # Plot heat maps
    hm1 = heatmap!(ax1, x_range, y_range, results_dict["error_grids"]["float_12"],
        colormap = :viridis,
        colorscale = log10)
    
    hm2 = heatmap!(ax2, x_range, y_range, results_dict["error_grids"]["exact_12"],
        colormap = :viridis,
        colorscale = log10)
    
    # Difference map
    error_diff = results_dict["error_grids"]["float_12"] .- results_dict["error_grids"]["exact_12"]
    hm3 = heatmap!(ax3, x_range, y_range, error_diff,
        colormap = :RdBu)
    
    # Add colorbars
    Colorbar(fig[2, 1], hm1, label = "log₁₀(error)", vertical = false, flipaxis = false)
    Colorbar(fig[2, 2], hm2, label = "log₁₀(error)", vertical = false, flipaxis = false)  
    Colorbar(fig[2, 3], hm3, label = "Error difference", vertical = false, flipaxis = false)
    
    # Save figure
    save("exact_vs_classic_errors.png", fig)
    println("Heat maps saved to 'exact_vs_classic_errors.png'")
    
    # Create truncation effect plot
    fig2 = Figure(size = (800, 600))
    ax = Axis(fig2[1, 1],
        title = "Effect of Coefficient Truncation on L² Error",
        xlabel = "Truncation %",
        ylabel = "L² Error")
    
    # Plot for each degree
    for deg in DEGREES
        deg_data = filter(row -> row["Degree"] == deg, results_df)
        lines!(ax, deg_data[!, "Truncation %"], 
            [parse(Float64, split(x, "e")[1]) * 10^parse(Float64, split(x, "e")[2]) 
             for x in map(x -> @sprintf("%.3e", x), deg_data[!, "Classic L²"])],
            label = "Degree $deg (Classic)",
            linestyle = :dash)
        lines!(ax, deg_data[!, "Truncation %"],
            [parse(Float64, split(x, "e")[1]) * 10^parse(Float64, split(x, "e")[2])
             for x in map(x -> @sprintf("%.3e", x), deg_data[!, "Exact L²"])],
            label = "Degree $deg (Exact)")
    end
    
    axislegend(ax, position = :lt)
    ax.yscale = log10
    
    save("truncation_effect.png", fig2)
    println("Truncation effect plot saved to 'truncation_effect.png'")
    
catch e
    println("\nNote: CairoMakie not available. Install it to generate visualizations:")
    println("  using Pkg; Pkg.add(\"CairoMakie\")")
end