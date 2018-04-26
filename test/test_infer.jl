# these definitions need to be at the top level
@testset "infer unsafe_load" begin
    @eval const a = pointer([42])
    tt = Tuple{typeof(a), typeof(1)}

    @inline @eval dub() = TinyCassette.execute(nothing, unsafe_load, a, 1)

    original_result_type = code_typed(unsafe_load, tt)[1][2]
    overdubbed_result_type = code_typed(dub, Tuple{})[1][2]

    @test original_result_type == overdubbed_result_type

    @code_warntype dub()
end
