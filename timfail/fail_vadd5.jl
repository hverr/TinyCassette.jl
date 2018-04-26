foo(ptr::Ptr{T}, i) where {T} = Base.unsafe_load(ptr, i)::T


code_warntype(foo, Tuple{Ptr{Float32}, Int})

using Cassette
Cassette.@context Ctx

code_warntype(Cassette.overdub(Ctx, foo),
              Tuple{Ptr{Float32}, Int})
