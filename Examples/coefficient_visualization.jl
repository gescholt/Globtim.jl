"""
Coefficient Magnitude Visualization

This module provides visualization tools for polynomial coefficient distributions:
1. Coefficient magnitude plots with truncation thresholds
2. Sparsity analysis visualization
3. Comparison plots for different bases
4. Interactive threshold exploration

Usage:
    julia --project=. Examples/coefficient_visualization.jl
    
Or in REPL:
    include("Examples/coefficient_visualization.jl")
    plot_coefficient_distribution(polynomial, thresholds=[1e-10, 1e-8, 1e-6])
"""

using Pkg
Pkg.activate(".")

# Core packages
using Globtim
using DynamicPolynomials
using Printf
using Statistics
using LinearAlgebra

# Plotting packages
plotting_available = false
try
    using CairoMakie
    global plotting_available = true
    println("✅ CairoMakie loaded - high-quality plotting available")
catch
    try
        using Plots
        global plotting_available = true
        println("✅ Plots.jl loaded - basic plotting available")
    catch
        println("⚠️  No plotting packages available - install CairoMakie or Plots")
        println("   Run: using Pkg; Pkg.add(\"CairoMakie\")")
    end
end

# Load development utilities
include("adaptive_precision_4d_dev.jl")

println("📊 Coefficient Visualization System")
println("=" ^ 40)

# ============================================================================
# COEFFICIENT EXTRACTION AND ANALYSIS
# ============================================================================

"""
    extract_coefficient_data(poly)

Extract coefficient magnitudes and monomial information from polynomial.
"""
function extract_coefficient_data(poly)
    @polyvar x[1:4]
    
    # Convert to monomial basis
    mono_poly = to_exact_monomial_basis(poly, variables=x)
    
    # Extract coefficients and monomials
    terms_list = terms(mono_poly)
    coeffs = [coefficient(t) for t in terms_list]
    monos = [monomial(t) for t in terms_list]
    
    # Calculate magnitudes
    magnitudes = abs.(Float64.(coeffs))
    
    # Sort by magnitude (descending)
    sorted_indices = sortperm(magnitudes, rev=true)
    sorted_magnitudes = magnitudes[sorted_indices]
    sorted_coeffs = coeffs[sorted_indices]
    sorted_monos = monos[sorted_indices]
    
    # Calculate degrees for each term
    degrees = [sum(exponents(mono)) for mono in sorted_monos]
    
    return Dict(
        :magnitudes => sorted_magnitudes,
        :coefficients => sorted_coeffs,
        :monomials => sorted_monos,
        :degrees => degrees,
        :total_terms => length(coeffs)
    )
end

"""
    analyze_truncation_thresholds(magnitudes, thresholds)

Analyze how many coefficients are kept at different truncation thresholds.
"""
function analyze_truncation_thresholds(magnitudes, thresholds)
    total_terms = length(magnitudes)
    
    threshold_data = []
    for threshold in thresholds
        kept = sum(magnitudes .> threshold)
        sparsity = (total_terms - kept) / total_terms * 100
        
        push!(threshold_data, Dict(
            :threshold => threshold,
            :kept => kept,
            :removed => total_terms - kept,
            :sparsity => sparsity
        ))
    end
    
    return threshold_data
end

# ============================================================================
# PLOTTING FUNCTIONS
# ============================================================================

"""
    plot_coefficient_distribution(poly, thresholds=[1e-12, 1e-10, 1e-8, 1e-6]; 
                                 title="Coefficient Magnitude Distribution")

Plot coefficient magnitude distribution with truncation thresholds.
"""
function plot_coefficient_distribution(poly, thresholds=[1e-12, 1e-10, 1e-8, 1e-6]; 
                                      title="Coefficient Magnitude Distribution",
                                      save_path=nothing)
    
    if !plotting_available
        println("❌ Plotting not available - install CairoMakie or Plots")
        return nothing
    end
    
    println("📊 Creating coefficient distribution plot...")
    
    # Extract coefficient data
    coeff_data = extract_coefficient_data(poly)
    magnitudes = coeff_data[:magnitudes]
    degrees = coeff_data[:degrees]
    total_terms = coeff_data[:total_terms]
    
    # Analyze thresholds
    threshold_data = analyze_truncation_thresholds(magnitudes, thresholds)
    
    # Create plot
    if @isdefined(CairoMakie)
        fig = create_makie_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)
    else
        fig = create_plots_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)
    end
    
    # Display threshold information
    println("\n📊 Truncation Analysis:")
    println("┌─────────────┬──────────┬──────────┬───────────┐")
    println("│ Threshold   │ Kept     │ Removed  │ Sparsity  │")
    println("├─────────────┼──────────┼──────────┼───────────┤")
    for data in threshold_data
        @printf "│ %11.0e │ %8d │ %8d │ %7.1f%% │\n" data[:threshold] data[:kept] data[:removed] data[:sparsity]
    end
    println("└─────────────┴──────────┴──────────┴───────────┘")
    
    # Save if requested
    if save_path !== nothing
        try
            if @isdefined(CairoMakie)
                CairoMakie.save(save_path, fig)
            else
                Plots.savefig(fig, save_path)
            end
            println("💾 Plot saved to: $save_path")
        catch e
            println("⚠️  Could not save plot: $e")
        end
    end
    
    return fig, coeff_data, threshold_data
end

"""
    create_makie_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)

Create coefficient plot using CairoMakie.
"""
function create_makie_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)
    # Create figure
    fig = CairoMakie.Figure(resolution=(1000, 600))
    ax = CairoMakie.Axis(fig[1, 1], 
                        title=title,
                        xlabel="Coefficient Index (sorted by magnitude)",
                        ylabel="Coefficient Magnitude",
                        yscale=log10)
    
    # Color coefficients based on truncation
    colors = []
    for (i, mag) in enumerate(magnitudes)
        if mag > thresholds[1]
            push!(colors, :red)      # Keep (highest threshold)
        elseif mag > thresholds[2]
            push!(colors, :orange)   # Keep (medium threshold)
        elseif mag > thresholds[3]
            push!(colors, :yellow)   # Keep (low threshold)
        elseif mag > thresholds[4]
            push!(colors, :lightblue) # Keep (very low threshold)
        else
            push!(colors, :lightgray) # Truncate
        end
    end
    
    # Plot coefficients
    CairoMakie.scatter!(ax, 1:length(magnitudes), magnitudes, 
                       color=colors, markersize=8, alpha=0.7)
    
    # Add threshold lines
    threshold_colors = [:red, :orange, :yellow, :lightblue]
    for (i, threshold) in enumerate(thresholds)
        CairoMakie.hlines!(ax, [threshold], color=threshold_colors[i], 
                          linestyle=:dash, linewidth=2,
                          label="Threshold $(threshold)")
    end
    
    # Add legend
    CairoMakie.axislegend(ax, position=:rt)
    
    # Add text annotations for sparsity
    y_pos = maximum(magnitudes) * 0.1
    for (i, data) in enumerate(threshold_data)
        text_str = @sprintf "%.0e: %.1f%% sparse" data[:threshold] data[:sparsity]
        CairoMakie.text!(ax, length(magnitudes) * 0.7, y_pos / (10^(i-1)), 
                        text=text_str, color=threshold_colors[i], fontsize=12)
    end
    
    return fig
end

"""
    create_plots_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)

Create coefficient plot using Plots.jl.
"""
function create_plots_coefficient_plot(magnitudes, degrees, thresholds, threshold_data, title)
    # Create base plot
    p = Plots.plot(title=title, 
                  xlabel="Coefficient Index (sorted by magnitude)",
                  ylabel="Coefficient Magnitude",
                  yscale=:log10,
                  size=(1000, 600),
                  dpi=300)
    
    # Color coefficients based on truncation
    colors = []
    labels = []
    for (i, mag) in enumerate(magnitudes)
        if mag > thresholds[1]
            push!(colors, :red)
            push!(labels, "Keep (>$(thresholds[1]))")
        elseif mag > thresholds[2]
            push!(colors, :orange)
            push!(labels, "Keep (>$(thresholds[2]))")
        elseif mag > thresholds[3]
            push!(colors, :yellow)
            push!(labels, "Keep (>$(thresholds[3]))")
        elseif mag > thresholds[4]
            push!(colors, :lightblue)
            push!(labels, "Keep (>$(thresholds[4]))")
        else
            push!(colors, :lightgray)
            push!(labels, "Truncate")
        end
    end
    
    # Plot coefficients
    Plots.scatter!(p, 1:length(magnitudes), magnitudes, 
                  color=colors, markersize=4, alpha=0.7,
                  legend=false)
    
    # Add threshold lines
    threshold_colors = [:red, :orange, :yellow, :lightblue]
    for (i, threshold) in enumerate(thresholds)
        Plots.hline!(p, [threshold], color=threshold_colors[i], 
                    linestyle=:dash, linewidth=2,
                    label="Threshold $(threshold)")
    end
    
    return p
end

"""
    compare_basis_coefficients(cheb_poly, leg_poly, thresholds=[1e-10, 1e-8, 1e-6])

Compare coefficient distributions between Chebyshev and Legendre bases.
"""
function compare_basis_coefficients(cheb_poly, leg_poly, thresholds=[1e-10, 1e-8, 1e-6])
    if !plotting_available
        println("❌ Plotting not available - install CairoMakie or Plots")
        return nothing
    end
    
    println("📊 Comparing coefficient distributions...")
    
    # Extract data for both bases
    cheb_data = extract_coefficient_data(cheb_poly)
    
    leg_data = nothing
    try
        leg_data = extract_coefficient_data(leg_poly)
    catch e
        println("⚠️  Legendre coefficient extraction failed: $e")
        println("   Creating Chebyshev-only plot...")
        return plot_coefficient_distribution(cheb_poly, thresholds, 
                                           title="Chebyshev Coefficient Distribution (Legendre Failed)")
    end
    
    # Create comparison plot
    if @isdefined(CairoMakie)
        fig = create_makie_comparison_plot(cheb_data, leg_data, thresholds)
    else
        fig = create_plots_comparison_plot(cheb_data, leg_data, thresholds)
    end
    
    # Analysis
    println("\n📊 Basis Comparison:")
    for threshold in thresholds
        cheb_kept = sum(cheb_data[:magnitudes] .> threshold)
        leg_kept = sum(leg_data[:magnitudes] .> threshold)
        
        cheb_sparsity = (cheb_data[:total_terms] - cheb_kept) / cheb_data[:total_terms] * 100
        leg_sparsity = (leg_data[:total_terms] - leg_kept) / leg_data[:total_terms] * 100
        
        @printf "Threshold %.0e: Cheb %.1f%% sparse, Leg %.1f%% sparse\n" threshold cheb_sparsity leg_sparsity
    end
    
    return fig, cheb_data, leg_data
end

"""
    create_makie_comparison_plot(cheb_data, leg_data, thresholds)

Create comparison plot using CairoMakie.
"""
function create_makie_comparison_plot(cheb_data, leg_data, thresholds)
    fig = CairoMakie.Figure(resolution=(1200, 800))
    
    # Chebyshev plot
    ax1 = CairoMakie.Axis(fig[1, 1], 
                         title="Chebyshev Coefficients",
                         xlabel="Coefficient Index",
                         ylabel="Magnitude",
                         yscale=log10)
    
    CairoMakie.scatter!(ax1, 1:length(cheb_data[:magnitudes]), cheb_data[:magnitudes], 
                       color=:blue, markersize=6, alpha=0.7)
    
    for threshold in thresholds
        CairoMakie.hlines!(ax1, [threshold], color=:red, linestyle=:dash)
    end
    
    # Legendre plot
    ax2 = CairoMakie.Axis(fig[1, 2], 
                         title="Legendre Coefficients",
                         xlabel="Coefficient Index",
                         ylabel="Magnitude",
                         yscale=log10)
    
    CairoMakie.scatter!(ax2, 1:length(leg_data[:magnitudes]), leg_data[:magnitudes], 
                       color=:green, markersize=6, alpha=0.7)
    
    for threshold in thresholds
        CairoMakie.hlines!(ax2, [threshold], color=:red, linestyle=:dash)
    end
    
    return fig
end

"""
    create_plots_comparison_plot(cheb_data, leg_data, thresholds)

Create comparison plot using Plots.jl.
"""
function create_plots_comparison_plot(cheb_data, leg_data, thresholds)
    # Create subplots
    p1 = Plots.scatter(1:length(cheb_data[:magnitudes]), cheb_data[:magnitudes],
                      title="Chebyshev Coefficients",
                      xlabel="Coefficient Index",
                      ylabel="Magnitude",
                      yscale=:log10,
                      color=:blue,
                      markersize=3,
                      alpha=0.7,
                      legend=false)
    
    for threshold in thresholds
        Plots.hline!(p1, [threshold], color=:red, linestyle=:dash, alpha=0.5)
    end
    
    p2 = Plots.scatter(1:length(leg_data[:magnitudes]), leg_data[:magnitudes],
                      title="Legendre Coefficients",
                      xlabel="Coefficient Index", 
                      ylabel="Magnitude",
                      yscale=:log10,
                      color=:green,
                      markersize=3,
                      alpha=0.7,
                      legend=false)
    
    for threshold in thresholds
        Plots.hline!(p2, [threshold], color=:red, linestyle=:dash, alpha=0.5)
    end
    
    return Plots.plot(p1, p2, layout=(1, 2), size=(1200, 600))
end

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

"""
    quick_coefficient_plot(degree=4, samples=20, basis=:chebyshev)

Quick coefficient distribution plot for a polynomial.
"""
function quick_coefficient_plot(degree=4, samples=20, basis=:chebyshev)
    println("🚀 Creating quick coefficient plot...")
    
    # Construct polynomial
    TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=samples, 
                   sample_range=2.0, degree_max=degree+2)
    
    poly = Constructor(TR, degree, basis=basis, precision=AdaptivePrecision, verbose=0)
    
    # Create plot
    title_str = "$(titlecase(string(basis))) Coefficients (deg=$degree, n=$samples)"
    return plot_coefficient_distribution(poly, [1e-12, 1e-10, 1e-8, 1e-6], 
                                       title=title_str,
                                       save_path="coefficient_plot_$(basis)_deg$(degree)_n$(samples).png")
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    if plotting_available
        println("\n🚀 Creating example coefficient plots...")
        
        # Quick example
        fig, data, thresholds = quick_coefficient_plot(4, 20, :chebyshev)
        
        println("\n🎉 Visualization complete!")
    else
        println("\n⚠️  Install plotting packages to use visualization:")
        println("   using Pkg; Pkg.add(\"CairoMakie\")")
    end
    
else
    println("\n💡 Coefficient visualization functions loaded:")
    println("  - plot_coefficient_distribution(poly, thresholds)")
    println("  - compare_basis_coefficients(cheb_poly, leg_poly)")
    println("  - quick_coefficient_plot(degree, samples, basis)")
    println("  - extract_coefficient_data(poly)")
    
    if plotting_available
        println("\n🎨 Plotting ready!")
    else
        println("\n⚠️  Install CairoMakie or Plots for visualization")
    end
end
