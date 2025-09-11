# GlobtimDataAdapters.jl
#
# Data adapters that convert existing Globtim types to abstract plotting interfaces
# These will help during manual migration - you can test interface compatibility
# before copying files to GlobtimPlots.jl

include("AbstractPlottingInterfaces.jl")
using .AbstractPlottingInterfaces
using DataFrames

"""
Adapter that wraps ApproxPoly to implement AbstractPolynomialData interface.
Use this to test plotting functions with the new interface.
"""
struct ApproxPolyAdapter <: AbstractPolynomialData
    wrapped::ApproxPoly
end

# Implement interface methods by delegating to ApproxPoly
get_coefficients(a::ApproxPolyAdapter) = a.wrapped.coeffs
get_degree(a::ApproxPolyAdapter) = a.wrapped.degree
get_grid_points(a::ApproxPolyAdapter) = a.wrapped.grid
get_function_values(a::ApproxPolyAdapter) = a.wrapped.z
get_basis_type(a::ApproxPolyAdapter) = a.wrapped.basis
get_scale_factor(a::ApproxPolyAdapter) = a.wrapped.scale_factor
get_domain_center(a::ApproxPolyAdapter) = length(a.wrapped.grid) > 0 ? vec(mean(a.wrapped.grid, dims=1)) : Float64[]

"""
Adapter for test_input to AbstractProblemData interface.
"""
struct TestInputAdapter <: AbstractProblemData
    wrapped::test_input
end

get_dimension(t::TestInputAdapter) = t.wrapped.dim
get_center_point(t::TestInputAdapter) = t.wrapped.center
get_sample_range(t::TestInputAdapter) = t.wrapped.sample_range
get_objective_function(t::TestInputAdapter) = t.wrapped.objective

"""
Adapter for DataFrame containing critical points.
"""
struct CriticalPointDataFrameAdapter <: AbstractCriticalPointData
    wrapped::DataFrame
    dimension::Int
end

function CriticalPointDataFrameAdapter(df::DataFrame)
    # Auto-detect dimension from column names (x1, x2, x3, ...)
    dim = count(col -> startswith(string(col), "x"), names(df))
    CriticalPointDataFrameAdapter(df, dim)
end

function get_coordinates(c::CriticalPointDataFrameAdapter)
    coords = Matrix{Float64}(undef, nrow(c.wrapped), c.dimension)
    for i in 1:c.dimension
        col_name = Symbol("x$i")
        if col_name in names(c.wrapped)
            coords[:, i] = c.wrapped[!, col_name]
        else
            error("Missing coordinate column: $col_name")
        end
    end
    return coords
end

get_function_values(c::CriticalPointDataFrameAdapter) = haskey(c.wrapped, :z) ? c.wrapped.z : Float64[]
get_point_types(c::CriticalPointDataFrameAdapter) = haskey(c.wrapped, :critical_point_type) ? c.wrapped.critical_point_type : Symbol[]
get_convergence_info(c::CriticalPointDataFrameAdapter) = haskey(c.wrapped, :convergence_info) ? c.wrapped.convergence_info : Dict[]

"""
Helper function to create adapters from common Globtim objects.
"""
function create_plot_adapters(pol::ApproxPoly, TR::test_input, df::DataFrame)
    poly_adapter = ApproxPolyAdapter(pol)
    problem_adapter = TestInputAdapter(TR)
    points_adapter = CriticalPointDataFrameAdapter(df)
    config = default_plot_config()
    
    return (
        polynomial = poly_adapter,
        problem = problem_adapter,
        critical_points = points_adapter,
        config = config
    )
end

"""
Test function to validate adapter interfaces work correctly.
"""
function test_adapters(pol::ApproxPoly, TR::test_input, df::DataFrame)
    adapters = create_plot_adapters(pol, TR, df)
    
    println("=== Adapter Interface Testing ===")
    
    # Test polynomial adapter
    println("Polynomial Data:")
    println("  Degree: $(get_degree(adapters.polynomial))")
    println("  Basis: $(get_basis_type(adapters.polynomial))")
    println("  Grid size: $(size(get_grid_points(adapters.polynomial)))")
    println("  Function values: $(length(get_function_values(adapters.polynomial)))")
    
    # Test problem adapter  
    println("Problem Data:")
    println("  Dimension: $(get_dimension(adapters.problem))")
    println("  Center: $(get_center_point(adapters.problem))")
    println("  Sample range: $(get_sample_range(adapters.problem))")
    
    # Test critical points adapter
    println("Critical Points Data:")
    coords = get_coordinates(adapters.critical_points)
    println("  Points: $(size(coords, 1)) points in $(size(coords, 2))D")
    println("  Has function values: $(length(get_function_values(adapters.critical_points)) > 0)")
    println("  Has point types: $(length(get_point_types(adapters.critical_points)) > 0)")
    
    println("✅ All adapters working correctly!")
    
    return adapters
end

"""
Generate sample data that matches the interface for testing GlobtimPlots functions.
"""
function generate_sample_plotting_data(dim::Int = 2, n_points::Int = 100)
    # Generate sample polynomial data
    grid = randn(n_points, dim)
    func_vals = [sum(x.^2) for x in eachrow(grid)]  # Simple quadratic
    
    poly_data = GenericPolynomialData(
        randn(10),  # coefficients
        4,          # degree
        grid,
        func_vals,
        :chebyshev,
        1.0,
        zeros(dim)
    )
    
    # Generate sample problem data
    problem_data = GenericProblemData(
        dim,
        zeros(dim),
        2.0,
        x -> sum(x.^2)
    )
    
    # Generate sample critical points
    n_crit = 20
    crit_coords = randn(n_crit, dim) * 0.5
    crit_df_dict = Dict{Symbol, Vector}()
    for i in 1:dim
        crit_df_dict[Symbol("x$i")] = crit_coords[:, i]
    end
    crit_df_dict[:z] = [sum(row.^2) for row in eachrow(crit_coords)]
    crit_df_dict[:critical_point_type] = rand([:minimum, :saddle, :maximum], n_crit)
    
    crit_df = DataFrame(crit_df_dict)
    crit_points = CriticalPointDataFrameAdapter(crit_df)
    
    return (
        polynomial = poly_data,
        problem = problem_data, 
        critical_points = crit_points,
        config = default_plot_config()
    )
end

export ApproxPolyAdapter, TestInputAdapter, CriticalPointDataFrameAdapter,
       create_plot_adapters, test_adapters, generate_sample_plotting_data