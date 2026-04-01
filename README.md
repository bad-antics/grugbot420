# 🧠 grugbot420

A neuromorphic AI engine written in Julia. GrugBot models cognition through competing populations of pattern nodes — not if-else waterfalls, not transformers, not lookup tables. Many rocks compete to be loudest. Loudest rock gets to talk. Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.

---

## Requirements

- [Julia](https://julialang.org/downloads/) 1.9+
- Julia packages: `Distributions`, `JSON`, `Random` (all stdlib or registered)

Install dependencies once:

```julia
using Pkg
Pkg.add(["Distributions", "JSON"])
```

---

## Running GrugBot

```bash
julia Main.jl
```

That's it. The engine seeds three boot nodes, prints a startup banner, and drops you at the `Brain >` prompt.

---

## CLI Commands

### Core

| Command | What it does |
|---|---|
| `/mission <text>` | Send input to the engine. This is the main command. Also accepts image binary (Base64 or hex). |
| `/wrong` | Tell GrugBot its last response was bad. Penalizes every node that voted via coinflip strength decay. Nodes that reach 0 become graves. |
| `/explicit <cmd> [<node_id>] <text>` | Force a specific command+node combination, bypassing the vote system. |
| `/grow <json>` | Plant one or more new nodes from a JSON packet (see format below). |
| `/addRule <rule text> [prob=0.0-1.0]` | Add a stochastic orchestration rule. Fires with given probability on every response. Supports template tags. |
| `/pin <text>` | Pin text permanently to the memory cave wall. Pinned messages survive the 10,000-message rolling window. |

### Status & Inspection

| Command | What it does |
|---|---|
| `/nodes` | Show all nodes: ID, pattern, strength, neighbor count, grave status. |
| `/status` | Full system health snapshot: node count, Hopfield cache, memory estimate, lobe summary, BrainStem stats, ChatterMode stats. |
| `/arousal <0.0-1.0>` | Manually set the EyeSystem arousal level. Higher arousal = tighter visual attention cutout. |

### Semantic Verbs

| Command | What it does |
|---|---|
| `/addVerb <verb> <class>` | Add a verb to a relation class (e.g. `/addVerb triggers causal`). Takes effect immediately on next `/mission`. |
| `/addRelationClass <name>` | Create a new verb class bucket (e.g. `/addRelationClass epistemic`). |
| `/addSynonym <canonical> <alias>` | Register a synonym normalization (e.g. `/addSynonym causes triggers`). Alias is rewritten to canonical before triple extraction. |
| `/listVerbs` | Dump all registered verb classes, their verbs, and synonym mappings. |

### Lobes & Tables

| Command | What it does |
|---|---|
| `/newLobe <id> <subject>` | Create a new subject partition (e.g. `/newLobe language "natural language processing"`). Cap: 20,000 nodes per lobe, 64 lobes max. |
| `/connectLobes <id_a> <id_b>` | Link two lobes bidirectionally. BrainStem uses connections for lateral signal propagation (60% decay per hop). |
| `/lobeGrow <lobe_id> <json>` | Grow a node directly into a specific lobe. JSON must have `pattern` and `action_packet` fields. |
| `/lobes` | Show all lobes: node counts, connection graph, fire counts. |
| `/tableStatus <lobe_id>` | Show hash table chunk sizes for a lobe (nodes, json, drop, hopfield, meta chunks). |
| `/tableMatch <lobe_id> <chunk> <pattern>` | Pattern-activate entries in a lobe's hash table. Use `node_id` for prefix match, any other token for token match. |

### Thesaurus

| Command | What it does |
|---|---|
| `/thesaurus <word1> \| <word2>` | Dimensional similarity comparison: overall %, semantic %, contextual %, associative %, confidence %. |
| `/thesaurus <w1> \| <w2> :: <ctx1> :: <ctx2>` | Same comparison with context lists (comma-separated) to modulate scoring. |

### Negative Thesaurus (Inhibition Filter)

| Command | What it does |
|---|---|
| `/negativeThesaurus add <word> [--reason <text>]` | Register a word as inhibited. Filtered from input before scan. |
| `/negativeThesaurus remove <word>` | Remove a word from the inhibition list. |
| `/negativeThesaurus list` | Show all inhibited words with reasons and timestamps. |
| `/negativeThesaurus check <word>` | Quick check if a word is currently inhibited. |
| `/negativeThesaurus flush` | Clear all inhibitions at once. |

### Specimen Persistence (Long-Term Storage)

| Command | What it does |
|---|---|
| `/saveSpecimen <filepath>` | Freeze the entire cave state to a gzip-compressed JSON file. Every node, lobe, rule, message, verb, thesaurus entry, inhibition, arousal level — everything. |
| `/loadSpecimen <filepath>` | Restore the entire cave state from a previously saved specimen file. **Destructive** — current state is wiped and replaced (full brain transplant). |

### Help

```
/help
```

Prints the full command reference inside the CLI.

---

## Growing Nodes (`/grow`)

Nodes are the atomic unit of GrugBot. Each node has a pattern (the text it matches against), an action packet (what it does when it fires), optional JSON data, and an optional drop table (co-activation neighbors).

**JSON packet format:**

```json
{
  "nodes": [
    {
      "pattern": "machine learning neural network",
      "action_packet": "reason[dont hallucinate]^4 | analyze^2 | explain^1",
      "data": {
        "system_prompt": "Technical ML domain active.",
        "required_relations": ["uses"],
        "relation_weights": {"uses": 2.0}
      },
      "drop_table": []
    }
  ]
}
```

**Action packet format:** `action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight`

- Actions: `reason`, `analyze`, `ponder`, `calculate`, `greet`, `welcome`, `smile`, `laugh`, `flee`, `hide`, `fight`, `explain`, `clarify`, `describe`, `define`, `elaborate`, `comfort`, `support`, `validate`, `acknowledge`, `reassure`, `alert`, `warn`, `caution`, `notify`, `flag`
- Negatives in `[...]` are constraints injected into the AIML payload
- `^weight` sets the relative voting weight for the superposition orchestrator

**Example:**

```
/grow {"nodes":[{"pattern":"sad unhappy depressed","action_packet":"comfort[dont dismiss]^3 | validate^2 | support^1","data":{"system_prompt":"Emotional support mode active."}}]}
```

---

## Specimen Persistence (`/saveSpecimen` + `/loadSpecimen`)

GrugBot supports full long-term persistence via specimen files. A specimen file is a **gzip-compressed JSON** snapshot of the entire cave state — every node, lobe, rule, message, verb, thesaurus entry, inhibition, and more. Save your cave at any time, share it with others, or restore it later.

### Saving

```
/saveSpecimen mycave.specimen.gz
```

This freezes the entire cave state into `mycave.specimen.gz`. The file contains compressed JSON covering all 13 state categories.

### Loading (Restoring)

```
/loadSpecimen mycave.specimen.gz
```

**This is a destructive operation** — current cave state is completely wiped and replaced with the specimen file contents. Think of it as a full brain transplant.

The file is validated before any state is wiped. If validation fails, zero changes are made.

### What gets saved/restored

| # | State Category | Description |
|---|---|---|
| 1 | **nodes** | Full Node structs — id, pattern, signal, action_packet, strength, neighbors, graves, drop_table, response_times, hopfield_key, relational_patterns, throttle, json_data |
| 2 | **hopfield_cache** | Familiar input fast-path cache with hit counts (UInt64 hash → node IDs) |
| 3 | **rules** | AIML_DROP_TABLE stochastic orchestration rules (text + fire probability) |
| 4 | **message_history** | Up to 10,000 ChatMessage entries with pin flags preserved |
| 5 | **lobes** | LOBE_REGISTRY — subject, node_ids, connected_lobe_ids, fire/inhibit counts |
| 6 | **node_to_lobe_idx** | NODE_TO_LOBE_IDX reverse index (node → lobe mapping) |
| 7 | **lobe_tables** | LOBE_TABLE_REGISTRY with all chunks (nodes, json, drop, hopfield, meta) and NodeRef objects |
| 8 | **verb_registry** | SemanticVerbs — all verb classes, verbs, and synonym normalizations |
| 9 | **thesaurus_seeds** | Thesaurus SYNONYM_SEED_MAP (hardcoded defaults + runtime additions) |
| 10 | **inhibitions** | InputQueue NegativeThesaurus entries (word, reason, timestamp) |
| 11 | **arousal** | EyeSystem arousal state (level, decay_rate, baseline) |
| 12 | **id_counters** | NODE ID_COUNTER and MSG_ID_COUNTER atomic values |
| 13 | **brainstem** | BrainStem dispatch count and propagation history |

### Restore order

`id_counters` → `verb_registry` → `thesaurus_seeds` → `lobes` → `lobe_tables` → `nodes` → `node_to_lobe_idx` → `hopfield_cache` → `rules` → `inhibitions` → `message_history` → `arousal` → `brainstem`

This ensures upstream entities exist before downstream references (e.g., lobes exist before nodes reference them).

### File format

- **Extension convention:** `.specimen.gz` (not enforced, any path works)
- **Compression:** gzip (system `gzip`/`gunzip` via pipeline — no extra Julia packages)
- **Content:** JSON with pretty-print indentation (human-readable when decompressed)
- **Metadata:** `_meta` section records version, timestamp, and format identifier

---

## Adding Orchestration Rules (`/addRule`)

Rules are injected into every response payload. They support template tags and fire stochastically.

**Template tags:** `{MISSION}`, `{PRIMARY_ACTION}`, `{SURE_ACTIONS}`, `{UNSURE_ACTIONS}`, `{ALL_ACTIONS}`, `{CONFIDENCE}`, `{NODE_ID}`, `{MEMORY}`, `{LOBE_CONTEXT}`

**Examples:**

```
/addRule Always ground responses in {MISSION} before expanding.
/addRule If confidence {CONFIDENCE} is below 0.5, hedge your answer. [prob=0.7]
/addRule Current lobe state: {LOBE_CONTEXT} — use cross-domain reasoning. [prob=0.5]
```

Rules with no `[prob=X]` suffix default to `prob=1.0` (always fire).

---

## Idle Behavior (v7.1 — Slow Timer)

When the cave has been quiet for ~120 seconds (±30s jitter), GrugBot runs an idle action automatically — a 50/50 coinflip between:

- **Chatter (1000+ nodes only):** 50–500 node clones gossip and exchange patterns. Only **weak** nodes morph — receivers must be weaker than senders. Each node can only morph **once per 24 hours** (cooldown enforced). New specimens with < 1000 nodes skip chatter entirely.
- **Phagy:** One maintenance automaton runs (orphan pruning, strength decay, grave recycling, cache validation, drop table compaction, or rule pruning). Always fires regardless of population.

Both chatter and phagy share the same slow idle timer. If fewer than 50 eligible nodes exist, the group size floors at whatever is available. You don't need to trigger this manually. It runs between CLI prompts.

---

## Running Tests

Each test file is standalone:

```bash
julia test_smoke.jl            # 16 integration groups
julia test_lobes.jl            # 123 assertions
julia test_lobe_table.jl       # 193 assertions
julia test_brainstem.jl        # 39 assertions
julia test_thesaurus.jl        # 151 assertions
julia test_chat_specimen.jl    # 18 specimens
julia test_input_queue.jl      # 20 groups, 1095 assertions
julia test_action_packet.jl    # 18 groups, 111 assertions
julia test_load_specimen.jl    # 14 groups, 102 assertions
julia test_phagy.jl            # Phagy cycle (placeholder)
julia live_training_test.jl    # Multi-lobe training (12+ pass, 0 hard fail)
```

---

## File Reference

| File | Role |
|---|---|
| `Main.jl` | Entry point. CLI loop, memory cave, mission processor, idle manager, specimen persistence. |
| `engine.jl` | Core node engine: node creation, scanning, voting, Hopfield cache, drop-table expansion. |
| `stochastichelper.jl` | `@coinflip` macro and `bias()` helper for weighted probabilistic branching. |
| `patternscanner.jl` | Signal-level pattern matching: `cheap_scan`, `medium_scan`, `high_res_scan`. |
| `Lobe.jl` | Subject-specific node partitions with O(1) reverse index. |
| `LobeTable.jl` | Per-lobe chunked hash table storage (nodes, json, drop, hopfield, meta chunks). |
| `BrainStem.jl` | Winner-take-all dispatcher with cross-lobe signal propagation and fire-count decay. |
| `Thesaurus.jl` | Dimensional similarity engine with seed synonym dictionary, gate filter, and runtime seed injection. |
| `InputQueue.jl` | FIFO input queue and NegativeThesaurus inhibition filter. |
| `ChatterMode.jl` | Idle gossip system (v7.1): 50–500 ephemeral clones, 1000+ node gate, weak-only morph, 24h cooldown, 120s±30s shared timer. |
| `PhagyMode.jl` | Six idle-time maintenance automata for self-healing map management. |
| `EyeSystem.jl` | Visual attention: edge blurring, arousal-gated center cutout, attention modulation. |
| `ImageSDF.jl` | JIT image → SDF parameter conversion for image node matching. |
| `SemanticVerbs.jl` | Live mutable verb registry: causal, spatial, temporal classes + runtime synonyms. |
| `ActionTonePredictor.jl` | Pre-vote input classifier: predicts action type and tone, nudges arousal and confidence weights. |
| `grugbot_whitepaper.html` | Full technical documentation and architecture reference. |

---

## Documentation

Open `grugbot_whitepaper.html` in a browser for the full technical whitepaper covering architecture, formal mathematics, all subsystems, and design rationale.

---

## Notes on Seeding

The first ~100 nodes you plant are the specimen's DNA. Before hitting 1,000 nodes, automatic neighbor latching is suppressed — you control topology manually via drop tables. Recommendations:

1. Seed orthogonal archetypes first — distinct semantic poles, not 50 near-identical nodes
2. Use `required_relations` as semantic gates from day one so nodes don't fire on noise
3. Name action packets deliberately — distinct action families give the superposition orchestrator something meaningful to work with
4. Wire drop tables manually for known co-activation pairs
5. The engine enforces structure at scale (1,000+ nodes). You enforce meaning at the start.