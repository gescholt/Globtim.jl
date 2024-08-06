# ======================================================= Functions =======================================================

function zeta(x::Float64)::Float64
    # =======================================================
    # Relative tolearance function for the number of samples
    # =======================================================
    return x + (1 - x) * log(1 - x)
end

# Function to calculate the required number of samples
function calculate_samples(m::Int, delta::Float64, alph::Float64)::Int
    # =======================================================
    # Generate enought samples to satisfy the error bound with respect to tensorized Chebyshev polynomial basis.
    # m: dimension of the polynomial space
    # delta: relative error bound
    # alph: probability, confidence level
    # =======================================================
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

function generate_grid(n::Int, GN::Int)
    # =======================================================
    # Function to generate tensorized Chebyshev grid 
    # =======================================================
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
end