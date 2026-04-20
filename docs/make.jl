push!(LOAD_PATH, "../src/")
using Documenter, Globtim

# WGLMakie requires a browser/display and is not available in CI.
# In CI we run in draft mode (skips @example block execution) so WGLMakie
# is never needed — docs structure and docstring validity are still checked.
const CI = get(ENV, "CI", "false") == "true"
if !CI
    using WGLMakie, Bonito
    WGLMakie.activate!()
    Makie.inline!(true)
end

makedocs(
    sitename = "Globtim.jl Documentation",
    modules = [Globtim],
    repo = "github.com/gescholt/Globtim.jl",
    format = Documenter.HTML(
        repolink = "https://github.com/gescholt/Globtim.jl",
        canonical = "https://gescholt.github.io/Globtim.jl/dev/",
        edit_link = "main",
        size_threshold = nothing,           # WGLMakie pages embed JS/WebGL data
        example_size_threshold = nothing,   # prevent per-example fallback to static images
        assets = [
            RawHTMLHeadContent(
                """
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-22HWCKE0JK"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-22HWCKE0JK');
</script>
""",
            ),
        ],
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
        "Interactive Visualizations" => "interactive_test.md",
        "API Reference" => "api_reference.md",
    ],
    checkdocs = :none,
    draft = CI,   # skips @example execution in CI; still validates structure
)

deploydocs(
    repo = "github.com/gescholt/Globtim.jl.git",
    devbranch = "main",
    versions = ["stable" => "dev"],
)
