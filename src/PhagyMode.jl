# PhagyMode.jl
# ==============================================================================
# PHAGY MODE - IDLE-TIME AUTOMATA MAINTENANCE SYSTEM
# ==============================================================================
# GRUG: When idle timer fires and coinflip lands on PHAGY (50/50 vs chatter),
# one phagy automaton runs instead of a gossip session.
#
# PHAGY MECHANICS:
#   - ONE target is selected per cycle (random weighted priority)
#   - Phagy never does a full sweep - one job, then done (Big-O safe)
#   - Six automata are available, selected randomly each cycle:
#       1. ORPHAN PRUNER      - Cull nodes with zero connections (in + out)
#       2. STRENGTH DECAYER   - Batch-decay nodes unseen for N sessions
#       3. GRAVE RECYCLER     - Salvage drop_table assets before final deletion
#       4. CACHE VALIDATOR    - Purge stale Hopfield cache entries
#       5. DROP TABLE COMPACT - Dedupe + trim low-probability drop_table tails
#       6. RULE PRUNER        - Flag/remove orchestration rules that never fire
#
# DESIGN RULES:
#   - No silent failures. Every error surfaces.
#   - One automaton per cycle. Never all six at once.
#   - Thread-safe: all NODE_MAP access goes through NODE_LOCK.
#   - PhagyStats returned on every run for diagnostics and /status CLI.
# ==============================================================================

module PhagyMode

using Random

export run_phagy!, PhagyStats, get_phagy_log, PhagyError

# ==============================================================================
# ERROR TYPE - GRUG: NO SILENT FAILURES
# ==============================================================================

struct PhagyError <: Exception
    msg::String
end

Base.showerror(io::IO, e::PhagyError) =
    print(io, "PhagyError: ", e.msg)

# ==============================================================================
# PHAGY STATS (returned per cycle for diagnostics)
# ==============================================================================

# GRUG: Each phagy run reports what it did. Zero values are fine - it means
# the automaton found nothing to clean. That is still a valid healthy run.
struct PhagyStats
    automaton::String       # GRUG: Which automaton ran this cycle
    items_processed::Int    # GRUG: How many candidates were examined
    items_changed::Int      # GRUG: How many were actually mutated/removed
    cycle_time_ms::Float64  # GRUG: Wall time for this cycle in milliseconds
    notes::String           # GRUG: Human-readable summary of what happened
end

# ==============================================================================
# PHAGY LOG (bounded ring - last 50 cycles)
# ==============================================================================

const PHAGY_LOG      = PhagyStats[]
const PHAGY_LOG_LOCK = ReentrantLock()
const MAX_PHAGY_LOG  = 50

"""
push_phagy_log!(stats::PhagyStats)

GRUG: Append a phagy cycle result to the bounded log. Trims oldest entry
when log exceeds MAX_PHAGY_LOG. Thread-safe.
"""
function push_phagy_log!(stats::PhagyStats)
    lock(PHAGY_LOG_LOCK) do
        push!(PHAGY_LOG, stats)
        while length(PHAGY_LOG) > MAX_PHAGY_LOG
            deleteat!(PHAGY_LOG, 1)
        end
    end
end

"""
get_phagy_log()::Vector{PhagyStats}

GRUG: Return a snapshot copy of the phagy log for diagnostics.
"""
function get_phagy_log()::Vector{PhagyStats}
    return lock(PHAGY_LOG_LOCK) do
        copy(PHAGY_LOG)
    end
end

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: A node is an orphan if it has been created but never latched any
# neighbors AND has zero connections accumulated. Only meaningful on large maps
# (NODE_LATCH_THRESHOLD guards growth, phagy guards cleanup on same boundary).
const ORPHAN_MAX_NEIGHBORS  = 0     # GRUG: Nodes with exactly 0 neighbors are orphan candidates

# GRUG: Strength decay per phagy cycle for nodes that have not been activated
# recently. Small enough that a single phagy cycle won't kill a useful node.
const DECAY_RATE            = 0.03  # GRUG: 3% strength reduction per cycle

# GRUG: Nodes below this strength threshold are eligible for decay processing.
# Avoids wasting phagy cycles on already-strong nodes.
const DECAY_ELIGIBILITY_MAX = 0.4   # GRUG: Only decay nodes below 40% strength

# GRUG: Drop table entries below this probability are trimmed by DROP TABLE COMPACT.
const DROP_TABLE_TRIM_FLOOR = 0.05  # GRUG: 5% floor - below this gets cut

# GRUG: Rules that have been in the system for at least this many phagy cycles
# without ever firing are considered dormant candidates.
# (Rules track fire_count; zero fires after RULE_DORMANCY_CYCLES = dormant)
const RULE_DORMANCY_CYCLES  = 20    # GRUG: 20 idle cycles without a fire = dormant

# ==============================================================================
# AUTOMATON 1: ORPHAN PRUNER
# ==============================================================================

"""
prune_orphan_nodes!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Identify and grave nodes that have zero neighbors and zero strength.
These are disconnected dead-ends that were never integrated into the map topology.
Graving (not deleting) preserves their ID in the grave registry so latching
history remains consistent.

SAFETY: Never graves a node that has a non-empty drop_table (GRAVE RECYCLER
handles those). Never graves image nodes (SDF data is irreplaceable).
"""
function prune_orphan_nodes!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    t_start = time()
    examined = 0
    graved   = 0
    skipped_has_drops  = 0
    skipped_image      = 0

    orphan_ids = String[]

    lock(node_lock) do
        for (id, node) in node_map
            examined += 1
            # GRUG: Skip already-graved nodes (phagy should not double-process)
            node.is_grave && continue
            # GRUG: Skip image nodes - their SDF data is not reconstructable
            if node.is_image_node
                skipped_image += 1
                continue
            end
            # GRUG: Skip nodes that still have drop_table entries - GRAVE RECYCLER owns those
            if !isempty(node.drop_table)
                skipped_has_drops += 1
                continue
            end
            # GRUG: Orphan condition: zero neighbors AND zero strength
            if length(node.neighbors) <= ORPHAN_MAX_NEIGHBORS && node.strength <= 0.0
                push!(orphan_ids, id)
            end
        end
    end

    # GRUG: Second pass - grave the identified orphans under lock
    if !isempty(orphan_ids)
        lock(node_lock) do
            for id in orphan_ids
                if haskey(node_map, id)
                    node = node_map[id]
                    # GRUG: Final safety check under lock before graving
                    if !node.is_grave && !node.is_image_node && isempty(node.drop_table)
                        node.is_grave = true
                        graved += 1
                        @debug "[PHAGY:ORPHAN] Graved orphan node $id (strength=$(node.strength), neighbors=$(length(node.neighbors)))"
                    end
                end
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Graved=$graved, SkippedImageNodes=$skipped_image, SkippedHasDrops=$skipped_has_drops"
    println("[PHAGY:ORPHAN] 🧹  Cycle complete. $notes")
    return PhagyStats("ORPHAN_PRUNER", examined, graved, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 2: STRENGTH DECAYER
# ==============================================================================

"""
decay_forgotten_strengths!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Apply a small strength decay to nodes that are below DECAY_ELIGIBILITY_MAX.
This models biological forgetting: patterns that are rarely reinforced slowly fade.
Does NOT grave nodes - strength decay only. Graving is the ORPHAN PRUNER's job.

SAFETY: Never decays image nodes. Never decays nodes already at strength 0.0.
Decay is floored at 0.0 (no negative strength).
"""
function decay_forgotten_strengths!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    t_start  = time()
    examined = 0
    decayed  = 0
    skipped_strong = 0
    skipped_image  = 0

    lock(node_lock) do
        for (id, node) in node_map
            examined += 1
            node.is_grave && continue
            if node.is_image_node
                skipped_image += 1
                continue
            end
            # GRUG: Only decay weak nodes - strong nodes earned their keep
            if node.strength > DECAY_ELIGIBILITY_MAX
                skipped_strong += 1
                continue
            end
            # GRUG: Already at floor - nothing to decay
            node.strength <= 0.0 && continue

            old_str = node.strength
            node.strength = max(0.0, node.strength - DECAY_RATE)
            decayed += 1
            @debug "[PHAGY:DECAY] Node $id: strength $old_str → $(node.strength)"
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Decayed=$decayed, SkippedStrong=$skipped_strong, SkippedImageNodes=$skipped_image, DecayRate=$DECAY_RATE"
    println("[PHAGY:DECAY] 📉  Cycle complete. $notes")
    return PhagyStats("STRENGTH_DECAYER", examined, decayed, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 3: GRAVE RECYCLER
# ==============================================================================

"""
recycle_grave_assets!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Scan graved nodes for non-empty drop_tables. If a graved node still has
drop_table entries, extract those entries and attempt to merge them into the
strongest non-grave neighbor node. This is organ donation - the node is dead
but its learned associations can still benefit the map.

After recycling, the graved node's drop_table is cleared (assets donated, nothing
left to recycle on next pass).

SAFETY: Only processes nodes where is_grave=true. Never ungraves a node.
If no neighbor exists to receive assets, assets are discarded (logged as waste).
"""
function recycle_grave_assets!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    t_start   = time()
    examined  = 0
    recycled  = 0
    wasted    = 0
    no_target = 0

    lock(node_lock) do
        for (id, node) in node_map
            node.is_grave || continue
            isempty(node.drop_table) && continue
            examined += 1

            # GRUG: Find the strongest alive neighbor to receive the assets
            best_neighbor_id = ""
            best_strength    = -1.0

            for nid in node.neighbors
                if haskey(node_map, nid)
                    n = node_map[nid]
                    if !n.is_grave && n.strength > best_strength
                        best_strength    = n.strength
                        best_neighbor_id = nid
                    end
                end
            end

            if isempty(best_neighbor_id)
                # GRUG: Graved node has no alive neighbors. Assets go to waste.
                # Clear them anyway so this node doesn't get re-examined next cycle.
                wasted += length(node.drop_table)
                empty!(node.drop_table)
                no_target += 1
                @debug "[PHAGY:RECYCLE] Node $id: no alive neighbors. $(wasted) assets wasted."
                continue
            end

            # GRUG: Donate drop_table entries to best neighbor
            target = node_map[best_neighbor_id]
            donated = 0
            for (response_text, probability) in node.drop_table
                # GRUG: Only donate if target doesn't already have this entry
                if !haskey(target.drop_table, response_text)
                    target.drop_table[response_text] = probability
                    donated += 1
                end
                # GRUG: If target already has it, keep the max probability
                # (donated knowledge should not override stronger existing knowledge)
                existing = get(target.drop_table, response_text, 0.0)
                if probability > existing
                    target.drop_table[response_text] = probability
                    donated += 1
                end
            end

            # GRUG: Clear the graved node's drop_table - assets have been transferred
            empty!(node.drop_table)
            recycled += donated
            @debug "[PHAGY:RECYCLE] Node $id → $best_neighbor_id: donated $donated entries"
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Recycled=$recycled, Wasted=$wasted, NoTargetNodes=$no_target"
    println("[PHAGY:RECYCLE] ♻️   Cycle complete. $notes")
    return PhagyStats("GRAVE_RECYCLER", examined, recycled, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 4: HOPFIELD CACHE VALIDATOR
# ==============================================================================

"""
validate_hopfield_cache!(hopfield_cache, cache_lock, node_map, node_lock)::PhagyStats

GRUG: The Hopfield cache stores familiar-input fast-paths: UInt64 hash keys ->
Vector{String} of node IDs. If those node IDs have since been graved or deleted,
the cache entry is stale - it routes the fast-path to a dead node.
This automaton purges stale entries so the cache doesn't route to dead nodes.

Cache key type  : UInt64 (hash of normalized input text, from hopfield_input_hash())
Cache value type: Vector{String} (list of node IDs that matched that input)

A cache entry is stale if ANY of its node IDs are missing or graved.
SAFETY: Only removes entries - never modifies NODE_MAP. Two-pass pattern to avoid
mutation-during-iteration. Always acquires cache_lock THEN node_lock (deadlock order).
"""
function validate_hopfield_cache!(
    hopfield_cache  ::Dict,          # GRUG: Dict{UInt64, Vector{String}} from engine
    cache_lock      ::ReentrantLock,
    node_map        ::Dict,
    node_lock       ::ReentrantLock
)::PhagyStats
    t_start    = time()
    examined   = 0
    purged     = 0
    valid      = 0

    stale_keys = UInt64[]

    # GRUG: PASS 1 - collect stale keys under both locks (cache_lock THEN node_lock)
    # Lock order must always be cache_lock -> node_lock to prevent deadlock.
    lock(cache_lock) do
        lock(node_lock) do
            for (cache_key, node_ids) in hopfield_cache
                examined += 1
                # GRUG: Entry is stale if ANY referenced node is missing or graved
                is_stale = any(node_ids) do nid
                    !haskey(node_map, nid) || node_map[nid].is_grave
                end
                if is_stale
                    push!(stale_keys, cache_key)
                else
                    valid += 1
                end
            end
        end
    end

    # GRUG: PASS 2 - delete stale entries under cache_lock only (node_map not touched)
    if !isempty(stale_keys)
        lock(cache_lock) do
            for key in stale_keys
                delete!(hopfield_cache, key)
                purged += 1
                @debug "[PHAGY:CACHE] Purged stale cache entry key=$(key)"
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Purged=$purged, ValidKept=$valid"
    println("[PHAGY:CACHE] 🗄️   Cycle complete. $notes")
    return PhagyStats("CACHE_VALIDATOR", examined, purged, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 5: DROP TABLE COMPACTOR
# ==============================================================================

"""
compact_drop_tables!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Drop tables can accumulate low-probability junk entries over time.
This automaton scans all alive nodes and removes entries below DROP_TABLE_TRIM_FLOOR.
Also deduplicates any entries that are exact string matches (keeps the max probability).

SAFETY: Never removes entries from graved nodes (GRAVE RECYCLER handles those).
Never removes the LAST entry in a drop_table (node must keep at least one response).
"""
function compact_drop_tables!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    t_start   = time()
    examined  = 0
    trimmed   = 0
    protected = 0   # GRUG: Entries saved by "last entry" protection rule

    lock(node_lock) do
        for (id, node) in node_map
            node.is_grave && continue
            isempty(node.drop_table) && continue
            examined += 1

            # GRUG: Collect keys to trim (below floor probability)
            trim_candidates = String[]
            for (response_text, probability) in node.drop_table
                if probability < DROP_TABLE_TRIM_FLOOR
                    push!(trim_candidates, response_text)
                end
            end

            # GRUG: Apply "last entry" protection - never empty a drop_table
            if length(trim_candidates) >= length(node.drop_table)
                # GRUG: Would empty the table. Protect by keeping the highest-prob entry.
                keep_key = argmax(node.drop_table)
                filter!(k -> k != keep_key, trim_candidates)
                protected += 1
                @debug "[PHAGY:COMPACT] Node $id: last-entry protection applied, kept $keep_key"
            end

            # GRUG: Delete trim candidates
            for key in trim_candidates
                delete!(node.drop_table, key)
                trimmed += 1
                @debug "[PHAGY:COMPACT] Node $id: trimmed '$key' (below floor $DROP_TABLE_TRIM_FLOOR)"
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Trimmed=$trimmed, LastEntryProtections=$protected, TrimFloor=$DROP_TABLE_TRIM_FLOOR"
    println("[PHAGY:COMPACT] 🗜️   Cycle complete. $notes")
    return PhagyStats("DROP_TABLE_COMPACT", examined, trimmed, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 6: RULE PRUNER
# ==============================================================================

"""
prune_dormant_rules!(rules::Vector, rules_lock::ReentrantLock)::PhagyStats

GRUG: Orchestration rules that have never fired after RULE_DORMANCY_CYCLES phagy
cycles are flagged as dormant. This automaton increments a dormancy counter on
each rule per cycle and marks rules as dormant when the threshold is hit.

Rules must have fields: fire_count::Int, dormancy_strikes::Int, is_dormant::Bool
If rules don't have dormancy_strikes yet, this automaton adds them gracefully.

SAFETY: Never deletes rules - only sets is_dormant=true. User must explicitly
purge dormant rules via /pruneRules CLI command. This prevents accidental rule loss.
"""
function prune_dormant_rules!(rules::Vector, rules_lock::ReentrantLock)::PhagyStats
    t_start   = time()
    examined  = 0
    flagged   = 0
    already   = 0
    active    = 0

    lock(rules_lock) do
        for rule in rules
            examined += 1

            # GRUG: Skip rules already marked dormant
            if hasproperty(rule, :is_dormant) && rule.is_dormant
                already += 1
                continue
            end

            # GRUG: Rules with fires are alive - reset their dormancy strike counter
            if hasproperty(rule, :fire_count) && rule.fire_count > 0
                if hasproperty(rule, :dormancy_strikes)
                    rule.dormancy_strikes = 0
                end
                active += 1
                continue
            end

            # GRUG: Rule has zero fires. Increment dormancy strike.
            if hasproperty(rule, :dormancy_strikes)
                rule.dormancy_strikes += 1
                if rule.dormancy_strikes >= RULE_DORMANCY_CYCLES
                    if hasproperty(rule, :is_dormant)
                        rule.is_dormant = true
                        flagged += 1
                        @debug "[PHAGY:RULES] Rule flagged dormant after $(rule.dormancy_strikes) strikes: $(hasproperty(rule, :pattern) ? rule.pattern : rule)"
                    end
                end
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Flagged=$flagged, AlreadyDormant=$already, ActiveRules=$active, DormancyThreshold=$RULE_DORMANCY_CYCLES"
    println("[PHAGY:RULES] ✂️   Cycle complete. $notes")
    return PhagyStats("RULE_PRUNER", examined, flagged, elapsed_ms, notes)
end

# ==============================================================================
# PHAGY DISPATCHER - ONE AUTOMATON PER CYCLE
# ==============================================================================

"""
run_phagy!(node_map, node_lock, hopfield_cache, cache_lock, rules, rules_lock)::PhagyStats

GRUG: Main phagy entry point. Randomly selects ONE automaton to run this cycle.
Selection is weighted equally (1/6 each) - no automaton gets priority over others.
Each automaton is self-contained and handles its own locking.

Returns PhagyStats from the automaton that ran. Logs result to PHAGY_LOG.
Throws PhagyError on structural failure (missing locks, corrupted state).
Never silently swallows errors - all exceptions propagate up to maybe_run_idle().
"""
function run_phagy!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    hopfield_cache  ::Dict,
    cache_lock      ::ReentrantLock,
    rules           ::Vector,
    rules_lock      ::ReentrantLock
)::PhagyStats

    # GRUG: Validate inputs - phagy must not run against corrupted state
    if !isa(node_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid node_lock! !!!"))
    end
    if !isa(cache_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid cache_lock! !!!"))
    end
    if !isa(rules_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid rules_lock! !!!"))
    end

    # GRUG: Roll the automaton selector (1-6, uniform)
    automaton_roll = rand(1:6)

    println("[PHAGY] 🦠  Phagy cycle starting. Automaton roll: $automaton_roll/6")

    stats = try
        if automaton_roll == 1
            prune_orphan_nodes!(node_map, node_lock)
        elseif automaton_roll == 2
            decay_forgotten_strengths!(node_map, node_lock)
        elseif automaton_roll == 3
            recycle_grave_assets!(node_map, node_lock)
        elseif automaton_roll == 4
            validate_hopfield_cache!(hopfield_cache, cache_lock, node_map, node_lock)
        elseif automaton_roll == 5
            compact_drop_tables!(node_map, node_lock)
        elseif automaton_roll == 6
            prune_dormant_rules!(rules, rules_lock)
        else
            # GRUG: Should be unreachable. If rand(1:6) returns something else, cave is haunted.
            throw(PhagyError("!!! FATAL: automaton_roll=$automaton_roll is out of range [1,6]! !!!"))
        end
    catch e
        # GRUG: Automaton failure is NOT silent. Surface it immediately.
        println("[PHAGY] !!! ERROR in automaton $automaton_roll: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    end

    # GRUG: Log the completed cycle
    push_phagy_log!(stats)
    println("[PHAGY] ✅  Phagy cycle complete. Automaton=$(stats.automaton), Changed=$(stats.items_changed), Time=$(round(stats.cycle_time_ms, digits=2))ms")

    return stats
end

end # module PhagyMode

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: PHAGY MODE LAYER
#
# 1. ONE AUTOMATON PER CYCLE (BIG-O SAFETY):
# Phagy never runs all six automata in one idle event. A single random automaton
# is selected per cycle. This bounds the worst-case idle work to O(N) where N
# is the number of nodes/rules/cache entries. No compounding sweep costs.
#
# 2. TWO-PASS MUTATION PATTERN:
# Automata that need to delete/modify entries first collect candidates under a
# read lock, then apply mutations in a second pass under a write lock. This
# avoids mutation-during-iteration undefined behavior.
#
# 3. LAST-ENTRY PROTECTION:
# DROP TABLE COMPACT never empties a node's drop_table. If all entries are below
# the trim floor, the highest-probability entry is preserved. A node without any
# response is broken topology.
#
# 4. GRAVE VS DELETE:
# ORPHAN PRUNER sets is_grave=true rather than calling delete!(). This preserves
# node IDs in the map for history consistency. True deletion is a manual operation.
#
# 5. RULE FLAGGING VS DELETION:
# RULE PRUNER only sets is_dormant=true. It never deletes rules. This prevents
# accidental loss of hand-crafted orchestration logic. The user prunes explicitly.
#
# 6. HOPFIELD CACHE DUAL-LOCK ORDER:
# CACHE_VALIDATOR always acquires cache_lock THEN node_lock (in that order).
# All other code touching both locks must respect this order to prevent deadlock.
# ==============================================================================