using KhepriMakie
using Documenter

DocMeta.setdocmeta!(KhepriMakie, :DocTestSetup, :(using KhepriMakie); recursive=true)

makedocs(;
    modules=[KhepriMakie],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriMakie.jl/blob/{commit}{path}#{line}",
    sitename="KhepriMakie.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriMakie.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriMakie.jl",
    devbranch="master",
)
