using Documenter, Tofu

makedocs(;
    modules=[Tofu],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/Tofu.jl/blob/{commit}{path}#L{line}",
    sitename="Tofu.jl",
    authors="Takafumi Arakaki",
    assets=[],
)

deploydocs(;
    repo="github.com/tkf/Tofu.jl",
)
