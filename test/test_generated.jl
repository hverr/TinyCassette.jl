#@testset "infer generated function" begin
#    @testset "simple" begin
#        @eval @generated function f(t)
#            if t <: Int
#                :(t + 3)
#            else
#                println(t)
#            end
#        end
#
#        @eval function g(x)
#            f(x)
#        end
#
#        code_llvm(stdout, g, Tuple{Int64})
#
#        dub_tt = Tuple{Nothing, typeof(g), Int64}
#        code_llvm(stdout, TinyCassette.execute, dub_tt)
#    end
#end

##############
##############
##############

@generated function f(::Val{name}) where {name}
    i = "llvm.nvvm.read.ptx.sreg.tid.$name"
    :(Int(ccall($i, llvmcall, UInt32, ())))
end

@inline x() = f(Val(:x))

function g()
    x()
end

code_llvm(stdout, g, Tuple{})

dub_tt = Tuple{Nothing, typeof(g)}
code_llvm(stdout, TinyCassette.execute, dub_tt)
