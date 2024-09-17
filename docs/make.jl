push!(LOAD_PATH, "../src/")
using Documenter, Globtim

makedocs(
    sitename="Globtim documentation",
    modules=[Globtim],
    repo="github.com/gescholt/Globtim.jl",
    format=Documenter.HTML(repolink="https://github.com/gescholt/Globtim.jl"),
    pages=[
        "Home" => "index.md"
    ]
)

deploydocs(
    repo="github.com/gescholt/Globtim.jl.git",
)
