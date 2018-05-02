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

@inline blockIdx_x() = (ccall("llvm.nvvm.read.ptx.sreg.ctaid.x", llvmcall, UInt32, ()))+UInt32(1)
@inline blockIdx_y() = (ccall("llvm.nvvm.read.ptx.sreg.ctaid.y", llvmcall, UInt32, ()))+UInt32(1)
@inline blockIdx_z() = (ccall("llvm.nvvm.read.ptx.sreg.ctaid.z", llvmcall, UInt32, ()))+UInt32(1)

@inline blockIdx() = (blockIdx_x(), blockIdx_y(), blockIdx_z())

function kernel_vadd(a, b, c)
    i = blockIdx()[1]-UInt32(1)
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
