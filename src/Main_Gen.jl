# ==================== Functions ====================
"""
    MainGenerate(f, n::Int, d::Int, delta::Float64, alpha::Float64, scale_factor::Float64, scl::Float64; center::Vector{Float64}=fill(0.0, n))::ApproxPoly
# Arguments
- `f::Function`: The objective function to approximate.
- `n::Int`: The number of variables.
- `d::Int`: The degree of the polynomial.
- `delta::Float64`: Sampling parameter.
- `alpha::Float64`: Probability parameter.
- `scale_factor::Float64`: Scaling factor for the domain.
- `scl::Float64`: Scaling factor to reduce the number of points in the grid.
- `center::Vector{Float64}`: The center of the domain (default is a zero vector of length `n`).

# Returns
- `ApproxPoly`: An object containing the polynomial approximation and related data.

# Description
This function computes the coefficients of a polynomial approximant of degree `d` in the Chebyshev basis. The function constructs a Vandermonde-like matrix with monomials centered at the origin for stability and applicability of the theorems. The critical points are then rescaled to the appropriate positions in the domain.

# Example
```julia
f = x -> sum(x.^2)
n = 2
d = 3
delta = 0.1
alph = 0.05
scale_factor = 1.0
scl = 0.5
center = [0.0, 0.0]
approx_poly = MainGenerate(f, n, d, delta, alpha, scale_factor, scl, center=center)
# approx_poly is an ApproxPoly object containing the polynomial approximation and related data
"""
function MainGenerate(f, n::Int, d::Int, delta::Float64, alpha::Float64, scale_factor::Float64, scl::Float64;
    center::Vector{Float64}=fill(0.0, n), verbose=1, basis=:chebyshev, GN::Union{Int,Nothing}=nothing)::ApproxPoly
    m = binomial(n + d, d)  # Dimension of vector space
    K = calculate_samples(m, delta, alpha)

    # Use provided GN if given, otherwise compute it
    actual_GN = if isnothing(GN)
        Int(round(K^(1 / n) * scl) + 1)
    else
        GN
    end

    Lambda = SupportGen(n, d)
    if n<= 4
        grid = generate_grid_small_n(n, actual_GN, basis=basis)
    else
        grid = generate_grid(n, actual_GN, basis=basis)
    end
    matrix_from_grid = reduce(vcat, map(x -> x', reshape(grid, :)))
    VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
    G_original = VL' * VL
    scaled_center = SVector{n,Float64}(center)
    F = map(x -> f(scale_factor * x + scaled_center), reshape(grid, :))
    RHS = VL' * F
    linear_prob = LinearProblem(G_original, RHS) 
    if verbose == 1
        println("Condition number of G: ", cond(G_original))
        sol = LinearSolve.solve(linear_prob,verbose=true)
        println("Chosen method: ", typeof(sol.alg))
    else
        sol = LinearSolve.solve(linear_prob)
    end
    # nrm = norm(VL * sol.u - F) / (actual_GN^n) # Watch out, we divide by GN to get the discrete norm
    # Compute norm based on basis type
    nrm = if basis == :chebyshev
        # Compute Riemann sum norm over the Chebyshev grid
        residual = x -> (VL*sol.u-F)[findfirst(y -> y == x, reshape(grid, :))]
        discrete_l2_norm_riemann(residual, grid)
    else  # Legendre case
        # Use uniform weights for Legendre grid
        sqrt((2 / actual_GN)^n * sum(abs2.(VL * sol.u - F)))
    end
    return ApproxPoly{Float64}(sol, d, nrm, actual_GN, scale_factor, matrix_from_grid, F)
end

"""
    main_nd(x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
    n::Int, d::Int, coeffs::Vector{Float64})::Polynomial{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder},Rational{BigInt}}    

Construct a polynomial in the standard monomial basis from a vector of coefficients (which have been computed in the tensorized Chebyshev or tensorized Legendre basis).

"""
function main_nd(x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
    n::Int, d::Int, coeffs::Vector{Float64};
    basis=:chebyshev,
    verbose=true,
    bigint=false)

    lambda = SupportGen(n, d).data
    m = size(lambda)[1]

    if verbose
        println("Dimension m of the vector space: ", m)
    end

    if length(coeffs) != m
        if verbose
            println("The length of coeffs_poly_approx does not match the dimension of the space we project onto")
        end
        error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
    end

    coeffs = convert.(Rational{bigint ? BigInt : Int}, coeffs)
    S_rat = zero(x[1])

    if basis == :chebyshev
        for j in 1:m
            total_time_j = @elapsed begin  # Time the entire j iteration
                prd = one(x[1])
                for k in 1:n
                    time_coeff = @elapsed coeff_vec = ChebyshevPolyExact(lambda[j, k])
                    println("Time for ChebyshevPolyExact at j=$j, k=$k: $time_coeff seconds")

                    time_sizing = @elapsed sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
                    println("Time for vector sizing at j=$j, k=$k: $time_sizing seconds")

                    time_monom = @elapsed monom_vec = MonomialVector([x[k]], 0:d)
                    println("Time for MonomialVector at j=$j, k=$k: $time_monom seconds")

                    time_mult = @elapsed prd *= sum(sized_coeff_vec .* monom_vec)
                    println("Time for multiplication and sum at j=$j, k=$k: $time_mult seconds")
                end
                time_final = @elapsed S_rat += coeffs[j] * prd
                println("Time for final addition at j=$j: $time_final seconds")
            end
            println("Total time for iteration j=$j: $total_time_j seconds")
            println("-------------------")
        end
    elseif basis == :legendre
        max_degree = maximum(lambda)
        legendre_coeffs = get_legendre_coeffs(max_degree)

        for j in 1:m
            prd = one(x[1])
            for k in 1:n
                deg = lambda[j, k]
                coeff_vec = legendre_coeffs[deg+1]
                sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
                prd *= sum(sized_coeff_vec .* MonomialVector([x[k]], 0:d))
            end
            S_rat += coeffs[j] * prd
        end
    end

    # If not using BigInt, convert coefficients to simpler rational numbers
    if !bigint
        terms_array = terms(S_rat)
        simplified_terms = map(terms_array) do term
            coeff = coefficient(term)
            try
                # Try to convert to simpler Rational{Int}
                simple_coeff = convert(Rational{Int}, rationalize(Float64(coeff)))
                simple_coeff * monomial(term)
            catch e
                @warn "Coefficient too large for Int, switching to BigInt for this term"
                coeff * monomial(term)  # Keep original BigInt coefficient
            end
        end
        return sum(simplified_terms)
    end

    return S_rat
end
# function main_nd(x::Vector{Variable{DynamicPolynomials.Commutative{DynamicPolynomials.CreationOrder},Graded{LexOrder}}},
#     n::Int, d::Int, coeffs::Vector{Float64};
#     basis=:chebyshev,
#     verbose=true,
#     bigint=false)

#     # Initialization timing
#     t_init = @elapsed begin
#         lambda = SupportGen(n, d).data
#         m = size(lambda)[1]

#         if length(coeffs) != m
#             error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
#         end

#         coeffs = convert.(Rational{bigint ? BigInt : Int}, coeffs)
#         S_rat = zero(x[1])
#     end

#     if verbose
#         println("\nInitialization time: ", t_init, " seconds")
#     end

#     # Timing aggregators for detailed breakdown
#     t_cheb_or_leg_total = 0.0  # Time for computing Chebyshev or Legendre coefficients
#     t_padding_total = 0.0      # Time for padding vectors
#     t_monom_total = 0.0        # Time for MonomialVector operations
#     t_prod_total = 0.0         # Time for polynomial products
#     t_sum_total = 0.0          # Time for final sum in each iteration

#     # Main computation timing
#     t_main = @elapsed begin
#         if basis == :chebyshev
#             for j in 1:m
#                 local_prd = one(x[1])
#                 for k in 1:n
#                     # Time Chebyshev polynomial computation
#                     t_cheb = @elapsed coeff_vec = ChebyshevPolyExact(lambda[j, k])
#                     t_cheb_or_leg_total += t_cheb

#                     # Time padding operation
#                     t_pad = @elapsed sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
#                     t_padding_total += t_pad

#                     # Time monomial vector creation
#                     t_monom = @elapsed monom_vec = MonomialVector([x[k]], 0:d)
#                     t_monom_total += t_monom

#                     # Time polynomial multiplication
#                     t_prod = @elapsed local_prd *= sum(sized_coeff_vec .* monom_vec)
#                     t_prod_total += t_prod
#                 end

#                 # Time final sum for this iteration
#                 t_sum = @elapsed S_rat += coeffs[j] * local_prd
#                 t_sum_total += t_sum

#                 if verbose && j == 1
#                     println("\nDetailed timing for first iteration:")
#                     println("  Chebyshev computation: ", t_cheb, " seconds")
#                     println("  Vector padding: ", t_pad, " seconds")
#                     println("  Monomial vector creation: ", t_monom, " seconds")
#                     println("  Polynomial multiplication: ", t_prod, " seconds")
#                     println("  Final sum: ", t_sum, " seconds")
#                 end
#             end
#         elseif basis == :legendre
#             t_legendre_prep = @elapsed begin
#                 max_degree = maximum(lambda)
#                 legendre_coeffs = get_legendre_coeffs(max_degree)
#             end

#             if verbose
#                 println("\nLegendre coefficients preparation time: ", t_legendre_prep, " seconds")
#             end

#             for j in 1:m
#                 local_prd = one(x[1])
#                 for k in 1:n
#                     # Time Legendre coefficient lookup
#                     t_leg = @elapsed begin
#                         deg = lambda[j, k]
#                         coeff_vec = legendre_coeffs[deg+1]
#                     end
#                     t_cheb_or_leg_total += t_leg

#                     # Time padding operation
#                     t_pad = @elapsed sized_coeff_vec = vcat(coeff_vec, zeros(eltype(coeff_vec), d + 1 - length(coeff_vec)))
#                     t_padding_total += t_pad

#                     # Time monomial vector creation
#                     t_monom = @elapsed monom_vec = MonomialVector([x[k]], 0:d)
#                     t_monom_total += t_monom

#                     # Time polynomial multiplication
#                     t_prod = @elapsed local_prd *= sum(sized_coeff_vec .* monom_vec)
#                     t_prod_total += t_prod
#                 end

#                 # Time final sum for this iteration
#                 t_sum = @elapsed S_rat += coeffs[j] * local_prd
#                 t_sum_total += t_sum

#                 if verbose && j == 1
#                     println("\nDetailed timing for first iteration:")
#                     println("  Legendre lookup: ", t_leg, " seconds")
#                     println("  Vector padding: ", t_pad, " seconds")
#                     println("  Monomial vector creation: ", t_monom, " seconds")
#                     println("  Polynomial multiplication: ", t_prod, " seconds")
#                     println("  Final sum: ", t_sum, " seconds")
#                 end
#             end
#         end
#     end

#     # Final conversion timing
#     t_final = @elapsed begin
#         if !bigint
#             terms_array = terms(S_rat)
#             simplified_terms = map(terms_array) do term
#                 coeff = coefficient(term)
#                 try
#                     simple_coeff = convert(Rational{Int}, rationalize(Float64(coeff)))
#                     simple_coeff * monomial(term)
#                 catch e
#                     @warn "Coefficient too large for Int, switching to BigInt for this term"
#                     coeff * monomial(term)
#                 end
#             end
#             S_rat = sum(simplified_terms)
#         end
#     end

#     if verbose
#         println("\nDetailed Timing Summary:")
#         println("Initialization time: ", t_init, " seconds")
#         println("\nMain computation breakdown:")
#         println("  $(basis) computation/lookup total: ", t_cheb_or_leg_total, " seconds")
#         println("  Vector padding operations total: ", t_padding_total, " seconds")
#         println("  Monomial vector operations total: ", t_monom_total, " seconds")
#         println("  Polynomial multiplications total: ", t_prod_total, " seconds")
#         println("  Final summations total: ", t_sum_total, " seconds")
#         println("Total main computation time: ", t_main, " seconds")
#         println("Final conversion time: ", t_final, " seconds")
#         println("\nTotal execution time: ", t_init + t_main + t_final, " seconds")
#     end

#     return S_rat
# end

"""
Constructor(T, degree) takes a test input and a starting degree and computes the polynomial approximant satisfying that tolerance. 
If GN, the number of samples (per dimension), is specified in the test input `T`, then we only compute the polynomial approximant for that number of samples per coordinate axis.

"""
function Constructor(T::test_input, degree::Int; verbose=0, basis::Symbol=:chebyshev)::ApproxPoly
    if !(basis in [:chebyshev, :legendre])
        throw(ArgumentError("basis must be either :chebyshev or :legendre"))
    end

    if !isnothing(T.GN) && isa(T.GN, Int)
        p = MainGenerate(T.objective, T.dim, degree, T.prec[2], T.prec[1], T.sample_range, T.reduce_samples, center=T.center, verbose=verbose, basis=basis, GN=T.GN)
        println("current L2-norm: ", p.nrm)
        return p
    end

    p = nothing
    while true
        p = MainGenerate(T.objective, T.dim, degree, T.prec[2], T.prec[1], T.sample_range, T.reduce_samples,
            center=T.center, verbose=verbose, basis=basis, GN=T.GN)
        if p.nrm < T.tolerance
            println("attained the desired L2-norm: ", p.nrm)
            println("Degree :$degree ")
            break
        else
            degree += 1
            println("Increase degree to: $degree")
        end
    end
    return p
end

"""
Function to solve the polynomial system using HomotopyContinuation.jl and the DynamicPolynomials.jl environment.
"""
function solve_polynomial_system(x, n, d, coeffs; basis=:chebyshev, bigint=true)::Vector{Vector{Float64}}
    pol = main_nd(x, n, d, coeffs, basis=basis, bigint=bigint)
    grad = differentiate.(pol, x)
    sys = System(grad)
    solutions = solve(sys, start_system=:total_degree)
    rl_sol = real_solutions(solutions; only_real=true, multiple_results=false)
    return rl_sol
end


function msolve_polynomial_system(pol::ApproxPoly, x; n=2, basis=:chebyshev, bigint=true)
    # Generate random temporary filenames
    random_suffix = randstring(8)
    input_file = "tmp_input_$(random_suffix).ms"
    output_file = "tmp_output_$(random_suffix).ms"

    try
        # Process polynomial system
        names = [x[i].name for i in 1:length(x)]
        open(input_file, "w") do file
            println(file, join(names, ", "))
            println(file, 0)
        end

        p = main_nd(x, n, pol.degree, pol.coeffs, basis=basis, bigint=bigint)
        grad = differentiate.(p, x)

        for i in 1:n
            partial_str = replace(string(grad[i]), "//" => "/")
            open(input_file, "a") do file
                if i < n
                    println(file, string(partial_str, ","))
                else
                    println(file, partial_str)
                end
            end
        end

        run(`msolve -v 0 -t 10 -f $input_file -o $output_file`)

        # Return the output filename so it can be used by msolve_parser
        return output_file

    finally
        # Clean up only the input file here
        isfile(input_file) && rm(input_file)
    end
end



