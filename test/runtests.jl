using Tofu
using Test

@testset "Tofu.jl" begin
    @test (◻.x)((x=1,)) == 1
    @test (◻.x + 2)((x=1,)) == 3
    @test_broken detect_ambiguities(Tofu, Base, imported=true, recursive=true) == []
end
