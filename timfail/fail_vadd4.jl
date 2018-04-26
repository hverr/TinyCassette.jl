struct CuDeviceArray{T,N} <: AbstractArray{T,N}
    shape::NTuple{N,Int}
    ptr::Ptr{T}
end

@inline function Base.getindex(A::CuDeviceArray{T}, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    Base.unsafe_load(A.ptr, index)::T
end

Base.size(g::CuDeviceArray) = g.shape

function kernel(a, i)
    return a[i]
end


code_llvm(STDOUT, kernel, Tuple{CuDeviceArray{Float32,1}, Int})


using Cassette
Cassette.@context Ctx

code_llvm(STDOUT, Cassette.overdub(Ctx, kernel),
          Tuple{CuDeviceArray{Float32,1}, Int})
