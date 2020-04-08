
include("../main.jl")

using Documenter, Main.bvm

push!(LOAD_PATH, "../")

makedocs(sitename="ROD (Reproducible Opinion Dynamics)")
