# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, AlgebraicSolving
# , HomotopyContinuation

function rational_bigint_to_int(r::Rational{BigInt})
    # Convert BigInt to Int safely
    function safe_convert_to_int(x::BigInt)
        if x <= typemax(Int) && x >= typemin(Int)
            return Int(x)
        else
            # Scale down by the greatest power of 10 that maintains the number above Int's min/max
            scale = 10^(floor(log10(abs(x))) - floor(log10(typemax(Int))))
            return Int(x / scale)
        end
    end

    # Apply safe conversion to both numerator and denominator
    num_int = safe_convert_to_obsidian(r.num)
    den_int = safe_convert_to_int(r.den)

    # Ensure the fraction is reduced
    gcd_val = gcd(num_int, den_int)
    return Rational(num_int ÷ gcd_val, den_int ÷ gcd_val)
end



# Constants and Parameters
const d1, d2, ds = 2, 8, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters

# Execute the computation
results = main_computation(n, d1, d2, ds)
sol = results[end][1]
lambda = support_gen(n, d2)[1]

# Compute the approximant 
@polyvar(x[1:n]) # Define polynomial ring 
R = generateApproximant(lambda, sol)


# Generate the system for homotopy HomotopyContinuation
P1 = differentiate(R, x[1])
P2 = differentiate(R, x[2])

# Prepare for HomotopyContinuation
p1_converted = mapcoefficients(rational_bigint_to_int, P1)
p2_converted = mapcoefficients(rational_bigint_to_int, P2)

# Solve homotopy continuation system with reduced rational fractions. 
@var(x[1:n]) # Define polynomial ring for HomotopyContinuation
# Z  = System([P1, P2])
Z  = System([p1_converted, p2_converted])

Real_sol_lstsq = HomotopyContinuation.solve(Z)
HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
