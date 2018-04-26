struct CuDeviceArray{T,N} <: AbstractArray{T,N}
    shape::NTuple{N,Int}
    ptr::Ptr{T}
end

@inline function Base.getindex(A::CuDeviceArray{T}, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    Base.unsafe_load(A.ptr, index)::T
end

Base.size(g::CuDeviceArray) = g.shape

Base.checkbounds(::CuDeviceArray, I...) = nothing

function kernel(a, i)
    return a[i]
end


code_llvm(stdout, kernel, Tuple{CuDeviceArray{Float32,1}, Int})


using TinyCassette
struct GPUctx end

code_llvm(stdout, TinyCassette.execute,
          Tuple{GPUctx, typeof(kernel), CuDeviceArray{Float32,1}, Int})
