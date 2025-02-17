using Documenter, Globtim

makedocs(
    sitename="Globtim.jl",
    modules=[Globtim],
    authors="Georgy Scholten",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", nothing) == "true",
        canonical="https://gescholt.github.io/Globtim",
        # Fix the repo link warning
        repolink="https://github.com/gescholt/Globtim.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api.md",
        # "Examples" => "examples.md"
    ],
    remotes=nothing
)

# The deployment warning is normal when building locally
# It will work when deployed through GitHub Actions
deploydocs(
    repo="github.com/gescholt/Globtim.jl",
    devbranch="clean-version",
    push_preview=true
)