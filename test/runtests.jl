# test/runtests.jl — GrugBot420 Package Test Runner
# ==============================================================================
# GRUG: Test files fall into two categories:
#
#   IN-PROCESS: Single-module unit tests with isdefined guards. Safe to run
#               sequentially in one Julia process.
#
#   SUBPROCESS: Tests that include engine.jl + multiple src/ modules directly.
#               Must run in isolated subprocesses to avoid module redefinition.
#               No silent failures — non-zero exit code = test failure.
# ==============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..")
const TEST_DIR  = @__DIR__

# Single-module unit tests — safe in-process
const INPROCESS_TESTS = [
    "test_lobe_table.jl",
    "test_lobes.jl",
    "test_brainstem.jl",
    "test_thesaurus.jl",
    "test_input_queue.jl",
]

# Multi-module / engine-level tests — must be subprocess isolated
const SUBPROCESS_TESTS = [
    "test_action_packet.jl",
    "test_smoke.jl",
]

@testset "GrugBot420 Tests" begin

    @testset "Unit Tests" begin
        for f in INPROCESS_TESTS
            @testset "$f" begin
                try
                    include(joinpath(TEST_DIR, f))
                catch e
                    @test false
                    @error "!!! $f failed" exception=(e, catch_backtrace())
                end
            end
        end
    end

    @testset "Integration Tests" begin
        for f in SUBPROCESS_TESTS
            @testset "$f" begin
                fpath = joinpath(TEST_DIR, f)
                cmd = `$(Base.julia_cmd()) --project=$(REPO_ROOT) $fpath`
                ok = success(pipeline(cmd, stdout=stdout, stderr=stderr))
                @test ok
            end
        end
    end

end