# wrapper for overdubbing functions
struct Overdub{F,C}
    func::F
    context::C
    Overdub(f::F, c::C=nothing) where {F,C} = new{F,C}(f,c)
end

@generated function (o::Overdub{F,C})(args...) where {F,C}
    # configure the global logger to use plain stderr so that we can log without task switches
    old_logger = global_logger()
    global_logger(Logging.ConsoleLogger(Core.stderr))
    @info "Overdubbing function call" func=F types=args

    # don't recurse into Core
    if parentmodule(F) == Core
        global_logger(old_logger)
        return :((o.func)(args...))
    end

    # refuse to overdub already-overdubbed functions
    if F <: Overdub
        error("can't double-overdub")
    end

    # retrieve code
    # NOTE: this could use code_lowered if it weren't for F being a function type
    world = typemax(UInt)
    ## initial Method
    matched_methods = Base._methods_by_ftype(Tuple{F,args...}, -1, world)
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

    # prepare references to the underlying function and context
    func = Core.SSAValue(code_info.ssavaluetypes)
    code_info.ssavaluetypes += 1
    context = Core.SSAValue(code_info.ssavaluetypes)
    code_info.ssavaluetypes += 1
    
    # rewrite function calls
    self = Core.SlotNumber(1)
    worklist = Any[map(item->(item,item), body.args)...] # item & pos to insert before
    while !isempty(worklist)
        item, paren = popfirst!(worklist)

        if isa(item, Expr)
            # queue expr arguments
            append!(worklist, map(item->(item,paren), item.args))
        end

        if Meta.isexpr(item, :call)
            # don't overdub calls to self, because this now already points to Overdub
            orig = item.args[1]
            if orig != self
                # insert new SSA value
                ssaval = Core.SSAValue(code_info.ssavaluetypes)
                code_info.ssavaluetypes += 1

                # populate it with the replacement function
                dub = GlobalRef(@__MODULE__, :Overdub)
                new = :($dub($orig,$context))
                def = :($ssaval = $new)

                # insert the definition right before the use (this is important, as the
                # function argument can itself be an SSA value)
                pos = findfirst(isequal(paren), body.args)
                insert!(body.args, pos, def)

                item.args[1] = ssaval
            end
        end
    end

    # destructure the splatted argument tuple
    argc = length(args)
    paramc = method.nargs - 1
    splat = Core.SlotNumber(2)
    ## fix up codeinfo arrays
    code_info.slotnames = Any[code_info.slotnames[1], Symbol("#args#"), code_info.slotnames[2:end]...]
    code_info.slotflags = Any[code_info.slotflags[1], 0x00,             code_info.slotflags[2:end]...]
    ## generate new slots
    prelude = Expr[]
    for i in 1:paramc
        # insert new slot
        slotnum = i+2
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
            return func
        elseif isa(node, Core.SlotNumber) && node.id > 1
            return Core.SlotNumber(node.id+1)
        elseif isa(node, Core.NewvarNode) && node.slot.id > 1
            return Core.NewvarNode(Core.SlotNumber(node.slot.id+1))
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
        push!(prelude, :($(Core.SlotNumber(paramc + 2)) = $vararg))
    end
    ## insert slot definitions
    for expr in reverse(prelude)
        insert!(body.args, insert_point, expr)
    end

    # actually get the value of the underlying function and context
    insert!(body.args, insert_point, :($context =
        $(Expr(:call, GlobalRef(Core, :getfield), self, QuoteNode(:context)))))
    insert!(body.args, insert_point, :($func =
        $(Expr(:call, GlobalRef(Core, :getfield), self, QuoteNode(:func)))))

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

    # validate
    errors = Core.Compiler.validate_code(method_instance, code_info)
    for e in errors
        @error "Encountered invalid code" code=body.args error=e
    end

    @info "Rewriting code" original=original_code_info overdubbed=code_info
    global_logger(old_logger)
    return code_info
end
