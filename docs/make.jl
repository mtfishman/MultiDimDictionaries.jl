using MultiDimDictionaries
using Documenter

DocMeta.setdocmeta!(
  MultiDimDictionaries, :DocTestSetup, :(using MultiDimDictionaries); recursive=true
)

makedocs(;
  modules=[MultiDimDictionaries],
  authors="Matthew Fishman <mfishman@flatironinstitute.org> and contributors",
  repo="https://github.com/mtfishman/MultiDimDictionaries.jl/blob/{commit}{path}#{line}",
  sitename="MultiDimDictionaries.jl",
  format=Documenter.HTML(;
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://mtfishman.github.io/MultiDimDictionaries.jl",
    assets=String[],
  ),
  pages=["Home" => "index.md"],
)

deploydocs(; repo="github.com/mtfishman/MultiDimDictionaries.jl", devbranch="main")
