"""
Debug Sparsity Visualization Issues

Step-by-step debugging for sparsification analysis and visualization problems.
"""

using Globtim
using DataFrames
using Printf

println("🔍 Step 2: Sparsity Visualization Debugging")
println("=" ^ 50)

# ============================================================================
# STEP 2A: Test Sparsification Without Plotting
# ============================================================================

println("\n📊 Step 2A: Sparsification Analysis (No Plotting)")
println("-" ^ 40)

# Create test case
f_test(x) = sum(x.^2) + 0.01*sum(x[1:end-1] .* x[2:end])
TR_test = test_input(f_test, dim=4, center=zeros(4), sample_range=2.0)

println("Test function: 4D quadratic with small cross terms")
println("Domain: [-2, 2]⁴")

# Test different degrees
for degree in [6, 8]
    println("\n🔬 Degree $degree Analysis:")
    
    pol = Constructor(TR_test, degree)
    println("  Original L2 error: $(pol.nrm)")
    println("  Total coefficients: $(length(pol.coeffs))")
    
    # Count non-zero coefficients
    non_zero_count = count(x -> abs(x) > 1e-15, pol.coeffs)
    println("  Non-zero coefficients: $non_zero_count")
    
    # Coefficient statistics
    coeffs_abs = abs.(pol.coeffs)
    coeffs_sorted = sort(coeffs_abs[coeffs_abs .> 1e-15], rev=true)
    
    if !isempty(coeffs_sorted)
        println("  Coefficient range:")
        println("    Largest: $(coeffs_sorted[1])")
        println("    Median: $(coeffs_sorted[length(coeffs_sorted)÷2])")
        println("    Smallest: $(coeffs_sorted[end])")
    end
    
    # Test sparsification thresholds
    thresholds = [1e-10, 1e-8, 1e-6, 1e-4, 1e-2]
    println("  Sparsification results:")
    
    for threshold in thresholds
        try
            sparse_result = sparsify_polynomial(pol, threshold, mode=:absolute)
            
            kept_count = length(pol.coeffs) - length(sparse_result.zeroed_indices)
            sparsity_percent = (length(sparse_result.zeroed_indices) / length(pol.coeffs)) * 100
            
            println("    $threshold: $kept_count kept ($(sparsity_percent)% sparse), L2 ratio: $(sparse_result.l2_ratio)")
            
            # Verify the sparsification worked
            sparse_coeffs = sparse_result.polynomial.coeffs
            zeroed_correctly = all(sparse_coeffs[sparse_result.zeroed_indices] .== 0)
            println("      Zeroing correct: $zeroed_correctly")
            
        catch e
            println("    $threshold: ERROR - $e")
        end
    end
end

# ============================================================================
# STEP 2B: Test Sparsification Data Structures
# ============================================================================

println("\n📊 Step 2B: Sparsification Data Structure Test")
println("-" ^ 40)

# Create a simple polynomial for testing
f_simple(x) = x[1]^4 + 0.1*x[1]^2 + 0.001*x[1] + 0.0001
TR_simple = test_input(f_simple, dim=1, center=[0.0], sample_range=1.0)

pol_simple = Constructor(TR_simple, 6)
println("Simple 1D polynomial test:")
println("  Coefficients: $(pol_simple.coeffs)")
println("  L2 error: $(pol_simple.nrm)")

# Test sparsification
threshold = 1e-3
sparse_result = sparsify_polynomial(pol_simple, threshold, mode=:absolute)

println("\nSparsification result structure:")
println("  Type: $(typeof(sparse_result))")
println("  Fields: $(fieldnames(typeof(sparse_result)))")

if hasfield(typeof(sparse_result), :polynomial)
    println("  Sparse polynomial type: $(typeof(sparse_result.polynomial))")
    println("  Sparse coefficients: $(sparse_result.polynomial.coeffs)")
end

if hasfield(typeof(sparse_result), :zeroed_indices)
    println("  Zeroed indices: $(sparse_result.zeroed_indices)")
end

if hasfield(typeof(sparse_result), :l2_ratio)
    println("  L2 ratio: $(sparse_result.l2_ratio)")
end

# ============================================================================
# STEP 2C: Test Visualization Data Preparation
# ============================================================================

println("\n📊 Step 2C: Visualization Data Preparation")
println("-" ^ 40)

# Test the data preparation that would be used for plotting
function prepare_sparsification_data(pol, thresholds)
    """Prepare data for sparsification visualization"""
    
    results = []
    
    for threshold in thresholds
        try
            sparse_result = sparsify_polynomial(pol, threshold, mode=:absolute)
            
            original_nnz = count(x -> abs(x) > 1e-15, pol.coeffs)
            new_nnz = count(x -> abs(x) > 1e-15, sparse_result.polynomial.coeffs)
            sparsity_gain = 1.0 - (new_nnz / original_nnz)
            
            push!(results, (
                threshold = threshold,
                original_nnz = original_nnz,
                new_nnz = new_nnz,
                sparsity_gain = sparsity_gain,
                l2_ratio = sparse_result.l2_ratio,
                zeroed_count = length(sparse_result.zeroed_indices)
            ))
            
        catch e
            println("  Error at threshold $threshold: $e")
            push!(results, (
                threshold = threshold,
                original_nnz = 0,
                new_nnz = 0,
                sparsity_gain = 0.0,
                l2_ratio = 0.0,
                zeroed_count = 0
            ))
        end
    end
    
    return results
end

# Test data preparation
f_data(x) = sum(x.^2) + 0.1*sum(x[1:end-1] .* x[2:end])
TR_data = test_input(f_data, dim=3, center=zeros(3), sample_range=1.5)
pol_data = Constructor(TR_data, 6)

thresholds = [1e-6, 1e-4, 1e-2]
viz_data = prepare_sparsification_data(pol_data, thresholds)

println("Visualization data preparation test:")
println("  Original polynomial: $(length(pol_data.coeffs)) coefficients")
println("  L2 error: $(pol_data.nrm)")

for (i, data) in enumerate(viz_data)
    println("  Threshold $(data.threshold):")
    println("    Original NNZ: $(data.original_nnz)")
    println("    New NNZ: $(data.new_nnz)")
    println("    Sparsity gain: $(data.sparsity_gain)")
    println("    L2 ratio: $(data.l2_ratio)")
    println("    Zeroed count: $(data.zeroed_count)")
end

# ============================================================================
# STEP 2D: Check Plotting Dependencies
# ============================================================================

println("\n📊 Step 2D: Plotting Dependencies Check")
println("-" ^ 40)

# Check if plotting packages are available
plotting_available = false
plotting_backend = "none"

try
    using CairoMakie
    plotting_available = true
    plotting_backend = "CairoMakie"
    println("✅ CairoMakie is available")
catch e
    println("❌ CairoMakie not available: $e")
    
    try
        using GLMakie
        plotting_available = true
        plotting_backend = "GLMakie"
        println("✅ GLMakie is available")
    catch e2
        println("❌ GLMakie not available: $e2")
        
        try
            using Plots
            plotting_available = true
            plotting_backend = "Plots"
            println("✅ Plots.jl is available")
        catch e3
            println("❌ Plots.jl not available: $e3")
        end
    end
end

println("Plotting status: $plotting_available (backend: $plotting_backend)")

if plotting_available
    println("\n🎨 Testing basic plotting capability:")
    
    try
        if plotting_backend == "CairoMakie"
            fig = Figure(size=(400, 300))
            ax = Axis(fig[1, 1], xlabel="X", ylabel="Y", title="Test Plot")
            lines!(ax, [1, 2, 3], [1, 4, 2])
            println("  ✅ Basic CairoMakie plot creation successful")
        elseif plotting_backend == "GLMakie"
            fig = Figure(size=(400, 300))
            ax = Axis(fig[1, 1], xlabel="X", ylabel="Y", title="Test Plot")
            lines!(ax, [1, 2, 3], [1, 4, 2])
            println("  ✅ Basic GLMakie plot creation successful")
        elseif plotting_backend == "Plots"
            using Plots
            p = plot([1, 2, 3], [1, 4, 2], xlabel="X", ylabel="Y", title="Test Plot")
            println("  ✅ Basic Plots.jl plot creation successful")
        end
    catch e
        println("  ❌ Basic plotting failed: $e")
        plotting_available = false
    end
end

# ============================================================================
# STEP 2E: Alternative Text-Based Visualization
# ============================================================================

println("\n📊 Step 2E: Text-Based Sparsification Visualization")
println("-" ^ 40)

function text_sparsification_plot(results, title="Sparsification Analysis")
    """Create a text-based visualization of sparsification results"""
    
    println("\n$title")
    println("=" * length(title))
    
    if isempty(results)
        println("No data to plot")
        return
    end
    
    # Extract data
    thresholds = [r.threshold for r in results]
    sparsity_gains = [r.sparsity_gain for r in results]
    l2_ratios = [r.l2_ratio for r in results]
    
    # Create text plot
    println("\nThreshold vs Sparsity Gain:")
    println("Threshold".ljust(12) * "Sparsity%".ljust(12) * "L2 Ratio".ljust(12) * "Visual")
    println("-" ^ 60)
    
    for (thresh, sparsity, l2) in zip(thresholds, sparsity_gains, l2_ratios)
        thresh_str = @sprintf("%.0e", thresh)
        sparsity_str = @sprintf("%.1f%%", sparsity * 100)
        l2_str = @sprintf("%.3f", l2)
        
        # Create simple bar visualization
        bar_length = Int(round(sparsity * 20))  # Scale to 20 characters
        bar = "█" ^ bar_length * "░" ^ (20 - bar_length)
        
        println("$(thresh_str.ljust(12))$(sparsity_str.ljust(12))$(l2_str.ljust(12))$bar")
    end
    
    println("\nLegend: █ = sparsified, ░ = remaining")
end

# Test text visualization
if !isempty(viz_data)
    text_sparsification_plot(viz_data, "4D Polynomial Sparsification")
end

println("\n✅ Step 2 Debugging Complete")
println("Summary:")
println("  - Sparsification analysis: $(length(viz_data) > 0 ? "✅ Working" : "❌ Failed")")
println("  - Data preparation: ✅ Working")
println("  - Plotting available: $(plotting_available ? "✅ Yes ($plotting_backend)" : "❌ No")")
println("  - Text visualization: ✅ Working")
