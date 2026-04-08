# CLI Reference

Launch GrugBot420 with `julia Main.jl` (standalone) or `GrugBot420.main()` (from the module). You'll see the `Brain >` prompt.

## Core Commands

| Command | Description |
|---------|-------------|
| `/mission <text>` | Send input to the engine (main command) |
| `/wrong` | Penalize nodes that voted on the last response |
| `/explicit <cmd> [<node_id>] <text>` | Force a specific command+node, bypassing votes |
| `/grow <json>` | Plant new nodes from a JSON packet |
| `/addRule <rule> [prob=X]` | Add a stochastic orchestration rule |
| `/pin <text>` | Pin text permanently to the memory cave wall |

## Status & Inspection

| Command | Description |
|---------|-------------|
| `/nodes` | Show all nodes with ID, pattern, strength, neighbors, grave status |
| `/status` | Full system health snapshot |
| `/arousal <0.0-1.0>` | Set the EyeSystem arousal level |

## Semantic Verbs

| Command | Description |
|---------|-------------|
| `/addVerb <verb> <class>` | Add a verb to a relation class |
| `/addRelationClass <name>` | Create a new verb class bucket |
| `/addSynonym <canonical> <alias>` | Register a synonym normalization |
| `/listVerbs` | Dump all verb classes and synonyms |

## Lobes & Tables

| Command | Description |
|---------|-------------|
| `/newLobe <id> <subject>` | Create a new subject partition |
| `/connectLobes <id_a> <id_b>` | Link two lobes bidirectionally |
| `/lobeGrow <lobe_id> <json>` | Grow a node into a specific lobe |
| `/lobes` | Show all lobes |
| `/tableStatus <lobe_id>` | Show hash table chunk sizes |

## Thesaurus

| Command | Description |
|---------|-------------|
| `/thesaurus <w1> \| <w2>` | Dimensional similarity comparison |
| `/negativeThesaurus add <word>` | Inhibit a word from input scanning |
| `/negativeThesaurus list` | Show all inhibited words |

## Relational Fire (Node Attachments)

| Command | Description |
|---------|-------------|
| `/nodeAttach <target> <id1> <pattern1> [...]` | Attach up to 4 text nodes to a target with connector patterns (middleman reasons). Confidence JIT-baked at attach time. Quoted multi-word patterns supported. |
| `/nodeDetach <target> <id>` | Remove a specific text attachment from a target node |
| `/imgnodeAttach <target> <id> <b64> [w h]` | Attach an image node to a target with SDF-based relational fire. Image→SDF conversion at attach time (JIT GPU accel). Width/height optional (default 8×8). |
| `/imgnodeDetach <target> <id>` | Remove a specific image attachment from a target node |
| `/attachments` | Show the full attachment map (all targets, attached nodes, base_confidence) |

When the target node fires during `scan_and_expand`, each attached node does a strength-biased coinflip. Winners get their connector pattern (middleman) scanned against the **attached node's own pattern** — not the target's — to determine voting confidence. The connector pattern also surfaces as generative context explaining WHY the relay fired. The active cap (biological attention bottleneck) is respected. See the Relational Fire System section in the project README for full details.

## Specimen Persistence

| Command | Description |
|---------|-------------|
| `/saveSpecimen <path>` | Freeze entire cave state to gzip JSON (includes attachments) |
| `/loadSpecimen <path>` | Restore cave state from specimen file (includes attachments) |

## Help

```
/help
```

Prints the full command reference inside the CLI.
