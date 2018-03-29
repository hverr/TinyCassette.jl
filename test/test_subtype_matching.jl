module TestSubtypeMatching
    abstract type GPU end
    struct Context <: GPU end

    struct T{A} end
end

@testset "subtype matching" begin
    function foobar()
        foo()
    end

    @noinline foo() = "foo"
    @noinline bar() = "bar"

    # regular execution, without a context
    @test foobar() == "foo"
    @test TinyCassette.Overdub(foobar)() == "foo"

    # define a context, as a subtype of some other context
    (::TinyCassette.Overdub{typeof(foo),<:TestSubtypeMatching.GPU})() = bar()
    @test TinyCassette.Overdub(foobar,TestSubtypeMatching.Context())() == "bar"
end

@testset "subtype matching directly" begin
    foo() = 0
    (::TinyCassette.Overdub{typeof(foo), C})() where {C <:TestSubtypeMatching.GPU} = 1
    @test TinyCassette.Overdub(foo, TestSubtypeMatching.Context())() == 1
end

@testset "access type var" begin
    foo() = 0
    (::TinyCassette.Overdub{typeof(foo), <: TestSubtypeMatching.T{A}})() where {A} = A

    @test TinyCassette.Overdub(foo, TestSubtypeMatching.T{3}())() == 3
    @test TinyCassette.Overdub(foo, TestSubtypeMatching.T{5}())() == 5
end
