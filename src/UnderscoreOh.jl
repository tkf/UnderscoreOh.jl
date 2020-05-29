module UnderscoreOh

export _o

import LinearAlgebra
import REPL

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
Base.getproperty(g::Graph, prop) = call(getproperty, g, prop)
Base.getindex(g::Graph, idx...) = call(getindex, g, idx...)

_f(x) = getfield(x, :f)
_args(x) = getfield(x, :args)
_kwargs(x) = getfield(x, :kwargs)

const binop_symbols = [
    :(=>),
    :>, :<, :≥, :≤, :(==), :!=, :∈, :∉, :∋, :∌,
    :+, :-, :|,
    :*, :/, :÷, :%, :&, :⋅, :×, :\,
    ://,
    :<<, :>>, :>>>,
    :^,
]
const binop_map = Dict(
    if n in (:⋅, :×)
        getproperty(LinearAlgebra, n) => n
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

Base.:(:)(x::Graph, y) = call(:, x, y)
Base.:(:)(x, y::Graph) = call(:, x, y)
Base.:(:)(x::Graph, y::Graph) = call(:, x, y)
Base.:(:)(x::Graph, y, z) = call(:, x, y, z)
Base.:(:)(x, y::Graph, z) = call(:, x, y, z)
Base.:(:)(x, y, z::Graph) = call(:, x, y, z)
Base.:(:)(x::Graph, y::Graph, z) = call(:, x, y, z)
Base.:(:)(x::Graph, y, z::Graph) = call(:, x, y, z)
Base.:(:)(x, y::Graph, z::Graph) = call(:, x, y, z)
Base.:(:)(x::Graph, y::Graph, z::Graph) = call(:, x, y, z)

# Disambiguation:
Base.:(:)(x::T, y::Graph, z::T) where {T <: Real} = call(:, x, y, z)
Base.:(:)(x::T, y::Graph, z::T) where {T} = call(:, x, y, z)
Base.:(:)(x::Real, y::Graph, z::Real) = call(:, x, y, z)

# --- Evaluation

(g::Hole)(x) = materialize(g, x)
(g::Call)(x) = materialize(g, x)

materialize(y, _) = y
materialize(g::Hole, x) = x
materialize(g::Call, x) = _f(g)(feed(x, _args(g)...)...; _kwargs(g)...)

feed(x) = ()
feed(x, a, args...) = (materialize(a, x), feed(x, args...)...)

# --- Show it like you build it

Base.show(io::IO, ::Hole) = print(io, "_o")
Base.show(io::IO, g::Call) = show_impl(io, _f(g), _args(g), _kwargs(g))

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
need_paren(f, g::Call) = _f(g) isa binop_types && _f(g) !== f

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

function show_impl(io, ::Colon, args, kwargs)
    @assert length(kwargs) == 0
    if length(args) > 0
        show(io, args[1])
        for a in args[2:end]
            print(io, ":")
            show(io, a)
        end
    end
    return
end

# --- User interface

const _o = Hole()

end # module
