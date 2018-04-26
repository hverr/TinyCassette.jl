using CUDAnative

function kernel_vadd(a, b, c)
    i = (blockIdx().x-1) * blockDim().x + threadIdx().x
    c[i] = a[i] + b[i]

    return nothing
end


Base.code_llvm(STDOUT, kernel_vadd, Tuple{CuDeviceArray{Float32,1,AS.Global},
                                          CuDeviceArray{Float32,1,AS.Global},
                                          CuDeviceArray{Float32,1,AS.Global}})


using Cassette
Cassette.@context Ctx

Base.code_llvm(STDOUT, Cassette.overdub(Ctx, kernel_vadd),
               Tuple{CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global}})
