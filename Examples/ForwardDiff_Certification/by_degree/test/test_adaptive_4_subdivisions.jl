# Test adaptive analysis with 4 subdivisions (robust plotting)

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim

using Statistics, Printf, LinearAlgebra, Dates
using DataFrames, CSV
using DynamicPolynomials, Optim, ForwardDiff
using PrettyTables
using CairoMakie  # Use CairoMakie instead of GLMakie for better stability

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

function test_four_subdivisions()
    @info "Testing adaptive analysis with 4 subdivisions" target_l2=L2_TOLERANCE_TARGET
    
    # Create 4 corner subdomains
    subdivisions = [
        Subdomain("0000", [-0.5, -0.5, -0.5, -0.5], SUBDOMAIN_RANGE, 
                 [(-1.0, 0.0), (-1.0, 0.0), (-1.0, 0.0), (-1.0, 0.0)]),
        Subdomain("0011", [-0.5, -0.5, 0.5, 0.5], SUBDOMAIN_RANGE,
                 [(-1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, 1.0)]),
        Subdomain("1100", [0.5, 0.5, -0.5, -0.5], SUBDOMAIN_RANGE,
                 [(0.0, 1.0), (0.0, 1.0), (-1.0, 0.0), (-1.0, 0.0)]),
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

# Generate summary table
function generate_test_summary_table(results::Dict)
    @info "Generating test summary table"
    
    table_data = Vector{Vector{Any}}()
    
    for label in sort(collect(keys(results)))
        subdomain_results = results[label]
        if !isempty(subdomain_results)
            best_l2 = minimum([r.l2_norm for r in subdomain_results])
            converged = any([r.converged for r in subdomain_results])
            convergence_degree = converged ? subdomain_results[findfirst([r.converged for r in subdomain_results])].degree : "None"
            total_runtime = sum([r.runtime_seconds for r in subdomain_results])
            degrees_tested = length(subdomain_results)
            
            push!(table_data, [
                label,
                degrees_tested,
                @sprintf("%.2e", best_l2),
                string(convergence_degree),
                converged ? "Yes" : "No",
                @sprintf("%.1f", total_runtime)
            ])
        end
    end
    
    headers = ["Subdomain", "Degrees", "Best L²-Norm", "Conv. Degree", "Converged", "Runtime(s)"]
    
    if !isempty(table_data)
        n_rows = length(table_data)
        n_cols = length(headers)
        table_matrix = Matrix{String}(undef, n_rows, n_cols)
        
        for (i, row) in enumerate(table_data)
            for (j, val) in enumerate(row)
                table_matrix[i, j] = string(val)
            end
        end
        
        pretty_table(
            table_matrix,
            header = headers,
            alignment = [:c, :c, :r, :c, :c, :r],
            title = "4 Subdivision Test Results"
        )
    end
end

# Simple robust plot
function plot_test_results_robust(results::Dict)
    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1],
        title = "L²-Norm Convergence: 4 Test Subdomains",
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10
    )
    
    colors = [:red, :blue, :green, :orange]
    
    plotted_count = 0
    for (i, (label, subdomain_results)) in enumerate(sort(collect(results)))
        if !isempty(subdomain_results)
            degrees = [r.degree for r in subdomain_results]
            l2_norms = [r.l2_norm for r in subdomain_results]
            
            # Filter valid data
            valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
            if !isempty(valid_indices)
                valid_degrees = degrees[valid_indices]
                valid_l2_norms = l2_norms[valid_indices]
                
                scatterlines!(ax, valid_degrees, valid_l2_norms, 
                            color = colors[min(i, length(colors))], 
                            markersize = 8, linewidth = 2,
                            label = label)
                plotted_count += 1
            end
        end
    end
    
    # Add target line
    hlines!(ax, [L2_TOLERANCE_TARGET], color = :black, linestyle = :dash, linewidth = 2)
    
    # Add grid
    ax.xgridvisible = true
    ax.ygridvisible = true
    
    # Legend below plot
    if plotted_count > 0
        try
            Legend(fig[2, 1], ax, orientation = :horizontal, framevisible = true)
        catch e
            @warn "Legend creation failed, continuing without legend" exception=e
        end
    end
    
    @info "Test plot generation complete" plotted_subdivisions=plotted_count
    return fig
end

# Run test
@info "Starting 4-subdivision adaptive test"
results = test_four_subdivisions()

# Generate summary
@info "Test Analysis Summary"
for (label, subdomain_results) in results
    if !isempty(subdomain_results)
        best_l2 = minimum([r.l2_norm for r in subdomain_results])
        converged = any([r.converged for r in subdomain_results])
        total_runtime = sum([r.runtime_seconds for r in subdomain_results])
        
        @info "Subdomain $label summary" best_l2_norm=@sprintf("%.2e", best_l2) converged=converged total_runtime=@sprintf("%.1f", total_runtime)
    end
end

# Generate table
generate_test_summary_table(results)

# Display plot
try
    fig = plot_test_results_robust(results)
    display(fig)
    @info "Test plot displayed successfully"
catch e
    @warn "Test plotting failed: $e"
end

@info "4-subdivision adaptive test complete"