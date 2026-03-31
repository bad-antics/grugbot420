# ActionTonePredictor.jl
# ==============================================================================
# GRUG: This is the reflex prediction cave. Fires BEFORE the vote pool assembles.
#
# NOT token prediction. NOT next-word guessing. NOT an LLM.
# THIS reads raw input structure and predicts:
#   1. What ACTION the user intends (ASSERT / QUERY / COMMAND / NEGATE /
#      SPECULATE / ESCALATE)
#   2. What TONE they carry (HOSTILE / CURIOUS / DECLARATIVE / URGENT /
#      NEUTRAL / REFLECTIVE)
#
# GRUG: Two outputs from this module feed back into the cave:
#   - arousal_nudge  → applied to EyeSystem BEFORE scan runs
#   - action_weight  → multiplied into node confidence scores INSIDE scan_specimens
#
# Neither output is a vote. Neither output is mandatory. If prediction fails,
# the cave scans normally without modulation. No silent failure — failure is
# logged as @warn and execution continues.
#
# INCOMPLETE CAUSAL CHAIN DETECTION:
# If a relational verb appears at the tail of input with no object token
# following it (e.g. "fire causes"), the chain is flagged as dangling.
# This nudges the predicted action toward SPECULATE — the system is being asked
# to complete a partial thought.
# ==============================================================================

module ActionTonePredictor

using Random

export ActionFamily, ToneFamily, PredictionResult,
       predict_action_tone, apply_prediction_to_arousal!,
       get_action_weight_multiplier, format_prediction_summary

# ==============================================================================
# ENUM TYPES
# ==============================================================================

# GRUG: Action families — what is the user trying to DO?
@enum ActionFamily begin
    ACTION_ASSERT     # "X is Y", "X causes Y" — declarative claim, stating a fact
    ACTION_QUERY      # "what", "why", "how", "?" — requesting information
    ACTION_COMMAND    # "run", "stop", "build" — directive, imperative structure
    ACTION_NEGATE     # "not", "never", "wrong" — contradiction or rejection
    ACTION_SPECULATE  # "maybe", "could", "might" — epistemic hedge, incomplete chain
    ACTION_ESCALATE   # ALL CAPS, "!!!", "critical" — emotional spike, urgency burst
end

# GRUG: Tone families — HOW does the user sound while doing it?
@enum ToneFamily begin
    TONE_HOSTILE      # Aggression markers: "wrong", "broken", "garbage", "stupid"
    TONE_CURIOUS      # Exploratory: question words, open-ended framing
    TONE_DECLARATIVE  # Flat assertion, no emotional loading
    TONE_URGENT       # Time pressure: "now", "immediately", "critical", "asap"
    TONE_NEUTRAL      # No strong markers detected — baseline
    TONE_REFLECTIVE   # Hedged language: "i think", "perhaps", "it seems"
end

# GRUG: Full prediction result. Carry this through the cave as a pre-tuning packet.
# It is immutable — created once per input, read many times during scan.
struct PredictionResult
    action_family    ::ActionFamily
    tone_family      ::ToneFamily
    confidence       ::Float64   # Prediction confidence [0.0, 1.0]
    incomplete_chain ::Bool      # True if a dangling relational verb was detected
    dangling_verb    ::Union{String, Nothing}  # Which verb was left dangling, if any
    arousal_nudge    ::Float64   # Signed delta [-1.0, 1.0] to add to current arousal
    action_weight    ::Float64   # Confidence multiplier for aligned nodes [0.5, 2.0]
    timestamp        ::Float64   # Unix timestamp of prediction (time())
end

# ==============================================================================
# LEXICONS
# GRUG: Surface-level token scoring tables. These are the cave's smell sensors.
# Strong signal = clear action/tone. Weak/absent signal = default to ASSERT/NEUTRAL.
# ==============================================================================

# GRUG: Query markers — tokens that smell like information-seeking
const QUERY_MARKERS = Set([
    "what", "why", "how", "when", "where", "who", "which",
    "explain", "describe", "tell", "show", "define", "clarify"
])

# GRUG: Command markers — imperative/directive tokens
const COMMAND_MARKERS = Set([
    "do", "run", "stop", "start", "make", "create", "build", "delete",
    "remove", "add", "set", "get", "list", "give", "send", "go",
    "generate", "write", "find", "search", "update", "reset", "load"
])

# GRUG: Negation markers — contradiction and rejection tokens
const NEGATE_MARKERS = Set([
    "not", "never", "no", "wrong", "incorrect", "false", "deny",
    "negate", "contradict", "disagree", "refuse", "reject", "invalid"
])

# GRUG: Speculative markers — epistemic hedging tokens
const SPECULATE_MARKERS = Set([
    "maybe", "perhaps", "possibly", "might", "could", "would",
    "probably", "likely", "unlikely", "assume", "hypothetically",
    "suppose", "imagine", "theoretically", "roughly", "approximately"
])

# GRUG: Hostile tone markers — frustration and aggression tokens
const HOSTILE_MARKERS = Set([
    "wrong", "stupid", "useless", "broken", "garbage", "terrible",
    "awful", "horrible", "idiot", "dumb", "bad", "fail", "failed",
    "trash", "ridiculous", "absurd", "pathetic"
])

# GRUG: Urgent tone markers — time pressure and critical framing tokens
const URGENT_MARKERS = Set([
    "now", "immediately", "urgent", "critical", "emergency", "asap",
    "quickly", "fast", "hurry", "instantly", "priority", "crucial",
    "vital", "important", "deadline", "must"
])

# GRUG: Reflective tone markers — hedged, thoughtful language tokens
const REFLECTIVE_MARKERS = Set([
    "interesting", "wonder", "curious", "consider", "reflect",
    "ponder", "notice", "observe", "realize", "seems", "appears",
    "suggests", "implies", "indicates"
])

# GRUG: Multi-word reflective phrase markers. These scan the full lowercased input
# string, not token-by-token. More expensive but catches compound hedges.
const REFLECTIVE_PHRASES = [
    "i think", "i believe", "it seems", "i wonder",
    "one might", "it appears", "it suggests"
]

# ==============================================================================
# MODULATION TABLES
# GRUG: Numbers that turn prediction results into cave pre-tuning values.
# ==============================================================================

# GRUG: Arousal nudge per tone. Positive = more peripheral, Negative = more foveal.
# HOSTILE and URGENT push arousal up — the cave needs wider attention.
# REFLECTIVE and DECLARATIVE pull arousal down — narrow focus, deliberate scan.
const TONE_AROUSAL_NUDGE = Dict{ToneFamily, Float64}(
    TONE_HOSTILE     => +0.35,
    TONE_URGENT      => +0.25,
    TONE_CURIOUS     =>  0.0,
    TONE_DECLARATIVE => -0.10,
    TONE_NEUTRAL     =>  0.0,
    TONE_REFLECTIVE  => -0.15
)

# GRUG: Base confidence weight multiplier per predicted action family.
# Applied to aligned node confidence scores in scan_specimens.
# ESCALATE is highest — cave must respond fast when user is spiking.
# SPECULATE is lowest — uncertain input deserves less aggressive pre-weighting.
const ACTION_WEIGHT_TABLE = Dict{ActionFamily, Float64}(
    ACTION_ASSERT    => 1.4,
    ACTION_QUERY     => 1.6,
    ACTION_COMMAND   => 1.5,
    ACTION_NEGATE    => 1.3,
    ACTION_SPECULATE => 1.2,
    ACTION_ESCALATE  => 1.7
)

# ==============================================================================
# INCOMPLETE CAUSAL CHAIN DETECTOR
# ==============================================================================

"""
    detect_incomplete_chain(tokens, all_verbs) -> (Bool, Union{String,Nothing})

Scan the last 1-2 tokens for a relational verb with no object following it.
A verb at end-of-input with only punctuation (or nothing) after it is a
dangling causal chain — the user may be mid-thought or asking the system
to complete the structure.

Returns `(true, dangling_verb)` if dangling, `(false, nothing)` otherwise.
"""
function detect_incomplete_chain(
    tokens   ::Vector{String},
    all_verbs::Set{String}
)::Tuple{Bool, Union{String, Nothing}}

    # GRUG: Need at least subject + verb to call it a chain. Single token = nothing to dangle.
    if length(tokens) < 2
        return (false, nothing)
    end

    n = length(tokens)
    for look_back in [1, 2]
        idx = n - look_back + 1
        if idx >= 1 && tokens[idx] in all_verbs
            # GRUG: Look at everything after the verb. Strip punctuation-only tokens.
            # If nothing meaningful follows, the chain is dangling.
            tail_tokens = tokens[idx+1:end]
            non_punct   = filter(t -> !occursin(r"^[,;.!?:\s]+$", t), tail_tokens)
            if isempty(non_punct)
                return (true, tokens[idx])
            end
        end
    end

    return (false, nothing)
end

# ==============================================================================
# CORE PREDICTOR
# ==============================================================================

"""
    predict_action_tone(input_text, all_verbs) -> PredictionResult

Main entry point. Scores input text against all action and tone lexicons,
detects incomplete causal chains, and returns a `PredictionResult` carrying
the predicted action family, tone family, confidence, arousal nudge, and
confidence weight multiplier.

`all_verbs` should come from `SemanticVerbs.get_all_verbs()` so the live
runtime verb registry is used for chain detection.

This function does NOT modify any global state. It is pure input -> output.
Callers apply the results via `apply_prediction_to_arousal!` and
`get_action_weight_multiplier`.
"""
function predict_action_tone(
    input_text::String,
    all_verbs ::Set{String}
)::PredictionResult

    if isempty(strip(input_text))
        error("!!! FATAL: ActionTonePredictor cannot predict on empty input! !!!")
    end

    tokens_raw   = split(strip(input_text))
    tokens_low   = [lowercase(t) for t in tokens_raw]

    # GRUG: Strip trailing punctuation from tokens for clean lexicon lookup.
    # "wrong!" should hit HOSTILE_MARKERS. "what?" should hit QUERY_MARKERS.
    tokens_clean = [replace(t, r"[,;.!?:]+$" => "") for t in tokens_low]
    tokens_clean = filter(!isempty, tokens_clean)

    if isempty(tokens_clean)
        error("!!! FATAL: ActionTonePredictor: all tokens vanished after punctuation strip! !!!")
    end

    # ------------------------------------------------------------------
    # STEP 1: Score action families
    # ------------------------------------------------------------------
    action_scores = Dict{ActionFamily, Float64}(
        ACTION_ASSERT    => 0.0,
        ACTION_QUERY     => 0.0,
        ACTION_COMMAND   => 0.0,
        ACTION_NEGATE    => 0.0,
        ACTION_SPECULATE => 0.0,
        ACTION_ESCALATE  => 0.0
    )

    # GRUG: "?" is the strongest query signal. Check raw input, not tokens.
    if contains(input_text, "?")
        action_scores[ACTION_QUERY] += 1.5
    end

    # GRUG: ALL CAPS words (3+ chars, starts with letter) = escalation signal.
    # isletter() used because isalpha() does not exist in Julia.
    caps_words = count(
        t -> length(t) >= 3 && t == uppercase(t) && isletter(t[1]),
        tokens_raw
    )
    if caps_words > 0
        action_scores[ACTION_ESCALATE] += Float64(caps_words) * 0.8
    end

    # GRUG: Each exclamation mark adds escalation weight.
    excl_count = count(c -> c == '!', input_text)
    if excl_count > 0
        action_scores[ACTION_ESCALATE] += Float64(excl_count) * 0.5
    end

    # GRUG: Per-token lexicon scoring.
    for tok in tokens_clean
        tok in QUERY_MARKERS     && (action_scores[ACTION_QUERY]     += 1.0)
        tok in COMMAND_MARKERS   && (action_scores[ACTION_COMMAND]   += 1.0)
        tok in NEGATE_MARKERS    && (action_scores[ACTION_NEGATE]    += 1.0)
        tok in SPECULATE_MARKERS && (action_scores[ACTION_SPECULATE] += 1.0)
    end

    # GRUG: First token is a command marker = strong imperative signal.
    # "Run the tests" is clearly a command. "List everything" too.
    if !isempty(tokens_clean) && tokens_clean[1] in COMMAND_MARKERS
        action_scores[ACTION_COMMAND] += 0.8
    end

    # GRUG: If no action signal found at all, default to ASSERT.
    # Most plain statements are assertions. Better than defaulting to nothing.
    total_action_signal = sum(values(action_scores))
    if total_action_signal < 0.5
        action_scores[ACTION_ASSERT] += 1.0
        total_action_signal = 1.0
    end

    predicted_action  = argmax(action_scores)
    action_max_score  = action_scores[predicted_action]
    action_confidence = clamp(action_max_score / max(total_action_signal, 1.0), 0.1, 1.0)

    # ------------------------------------------------------------------
    # STEP 2: Score tone families
    # ------------------------------------------------------------------
    tone_scores = Dict{ToneFamily, Float64}(
        TONE_HOSTILE     => 0.0,
        TONE_CURIOUS     => 0.0,
        TONE_DECLARATIVE => 0.0,
        TONE_URGENT      => 0.0,
        TONE_NEUTRAL     => 0.0,
        TONE_REFLECTIVE  => 0.0
    )

    # GRUG: Per-token tone scoring.
    for tok in tokens_clean
        tok in HOSTILE_MARKERS   && (tone_scores[TONE_HOSTILE]    += 1.0)
        tok in URGENT_MARKERS    && (tone_scores[TONE_URGENT]     += 1.0)
        tok in SPECULATE_MARKERS && (tone_scores[TONE_REFLECTIVE] += 0.6)
        tok in QUERY_MARKERS     && (tone_scores[TONE_CURIOUS]    += 0.7)
        tok in REFLECTIVE_MARKERS && (tone_scores[TONE_REFLECTIVE] += 0.5)
    end

    # GRUG: Multiple ALL CAPS words = hostile OR urgent. Add to both, winner takes it.
    if caps_words >= 2
        tone_scores[TONE_HOSTILE] += 0.5
        tone_scores[TONE_URGENT]  += 0.5
    end

    # GRUG: Multi-word reflective phrases. Scan lowercased full string.
    input_low = lowercase(input_text)
    for phrase in REFLECTIVE_PHRASES
        if contains(input_low, phrase)
            tone_scores[TONE_REFLECTIVE] += 0.8
        end
    end

    # GRUG: Query action + no hostility = probably curious, not aggressive.
    if action_scores[ACTION_QUERY] > 0.5 && tone_scores[TONE_HOSTILE] < 0.5
        tone_scores[TONE_CURIOUS] += 0.6
    end

    # GRUG: No strong tone signal? Default to NEUTRAL. Baseline is calm.
    total_tone_signal = sum(values(tone_scores))
    if total_tone_signal < 0.4
        tone_scores[TONE_NEUTRAL] += 1.0
    end

    predicted_tone = argmax(tone_scores)

    # ------------------------------------------------------------------
    # STEP 3: Incomplete causal chain detection
    # ------------------------------------------------------------------
    is_dangling, dangling_verb = detect_incomplete_chain(tokens_clean, all_verbs)

    # GRUG: Dangling verb = user left a thought incomplete. Nudge toward SPECULATE.
    # Only switch predicted_action if SPECULATE clearly wins (0.3+ margin).
    # Don't flip action on a whisper of evidence.
    if is_dangling
        action_scores[ACTION_SPECULATE] += 0.5
        new_action = argmax(action_scores)
        if new_action != predicted_action &&
           action_scores[new_action] >= action_scores[predicted_action] + 0.3
            predicted_action = new_action
        end
    end

    # ------------------------------------------------------------------
    # STEP 4: Compute arousal nudge
    # ------------------------------------------------------------------
    arousal_nudge = get(TONE_AROUSAL_NUDGE, predicted_tone, 0.0)

    # GRUG: ESCALATE action adds extra arousal push regardless of tone.
    # User spiking = cave must widen attention immediately.
    if predicted_action == ACTION_ESCALATE
        arousal_nudge = clamp(arousal_nudge + 0.20, -1.0, 1.0)
    end

    # ------------------------------------------------------------------
    # STEP 5: Compute confidence weight multiplier
    # ------------------------------------------------------------------
    base_weight   = get(ACTION_WEIGHT_TABLE, predicted_action, 1.0)

    # GRUG: Scale weight by confidence. Low confidence = stay near 1.0 (minimal skew).
    # High confidence = apply full multiplier. Linear interpolation between the two.
    scaled_weight = 1.0 + (base_weight - 1.0) * action_confidence

    return PredictionResult(
        predicted_action,
        predicted_tone,
        action_confidence,
        is_dangling,
        dangling_verb,
        arousal_nudge,
        scaled_weight,
        time()
    )
end

# ==============================================================================
# INTEGRATION HELPERS
# ==============================================================================

"""
    apply_prediction_to_arousal!(prediction, get_arousal_fn, set_arousal_fn!)

Apply the prediction's `arousal_nudge` to the EyeSystem by calling the provided
getter and setter function handles. Caller passes the functions — this module
stays decoupled from EyeSystem and can be tested independently.

No-ops if `arousal_nudge == 0.0` to avoid a pointless EyeSystem write.
Clamps the result to [0.0, 1.0] before setting.
"""
function apply_prediction_to_arousal!(
    prediction     ::PredictionResult,
    get_arousal_fn ::Function,
    set_arousal_fn!::Function
)
    # GRUG: Zero nudge = skip the write. Don't touch EyeSystem for nothing.
    if prediction.arousal_nudge == 0.0
        return
    end

    current = get_arousal_fn()
    new_val = clamp(current + prediction.arousal_nudge, 0.0, 1.0)
    set_arousal_fn!(new_val)

    @info "[PREDICTOR] 👁  Arousal nudged $(round(current, digits=3)) → " *
          "$(round(new_val, digits=3)) ($(prediction.tone_family))"
end

"""
    get_action_weight_multiplier(prediction, node_action_name) -> Float64

Given a `PredictionResult` and a node's winning action name string, return
the confidence multiplier to apply to that node's scan confidence score.

- If node action aligns with predicted family: returns `prediction.action_weight` (> 1.0)
- If node action does NOT align: returns suppression factor (< 1.0, scales with confidence)
- If prediction confidence < 0.3: returns 1.0 (no modulation — prediction too weak)

Alignment is keyword-based: the node's action name is checked for substrings
associated with each action family (e.g. "query", "answer", "respond" for ACTION_QUERY).
"""
function get_action_weight_multiplier(
    prediction      ::PredictionResult,
    node_action_name::String
)::Float64

    # GRUG: Weak prediction = don't skew anything. Let the cave scan naturally.
    if prediction.confidence < 0.3
        return 1.0
    end

    # GRUG: Empty action name = unknown action. No alignment possible. No suppression either.
    action_low = lowercase(strip(node_action_name))
    if isempty(action_low)
        return 1.0
    end

    aligned = _action_name_aligns(action_low, prediction.action_family)

    if aligned
        return prediction.action_weight
    else
        # GRUG: Misaligned node gets gentle suppression. Not a hard block —
        # just a probabilistic lean. Low-confidence predictions suppress less.
        # suppression ranges from 0.85 (high conf) to 1.0 (zero conf).
        return 0.85 + (0.15 * (1.0 - prediction.confidence))
    end
end

# GRUG: Internal keyword alignment check — does this action name sound like the
# predicted action family? Substring match on known keywords per family.
# Not a perfect classifier — just a fast heuristic for confidence modulation.
function _action_name_aligns(action_name::String, family::ActionFamily)::Bool
    if family == ACTION_QUERY
        return any(kw -> contains(action_name, kw),
                   ["query", "answer", "respond", "explain", "describe", "tell", "info"])
    elseif family == ACTION_COMMAND
        return any(kw -> contains(action_name, kw),
                   ["execute", "run", "do", "action", "command", "perform", "trigger"])
    elseif family == ACTION_NEGATE
        return any(kw -> contains(action_name, kw),
                   ["negate", "deny", "reject", "contra", "refute", "wrong"])
    elseif family == ACTION_ASSERT
        return any(kw -> contains(action_name, kw),
                   ["assert", "state", "declare", "confirm", "affirm", "say"])
    elseif family == ACTION_SPECULATE
        return any(kw -> contains(action_name, kw),
                   ["speculate", "predict", "infer", "hypothe", "guess", "maybe"])
    elseif family == ACTION_ESCALATE
        return any(kw -> contains(action_name, kw),
                   ["alert", "warn", "escalate", "urgent", "critical", "flag"])
    end
    return false
end

"""
    format_prediction_summary(prediction) -> String

Return a compact human-readable summary of a `PredictionResult`.
Used by `/status`, debug logging, and the `@info` line in `scan_specimens`.
"""
function format_prediction_summary(prediction::PredictionResult)::String
    chain_str = prediction.incomplete_chain ?
        " [dangling: '$(prediction.dangling_verb)']" : ""
    return "Action=$(prediction.action_family) | " *
           "Tone=$(prediction.tone_family) | " *
           "Conf=$(round(prediction.confidence, digits=2)) | " *
           "ArousalNudge=$(round(prediction.arousal_nudge, digits=2)) | " *
           "Weight=$(round(prediction.action_weight, digits=2))$(chain_str)"
end

end # module ActionTonePredictor

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: ACTION+TONE PREDICTION LAYER
#
# 1. PRE-VOTE MODULATION ARCHITECTURE:
# The predictor fires before scan_specimens assembles its vote pool.
# It does not vote, does not create nodes, and does not modify global state.
# Its two outputs — arousal_nudge and action_weight — are applied by callers:
#   - arousal_nudge: applied in process_mission() via apply_prediction_to_arousal!()
#   - action_weight: applied per-node inside scan_specimens() via
#     get_action_weight_multiplier()
# If the predictor throws for any reason, both callers catch the error, log a
# @warn, and continue with unmodulated behavior. The cave always scans.
#
# 2. ACTION FAMILY SCORING:
# Each action family accumulates a float score from multiple signal sources:
# lexicon token matches, structural signals (first-token imperative, "?"),
# and surface signals (ALL CAPS count, exclamation count). The family with the
# highest score wins. Confidence is the winning score divided by total signal
# magnitude, clamped to [0.1, 1.0]. Default fallback is ACTION_ASSERT when
# total signal is below 0.5.
#
# 3. TONE FAMILY SCORING:
# Tone scoring follows the same accumulation pattern but is evaluated
# independently from action scoring. This allows cross-classification:
# e.g., ACTION_COMMAND with TONE_HOSTILE ("STOP this broken thing now!"),
# or ACTION_QUERY with TONE_REFLECTIVE ("I wonder what causes this?").
# Multi-word phrase markers are scanned against the full lowercased input
# string for reflective hedges that can't be detected token-by-token.
#
# 4. INCOMPLETE CAUSAL CHAIN DETECTION:
# A dangling chain is defined as a relational verb appearing in the last 1-2
# token positions of the input with no meaningful object token following it.
# Only punctuation tokens are allowed after the verb for the chain to qualify
# as dangling. Detection uses the live verb set from SemanticVerbs so runtime
# verb additions are immediately included in chain detection.
#
# 5. CONFIDENCE WEIGHT SCALING:
# Action weight multipliers from ACTION_WEIGHT_TABLE represent the maximum boost
# at full prediction confidence. The actual applied weight is linearly
# interpolated between 1.0 (zero confidence) and the table value (full confidence).
# This ensures that low-confidence predictions produce minimal modulation,
# preventing a weak signal from aggressively skewing the scan results.
#
# 6. DECOUPLING FROM EYESYSTEM:
# apply_prediction_to_arousal!() accepts EyeSystem's get/set functions as
# parameters rather than importing EyeSystem directly. This keeps ActionTonePredictor
# independently testable and prevents circular module dependencies.
# ==============================================================================