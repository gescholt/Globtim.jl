# AbstractPlottingInterfaces.jl
# 
# Abstract interfaces for plotting data that will be used by GlobtimPlots.jl
# This module defines clean, minimal interfaces without dependencies on Globtim internals

"""
Abstract interface for polynomial approximation data used in plotting.
GlobtimPlots will work with implementations of this interface.
"""
abstract type AbstractPolynomialData end

"""
Essential methods that any polynomial data implementation must provide for plotting.
"""
function get_coefficients(::AbstractPolynomialData) end
function get_degree(::AbstractPolynomialData) end  
function get_grid_points(::AbstractPolynomialData) end
function get_function_values(::AbstractPolynomialData) end
function get_basis_type(::AbstractPolynomialData) end
function get_scale_factor(::AbstractPolynomialData) end
function get_domain_center(::AbstractPolynomialData) end

"""
Abstract interface for problem domain configuration.
"""
abstract type AbstractProblemData end

"""
Essential methods for problem domain information.
"""
function get_dimension(::AbstractProblemData) end
function get_center_point(::AbstractProblemData) end
function get_sample_range(::AbstractProblemData) end
function get_objective_function(::AbstractProblemData) end

"""
Abstract interface for critical point analysis data.
"""
abstract type AbstractCriticalPointData end

"""
Methods for critical point data access.
"""
function get_coordinates(::AbstractCriticalPointData) end
function get_function_values(::AbstractCriticalPointData) end
function get_point_types(::AbstractCriticalPointData) end
function get_convergence_info(::AbstractCriticalPointData) end

"""
Abstract interface for level set visualization data.
"""
abstract type AbstractLevelSetData end

"""
Methods for level set data.
"""
function get_level_points(::AbstractLevelSetData) end
function get_level_values(::AbstractLevelSetData) end
function get_target_level(::AbstractLevelSetData) end

"""
Configuration interface for plotting parameters.
"""
abstract type AbstractPlotConfig end

"""
Standard plot configuration methods.
"""
function get_figure_size(::AbstractPlotConfig) end
function get_color_scheme(::AbstractPlotConfig) end
function get_contour_levels(::AbstractPlotConfig) end
function get_plot_style(::AbstractPlotConfig) end

# Concrete implementations for migration testing
"""
Generic implementation of polynomial data interface for testing.
"""
struct GenericPolynomialData <: AbstractPolynomialData
    coefficients::Vector{<:Number}
    degree::Int
    grid_points::Matrix{Float64}
    function_values::Vector{Float64}
    basis_type::Symbol
    scale_factor::Union{Float64, Vector{Float64}}
    domain_center::Vector{Float64}
end

# Implement interface methods for generic type
get_coefficients(p::GenericPolynomialData) = p.coefficients
get_degree(p::GenericPolynomialData) = p.degree
get_grid_points(p::GenericPolynomialData) = p.grid_points
get_function_values(p::GenericPolynomialData) = p.function_values
get_basis_type(p::GenericPolynomialData) = p.basis_type
get_scale_factor(p::GenericPolynomialData) = p.scale_factor
get_domain_center(p::GenericPolynomialData) = p.domain_center

"""
Generic problem data implementation.
"""
struct GenericProblemData <: AbstractProblemData
    dimension::Int
    center_point::Vector{Float64}
    sample_range::Union{Float64, Vector{Float64}}
    objective_function::Function
end

get_dimension(p::GenericProblemData) = p.dimension
get_center_point(p::GenericProblemData) = p.center_point
get_sample_range(p::GenericProblemData) = p.sample_range
get_objective_function(p::GenericProblemData) = p.objective_function

"""
Generic plot configuration.
"""
struct GenericPlotConfig <: AbstractPlotConfig
    figure_size::Tuple{Int, Int}
    color_scheme::Symbol
    contour_levels::Int
    plot_style::Dict{Symbol, Any}
end

get_figure_size(c::GenericPlotConfig) = c.figure_size
get_color_scheme(c::GenericPlotConfig) = c.color_scheme
get_contour_levels(c::GenericPlotConfig) = c.contour_levels
get_plot_style(c::GenericPlotConfig) = c.plot_style

# Default configurations
function default_plot_config()
    GenericPlotConfig(
        (800, 600),
        :viridis,
        30,
        Dict(:line_width => 2, :marker_size => 8)
    )
end

export AbstractPolynomialData, AbstractProblemData, AbstractCriticalPointData, 
       AbstractLevelSetData, AbstractPlotConfig,
       GenericPolynomialData, GenericProblemData, GenericPlotConfig,
       get_coefficients, get_degree, get_grid_points, get_function_values,
       get_basis_type, get_scale_factor, get_domain_center,
       get_dimension, get_center_point, get_sample_range, get_objective_function,
       default_plot_config