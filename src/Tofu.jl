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
