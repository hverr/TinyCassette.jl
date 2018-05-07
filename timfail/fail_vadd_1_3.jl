using CUDAnative: AS, DevicePtr

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

function kernel_vadd(a::DevicePtr{T,A}, b::DevicePtr{T,A}, c::DevicePtr{T,A}, i::Int) where {T,A}
    align = datatype_align(T)
    x = unsafe_load(a, i, Val(align)) + unsafe_load(b, i, Val(align))
    unsafe_store!(c, x, i, Val(align))
    return nothing
end


Base.code_llvm(stdout, kernel_vadd, Tuple{DevicePtr{Float32,AS.Global},
                                          DevicePtr{Float32,AS.Global},
                                          DevicePtr{Float32,AS.Global},
                                          Int})

using TinyCassette
struct Ctx end

Base.code_llvm(stdout, TinyCassette.execute,
               Tuple{Ctx, typeof(kernel_vadd),
                     DevicePtr{Float32,AS.Global},
                     DevicePtr{Float32,AS.Global},
                     DevicePtr{Float32,AS.Global},
                     Int})
