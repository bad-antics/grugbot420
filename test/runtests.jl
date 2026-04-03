# test/runtests.jl — GrugBot420 Package Test Runner
# ==============================================================================
# Runs all test suites in the proper order. Compatible with `Pkg.test()`.
# ==============================================================================

using Test

@testset "GrugBot420 Tests" begin

    @testset "LobeTable" begin
        include("test_lobe_table.jl")
    end

    @testset "Lobes" begin
        include("test_lobes.jl")
    end

    @testset "BrainStem" begin
        include("test_brainstem.jl")
    end

    @testset "Thesaurus" begin
        include("test_thesaurus.jl")
    end

    @testset "InputQueue" begin
        include("test_input_queue.jl")
    end

    @testset "ActionPacket" begin
        include("test_action_packet.jl")
    end

    @testset "Smoke" begin
        include("test_smoke.jl")
    end

end
