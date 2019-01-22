module Tofu

export ◻

import LinearAlgebra
import REPL

togetfield(ex) = ex
togetfield(ex::Expr) =
    if ex.head == :. && ex.args[1] == :g
        @assert length(ex.args) == 2
        :($getfield(g, $(ex.args[2])))
    else
        Expr(ex.head, togetfield.(ex.args)...)
    end

"""
  @G ex

Convert `g.PROPERTY` in `ex` to `getfield(g, :PROPERTY)`.
"""
macro G(ex)
    esc(togetfield(ex))
end

# --- Call graph

abstract type Graph end
struct Hole <: Graph end
struct Call{F,A,K} <: Graph
    f::F
    args::A
    kwargs::K
end
call(f, args...; kwargs...) = Call(f, args, kwargs.data)

Base.getproperty(g::Graph, name::Symbol) = call(getproperty, g, name)
Base.getindex(g::Graph, idx...) = call(getindex, g, idx...)

const binop_symbols = [
    :(=>),
    :>, :<, :≥, :≤, :(==), :!=, :∈, :∉, :∋, :∌,
    :+, :-, :|,
    :*, :/, :÷, :%, :&, :⋅, :∘, :×, :\,
    ://,
    :<<, :>>, :>>>,
    :^,
]
const binop_map = Dict(
    if n in (:⋅, :×)
        LinearAlgebra.dot => n
    else
        getproperty(Base, n) => n
    end
    for n in binop_symbols)
const binop_types = Union{typeof.(keys(binop_map))...}

for (f, name) in binop_map
    mod = parentmodule(f)
    @eval $mod.$name(x::Graph, y) = call($f, x, y)
    @eval $mod.$name(x, y::Graph) = call($f, x, y)
    @eval $mod.$name(x::Graph, y::Graph) = call($f, x, y)
end

# TODO: use https://github.com/JuliaDiff/DiffRules.jl
# (or maybe https://github.com/JuliaDiff/ChainRules.jl if it's ready)

const unaryops = [
    ~,
    adjoint,
]

for f in unaryops
    mod = parentmodule(f)
    name = nameof(f)
    @eval $mod.$name(x::Graph) = call($f, x)
end

# --- Evaluation

(g::Hole)(x) = materialize(g, x)
(g::Call)(x) = materialize(g, x)

materialize(y, _) = y
materialize(g::Hole, x) = x
materialize(g::Call, x) = @G g.f(feed(x, g.args...)...; g.kwargs...)

feed(x) = ()
feed(x, a, args...) = (materialize(a, x), feed(x, args...)...)

# --- Show it like you build it

Base.show(io::IO, ::Hole) = print(io, "◻")
Base.show(io::IO, g::Call) = @G show_impl(io, g.f, g.args, g.kwargs)

function show_impl(io, f, args, kwargs)
    print(io, f, '(')
    if length(args) > 0
        show(io, args[1])
        for a in args[2:end]
            print(io, ", ")
            show(io, a)
        end
    end
    if length(kwargs) > 0
    end
    print(io, ')')
end

function show_impl(io, f::binop_types, args, kwargs)
    @assert length(kwargs) == 0
    if length(args) > 0
        show_term(io, f, args[1])
        for a in args[2:end]
            print(io, ' ', binop_map[f], ' ')
            show_term(io, f, a)
        end
    end
end

function show_term(io, f, a)
    if need_paren(f, a)
        print(io, '(')
        show(io, a)
        print(io, ')')
    else
        show(io, a)
    end
end

need_paren(f, g) = false
need_paren(f, g::Call) = @G g.f isa binop_types && g.f !== f

function show_impl(io, ::typeof(getproperty), args, kwargs)
    value, (name::Symbol) = args
    @assert length(args) == 2
    @assert length(kwargs) == 0
    show(io, value)
    print(io, '.')
    print(io, name)
    return
end

function show_impl(io, ::typeof(getindex), args, kwargs)
    @assert length(kwargs) == 0
    show(io, args[1])
    print(io, '[')
    if length(args) > 1
        show(io, args[2])
        for a in args[3:end]
            print(io, ", ")
            show(io, a)
        end
    end
    print(io, ']')
    return
end

# --- User interface

const ◻ = Hole()

function __init__()
    try
        REPL.REPLCompletions.latex_symbols["\\tofu"] = "◻"
    catch err
        @error "Incompatible REPL module; Disabling LaTeX command `\\tofu`" err
    end
end

end # module
