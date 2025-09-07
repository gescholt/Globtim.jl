# Globtim.jl Example Notebooks

This directory contains Jupyter notebooks demonstrating various features and use cases of Globtim.jl.

## Production-Ready Examples

These notebooks are fully documented and ready for public use:

- **Camel_2d.ipynb** - 2D Camel function optimization
- **CrossInTray.ipynb** - Cross-in-tray function analysis
- **DeJong.ipynb** - De Jong's function optimization
- **DeJong_msolve.ipynb** - De Jong's function using Msolve
- **Deuflhard.ipynb** - Deuflhard test function
- **Deuflhard_msolve.ipynb** - Deuflhard function using Msolve
- **HolderTable.ipynb** - Holder table function optimization
- **Ratstrigin_3.ipynb** - 3D Rastrigin function
- **Ratstrigin_3_msolve.ipynb** - 3D Rastrigin using Msolve
- **Shubert_4d_msolve.ipynb** - 4D Shubert function with Msolve
- **Trefethen_3D.ipynb** - 3D Trefethen function
- **Trefethen_msolve.ipynb** - Trefethen function using Msolve

## Error Handling Framework Tests

- **OTL_Circuit_Error_Handling_Test.ipynb** - Comprehensive test of error handling framework using 6D OTL Circuit function from SFU benchmark suite

## Development Notebooks (Not for Public Release)

These notebooks are experimental or under development:

- **AnisotropicGridComparison.ipynb** - Testing anisotropic grid implementations (in development)
- **Triple_Graph*.ipynb** - Various triple graph visualizations (experimental)

## Running the Examples

To run these notebooks:

1. Install Jupyter and IJulia:
   ```julia
   using Pkg
   Pkg.add("IJulia")
   ```

2. Start Jupyter:
   ```julia
   using IJulia
   notebook(dir="Examples/Notebooks")
   ```

3. Open any notebook and run the cells sequentially.

## Notes

- Notebooks with `_msolve` suffix demonstrate using the Msolve solver for exact polynomial system solving
- All notebooks assume Globtim.jl is already installed
- Some notebooks may generate output files (PDFs, PNGs) which are excluded from version control

### Plotting Functions

For notebooks using plotting functionality (especially Deuflhard.ipynb):

- **CairoMakie plotting functions** require module prefix: `Globtim.cairo_plot_polyapprox_levelset()`
- Load CairoMakie first: `using CairoMakie; CairoMakie.activate!()`
- The function generates contour plots with critical points and minimizers