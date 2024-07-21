include("optim_lib.jl")
include("lib_func.jl")

# Constants and Parameters
d1, d2, ds = 6, 6, 1  # Degree range and step
const n, a, b = 2, 5, 1
const C = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alph = 0.5, 9 / 10  # Sampling parameters
f = camel_3 # Objective function