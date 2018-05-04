using TinyCassette

using Test: @testset, @test, @test_throws

@testset "TinyCassette" begin
    include("test_if_statement.jl")
    include("test_subtype_matching.jl")
    include("test_vararg.jl")
    include("test_infer.jl")
    include("test_generated.jl")
end
