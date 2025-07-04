# Step 3: Table Formatting & Display Improvements
#
# This implementation demonstrates professional table formatting using PrettyTables.jl
# for the 4D Deuflhard analysis results.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
using PrettyTables

# Include Step 1 components
include("step1_bfgs_enhanced.jl")

# ================================================================================
# TABLE FORMATTING CONFIGURATION
# ================================================================================

# Color scheme for better visual hierarchy
const TABLE_COLORS = Dict(
    :header => crayon"bold white bg:blue",
    :subheader => crayon"bold",
    :highlight => crayon"bold yellow",
    :good => crayon"green",
    :warning => crayon"yellow",
    :error => crayon"red"
)

# ================================================================================
# CRITICAL POINTS SUMMARY TABLE
# ================================================================================

function format_critical_points_table(points, values, labels, degrees, norms; n_show=10)
    n_display = min(n_show, length(points))
    sort_idx = sortperm(values)
    
    # Prepare data for table
    data_matrix = Matrix{Any}(undef, n_display, 8)
    
    for i in 1:n_display
        idx = sort_idx[i]
        point = points[idx]
        dist_to_global = norm(point - EXPECTED_GLOBAL_MIN)
        
        data_matrix[i, :] = [
            i,                                                    # Rank
            labels[idx],                                         # Orthant
            @sprintf("%.6f", point[1]),                         # x1
            @sprintf("%.6f", point[2]),                         # x2  
            @sprintf("%.6f", point[3]),                         # x3
            @sprintf("%.6f", point[4]),                         # x4
            @sprintf("%.8f", values[idx]),                      # Function Value
            @sprintf("%.3e", dist_to_global)                    # Distance to Global
        ]
    end
    
    # Create and display table
    header = ["Rank", "Orthant", "x₁", "x₂", "x₃", "x₄", "Function Value", "Dist. to Global"]
    
    println("\n")
    pretty_table(
        data_matrix, 
        header=header,
        header_crayon=TABLE_COLORS[:header],
        alignment=[:center, :center, :right, :right, :right, :right, :right, :right],
        crop=:none,
        linebreaks=true,
        autowrap=true,
        title="TOP $n_display CRITICAL POINTS (Raw Polynomial Results)",
        title_crayon=crayon"bold"
    )
    
    # Add summary statistics below table
    println("\nSummary Statistics:")
    println("  • Total unique points: $(length(points))")
    println("  • Average polynomial degree: $(Printf.@sprintf("%.1f", mean(degrees)))")
    println("  • Average L²-norm: $(Printf.@sprintf("%.2e", mean(norms)))")
end

# ================================================================================
# BFGS REFINEMENT RESULTS TABLE
# ================================================================================

function format_bfgs_results_table(bfgs_results::Vector{BFGSResult})
    n_results = length(bfgs_results)
    data_matrix = Matrix{Any}(undef, n_results, 9)
    
    for (i, result) in enumerate(bfgs_results)
        convergence_symbol = result.converged ? "✓" : "✗"
        convergence_color = result.converged ? TABLE_COLORS[:good] : TABLE_COLORS[:error]
        
        tolerance_type = occursin("high_precision", result.tolerance_selection_reason) ? "HP" : "STD"
        
        # Color code improvements
        improvement_str = @sprintf("%.2e", result.value_improvement)
        if result.value_improvement > 1e-3
            improvement_str = string(crayon"green") * improvement_str * string(crayon"reset")
        end
        
        data_matrix[i, :] = [
            i,                                          # Rank
            result.orthant_label,                       # Orthant
            @sprintf("%.8f", result.initial_value),     # Initial Value
            @sprintf("%.8f", result.refined_value),     # Refined Value  
            improvement_str,                            # Value Improvement (colored)
            result.iterations_used,                     # BFGS Iterations
            @sprintf("%.2e", result.final_grad_norm),   # Final Gradient Norm
            tolerance_type,                             # Tolerance Type
            string(convergence_color) * convergence_symbol * string(crayon"reset")  # Converged Status (colored)
        ]
    end
    
    header = ["#", "Orthant", "Initial Value", "Refined Value", "Improvement", 
              "Iters", "Grad Norm", "Tol", "Conv"]
    
    println("\n")
    pretty_table(
        data_matrix,
        header=header,
        header_crayon=TABLE_COLORS[:header],
        alignment=[:center, :center, :right, :right, :right, :center, :right, :center, :center],
        crop=:none,
        title="BFGS REFINEMENT RESULTS",
        title_crayon=crayon"bold"
    )
    
    # Summary statistics with colored indicators
    avg_improvement = mean([r.value_improvement for r in bfgs_results])
    avg_grad_norm = mean([r.final_grad_norm for r in bfgs_results])
    convergence_rate = count([r.converged for r in bfgs_results]) / n_results * 100
    
    println("\nBFGS Summary Statistics:")
    println("  • Average value improvement: $(Printf.@sprintf("%.2e", avg_improvement))")
    
    grad_color = avg_grad_norm < 1e-8 ? TABLE_COLORS[:good] : TABLE_COLORS[:warning]
    println("  • Average final gradient norm: " * string(grad_color) * 
            Printf.@sprintf("%.2e", avg_grad_norm) * string(crayon"reset"))
    
    conv_color = convergence_rate == 100 ? TABLE_COLORS[:good] : TABLE_COLORS[:warning]
    println("  • Convergence rate: " * string(conv_color) * 
            Printf.@sprintf("%.1f", convergence_rate) * "%" * string(crayon"reset"))
end

# ================================================================================
# ORTHANT DISTRIBUTION ANALYSIS TABLE
# ================================================================================

function format_orthant_distribution_table(all_orthants, unique_labels, unique_values, unique_degrees)
    n_orthants = length(all_orthants)
    data_matrix = Matrix{Any}(undef, n_orthants, 6)
    
    # Count total points for percentage calculation
    total_points = length(unique_values)
    
    for (i, (signs, label)) in enumerate(all_orthants)
        # Find points in this orthant
        mask = unique_labels .== label
        n_points = sum(mask)
        
        if n_points > 0
            orthant_values = unique_values[mask]
            orthant_degrees = unique_degrees[mask]
            best_value = minimum(orthant_values)
            avg_degree = mean(orthant_degrees)
            
            # Color-coded status
            status_str = if best_value < -1.5
                string(TABLE_COLORS[:good]) * "✓ Global candidate" * string(crayon"reset")
            elseif n_points > 2
                string(TABLE_COLORS[:highlight]) * "Multiple found" * string(crayon"reset")
            elseif n_points > 0
                "Points found"
            else
                string(TABLE_COLORS[:error]) * "Empty" * string(crayon"reset")
            end
        else
            best_value = NaN
            avg_degree = NaN
            status_str = string(crayon"dark_gray") * "Empty" * string(crayon"reset")
        end
        
        # Color code point count
        count_str = if n_points == 0
            string(crayon"dark_gray") * string(n_points) * string(crayon"reset")
        elseif n_points > 2
            string(crayon"bold") * string(n_points) * string(crayon"reset")
        else
            string(n_points)
        end
        
        data_matrix[i, :] = [
            label,                                              # Orthant
            count_str,                                          # Points Found (colored)
            isnan(best_value) ? string(crayon"dark_gray") * "—" * string(crayon"reset") : 
                @sprintf("%.6f", best_value),                   # Best Value
            isnan(avg_degree) ? string(crayon"dark_gray") * "—" * string(crayon"reset") : 
                @sprintf("%.1f", avg_degree),                   # Avg Degree
            status_str,                                         # Status (colored)
            @sprintf("%.1f%%", n_points/total_points*100)      # Coverage %
        ]
    end
    
    header = ["Orthant", "Points", "Best Value", "Avg Degree", "Status", "Coverage"]
    
    println("\n")
    pretty_table(
        data_matrix,
        header=header,
        header_crayon=TABLE_COLORS[:header],
        alignment=[:center, :center, :right, :right, :left, :right],
        crop=:none,
        title="ORTHANT DISTRIBUTION ANALYSIS",
        title_crayon=crayon"bold"
    )
    
    # Summary footer
    covered_orthants = count(row -> !occursin("Empty", string(row[5])), eachrow(data_matrix))
    println("\nOrthant Coverage: $covered_orthants/16 orthants contain critical points")
end

# ================================================================================
# COMPREHENSIVE SUMMARY DASHBOARD
# ================================================================================

function format_analysis_summary_table(
    n_total, n_unique, n_refined, 
    best_raw_val, best_refined_val,
    avg_degree, avg_l2_norm, target_l2,
    global_found=false
)
    
    # Create sections with visual separators
    sections = [
        ("Point Statistics", [
            ("Total Points Found", string(n_total)),
            ("Unique After Dedup", string(n_unique)),
            ("Successfully Refined", string(n_refined))
        ]),
        ("Optimization Results", [
            ("Best Raw Value", @sprintf("%.8f", best_raw_val)),
            ("Best Refined Value", @sprintf("%.8f", best_refined_val)),
            ("Total Improvement", @sprintf("%.2e", best_raw_val - best_refined_val))
        ]),
        ("Polynomial Quality", [
            ("Avg Polynomial Degree", @sprintf("%.1f", avg_degree)),
            ("Avg L²-norm", @sprintf("%.2e", avg_l2_norm)),
            ("Target L²-norm", @sprintf("%.2e", target_l2)),
            ("L²-norm Compliance", avg_l2_norm ≤ target_l2 ? 
                string(TABLE_COLORS[:good]) * "✓ Pass" * string(crayon"reset") : 
                string(TABLE_COLORS[:error]) * "✗ Fail" * string(crayon"reset"))
        ]),
        ("Global Minimum Status", [
            ("Expected Minimum Found", global_found ? 
                string(TABLE_COLORS[:good]) * "✓ Yes" * string(crayon"reset") : 
                string(TABLE_COLORS[:warning]) * "⚠ No" * string(crayon"reset"))
        ])
    ]
    
    println("\n")
    println(string(crayon"bold") * "="^70 * string(crayon"reset"))
    println(string(crayon"bold") * " "^20 * "COMPREHENSIVE ANALYSIS SUMMARY" * string(crayon"reset"))
    println(string(crayon"bold") * "="^70 * string(crayon"reset"))
    
    for (section_name, items) in sections
        println("\n" * string(crayon"bold underline") * section_name * string(crayon"reset"))
        
        for (metric, value) in items
            # Right-align metrics and left-align values
            println(@sprintf("  %-30s %s", metric * ":", value))
        end
    end
    
    println("\n" * string(crayon"bold") * "="^70 * string(crayon"reset"))
end

# ================================================================================
# DEMONSTRATION WITH SAMPLE DATA
# ================================================================================

println("="^80)
println("STEP 3: TABLE FORMATTING DEMONSTRATION")
println("="^80)

# Generate sample data for demonstration
println("\nGenerating sample data for table demonstrations...")

# Sample critical points
sample_points = [
    [-0.7412, 0.7412, -0.7412, 0.7412],   # Near global minimum
    [0.0, 0.0, 0.0, 0.0],                  # Origin
    [0.5, -0.5, 0.5, -0.5],                # Other point
    [-0.3, 0.3, -0.3, 0.3],                # Another point
    [0.7, 0.7, -0.7, -0.7],                # Different orthant
    [-0.1, -0.1, 0.1, 0.1]                 # Small values
]

sample_values = [deuflhard_4d_composite(p) for p in sample_points]
sample_labels = ["(-,+,-,+)", "(+,+,+,+)", "(+,-,+,-)", "(-,+,-,+)", "(+,+,-,-)", "(-,-,+,+)"]
sample_degrees = [6, 8, 7, 8, 6, 7]
sample_norms = [0.0006, 0.0007, 0.0005, 0.0007, 0.0006, 0.0005]

# Demo 1: Critical Points Table
println("\n1. Critical Points Summary Table:")
format_critical_points_table(sample_points, sample_values, sample_labels, 
                           sample_degrees, sample_norms, n_show=5)

# Demo 2: BFGS Results Table
println("\n2. BFGS Refinement Results:")

# Create sample BFGS results
config = BFGSConfig(show_trace=false, track_hyperparameters=false)
bfgs_results = enhanced_bfgs_refinement(
    sample_points[1:4],
    sample_values[1:4],
    sample_labels[1:4],
    deuflhard_4d_composite,
    config
)

format_bfgs_results_table(bfgs_results)

# Demo 3: Orthant Distribution
println("\n3. Orthant Distribution Analysis:")

# Generate all orthants
all_orthants = []
for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
    signs = [s1, s2, s3, s4]
    label = "(" * join([s > 0 ? '+' : '-' for s in signs], ",") * ")"
    push!(all_orthants, (signs, label))
end

format_orthant_distribution_table(all_orthants, sample_labels, sample_values, sample_degrees)

# Demo 4: Summary Dashboard
println("\n4. Comprehensive Summary Dashboard:")

format_analysis_summary_table(
    20,      # n_total
    6,       # n_unique
    4,       # n_refined
    minimum(sample_values),  # best_raw
    minimum([r.refined_value for r in bfgs_results]),  # best_refined
    mean(sample_degrees),    # avg_degree
    mean(sample_norms),      # avg_l2_norm
    0.0007,  # target_l2
    true     # global_found
)

println("\n" * "="^80)
println("STEP 3 IMPLEMENTATION COMPLETE")
println("="^80)
println("\nKey achievements:")
println("✓ Professional table formatting with PrettyTables.jl")
println("✓ Color-coded status indicators and values")
println("✓ Comprehensive summary statistics")
println("✓ Visual hierarchy with sections and formatting")
println("✓ Adaptive content display (empty cells, NaN handling)")
println("✓ Export-ready tabular output")
println("\nThese formatted tables dramatically improve data readability")
println("and make analysis results more accessible and professional.")