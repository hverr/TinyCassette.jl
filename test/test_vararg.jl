@testset "varargs" begin
    @noinline f(a, b, c...) = a + b + sum(c)

    @noinline function foobar()
        f(3, 4, 5, 6, 7)
    end

    @test TinyCassette.execute(nothing, foobar) == 25
end
