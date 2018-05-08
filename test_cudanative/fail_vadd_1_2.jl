
@generated function _index(::Val{name}) where {name}
    #:(Int((ccall("llvm.nvvm.read.ptx.sreg.ctaid.x", llvmcall, UInt32, ()))+UInt32(1)))

    s = "llvm.nvvm.read.ptx.sreg.ctaid.$name"
    :(Int((ccall($s, llvmcall, UInt32, ()))+UInt32(1)))
end

#@inline blockIdx_x() = Int((ccall("llvm.nvvm.read.ptx.sreg.ctaid.x", llvmcall, UInt32, ()))+UInt32(1))
@inline blockIdx_x() = _index(Val(:x))
@inline blockIdx_y() = _index(Val(:y))
@inline blockIdx_z() = _index(Val(:z))

@inline blockIdx() = (x=blockIdx_x(), y=blockIdx_y(), z=blockIdx_z())

function kernel_vadd()
    blockIdx().x-1
end


code_llvm(stdout, kernel_vadd, Tuple{})


using TinyCassette
struct Ctx end

code_llvm(stdout, TinyCassette.execute,
          Tuple{Ctx,
                typeof(kernel_vadd)})
