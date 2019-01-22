module Tofu

export ◻

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

for op in [:+, :-, :*, :/, ://, :div]
    @eval Base.$op(x::Graph, y) = call($op, x, y)
    @eval Base.$op(x, y::Graph) = call($op, x, y)
    @eval Base.$op(x::Graph, y::Graph) = call($op, x, y)
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
        @error "Incompatible REPL module disabling LaTeX command `\\tofu`" err
    end
end

end # module
