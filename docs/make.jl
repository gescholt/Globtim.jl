push!(LOAD_PATH, "../src/")
using Documenter, Globtim

makedocs(
    sitename = "Globtim.jl Documentation",
    modules = [Globtim],
    repo = "github.com/gescholt/Globtim.jl",
    format = Documenter.HTML(
        repolink = "https://github.com/gescholt/Globtim.jl",
        canonical = "https://gescholt.github.io/Globtim.jl/dev/",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Examples" => "examples.md",
        "Core Algorithm" => "core_algorithm.md",
        "Polynomial Approximation" => "polynomial_approximation.md",
        "Solvers" => "solvers.md",
        "Critical Point Analysis" => "critical_point_analysis.md",
        "Sparsification" => "sparsification.md",
        "Exact Conversion" => "exact_conversion.md",
        "Grid Formats" => "grid_formats.md",
        "Precision" => "precision_parameters.md",
        "GlobtimPlots" => "globtimplots.md",
        "API Reference" => "api_reference.md"
    ],
    checkdocs = :none
)

deploydocs(
    repo = "github.com/gescholt/Globtim.jl.git",
    versions = ["stable" => "dev"]
)
