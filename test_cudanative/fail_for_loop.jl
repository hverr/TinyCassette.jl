using CUDAnative

function kernel_vloop(a, b, c, i)
    c[i] = 0
    for j in 1:i
        c[i] += a[j] + b[j]
    end
    return nothing
end


Base.code_llvm(stdout, kernel_vloop, Tuple{CuDeviceArray{Float32,1,AS.Global},
                                           CuDeviceArray{Float32,1,AS.Global},
                                           CuDeviceArray{Float32,1,AS.Global},
                                           Int})

using TinyCassette
struct Ctx end

Base.code_llvm(stdout, TinyCassette.execute,
               Tuple{Ctx, typeof(kernel_vloop),
                     CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global},
                     CuDeviceArray{Float32,1,AS.Global},
                     Int})
