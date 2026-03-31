# Main.jl

# GRUG: Bring the stochastic coinflip helper to the top of the mountain!
# GRUG: Guard against double-include if CoinFlipHeader already loaded by caller.
if !isdefined(Main, :CoinFlipHeader)
    include("stochastichelper.jl")
end
using .CoinFlipHeader

# GRUG: Include engine after macro is alive. Engine need coinflip!
# Engine.jl now includes patternscanner.jl, ImageSDF.jl and EyeSystem.jl internally.
include("engine.jl")

# GRUG: Bring the Chatter Mode gossip system into the cave!
# GRUG: Guard against double-include if ChatterMode already loaded by caller.
if !isdefined(Main, :ChatterMode)
    include("ChatterMode.jl")
end
using .ChatterMode

# GRUG: Bring the Phagy Mode maintenance automata into the cave!
# GRUG: Guard against double-include if PhagyMode already loaded by caller.
if !isdefined(Main, :PhagyMode)
    include("PhagyMode.jl")
end
using .PhagyMode

# GRUG: Bring the Thesaurus dimensional similarity engine into the cave!
# GRUG: Guard against double-include if Thesaurus already loaded by caller.
if !isdefined(Main, :Thesaurus)
    include("Thesaurus.jl")
end
using .Thesaurus

# GRUG: Bring the Lobe partitioning system into the cave!
# GRUG: Guard against double-include if Lobe already loaded by caller.
if !isdefined(Main, :Lobe)
    include("Lobe.jl")
end
using .Lobe

# GRUG: Bring the LobeTable hash storage system into the cave!
# GRUG: Guard against double-include if LobeTable already loaded by caller.
if !isdefined(Main, :LobeTable)
    include("LobeTable.jl")
end
using .LobeTable

# GRUG: Bring the BrainStem winner-take-all dispatcher into the cave!
# GRUG: Guard against double-include if BrainStem already loaded by caller.
if !isdefined(Main, :BrainStem)
    include("BrainStem.jl")
end
using .BrainStem

# GRUG: Bring the InputQueue and NegativeThesaurus inhibition system into the cave!
# GRUG: Guard against double-include if InputQueue already loaded by caller.
if !isdefined(Main, :InputQueue)
    include("InputQueue.jl")
end
using .InputQueue

using Base64: base64decode

# ==============================================================================
# MEMORY CAVE (PIN AWARENESS LAYER)
# ==============================================================================

# GRUG DOC 3.6: These big memory rocks disappear when Grug goes to sleep (CLI closes).
# Future Grug need to learn how to write on permanent cave walls (Persistence feature).
mutable struct ChatMessage
    id::Int
    role::String
    text::String
    pinned::Bool
end

const MAX_HISTORY   = 10000
const MESSAGE_HISTORY = Vector{ChatMessage}()
const MSG_ID_COUNTER  = Atomic{Int}(0)

# GRUG FIX 3.1: Strict Role Validation!
# Grug no let random strangers paint on memory wall.
const ALLOWED_ROLES = Set(["User", "System", "User_Pinned", "Engine_Voice"])

# GRUG: Write new words on memory cave wall. If wall full, wash away old words.
function add_message_to_history!(role::String, text::String, pinned::Bool=false)
    if strip(text) == "" || strip(role) == ""
        error("!!! FATAL: Grug cannot paint empty air on memory cave wall! !!!")
    end

    if !(role in ALLOWED_ROLES)
        error("!!! FATAL: Grug does not know role '$role'. Allowed roles: $(join(ALLOWED_ROLES, ", ")) !!!")
    end
    
    id  = atomic_add!(MSG_ID_COUNTER, 1)
    msg = ChatMessage(id, role, text, pinned)
    
    if length(MESSAGE_HISTORY) < MAX_HISTORY
        push!(MESSAGE_HISTORY, msg)
    else
        # GRUG: Cave full! Find oldest un-pinned drawing and smash it.
        idx_to_replace = findfirst(m -> !m.pinned, MESSAGE_HISTORY)
        if isnothing(idx_to_replace)
            error("!!! FATAL: All 10,000 slots have pinned rocks! Grug's memory cave is completely full! !!!")
        end
        deleteat!(MESSAGE_HISTORY, idx_to_replace)
        push!(MESSAGE_HISTORY, msg)
    end
end

# ==============================================================================
# DYNAMIC AIML DROP TABLE & MAGIC WORD TEMPLATES
# ==============================================================================
# GRUG: AIML_DROP_TABLE, StochasticRule, ALLOWED_RULE_TAGS, and add_orchestration_rule!
# are defined in Engine.jl so they are available to both Main.jl and the test runner.
# Nothing to re-define here. Grug just uses them directly!

# ==============================================================================
# EPHEMERAL AIML ORCHESTRATOR
# ==============================================================================

# GRUG: Read the pinned words and the fresh words to give context to the dynamic generation engine.
function extract_lobe_aware_context(votes::Vector{Vote})::String
    # GRUG: Prefrontal cortex context injector!
    # Show which lobes are active and what knowledge is available from each.
    # This lets AIML rules reason across domain boundaries (science ↔ philosophy ↔ etc.)
    
    try
        if isempty(votes)
            return "Lobe Context: [No active lobes]"
        end
        
        # GRUG: Map each vote to its lobe, collect unique active lobes
        active_lobes = Set{String}()
        for vote in votes
            lobe_name = Lobe.find_lobe_for_node(vote.node_id)
            if !isnothing(lobe_name)
                push!(active_lobes, lobe_name)
            end
        end
        
        if isempty(active_lobes)
            return "Lobe Context: [Unassigned nodes - no lobe context]"
        end
        
        # GRUG: Build context string with active lobes and their node counts
        lobe_parts = String[]
        for lobe_name in sort(collect(active_lobes))
            lobe_node_count = Lobe.get_lobe_node_count(lobe_name)
            active_node_ids = if isdefined(Main, :LobeTable) && LobeTable.table_exists(lobe_name)
                LobeTable.get_active_node_ids(lobe_name)
            else
                String[]
            end
            active_count = length(active_node_ids)
            
            # Sample 2-3 node patterns from this lobe to show domain flavor
            sample_patterns = String[]
            for node_id in active_node_ids[1:min(3, length(active_node_ids))]
                node = lock(() -> get(NODE_MAP, node_id, nothing), NODE_LOCK)
                if !isnothing(node)
                    push!(sample_patterns, node.pattern)
                end
            end
            
            pattern_preview = isempty(sample_patterns) ? "" : 
                " ($(join([p[1:min(30, length(p))] for p in sample_patterns], " | ")))"
            
            push!(lobe_parts, "$lobe_name ($active_count/$lobe_node_count active$pattern_preview)")
        end
        
        return "Lobe Context: [" * join(lobe_parts, "] | [") * "]"
        
    catch e
        # GRUG: Don't crash AIML on lobe context error, but WARN
        @warn "[MAIN] ⚠ Failed to extract lobe-aware context (non-fatal): $e"
        return "Lobe Context: [Error retrieving lobe information]"
    end
end

function extract_aiml_memory_context()::String
    total_msgs = length(MESSAGE_HISTORY)
    if total_msgs == 0
        return "Memory Cave: [EMPTY]"
    end
    
    pinned_msgs = String[]
    recent_msgs = String[]
    
    try
        # 1. Grab all pinned rocks
        for m in MESSAGE_HISTORY
            if m.pinned
                push!(pinned_msgs, "[$(m.role)]: $(m.text)")
            end
        end
        
        # GRUG FIX 3.2: Grug want last 5 UNPINNED rocks. 
        # If Grug just check last 5 spots and all are pinned, recent sounds is empty!
        # So Grug filter first, then take last 5.
        unpinned_history = [m for m in MESSAGE_HISTORY if !m.pinned]
        recent_count = min(5, length(unpinned_history))
        
        for i in (length(unpinned_history) - recent_count + 1):length(unpinned_history)
            m = unpinned_history[i]
            push!(recent_msgs, "[$(m.role)]: $(m.text)")
        end
        
        pinned_str = isempty(pinned_msgs) ? "No pinned rocks" : join(pinned_msgs, " | ")
        recent_str = isempty(recent_msgs) ? "No recent sounds" : join(recent_msgs, " | ")
        
        return "Deep Memory (Pinned): $pinned_str\nFresh Memory (Recent): $recent_str"
    catch e
        error("!!! FATAL: Chief Orchestrator failed to read memory wall: $e !!!")
    end
end

# GRUG DOC 3.9: SUPERPOSITION ORCHESTRATOR!
# Grug no longer picks just one rock. 
# Grug finds the heaviest rocks (max confidence) and puts them in "Sure" basket.
# For all smaller rocks, Grug flips a 50/50 coin to decide if they go in "Unsure" basket!
function ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})
    if isempty(votes)
        error("!!! FATAL: Orchestrator failed: Cave empty! Received zero votes! Cannot build fire! !!!")
    end
    if strip(mission) == ""
        error("!!! FATAL: Orchestrator failed: Mission text is invisible wind! !!!")
    end

    # GRUG FIX: Sort votes by confidence descending BEFORE bucketing.
    # This guarantees the highest-confidence domain node wins primary slot,
    # not a boot seed that happened to be inserted first.
    sorted_votes = sort(votes; by = v -> v.confidence, rev = true)

    max_conf = sorted_votes[1].confidence

    sure_votes   = Vote[]
    unsure_votes = Vote[]

    for v in sorted_votes
        # GRUG: If rock is within 0.05 of the biggest rock, it is a SURE thing.
        if v.confidence >= max_conf - 0.05
            push!(sure_votes, v)
        else
            # GRUG: For smaller rocks, loop through and flip a flat 50/50 coin!
            # Side effects! If Keep wins, push to unsure_votes.
            @coinflip [
                bias(:Keep, 50) => () -> push!(unsure_votes, v),
                bias(:Drop, 50) => () -> nothing
            ]
        end
    end

    if isempty(sure_votes)
        # GRUG: Should be mathematically impossible, but Grug checks anyway! NO SILENT FAILURES!
        error("!!! FATAL: Grug math broke! Max confidence produced zero sure votes! !!!")
    end

    # GRUG: Primary action is first in sorted sure_votes = highest confidence winner.
    primary_vote = sure_votes[1]

    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    if isnothing(node)
        error("!!! FATAL: Winning node $(primary_vote.node_id) vanished before Grug could grab it! !!!")
    end

    # GRUG: Pass EVERYTHING to the command block so the Generative Engine can see Grug's whole mind!
    return COMMANDS[primary_vote.action](mission, node, primary_vote, sure_votes, unsure_votes, votes)
end

# ==============================================================================
# COMMAND DEFINITIONS & JIT TEXT GENERATION
# ==============================================================================

# GRUG: Build text sandwich for the JIT Generative Builder, and synthesize the dynamic response!
function generate_aiml_payload(mission::String, primary_vote::Vote, sure_votes::Vector{Vote}, unsure_votes::Vector{Vote}, all_votes::Vector{Vote}, context::Dict)
    if !haskey(context, "system_prompt")
        error("!!! FATAL: Node dictionary missing 'system_prompt'! Grug confused! !!!")
    end

    system_prompt = context["system_prompt"]
    neg_str       = isempty(primary_vote.negatives) ? "None" : join(primary_vote.negatives, ", ")
    
    memory_str = extract_aiml_memory_context()
    lobe_str  = extract_lobe_aware_context(all_votes)

    sure_str   = join([v.action for v in sure_votes], ", ")
    unsure_str = isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", ")

    # GRUG: Read rule board. Swap shape-shifter words for real context chunks.
    # NOW STOCHASTIC: each rule fires based on its fire_probability.
    # This is where Grug JIT-compiles math into human language with natural variation!
    evaluated_rules = String[]
    try
        for rule in AIML_DROP_TABLE
            # GRUG: Roll a coinflip against the rule's fire probability.
            # prob=1.0 rules always fire. prob=0.5 rules fire ~half the time.
            if rand() > rule.fire_probability
                # GRUG: This rule lost its coinflip this round. Skip it!
                continue
            end

            processed = rule.text
            processed = replace(processed, "{MISSION}"        => mission)
            processed = replace(processed, "{PRIMARY_ACTION}" => primary_vote.action)
            processed = replace(processed, "{SURE_ACTIONS}"   => sure_str)
            processed = replace(processed, "{UNSURE_ACTIONS}" => unsure_str)
            processed = replace(processed, "{ALL_ACTIONS}"    => join([v.action for v in all_votes], ", "))
            processed = replace(processed, "{CONFIDENCE}"     => string(round(primary_vote.confidence, digits=2)))
            processed = replace(processed, "{NODE_ID}"        => primary_vote.node_id)
            processed = replace(processed, "{MEMORY}"         => memory_str)
            processed = replace(processed, "{LOBE_CONTEXT}"   => lobe_str)
            push!(evaluated_rules, processed)
        end
    catch e
        error("!!! FATAL: Grug failed to swap shape-shifter words in dynamic rules: $e !!!")
    end

    rules_str = isempty(evaluated_rules) ? "None" : join(evaluated_rules, " | ")

    # GRUG: Put relation verb-noun sandwiches into the prompt to provide grammar context.
    u_triples = isempty(primary_vote.user_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.user_triples], ", ")
    n_triples = isempty(primary_vote.node_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.node_triples], ", ")
    
    # GRUG DOC 3.4: Dynamic Stochastic Generation!
    # Grug uses the primary action AND the side-feature unsure actions to construct a highly varied output.
    jit_response = "[System Prompt Active: $system_prompt]\n"
    if primary_vote.action in ["greet", "welcome", "smile", "laugh"]
        jit_response *= "Hello human! I have received your input: '$mission'. "
    elseif primary_vote.action in ["flee", "hide", "fight"]
        jit_response *= "Warning! Evasive action protocol triggered by input: '$mission'. "
    else
        jit_response *= "Processing input... Executing logical analysis on: '$mission'. "
    end

    jit_response *= "I am entirely sure that I should: [$sure_str]. "
    if !isempty(unsure_votes)
        jit_response *= "However, due to stochastic variations, I am also considering these side features: [$unsure_str]. "
    end

    if !isempty(evaluated_rules)
        jit_response *= "\n[ENFORCING DYNAMIC USER RULES]:\n"
        for r in evaluated_rules
            jit_response *= " -> $r\n"
        end
    end

    # GRUG: Wait little bit so cpu fire not burn down hut.
    sleep(0.3) 
    
    out  = "SYNTHESIZED PAYLOAD. (Primary Confidence: $(round(primary_vote.confidence, digits=2))).\n"
    out *= "Mission: '$mission'\n"
    out *= "Primary Action: $(primary_vote.action)\n"
    out *= "Sure Actions: [$sure_str]\n"
    out *= "Unsure Actions (Coinflip Side-Features): [$unsure_str]\n"
    out *= "Dynamic Rules (Stochastic): [$rules_str]\n"
    out *= "Constraints: [$neg_str]\n"
    out *= "Context: '$system_prompt'\n"
    out *= "--- LOBE CONTEXT (PREFRONTAL CORTEX) ---\n"
    out *= "$lobe_str\n"
    out *= "--- RELATIONAL CONTEXT ---\n"
    out *= "User Triples: $u_triples\n"
    out *= "Node Triples: $n_triples\n"
    out *= "Anti-Match Detected: $(primary_vote.antimatch)\n"
    out *= "--- AIML MEMORY BANK ---\n$memory_str\n"
    out *= "=========================================\n"
    out *= "🗣️ STOCHASTIC GENERATION (JIT AIML):\n$jit_response\n"
    out *= "========================================="
    return out
end

# GRUG: Family of brain actions. Command must take all vote states now!
reason_family = ["reason", "analyze", "ponder", "calculate"]
for act in reason_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        if mission == "boom"
            error("!!! FATAL: Grug triggered intentional crash to test safety nets !!!")
        end
        node.json_data["last_reason"] = mission
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        
        # GRUG: If relations match well, node stay hot. Else, cool down fast.
        rel_strength = length(primary_vote.user_triples) > 0 ? 2.0 : 0.5
        reset_throttle!(node, rel_strength)
        return generated_text
    end
end

# GRUG: Family of happy face actions.
greet_family = ["greet", "welcome", "smile", "laugh"]
for act in greet_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        reset_throttle!(node, 0.5)
        return generated_text
    end
end

# GRUG: Family of survival actions. Grug learn to run away!
survival_family = ["flee", "hide", "fight"]
for act in survival_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        # Give survival actions a unique payload if we want, or use the standard one
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Survival means danger! Keep the node throttle HOT!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# GRUG: Family of explain actions. Grug make things clear like cave painting!
explain_family = ["explain", "clarify", "describe", "define", "elaborate"]
for act in explain_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Explanations are cold logical work. Medium throttle.
        reset_throttle!(node, 0.7)

        return generated_text
    end
end

# GRUG: Family of empathy actions. Grug feel your pain!
empathy_family = ["comfort", "support", "validate", "acknowledge", "reassure"]
for act in empathy_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Emotional support - warm and open throttle.
        reset_throttle!(node, 0.5)

        return generated_text
    end
end

# GRUG: Family of warning actions. Grug shout danger before it arrives!
warning_family = ["alert", "warn", "caution", "notify", "flag"]
for act in warning_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Warnings are urgent! Keep throttle HOT like survival!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# ==============================================================================
# IMAGE BINARY DETECTION HELPER (FOR /mission AND /grow)
# ==============================================================================

"""
maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}

GRUG: Pre-screen input text for image binary using regex from ImageSDF.
If image binary found:
  1. Decode image data from Base64 (or hex)
  2. Run JIT image->SDF conversion
  3. Apply EyeSystem visual processing (edge blur, attention, arousal cutout)
  4. Apply SDF jitter (pineal drip)
  5. Convert to flat Float64 signal
  6. Return (true, signal)
If no image binary: return (false, Float64[])
"""
function maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}
    if strip(input_text) == ""
        error("!!! FATAL: maybe_convert_image_input got empty input! !!!")
    end

    found, fmt, payload = ImageSDF.detect_image_binary(input_text)
    if !found
        return (false, Float64[])
    end

    println("[IMAGE] 🖼  Image binary detected (format: $fmt). Running JIT SDF conversion...")

    try
        # GRUG: Decode raw image bytes based on detected format
        raw_bytes = if fmt == :base64
            base64decode(payload)
        elseif fmt == :hex_png || fmt == :hex_jpeg
            # GRUG: Convert hex string to bytes
            hex_clean = replace(payload, r"[^A-Fa-f0-9]" => "")
            # GRUG: Hex must be even length (2 chars per byte)
            if length(hex_clean) % 2 != 0
                hex_clean = hex_clean[1:end-1]
            end
            UInt8[parse(UInt8, hex_clean[i:i+1], base=16) for i in 1:2:length(hex_clean)]
        else
            # GRUG: Raw binary escape sequences - use payload bytes directly
            Vector{UInt8}(codeunits(payload))
        end

        if isempty(raw_bytes)
            error("!!! FATAL: Image decode produced empty byte array for format $fmt! !!!")
        end

        # GRUG: Estimate dimensions from byte count (assume square grayscale as fallback).
        # Real use case: width/height should come from image metadata.
        # For this JIT path, Grug use sqrt to estimate square-ish dimensions.
        n_bytes     = length(raw_bytes)
        est_side    = max(1, round(Int, sqrt(Float64(n_bytes))))
        est_width   = est_side
        est_height  = max(1, n_bytes ÷ est_side)

        # GRUG: Run JIT image -> SDFParams conversion
        sdf_params  = ImageSDF.image_to_sdf_params(raw_bytes, est_width, est_height)

        # GRUG: Apply EyeSystem visual processing (blur + attention modulation + arousal cutout)
        mod_brightness, _attn_map = EyeSystem.process_visual_input(
            sdf_params.brightnessArray,
            sdf_params.colorArray,
            sdf_params.xArray,
            sdf_params.yArray,
            sdf_params.width,
            sdf_params.height
        )

        # GRUG: Rebuild SDFParams with eye-processed brightness before jitter
        eye_params = ImageSDF.SDFParams(
            sdf_params.xArray, sdf_params.yArray,
            mod_brightness, sdf_params.colorArray,
            sdf_params.width, sdf_params.height,
            sdf_params.timestamp
        )

        # GRUG: Apply pineal drip jitter (slight deviation from bullseye, snaps back next call)
        jittered_params = ImageSDF.apply_sdf_jitter(eye_params)

        # GRUG: Convert to flat signal vector for PatternScanner compatibility
        signal = ImageSDF.sdf_to_signal(jittered_params; max_samples=256)

        println("[IMAGE] ✅  JIT SDF conversion complete. Signal length: $(length(signal)).")
        return (true, signal)

    catch e
        # GRUG: Image conversion failure is LOUD. No silent swallowing!
        error("!!! FATAL: JIT image->SDF conversion failed for format $fmt: $e !!!")
    end
end

# ==============================================================================
# MISSION PROCESSOR (EXTRACTED FOR QUEUE REUSE)
# ==============================================================================

# GRUG: Track last voter IDs so /wrong knows who to punish
const LAST_VOTER_IDS = String[]
const LAST_VOTER_LOCK = ReentrantLock()

"""
process_mission(mission_text::String)

GRUG: Core mission processing logic, extracted so chatter queue can reuse it.
Handles both text missions and image-binary missions.
Measures response time and records it on the winning nodes for big-O ledger.
"""
function process_mission(mission_text::String)
    if strip(mission_text) == ""
        error("!!! FATAL: process_mission got empty mission text! !!!")
    end

    add_message_to_history!("User", mission_text, false)
    
    # GRUG: Pre-screen for image binary BEFORE normal scan
    is_image, img_signal = maybe_convert_image_input(mission_text)

    # GRUG: ACTION+TONE AROUSAL PRE-SET (text inputs only)
    # For text missions, run the predictor here to nudge EyeSystem arousal BEFORE
    # the scan starts. Image inputs skip this — SDF has its own visual arousal path.
    #
    # WHY HERE AND NOT JUST IN scan_specimens?
    # scan_specimens uses the prediction for confidence weighting (its own concern).
    # Arousal is an EyeSystem concern — it belongs in Main where EyeSystem lives.
    # Running it here means the eye is already tuned by the time scan fires.
    # The two calls are intentionally separate: one modulates scan weights,
    # the other modulates the visual attention gate. They are orthogonal.
    #
    # GRUG: Non-fatal on error. Arousal nudge is enhancement, not core pipeline.
    # If prediction throws for any reason, cave still scans normally.
    if !is_image
        try
            prediction = ActionTonePredictor.predict_action_tone(
                mission_text, SemanticVerbs.get_all_verbs()
            )
            ActionTonePredictor.apply_prediction_to_arousal!(
                prediction,
                EyeSystem.get_arousal,
                EyeSystem.set_arousal!
            )
        catch e
            @warn "[MAIN] ActionTonePredictor arousal nudge failed (non-fatal): $e"
        end
    end

    # GRUG: THESAURUS GATE EXPANSION (text inputs only)
    # Before the scan fires, expand the mission tokens with synonym cloud.
    # This bridges the structural gap (happy/joyful = 0.0 without seeds).
    # Expansion is logged so operator can see what the gate added.
    # Non-fatal: if thesaurus throws for any reason, scan proceeds on raw text.
    if !is_image
        try
            gate_tokens = Thesaurus.thesaurus_gate_filter(mission_text)
            original_tokens = Set(split(lowercase(strip(mission_text))))
            new_tokens = setdiff(gate_tokens, original_tokens)
            if !isempty(new_tokens)
                @info "[MAIN] 🔤 Thesaurus gate expanded $(length(original_tokens)) tokens → $(length(gate_tokens)) (+$(length(new_tokens)) synonyms: $(join(sort(collect(new_tokens)), ", ")))"
            end
        catch e
            @warn "[MAIN] Thesaurus gate expansion failed (non-fatal): $e"
        end
    end

    println("--> Scanning specimens & looking for dialectical relations...")
    t_start = time()

    valid_specimens = if is_image
        # GRUG: Image input! Scan image nodes using SDF signal.
        println("[IMAGE] 🔍  Routing to image node scan path...")
        _scan_image_specimens(img_signal)
    else
        # GRUG: Normal text scan with drop-table expansion
        scan_and_expand(mission_text)
    end

    if isempty(valid_specimens)
        println("--> No valid specimens found for this input. Cave is silent.")
        return
    end

    cast_votes = Vote[]
    for (id, conf, is_antimatch, u_trips, n_trips) in valid_specimens
        push!(cast_votes, cast_vote(id, conf, is_antimatch, u_trips, n_trips))
    end

    println("--> $(length(cast_votes)) valid votes passed gate... compiling JIT superposition...")
    output = ephemeral_aiml_orchestrator(mission_text, cast_votes)

    t_elapsed = time() - t_start

    # GRUG: Record response time on all winning node voters for big-O ledger
    for v in cast_votes
        voter_node = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
        if !isnothing(voter_node)
            record_response_time!(voter_node, t_elapsed)
        end
    end

    # GRUG: Store voter IDs so /wrong can punish them if user is unhappy
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
        append!(LAST_VOTER_IDS, [v.node_id for v in cast_votes])
    end

    println("\n🤖 AIML Output Scaffold:\n$output")
    add_message_to_history!("System", output, false)
end

# ==============================================================================
# IMAGE NODE SCAN PATH
# ==============================================================================

"""
_scan_image_specimens(img_signal::Vector{Float64})::Vector{Tuple{...}}

GRUG: Scan only image nodes using SDF signal vector.
Text nodes are skipped. Image nodes use their stored SDF signal for comparison.
Returns same tuple format as scan_specimens for uniform downstream processing.
"""
function _scan_image_specimens(img_signal::Vector{Float64})
    if isempty(img_signal)
        error("!!! FATAL: _scan_image_specimens got empty img_signal! !!!")
    end

    results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            # GRUG: Only image nodes respond to image signals
            !node.is_image_node && continue
            node.is_grave       && continue

            # GRUG: Strength-biased coinflip applies to image nodes too
            !strength_biased_scan_coinflip(node) && continue

            # GRUG: Image node needs a non-empty SDF signal to compare against
            if isempty(node.signal)
                # GRUG: Image node has no signal baked in yet. Skip safely.
                continue
            end

            # GRUG: Use cheap_scan for image signals (SDF comparison)
            try
                target = length(img_signal) >= length(node.signal) ? img_signal : continue
                _, conf = cheap_scan(target, node.signal; threshold=0.25)
                push!(results, (id, conf, false, RelationalTriple[], node.relational_patterns))
            catch e
                if e isa PatternNotFoundError
                    continue
                elseif e isa PatternScanError
                    rethrow(e)
                else
                    error("!!! FATAL: Unknown error in _scan_image_specimens for node $id: $e !!!")
                end
            end
        end
    end

    return results
end

# ==============================================================================
# SPECIMEN LOADER (BATCH SEEDING FROM JSON)
# ==============================================================================

# GRUG: /loadSpecimen is the BIG GROW. Not one node at a time like /grow.
# Grug hand you the ENTIRE CAVE BLUEPRINT in one JSON scroll.
# Nodes, rules, lobes, connections, verbs, synonyms, inhibitions, pins — ALL AT ONCE.
# Grug validate EVERYTHING before planting ANYTHING. If scroll is bad, NOTHING grows.
# No half-built caves. No silent failures. Grug scream loud if scroll is wrong.

"""
load_specimen_from_json!(json_str::String)::String

GRUG: Parse a full specimen blueprint JSON and seed the cave in batch.
Validates the entire payload before committing any changes.
Returns a multi-line summary string of everything that happened.

Supported top-level keys (all optional, but at least one required):
  "nodes"        - Array of node objects (same format as /grow)
  "rules"        - Array of rule objects: {"text": "...", "prob": 0.0-1.0}
  "lobes"        - Array of lobe objects: {"id": "...", "subject": "..."}
  "connections"  - Array of connection pairs: {"lobe_a": "...", "lobe_b": "..."}
  "lobe_nodes"   - Array of lobe node assignments: {"lobe_id": "...", "node": {<node_json>}}
  "verbs"        - Array of verb entries: {"verb": "...", "class": "..."}
  "verb_classes"  - Array of class names: ["causal", "epistemic", ...]
  "synonyms"     - Array of synonym pairs: {"canonical": "...", "alias": "..."}
  "inhibitions"  - Array of inhibition entries: {"word": "...", "reason": "..."}
  "pins"         - Array of pinned text strings: ["important fact 1", ...]
"""
function load_specimen_from_json!(json_str::String)::String
    if strip(json_str) == ""
        error("!!! FATAL: /loadSpecimen got empty input! Grug cannot grow cave from invisible wind! !!!")
    end

    # GRUG: Phase 1 — Parse JSON. If scroll is unreadable, scream immediately.
    specimen = try
        JSON.parse(json_str)
    catch e
        error("!!! FATAL: /loadSpecimen JSON parse failed! Grug cannot read this scroll: $e !!!")
    end

    if !isa(specimen, Dict)
        error("!!! FATAL: /loadSpecimen expects a JSON object (Dict) at top level, got $(typeof(specimen))! !!!")
    end

    # GRUG: Allowed top-level keys. Anything else is a typo or sabotage.
    allowed_keys = Set(["nodes", "rules", "lobes", "connections", "lobe_nodes",
                        "verbs", "verb_classes", "synonyms", "inhibitions", "pins"])
    for key in keys(specimen)
        if !(key in allowed_keys)
            error("!!! FATAL: /loadSpecimen found unknown top-level key '$key'! Allowed keys: $(join(sort(collect(allowed_keys)), ", ")) !!!")
        end
    end

    # GRUG: At least one section must be present. Empty scroll is useless.
    if isempty(specimen)
        error("!!! FATAL: /loadSpecimen JSON is empty object {}! Give Grug at least one section to work with! !!!")
    end

    # GRUG: Phase 2 — Validate ALL sections BEFORE committing ANY changes.
    # Each section gets its own validation pass. Errors are collected, not thrown one at a time.
    # If ANY validation fails, NOTHING is committed. Atomic cave blueprint.
    validation_errors = String[]

    # --- VALIDATE: verb_classes ---
    v_verb_classes = String[]
    if haskey(specimen, "verb_classes")
        if !isa(specimen["verb_classes"], AbstractVector)
            push!(validation_errors, "verb_classes: must be an array of strings")
        else
            for (i, vc) in enumerate(specimen["verb_classes"])
                if !isa(vc, AbstractString) || strip(vc) == ""
                    push!(validation_errors, "verb_classes[$i]: must be a non-empty string")
                else
                    push!(v_verb_classes, String(strip(vc)))
                end
            end
        end
    end

    # --- VALIDATE: verbs ---
    v_verbs = Tuple{String, String}[]
    if haskey(specimen, "verbs")
        if !isa(specimen["verbs"], AbstractVector)
            push!(validation_errors, "verbs: must be an array of {verb, class} objects")
        else
            for (i, ventry) in enumerate(specimen["verbs"])
                if !isa(ventry, Dict)
                    push!(validation_errors, "verbs[$i]: must be a JSON object with 'verb' and 'class'")
                elseif !haskey(ventry, "verb") || !haskey(ventry, "class")
                    push!(validation_errors, "verbs[$i]: missing 'verb' or 'class' field")
                elseif strip(ventry["verb"]) == "" || strip(ventry["class"]) == ""
                    push!(validation_errors, "verbs[$i]: 'verb' and 'class' must be non-empty strings")
                else
                    push!(v_verbs, (String(strip(ventry["verb"])), String(strip(ventry["class"]))))
                end
            end
        end
    end

    # --- VALIDATE: synonyms ---
    v_synonyms = Tuple{String, String}[]
    if haskey(specimen, "synonyms")
        if !isa(specimen["synonyms"], AbstractVector)
            push!(validation_errors, "synonyms: must be an array of {canonical, alias} objects")
        else
            for (i, sentry) in enumerate(specimen["synonyms"])
                if !isa(sentry, Dict)
                    push!(validation_errors, "synonyms[$i]: must be a JSON object with 'canonical' and 'alias'")
                elseif !haskey(sentry, "canonical") || !haskey(sentry, "alias")
                    push!(validation_errors, "synonyms[$i]: missing 'canonical' or 'alias' field")
                elseif strip(sentry["canonical"]) == "" || strip(sentry["alias"]) == ""
                    push!(validation_errors, "synonyms[$i]: 'canonical' and 'alias' must be non-empty strings")
                else
                    push!(v_synonyms, (String(strip(sentry["canonical"])), String(strip(sentry["alias"]))))
                end
            end
        end
    end

    # --- VALIDATE: lobes ---
    v_lobes = Tuple{String, String}[]
    if haskey(specimen, "lobes")
        if !isa(specimen["lobes"], AbstractVector)
            push!(validation_errors, "lobes: must be an array of {id, subject} objects")
        else
            for (i, lentry) in enumerate(specimen["lobes"])
                if !isa(lentry, Dict)
                    push!(validation_errors, "lobes[$i]: must be a JSON object with 'id' and 'subject'")
                elseif !haskey(lentry, "id") || !haskey(lentry, "subject")
                    push!(validation_errors, "lobes[$i]: missing 'id' or 'subject' field")
                elseif strip(lentry["id"]) == "" || strip(lentry["subject"]) == ""
                    push!(validation_errors, "lobes[$i]: 'id' and 'subject' must be non-empty strings")
                else
                    push!(v_lobes, (String(strip(lentry["id"])), String(strip(lentry["subject"]))))
                end
            end
        end
    end

    # --- VALIDATE: connections ---
    v_connections = Tuple{String, String}[]
    if haskey(specimen, "connections")
        if !isa(specimen["connections"], AbstractVector)
            push!(validation_errors, "connections: must be an array of {lobe_a, lobe_b} objects")
        else
            for (i, centry) in enumerate(specimen["connections"])
                if !isa(centry, Dict)
                    push!(validation_errors, "connections[$i]: must be a JSON object with 'lobe_a' and 'lobe_b'")
                elseif !haskey(centry, "lobe_a") || !haskey(centry, "lobe_b")
                    push!(validation_errors, "connections[$i]: missing 'lobe_a' or 'lobe_b' field")
                elseif strip(centry["lobe_a"]) == "" || strip(centry["lobe_b"]) == ""
                    push!(validation_errors, "connections[$i]: 'lobe_a' and 'lobe_b' must be non-empty strings")
                else
                    push!(v_connections, (String(strip(centry["lobe_a"])), String(strip(centry["lobe_b"]))))
                end
            end
        end
    end

    # --- VALIDATE: nodes ---
    v_nodes = Vector{Tuple{String, String, Dict{String,Any}, Vector{String}, Bool}}()
    if haskey(specimen, "nodes")
        if !isa(specimen["nodes"], AbstractVector)
            push!(validation_errors, "nodes: must be an array of node objects")
        else
            for (i, nentry) in enumerate(specimen["nodes"])
                if !isa(nentry, Dict)
                    push!(validation_errors, "nodes[$i]: must be a JSON object")
                elseif !haskey(nentry, "pattern") || !haskey(nentry, "action_packet")
                    push!(validation_errors, "nodes[$i]: missing 'pattern' or 'action_packet' field")
                elseif strip(nentry["pattern"]) == "" || strip(nentry["action_packet"]) == ""
                    push!(validation_errors, "nodes[$i]: 'pattern' and 'action_packet' must be non-empty")
                else
                    # GRUG: Validate action packet syntax BEFORE commit phase
                    try
                        parse_action_packet(String(nentry["action_packet"]))
                    catch e
                        push!(validation_errors, "nodes[$i]: action_packet parse failed: $e")
                        continue
                    end
                    json_data  = haskey(nentry, "json_data") ? Dict{String,Any}(string(k) => v for (k,v) in nentry["json_data"]) :
                                 haskey(nentry, "data") ? Dict{String,Any}(string(k) => v for (k,v) in nentry["data"]) :
                                 Dict{String,Any}()
                    drop_table = (haskey(nentry, "drop_table") && nentry["drop_table"] isa AbstractVector) ?
                                 String[string(x) for x in nentry["drop_table"]] : String[]
                    is_img     = haskey(nentry, "is_image_node") && nentry["is_image_node"] === true
                    push!(v_nodes, (String(nentry["pattern"]), String(nentry["action_packet"]), json_data, drop_table, is_img))
                end
            end
        end
    end

    # --- VALIDATE: lobe_nodes ---
    v_lobe_nodes = Vector{Tuple{String, String, String, Dict{String,Any}, Vector{String}}}()
    if haskey(specimen, "lobe_nodes")
        if !isa(specimen["lobe_nodes"], AbstractVector)
            push!(validation_errors, "lobe_nodes: must be an array of {lobe_id, node} objects")
        else
            for (i, lnentry) in enumerate(specimen["lobe_nodes"])
                if !isa(lnentry, Dict)
                    push!(validation_errors, "lobe_nodes[$i]: must be a JSON object with 'lobe_id' and 'node'")
                elseif !haskey(lnentry, "lobe_id") || !haskey(lnentry, "node")
                    push!(validation_errors, "lobe_nodes[$i]: missing 'lobe_id' or 'node' field")
                elseif strip(lnentry["lobe_id"]) == ""
                    push!(validation_errors, "lobe_nodes[$i]: 'lobe_id' must be non-empty string")
                else
                    nd = lnentry["node"]
                    if !isa(nd, Dict)
                        push!(validation_errors, "lobe_nodes[$i].node: must be a JSON object")
                    elseif !haskey(nd, "pattern") || !haskey(nd, "action_packet")
                        push!(validation_errors, "lobe_nodes[$i].node: missing 'pattern' or 'action_packet'")
                    elseif strip(nd["pattern"]) == "" || strip(nd["action_packet"]) == ""
                        push!(validation_errors, "lobe_nodes[$i].node: 'pattern' and 'action_packet' must be non-empty")
                    else
                        try
                            parse_action_packet(String(nd["action_packet"]))
                        catch e
                            push!(validation_errors, "lobe_nodes[$i].node: action_packet parse failed: $e")
                            continue
                        end
                        json_data  = haskey(nd, "data") ? Dict{String,Any}(string(k) => v for (k,v) in nd["data"]) : Dict{String,Any}()
                        drop_table = (haskey(nd, "drop_table") && nd["drop_table"] isa AbstractVector) ?
                                     String[string(x) for x in nd["drop_table"]] : String[]
                        push!(v_lobe_nodes, (String(strip(lnentry["lobe_id"])), String(nd["pattern"]), String(nd["action_packet"]), json_data, drop_table))
                    end
                end
            end
        end
    end

    # --- VALIDATE: rules ---
    v_rules = Tuple{String, Float64}[]
    if haskey(specimen, "rules")
        if !isa(specimen["rules"], AbstractVector)
            push!(validation_errors, "rules: must be an array of rule objects")
        else
            for (i, rentry) in enumerate(specimen["rules"])
                if !isa(rentry, Dict)
                    push!(validation_errors, "rules[$i]: must be a JSON object with 'text' field")
                elseif !haskey(rentry, "text")
                    push!(validation_errors, "rules[$i]: missing 'text' field")
                elseif strip(rentry["text"]) == ""
                    push!(validation_errors, "rules[$i]: 'text' must be non-empty")
                else
                    rtext = String(strip(rentry["text"]))
                    rprob = 1.0
                    if haskey(rentry, "prob")
                        rp = rentry["prob"]
                        if isa(rp, Number) && 0.0 <= rp <= 1.0
                            rprob = Float64(rp)
                        else
                            push!(validation_errors, "rules[$i]: 'prob' must be a number between 0.0 and 1.0, got: $rp")
                            continue
                        end
                    end
                    # GRUG: Validate magic word tags just like add_orchestration_rule! does
                    bad_tags = false
                    for m in eachmatch(r"\{[A-Z_]+\}", rtext)
                        tag = m.match
                        if !(tag in ALLOWED_RULE_TAGS)
                            push!(validation_errors, "rules[$i]: invalid tag '$tag'. Allowed: $(join(ALLOWED_RULE_TAGS, ", "))")
                            bad_tags = true
                        end
                    end
                    !bad_tags && push!(v_rules, (rtext, rprob))
                end
            end
        end
    end

    # --- VALIDATE: inhibitions ---
    v_inhibitions = Tuple{String, String}[]
    if haskey(specimen, "inhibitions")
        if !isa(specimen["inhibitions"], AbstractVector)
            push!(validation_errors, "inhibitions: must be an array of {word} objects")
        else
            for (i, ientry) in enumerate(specimen["inhibitions"])
                if !isa(ientry, Dict)
                    push!(validation_errors, "inhibitions[$i]: must be a JSON object with 'word' field")
                elseif !haskey(ientry, "word")
                    push!(validation_errors, "inhibitions[$i]: missing 'word' field")
                elseif strip(ientry["word"]) == ""
                    push!(validation_errors, "inhibitions[$i]: 'word' must be non-empty string")
                else
                    reason = haskey(ientry, "reason") ? String(strip(string(ientry["reason"]))) : ""
                    push!(v_inhibitions, (String(strip(ientry["word"])), reason))
                end
            end
        end
    end

    # --- VALIDATE: pins ---
    v_pins = String[]
    if haskey(specimen, "pins")
        if !isa(specimen["pins"], AbstractVector)
            push!(validation_errors, "pins: must be an array of strings")
        else
            for (i, pentry) in enumerate(specimen["pins"])
                if !isa(pentry, AbstractString) || strip(pentry) == ""
                    push!(validation_errors, "pins[$i]: must be a non-empty string")
                else
                    push!(v_pins, String(strip(pentry)))
                end
            end
        end
    end

    # GRUG: Phase 2 complete. If ANY validation failed, reject the ENTIRE specimen.
    # Grug does not build half a cave. All or nothing!
    if !isempty(validation_errors)
        err_list = join(["  ❌ $e" for e in validation_errors], "\n")
        error("!!! FATAL: /loadSpecimen validation failed with $(length(validation_errors)) error(s):\n$err_list\n!!! NO CHANGES COMMITTED. Fix the scroll and try again. !!!")
    end

    # GRUG: Phase 3 — COMMIT. All validation passed. Now plant everything in order.
    # Order matters: verb_classes → verbs → synonyms → lobes → connections →
    # nodes → lobe_nodes → rules → inhibitions → pins
    # Each section is wrapped in try/catch. Errors here are FATAL (should not happen
    # after validation, but Grug is paranoid).

    summary_lines = String[]
    counts = Dict{String,Int}("verb_classes" => 0, "verbs" => 0, "synonyms" => 0,
                               "lobes" => 0, "connections" => 0, "nodes" => 0,
                               "lobe_nodes" => 0, "rules" => 0, "inhibitions" => 0, "pins" => 0)

    # --- COMMIT: verb_classes ---
    for vc in v_verb_classes
        try
            SemanticVerbs.add_relation_class!(vc)
            counts["verb_classes"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to create verb class '$vc': $e !!!")
        end
    end

    # --- COMMIT: verbs ---
    for (verb, cls) in v_verbs
        try
            SemanticVerbs.add_verb!(verb, cls)
            counts["verbs"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to add verb '$verb' to class '$cls': $e !!!")
        end
    end

    # --- COMMIT: synonyms ---
    for (canonical, alias) in v_synonyms
        try
            SemanticVerbs.add_synonym!(canonical, alias)
            counts["synonyms"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to add synonym '$alias' → '$canonical': $e !!!")
        end
    end

    # --- COMMIT: lobes ---
    for (lid, subj) in v_lobes
        try
            Lobe.create_lobe!(lid, subj)
            counts["lobes"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to create lobe '$lid': $e !!!")
        end
    end

    # --- COMMIT: connections ---
    for (la, lb) in v_connections
        try
            Lobe.connect_lobes!(la, lb)
            counts["connections"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to connect lobes '$la' ↔ '$lb': $e !!!")
        end
    end

    # --- COMMIT: nodes ---
    node_ids_created = String[]
    for (pat, ap, jd, dt, is_img) in v_nodes
        try
            nid = create_node(pat, ap, jd, dt; is_image_node=is_img)
            push!(node_ids_created, nid)
            counts["nodes"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to create node (pattern='$(pat[1:min(40, length(pat))])'): $e !!!")
        end
    end

    # --- COMMIT: lobe_nodes ---
    lobe_node_ids_created = String[]
    for (lid, pat, ap, jd, dt) in v_lobe_nodes
        try
            nid = create_node(pat, ap, jd, dt)
            Lobe.add_node_to_lobe!(lid, nid)
            json_count = LobeTable.json_to_table_chunk!(lid, nid, jd)
            drop_count = LobeTable.drop_table_to_chunk!(lid, nid, dt)
            push!(lobe_node_ids_created, nid)
            counts["lobe_nodes"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to grow node into lobe '$lid' (pattern='$(pat[1:min(40, length(pat))])'): $e !!!")
        end
    end

    # --- COMMIT: rules ---
    for (rtext, rprob) in v_rules
        try
            push!(AIML_DROP_TABLE, StochasticRule(rtext, rprob))
            counts["rules"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to add rule '$rtext': $e !!!")
        end
    end

    # --- COMMIT: inhibitions ---
    for (word, reason) in v_inhibitions
        try
            InputQueue.add_inhibition!(word; reason=reason)
            counts["inhibitions"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to add inhibition '$word': $e !!!")
        end
    end

    # --- COMMIT: pins ---
    for pin_text in v_pins
        try
            add_message_to_history!("User_Pinned", pin_text, true)
            counts["pins"] += 1
        catch e
            error("!!! FATAL: /loadSpecimen failed to pin text: $e !!!")
        end
    end

    # GRUG: Phase 4 — Build the victory scroll. Tell operator what Grug planted.
    push!(summary_lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(summary_lines, "║            🧬 SPECIMEN LOADED SUCCESSFULLY                  ║")
    push!(summary_lines, "╠══════════════════════════════════════════════════════════════╣")

    total_ops = sum(values(counts))
    for (section, count) in sort(collect(counts), by=x->x[1])
        if count > 0
            emoji = Dict("verb_classes" => "🗂 ", "verbs" => "🔧", "synonyms" => "📖",
                         "lobes" => "🧠", "connections" => "🔗", "nodes" => "🌱",
                         "lobe_nodes" => "🌿", "rules" => "⚙️ ", "inhibitions" => "🚫",
                         "pins" => "📌")
            e = get(emoji, section, "  ")
            push!(summary_lines, "  $e  $(rpad(section, 16)) : $count")
        end
    end

    push!(summary_lines, "  ─────────────────────────────────────")
    push!(summary_lines, "  📊  TOTAL OPERATIONS  : $total_ops")

    if !isempty(node_ids_created)
        id_preview = length(node_ids_created) <= 5 ?
            join(node_ids_created, ", ") :
            join(node_ids_created[1:5], ", ") * " ... (+$(length(node_ids_created)-5) more)"
        push!(summary_lines, "  🆔  Node IDs          : $id_preview")
    end
    if !isempty(lobe_node_ids_created)
        id_preview = length(lobe_node_ids_created) <= 5 ?
            join(lobe_node_ids_created, ", ") :
            join(lobe_node_ids_created[1:5], ", ") * " ... (+$(length(lobe_node_ids_created)-5) more)"
        push!(summary_lines, "  🆔  Lobe Node IDs     : $id_preview")
    end

    push!(summary_lines, "╚══════════════════════════════════════════════════════════════╝")

    return join(summary_lines, "\n")
end

# ==============================================================================
# CAVE POPULATION & CLI LOOP
# ==============================================================================

try
    println("Growing initial map seeds with Stochastic Emotion Packets & Relational Gating...")
    greet_ctx    = Dict{String, Any}("system_prompt" => "Highly polite greeting protocols active.")
    reason_ctx   = Dict{String, Any}("system_prompt" => "Cold logical analysis engine active.")
    
    # GRUG: Relation dictionary to guard the gate!
    relational_ctx = Dict{String, Any}(
        "system_prompt"      => "Causal relational analysis active.",
        "required_relations" => ["hits"], # GRUG: Gate requirement! Must hit!
        "relation_weights"   => Dict("hits" => 2.5) # GRUG: Amplify math if hits match!
    )

    # GRUG: Seed nodes use pipe-delimited action packets with inline negatives per action.
    # Format: "action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight"
    create_node("hello hi greeting mornin",
        "greet[dont frown, dont insult]^3 | welcome[dont be rude]^2 | smile^1",
        greet_ctx, String[])

    create_node("think ponder reason calculate",
        "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^1",
        reason_ctx, String[])

    # GRUG: Node that demands verb "hits". Will hard-reject "rock hits grug" via anti-match!
    create_node("grug hits rock and makes fire",
        "analyze[dont panic]^5 | ponder^2",
        relational_ctx, String[])
catch e
    println("!!! FATAL: Grug failed to plant initial seeds in cave !!!")
    Base.show_backtrace(stdout, catch_backtrace())
    exit(1)
end

# ==============================================================================
# IDLE BACKGROUND TRACKER (CHATTER + PHAGY)
# ==============================================================================

# GRUG: Track when last user input arrived so idle detector knows when to act.
const LAST_INPUT_TIME = Ref{Float64}(time())

# GRUG: Rules vector and lock for RULE PRUNER automaton.
# These are the live orchestration rules registered via /addRule.
# PhagyMode.prune_dormant_rules! expects: rules with fire_count, dormancy_strikes, is_dormant fields.
const PHAGY_RULES_REF  = Ref{Vector}(Vector())
const PHAGY_RULES_LOCK = ReentrantLock()

"""
maybe_run_idle()

GRUG: Check if cave is idle enough for an idle action.
If yes, do a 50/50 COINFLIP:
  - Heads (CHATTER): snapshot NODE_MAP, run gossip session, apply diffs back.
  - Tails (PHAGY):   run one phagy automaton for map maintenance.

This is called in the main CLI loop during idle waits.
Uses the same event timer as before - no new timer needed. One idle event, one action.
"""
function maybe_run_idle()
    # GRUG: Don't start if chatter is already running (single-threaded loop guard)
    status = ChatterMode.get_chatter_status()
    status.is_running && return

    # GRUG: Check idle threshold (default 30s, jittered inside should_trigger_chatter)
    !ChatterMode.should_trigger_chatter(LAST_INPUT_TIME[], 30.0) && return

    # GRUG: THE COINFLIP. 50/50 - Chatter or Phagy. No favorites.
    if rand() < 0.5
        # ── HEADS: CHATTER ────────────────────────────────────────────────────
        println("[IDLE] 🪙  Coinflip → CHATTER. Starting gossip round...")

        # GRUG: Snapshot the NODE_MAP for the chatter clones
        snapshot = Tuple{String, String, String, Float64}[]
        lock(NODE_LOCK) do
            for (id, node) in NODE_MAP
                # GRUG: Only snapshot alive, non-image nodes for chatter
                # (Image nodes don't gossip pattern text - their patterns are SDF data)
                !node.is_grave && !node.is_image_node && push!(snapshot, (id, node.pattern, node.action_packet, node.strength))
            end
        end

        if isempty(snapshot)
            println("[IDLE:CHATTER] ⚠  No eligible nodes for chatter (all grave or image). Skipping.")
            LAST_INPUT_TIME[] = time()
            return
        end

        try
            session = ChatterMode.start_chatter_session!(snapshot)
            ChatterMode.apply_chatter_diffs!(session, NODE_MAP, NODE_LOCK)
        catch e
            println("[IDLE:CHATTER] !!! ERROR during chatter session: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
        end

    else
        # ── TAILS: PHAGY ──────────────────────────────────────────────────────
        println("[IDLE] 🪙  Coinflip → PHAGY. Running maintenance automaton...")

        # GRUG: Grab the live rules vector for RULE PRUNER
        rules_snapshot = lock(PHAGY_RULES_LOCK) do
            PHAGY_RULES_REF[]
        end

        try
            PhagyMode.run_phagy!(
                NODE_MAP,
                NODE_LOCK,
                HOPFIELD_CACHE,
                HOPFIELD_CACHE_LOCK,
                rules_snapshot,
                PHAGY_RULES_LOCK
            )
        catch e
            println("[IDLE:PHAGY] !!! ERROR during phagy cycle: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    # GRUG: Reset idle timer after EITHER action so the next event waits a full interval.
    # Without this reset, chatter or phagy would re-trigger immediately next loop tick.
    LAST_INPUT_TIME[] = time()
end

# ==============================================================================
# MAIN CLI LOOP
# ==============================================================================

function run_cli()
    println("\nSystem Online. Grug waiting at cave entrance for instructions.")
    println("Primary  : /mission <input>                    (text or image binary)")
    println("Feedback : /wrong                              (penalize last response voters)")
    println("Explicit : /explicit <cmd> [<node_id>] <input>")
    println("Grow     : /grow <single_line_json_packet>")
    println("Rules    : /addRule <rule text> [prob=0.0-1.0]")
    println("           Tags: {MISSION}, {PRIMARY_ACTION}, {SURE_ACTIONS}, {UNSURE_ACTIONS},")
    println("                 {ALL_ACTIONS}, {CONFIDENCE}, {NODE_ID}, {MEMORY}, {LOBE_CONTEXT}")
    println("Memory   : /pin <text>")
    println("Nodes    : /nodes                              (show node map status)")
    println("Status   : /status                             (show chatter + system status)")
    println("Arousal  : /arousal <0.0-1.0>                 (set eye system arousal level)")
    println("Verbs    : /addVerb <verb> <class>             (add verb to relation class)")
    println("         : /addRelationClass <name>            (create new verb class bucket)")
    println("         : /addSynonym <canonical> <alias>     (normalize alias->canonical)")
    println("         : /listVerbs                          (show all verb classes + synonyms)")
    println("Lobes    : /newLobe <id> <subject>             (create a new subject lobe)")
    println("         : /connectLobes <id_a> <id_b>         (connect two lobes)")
    println("         : /lobeGrow <lobe_id> <json_packet>   (grow node into specific lobe)")
    println("         : /lobes                              (list all lobes + node counts)")
    println("         : /tableStatus <lobe_id>              (show hash table chunks for a lobe)")
    println("         : /tableMatch <lobe_id> <chunk> <pat> (pattern-activate entries in chunk)")
    println("Thesaurus: /thesaurus <word1> | <word2>        (compare words/concepts dimensionally)")
    println("         : /thesaurus <w1> | <w2> :: <ctx1> :: <ctx2>  (with context lists)")
    println("NegThes  : /negativeThesaurus add|remove|list|check|flush")
    println("Specimen : /loadSpecimen <json>                (batch-load full cave blueprint)")
    println("Help     : /help                               (full command reference)")
    println()
    println("╔══════════════════════════════════════════════════════════════════╗")
    println("║  SPECIMEN SEEDING GUIDE (read before /grow)                     ║")
    println("╠══════════════════════════════════════════════════════════════════╣")
    println("║  Automatic neighbor latching is SUPPRESSED below 1000 nodes.   ║")
    println("║  Below that threshold, YOU control topology via drop_table.     ║")
    println("║                                                                  ║")
    println("║  For a coherent specimen from the start:                        ║")
    println("║  1. Seed ORTHOGONAL archetypes first - distinct semantic poles. ║")
    println("║     Don't plant 50 near-identical nodes up front.               ║")
    println("║  2. Use required_relations as semantic GATES from day one.      ║")
    println("║     Nodes that demand specific verbs won't fire on noise.       ║")
    println("║  3. Name action_packets deliberately - distinct action families ║")
    println("║     give the superposition orchestrator something to work with. ║")
    println("║  4. Wire drop_tables manually for known co-activation pairs.    ║")
    println("║     Don't rely on the latch system to discover semantics.       ║")
    println("║  5. Your first ~100 nodes are the specimen's DNA.               ║")
    println("║     The engine enforces structure at scale (1000+ nodes).       ║")
    println("║     You enforce MEANING at the start.                           ║")
    println("╚══════════════════════════════════════════════════════════════════╝")
    
    while true
        print("\nBrain > ")

        # GRUG: Quick idle check BEFORE reading input.
        # Non-blocking: if no input ready, maybe trigger chatter OR phagy (50/50 coinflip).
        # In standard Julia CLI, readline() blocks. So idle action runs between prompts.
        maybe_run_idle()

        line = strip(readline())
        
        line == "" && continue

        # GRUG: Update last input time so idle detector resets
        LAST_INPUT_TIME[] = time()

        # GRUG: If chatter is currently running (async future), queue the input.
        # In this single-threaded implementation, chatter runs synchronously between
        # prompts so this is a safeguard for future async upgrades.
        status = ChatterMode.get_chatter_status()
        if status.is_running
            ChatterMode.enqueue_input!(line)
            println("[MAIN] ⏳  Input queued (chatter active). Will process after chatter ends.")
            continue
        end

        # GRUG: Drain any queued inputs from previous chatter round before processing new one
        ChatterMode.process_chatter_queue!(process_mission)
        
        try
            # GRUG: Parse all known commands via regex
            m_mission     = match(r"^/mission\s+(.+)"s,  line)
            m_wrong       = match(r"^/wrong\s*$",         line)
            m_explicit    = match(r"^/explicit\s+([a-zA-Z0-9_]+)\s+\[(.+?)\]\s+(.+)", line)
            m_grow        = match(r"^/grow\s+(.+)"s,      line)
            m_rule        = match(r"^/addRule\s+(.+)"s,   line)
            m_pin         = match(r"^/pin\s+(.+)"s,       line)
            m_nodes       = match(r"^/nodes\s*$",          line)
            m_status      = match(r"^/status\s*$",         line)
            m_arousal     = match(r"^/arousal\s+([0-9.]+)\s*$", line)
            # GRUG: Semantic verb/synonym system commands
            m_addverb     = match(r"^/addVerb\s+(\S+)\s+(\S+)\s*$",        line)
            m_addrelclass = match(r"^/addRelationClass\s+(\S+)\s*$",        line)
            m_addsynonym  = match(r"^/addSynonym\s+(\S+)\s+(\S+)\s*$",     line)
            m_listverbs   = match(r"^/listVerbs\s*$",                        line)
            # GRUG: Lobe management commands
            m_newlobe     = match(r"^/newLobe\s+(\S+)\s+(.+)$",               line)
            m_connectlobes= match(r"^/connectLobes\s+(\S+)\s+(\S+)\s*$",    line)
            m_lobegrow    = match(r"^/lobeGrow\s+(\S+)\s+(.+)$"s,             line)
            m_lobes        = match(r"^/lobes\s*$",                                      line)
            m_tablestatus  = match(r"^/tableStatus\s+(\S+)\s*$",                        line)
            m_tablematch   = match(r"^/tableMatch\s+(\S+)\s+(\S+)\s+(.+)$",            line)
            # GRUG: Thesaurus dimensional similarity command
            m_thesaurus    = match(r"^/thesaurus\s+(.+)\|(.+)$",                       line)
            # GRUG: NegativeThesaurus inhibition commands
            m_neginhibit   = match(r"^/negativeThesaurus\s+add\s+(.+?)(?:\s+--reason\s+(.+))?$", line)
            m_negremove    = match(r"^/negativeThesaurus\s+remove\s+(\S+)\s*$",         line)
            m_neglist      = match(r"^/negativeThesaurus\s+list\s*$",                   line)
            m_negcheck     = match(r"^/negativeThesaurus\s+check\s+(.+)$",              line)
            m_negflush     = match(r"^/negativeThesaurus\s+flush\s*$",                  line)
            # GRUG: Help command — show all commands
            m_loadspecimen = match(r"^/loadSpecimen\s+(.+)"s,                             line)
            m_help         = match(r"^/help\s*$",                                       line)
            
            if !isnothing(m_help)
                # GRUG: /help - show all available CLI commands. Cave painting instruction scroll!
                println("╔══════════════════════════════════════════════════════════════╗")
                println("║                  GRUGBOT COMMAND REFERENCE                  ║")
                println("╠══════════════════════════════════════════════════════════════╣")
                println("║  CORE                                                        ║")
                println("║  /mission <text>            Send input to the AI engine      ║")
                println("║  /wrong                     Penalize last response voters    ║")
                println("║  /explicit <cmd> [<id>] <t> Force a specific command+node    ║")
                println("║  /grow <json>               Plant nodes from JSON packet     ║")
                println("║  /addRule <rule>            Add stochastic orchestration rule║")
                println("║  /pin <text>                Pin text to memory cave wall     ║")
                println("║                                                              ║")
                println("║  STATUS                                                      ║")
                println("║  /nodes                     Show all node map status         ║")
                println("║  /status                    Full system health snapshot      ║")
                println("║  /arousal <0.0-1.0>         Set eye system arousal level     ║")
                println("║                                                              ║")
                println("║  SEMANTIC VERBS                                              ║")
                println("║  /addVerb <verb> <class>    Add verb to relation class       ║")
                println("║  /addRelationClass <name>   Create new verb class bucket     ║")
                println("║  /addSynonym <canon> <alias> Register synonym normalization  ║")
                println("║  /listVerbs                 Show verb registry               ║")
                println("║                                                              ║")
                println("║  LOBES & TABLES                                              ║")
                println("║  /newLobe <id> <subject>    Create new subject partition     ║")
                println("║  /connectLobes <a> <b>      Link two lobes bidirectionally   ║")
                println("║  /lobeGrow <id> <json>      Grow node directly into lobe     ║")
                println("║  /lobes                     Show lobe status summary         ║")
                println("║  /tableStatus <lobe_id>     Show hash table chunk sizes      ║")
                println("║  /tableMatch <l> <c> <pat>  Pattern-activate table entries   ║")
                println("║                                                              ║")
                println("║  THESAURUS                                                   ║")
                println("║  /thesaurus <w1> | <w2>     Dimensional similarity compare   ║")
                println("║                                                              ║")
                println("║  NEGATIVE THESAURUS (INHIBITION FILTER)                     ║")
                println("║  /negativeThesaurus add <word> [--reason <text>]             ║")
                println("║  /negativeThesaurus remove <word>                           ║")
                println("║  /negativeThesaurus list                                    ║")
                println("║  /negativeThesaurus check <word>                            ║")
                println("║  /negativeThesaurus flush                                   ║")
                println("║                                                              ║")
                println("║  SPECIMEN LOADER                                             ║")
                println("║  /loadSpecimen <json>        Batch-load full cave blueprint  ║")
                println("║    Supports: nodes, rules, lobes, connections, lobe_nodes,   ║")
                println("║    verbs, verb_classes, synonyms, inhibitions, pins          ║")
                println("║                                                              ║")
                println("║  /help                      Show this scroll                ║")
                println("╚══════════════════════════════════════════════════════════════╝")

            elseif !isnothing(m_mission)
                # GRUG: /mission - main input command. Handles text AND image binary.
                mission_text = String(m_mission.captures[1])
                process_mission(mission_text)

            elseif !isnothing(m_wrong)
                # GRUG: /wrong - user says last response was wrong.
                # Every node that voted gets a coinflip strength penalty.
                # Nodes that hit 0 become grave (negative reinforcement markers).
                voter_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_VOTER_IDS)
                end

                if isempty(voter_ids)
                    println("⚠  /wrong: No previous voters to penalize. Did you run /mission first?")
                else
                    apply_wrong_feedback!(voter_ids)
                    println("❌  /wrong applied. $(length(voter_ids)) voter(s) penalized via coinflip.")
                end

            elseif !isnothing(m_explicit)
                cmd, id, mission_text = m_explicit.captures
                add_message_to_history!("User", mission_text, false)
                
                println("--> Grug forcing command override for [$id]...")
                override_vote = cast_explicit_vote(String(cmd), String(id))
                
                output = ephemeral_aiml_orchestrator(String(mission_text), [override_vote])
                println("\n🤖 AIML [Targeted Override]:\n$output")
                add_message_to_history!("System", output, false)
                
            elseif !isnothing(m_grow)
                # GRUG: /grow - plant new nodes from JSON packet.
                # Regex pre-screens JSON for image binary patterns before parsing.
                json_text = String(m_grow.captures[1])
                add_message_to_history!("System", "/grow [JSON MAP PACKET]", false)
                
                println("--> Grug unpacking JSON node seeds...")

                # GRUG: Check if the grow packet contains image binary data.
                # If pattern field has image binary, flag it as image node automatically.
                is_img, img_sig = maybe_convert_image_input(json_text)
                if is_img
                    println("[GROW] 🖼  Image binary detected in /grow packet. Image node path active.")
                    # GRUG: The JSON node grower in Engine.jl handles is_image_node flag.
                    # Image binary in pattern will be stored as SDF signal.
                    # Caller must set "is_image_node": true in the JSON for this to work.
                end

                new_ids = grow_nodes_from_packet(json_text)
                
                success_msg = "🌱 Tribe expanded! Grug planted $(length(new_ids)) new nodes: [$(join(new_ids, ", "))]"
                println(success_msg)
                add_message_to_history!("System", success_msg, false)

            elseif !isnothing(m_rule)
                # GRUG: /addRule - add a stochastic orchestration rule.
                # Optional [prob=X.XX] suffix sets fire probability (default 1.0).
                rule_text = String(m_rule.captures[1])
                println("⚙️ ", add_orchestration_rule!(rule_text))

            elseif !isnothing(m_pin)
                pin_text = String(m_pin.captures[1])
                add_message_to_history!("User_Pinned", pin_text, true)
                println("📌 Grug pinned text to Memory Wall!")

            elseif !isnothing(m_nodes)
                # GRUG: /nodes - show full node map status (strength, neighbors, graves, etc.)
                println(get_node_status_summary())

            elseif !isnothing(m_status)
                # GRUG: /status - comprehensive system health snapshot.
                # Shows: engine, chatter, lobes, brainstem, thesaurus gate, memory estimate.
                cs  = ChatterMode.get_chatter_status()
                bs  = BrainStem.get_brainstem_status()
                lobe_ids_now = Lobe.get_lobe_ids()
                total_lobe_nodes = sum(Lobe.get_lobe_node_count(lid) for lid in lobe_ids_now; init=0)

                # GRUG: Rough memory estimate. Each node ~= 1KB (pattern + signal + metadata).
                # Hopfield cache ~= 200 bytes per entry. Message history ~= 500 bytes per msg.
                est_node_mem_kb    = length(NODE_MAP) * 1
                est_hopfield_mem_b = length(HOPFIELD_CACHE) * 200
                est_history_mem_b  = length(MESSAGE_HISTORY) * 500
                est_total_kb       = est_node_mem_kb + div(est_hopfield_mem_b + est_history_mem_b, 1024)

                # GRUG: Find top-firing lobe (most wins)
                top_lobe = isempty(lobe_ids_now) ? "none" : begin
                    best_lid = lobe_ids_now[1]
                    best_fc  = 0
                    for lid in lobe_ids_now
                        rec = Lobe.get_lobe(lid)
                        if rec.fire_count > best_fc
                            best_fc  = rec.fire_count
                            best_lid = lid
                        end
                    end
                    "$(best_lid) ($(best_fc) fires)"
                end

                println("╔══════════════════════════════════════════════════╗")
                println("║              GRUGBOT SYSTEM STATUS               ║")
                println("╠══════════════════════════════════════════════════╣")
                println("║  ENGINE                                          ║")
                println("  Nodes in cave   : $(length(NODE_MAP))")
                println("  Hopfield cache  : $(length(HOPFIELD_CACHE)) entries")
                println("  Memory messages : $(length(MESSAGE_HISTORY))")
                println("  Est. memory use : ~$(est_total_kb) KB")
                println("  Current arousal : $(round(EyeSystem.get_arousal(), digits=3))")
                println("  Last input ago  : $(round(time() - LAST_INPUT_TIME[], digits=1))s")
                println("║  LOBES                                           ║")
                println("  Lobes registered: $(length(lobe_ids_now))")
                println("  Nodes in lobes  : $(total_lobe_nodes)")
                println("  Top lobe (fires): $(top_lobe)")
                println("║  BRAINSTEM                                       ║")
                println("  Dispatches run  : $(bs["dispatch_count"])")
                println("  Last winner     : $(isempty(bs["last_winner_id"]) ? "none" : bs["last_winner_id"])")
                println("  Propagations    : $(bs["propagation_events"])")
                println("  Is dispatching  : $(bs["is_dispatching"])")
                println("║  CHATTER                                         ║")
                println("  Chatter running : $(cs.is_running)")
                println("  Input queue     : $(cs.queue_depth) pending")
                println("  Sessions run    : $(cs.sessions_run)")
                println("╚══════════════════════════════════════════════════╝")

            elseif !isnothing(m_arousal)
                # GRUG: /arousal - manually set eye system arousal level [0.0, 1.0]
                arousal_val = tryparse(Float64, m_arousal.captures[1])
                if isnothing(arousal_val)
                    error("!!! FATAL: /arousal value is not a valid float! !!!")
                end
                EyeSystem.set_arousal!(arousal_val)
                println("👁  Arousal set to $(round(arousal_val, digits=3)). Eye system updated.")

            elseif !isnothing(m_addverb)
                # GRUG: /addVerb <verb> <class> - add a new verb to a relation class at runtime.
                # User must create the class first with /addRelationClass if it is new.
                # Example: /addVerb triggers causal
                verb_word  = String(m_addverb.captures[1])
                verb_class = String(m_addverb.captures[2])
                SemanticVerbs.add_verb!(verb_word, verb_class)
                println("🔧 Verb '$(verb_word)' added to class '$(verb_class)'. Active immediately.")

            elseif !isnothing(m_addrelclass)
                # GRUG: /addRelationClass <name> - create a new verb class bucket.
                # After this, user can /addVerb <word> <name> to populate it.
                # Example: /addRelationClass epistemic
                class_name = String(m_addrelclass.captures[1])
                SemanticVerbs.add_relation_class!(class_name)
                println("🗂  Relation class '$(class_name)' created. Use /addVerb to populate.")

            elseif !isnothing(m_addsynonym)
                # GRUG: /addSynonym <canonical> <alias> - register a synonym normalization.
                # From now on, <alias> in user input is treated as <canonical> before triple extraction.
                # Canonical verb must already exist in a relation class!
                # Example: /addSynonym causes triggers
                canonical_verb = String(m_addsynonym.captures[1])
                alias_verb     = String(m_addsynonym.captures[2])
                SemanticVerbs.add_synonym!(canonical_verb, alias_verb)
                println("📖 Synonym registered: '$(alias_verb)' → '$(canonical_verb)'. Normalization active.")

            elseif !isnothing(m_listverbs)
                # GRUG: /listVerbs - show all registered verb classes and their verbs + synonyms.
                classes   = SemanticVerbs.get_relation_classes()
                synonyms  = SemanticVerbs.get_synonym_map()
                println("=== SEMANTIC VERB REGISTRY ===")
                for cls in classes
                    verbs = SemanticVerbs.get_verbs_in_class(cls)
                    println("  [$(cls)]: $(join(sort(collect(verbs)), ", "))")
                end
                if !isempty(synonyms)
                    println("  --- Synonyms ---")
                    for (alias, canon) in sort(collect(synonyms))
                        println("    $(alias) → $(canon)")
                    end
                else
                    println("  (no synonyms registered)")
                end

            elseif !isnothing(m_newlobe)
                # GRUG: /newLobe <id> <subject> - create a new subject partition.
                # Example: /newLobe language "natural language processing"
                lobe_id_new  = String(m_newlobe.captures[1])
                lobe_subject = String(strip(m_newlobe.captures[2]))
                Lobe.create_lobe!(lobe_id_new, lobe_subject)
                println("\U0001f9e0 Lobe '$(lobe_id_new)' created for subject: '$(lobe_subject)'. Cap: $(Lobe.LOBE_NODE_CAP) nodes.")

            elseif !isnothing(m_connectlobes)
                # GRUG: /connectLobes <id_a> <id_b> - link two lobes bidirectionally.
                # BrainStem uses connections for lateral signal routing.
                # Example: /connectLobes language emotion
                lobe_a = String(m_connectlobes.captures[1])
                lobe_b = String(m_connectlobes.captures[2])
                Lobe.connect_lobes!(lobe_a, lobe_b)
                println("\U0001f517 Lobes '$(lobe_a)' \u2194 '$(lobe_b)' connected.")

            elseif !isnothing(m_lobegrow)
                # GRUG: /lobeGrow <lobe_id> <json_packet> - grow a node directly into a lobe.
                # JSON must have: pattern, action_packet. Optional: data, drop_table.
                # Example: /lobeGrow language {"pattern":"hello","action_packet":"{...}"}
                target_lobe_id = String(m_lobegrow.captures[1])
                lobe_json      = String(strip(m_lobegrow.captures[2]))
                if !haskey(Lobe.LOBE_REGISTRY, target_lobe_id)
                    println("\u26a0  /lobeGrow: Lobe '$(target_lobe_id)' does not exist. Use /newLobe first.")
                elseif Lobe.lobe_is_full(target_lobe_id)
                    println("!!! LOBE FULL: Lobe '$(target_lobe_id)' has reached its node cap. Cannot grow more nodes! Use /newLobe to add a new lobe. !!!")
                else
                    try
                        packet = JSON.parse(lobe_json)
                        if !haskey(packet, "pattern") || !haskey(packet, "action_packet")
                            println("\u26a0  /lobeGrow: JSON must have 'pattern' and 'action_packet' fields.")
                        else
                            json_data  = Dict{String,Any}(string(k) => v for (k,v) in get(packet, "data", Dict()))
                            drop_table = haskey(packet, "drop_table") && packet["drop_table"] isa AbstractVector ?
                                         String[string(x) for x in packet["drop_table"]] : String[]
                            new_id = create_node(
                                packet["pattern"],
                                packet["action_packet"],
                                json_data,
                                drop_table
                            )
                            Lobe.add_node_to_lobe!(target_lobe_id, new_id)
                            # GRUG: Convert JSON data and drop table into lobe's hash table chunks.
                            # Flat dict and flat vector become O(1) pattern-activated storage.
                            json_count = LobeTable.json_to_table_chunk!(target_lobe_id, new_id, json_data)
                            drop_count = LobeTable.drop_table_to_chunk!(target_lobe_id, new_id, drop_table)
                            println("\U0001f331 Node '$(new_id)' grown into lobe '$(target_lobe_id)'. json_fields=$json_count drop_links=$drop_count")
                        end
                    catch e
                        ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" :
                              e isa Lobe.LobeError ? " [ctx: $(e.context)]" : ""
                        println("!!! ERROR in /lobeGrow: $e$ctx !!!")
                    end
                end

            elseif !isnothing(m_lobes)
                # GRUG: /lobes - uses get_lobe_status_summary() which includes O(1) reverse index count.
                println(Lobe.get_lobe_status_summary())

            elseif !isnothing(m_tablestatus)
                # GRUG: /tableStatus <lobe_id> - show hash table chunk sizes for a lobe.
                # Shows nodes/json/drop/hopfield/meta chunk entry counts.
                ts_lobe_id = String(m_tablestatus.captures[1])
                try
                    if !LobeTable.table_exists(ts_lobe_id)
                        println("\u26a0  /tableStatus: No table found for lobe '$(ts_lobe_id)'. Does the lobe exist?")
                    else
                        println(LobeTable.get_table_summary(ts_lobe_id))
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableStatus: $e$ctx !!!")
                end

            elseif !isnothing(m_tablematch)
                # GRUG: /tableMatch <lobe_id> <chunk> <pattern> - pattern-activate entries.
                # chunk must be one of: nodes, json, drop, hopfield, meta
                # pattern is matched as token mode (any token in pattern activates key)
                # Example: /tableMatch lang json node_0 -> all json fields for node_0
                # Example: /tableMatch lang drop node_0 -> all drop neighbors of node_0
                tm_lobe_id  = String(m_tablematch.captures[1])
                tm_chunk    = String(strip(m_tablematch.captures[2]))
                tm_pattern  = String(strip(m_tablematch.captures[3]))
                try
                    if !LobeTable.table_exists(tm_lobe_id)
                        println("\u26a0  /tableMatch: No table found for lobe '$(tm_lobe_id)'.")
                    else
                        # GRUG: Use prefix mode when pattern looks like a node_id, token otherwise
                        match_mode = startswith(tm_pattern, "node_") ? :prefix : :token
                        hits = LobeTable.table_match(tm_lobe_id, tm_chunk, tm_pattern, mode=match_mode)
                        if isempty(hits)
                            println("[tableMatch] No entries matched '$(tm_pattern)' in chunk '$(tm_chunk)' of lobe '$(tm_lobe_id)'.")
                        else
                            println("[tableMatch] $(length(hits)) hits in lobe='$(tm_lobe_id)' chunk='$(tm_chunk)' pattern='$(tm_pattern)':")
                            for (k, v) in sort(collect(hits), by=x->x[1])
                                println("  $(k) -> $(v)")
                            end
                        end
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableMatch: $e$ctx !!!")
                end

            elseif !isnothing(m_thesaurus)
                # GRUG: /thesaurus <input1> | <input2> - dimensional similarity comparison.
                # Optional context lists after :: separators (comma-separated).
                # Examples:
                #   /thesaurus happy | joyful
                #   /thesaurus machine learning | artificial intelligence
                #   /thesaurus dog | canine :: pet,animal :: domesticated,beast
                raw1 = String(strip(m_thesaurus.captures[1]))
                raw2 = String(strip(m_thesaurus.captures[2]))
                # GRUG: Parse optional context lists after :: separator in raw2
                ctx1 = String[]
                ctx2 = String[]
                if occursin("::", raw2)
                    parts = split(raw2, "::")
                    raw2  = String(strip(parts[1]))
                    if length(parts) >= 2
                        ctx1 = filter(!isempty, map(c -> String(strip(c)), split(parts[2], ",")))
                    end
                    if length(parts) >= 3
                        ctx2 = filter(!isempty, map(c -> String(strip(c)), split(parts[3], ",")))
                    end
                end
                try
                    result = Thesaurus.thesaurus_compare(raw1, raw2; context1=ctx1, context2=ctx2)
                    intensity = Thesaurus.format_thesaurus_intensity(result.overall)
                    # GRUG: Show seed synonyms for single-word inputs so operator sees what gate knows
                    syns1 = !occursin(" ", raw1) ? Thesaurus.get_seed_synonyms(raw1) : String[]
                    syns2 = !occursin(" ", raw2) ? Thesaurus.get_seed_synonyms(raw2) : String[]
                    syn1_str = isempty(syns1) ? "" : "  → seeds: $(join(first(syns1, 4), ", "))"
                    syn2_str = isempty(syns2) ? "" : "  → seeds: $(join(first(syns2, 4), ", "))"
                    println("\n\U0001f50d THESAURUS COMPARISON")
                    println("  Input 1  : \"$(raw1)\"$(syn1_str)")
                    println("  Input 2  : \"$(raw2)\"$(syn2_str)")
                    println("  Type     : $(result.match_type)")
                    println("  \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
                    println("  Overall  : $(round(result.overall * 100, digits=1))%  [$(intensity)]")
                    println("  Semantic : $(round(result.semantic * 100, digits=1))%")
                    println("  Context  : $(round(result.contextual * 100, digits=1))%")
                    println("  Assoc    : $(round(result.associative * 100, digits=1))%")
                    println("  Confid.  : $(round(result.confidence * 100, digits=1))%")
                    if !isempty(ctx1)
                        println("  Ctx1     : $(join(ctx1, ", "))")
                    end
                    if !isempty(ctx2)
                        println("  Ctx2     : $(join(ctx2, ", "))")
                    end
                    println()
                catch e
                    # GRUG: Surface full error context from typed exceptions, not just message!
                    if e isa Thesaurus.ThesaurusError
                        println("!!! THESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! THESAURUS ERROR: $e !!!")
                    end
                end

            elseif !isnothing(m_neginhibit)
                # GRUG: /negativeThesaurus add <word> [--reason <text>]
                # Register a word/phrase as inhibited. Filtered from input before scanning.
                inhibit_word   = String(strip(m_neginhibit.captures[1]))
                inhibit_reason = isnothing(m_neginhibit.captures[2]) ? "" : String(strip(m_neginhibit.captures[2]))
                try
                    InputQueue.add_inhibition!(inhibit_word; reason=inhibit_reason)
                    println("🚫 Inhibition registered: '$(inhibit_word)'" * (isempty(inhibit_reason) ? "" : "  reason: $(inhibit_reason)"))
                    println("   NegativeThesaurus size: $(InputQueue.inhibition_count()) / $(InputQueue.NEG_THESAURUS_MAX)")
                catch e
                    if e isa InputQueue.InputQueueError
                        println("!!! NEGATIVETHESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                    end
                end

            elseif !isnothing(m_negremove)
                # GRUG: /negativeThesaurus remove <word>
                # Remove a word from the inhibition list.
                remove_word = String(strip(m_negremove.captures[1]))
                try
                    removed = InputQueue.remove_inhibition!(remove_word)
                    if removed
                        println("✅ Inhibition removed: '$(remove_word)'. Word no longer blocked.")
                    else
                        println("⚠️  '$(remove_word)' was not in NegativeThesaurus. Nothing changed.")
                    end
                catch e
                    println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                end

            elseif !isnothing(m_neglist)
                # GRUG: /negativeThesaurus list
                # Show all currently inhibited words with reasons and timestamps.
                entries = InputQueue.list_inhibitions()
                if isempty(entries)
                    println("📋 NegativeThesaurus is empty. No words currently inhibited.")
                else
                    println("📋 NegativeThesaurus — $(length(entries)) inhibited word(s):")
                    for e in entries
                        age_s   = round(time() - e.added_at, digits=0)
                        reason  = isempty(e.reason) ? "(no reason)" : e.reason
                        println("   🚫 '$(e.word)'   reason: $(reason)   added: $(age_s)s ago")
                    end
                end

            elseif !isnothing(m_negcheck)
                # GRUG: /negativeThesaurus check <word>
                # Quick check if a word is inhibited or not.
                check_word = String(strip(m_negcheck.captures[1]))
                if InputQueue.is_inhibited(check_word)
                    println("🚫 '$(check_word)' IS inhibited in NegativeThesaurus.")
                else
                    println("✅ '$(check_word)' is NOT inhibited. Word passes filter freely.")
                end

            elseif !isnothing(m_negflush)
                # GRUG: /negativeThesaurus flush
                # Remove ALL inhibitions at once. Destructive but useful for resets.
                old_count = InputQueue.inhibition_count()
                lock(InputQueue._NEG_LOCK) do
                    empty!(InputQueue._NEG_THESAURUS)
                end
                println("🧹 NegativeThesaurus flushed. Removed $(old_count) inhibition(s). Cave filter is now empty.")

            elseif !isnothing(m_loadspecimen)
                # GRUG: /loadSpecimen - batch-load a full cave blueprint from JSON.
                # Validates EVERYTHING before committing ANYTHING. Atomic specimen loading.
                # Supports: nodes, rules, lobes, connections, lobe_nodes, verbs,
                # verb_classes, synonyms, inhibitions, pins.
                specimen_json = String(m_loadspecimen.captures[1])
                add_message_to_history!("System", "/loadSpecimen [SPECIMEN BLUEPRINT]", false)

                println("--> Grug reading specimen blueprint scroll...")
                result_summary = load_specimen_from_json!(specimen_json)
                println("\n$result_summary")
                add_message_to_history!("System", result_summary, false)

            else
                error("!!! FATAL: Grug command bad format. Use /help to see all valid commands. !!!")
            end
            
        catch e
            println("!!! SYSTEM ERROR: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
        end
    end
end

run_cli()

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: BEHAVIORAL LAYER (MAIN.JL - UPDATED)
#
# 1. COGNITIVE SUPERPOSITION (MULTI-VOTE ORCHESTRATION):
# The routing engine abandons "winner-takes-all" Softmax weighting in favor of a 
# deterministic/stochastic superposition model. The maximum confidence threshold 
# mathematically bounds the sure_votes array (guaranteed truths), while ALL 
# remaining valid votes are subjected to an iterative 50/50 @coinflip to simulate 
# stochastic side-feature consideration (unsure_votes).
#
# 2. STOCHASTIC AIML RULES:
# Each orchestration rule now carries a fire_probability [0.0, 1.0]. At generation
# time, rules roll against their probability before being injected into the JIT
# payload. This produces natural, non-robotic variation in orchestrator output.
# Rules with no [prob=X] suffix default to 1.0 (always fire, backward compatible).
#
# 3. /WRONG FEEDBACK LOOP:
# /wrong triggers apply_wrong_feedback!() on all node IDs from the last /mission.
# Each voter does a coinflip strength penalty. Nodes reaching strength=0 become
# GRAVE markers used as negative reinforcement anchors during future generative phases.
#
# 4. IMAGE BINARY ROUTING:
# /mission and /grow pre-screen input via ImageSDF.detect_image_binary() regex.
# Detected image binary is decoded, JIT-converted to SDFParams, processed through
# EyeSystem (edge blur + arousal-gated attention cutout), jittered, and converted
# to a flat signal vector for PatternScanner-compatible image node matching.
#
# 5. IDLE MODE: CHATTER + PHAGY COINFLIP:
# Idle detection runs between CLI prompts via maybe_run_idle(). When the cave has
# been quiet for ~30s, a 50/50 coinflip fires. HEADS triggers a chatter session:
# 100-800 node clones gossip and exchange patterns. TAILS triggers a phagy cycle:
# one of six maintenance automata runs (ORPHAN_PRUNER, STRENGTH_DECAYER,
# GRAVE_RECYCLER, CACHE_VALIDATOR, DROP_TABLE_COMPACT, RULE_PRUNER). Only ONE
# automaton runs per phagy cycle to preserve Big-O safety. User input arriving
# during chatter is queued and drained after session completion. Phagy is
# synchronous and completes before the next prompt, so no queuing is needed.
#
# 6. DROP TABLE CO-ACTIVATION:
# scan_and_expand() replaces direct scan_specimens() calls for text missions.
# Primary scan results are expanded with drop-table neighbor nodes, modeling
# associative memory co-activation.
#
# 7. BIG-O RESPONSE TIME TRACKING:
# process_mission() measures wall-clock time for each full scan+vote+generate cycle
# and records it on all participating nodes via record_response_time!(). Nodes 
# with slow average times are automatically graved by the Engine ledger system.
#
# 8. SEMANTIC VERB REGISTRY CLI INTEGRATION:
# Four CLI commands expose the SemanticVerbs live registry to the operator at runtime:
#   /addVerb <verb> <class>           — adds a verb to an existing relation class
#   /addRelationClass <name>          — creates a new verb class bucket
#   /addSynonym <canonical> <alias>   — registers alias→canonical normalization
#   /listVerbs                        — dumps all classes, verbs, and synonyms
# All mutations take effect immediately on the next /mission call because
# extract_relational_triples() calls get_all_verbs() and normalize_synonyms()
# on every invocation. Errors from bad class names or duplicate entries are
# surfaced loudly through the standard CLI catch block with a printed backtrace.
#
# 9. ACTION+TONE AROUSAL PRE-SET IN BEHAVIORAL LAYER:
# process_mission() invokes ActionTonePredictor.predict_action_tone() a second
# time (first invocation is inside scan_specimens for confidence weighting) to
# apply an EyeSystem arousal nudge before the scan. The two invocations are
# intentionally orthogonal: the engine-layer call modulates per-node confidence
# multipliers (scan concern); the behavioral-layer call here modulates the global
# arousal level (EyeSystem concern). apply_prediction_to_arousal!() is decoupled
# from EyeSystem via function handle injection, keeping the predictor independently
# testable. Both calls are wrapped in non-fatal try/catch: a prediction failure
# never blocks the mission scan or response generation.
#
# 10. LOBE-AWARE PREFRONTAL CORTEX (AIML CONTEXT):
# extract_lobe_aware_context(votes) maps all votes to their owning lobes,
# building a cross-domain context string injected into the AIML payload via
# the {LOBE_CONTEXT} placeholder. This ensures the prefrontal cortex (AIML)
# has global awareness of which subject domains are active for the current
# query, preventing domain isolation where only one lobe's knowledge would
# be visible. Active lobe names, node counts, and sample patterns are
# included so orchestration rules can reason across science ↔ philosophy ↔
# reasoning boundaries. Errors in lobe context extraction are non-fatal
# (logged via @warn, fallback to empty context string).
#
# 11. NEGATIVE THESAURUS (INHIBITION FILTER):
# Five CLI commands expose the InputQueue.NegativeThesaurus to the operator:
#   /negativeThesaurus add <word> [--reason <text>]  — register inhibition
#   /negativeThesaurus remove <word>                 — deregister
#   /negativeThesaurus list                          — show all entries
#   /negativeThesaurus check <word>                  — test if inhibited
#   /negativeThesaurus flush                         — clear all entries
# Inhibited words are filtered from input tokens before pattern scanning,
# acting as a pre-scan suppression layer. O(1) lookup via Dict{String,NegEntry}.
#
# 12. SPECIMEN LOADER (BATCH CAVE BLUEPRINT):
# /loadSpecimen accepts a single JSON object containing up to 10 optional sections:
#   nodes, rules, lobes, connections, lobe_nodes, verbs, verb_classes,
#   synonyms, inhibitions, pins.
# Processing is ATOMIC: the entire JSON is validated BEFORE any changes are
# committed. If any section fails validation, ZERO changes are made. This
# prevents half-seeded caves where nodes exist but their lobes or verb
# classes are missing. Commit order is deliberate: verb_classes → verbs →
# synonyms → lobes → connections → nodes → lobe_nodes → rules →
# inhibitions → pins. This ensures downstream sections can reference
# upstream entities (e.g. verbs reference classes, lobe_nodes reference
# lobes). Each commit step is individually wrapped in try/catch with FATAL
# error reporting — validation should prevent all commit errors, but Grug
# is paranoid and does not trust silent success. The result is a formatted
# summary table showing per-section counts and created node IDs.
# ==============================================================================