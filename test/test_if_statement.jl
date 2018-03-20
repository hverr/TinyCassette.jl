# regression test for 5442a4e

@testset "if statement" begin
    function bar1()
        if false
            return 1
        else
            return 0
        end
    end
    @test TinyCassette.Overdub(bar1)() == 0

    @noinline foo() = false
    function bar2()
        if foo()
            return 1
        else
            return 0
        end
    end
    @test TinyCassette.Overdub(bar2)() == 0
end
