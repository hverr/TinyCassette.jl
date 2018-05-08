code_llvm(unsafe_load, Tuple{Ptr{Float32}})


using TinyCassette
struct GPUctx end

code_llvm(TinyCassette.execute,
              Tuple{GPUctx, typeof(unsafe_load), Ptr{Float32}})
