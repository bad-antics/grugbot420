using Documenter
using GrugBot420

makedocs(
    sitename = "GrugBot420.jl",
    modules  = [GrugBot420],
    authors  = "marshalldavidson61-arch",
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical  = "https://marshalldavidson61-arch.github.io/grugbot420",
    ),
    pages = [
        "Home"          => "index.md",
        "Architecture"  => "architecture.md",
        "CLI Reference" => "cli.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/marshalldavidson61-arch/grugbot420.git",
    devbranch = "main",
)
