module UnderscoreOh

export _o, _nt

using Base.Broadcast: Broadcasted
import LinearAlgebra

# --- Call graph

abstract type Graph <: Function end
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

const unaryops = [
    ~,
    adjoint,
]

# --- Broadcasting

struct UnderscoreOhStyle <: Broadcast.BroadcastStyle end
Base.BroadcastStyle(::Type{<:Graph}) = UnderscoreOhStyle()
Base.BroadcastStyle(::UnderscoreOhStyle, ::Broadcast.BroadcastStyle) = UnderscoreOhStyle()

Base.broadcastable(x::Graph) = x
Broadcast.instantiate(bc::Broadcasted{UnderscoreOhStyle}) = bc

# Convert broadcasted to a callable
Base.copy(bc::Broadcasted{UnderscoreOhStyle}) = asgraph(bc)

asgraph(x) = x
asgraph(bc::Broadcasted) = call(bc.f, map(asgraph, bc.args)...)

function _nt(; kwargs...)
    if any(x -> x isa Graph, values(kwargs))
        return call(_nt; kwargs...)
    else
        return (; kwargs...)
    end
end

# --- Evaluation

(g::Hole)(x) = materialize(g, x)
(g::Call)(x) = materialize(g, x)

materialize(y, _) = y
materialize(g::Hole, x) = x
materialize(g::Call, x) = _f(g)(feed(x, _args(g))...; feed(x, _kwargs(g))...)

feed(x, args::Tuple) = map(a -> materialize(a, x), args)
feed(x, kwargs::NamedTuple) = _map(a -> materialize(a, x), kwargs)

_map(f, xs::NamedTuple{names}) where {names} = NamedTuple{names}(map(f, Tuple(xs)))

# --- Indexing

# Base.getindex(x::AbstractArray, g::Graph) = g.(x)

# --- Show it like you build it

maybe_print_dot(io) =
    get(io, :_secrete_print_dot_key, true) ? print(io, '.') : nothing
unset_print_dot(io) = IOContext(io, :_secrete_print_dot_key => false)

@nospecialize

Base.show(io::IO, ::Hole) = printstyled(io, "_o"; color = :light_black)
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
        print(io, "; ")
        isfirst = true
        for (k, v) in pairs(kwargs)
            if isfirst
                isfirst = false
            else
                print(io, ", ")
            end
            print(io, k, "=")
            show(io, v)
        end
    end
    print(io, ')')
end

function show_impl(io, f::binop_types, args, kwargs)
    @assert length(kwargs) == 0
    if length(args) > 0
        show_term(io, f, args[1])
        for a in args[2:end]
            print(io, ' ')
            maybe_print_dot(io)
            print(io, binop_map[f], ' ')
            show_term(io, f, a)
        end
    end
end

function show_term(io, f, a)
    if need_paren(f, a)
        maybe_print_dot(io)
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

function Base.show(io::IO, ::MIME"text/plain", g::Graph)
    print(io, _o, " -> ")
    show(unset_print_dot(io), g)
end

# `Base.Function` defines those methods to be something different
Base.print(io::IO, g::Graph) = show(io, g)

@specialize

# --- User interface

const _o = Hole()

end # module
