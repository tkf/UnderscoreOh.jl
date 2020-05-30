module TestUnderscoreOh

using UnderscoreOh
using Test

struct IdentityProperties end
Base.getproperty(::IdentityProperties, x::Symbol) = x
Base.getproperty(::IdentityProperties, x) = x

@testset "eval" begin
    @test (_o.x)((x = 1,)) == 1
    @test (_o.x .+ 2)((x = 1,)) == 3
    @test (_o[2])((11, 22)) == 22
    @test (_o.x[2])((x = (11, 22),)) == 22
    @test (_o.p)(IdentityProperties()) == :p
    @test (_o."p")(IdentityProperties()) == "p"
    @test (_o.x[2]."p")((x = (11, IdentityProperties()),)) == "p"
    @test _nt(X = (_o.x))((x = 1,)) == (X = 1,)
end

@testset "~" begin
    @test identity.(~ _o.x) === ~(_o.x)
    @test identity.(~(_o .+ 1)) === ~(_o .+ 1)
end

const DATASET_REPR = [
    # Desired `repr(_)` outputs:
    "_o",
    "_o.x",
    "_o.\"x\"",
    "_o .* 2",
    "getproperty.(_o, 1, 2, 3)",
    "getproperty.(_o, 1; k=1)",
    "2 .* _o .* 2",
    "(2 .* _o .* 2) .+ 0",
    "2 .* _o",
    "2 .* _o[1]",
    "2 .* _o.x[1]",
    "2 .* _o.x[1].a",
    "2 .* identity.(_o.x[1]).a",
    "identity.(2 .* _o.x[1]).a",
]

sshow3(x; kwargs...) = sprint(show, MIME"text/plain"(), x; kwargs...)

@testset "show" begin
    @testset for code in DATASET_REPR
        @test repr(include_string(@__MODULE__, code)) == code
    end
    suffix = "(generic function with 1 method)"
    @test sshow3(_o) == "_o -> _o $suffix"
    @test sshow3(_o .* 2) == "_o -> _o * 2 $suffix"
    @test sshow3(_o[1].x .* 2) == "_o -> _o[1].x * 2 $suffix"
    @test sshow3(_o; context = :compact => true) == "(_o)"
    @test sshow3(2 .* _o; context = :compact => true) == "(2 .* _o)"
    @testset "smoketest" begin
        @test !isempty(repr(getproperty(_o, nothing))::AbstractString)
        @test !isempty(repr(getproperty(_o, [1, 2]))::AbstractString)
    end
end

end  # module
