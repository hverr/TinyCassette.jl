using CUDAnative

function kernel_vadd(a, b, c)
    blockIdx().x
end


Base.code_llvm(stdout, kernel_vadd, Tuple{CuDeviceArray{Float32,1,AS.Global},
                                          CuDeviceArray{Float32,1,AS.Global},
                                          CuDeviceArray{Float32,1,AS.Global}})


using TinyCassette
struct Ctx end

Base.code_llvm(stdout, TinyCassette.execute,
               Tuple{Ctx, typeof(kernel_vadd),
                     CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global}})
