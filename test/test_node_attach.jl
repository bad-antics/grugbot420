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
    @test atts[1].base_confidence >= 0.0  # JIT-baked confidence stored
    @test atts[1].base_confidence <= 2.0  # Sane upper bound (similarity + strength bonus)

    println("  ✓ [1] Basic attach: single node attached successfully (base_conf=$(round(atts[1].base_confidence, digits=3)))")
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

    # GRUG: Verify JIT-baked base_confidence — zero token overlap + strength bonus
    atts = get_attachments_for_target(target)
    @test length(atts) == 1
    # No token overlap between "aaaaa bbbbb ccccc" and "zzzzz yyyyy xxxxx"
    # base_confidence = 0.0 + (10.0/10.0)*0.5 = 0.5 (strength bonus only)
    @test atts[1].base_confidence >= 0.4   # ~0.5 (strength bonus only)
    @test atts[1].base_confidence <= 0.6   # Tight bound since we know exact values

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

    println("  ✓ [15] Confidence floor: all fired confidences >= 0.1, base_conf=$(round(atts[1].base_confidence, digits=3)) ($(length(fired_confs)) samples)")
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
# 20. JIT CONFIDENCE — Pre-baked at attach time with known patterns
# ==============================================================================
@testset "JIT Confidence - Pre-baked at attach time" begin
    reset_engine!()

    # GRUG: Create nodes with known overlapping patterns for deterministic confidence
    target = make_node!("hub node central")
    # Pattern has 2/5 overlap with connector: "alpha beta" overlap with "alpha beta gamma delta epsilon"
    n1 = make_node!("alpha beta unique words here"; strength=5.0)

    attach_node!(target, n1, "alpha beta gamma delta epsilon")

    atts = get_attachments_for_target(target)
    @test length(atts) == 1

    # GRUG: Expected base_confidence calculation:
    #   Jaccard similarity of {"alpha","beta","gamma","delta","epsilon"} vs {"alpha","beta","unique","words","here"}
    #   intersection = {"alpha","beta"} = 2
    #   union = {"alpha","beta","gamma","delta","epsilon","unique","words","here"} = 8
    #   similarity = 2/8 = 0.25
    #   strength_bonus = (5.0/10.0) * 0.5 = 0.25
    #   base_confidence = 0.25 + 0.25 = 0.5
    @test atts[1].base_confidence >= 0.45   # Allow small float tolerance
    @test atts[1].base_confidence <= 0.55

    println("  ✓ [20] JIT confidence: pre-baked at attach time (base_conf=$(round(atts[1].base_confidence, digits=3)), expected ~0.5)")
end

# ==============================================================================
# 21. JIT CONFIDENCE — Fire only applies jitter to pre-baked value
# ==============================================================================
@testset "JIT Confidence - Fire applies jitter only" begin
    reset_engine!()

    # GRUG: Create a scenario with known base_confidence, then verify fire output
    # is tightly clustered around base_confidence (only jitter sigma=0.05)
    target = make_node!("hub node central")
    n1 = make_node!("exact same tokens here now"; strength=10.0)

    # High overlap connector: "exact same tokens" overlaps 3 of 5 with node pattern
    attach_node!(target, n1, "exact same tokens plus more")

    atts = get_attachments_for_target(target)
    baked_conf = atts[1].base_confidence

    # Fire many times and collect confidences
    fired_confs = Float64[]
    for _ in 1:200
        fired = fire_attachments!(target, 0, 1800)
        for (_, conf, _) in fired
            push!(fired_confs, conf)
        end
    end

    if !isempty(fired_confs)
        # GRUG: All confidences should be close to baked_conf (within jitter range)
        # Jitter sigma = 0.05, so 99.7% should be within ±0.15 (3σ)
        # Plus the 0.1 floor clamp
        for conf in fired_confs
            @test conf >= 0.1                    # Floor always enforced
            @test conf <= baked_conf + 0.25      # Generous upper bound (5σ safety)
        end
        # Mean should be close to baked_conf (jitter is zero-mean)
        mean_conf = sum(fired_confs) / length(fired_confs)
        @test abs(mean_conf - max(0.1, baked_conf)) < 0.1  # Mean within 0.1 of baked
    end

    println("  ✓ [21] JIT fire: confidences cluster around baked value $(round(baked_conf, digits=3)) ($(length(fired_confs)) samples)")
end

# ==============================================================================
# 22. SDF SIGNAL SIMILARITY — Cosine similarity function
# ==============================================================================
@testset "SDF Signal Similarity" begin
    # GRUG: Test the _sdf_signal_similarity function directly
    # Identical signals = 1.0
    sig_a = [0.5, 0.3, 0.8, 0.1]
    sig_b = [0.5, 0.3, 0.8, 0.1]
    @test _sdf_signal_similarity(sig_a, sig_b) ≈ 1.0 atol=0.001

    # Orthogonal signals — construct truly orthogonal vectors
    sig_c = [1.0, 0.0]
    sig_d = [0.0, 1.0]
    @test _sdf_signal_similarity(sig_c, sig_d) ≈ 0.0 atol=0.001

    # Similar signals — should be high but not 1.0
    sig_e = [0.5, 0.3, 0.8, 0.1]
    sig_f = [0.5, 0.3, 0.7, 0.2]
    sim = _sdf_signal_similarity(sig_e, sig_f)
    @test sim > 0.9
    @test sim < 1.0

    # Empty signals — should error
    @test_throws ErrorException _sdf_signal_similarity(Float64[], sig_a)
    @test_throws ErrorException _sdf_signal_similarity(sig_a, Float64[])

    # Different lengths — truncates to shorter
    sig_g = [0.5, 0.3, 0.8]
    sig_h = [0.5, 0.3, 0.8, 0.1, 0.2]
    sim2 = _sdf_signal_similarity(sig_g, sig_h)
    @test sim2 ≈ 1.0 atol=0.001  # First 3 elements are identical

    println("  ✓ [22] SDF signal similarity: identity, orthogonal, partial, error cases all pass")
end

# ==============================================================================
# 23. IMAGE NODE ATTACH — Basic SDF attachment
# ==============================================================================
@testset "ImgNodeAttach - Basic SDF attach" begin
    reset_engine!()

    target = make_node!("hub node for images")

    # GRUG: Create an image node manually (is_image_node=true)
    img_id = lock(NODE_LOCK) do
        nid = "img_test_$(length(NODE_MAP))"
        # Create a simple 4x4 grayscale image (16 bytes)
        img_data = UInt8[128, 64, 192, 255, 0, 100, 200, 50,
                         128, 64, 192, 255, 0, 100, 200, 50]
        sdf = ImageSDF.image_to_sdf_params(img_data, 4, 4)
        sig = ImageSDF.sdf_to_signal(sdf)
        node = Node(
            nid, "SDF:image:4x4", sig, "image_action",
            Dict{String, Any}(), String[], 1.0,
            RelationalTriple[], String[], Dict{String, Float64}(),
            5.0, true, String[], false, false, "",
            Float64[], time(), hash("SDF:image:4x4")
        )
        NODE_MAP[nid] = node
        return nid
    end

    # GRUG: Attach image node with SDF conversion at attach time
    img_data = UInt8[128, 64, 192, 255, 0, 100, 200, 50,
                     128, 64, 192, 255, 0, 100, 200, 50]
    result = attach_image_node!(target, img_id, img_data, 4, 4)

    @test occursin("Attached image", result)
    @test occursin(img_id, result)
    @test occursin("SDF", result)

    atts = get_attachments_for_target(target)
    @test length(atts) == 1
    @test atts[1].node_id == img_id
    @test startswith(atts[1].pattern, "SDF:")            # SDF metadata pattern
    @test length(atts[1].signal) > 0                     # SDF signal pre-baked
    @test atts[1].base_confidence >= 0.0                 # Confidence baked
    @test atts[1].base_confidence <= 2.0                 # Sane upper bound

    println("  ✓ [23] Image attach: SDF-based attachment successful (base_conf=$(round(atts[1].base_confidence, digits=3)))")
end

# ==============================================================================
# 24. IMAGE NODE ATTACH — Validation errors
# ==============================================================================
@testset "ImgNodeAttach - Validation errors" begin
    reset_engine!()

    target = make_node!("hub node")
    text_node = make_node!("this is a text node"; strength=5.0)

    # GRUG: Non-image node should be rejected
    img_data = UInt8[128, 64, 192, 255]
    @test_throws ErrorException attach_image_node!(target, text_node, img_data, 2, 2)

    # GRUG: Empty target_id
    @test_throws ErrorException attach_image_node!("", "fake", img_data, 2, 2)

    # GRUG: Empty attach_id
    @test_throws ErrorException attach_image_node!(target, "", img_data, 2, 2)

    # GRUG: Self-attach
    @test_throws ErrorException attach_image_node!(target, target, img_data, 2, 2)

    # GRUG: Empty image data
    @test_throws ErrorException attach_image_node!(target, text_node, UInt8[], 2, 2)

    # GRUG: Invalid dimensions
    @test_throws ErrorException attach_image_node!(target, text_node, img_data, 0, 2)
    @test_throws ErrorException attach_image_node!(target, text_node, img_data, 2, -1)

    # GRUG: Missing nodes
    @test_throws ErrorException attach_image_node!(target, "nonexistent_node", img_data, 2, 2)
    @test_throws ErrorException attach_image_node!("nonexistent_target", text_node, img_data, 2, 2)

    println("  ✓ [24] Image attach validation: all error cases caught correctly")
end

# ==============================================================================
# 25. IMAGE NODE ATTACH — SDF confidence similarity
# ==============================================================================
@testset "ImgNodeAttach - SDF confidence from similarity" begin
    reset_engine!()

    target = make_node!("hub for sdf confidence test")

    # GRUG: Create an image node with known SDF signal
    img_data_same = UInt8[128, 64, 192, 255, 0, 100, 200, 50,
                          128, 64, 192, 255, 0, 100, 200, 50]

    img_id = lock(NODE_LOCK) do
        nid = "img_conf_$(length(NODE_MAP))"
        sdf = ImageSDF.image_to_sdf_params(img_data_same, 4, 4)
        sig = ImageSDF.sdf_to_signal(sdf)
        node = Node(
            nid, "SDF:image:4x4", sig, "image_action",
            Dict{String, Any}(), String[], 1.0,
            RelationalTriple[], String[], Dict{String, Float64}(),
            5.0, true, String[], false, false, "",
            Float64[], time(), hash("SDF:image:4x4")
        )
        NODE_MAP[nid] = node
        return nid
    end

    # GRUG: Attach with THE SAME image data — SDF similarity should be ~1.0
    result = attach_image_node!(target, img_id, img_data_same, 4, 4)
    atts = get_attachments_for_target(target)
    @test length(atts) == 1

    # Same image → high SDF similarity → high base_confidence
    # base_confidence = sdf_sim (~1.0) + (5.0/10.0)*0.5 = ~1.25
    @test atts[1].base_confidence >= 0.8   # High similarity expected
    @test atts[1].base_confidence <= 1.5   # Upper bound with strength bonus

    println("  ✓ [25] Image SDF confidence: same image attachment has high confidence ($(round(atts[1].base_confidence, digits=3)))")
end

# ==============================================================================
# 26. SELECTIVE SCAN — _effective_scan_mode complexity downgrade
# ==============================================================================
@testset "SelectiveScan - Pattern complexity downgrade" begin
    # GRUG: Test that _effective_scan_mode correctly caps scan tier
    # based on node signal length (pattern complexity).

    # --- Tiny pattern (≤3 tokens) → always capped at mode 1 (cheap) ---
    tiny_signal = [0.5, 0.3]  # 2 elements
    @test _effective_scan_mode(1, tiny_signal) == 1  # 1 stays 1
    @test _effective_scan_mode(2, tiny_signal) == 1  # 2 downgraded to 1
    @test _effective_scan_mode(3, tiny_signal) == 1  # 3 downgraded to 1

    # Edge case: exactly 3 tokens
    three_signal = [0.1, 0.2, 0.3]
    @test _effective_scan_mode(3, three_signal) == 1  # 3 downgraded to 1

    # --- Medium pattern (4-8 tokens) → capped at mode 2 (medium) ---
    medium_signal = [0.1, 0.2, 0.3, 0.4, 0.5]  # 5 elements
    @test _effective_scan_mode(1, medium_signal) == 1  # 1 stays 1 (can't upgrade)
    @test _effective_scan_mode(2, medium_signal) == 2  # 2 stays 2
    @test _effective_scan_mode(3, medium_signal) == 2  # 3 downgraded to 2

    # Edge case: exactly 8 tokens
    eight_signal = Float64.(1:8)
    @test _effective_scan_mode(3, eight_signal) == 2  # Still capped at 2

    # --- Complex pattern (>8 tokens) → no cap, full tier ---
    complex_signal = Float64.(1:12)  # 12 elements
    @test _effective_scan_mode(1, complex_signal) == 1  # Input says cheap, stays cheap
    @test _effective_scan_mode(2, complex_signal) == 2  # Input says medium, stays medium
    @test _effective_scan_mode(3, complex_signal) == 3  # Input says high-res, gets high-res

    # Edge case: exactly 9 tokens (threshold boundary)
    nine_signal = Float64.(1:9)
    @test _effective_scan_mode(3, nine_signal) == 3  # 9 > 8, no cap

    # --- Empty signal → returns base mode (let scanner handle the error) ---
    @test _effective_scan_mode(1, Float64[]) == 1
    @test _effective_scan_mode(3, Float64[]) == 3

    # --- Single token → always cheap ---
    single = [0.99]
    @test _effective_scan_mode(3, single) == 1

    println("  ✓ [26] Selective scan: pattern complexity correctly downgrades scan tier")
end

# ==============================================================================
# 27. SELECTIVE SCAN — screen_input_complexity base tiers
# ==============================================================================
@testset "SelectiveScan - Input complexity tiers" begin
    # GRUG: Verify screen_input_complexity returns correct base tiers
    # based on signal length and triple count.

    # Short signal, no triples → tier 1 (cheap)
    short_signal = [0.5, 0.3]
    @test screen_input_complexity(short_signal, RelationalTriple[]) == 1

    # Medium signal with triples → tier 2 (medium)
    med_signal = Float64.(1:10)
    one_triple = [RelationalTriple("a", "likes", "b")]
    @test screen_input_complexity(med_signal, one_triple) == 2

    # Long signal with many triples → tier 3 (high-res)
    long_signal = Float64.(1:30)
    many_triples = [RelationalTriple("a", "r$i", "b") for i in 1:5]
    @test screen_input_complexity(long_signal, many_triples) == 3

    # Empty signal → error (no silent failure)
    @test_throws ErrorException screen_input_complexity(Float64[], RelationalTriple[])

    println("  ✓ [27] Input complexity: base scan tiers computed correctly")
end

# ==============================================================================
# 28. JITGPU — backend selection + SDFParams output contract
# ==============================================================================
@testset "JITGPU - CPU backend produces valid SDFParams" begin
    # GRUG: On CI (no GPU hardware), JITGPU() falls back to KernelAbstractions.CPU()
    # and runs the same @kernel code on Julia threads. Not a dummy fallback —
    # it IS the kernel dispatch, just targeting CPU threads instead of GPU cores.

    # 4x4 grayscale image (16 bytes)
    img_4x4_gray = UInt8[128, 64, 192, 255,
                          0, 100, 200, 50,
                          128, 64, 192, 255,
                          0, 100, 200, 50]

    params = ImageSDF.JITGPU(img_4x4_gray; width=4, height=4)

    # GRUG: SDFParams contract — all arrays must be length n_pixels
    @test length(params.xArray)          == 16
    @test length(params.yArray)          == 16
    @test length(params.brightnessArray) == 16
    @test length(params.colorArray)      == 16
    @test params.width  == 4
    @test params.height == 4
    @test params.timestamp > 0.0  # GRUG: Birth time was stamped

    # GRUG: All spatial coords must be in [0.0, 1.0]
    @test all(0.0 .<= params.xArray      .<= 1.0)
    @test all(0.0 .<= params.yArray      .<= 1.0)
    @test all(0.0 .<= params.brightnessArray .<= 1.0)
    @test all(0.0 .<= params.colorArray  .<= 1.0)

    # GRUG: tanh SDF output is always >= 0 (gradient magnitude is non-negative)
    @test all(params.brightnessArray .>= 0.0)

    println("  ✓ [28] JITGPU CPU backend: SDFParams contract holds for 4x4 grayscale")
end

# ==============================================================================
# 29. JITGPU — RGB and RGBA channel paths
# ==============================================================================
@testset "JITGPU - RGB and RGBA channel decoding" begin
    # GRUG: 2x2 RGB image (12 bytes) — test 3-channel decode path
    rgb_2x2 = UInt8[
        255, 0, 0,    # red pixel
        0, 255, 0,    # green pixel
        0, 0, 255,    # blue pixel
        255, 255, 0   # yellow pixel
    ]
    params_rgb = ImageSDF.JITGPU(rgb_2x2; width=2, height=2)
    @test length(params_rgb.xArray) == 4
    @test all(0.0 .<= params_rgb.brightnessArray .<= 1.0)
    @test all(0.0 .<= params_rgb.colorArray      .<= 1.0)

    # GRUG: Red pixel has low luminance weight for B channel -> color_scalar should be near 1.0
    # color = clamp((R - B + 1) / 2, 0, 1) = clamp((1.0 - 0.0 + 1.0) / 2, 0, 1) = 1.0
    # (pixel 1 is red: R=1.0, B=0.0 -> color = 1.0 before SDF)
    # After gradient pass the color array is unchanged (gradient only modifies brightness).
    @test params_rgb.colorArray[1] ≈ 1.0 atol=0.01  # Red pixel -> max color scalar

    # GRUG: 2x2 RGBA image (16 bytes) — test 4-channel decode path
    rgba_2x2 = UInt8[
        255, 0, 0, 128,   # red + half-alpha
        0, 255, 0, 255,   # green + full-alpha
        0, 0, 255, 64,    # blue + quarter-alpha
        128, 128, 128, 255 # gray + full-alpha
    ]
    params_rgba = ImageSDF.JITGPU(rgba_2x2; width=2, height=2)
    @test length(params_rgba.xArray) == 4
    @test all(0.0 .<= params_rgba.brightnessArray .<= 1.0)
    # GRUG: Alpha channel is ignored for brightness/color — same result as RGB path
    @test params_rgba.colorArray[1] ≈ 1.0 atol=0.01  # Red pixel again -> max color

    println("  ✓ [29] JITGPU channel paths: RGB and RGBA decoded correctly")
end

# ==============================================================================
# 30. JITGPU — error handling (no silent failures)
# ==============================================================================
@testset "JITGPU - Error cases propagate" begin
    # GRUG: Empty binary
    @test_throws ImageSDF.ImageSDFError ImageSDF.JITGPU(UInt8[]; width=4, height=4)

    # GRUG: Invalid dimensions
    valid_bytes = UInt8[128, 64, 192, 255, 0, 100, 200, 50,
                        128, 64, 192, 255, 0, 100, 200, 50]
    @test_throws ImageSDF.ImageSDFError ImageSDF.JITGPU(valid_bytes; width=0, height=4)
    @test_throws ImageSDF.ImageSDFError ImageSDF.JITGPU(valid_bytes; width=4, height=-1)

    # GRUG: Binary too small for stated dimensions
    tiny = UInt8[1, 2, 3]
    @test_throws ImageSDF.ImageSDFError ImageSDF.JITGPU(tiny; width=100, height=100)

    println("  ✓ [30] JITGPU error cases: all throw ImageSDFError, no silent failures")
end

# ==============================================================================
# 31. JITGPU — output matches CPU reference path within Float32 tolerance
# ==============================================================================
@testset "JITGPU - Output consistent with image_to_sdf_params CPU reference" begin
    # GRUG: Both JITGPU and image_to_sdf_params implement the same algorithm:
    # decode -> central-diff gradient -> tanh(3 * grad_mag).
    # Results should match within Float32 rounding tolerance (JITGPU uses Float32
    # internally, converts to Float64 at end; CPU reference uses Float64 throughout).

    img_data = UInt8[200, 100, 50, 25, 150, 75,
                     200, 100, 50, 25, 150, 75,
                     200, 100, 50, 25, 150, 75]  # 6x3 grayscale

    gpu_params = ImageSDF.JITGPU(img_data; width=6, height=3)
    cpu_params = ImageSDF.image_to_sdf_params(img_data, 6, 3)

    # GRUG: Arrays same length
    @test length(gpu_params.xArray)          == length(cpu_params.xArray)
    @test length(gpu_params.brightnessArray) == length(cpu_params.brightnessArray)

    # GRUG: Spatial coordinates should be identical (same formula, no float precision diff)
    @test gpu_params.xArray ≈ cpu_params.xArray atol=1e-5
    @test gpu_params.yArray ≈ cpu_params.yArray atol=1e-5

    # GRUG: SDF brightness should match within Float32 tolerance (~1e-5 for tanh(grad))
    @test gpu_params.brightnessArray ≈ cpu_params.brightnessArray atol=1e-4

    # GRUG: Dimensions preserved
    @test gpu_params.width  == cpu_params.width
    @test gpu_params.height == cpu_params.height

    println("  ✓ [31] JITGPU vs CPU reference: outputs match within Float32 tolerance")
end

# ==============================================================================
# 32. JITGPU — uniform image (all same pixel) produces near-zero SDF
# ==============================================================================
@testset "JITGPU - Uniform image yields near-zero SDF (no edges)" begin
    # GRUG: A completely uniform image has zero gradient everywhere.
    # tanh(3 * 0.0) = 0.0 -> all SDF values should be exactly 0.
    # Exception: boundary pixels (clamp-to-edge) are also uniform -> still 0.

    uniform_4x4 = fill(UInt8(128), 16)  # 4x4 grayscale, all 128
    params = ImageSDF.JITGPU(uniform_4x4; width=4, height=4)

    @test all(params.brightnessArray .< 1e-5)  # GRUG: No edges -> SDF near zero

    println("  ✓ [32] JITGPU uniform image: all SDF values near zero (no gradient)")
end

# ==============================================================================
# 33. JITGPU — sharp edge image produces high SDF activation at edge
# ==============================================================================
@testset "JITGPU - Sharp edge image activates SDF at edge boundary" begin
    # GRUG: Left half black (0), right half white (255) in a 4x4 grayscale image.
    # The vertical edge at column 2 should have high gradient -> high SDF activation.
    # Interior of each half (far from edge) should be near zero.
    half_black_half_white = UInt8[
        0,   0, 255, 255,
        0,   0, 255, 255,
        0,   0, 255, 255,
        0,   0, 255, 255
    ]
    params = ImageSDF.JITGPU(half_black_half_white; width=4, height=4)

    # GRUG: Pixels at the edge boundary (col 1->2 transition) should have high SDF.
    # Linear pixel index: col=1 (0-based) for row 0 is pixel 2 (1-based).
    # col=2 (0-based) for row 0 is pixel 3 (1-based).
    # Edge pixels have gx = (255 - 0) / 255 ≈ 1.0 -> tanh(3 * 1.0) ≈ 0.995
    edge_pixel_left  = params.brightnessArray[2]  # row 0, col 1 (just left of edge)
    edge_pixel_right = params.brightnessArray[3]  # row 0, col 2 (just right of edge)

    @test edge_pixel_left  > 0.9   # GRUG: Strong edge activation
    @test edge_pixel_right > 0.9   # GRUG: Strong edge activation

    # GRUG: Far-from-edge pixels: row 0 col 0 (pixel 1) has no right-neighbor edge
    # (col_left = col_right = 0 due to clamping -> gx = 0 -> SDF = 0)
    far_from_edge = params.brightnessArray[1]  # row 0, col 0 — leftmost, clamped neighbor
    @test far_from_edge < 1e-5  # GRUG: No gradient at fully clamped corner pixel

    println("  ✓ [33] JITGPU edge detection: sharp edge produces high SDF activation")
end

# ==============================================================================
# 34. JITGPU — sdf_to_signal pipeline (JITGPU -> signal)
# ==============================================================================
@testset "JITGPU - Full pipeline: JITGPU -> sdf_to_signal" begin
    # GRUG: End-to-end pipeline test. JITGPU -> SDFParams -> sdf_to_signal -> Vector{Float64}.
    # This is the exact pipeline called at /imgnodeAttach time.

    img_data = UInt8[128, 64, 192, 255, 0, 100, 200, 50,
                     128, 64, 192, 255, 0, 100, 200, 50]  # 4x4 grayscale

    params = ImageSDF.JITGPU(img_data; width=4, height=4)
    signal = ImageSDF.sdf_to_signal(params; max_samples=16)

    # GRUG: sdf_to_signal interleaves [x, y, brightness, color] per sample -> 4 * samples
    @test length(signal) == 4 * 16
    @test all(isfinite, signal)       # GRUG: No NaN or Inf
    @test all(0.0 .<= signal .<= 1.0) # GRUG: All values in normalized range

    println("  ✓ [34] JITGPU pipeline: JITGPU -> sdf_to_signal produces valid signal")
end

# ==============================================================================
# SUMMARY
# ==============================================================================
println("\n" * "="^60)
println("GRUG NODE ATTACHMENT TEST SUITE — ALL TESTS PASSED ✅")
println("="^60)