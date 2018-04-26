code_warntype(unsafe_load, Tuple{Ptr{Float32}})


using Cassette
Cassette.@context Ctx

code_warntype(Cassette.overdub(Ctx, unsafe_load), Tuple{Ptr{Float32}})
