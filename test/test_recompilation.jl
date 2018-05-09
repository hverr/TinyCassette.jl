#@testset "recompilation" begin
#    @eval f() = 1
#
#    @test f() == 1
#    @test TinyCassette.execute(nothing, f) == 1
#
#    @eval f() = 2
#    @test f() == 2
#    @test TinyCassette.execute(nothing, f) == 2
#end
