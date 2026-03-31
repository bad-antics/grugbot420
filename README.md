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

### Specimen Loader

| Command | What it does |
|---|---|
| `/loadSpecimen <json>` | Batch-load an entire cave blueprint from a single JSON object. Validates everything before committing anything — atomic loading, no half-built caves. |

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

## Loading a Full Specimen (`/loadSpecimen`)

`/loadSpecimen` is the batch seeding command. Instead of planting nodes one at a time with `/grow`, defining rules with `/addRule`, and creating lobes with `/newLobe` separately, you hand GrugBot a single JSON blueprint that describes an entire cave topology. All sections are validated before anything is committed — if any part of the JSON is malformed, zero changes are made.

**JSON schema (all top-level keys are optional, but at least one must be present):**

```json
{
  "verb_classes": ["epistemic", "emotional"],
  "verbs": [
    {"verb": "believes", "class": "epistemic"},
    {"verb": "doubts", "class": "epistemic"}
  ],
  "synonyms": [
    {"canonical": "believes", "alias": "thinks"},
    {"canonical": "causes", "alias": "triggers"}
  ],
  "lobes": [
    {"id": "philosophy", "subject": "philosophical reasoning"},
    {"id": "emotion", "subject": "emotional processing"}
  ],
  "connections": [
    {"lobe_a": "philosophy", "lobe_b": "emotion"}
  ],
  "nodes": [
    {
      "pattern": "what is consciousness awareness",
      "action_packet": "reason[dont hallucinate]^4 | ponder^2 | explain^1",
      "data": {"system_prompt": "Deep philosophical analysis active."},
      "drop_table": []
    }
  ],
  "lobe_nodes": [
    {
      "lobe_id": "philosophy",
      "node": {
        "pattern": "free will determinism choice",
        "action_packet": "analyze[dont assume]^3 | reason^2",
        "data": {"system_prompt": "Metaphysics domain active."}
      }
    }
  ],
  "rules": [
    {"text": "Always ground responses in {MISSION} context.", "prob": 1.0},
    {"text": "Consider cross-domain lobe signals: {LOBE_CONTEXT}", "prob": 0.5}
  ],
  "inhibitions": [
    {"word": "profanity", "reason": "content filter"},
    {"word": "spam"}
  ],
  "pins": [
    "Core directive: prioritize epistemic humility.",
    "This specimen was seeded on 2025-01-15."
  ]
}
```

**Commit order:** `verb_classes` → `verbs` → `synonyms` → `lobes` → `connections` → `nodes` → `lobe_nodes` → `rules` → `inhibitions` → `pins`. This ensures downstream sections can reference upstream entities (verbs reference classes, lobe_nodes reference lobes, etc.).

**Section reference:**

| Section | Format | What it does |
|---|---|---|
| `verb_classes` | `["name", ...]` | Create new verb class buckets |
| `verbs` | `[{verb, class}, ...]` | Add verbs to relation classes |
| `synonyms` | `[{canonical, alias}, ...]` | Register synonym normalizations |
| `lobes` | `[{id, subject}, ...]` | Create subject-specific partitions |
| `connections` | `[{lobe_a, lobe_b}, ...]` | Link lobes bidirectionally |
| `nodes` | `[{pattern, action_packet, data?, drop_table?, is_image_node?}, ...]` | Plant nodes (same format as `/grow`) |
| `lobe_nodes` | `[{lobe_id, node: {pattern, action_packet, data?, drop_table?}}, ...]` | Grow nodes directly into lobes |
| `rules` | `[{text, prob?}, ...]` | Add stochastic orchestration rules |
| `inhibitions` | `[{word, reason?}, ...]` | Register NegativeThesaurus inhibitions |
| `pins` | `["text", ...]` | Pin text to memory cave wall |

On success, GrugBot prints a summary table showing per-section counts and created node IDs.

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

## Idle Behavior

When the cave has been quiet for ~30 seconds, GrugBot runs an idle action automatically — a 50/50 coinflip between:

- **Chatter:** 100–800 node clones gossip and exchange patterns, strengthening frequently co-activated knowledge
- **Phagy:** One maintenance automaton runs (orphan pruning, strength decay, grave recycling, cache validation, drop table compaction, or rule pruning)

You don't need to trigger this manually. It runs between CLI prompts.

---

## Running Tests

Each test file is standalone:

```bash
julia test_smoke.jl
julia test_lobes.jl
julia test_lobe_table.jl
julia test_brainstem.jl
julia test_thesaurus.jl
julia test_chat_specimen.jl
julia test_input_queue.jl
julia test_action_packet.jl
julia test_phagy.jl
julia live_training_test.jl
```

---

## File Reference

| File | Role |
|---|---|
| `Main.jl` | Entry point. CLI loop, memory cave, mission processor, idle manager. |
| `engine.jl` | Core node engine: node creation, scanning, voting, Hopfield cache, drop-table expansion. |
| `stochastichelper.jl` | `@coinflip` macro and `bias()` helper for weighted probabilistic branching. |
| `patternscanner.jl` | Signal-level pattern matching: `cheap_scan`, `medium_scan`, `high_res_scan`. |
| `Lobe.jl` | Subject-specific node partitions with O(1) reverse index. |
| `LobeTable.jl` | Per-lobe chunked hash table storage (nodes, json, drop, hopfield, meta chunks). |
| `BrainStem.jl` | Winner-take-all dispatcher with cross-lobe signal propagation and fire-count decay. |
| `Thesaurus.jl` | Dimensional similarity engine with seed synonym dictionary and gate filter. |
| `InputQueue.jl` | FIFO input queue and NegativeThesaurus inhibition filter. |
| `ChatterMode.jl` | Idle gossip system: ephemeral node clones exchange patterns between prompts. |
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