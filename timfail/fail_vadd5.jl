foo(ptr::Ptr{T}, i) where {T} = Base.unsafe_load(ptr, i)::T


code_warntype(foo, Tuple{Ptr{Float32}, Int})

using TinyCassette
struct Ctx end

code_warntype(TinyCassette.execute,
              Tuple{Ctx, typeof(foo),
                    Ptr{Float32}, Int})
