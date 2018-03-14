# this demo overdubs functions without modifying their execution.
# it serves as a demonstration of the underlying techniques,
# and/or to debug compiler issues related to overdubbing.
using TinyCassette

function foobar()
    foo()
end

@noinline foo() = println("foo")
@noinline bar() = println("bar")

# regular execution, without a context
foobar()
TinyCassette.Overdub(foobar)()

# define a context, and override the fallback generated function with a call to `bar`
struct Context end
(::TinyCassette.Overdub{typeof(foo),Context})(args...) = bar()
TinyCassette.Overdub(foobar,Context())()

#exit()


# this demo overdubs functions without modifying their execution.
# it serves as a demonstration of the underlying techniques,
# and/or to debug compiler issues related to overdubbing.

using Test
using InteractiveUtils

const a = [42]

for (f, args) in [(unsafe_load, (pointer(a),1))]
    tt = Tuple{map(typeof, args)...}
    @info "Testing $f($(tt.parameters...))"
    dub = TinyCassette.Overdub(f)

    # test execution
    original_result = f(args...)
    overdubbed_result = dub(args...)
    @test overdubbed_result == original_result

    # test inference
    original_result_type = code_typed(f, tt)[1][2]
    overdubbed_result_type = code_typed(dub, tt)[1][2]
    if original_result_type != overdubbed_result_type
        @warn "Failed to infer overdubbed version of $f"
        code_warntype(f, tt)
        code_warntype(dub, tt)
    end
end
