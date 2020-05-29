using UnderscoreOh
using Test

@testset "UnderscoreOh.jl" begin
    @test (◻.x)((x=1,)) == 1
    @test (◻.x + 2)((x=1,)) == 3
    @test_broken detect_ambiguities(UnderscoreOh, Base, imported=true, recursive=true) == []
end
