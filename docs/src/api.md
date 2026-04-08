# API Reference

This page documents the public API of GrugBot420's core subsystems.

## Stochastic Helper (`CoinFlipHeader`)

The `@coinflip` macro provides weighted probabilistic branching. Given a list of `(outcome, weight)` pairs, it selects one outcome proportionally to its weight using a `Categorical` distribution.

```julia
result = @coinflip begin
    "greet"   => 3.0
    "analyze" => 1.5
    "refuse"  => 0.5
end
```

`bias(outcomes)` returns the most probable outcome without randomness — useful for deterministic fallback.

## Pattern Scanner (`PatternScanner`)

Three scan modes with increasing precision:

- `cheap_scan(input, pattern)` — strided sliding window, O(n/stride)
- `medium_scan(input, pattern)` — every-index sliding window, O(n)
- `high_res_scan(input, pattern)` — two-pass: candidate zone detection + strict variance-penalized validation

All return `(best_index, confidence)` or throw `PatternNotFoundError`.

- `_bidirectional_cheap_scan(target, pattern; threshold)` — tier-1 wrapper: runs `cheap_scan` **forward AND reverse** (reversed pattern signal), returns smoothed confidence = average of both contributions. Miss contribution = `threshold - 0.01` (not zero, to avoid harshly penalizing partial reversal). If both directions miss → `PatternNotFoundError`. Corrects order-sensitivity of `words_to_signal` encoding for short patterns.

### Selective Scan Tier Selection

Scan tier is determined by two factors:

1. **Input complexity** (`screen_input_complexity`) — signal length and triple count set the base tier (1=cheap, 2=medium, 3=high-res)
2. **Node pattern complexity** (`_effective_scan_mode`) — per-node downgrade based on the node's own signal length. Simple patterns don't justify expensive scanning:
   - ≤3 tokens → capped at tier 1 (**bidirectional** `_bidirectional_cheap_scan`)
   - 4–8 tokens → capped at tier 2 (medium scan, single direction)
   - \>8 tokens → no cap (full tier from input complexity)

The tier can only go **down**, never up. If the input demands cheap scan, the node can't push it to high-res. But if the input demands high-res, a tiny node pattern drops it back to cheap. Tier-1 nodes additionally get bidirectional smoothing to resolve the order-sensitivity of `words_to_signal` encoding — "dog bites man" and "man bites dog" both match regardless of which order the connector pattern was encoded.

## Image SDF (`ImageSDF`)

- `detect_image_binary(input)` — detects Base64 image data URIs or raw binary image headers. Returns `(found::Bool, format::Symbol, payload::String)`.
- `JITGPU(binary; width, height)` — **GPU-accelerated** nonlinear SDF conversion via `KernelAbstractions.jl`. Dispatches `@kernel` functions to `CUDABackend()`, `ROCBackend()`, `MetalBackend()`, or `CPU()` (multithreaded, CI-safe) based on runtime detection. Two-pass kernel: Pass 1 decodes pixels in parallel; `synchronize(backend)` ensures all neighbors exist before Pass 2 computes `tanh(3 × grad_mag)` SDF activations. Returns `SDFParams`.
- `image_to_sdf_params(pixels, width, height)` — CPU reference implementation (same algorithm as `JITGPU` but Float64 throughout). Kept for backward compatibility and test comparison.
- `SDFParams` — struct holding the SDF representation of an image for pattern scanning.
- `apply_sdf_jitter(params::SDFParams)` — injects small bounded per-element noise into SDF brightness/gradient values. Called each time an SDF fires to prevent identical repeat activations. Returns a new `SDFParams`.
- `sdf_to_signal(params::SDFParams)` — flattens `SDFParams` into a `Vector{Float64}` signal for pattern scanning. Interleaves brightness and gradient values.

## Semantic Verbs (`SemanticVerbs`)

- `add_verb!(verb, class)` — register a new causal/relational verb
- `add_relation_class!(class)` — add a new relation class
- `add_synonym!(canonical, alias)` — register a synonym alias

## Lobe System (`Lobe`)

- `create_lobe!(subject)` — create a named subject partition
- `connect_lobes!(lobe_a, lobe_b)` — link two lobes for cross-domain signal propagation
- `lobe_grow!(lobe_id, node_id)` — assign a node to a lobe (enforces capacity cap)

## Lobe Table (`LobeTable`)

- `create_lobe_table!(lobe_id)` — initialize the chunked hash table for a lobe

## BrainStem (`BrainStem`)

Winner-take-all dispatcher. Routes the highest-confidence vote to the correct lobe and propagates a decayed signal (60% of winning confidence) to connected lobes.

## Thesaurus (`Thesaurus`)

Multi-axis similarity engine with semantic, contextual, and associative dimensions. Seeded with a synonym dictionary at startup; extensible at runtime via `SemanticVerbs.add_synonym!`.

## Attachment System (Relational Fire)

The attachment system enables explicit relational firing chains between nodes. It lives in `engine.jl` alongside the core node engine. Supports both text nodes (`/nodeAttach`) and image nodes (`/imgnodeAttach`).

### Data Structures

- `AttachedNode` — Immutable struct holding:
  - `node_id::String` — ID of the attached node
  - `pattern::String` — Connector/middleman pattern (text) or SDF metadata (`"SDF:image:WxH"` for image attachments)
  - `signal::Vector{Float64}` — Pre-baked signal (text: via `words_to_signal`; image: via `sdf_to_signal`)
  - `base_confidence::Float64` — JIT-baked confidence computed at attach time (not at fire time)
- `ATTACHMENT_MAP` — `Dict{String, Vector{AttachedNode}}` mapping target node IDs to their attached nodes
- `ATTACHMENT_LOCK` — `ReentrantLock` for thread-safe access
- `MAX_ATTACHMENTS` — Hard cap of 4 attachments per target (shared between text and image)
- `RELAY_CONF_JITTER_SIGMA` — `0.05`, stochastic jitter applied at fire time to pre-baked confidence

### Functions

- `attach_node!(target_id, attach_id, pattern)` — Attach a text node to a target with a connector pattern (middleman). JIT confidence baking: the connector pattern is scanned against the **attached node's own pattern** at attach time via `_token_overlap_similarity()`, combined with a strength bonus `(strength / STRENGTH_CAP) * 0.5`, and stored as `base_confidence`. The signal is pre-baked via `words_to_signal()`. Validates: non-empty arguments, node existence, grave status, self-attach prevention, max cap, duplicate prevention. Returns a human-readable confirmation string including the baked `base_confidence`.

- `attach_image_node!(target_id, attach_id, image_data, width, height)` — Attach an image node to a target with SDF-based relational fire. JIT GPU accel: image binary is converted to nonlinear SDF at attach time via `JITGPU(image_data; width, height)` (real KernelAbstractions.jl kernel dispatch — CUDA/ROC/Metal/CPU), flattened to a signal via `sdf_to_signal()`, and `base_confidence` is baked from `_sdf_signal_similarity()` (cosine similarity) + strength bonus. The attach node **must** be an image node (`is_image_node=true`). Pattern field stores `"SDF:image:WxH"` metadata. All validations from `attach_node!` apply, plus image-specific checks (non-empty data, valid dimensions, image node requirement).

- `detach_node!(target_id, attach_id)` — Remove a specific attachment (works for both text and image). Cleans up the target's entry entirely if no attachments remain. Returns a confirmation string.

- `fire_attachments!(target_id, active_count, active_cap)` — Called during Pass 3 of `scan_and_expand()`. For each attached node: checks the active cap gate, verifies the node is alive, runs a strength-biased coinflip, then applies **only jitter** to the pre-baked `base_confidence`: `confidence = max(0.1, att.base_confidence + randn() * RELAY_CONF_JITTER_SIGMA)`. Calls `bump_strength!` on winners. Returns `Vector{Tuple{String, Float64, String}}` of `(node_id, confidence, connector_pattern)` triples. The connector pattern surfaces downstream as a `RelationalTriple("target_id", "relay_attached", connector_pattern)`.

- `_sdf_signal_similarity(sig_a, sig_b)` — Cosine similarity between two SDF-derived signal vectors, clamped to `[0.0, 1.0]`. Image-domain equivalent of `_token_overlap_similarity`. Truncates to the shorter signal length. Errors on empty signals.

- `get_attachment_summary()` — Returns a formatted string showing every target and its attached nodes with `base_confidence`, patterns, and slot usage. Used by the `/attachments` CLI command.

- `get_attachments_for_target(target_id)` — Simple accessor returning the `Vector{AttachedNode}` for a given target (empty vector if none).

## PhagyMode (`PhagyMode`)

Idle maintenance automata system with seven automata. Exported functions and types:

### Types

- `PhagyStats` — Return type for all automata. Fields: `automaton::String` (name), `items_examined::Int`, `items_changed::Int`, `cycle_time_ms::Float64`, `notes::String` (human-readable report).
- `PhagyError` — Custom exception type for structural failures (invalid locks, corrupted state). Always propagated, never silently swallowed.

### Core Functions

- `run_phagy!(node_map, node_lock, hopfield_cache, cache_lock, rules, rules_lock; message_history=nothing, history_lock=nothing)::PhagyStats` — Main entry point. Randomly selects one of seven automata to run. Automaton 7 (Memory Forensics) requires the optional `message_history` and `history_lock` kwargs; if not provided and Automaton 7 is rolled, re-rolls to 1–6.
- `get_phagy_log()::Vector{PhagyStats}` — Returns a copy of the `PHAGY_LOG` ring buffer (last 50 cycle results).

### Memory Forensics Functions

- `run_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Dispatcher. Validates locks, flips a coin (`rand(Bool)`), routes to fuzzy or metric mode. Returns `PhagyStats` with findings in the `notes` field.
- `fuzzy_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Approximate heuristic analysis. Samples up to 500 messages for role balance, 1000 nodes for pattern diversity and strength distribution, 200 messages for echo detection. Returns `PhagyStats` with automaton name `"MEMORY_FORENSICS_FUZZY"`.
- `metric_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Exact measurement-based analysis. Full enumeration of message census, node population, dead reference audit, pinned tracking, strength statistics, and orphan count. Returns `PhagyStats` with automaton name `"MEMORY_FORENSICS_METRIC"`.

### Forensics Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `FORENSICS_STALE_MSG_RATIO` | `0.90` | Role imbalance threshold — flag if one role exceeds 90% of messages |
| `FORENSICS_DEAD_REF_THRESHOLD` | `0.10` | Dead reference alert — flag if >10% of node refs in messages are dead |
| `FORENSICS_PATTERN_ENTROPY_LO` | `0.15` | Low diversity — flag if <15% unique patterns among alive nodes |
| `FORENSICS_STRENGTH_SKEW_MAX` | `0.80` | Monoculture — flag if >80% of nodes cluster in one strength band |

## Input Queue (`InputQueue`)

Bounded input queue with integrated `NegativeThesaurus` inhibition filter. Strips inhibited tokens before pattern matching begins.