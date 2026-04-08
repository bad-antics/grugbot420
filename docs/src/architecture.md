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
└─────────────────────────────────────────────────┘
```

## Node Lifecycle

1. **Creation** — Nodes are planted via `/grow` with a pattern, action packet, and optional JSON data
2. **Scanning** — Input is converted to a signal vector; nodes compete via pattern matching
3. **Attachment Relay** — Nodes that fired are checked for attachments; attached nodes do a strength-biased coinflip and winners join the vote pool (Pass 3 of `scan_and_expand`)
4. **Voting** — Matched nodes enter a superposition pool; action weights determine contribution
5. **Selection** — BrainStem dispatches the winner via winner-take-all with stochastic override
6. **Decay** — Unused nodes lose strength over time; grave nodes may be recycled by PhagyMode

## Attachment Relay (Relational Fire)

The attachment relay is **Pass 3** of `scan_and_expand()` in `engine.jl`. After the primary scan (Pass 1) and lobe cascade (Pass 2), the engine iterates every node in the expanded set and checks for attachments via `ATTACHMENT_MAP`. Each attached node does a strength-biased coinflip (`scan_prob = 0.20 + (strength / STRENGTH_CAP) * 0.70`). Winners enter the expanded vote set with pattern-derived confidence. The relay has its own independent active cap sample (`rand(600:1800)`) to respect the biological attention bottleneck.

Key properties:
- Max 4 attachments per target node
- Coinflip-gated: strong attachments fire more often but weak ones still have a 20% floor
- Confidence = `max(0.1, token_overlap(attached_pattern, target_pattern) + strength_bonus)`
- Deduplication: no node appears twice in the expanded set
- Fired attachments get a `bump_strength!` call (they earned it)
- Fully serialized in specimen save/load (section 14 / 4.14)

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
| `src/PhagyMode.jl` | Maintenance automata |
| `src/Main.jl` | CLI loop, memory cave, specimen persistence |
