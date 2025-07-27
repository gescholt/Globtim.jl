using Revise
using StructuralIdentifiability

# FitzHugh-Nagumo model
# https://github.com/iliailmer/ParameterEstimation.jl/blob/main/benchmarks/all-global/fitzhugh-nagumo.jl
ode = @ODEmodel(
	V'(t) = g * (V - V^3 / 3 + R),
    R'(t) = 1 / g * (V - a + b * R),
	y(t) = V
)

assess_identifiability(ode)

#=
[ Info: Summary of the model:
[ Info: State variables: V, R
[ Info: Parameters: a, b, g
[ Info: Inputs: 
[ Info: Outputs: y
[ Info: Assessing local identifiability
[ Info: Assessing global identifiability
[ Info: Functions to check involve states
[ Info: Computing IO-equations
[ Info: Computed IO-equations in 0.001274108 seconds
[ Info: Computing Wronskians
[ Info: Computed Wronskians in 0.001222247 seconds
[ Info: Dimensions of the Wronskians [5]
[ Info: Ranks of the Wronskians computed in 1.3407e-5 seconds
[ Info: Simplifying generating set. Simplification level: standard
[ Info: Computing normal forms of degree 2 in 3 variables
[ Info: Used 1 specializations in 0.052752471 seconds, found 3 relations
[ Info: Computing 4 Groebner bases for degrees (3, 3) for block orderings
[ Info: Computed Groebner bases in 0.011954726 seconds
[ Info: Inclusion checked with probability 0.9955 in 0.000731366 seconds
[ Info: Global identifiability assessed in 0.292982158 seconds
OrderedCollections.OrderedDict{Any, Symbol} with 5 entries:
  V(t) => :globally
  R(t) => :globally
  a    => :globally
  b    => :globally
  g    => :globally
=#

# Treatment model
# https://github.com/iliailmer/ParameterEstimation.jl/blob/751b26e30066665cfd75e6b1dfa40e64f4b4cace/benchmarks/all_models.jl#L386
ode = @ODEmodel(
	S'(t) = -b * S * In / 1. - d * b * S * Tr / 1.,
  In'(t) = b * S * In / 1. + d * b * S * Tr / 1. - (a + g) * In,
  Tr'(t) = g * In - 0.4 * Tr,
  y(t) = Tr
)

assess_identifiability(ode)

# Goodwin oscillator model
# https://github.com/iliailmer/ParameterEstimation.jl/blob/main/examples/unidentifiable/goodwin-osc.jl

ode = @ODEmodel(
  x1'(t) = k1 * 0.9^10 / (0.9^10 + x3^10) - k2 * x1, # x1'(t) = k1 * Ki^10 / (Ki^10 + x3^10) - k2 * x1,
  x2'(t) = 0.3 * x1 - k4 * x2, # x2'(t) = k3 * x1 - k4 * x2,
  x3'(t) = k5 * x2 - 0.5 * x3, # k5 * x2 - k6 * x3,
  y1(t) = x1,
  y2(t) = x3,
)

assess_identifiability(ode)
