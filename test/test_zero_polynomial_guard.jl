using Test
using Globtim

@testset "Constructor zero-polynomial guard (xosc)" begin
    # Regression test for bead xosc: on some platforms (observed on cluster
    # LAPACK at Deuflhard 2D deg 12) LinearSolve.LUFactorization silently
    # returns a zero-vector solution. Without the guard in Main_Gen.jl this
    # zero polynomial would flow into HC.System(grad) and raise a cryptic
    # "reducing over an empty collection" ArgumentError.
    #
    # A constant-zero objective reproduces the same end state deterministically:
    # F = zeros → RHS = VL' * F = zeros → sol.u = zeros → guard must fire.

    zero_obj(x) = 0.0
    TR = TestInput(zero_obj, dim = 2, center = [0.0, 0.0], GN = 10, sample_range = 1.0)

    err = try
        Globtim.Constructor(TR, 4, basis = :chebyshev, normalized = false)
        nothing
    catch e
        e
    end

    @test err !== nothing
    @test err isa ErrorException
    msg = sprint(showerror, err)
    @test occursin("zero polynomial", msg)
    @test occursin("GN=10", msg)
    @test occursin("basis=chebyshev", msg)
    @test occursin("cond_vandermonde=", msg)
end
