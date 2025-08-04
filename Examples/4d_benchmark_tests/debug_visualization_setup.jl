"""
Debug Basic Visualization Setup

Step-by-step debugging for plotting setup and basic visualization issues.
"""

using Globtim
using Printf

println("🔍 Step 3: Basic Visualization Setup Debugging")
println("=" ^ 50)

# ============================================================================
# STEP 3A: Check Package Availability
# ============================================================================

println("\n📊 Step 3A: Package Availability Check")
println("-" ^ 40)

# Check Julia version
println("Julia version: $(VERSION)")

# Check available packages
packages_to_check = ["CairoMakie", "GLMakie", "Plots", "PlotlyJS", "GR"]
available_packages = []

for pkg in packages_to_check
    try
        eval(:(using $(Symbol(pkg))))
        push!(available_packages, pkg)
        println("✅ $pkg: Available")
    catch e
        println("❌ $pkg: Not available - $e")
    end
end

println("\nAvailable plotting packages: $available_packages")

# ============================================================================
# STEP 3B: Installation Instructions
# ============================================================================

println("\n📊 Step 3B: Installation Instructions")
println("-" ^ 40)

if isempty(available_packages)
    println("No plotting packages found. Installation options:")
    println()
    println("Option 1 - CairoMakie (recommended for static plots):")
    println("  using Pkg")
    println("  Pkg.add(\"CairoMakie\")")
    println()
    println("Option 2 - GLMakie (for interactive plots):")
    println("  using Pkg") 
    println("  Pkg.add(\"GLMakie\")")
    println()
    println("Option 3 - Plots.jl (general purpose):")
    println("  using Pkg")
    println("  Pkg.add(\"Plots\")")
    println()
    println("After installation, restart Julia and try again.")
else
    println("Found plotting packages: $available_packages")
    println("You can use any of these for visualization.")
end

# ============================================================================
# STEP 3C: Test Minimal Plotting
# ============================================================================

println("\n📊 Step 3C: Minimal Plotting Test")
println("-" ^ 40)

plotting_success = false
used_backend = "none"

# Try CairoMakie first
if "CairoMakie" in available_packages
    try
        using CairoMakie
        
        # Test basic plot
        fig = Figure(size=(400, 300))
        ax = Axis(fig[1, 1], 
                 xlabel="X", 
                 ylabel="Y", 
                 title="Test Plot")
        
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 2, 5, 3]
        lines!(ax, x, y, color=:blue, linewidth=2)
        scatter!(ax, x, y, color=:red, markersize=8)
        
        # Try to save (this tests the full pipeline)
        test_output_dir = "Examples/4d_benchmark_tests/debug_output"
        if !isdir(test_output_dir)
            mkpath(test_output_dir)
        end
        
        save(joinpath(test_output_dir, "test_plot_cairomaki.png"), fig)
        
        plotting_success = true
        used_backend = "CairoMakie"
        println("✅ CairoMakie plotting successful")
        println("  Test plot saved to: $(joinpath(test_output_dir, "test_plot_cairomaki.png"))")
        
    catch e
        println("❌ CairoMakie plotting failed: $e")
    end
end

# Try GLMakie if CairoMakie failed
if !plotting_success && "GLMakie" in available_packages
    try
        using GLMakie
        
        fig = Figure(size=(400, 300))
        ax = Axis(fig[1, 1], 
                 xlabel="X", 
                 ylabel="Y", 
                 title="Test Plot")
        
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 2, 5, 3]
        lines!(ax, x, y, color=:blue, linewidth=2)
        scatter!(ax, x, y, color=:red, markersize=8)
        
        plotting_success = true
        used_backend = "GLMakie"
        println("✅ GLMakie plotting successful")
        
    catch e
        println("❌ GLMakie plotting failed: $e")
    end
end

# Try Plots.jl if Makie failed
if !plotting_success && "Plots" in available_packages
    try
        using Plots
        
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 2, 5, 3]
        p = plot(x, y, 
                xlabel="X", 
                ylabel="Y", 
                title="Test Plot",
                linewidth=2,
                marker=:circle,
                markersize=4)
        
        test_output_dir = "Examples/4d_benchmark_tests/debug_output"
        if !isdir(test_output_dir)
            mkpath(test_output_dir)
        end
        
        savefig(p, joinpath(test_output_dir, "test_plot_plots.png"))
        
        plotting_success = true
        used_backend = "Plots"
        println("✅ Plots.jl plotting successful")
        println("  Test plot saved to: $(joinpath(test_output_dir, "test_plot_plots.png"))")
        
    catch e
        println("❌ Plots.jl plotting failed: $e")
    end
end

# ============================================================================
# STEP 3D: Test Sparsification Plotting with Available Backend
# ============================================================================

println("\n📊 Step 3D: Sparsification Plotting Test")
println("-" ^ 40)

if plotting_success
    println("Testing sparsification plotting with $used_backend...")
    
    # Create test data
    f_test(x) = sum(x.^2) + 0.1*sum(x[1:end-1] .* x[2:end])
    TR_test = test_input(f_test, dim=3, center=zeros(3), sample_range=1.0)
    pol_test = Constructor(TR_test, 6)
    
    # Generate sparsification data
    thresholds = [1e-5, 1e-4, 1e-3, 1e-2]
    sparsification_data = []
    
    for threshold in thresholds
        sparse_result = sparsify_polynomial(pol_test, threshold, mode=:absolute)
        
        original_nnz = count(x -> abs(x) > 1e-15, pol_test.coeffs)
        new_nnz = count(x -> abs(x) > 1e-15, sparse_result.polynomial.coeffs)
        sparsity_gain = 1.0 - (new_nnz / original_nnz)
        
        push!(sparsification_data, (
            threshold = threshold,
            sparsity_gain = sparsity_gain,
            l2_ratio = sparse_result.l2_ratio,
            original_nnz = original_nnz,
            new_nnz = new_nnz
        ))
    end
    
    # Create sparsification plot
    try
        if used_backend == "CairoMakie"
            using CairoMakie
            
            fig = Figure(size=(800, 600))
            ax = Axis(fig[1, 1], 
                     xlabel="Sparsification Threshold", 
                     ylabel="Sparsity Gain",
                     title="Sparsification Analysis",
                     xscale=log10)
            
            x_vals = [d.threshold for d in sparsification_data]
            y_vals = [d.sparsity_gain for d in sparsification_data]
            
            lines!(ax, x_vals, y_vals, color=:blue, linewidth=2)
            scatter!(ax, x_vals, y_vals, color=:red, markersize=8)
            
            test_output_dir = "Examples/4d_benchmark_tests/debug_output"
            save(joinpath(test_output_dir, "sparsification_test.png"), fig)
            
            println("✅ Sparsification plot created successfully")
            println("  Saved to: $(joinpath(test_output_dir, "sparsification_test.png"))")
            
        elseif used_backend == "Plots"
            using Plots
            
            x_vals = [d.threshold for d in sparsification_data]
            y_vals = [d.sparsity_gain for d in sparsification_data]
            
            p = plot(x_vals, y_vals,
                    xlabel="Sparsification Threshold",
                    ylabel="Sparsity Gain", 
                    title="Sparsification Analysis",
                    xscale=:log10,
                    linewidth=2,
                    marker=:circle,
                    markersize=4)
            
            test_output_dir = "Examples/4d_benchmark_tests/debug_output"
            savefig(p, joinpath(test_output_dir, "sparsification_test.png"))
            
            println("✅ Sparsification plot created successfully")
            println("  Saved to: $(joinpath(test_output_dir, "sparsification_test.png"))")
        end
        
    catch e
        println("❌ Sparsification plotting failed: $e")
    end
    
else
    println("❌ No plotting backend available - cannot test sparsification plotting")
end

# ============================================================================
# STEP 3E: Create Fallback Text Visualization
# ============================================================================

println("\n📊 Step 3E: Fallback Text Visualization")
println("-" ^ 40)

function create_text_sparsification_report(sparsification_data, title="Sparsification Analysis")
    """Create a detailed text report of sparsification analysis"""
    
    println("\n$title")
    println("=" * length(title))
    
    if isempty(sparsification_data)
        println("No sparsification data available")
        return
    end
    
    println("\nDetailed Results:")
    println("Threshold".ljust(12) * "Orig NNZ".ljust(10) * "New NNZ".ljust(10) * "Sparsity%".ljust(12) * "L2 Ratio".ljust(12))
    println("-" ^ 70)
    
    for data in sparsification_data
        thresh_str = @sprintf("%.0e", data.threshold)
        sparsity_str = @sprintf("%.1f%%", data.sparsity_gain * 100)
        l2_str = @sprintf("%.4f", data.l2_ratio)
        
        println("$(thresh_str.ljust(12))$(data.original_nnz)".ljust(10) * 
                "$(data.new_nnz)".ljust(10) * 
                "$(sparsity_str.ljust(12))$(l2_str.ljust(12))")
    end
    
    # Summary statistics
    println("\nSummary:")
    max_sparsity = maximum([d.sparsity_gain for d in sparsification_data])
    min_l2_ratio = minimum([d.l2_ratio for d in sparsification_data])
    
    println("  Maximum sparsity achieved: $(max_sparsity * 100)%")
    println("  Minimum L2 ratio preserved: $min_l2_ratio")
    println("  Coefficient reduction range: $(sparsification_data[1].original_nnz) → $(sparsification_data[end].new_nnz)")
end

# Test text visualization
if !isempty(sparsification_data)
    create_text_sparsification_report(sparsification_data, "3D Test Function Sparsification")
end

println("\n✅ Step 3 Debugging Complete")
println("Summary:")
println("  - Available plotting packages: $available_packages")
println("  - Plotting functional: $(plotting_success ? "✅ Yes ($used_backend)" : "❌ No")")
println("  - Text visualization: ✅ Always available")
println("  - Output directory: Examples/4d_benchmark_tests/debug_output")

if !plotting_success
    println("\n💡 Recommendation:")
    println("  Install a plotting package for full visualization capability:")
    println("  using Pkg; Pkg.add(\"CairoMakie\")")
    println("  Then restart Julia and re-run the tests.")
end
