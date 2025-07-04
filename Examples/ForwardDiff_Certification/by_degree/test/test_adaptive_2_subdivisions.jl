# Test adaptive analysis with just 2 subdivisions for faster validation

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim

using Statistics, Printf, LinearAlgebra, Dates
using DataFrames, CSV
using DynamicPolynomials, Optim, ForwardDiff
using PrettyTables
using GLMakie

# Parameters
const L2_TOLERANCE_TARGET = 5e-3
const DEGREE_MIN = 2
const DEGREE_MAX = 10
const INITIAL_GN = 5
const SUBDOMAIN_RANGE = 0.5

function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

struct Subdomain
    label::String
    center::Vector{Float64}
    range::Float64
    bounds::Vector{Tuple{Float64,Float64}}
end

function test_two_subdivisions()
    @info "Testing adaptive analysis with 2 subdivisions" target_l2=L2_TOLERANCE_TARGET
    
    # Create 2 test subdomains
    subdivisions = [
        Subdomain("0000", [-0.5, -0.5, -0.5, -0.5], SUBDOMAIN_RANGE, 
                 [(-1.0, 0.0), (-1.0, 0.0), (-1.0, 0.0), (-1.0, 0.0)]),
        Subdomain("1111", [0.5, 0.5, 0.5, 0.5], SUBDOMAIN_RANGE,
                 [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0)])
    ]
    
    results = Dict{String, Vector{NamedTuple}}()
    
    for subdomain in subdivisions
        @info "Processing subdomain $(subdomain.label)"
        
        subdomain_results = NamedTuple[]
        
        for degree in DEGREE_MIN:DEGREE_MAX
            @info "Testing degree $degree for subdomain $(subdomain.label)"
            
            start_time = time()
            
            try
                TR = test_input(deuflhard_4d_composite, dim=4,
                               center=subdomain.center, sample_range=subdomain.range,
                               GN=INITIAL_GN, reduce_samples=1.0)
                
                pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
                actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
                
                runtime = time() - start_time
                converged = pol.nrm <= L2_TOLERANCE_TARGET
                
                result = (
                    subdomain_label = subdomain.label,
                    degree = actual_degree,
                    gn = INITIAL_GN,
                    l2_norm = pol.nrm,
                    runtime_seconds = runtime,
                    converged = converged
                )
                
                push!(subdomain_results, result)
                
                status = converged ? "CONVERGED" : "not converged"
                @info "Subdomain $(subdomain.label), degree $degree completed" l2_norm=@sprintf("%.2e", pol.nrm) status=status runtime=@sprintf("%.1f", runtime)
                
                # Stop if converged
                if converged
                    @info "Subdomain $(subdomain.label) achieved target at degree $degree"
                    break
                end
                
            catch e
                @error "Subdomain $(subdomain.label), degree $degree failed" exception=e
                break
            end
        end
        
        results[subdomain.label] = subdomain_results
        @info "Subdomain $(subdomain.label) complete" degrees_tested=length(subdomain_results)
    end
    
    return results
end

# Generate summary
function generate_test_summary(results::Dict)
    @info "Test Analysis Summary"
    
    for (label, subdomain_results) in results
        if !isempty(subdomain_results)
            best_l2 = minimum([r.l2_norm for r in subdomain_results])
            converged = any([r.converged for r in subdomain_results])
            total_runtime = sum([r.runtime_seconds for r in subdomain_results])
            
            @info "Subdomain $label summary" best_l2_norm=@sprintf("%.2e", best_l2) converged=converged total_runtime=@sprintf("%.1f", total_runtime)
        end
    end
end

# Generate test plot
function plot_test_results(results::Dict)
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = "Test: L²-Norm Convergence (2 Subdomains)",
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10
    )
    
    colors = [:blue, :red]
    
    for (i, (label, subdomain_results)) in enumerate(results)
        if !isempty(subdomain_results)
            degrees = [r.degree for r in subdomain_results]
            l2_norms = [r.l2_norm for r in subdomain_results]
            
            scatterlines!(ax, degrees, l2_norms, 
                        color = colors[i], markersize = 8, linewidth = 2,
                        label = label)
        end
    end
    
    # Add target line
    hlines!(ax, [L2_TOLERANCE_TARGET], color = :black, linestyle = :dash, linewidth = 2, label = "Target")
    
    axislegend(ax)
    
    return fig
end

# Run test
@info "Starting 2-subdivision test"
results = test_two_subdivisions()

generate_test_summary(results)

# Display plot
try
    fig = plot_test_results(results)
    display(fig)
    @info "Test plot displayed successfully"
catch e
    @warn "Test plotting failed: $e"
end

@info "2-subdivision test complete"