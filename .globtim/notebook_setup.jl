# Globtim Notebook Setup
# Activates the globtim environment and loads core packages.
# Included by notebooks via:
#   include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))

using Pkg

# Activate the globtim project environment
globtim_root = abspath(joinpath(@__DIR__, ".."))
Pkg.activate(globtim_root)

# Dev-link sibling packages so they resolve from the monorepo
for pkg in ("globtimplots", "globtimpostprocessing", "Dynamic_objectives")
    pkg_path = abspath(joinpath(globtim_root, "..", pkg))
    if isdir(pkg_path)
        try
            Pkg.develop(path=pkg_path)
        catch
        end
    end
end

# Core imports used by all notebooks
using Globtim
using DynamicPolynomials
using DataFrames

# Plotting — load CairoMakie + GlobtimPlots
using CairoMakie
using GlobtimPlots

println("Globtim notebook environment ready.")
