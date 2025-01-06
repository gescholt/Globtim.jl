using Pkg
# Pkg.activate("/home/user/Globtim.jl/Examples")
Pkg.activate(joinpath(@__DIR__, ".."))
using DataStructures
using LinearAlgebra
using StaticArrays
using SharedArrays
using ModelingToolkit
using OrdinaryDiffEq
using DataFrames

const T = Float64
time_interval = T[0.0, 1.0]
p_true = T[0.11, 0.22, 0.33]
ic = T[0.11, 0.15]
num_points = 6
include("model_eval.jl")
model, params, states, outputs = define_lotka_volterra_model()
error_func = make_error_distance(model, outputs, p_true, num_points)


"""
Globtim
"""

p_center = p_true + [0.1, 0.0, 0.0]

n = 3
Pkg.develop(path=".")
using Globtim
using DynamicPolynomials
@polyvar(x[1:n]); # Define polynomial ring 



# Usage example
function solve_and_parse(pol::ApproxPoly, x, f::Function, TR::test_input; kwargs...)
    # First run msolve_polynomial_system and get the output file path
    output_file = msolve_polynomial_system(pol, x; kwargs...)
    
    # Then parse the results and get the DataFrame
    # The output file will be automatically cleaned up after parsing
    df = msolve_parser(output_file, f, TR)
    
    return df
end

function adapt_legendre_constructor(T::test_input, x, degree::Int, f::Function; verbose=1)::DataFrame

    p = Constructor(T, degree, basis=:legendre, verbose=verbose)
    if verbose > 0
        println("Number of samples: ", p.N)
    end

    current_degree = degree
    while current_degree <= T.degree_max
        if p.nrm <= T.tolerance
            if verbose > 0
                println("Degree: $current_degree")
            end
            pol_lege = Constructor(T, current_degree, basis=:legendre, verbose=verbose)
            data_frame = solve_and_parse(pol_lege, x, f, T, n=3, basis=:legendre, bigint=true)
            return data_frame

        else # p.nrm > T.tolerance 
            if current_degree == T.degree_max
                if verbose > 0
                    @warn "Maximum degree $current_degree reached without meeting tolerance. Computing critical points at current degree."
                end
                # Compute with current maximum degree
                pol_lege = Constructor(T, current_degree, basis=:legendre, verbose=verbose)
                data_frame = solve_and_parse(pol_lege, x, f, T, n=3, basis=:legendre, bigint=true)
                return data_frame
            end

            current_degree += 1
            if verbose > 0
                println("L2 tolerance not satisfied: ", p.nrm)
                println("Continuing iteration with degree: $current_degree")
            end

            # Subdivide domain and process recursively
            LTR = subdivide_domain(T)
            combined_data = DataFrame()

            for subdomain in LTR
                if verbose > 0
                    println("New center point: ", subdomain.center)
                    println("New sample range: ", subdomain.sample_range)
                end

                # Recursive call for subdomain
                subdata = adapt_legendre_constructor(subdomain, x, current_degree, f, verbose=verbose)

                # Check if combined_data is empty
                if isempty(combined_data)
                    combined_data = subdata
                else
                    # Ensure both DataFrames have the same columns before appending
                    missing_cols = setdiff(names(subdata), names(combined_data))
                    for col in missing_cols
                        combined_data[!, col] .= missing
                    end

                    missing_cols = setdiff(names(combined_data), names(subdata))
                    for col in missing_cols
                        subdata[!, col] .= missing
                    end

                    # Now append
                    append!(combined_data, subdata)
                end
            end

            return combined_data
        end
    end
end


TR = test_input(error_func,
    dim=n,
    center=p_center,
    GN=10,
    sample_range=1 // 8,
    degree_max=6,
    tolerance=2.0e-1
);
d = 4

adapt_legendre_constructor(TR, x, 4, error_func, verbose=1)

TR1 = test_input(error_func,
    dim=n,
    center=p_center,
    GN=20,
    sample_range=1 // 8,
    degree_max=6,
    tolerance=2.0e-1
);
adapt_legendre_constructor(TR1, x, 4, error_func, verbose=1)

TR2 = test_input(error_func,
    dim=n,
    center=p_center,
    GN=15,
    sample_range=1 // 8,
    degree_max=8,
    tolerance=2.0e-1
);

df2 = adapt_legendre_constructor(TR2, x, 6, error_func, verbose=1)
# Recall what works in the direct case? 

d = 10
pol_lege = Constructor(TR, d, basis=:legendre, verbose=1);
df_lege = solve_and_parse(pol_lege, x, error_func, TR, n=3, basis=:legendre, bigint=true)