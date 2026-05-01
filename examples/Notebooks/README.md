# Globtim.jl Example Notebooks

Jupyter notebooks demonstrating Globtim workflows on standard analytical benchmarks.

## Setup

```julia
using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
using IJulia          # if not already installed: Pkg.add("IJulia")
notebook(dir = @__DIR__)
```

The `Project.toml` in this directory pins the example dependencies (Globtim, CairoMakie, DataFrames, DynamicPolynomials, etc.). Some notebooks use [msolve](https://msolve.lip6.fr/) — install separately if you want to run those.

## Notebooks

### Polynomial-approximation workflow on standard benchmarks

| Notebook | Description |
|---|---|
| `Camel_2d.ipynb` | 2D Camel function — minimal end-to-end |
| `Deuflhard.ipynb` | Deuflhard test function — with CairoMakie visualizations |
| `Trefethen_3D.ipynb` | 3D Trefethen function — DataFrames + StaticArrays |
| `pos_dim_min.ipynb` | Positive-dimensional minimization |

### msolve solver backend

These use [msolve](https://msolve.lip6.fr/) for exact polynomial-system solving instead of HomotopyContinuation.

| Notebook | Description |
|---|---|
| `DeJong_msolve.ipynb` | De Jong's function via msolve |
| `Deuflhard_msolve.ipynb` | Deuflhard via msolve |

### Adaptive precision (4D)

| Notebook | Description |
|---|---|
| `AdaptivePrecision_4D_Development.ipynb` | Adaptive precision in 4D, with `BenchmarkTools` |
| `Shubert_4d_adaptive_precision.ipynb` | 4D Shubert with adaptive precision |
