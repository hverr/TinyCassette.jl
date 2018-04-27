
function kernel(i)
    @inbounds (1,2,3)[i]
end


code_llvm(stdout, kernel, Tuple{Int})

using TinyCassette
struct Ctx end

code_llvm(stdout, TinyCassette.execute,
          Tuple{Ctx,
                typeof(kernel),
                Int})
