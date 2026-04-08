# Architecture

GrugBot420 is organized as a layered neuromorphic engine. This page describes the major subsystems and their interactions.

## System Overview

```
┌─────────────────────────────────────────────────┐
│                   CLI (Main.jl)                 │
├──────────┬──────────┬──────────┬────────────────┤
│ InputQueue│Thesaurus │BrainStem │  ChatterMode   │
│ (FIFO +  │(Dim.Sim) │(WTA     │  (Idle Gossip) │
│  NegThes)│          │Dispatch)│                │
├──────────┴──────────┴──────────┴────────────────┤
│          Lobe System (Subject Partitions)       │
│          LobeTable (Chunked Hash Storage)       │
├─────────────────────────────────────────────────┤
│           Engine (Node Voting Core)             │
│  ActionTonePredictor │ SemanticVerbs            │
│  AttachmentRelay (Relational Fire System)       │
├──────────────────────┴──────────────────────────┤
│  PatternScanner │ ImageSDF │ EyeSystem          │
├─────────────────┴──────────┴────────────────────┤
│         StochasticHelper (@coinflip)            │
├─────────────────────────────────────────────────┤
│  PhagyMode (7 Idle Maintenance Automata)        │
│  MemoryForensics (Coinflip: Fuzzy │ Metric)     │
└─────────────────────────────────────────────────┘
```

## Node Lifecycle

1. **Creation** — Nodes are planted via `/grow` with a pattern, action packet, and optional JSON data
2. **Scanning** — Input is converted to a signal vector; nodes compete via pattern matching with selective scan tiers (cheap/medium/high-res) based on both input complexity and per-node pattern complexity
3. **Attachment Relay** — Nodes that fired are checked for attachments; attached nodes do a strength-biased coinflip and winners join the vote pool (Pass 3 of `scan_and_expand`)
4. **Voting** — Matched nodes enter a superposition pool; action weights determine contribution
5. **Selection** — BrainStem dispatches the winner via winner-take-all with stochastic override
6. **Decay** — Unused nodes lose strength over time; grave nodes may be recycled by PhagyMode
7. **Forensics** — During idle cycles, PhagyMode may roll Automaton 7 (Memory Forensics) to audit message history and node population health. This is read-only observation, never mutation.

## Attachment Relay (Relational Fire)

The attachment relay is **Pass 3** of `scan_and_expand()` in `engine.jl`. After the primary scan (Pass 1) and lobe cascade (Pass 2), the engine iterates every node in the expanded set and checks for attachments via `ATTACHMENT_MAP`. Each attached node does a strength-biased coinflip (`scan_prob = 0.20 + (strength / STRENGTH_CAP) * 0.70`). Winners enter the expanded vote set with pre-baked confidence plus jitter. The relay has its own independent active cap sample (`rand(600:1800)`) to respect the biological attention bottleneck.

### JIT Confidence Baking

The **connector pattern** (middleman) is the core of the relay system. Confidence is computed **once at attach time** (JIT), not every fire cycle:

1. **Text nodes** (`/nodeAttach`): token overlap similarity between the connector pattern and the **attached node's own pattern** (Jaccard) + strength bonus → stored as `base_confidence`
2. **Image nodes** (`/imgnodeAttach`): image binary → `JITGPU(binary)` (real KernelAbstractions.jl GPU kernel dispatch) → cosine similarity between connector SDF signal and attached image node's signal + strength bonus → stored as `base_confidence`

At fire time, only stochastic jitter is applied: `confidence = max(0.1, base_confidence + randn() * 0.05)`. The connector pattern is still stored for AIML reference and surfaces as a `RelationalTriple(target_id, "relay_attached", connector_pattern)` so downstream knows WHY these nodes were co-activated.

### Image Attachment (`/imgnodeAttach`)

Image attachments use the same `AttachedNode` struct and `ATTACHMENT_MAP` as text attachments. The key difference is the JIT computation at attach time: image binary is converted to nonlinear SDF parameters via **`JITGPU(binary; width, height)`**, then flattened to a signal vector via `sdf_to_signal()`. Confidence is derived from `_sdf_signal_similarity()` (cosine similarity) instead of `_token_overlap_similarity()` (Jaccard). The pattern field stores SDF metadata (`"SDF:image:WxH"`) instead of a text connector pattern.

`JITGPU` uses `KernelAbstractions.jl` to dispatch real GPU kernels across backends selected at runtime: `CUDABackend()` on NVIDIA hardware, `ROCBackend()` on AMD, `MetalBackend()` on Apple Silicon, and `CPU()` (multithreaded Julia threads) as the CI-safe fallback. The kernel code is identical across all backends — only the dispatch target changes. The two-pass kernel pipeline is:

1. **Pass 1 (`_sdf_pixel_decode_kernel!`)**: one thread per pixel — decode UInt8 bytes (gray/RGB/RGBA) → `brightness_raw`, `color_scalar`, normalized `x`/`y` coordinates
2. **`KernelAbstractions.synchronize(backend)`**: device barrier — all pixels decoded before any gradient reads its neighbors
3. **Pass 2 (`_sdf_gradient_kernel!`)**: central-difference gradient → `tanh(3 × grad_mag)` nonlinear SDF activation — edges produce high activation, uniform regions suppress to near zero

Key properties:
- Max 4 attachments per target node (text + image share the same pool)
- Coinflip-gated: strong attachments fire more often but weak ones still have a 20% floor
- JIT confidence: `base_confidence` baked at attach time, fire applies `max(0.1, base_confidence + randn() * 0.05)` (synaptic jitter for vote diversity)
- Connector pattern / SDF metadata surfaces as a relay triple for generative context
- Deduplication: no node appears twice in the expanded set
- Fired attachments get a `bump_strength!` call (they earned it)
- Fully serialized in specimen save/load (section 14 / 4.14), with backward compat re-baking

## PhagyMode (Idle Maintenance Automata)

PhagyMode runs one randomly selected automaton per idle cycle. There are seven automata:

1. **Orphan Pruner** — Graves nodes with zero neighbors and zero strength
2. **Strength Decayer** — Decays forgotten node strengths toward a floor
3. **Grave Recycler** — Reclaims resources from long-dead grave nodes
4. **Hopfield Cache Validator** — Purges stale or orphaned cache entries
5. **Drop Table Compactor** — Trims low-probability drop table entries (preserves last entry)
6. **Rule Pruner** — Flags dormant rules by tracking fire count and dormancy strikes
7. **Memory Forensics** — Coinflip-gated read-only analysis of message history and node health

Selection is uniform (`rand(1:7)`). If Automaton 7 is rolled but `message_history` / `history_lock` kwargs are not available, the dispatcher re-rolls to 1–6 (graceful fallback, not silent skip). Each automaton handles its own locking and returns a `PhagyStats` result that is logged to the `PHAGY_LOG` ring buffer.

## Memory Forensics (Automaton 7)

Memory Forensics is a read-only diagnostic system that audits the health of `MESSAGE_HISTORY` and `NODE_MAP`. A coinflip (`rand(Bool)`) selects between two analysis modes:

**Fuzzy Mode** (approximate, heuristic, sampled) — fast for large caves:
- Role distribution balance (samples up to 500 messages, flags if one role exceeds 90%)
- Pattern diversity estimate (hash-based unique ratio across up to 1000 alive nodes)
- Strength distribution shape (5-band histogram, flags if >80% cluster in one band)
- Memory echo detection (samples 200 recent messages for repeated content)

**Metric Mode** (exact, measurement-based, full enumeration) — thorough but slower:
- Exact message census by role with totals
- Node population metrics (alive, grave, image node counts, grave reason breakdown)
- Dead node reference audit (regex scan of messages for `node_\d+` references to dead/missing nodes)
- Pinned message tracking (count, percentage, oldest pinned message ID)
- Strength statistics (mean, median, std dev, min, max — computed without Statistics.jl)
- Orphan detection (alive nodes with 0 neighbors and 0 strength)

Key design properties:
- **Read-only** — forensics never mutates MESSAGE_HISTORY or NODE_MAP
- **No silent failures** — all errors propagate via `PhagyError`, never swallowed
- **Dual-lock order** — metric dead-ref audit acquires `history_lock` then `node_lock` (consistent ordering prevents deadlock)
- **Configurable thresholds** — `FORENSICS_STALE_MSG_RATIO`, `FORENSICS_DEAD_REF_THRESHOLD`, `FORENSICS_PATTERN_ENTROPY_LO`, `FORENSICS_STRENGTH_SKEW_MAX`

## File Reference

| File | Description |
|------|-------------|
| `src/stochastichelper.jl` | `@coinflip` macro and `bias()` helper |
| `src/patternscanner.jl` | Multi-resolution signal pattern matching |
| `src/ImageSDF.jl` | JIT image → SDF parameter conversion |
| `src/EyeSystem.jl` | Visual attention and peripheral processing |
| `src/SemanticVerbs.jl` | Live mutable verb registry |
| `src/ActionTonePredictor.jl` | Pre-vote input classifier |
| `src/engine.jl` | Core node engine |
| `src/Lobe.jl` | Subject-specific node partitions |
| `src/LobeTable.jl` | Per-lobe chunked hash table storage |
| `src/BrainStem.jl` | Winner-take-all dispatcher |
| `src/Thesaurus.jl` | Dimensional similarity engine |
| `src/InputQueue.jl` | FIFO queue and NegativeThesaurus |
| `src/ChatterMode.jl` | Idle gossip system |
| `src/PhagyMode.jl` | 7 maintenance automata including memory forensics |
| `src/Main.jl` | CLI loop, memory cave, specimen persistence |
