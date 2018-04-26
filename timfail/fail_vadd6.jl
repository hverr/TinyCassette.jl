code_warntype(unsafe_load, Tuple{Ptr{Float32}})


using TinyCassette
struct GPUctx end

code_warntype(TinyCassette.execute,
              Tuple{GPUctx, typeof(unsafe_load), Ptr{Float32}})
