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
        assets = [
            RawHTMLHeadContent("""
            <!-- Google tag (gtag.js) -->
            <script async src="https://www.googletagmanager.com/gtag/js?id=G-22HWCKE0JK"></script>
            <script>
              window.dataLayer = window.dataLayer || [];
              function gtag(){dataLayer.push(arguments);}
              gtag('js', new Date());
              gtag('config', 'G-22HWCKE0JK');
            </script>
            """)
        ]
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
