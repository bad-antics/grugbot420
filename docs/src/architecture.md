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
├──────────────────────┴──────────────────────────┤
│  PatternScanner │ ImageSDF │ EyeSystem          │
├─────────────────┴──────────┴────────────────────┤
│         StochasticHelper (@coinflip)            │
└─────────────────────────────────────────────────┘
```

## Node Lifecycle

1. **Creation** — Nodes are planted via `/grow` with a pattern, action packet, and optional JSON data
2. **Scanning** — Input is converted to a signal vector; nodes compete via pattern matching
3. **Voting** — Matched nodes enter a superposition pool; action weights determine contribution
4. **Selection** — BrainStem dispatches the winner via winner-take-all with stochastic override
5. **Decay** — Unused nodes lose strength over time; grave nodes may be recycled by PhagyMode

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
