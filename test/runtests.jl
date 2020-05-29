using UnderscoreOh
using Test

@testset "UnderscoreOh.jl" begin
    @test (_o.x)((x=1,)) == 1
    @test (_o.x + 2)((x=1,)) == 3
    @test_broken detect_ambiguities(UnderscoreOh, Base, imported=true, recursive=true) == []
end
