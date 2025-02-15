using Pkg
Pkg.activate(".")
using Globtim
# include("../../../src/lib_func.jl") # Include the library of functions

# Constants and Parameters
d = 2 # Initial Degree 
const n, a, b = 2, 1, 1
const scale_factor = a / b       # Scaling factor appears in `main_computation`, maybe it should be a parameter.
const delta, alpha = 0.5, 1 / 10  # Sampling parameters
const tol_l2 = 1.5e-3             # Define the tolerance for the L2-norm

f = Deuflhard

poly_approx =
    MainGenerate(f, 2, d, delta, alpha, scale_factor, 0.2, verbose = 1, basis = :legendre)
