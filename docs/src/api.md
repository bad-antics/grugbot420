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

- `cheap_scan(input, pattern)` — fast token overlap, O(n) 
- `medium_scan(input, pattern)` — token + bigram overlap
- `high_res_scan(input, pattern, triples)` — full relational triple matching

All return a confidence score in `[0.0, 1.0]`.

## Image SDF (`ImageSDF`)

- `detect_image_binary(input)` — detects Base64 image data URIs or raw binary image headers. Returns `(found::Bool, format::Symbol, payload::String)`.
- `image_to_sdf_params(pixels, width, height)` — converts a raw pixel buffer to `SDFParams` (x/y arrays, brightness, color, dimensions).
- `SDFParams` — struct holding the SDF representation of an image for pattern scanning.

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

The attachment system enables explicit relational firing chains between nodes. It lives in `engine.jl` alongside the core node engine.

### Data Structures

- `AttachedNode` — Immutable struct holding `node_id::String`, `pattern::String`, `signal::Vector{Float64}` (pre-baked via `words_to_signal`)
- `ATTACHMENT_MAP` — `Dict{String, Vector{AttachedNode}}` mapping target node IDs to their attached nodes
- `ATTACHMENT_LOCK` — `ReentrantLock` for thread-safe access
- `MAX_ATTACHMENTS` — Hard cap of 4 attachments per target

### Functions

- `attach_node!(target_id, attach_id, pattern)` — Attach a node to a target with a user-defined firing pattern. Validates: non-empty arguments, node existence, grave status, self-attach prevention, max cap, duplicate prevention. Pre-bakes the pattern into a signal vector on attach. Returns a human-readable confirmation string.

- `detach_node!(target_id, attach_id)` — Remove a specific attachment. Cleans up the target's entry entirely if no attachments remain. Returns a confirmation string.

- `fire_attachments!(target_id, active_count, active_cap)` — Called during Pass 3 of `scan_and_expand()`. For each attached node: checks the active cap gate, verifies the node is alive, runs a strength-biased coinflip (`scan_prob = 0.20 + (strength / STRENGTH_CAP) * 0.70`), computes confidence from token overlap similarity + strength bonus, calls `bump_strength!` on winners. Returns `Vector{Tuple{String, Float64}}` of `(node_id, confidence)` pairs.

- `get_attachment_summary()` — Returns a formatted string showing every target and its attached nodes with patterns, signal lengths, and slot usage. Used by the `/attachments` CLI command.

- `get_attachments_for_target(target_id)` — Simple accessor returning the `Vector{AttachedNode}` for a given target (empty vector if none).

## Input Queue (`InputQueue`)

Bounded input queue with integrated `NegativeThesaurus` inhibition filter. Strips inhibited tokens before pattern matching begins.