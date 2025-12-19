push!(LOAD_PATH, "../src/")
using Documenter, Globtim

makedocs(
    sitename = "Globtim.jl Documentation",
    modules = [Globtim],
    repo = "github.com/gescholt/Globtim.jl",
    format = Documenter.HTML(
        repolink = "https://github.com/gescholt/Globtim.jl",
        canonical = "https://gescholt.github.io/Globtim.jl/stable/",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Core Algorithm" => "core_algorithm.md",
        "Polynomial Approximation" => "polynomial_approximation.md",
        "Solvers" => "solvers.md",
        "Critical Point Analysis" => "critical_point_analysis.md",
        "Anisotropic Grids" => "anisotropic_grids_guide.md",
        "Sparsification" => "sparsification.md",
        "Exact Conversion" => "exact_conversion.md",
        "Grid Formats" => "grid_formats.md",
        "Precision" => "precision_parameters.md",
        "Testing" => [
            "Test Documentation" => "test_documentation.md",
            "Test Running Guide" => "test_running_guide.md",
            "Anisotropic Grid Tests" => "anisotropic_grid_tests.md"
        ],
        "Examples" => "examples.md",
        "Visualization" => "visualization.md",
        "GlobtimPlots" => "globtimplots.md",
        "API Reference" => "api_reference.md"
    ],
    checkdocs = :none
)

deploydocs(repo = "github.com/gescholt/Globtim.jl.git")
