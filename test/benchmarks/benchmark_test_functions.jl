# Benchmark Test Functions for Sparse Re-optimization Validation
# Focus: 3D and 4D examples with varying sparsity characteristics

"""
Get test functions for specified dimension with metadata.

Returns: Vector of (name, function, expected_sparsity, category)
"""
function get_test_functions(dim::Int)
    if dim == 3
        return get_3d_test_functions()
    elseif dim == 4
        return get_4d_test_functions()
    else
        error("Only 3D and 4D test functions implemented")
    end
end

# ============================================================================
# 3D TEST FUNCTIONS
# ============================================================================

function get_3d_test_functions()
    return [
        # Category 1: Naturally Sparse (exact polynomials)
        (
            name = "3D_poly_x4",
            func = x -> x[1]^4 + x[2]^4 + x[3]^4,
            expected_sparsity = 0.10,
            category = :sparse_polynomial,
            description = "Sum of 4th powers - naturally sparse"
        ),

        (
            name = "3D_poly_x2y2",
            func = x -> x[1]^2 * x[2]^2 + x[2]^2 * x[3]^2 + x[1]^2 * x[3]^2,
            expected_sparsity = 0.15,
            category = :sparse_polynomial,
            description = "Pairwise products - tensor structure"
        ),

        (
            name = "3D_sphere",
            func = x -> (x[1]^2 + x[2]^2 + x[3]^2 - 1)^2,
            expected_sparsity = 0.20,
            category = :sparse_polynomial,
            description = "Sphere constraint - quadratic then squared"
        ),

        # Category 2: Dense Expansions (smooth functions)
        (
            name = "3D_runge",
            func = x -> 1 / (1 + 25*(x[1]^2 + x[2]^2 + x[3]^2)),
            expected_sparsity = 0.60,
            category = :dense_smooth,
            description = "3D Runge function - moderately dense"
        ),

        (
            name = "3D_exp_product",
            func = x -> exp(x[1] * x[2] * x[3]),
            expected_sparsity = 0.80,
            category = :dense_smooth,
            description = "Exponential product - very dense"
        ),

        (
            name = "3D_oscillatory",
            func = x -> sin(2π*x[1]) * cos(2π*x[2]) * sin(2π*x[3]),
            expected_sparsity = 0.70,
            category = :dense_smooth,
            description = "Oscillatory product - dense Chebyshev expansion"
        ),

        # Category 3: Multi-scale (for local refinement testing)
        (
            name = "3D_multiscale_peak",
            func = x -> sin(2π*x[1]) * sin(2π*x[2]) * sin(2π*x[3]) +
                       5*exp(-50*(x[1]^2 + x[2]^2 + x[3]^2)),
            expected_sparsity = 0.50,
            category = :multiscale,
            description = "Smooth background + localized peak"
        ),

        (
            name = "3D_quadratic_peak",
            func = x -> x[1]^2 + x[2]^2 + x[3]^2 +
                       10*exp(-100*((x[1]-0.5)^2 + (x[2]-0.5)^2 + (x[3]-0.5)^2)),
            expected_sparsity = 0.40,
            category = :multiscale,
            description = "Quadratic + sharp peak - local refinement target"
        ),

        # Category 4: Challenging cases
        (
            name = "3D_rosenbrock",
            func = x -> 100*(x[2] - x[1]^2)^2 + (1 - x[1])^2 +
                       100*(x[3] - x[2]^2)^2 + (1 - x[2])^2,
            expected_sparsity = 0.25,
            category = :challenging,
            description = "3D Rosenbrock - narrow valley, moderate sparsity"
        ),

        (
            name = "3D_ackley",
            func = x -> begin
                a, b, c = 20, 0.2, 2π
                d = 3
                sum_sq = sum(xi^2 for xi in x)
                sum_cos = sum(cos(c*xi) for xi in x)
                -a * exp(-b * sqrt(sum_sq/d)) - exp(sum_cos/d) + a + exp(1)
            end,
            expected_sparsity = 0.75,
            category = :challenging,
            description = "3D Ackley - highly oscillatory"
        ),
    ]
end

# ============================================================================
# 4D TEST FUNCTIONS
# ============================================================================

function get_4d_test_functions()
    return [
        # Category 1: Naturally Sparse
        (
            name = "4D_poly_x4",
            func = x -> sum(x[i]^4 for i in 1:4),
            expected_sparsity = 0.05,
            category = :sparse_polynomial,
            description = "Sum of 4th powers - additive separable"
        ),

        (
            name = "4D_poly_pairs",
            func = x -> x[1]^2 * x[2]^2 + x[3]^2 * x[4]^2,
            expected_sparsity = 0.10,
            category = :sparse_polynomial,
            description = "Paired interactions - block structure"
        ),

        (
            name = "4D_hypersphere",
            func = x -> (sum(x[i]^2 for i in 1:4) - 1)^2,
            expected_sparsity = 0.15,
            category = :sparse_polynomial,
            description = "4D hypersphere constraint"
        ),

        # Category 2: Dense Expansions
        (
            name = "4D_runge",
            func = x -> 1 / (1 + 25*sum(x[i]^2 for i in 1:4)),
            expected_sparsity = 0.50,
            category = :dense_smooth,
            description = "4D Runge function - will be dense"
        ),

        (
            name = "4D_exp_chain",
            func = x -> exp(sum(x[i]*x[i+1] for i in 1:3)),
            expected_sparsity = 0.70,
            category = :dense_smooth,
            description = "Chained exponential interactions"
        ),

        (
            name = "4D_oscillatory_product",
            func = x -> prod(sin(π*x[i]) for i in 1:4),
            expected_sparsity = 0.75,
            category = :dense_smooth,
            description = "Product of sines - very dense"
        ),

        # Category 3: Multi-scale
        (
            name = "4D_multiscale_additive",
            func = x -> sum(sin(2π*x[i]) for i in 1:4) +
                       5*exp(-50*sum(x[i]^2 for i in 1:4)),
            expected_sparsity = 0.45,
            category = :multiscale,
            description = "Additive oscillations + Gaussian peak"
        ),

        (
            name = "4D_quadratic_peak",
            func = x -> sum(x[i]^2 for i in 1:4) +
                       10*exp(-100*sum((x[i]-0.3)^2 for i in 1:4)),
            expected_sparsity = 0.35,
            category = :multiscale,
            description = "Quadratic bowl + sharp feature"
        ),

        # Category 4: Challenging cases
        (
            name = "4D_rastrigin",
            func = x -> begin
                A = 10
                n = 4
                A*n + sum(xi^2 - A*cos(2π*xi) for xi in x)
            end,
            expected_sparsity = 0.60,
            category = :challenging,
            description = "4D Rastrigin - many local minima"
        ),

        (
            name = "4D_griewank",
            func = x -> begin
                sum_term = sum(xi^2 for xi in x) / 4000
                prod_term = prod(cos(xi / sqrt(i)) for (i, xi) in enumerate(x))
                sum_term - prod_term + 1
            end,
            expected_sparsity = 0.65,
            category = :challenging,
            description = "4D Griewank - product-sum interaction"
        ),
    ]
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
Generate test grid for error evaluation.
"""
function generate_test_grid(dim::Int, n_per_dim::Int=10)
    # Gauss-Lobatto points for better coverage
    nodes_1d = [cos(π * i / (n_per_dim - 1)) for i in 0:(n_per_dim-1)]

    # Generate tensor product grid
    if dim == 1
        return [[x] for x in nodes_1d]
    elseif dim == 2
        return [[x, y] for x in nodes_1d for y in nodes_1d]
    elseif dim == 3
        return [[x, y, z] for x in nodes_1d for y in nodes_1d for z in nodes_1d]
    elseif dim == 4
        return [[x, y, z, w] for x in nodes_1d for y in nodes_1d
                for z in nodes_1d for w in nodes_1d]
    else
        error("Dimension $dim not supported")
    end
end

"""
Generate random test points for Monte Carlo evaluation.
"""
function generate_random_test_points(dim::Int, n_points::Int=1000)
    return [2 * rand(dim) .- 1 for _ in 1:n_points]  # Uniform in [-1, 1]^d
end

"""
Compute comprehensive error metrics.
"""
function compute_error_metrics(f::Function, poly, test_points::Vector)
    errors = [abs(f(pt) - poly(pt...)) for pt in test_points]

    return (
        max_error = maximum(errors),
        mean_error = mean(errors),
        median_error = median(errors),
        std_error = std(errors),
        rmse = sqrt(mean(errors.^2))
    )
end

"""
Test if function is well-approximated (sanity check).
"""
function verify_approximation_quality(f::Function, pol, dim::Int; max_error_threshold=0.1)
    test_points = generate_test_grid(dim, 10)
    errors = [abs(f(pt) - pol(pt...)) for pt in test_points]
    max_error = maximum(errors)

    if max_error > max_error_threshold
        @warn "Poor approximation quality detected!" max_error max_error_threshold
        return false
    end

    return true
end

"""
Get function category description.
"""
function get_category_description(category::Symbol)
    descriptions = Dict(
        :sparse_polynomial => "Naturally sparse in monomial basis",
        :dense_smooth => "Dense expansion from smooth functions",
        :multiscale => "Multiple length scales (for local refinement)",
        :challenging => "Difficult optimization landscapes"
    )

    return get(descriptions, category, "Unknown category")
end

"""
Print test function summary.
"""
function print_test_functions_summary(dim::Int)
    funcs = get_test_functions(dim)

    println("=" ^70)
    println("$(dim)D Test Functions Summary")
    println("=" ^70)
    println("Total functions: $(length(funcs))")
    println()

    categories = unique([f.category for f in funcs])

    for cat in categories
        cat_funcs = filter(f -> f.category == cat, funcs)
        println("Category: $cat ($(length(cat_funcs)) functions)")
        println("  Description: $(get_category_description(cat))")

        for f in cat_funcs
            println("    • $(f.name)")
            println("      $(f.description)")
            println("      Expected sparsity: $(round(f.expected_sparsity*100, digits=1))%")
        end
        println()
    end
end

# ============================================================================
# EXPORT
# ============================================================================

export get_test_functions,
       get_3d_test_functions,
       get_4d_test_functions,
       generate_test_grid,
       generate_random_test_points,
       compute_error_metrics,
       verify_approximation_quality,
       print_test_functions_summary
