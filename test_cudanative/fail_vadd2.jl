struct CuDeviceArray{T,N} <: AbstractArray{T,N}
    shape::NTuple{N,Int}
    ptr::Ptr{T}
end

@inline function Base.setindex!(A::CuDeviceArray{T}, x, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    Base.unsafe_store!(A.ptr, x, index)
end

@inline function Base.getindex(A::CuDeviceArray{T}, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    Base.unsafe_load(A.ptr, index)::T
end

Base.size(g::CuDeviceArray) = g.shape

Base.checkbounds(::CuDeviceArray, I...) = nothing

for dim in (:x, :y, :z)
    # Thread index
    fn = Symbol("threadIdx_$dim")
    @eval @inline $fn() = Int((ccall($"llvm.nvvm.read.ptx.sreg.tid.$dim", llvmcall, UInt32, ()))+UInt32(1))

    # Block size (#threads per block)
    fn = Symbol("blockDim_$dim")
    @eval @inline $fn() =  Int(ccall($"llvm.nvvm.read.ptx.sreg.ntid.$dim", llvmcall, UInt32, ()))

    # Block index
    fn = Symbol("blockIdx_$dim")
    @eval @inline $fn() = Int((ccall($"llvm.nvvm.read.ptx.sreg.ctaid.$dim", llvmcall, UInt32, ()))+UInt32(1))

    # Grid size (#blocks per grid)
    fn = Symbol("gridDim_$dim")
    @eval @inline $fn() =  Int(ccall($"llvm.nvvm.read.ptx.sreg.nctaid.$dim", llvmcall, UInt32, ()))
end

@inline gridDim() =   (x=gridDim_x(),   y=gridDim_y(),   z=gridDim_z())

@inline blockIdx() =  (x=blockIdx_x(),  y=blockIdx_y(),  z=blockIdx_z())

@inline blockDim() =  (x=blockDim_x(),  y=blockDim_y(),  z=blockDim_z())

@inline threadIdx() = (x=threadIdx_x(), y=threadIdx_y(), z=threadIdx_z())

function kernel_vadd(a, b, c)
    i = (blockIdx().x-1) * blockDim().x + threadIdx().x
    c[i] = a[i] + b[i]

    return nothing
end


code_llvm(stdout, kernel_vadd, Tuple{CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1}})


using TinyCassette
struct Ctx end

code_llvm(stdout, TinyCassette.execute,
          Tuple{Ctx,
                typeof(kernel_vadd),
                CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1}})
