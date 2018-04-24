@inline execute(ctx::Any, f, args...) = overdub_recurse(ctx, f, args...)

#@generated function overdub_recurse(ctx, f, args...)
function overdub_recurse_gen(self, ctx, f, args)
    # configure the global logger to use plain stderr so that we can log without task switches
    old_logger = global_logger()
    global_logger(Logging.ConsoleLogger(Core.stderr))
    @info "Overdubbing function call" func=f types=args

    # don't recurse into Core
    if parentmodule(f) == Core
        global_logger(old_logger)
        return :(f(args...))
    end

    # refuse to overdub already-overdubbed functions
    if f <: typeof(execute)
        error("can't double-overdub")
    end

    # slot number flag indicating that it is already set
    # yes this is hacky :o
    mark_fixed = Int64(1 << 62)

    # retrieve code
    # NOTE: this could use code_lowered if it weren't for F being a function type
    world = typemax(UInt)
    ## initial Method
    matched_methods = Base._methods_by_ftype(Tuple{f,args...}, -1, world)
    length(matched_methods) == 1 || error("did not uniquely match method")
    type_signature, raw_static_params, method = first(matched_methods)
    ## initial CodeInfo
    method_instance = Core.Compiler.code_for_method(method, type_signature, raw_static_params, world, false)
    method_signature = method.sig
    static_params = Any[raw_static_params...]
    code_info = Core.Compiler.retrieve_code_info(method_instance)
    isa(code_info, Core.CodeInfo) || error("could not retrieve original code")

    # prepare for rewriting
    body = Expr(:block)
    original_code_info = code_info
    code_info = Core.Compiler.copy_code_info(code_info)
    body.args = code_info.code
    insert_point = findfirst(item->isa(item,Expr), body.args) # past meta, lineno, ...

    # NOTE: most of the complexity here comes from the disconnect between (the signature of)
    #       the called generated function, and the function whose code we're injecting.
    #       arguably, the Julia compiler should handle this (see Cassette.jl#7).

    # substitute static parameters (the called generator doesn't have any)
    Core.Compiler.substitute!(body, 0, Any[], method_signature, static_params, 0, :propagate)

    # rewrite function calls
    # these slotnumbers will not be bumped
    context_slot = Core.SlotNumber(2 | mark_fixed)

    worklist = Any[map(item->(item,item), body.args)...] # item & pos to insert before
    while !isempty(worklist)
        item, paren = popfirst!(worklist)

        if isa(item, Expr)
            # queue expr arguments
            append!(worklist, map(item->(item,paren), item.args))
        end

        if Meta.isexpr(item, :call)
            orig_func = item.args[1]
            item.args[1] = GlobalRef(@__MODULE__, :execute)
            insert!(item.args, 2, context_slot)
            insert!(item.args, 3, orig_func)
        end
    end

    # destructure the splatted argument tuple
    argc = length(args)
    paramc = method.nargs - 1
    splat = Core.SlotNumber(4) # this won't be bumped later on
    ## fix up codeinfo arrays
    code_info.slotnames = Any[code_info.slotnames[1], Symbol("#ctx#"), Symbol("#f#"), Symbol("#args#"), code_info.slotnames[2:end]...]
    code_info.slotflags = Any[code_info.slotflags[1], 0x00           , 0x00         , 0x00            , code_info.slotflags[2:end]...]
    ## generate new slots
    prelude = Expr[]
    for i in 1:paramc
        # insert new slot
        slotnum = i+4
        slot = Core.SlotNumber(slotnum)
        code_info.slotflags[slotnum] |= 0x01 << 0x01    # mark the slot as assigned to

        # populate it with the actual argument
        arg = Expr(:call, GlobalRef(Core, :getfield), splat, i)
        push!(prelude, :($slot = $arg))
    end
    ## fix uses of slots
    function replace_nodes!(f, code)
        for (i,node) in enumerate(code)
            replacement = f(node)
            if replacement !== nothing
                code[i] = replacement
            elseif isa(node, Expr)
                # visit expr arguments
                replace_nodes!(f, node.args)
            end
        end
    end
    replace_nodes!(body.args) do node
        if isa(node, Core.SlotNumber) && node.id == 1
            return Core.SlotNumber(3)
        elseif isa(node, Core.SlotNumber) && (node.id & mark_fixed) == mark_fixed
            return Core.SlotNumber(node.id & ~mark_fixed)
        elseif isa(node, Core.SlotNumber)
            return Core.SlotNumber(node.id+3)
        elseif isa(node, Core.NewvarNode) && node.slot.id > 1
            return Core.NewvarNode(Core.SlotNumber(node.slot.id+3))
        end
    end
    ## special handling for vararg parameters
    if method.isva
        # the previous final slot assignment is wrong
        isempty(prelude) || pop!(prelude)
        # instead create and assign a tuple containing all trailing arguments
        vararg = Expr(:call, GlobalRef(Core, :tuple))
        for i in paramc:argc
            ssa = Core.SSAValue(code_info.ssavaluetypes)
            arg = Expr(:call, GlobalRef(Core, :getfield), splat, i)
            push!(prelude, :($ssa = $arg))
            push!(vararg.args, ssa)
            code_info.ssavaluetypes += 1
        end
        push!(prelude, :($(Core.SlotNumber(paramc + 4)) = $vararg))
    end
    ## insert slot definitions
    for expr in reverse(prelude)
        insert!(body.args, insert_point, expr)
    end

    # fix labels and references to them
    changes = Dict{Int,Int}()
    for (i, stmnt) in enumerate(code_info.code)
        if isa(stmnt, Core.LabelNode)
            code_info.code[i] = Core.LabelNode(i)
            changes[stmnt.label] = i
        end
    end
    for (i, stmnt) in enumerate(code_info.code)
        if isa(stmnt, Core.GotoNode)
            code_info.code[i] = Core.GotoNode(get(changes, stmnt.label, stmnt.label))
        elseif Meta.isexpr(stmnt, :enter)
            stmnt.args[1] = get(changes, stmnt.args[1], stmnt.args[1])
        elseif Meta.isexpr(stmnt, :gotoifnot)
            stmnt.args[2] = get(changes, stmnt.args[2], stmnt.args[2])
        end
    end

    code_info.method_for_inference_limit_heuristics = method
    code_info.inlineable = true

    # validate
    errors = Core.Compiler.validate_code(method_instance, code_info)
    for e in errors
        @error "Encountered invalid code" code=body.args error=e
    end

    @info "Rewriting code" original=original_code_info overdubbed=code_info
    global_logger(old_logger)
    return code_info
end

@eval function overdub_recurse(ctx, f, args...)
    # manual construction of the generated function in order to control the expand_early arg
    $(begin
          stub = Expr(:new,
                      Core.GeneratedFunctionStub,
                      :overdub_recurse_gen,
                      Any[:overdub_recurse, :ctx, :f, :args],
                      Any[],
                      @__LINE__,
                      QuoteNode(Symbol(@__FILE__)),
                      true)
          Expr(:meta, :generated, stub)
      end)
end
