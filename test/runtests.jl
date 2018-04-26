using TinyCassette

using Test: @testset, @test, @test_throws


# these definitions need to be at the top level
const a = pointer([42])
tt = Tuple{typeof(a), typeof(1)}

@inline dub() = TinyCassette.execute(nothing, unsafe_load, a, 1)

# actual testset
@testset "TinyCassette" begin
    include("test_if_statement.jl")
    include("test_subtype_matching.jl")
    include("test_vararg.jl")

    @testset "infer unsafe_load" begin
        original_result_type = code_typed(unsafe_load, tt)[1][2]
        overdubbed_result_type = code_typed(dub, Tuple{})[1][2]

        @test original_result_type == overdubbed_result_type

        @code_warntype dub()
    end
end
