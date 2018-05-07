Base.@pure function datatype_align(::Type{T}) where {T}
    # typedef struct {
    #     uint32_t nfields;
    #     uint32_t alignment : 9;
    #     uint32_t haspadding : 1;
    #     uint32_t npointers : 20;
    #     uint32_t fielddesc_type : 2;
    # } jl_datatype_layout_t;
    field = T.layout + sizeof(UInt32)
    unsafe_load(convert(Ptr{UInt16}, field)) & convert(Int16, 2^9-1)
end

abstract type AddressSpace end

struct Generic  <: AddressSpace end
struct Global   <: AddressSpace end
struct Shared   <: AddressSpace end
struct Constant <: AddressSpace end
struct Local    <: AddressSpace end

struct DevicePtr{T,A}
    ptr::Ptr{T}

    # inner constructors, fully parameterized
    DevicePtr{T,A}(ptr::Ptr{T}) where {T,A<:AddressSpace} = new(ptr)
end

Base.pointer(p::DevicePtr) = p.ptr

struct CuDeviceArray{T,N,A} <: AbstractArray{T,N}
    shape::NTuple{N,Int}
    ptr::DevicePtr{T,A}

    # inner constructors, fully parameterized, exact types (ie. Int not <:Integer)
    CuDeviceArray{T,N,A}(shape::NTuple{N,Int}, ptr::DevicePtr{T,A}) where {T,A,N} = new(shape,ptr)
end

Base.pointer(a::CuDeviceArray) = a.ptr
Base.size(g::CuDeviceArray) = g.shape
Base.length(g::CuDeviceArray) = prod(g.shape)
Base.checkbounds(::CuDeviceArray, I...) = nothing

@inline function Base.getindex(A::CuDeviceArray{T}, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    align = datatype_align(T)
    Base.unsafe_load(pointer(A), index, Val(align))::T
end

@inline function Base.setindex!(A::CuDeviceArray{T}, x, index::Integer) where {T}
    @boundscheck checkbounds(A, index)
    align = datatype_align(T)
    Base.unsafe_store!(pointer(A), x, index, Val(align))
end

function kernel_vadd(a, b, c, i)
    c[i] = a[i] + b[i]
    return nothing
end


Base.code_warntype(stdout, kernel_vadd, Tuple{CuDeviceArray{Float32,1,Global},
                                          CuDeviceArray{Float32,1,Global},
                                          CuDeviceArray{Float32,1,Global},
                                          Int})


exit(0)
using TinyCassette
struct Ctx end

Base.code_llvm(stdout, TinyCassette.execute,
               Tuple{Ctx, typeof(kernel_vadd),
                     CuDeviceArray{Float32,1,Global},
                     CuDeviceArray{Float32,1,Global},
                     CuDeviceArray{Float32,1,Global},
                     Int})
