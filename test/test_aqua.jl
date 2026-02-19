using Test
using Aqua
using Globtim

include("aqua_config.jl")

@testset "Aqua.jl Quality Assurance" begin
    run_aqua_tests(Globtim)
end
