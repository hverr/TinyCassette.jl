module TestSubtypeMatching
    abstract type GPU end
    struct Context <: GPU end
end

#@testset "subtype matching" begin
#    function foobar()
#        foo()
#    end
#
#    @noinline foo() = "foo"
#    @noinline bar() = "bar"
#
#    # regular execution, without a context
#    @test foobar() == "foo"
#    @test TinyCassette.Overdub(foobar)() == "foo"
#
#    # define a context, as a subtype of some other context
#    (::TinyCassette.Overdub{typeof(foo),<:TestSubtypeMatching.GPU})() = bar()
#    @test TinyCassette.Overdub(foobar,TestSubtypeMatching.Context())() == "bar"
#
#end