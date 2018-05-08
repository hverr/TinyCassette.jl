
@inline blockIdx_x() = (ccall("llvm.nvvm.read.ptx.sreg.ctaid.x", llvmcall, UInt32, ()))+UInt32(1)

function kernel_vadd()
    blockIdx_x()-UInt32(1)
end


code_llvm(stdout, kernel_vadd, Tuple{})


using TinyCassette
struct Ctx end

code_llvm(stdout, TinyCassette.execute,
          Tuple{Ctx,
                typeof(kernel_vadd)})
