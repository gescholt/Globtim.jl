# Globtim.jl examples

## Demo scripts

Self-contained `.jl` scripts. Run with `julia --project=. <name>.jl` from a project that has Globtim installed.

| Script | What it shows |
|---|---|
| `custom_function_demo.jl` | Define a custom 2D objective, build polynomial approximation, find critical points |
| `quick_subdivision_demo.jl` | Adaptive subdivision on sphere / Rosenbrock / Rastrigin / anisotropic |
| `domain_sweep_demo.jl` | Sweep over domain sizes for a fixed objective |
| `high_dimensional_demo.jl` | 3D / 4D scaling behaviour |
| `scalar_function_demo.jl` | 1D scalar functions |
| `sparsification_demo.jl` | Polynomial coefficient sparsification |
| `anisotropic_grid_demo.jl` | Anisotropic Chebyshev/Legendre grids |

## Notebooks

`Notebooks/` — Jupyter notebooks for analytical benchmark functions (Camel, CrossInTray, Deuflhard, Trefethen, etc.). See `Notebooks/README.md` for the index and setup instructions.

## TOML configs

`configs/` — example TOML configs for the experiment-driven workflow:

- `ackley_3d.toml`
- `deuflhard_2d.toml`
- `griewank_3d.toml`
- `levy_3d.toml`

Run with `Globtim.run_experiment(joinpath(@__DIR__, "configs", "ackley_3d.toml"))` or via the CLI documented in the package `docs/`.
