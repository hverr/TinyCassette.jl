@testset "infer generated function" begin
    function code_llvm_lines(g, t)
        buf = IOBuffer()
        code_llvm(buf, g, t)
        return filter(x -> !startswith(x, ";"), split(String(buf), "\n"))
    end

    function llvm_eq(a, b)
        if length(a) != length(b)
            return false
        end

        for (i, j) in zip(a, b)
            r = r"define(.*)@julia"
            mi = match(r, i)
            mj = match(r, j)
            if mi != nothing && mj != nothing
                if mi[1] != mj[1]
                    return false
                end
            elseif mi != nothing || mj != nothing
                return false
            elseif i != j
                return false
            end
        end
        return true
    end

    @testset "simple" begin
        @eval @generated function f(t)
            if t <: Int
                :(t + 3)
            else
                println(t)
            end
        end

        @eval function g(x)
            f(x)
        end

        orig = code_llvm_lines(g, Tuple{Int64})

        dub_tt = Tuple{Nothing, typeof(g), Int64}
        over = code_llvm_lines(TinyCassette.execute, dub_tt)

        @test llvm_eq(orig, over)
    end

    @testset "with Val" begin
        @eval @generated function f(::Val{name}) where {name}
            i = "llvm.nvvm.read.ptx.sreg.tid.$name"
            :(Int(ccall($i, llvmcall, UInt32, ())))
        end

        @eval @inline x() = f(Val(:x))

        @eval function g()
            x()
        end

        orig = code_llvm_lines(g, Tuple{})

        dub_tt = Tuple{Nothing, typeof(g)}
        over = code_llvm_lines(TinyCassette.execute, dub_tt)

        @test llvm_eq(orig, over)
    end
end
