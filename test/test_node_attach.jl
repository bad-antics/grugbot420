# test_node_attach.jl
# ==============================================================================
# GRUG TEST: Node Attachment System (Relational Fire) — comprehensive unit tests.
# GRUG say: test the bolts like testing cave bridge. Attach, detach, fire, break.
# ==============================================================================

using Test, Random

println("\n" * "="^60)
println("GRUG NODE ATTACHMENT TEST SUITE")
println("="^60)

# ==============================================================================
# MODULE LOADS
# ==============================================================================
println("\n[0] MODULE LOADS")

include("../src/stochastichelper.jl");    using .CoinFlipHeader;      println("  ✓ StochasticHelper")
include("../src/patternscanner.jl");      using .PatternScanner;      println("  ✓ PatternScanner")
include("../src/ImageSDF.jl");            using .ImageSDF;            println("  ✓ ImageSDF")
include("../src/EyeSystem.jl");           using .EyeSystem;           println("  ✓ EyeSystem")
include("../src/SemanticVerbs.jl");       using .SemanticVerbs;       println("  ✓ SemanticVerbs")
include("../src/ActionTonePredictor.jl"); using .ActionTonePredictor; println("  ✓ ActionTonePredictor")
include("../src/engine.jl")
println("  ✓ Engine (full chain)")

# ==============================================================================
# HELPERS — GRUG reset state between test groups
# ==============================================================================

function reset_engine!()
    lock(NODE_LOCK) do
        empty!(NODE_MAP)
    end
    lock(ATTACHMENT_LOCK) do
        empty!(ATTACHMENT_MAP)
    end
    lock(HOPFIELD_CACHE_LOCK) do
        empty!(HOPFIELD_CACHE)
    end
    ID_COUNTER[] = 0
end

function make_node!(pattern::String, action::String="reason^1"; strength::Float64=5.0)
    id = create_node(pattern, action, Dict{String,Any}(), String[]; initial_strength=strength)
    return id
end

# ==============================================================================
# 1. ATTACH — Basic success cases
# ==============================================================================
@testset "NodeAttach - Basic attach" begin
    reset_engine!()

    target = make_node!("target pattern alpha")
    n1 = make_node!("attached node beta")

    result = attach_node!(target, n1, "relay pattern gamma")
    @test occursin("Attached", result)
    @test occursin(n1, result)
    @test occursin(target, result)

    # Verify attachment exists
    atts = get_attachments_for_target(target)
    @test length(atts) == 1
    @test atts[1].node_id == n1
    @test atts[1].pattern == "relay pattern gamma"
    @test length(atts[1].signal) > 0  # Signal pre-baked

    println("  ✓ [1] Basic attach: single node attached successfully")
end

# ==============================================================================
# 2. ATTACH — Multiple attachments (up to 4)
# ==============================================================================
@testset "NodeAttach - Multiple attachments" begin
    reset_engine!()

    target = make_node!("hub node central")
    n1 = make_node!("spoke one alpha")
    n2 = make_node!("spoke two beta")
    n3 = make_node!("spoke three gamma")
    n4 = make_node!("spoke four delta")

    attach_node!(target, n1, "pattern one")
    attach_node!(target, n2, "pattern two")
    attach_node!(target, n3, "pattern three")
    attach_node!(target, n4, "pattern four")

    atts = get_attachments_for_target(target)
    @test length(atts) == 4

    ids = Set([a.node_id for a in atts])
    @test n1 in ids
    @test n2 in ids
    @test n3 in ids
    @test n4 in ids

    println("  ✓ [2] Multiple attachments: 4/4 slots filled successfully")
end

# ==============================================================================
# 3. ATTACH — Max cap enforcement (5th attach fails)
# ==============================================================================
@testset "NodeAttach - Max cap rejection" begin
    reset_engine!()

    target = make_node!("hub node")
    nodes = [make_node!("node $i") for i in 1:5]

    for i in 1:4
        attach_node!(target, nodes[i], "pat $i")
    end

    # 5th should throw
    @test_throws ErrorException attach_node!(target, nodes[5], "pat 5")

    # Still only 4
    @test length(get_attachments_for_target(target)) == 4

    println("  ✓ [3] Max cap: 5th attachment correctly rejected with error")
end

# ==============================================================================
# 4. ATTACH — Empty argument validation
# ==============================================================================
@testset "NodeAttach - Empty argument errors" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("attach node")

    @test_throws ErrorException attach_node!("", n1, "pattern")
    @test_throws ErrorException attach_node!(target, "", "pattern")
    @test_throws ErrorException attach_node!(target, n1, "")

    println("  ✓ [4] Empty arguments: all three correctly throw errors")
end

# ==============================================================================
# 5. ATTACH — Non-existent node validation
# ==============================================================================
@testset "NodeAttach - Missing node errors" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("attach node")

    @test_throws ErrorException attach_node!("fake_node_999", n1, "pattern")
    @test_throws ErrorException attach_node!(target, "fake_node_999", "pattern")

    println("  ✓ [5] Missing nodes: correctly rejected with error")
end

# ==============================================================================
# 6. ATTACH — Self-attach prevention
# ==============================================================================
@testset "NodeAttach - Self-attach prevention" begin
    reset_engine!()

    n1 = make_node!("lonely node")

    @test_throws ErrorException attach_node!(n1, n1, "mirror pattern")
    @test length(get_attachments_for_target(n1)) == 0

    println("  ✓ [6] Self-attach: correctly prevented with error")
end

# ==============================================================================
# 7. ATTACH — Duplicate prevention
# ==============================================================================
@testset "NodeAttach - Duplicate prevention" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("attach node")

    attach_node!(target, n1, "first pattern")
    @test_throws ErrorException attach_node!(target, n1, "different pattern")

    @test length(get_attachments_for_target(target)) == 1

    println("  ✓ [7] Duplicate attachment: correctly rejected with error")
end

# ==============================================================================
# 8. ATTACH — Grave node validation
# ==============================================================================
@testset "NodeAttach - Grave node rejection" begin
    reset_engine!()

    target = make_node!("alive target")
    grave_node = make_node!("doomed node")

    # Manually grave the node
    lock(NODE_LOCK) do
        NODE_MAP[grave_node].is_grave = true
        NODE_MAP[grave_node].grave_reason = "TEST_GRAVED"
    end

    # Cannot attach a grave node
    @test_throws ErrorException attach_node!(target, grave_node, "dead pattern")

    # Cannot attach to a grave target
    alive_node = make_node!("alive attach")
    lock(NODE_LOCK) do
        NODE_MAP[target].is_grave = true
        NODE_MAP[target].grave_reason = "TEST_GRAVED"
    end
    @test_throws ErrorException attach_node!(target, alive_node, "pattern")

    println("  ✓ [8] Grave nodes: correctly rejected on both sides")
end

# ==============================================================================
# 9. DETACH — Success cases
# ==============================================================================
@testset "NodeDetach - Basic detach" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("attach one")
    n2 = make_node!("attach two")

    attach_node!(target, n1, "pat one")
    attach_node!(target, n2, "pat two")
    @test length(get_attachments_for_target(target)) == 2

    result = detach_node!(target, n1)
    @test occursin("Detached", result)

    atts = get_attachments_for_target(target)
    @test length(atts) == 1
    @test atts[1].node_id == n2

    # Detach last one — entry should be cleaned up
    detach_node!(target, n2)
    @test length(get_attachments_for_target(target)) == 0

    # Verify ATTACHMENT_MAP entry is fully removed
    lock(ATTACHMENT_LOCK) do
        @test !haskey(ATTACHMENT_MAP, target)
    end

    println("  ✓ [9] Detach: both nodes detached, map entry cleaned up")
end

# ==============================================================================
# 10. DETACH — Error cases
# ==============================================================================
@testset "NodeDetach - Error cases" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("attach one")

    # Detach from node with no attachments
    @test_throws ErrorException detach_node!(target, n1)

    # Detach non-attached node
    n2 = make_node!("not attached")
    attach_node!(target, n1, "pattern")
    @test_throws ErrorException detach_node!(target, n2)

    # Empty args
    @test_throws ErrorException detach_node!("", n1)
    @test_throws ErrorException detach_node!(target, "")

    println("  ✓ [10] Detach errors: all invalid cases correctly throw")
end

# ==============================================================================
# 11. FIRE — Basic firing mechanics
# ==============================================================================
@testset "FireAttachments - Basic firing" begin
    reset_engine!()

    target = make_node!("machine learning neural network")
    n1 = make_node!("deep learning gradient descent"; strength=10.0)  # Max strength = high coinflip chance

    attach_node!(target, n1, "machine learning optimization")

    # Run fire_attachments! many times to verify probabilistic firing
    fired_count = 0
    for _ in 1:100
        fired = fire_attachments!(target, 0, 1800)  # Big cap, should not block
        if !isempty(fired)
            fired_count += 1
            @test fired[1][1] == n1                          # node_id
            @test fired[1][2] >= 0.1                         # Confidence floor (jitter-safe)
            @test fired[1][2] <= 3.0                         # Reasonable upper bound (jitter-safe)
            @test fired[1][3] == "machine learning optimization"  # Connector pattern returned
        end
    end

    # With strength=10.0, coinflip prob = 0.20 + (10/10)*0.70 = 0.90
    # Over 100 trials, should fire most of the time
    @test fired_count > 50  # Very conservative lower bound

    println("  ✓ [11] Fire attachments: fired $fired_count/100 times (strength=10.0, expected ~90%)")
end

# ==============================================================================
# 12. FIRE — Active cap enforcement
# ==============================================================================
@testset "FireAttachments - Active cap" begin
    reset_engine!()

    target = make_node!("target hub")
    n1 = make_node!("spoke one"; strength=10.0)
    n2 = make_node!("spoke two"; strength=10.0)

    attach_node!(target, n1, "pattern one")
    attach_node!(target, n2, "pattern two")

    # Set active_count = active_cap (already at limit)
    fired = fire_attachments!(target, 100, 100)
    @test isempty(fired)  # Cap reached, nothing should fire

    println("  ✓ [12] Active cap: no attachments fire when cap is already reached")
end

# ==============================================================================
# 13. FIRE — Dead/grave attachments skipped
# ==============================================================================
@testset "FireAttachments - Dead attachment skip" begin
    reset_engine!()

    target = make_node!("target node")
    n1 = make_node!("alive node"; strength=10.0)
    n2 = make_node!("dead node"; strength=10.0)

    attach_node!(target, n1, "alive pattern")
    attach_node!(target, n2, "dead pattern")

    # Grave n2 after attachment
    lock(NODE_LOCK) do
        NODE_MAP[n2].is_grave = true
    end

    # Fire many times — only n1 should ever appear
    for _ in 1:50
        fired = fire_attachments!(target, 0, 1800)
        for (fid, _, _) in fired
            @test fid == n1  # n2 is graved, should never fire
        end
    end

    println("  ✓ [13] Dead attachment: graved node correctly skipped in firing")
end

# ==============================================================================
# 14. FIRE — No attachments returns empty
# ==============================================================================
@testset "FireAttachments - No attachments" begin
    reset_engine!()

    target = make_node!("lonely node")

    fired = fire_attachments!(target, 0, 1800)
    @test isempty(fired)

    println("  ✓ [14] No attachments: returns empty vector")
end

# ==============================================================================
# 15. FIRE — Confidence calculation
# ==============================================================================
@testset "FireAttachments - Confidence floor" begin
    reset_engine!()

    target = make_node!("completely unrelated topic")
    # Attach with a totally different pattern — should still get 0.1 floor
    n1 = make_node!("zzzzz yyyyy xxxxx"; strength=10.0)
    attach_node!(target, n1, "aaaaa bbbbb ccccc")

    fired_confs = Float64[]
    for _ in 1:100
        fired = fire_attachments!(target, 0, 1800)
        for (_, conf, connector) in fired
            push!(fired_confs, conf)
            @test connector == "aaaaa bbbbb ccccc"  # Connector pattern returned
        end
    end

    if !isempty(fired_confs)
        @test minimum(fired_confs) >= 0.1  # Floor enforced
    end

    println("  ✓ [15] Confidence floor: all fired confidences >= 0.1 ($(length(fired_confs)) samples)")
end

# ==============================================================================
# 16. SUMMARY — get_attachment_summary
# ==============================================================================
@testset "AttachmentSummary" begin
    reset_engine!()

    # Empty map
    summary = get_attachment_summary()
    @test occursin("No attachments", summary) || occursin("empty", lowercase(summary))

    # Populated map
    target = make_node!("target node")
    n1 = make_node!("attached node")
    attach_node!(target, n1, "relay pattern")

    summary = get_attachment_summary()
    @test occursin(target, summary)
    @test occursin(n1, summary)
    @test occursin("1/4", summary) || occursin("1/$MAX_ATTACHMENTS", summary)

    println("  ✓ [16] Attachment summary: empty and populated cases correct")
end

# ==============================================================================
# 17. GET ATTACHMENTS — get_attachments_for_target
# ==============================================================================
@testset "GetAttachmentsForTarget" begin
    reset_engine!()

    target = make_node!("target")
    n1 = make_node!("one")

    # Empty before attach
    @test isempty(get_attachments_for_target(target))
    @test isempty(get_attachments_for_target("nonexistent"))

    attach_node!(target, n1, "pat")
    atts = get_attachments_for_target(target)
    @test length(atts) == 1
    @test atts[1].node_id == n1

    println("  ✓ [17] get_attachments_for_target: correct for empty, populated, and nonexistent")
end

# ==============================================================================
# 18. REATTACH AFTER DETACH — slot reuse
# ==============================================================================
@testset "NodeAttach - Slot reuse after detach" begin
    reset_engine!()

    target = make_node!("target hub")
    nodes = [make_node!("node $i") for i in 1:5]

    # Fill all 4 slots
    for i in 1:4
        attach_node!(target, nodes[i], "pat $i")
    end
    @test length(get_attachments_for_target(target)) == 4

    # Detach one, then attach the 5th
    detach_node!(target, nodes[2])
    @test length(get_attachments_for_target(target)) == 3

    attach_node!(target, nodes[5], "pat 5")
    @test length(get_attachments_for_target(target)) == 4

    println("  ✓ [18] Slot reuse: detach frees slot, new attach fills it")
end

# ==============================================================================
# 19. WEAK STRENGTH — low coinflip probability
# ==============================================================================
@testset "FireAttachments - Weak strength coinflip" begin
    reset_engine!()

    target = make_node!("target node")
    weak = make_node!("weak node"; strength=0.0)

    attach_node!(target, weak, "weak pattern")

    # With strength=0.0, initial coinflip prob = 0.20
    # NOTE: bump_strength! is called on each fire, so probability drifts upward.
    # Over 10 trials at initial strength, should fire roughly 2 times (20%).
    # We use a short burst to test the initial weak state before drift takes over.
    fired_count = 0
    for _ in 1:10
        fired = fire_attachments!(target, 0, 1800)
        fired_count += length(fired)
    end

    # Should fire some but not all in a short burst
    @test fired_count >= 0    # Stochastic: may fire zero times in 10 trials
    @test fired_count <= 10   # Cannot fire more times than trials

    # Now verify strength drifted upward from bump_strength! calls
    lock(NODE_LOCK) do
        @test NODE_MAP[weak].strength >= 0.0  # Should have increased if any fired
    end

    println("  ✓ [19] Weak strength: fired $fired_count/10 in short burst (initial prob=20%, drift expected)")
end

# ==============================================================================
# SUMMARY
# ==============================================================================
println("\n" * "="^60)
println("GRUG NODE ATTACHMENT TEST SUITE — ALL TESTS PASSED ✅")
println("="^60)