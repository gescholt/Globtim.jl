push!(LOAD_PATH, "../src/")
using Documenter, Globtim

# Self-contained docs: this environment depends ONLY on Globtim (+ Documenter),
# so the site builds on the public Globtim.jl mirror without the sibling
# GlobtimPlots / GlobtimPostProcessing path-sources (which don't exist there).
# @example blocks are skipped in CI via draft mode; docs structure is still checked.
const CI = get(ENV, "CI", "false") == "true"

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
        "Ecosystem Walkthrough" => "ecosystem_walkthrough.md",
        "Examples" => "examples.md",
        "Core Algorithm" => "core_algorithm.md",
        "Polynomial Approximation" => "polynomial_approximation.md",
        "Solvers" => "solvers.md",
        "Critical Point Analysis" => "critical_point_analysis.md",
        "Sparsification" => "sparsification.md",
        "Exact Conversion" => "exact_conversion.md",
        "Grid Formats" => "grid_formats.md",
        "Precision" => "precision_parameters.md",
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
