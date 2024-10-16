![Run Tests](https://github.com/gescholt/globtim.jl/actions/workflows/test.yml/badge.svg)

## Global optimization of continuous functions over compact domains

The purpose of the Globtim package is to compute the set of all local minima of a real continuous function over a rectangular domain in $$ \R^n $$. This is carried out in 3 main steps:


1. The input function $f$ is sampled on a tensorized Chebyshev grid.
2. A polynomial approximant is constructed via a discrete least squares.
3. The polynomial system of Partial derivatives is solved by either homotopy continuation (numerical  method) or through exact polynomial system solving (symbolic method).

## Project Status

In active development.

## Installation

The package is directly available from the Julia REPL.

```julia
julia> ]
pkg> add Globtim
```

The `exact` examples require [Msolve](https://msolve.lip6.fr/) to be installed. 
The other examples rely on [HomotopyContinuation.jl](https://www.juliahomotopycontinuation.org/) for the resolution of the polynomial system encoding the critical points of the objective function. 

## Examples


See the description page for this package at [Globtim](https://gescholt.github.io/globtim).
