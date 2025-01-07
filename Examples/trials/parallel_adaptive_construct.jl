using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using DataStructures
using LinearAlgebra
using StaticArrays
using SharedArrays
using ModelingToolkit
using OrdinaryDiffEq
using DataFrames
using Distributed
using Globtim
using DynamicPolynomials

# Make sure all workers have access to everything they need
@everywhere begin
    using Globtim
    using DataFrames
    using DynamicPolynomials
    using LinearAlgebra
    using ModelingToolkit
    using OrdinaryDiffEq
    using DataStructures
    using StaticArrays

    const T = Float64
    const time_interval = T[0.0, 1.0]
    const p_true = T[0.11, 0.22, 0.33]
    const ic = T[0.11, 0.15]
    const num_points = 6
    const n = 3  # dimension of the problem

    # Include the model definition
    include("model_eval.jl")

    # Define model and error function on all workers
    model, params, states, outputs = define_lotka_volterra_model()
    error_func = make_error_distance(model, outputs, p_true, num_points)

    # Create polynomial variables on each worker
    @polyvar(x[1:n])

    function solve_and_parse(pol::ApproxPoly, f::Function, TR::test_input; kwargs...)
        output_file = msolve_polynomial_system(pol, x; kwargs...)
        df = msolve_parser(output_file, f, TR)
        return df
    end

    function parallel_adapt_legendre_constructor(T::test_input, degree::Int, f::Function)::DataFrame
        # Initial polynomial construction
        p = Constructor(T, degree, verbose=0, basis=:legendre)

        if p.nrm <= T.tolerance || degree == T.degree_max
            pol_lege = Constructor(T, degree, basis=:legendre)
            df = solve_and_parse(pol_lege, f, T, n=T.dim, basis=:legendre, bigint=true)
            return isempty(df) ? DataFrame() : df
        else
            # Subdivide domain and process recursively in parallel
            subdomains = subdivide_domain(T)

            # Process subdomains in parallel using remotecall_fetch
            futures = []
            for (i, subdomain) in enumerate(subdomains)
                worker = (i % nworkers()) + 1
                future = remotecall_fetch(
                    parallel_adapt_legendre_constructor,
                    worker,
                    subdomain, degree + 1, f
                )
                push!(futures, future)
            end

            # Combine non-empty results
            combined_data = DataFrame()
            for subdata in futures
                if !isempty(subdata)
                    if isempty(combined_data)
                        combined_data = subdata
                    else
                        # Ensure matching columns before appending
                        all_cols = union(names(combined_data), names(subdata))
                        for col in setdiff(all_cols, names(combined_data))
                            combined_data[!, col] .= missing
                        end
                        for col in setdiff(all_cols, names(subdata))
                            subdata[!, col] .= missing
                        end
                        append!(combined_data, subdata)
                    end
                end
            end

            return combined_data
        end
    end
end

p_center = p_true + [0.1, 0.0, 0.0]

TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=10,
    sample_range=1 // 8,
    degree_max=8,
    tolerance=2.0e-1
)

# Run parallel version
df = parallel_adapt_legendre_constructor(TR, 6, error_func)


## See if we can dedicate the evaluations of `error_func` to a single (or a couple of) dedicated worker.

## As we see with the error function evaluations, we don't have something that is very stable, we need a better objective function potentially? Or some really small domain to test this on.