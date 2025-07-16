push!(LOAD_PATH, "../src/")
using Documenter, Globtim

makedocs(
    sitename="Globtim.jl Documentation",
    modules=[Globtim],
    repo="github.com/gescholt/Globtim.jl",
    format=Documenter.HTML(
        repolink="https://github.com/gescholt/Globtim.jl",
        canonical="https://gescholt.github.io/Globtim.jl/stable/",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Core Algorithm" => "core_algorithm.md",
        "Critical Point Analysis" => "critical_point_analysis.md",
        "Examples" => "examples.md",
        "Visualization" => "visualization.md",
        "API Reference" => "api_reference.md"
    ],
    checkdocs=:exports,
    linkcheck=true
)

deploydocs(
    repo="github.com/gescholt/Globtim.jl.git",
)
