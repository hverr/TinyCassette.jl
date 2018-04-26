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

function kernel_vadd(a, b, c, i)
    c[i] = a[i] + b[i]

    return nothing
end


code_llvm(STDOUT, kernel_vadd, Tuple{CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1},
                                     CuDeviceArray{Float32,1},
                                     Int})


using Cassette
Cassette.@context Ctx

code_llvm(STDOUT, Cassette.overdub(Ctx, kernel_vadd),
          Tuple{CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1},
                CuDeviceArray{Float32,1},
                Int})
