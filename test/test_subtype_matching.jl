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
    @test TinyCassette.execute(nothing, foobar) == "foo"

    # define a context, as a subtype of some other context
    TinyCassette.execute(ctx::TestSubtypeMatching.GPU, f::typeof(foo)) = bar()
    @test TinyCassette.execute(TestSubtypeMatching.Context(), foobar) == "bar"
end

@testset "subtype matching directly" begin
    foo() = 0
    TinyCassette.execute(ctx::C, f::typeof(foo)) = 1
    @test TinyCassette.execute(TestSubtypeMatching.Context(), foo) == 1
end

@testset "access type var" begin
    foo() = 0
    TinyCassette.execute(ctx::T, f::typeof(foo)) where {T <: TestSubtypeMatching.T{A}} = A

    @test TinyCassette.execute(TestSubtypeMatching.T{3}(), foo) == 3
    @test TinyCassette.execute(TestSubtypeMatching.T{5}(), foo) == 5
end
