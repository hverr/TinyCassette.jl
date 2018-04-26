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

for dim in (:x, :y, :z)
    # Thread index
    fn = Symbol("threadIdx_$dim")
    @eval @inline $fn() = (ccall($"llvm.nvvm.read.ptx.sreg.tid.$dim", llvmcall, UInt32, ()))+UInt32(1)

    # Block size (#threads per block)
    fn = Symbol("blockDim_$dim")
    @eval @inline $fn() =  ccall($"llvm.nvvm.read.ptx.sreg.ntid.$dim", llvmcall, UInt32, ())

    # Block index
    fn = Symbol("blockIdx_$dim")
    @eval @inline $fn() = (ccall($"llvm.nvvm.read.ptx.sreg.ctaid.$dim", llvmcall, UInt32, ()))+UInt32(1)

    # Grid size (#blocks per grid)
    fn = Symbol("gridDim_$dim")
    @eval @inline $fn() =  ccall($"llvm.nvvm.read.ptx.sreg.nctaid.$dim", llvmcall, UInt32, ())
end

@inline gridDim() =   (gridDim_x(),   gridDim_y(),   gridDim_z())

@inline blockIdx() =  (blockIdx_x(),  blockIdx_y(),  blockIdx_z())

@inline blockDim() =  (blockDim_x(),  blockDim_y(),  blockDim_z())

@inline threadIdx() = (threadIdx_x(), threadIdx_y(), threadIdx_z())

function kernel_vadd(a, b, c)
    i = (blockIdx()[1]-1) * blockDim()[1] + threadIdx()[1]
    c[i] = a[i] + b[i]

    return nothing
end


code_llvm(STDOUT, kernel_vadd, Tuple{CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1}})


using Cassette
Cassette.@context Ctx

code_llvm(STDOUT, Cassette.overdub(Ctx, kernel_vadd),
          Tuple{CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1}})
