# test_immune_thread_pool.jl
# ==============================================================================
# GRUG IMMUNE THREAD POOL TEST SUITE
# Tests the 8-thread immune worker pool, load balancer, waiting list,
# futures, error propagation, and non-blocking submission.
# NO SILENT FAILURES. If something breaks, Grug screams.
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG IMMUNE THREAD POOL TEST SUITE")
println("="^60)

# ==============================================================================
# MODULE LOAD
# ==============================================================================
println("\n[0] MODULE LOAD")

include("../src/ImmuneSystem.jl")
using .ImmuneSystem

include("../src/ImmuneThreadPool.jl")
using .ImmuneThreadPool

println("  ✓ ImmuneSystem module loaded")
println("  ✓ ImmuneThreadPool module loaded")

# ==============================================================================
# HELPER: fresh pool for each test group
# ==============================================================================

function fresh_pool()
    ImmuneSystem.reset_immune_state!()
    return create_immune_pool(ImmuneSystem)
end

# ==============================================================================
# 1. ERROR TYPE COVERAGE
# ==============================================================================
println("\n[1] ERROR TYPES")

# ImmuneWorkerDiedError
e1 = ImmuneWorkerDiedError(3, ErrorException("kaboom"))
@assert e1.worker_id == 3 "FAIL: worker_id mismatch"
io = IOBuffer(); showerror(io, e1)
msg = String(take!(io))
@assert occursin("WORKER #3 DIED", msg) "FAIL: showerror missing worker id"
println("  ✓ ImmuneWorkerDiedError: correct fields + showerror")

# ImmunePoolOverloadError
e2 = ImmunePoolOverloadError(512, "too many")
@assert e2.waiting_list_size == 512 "FAIL: size mismatch"
io2 = IOBuffer(); showerror(io2, e2)
@assert occursin("OVERLOADED", String(take!(io2))) "FAIL: showerror missing OVERLOADED"
println("  ✓ ImmunePoolOverloadError: correct fields + showerror")

# ImmunePoolDeadError
e3 = ImmunePoolDeadError("pool gone")
io3 = IOBuffer(); showerror(io3, e3)
@assert occursin("DEAD", String(take!(io3))) "FAIL: showerror missing DEAD"
println("  ✓ ImmunePoolDeadError: correct fields + showerror")

# ImmuneWorkerBalancerError
e4 = ImmuneWorkerBalancerError("no space")
io4 = IOBuffer(); showerror(io4, e4)
@assert occursin("BALANCER", String(take!(io4))) "FAIL: showerror missing BALANCER"
println("  ✓ ImmuneWorkerBalancerError: correct fields + showerror")

# ==============================================================================
# 2. POOL CREATION — 8 workers alive, dispatcher running
# ==============================================================================
println("\n[2] POOL CREATION")

pool = fresh_pool()
@assert pool.alive[] == true "FAIL: pool should be alive after creation"
@assert length(pool.workers) == NUM_IMMUNE_WORKERS "FAIL: should have $(NUM_IMMUNE_WORKERS) workers, got $(length(pool.workers))"
println("  ✓ Pool alive with $(NUM_IMMUNE_WORKERS) workers")

# Give workers time to start their loops
sleep(0.05)

alive_count = count(w -> w.alive[], pool.workers)
@assert alive_count == NUM_IMMUNE_WORKERS "FAIL: All workers should be alive, got $alive_count/$(NUM_IMMUNE_WORKERS)"
println("  ✓ All $alive_count / $(NUM_IMMUNE_WORKERS) workers alive")

# Dispatcher should be running (not done, not failed)
@assert !istaskdone(pool.dispatcher) "FAIL: Dispatcher should still be running"
@assert !istaskfailed(pool.dispatcher) "FAIL: Dispatcher should not have failed"
println("  ✓ Dispatcher task running")

kill_immune_pool!(pool)

# ==============================================================================
# 3. SUBMIT + FETCH — Basic end-to-end
# ==============================================================================
println("\n[3] SUBMIT + FETCH — Basic end-to-end")

pool = fresh_pool()
sleep(0.05)  # let workers start

# JSON input → should be :nonfunky (immune system below maturity for node_count < 1000)
future = submit_immune_work!(pool, """{"pattern":"hello","action":"greet"}""", 500)
@assert future isa ImmuneFuture "FAIL: submit should return ImmuneFuture"
println("  ✓ submit_immune_work! returned ImmuneFuture immediately")

# Wait for result (block)
status, sig = fetch_result(future)
@assert status == :immature "FAIL: node_count=500 < 1000 should be :immature, got $status"
println("  ✓ fetch_result returned (:immature, _) for node_count=500 (maturity gate)")

# Mature node count — JSON should be :nonfunky
future2 = submit_immune_work!(pool, """{"pattern":"hello","action":"greet"}""", 2000)
status2, sig2 = fetch_result(future2)
@assert status2 == :nonfunky "FAIL: Valid JSON at node_count=2000 should be :nonfunky, got $status2"
println("  ✓ fetch_result returned (:nonfunky, sig) for valid JSON at node_count=2000")

kill_immune_pool!(pool)

# ==============================================================================
# 4. NON-BLOCKING SUBMISSION — Main thread does not stall
# ==============================================================================
println("\n[4] NON-BLOCKING SUBMISSION")

pool = fresh_pool()
sleep(0.05)

t_start = time()

# Submit 50 items rapidly — should all return immediately
futures = ImmuneFuture[]
for i in 1:50
    f = submit_immune_work!(pool, """{"pattern":"test_$i","action":"greet"}""", 500)
    push!(futures, f)
end

t_submit = time() - t_start
println("  Submitted 50 items in $(round(t_submit * 1000, digits=2))ms")

# GRUG: Submitting 50 items should be very fast (< 100ms, realistically < 5ms).
# We're just pushing to a Vector + atomic increment. Not calling immune_scan!.
@assert t_submit < 0.5 "FAIL: 50 submissions took $(round(t_submit*1000))ms, should be < 500ms"
println("  ✓ 50 submissions completed in $(round(t_submit*1000, digits=1))ms (non-blocking)")

# Now wait for all results
for (i, f) in enumerate(futures)
    status, _ = fetch_result(f)
    @assert status == :immature "FAIL: item $i should be :immature, got $status"
end
println("  ✓ All 50 futures resolved correctly")

kill_immune_pool!(pool)

# ==============================================================================
# 5. LOAD BALANCING — Work distributed across all 8 workers
# ==============================================================================
println("\n[5] LOAD BALANCING")

pool = fresh_pool()
sleep(0.05)

n_jobs = 160  # 20 per worker if perfectly balanced

futures = ImmuneFuture[]
for i in 1:n_jobs
    f = submit_immune_work!(pool, """{"pattern":"lb_test_$i","value":$i}""", 500)
    push!(futures, f)
end

# Wait for all
for f in futures
    fetch_result(f)
end

# Check that multiple workers processed items
processed_counts = [w.processed[] for w in pool.workers]
workers_with_work = count(c -> c > 0, processed_counts)
total_processed = sum(processed_counts)

println("  Worker processed counts: $processed_counts")
println("  Total processed: $total_processed / $n_jobs")
println("  Workers that got work: $workers_with_work / $(NUM_IMMUNE_WORKERS)")

@assert total_processed == n_jobs "FAIL: total_processed=$total_processed should equal n_jobs=$n_jobs"
println("  ✓ All $n_jobs jobs processed")

# GRUG: With 160 jobs and 8 workers, at least 2 workers should have gotten work.
# Perfect balance would be 20 each. We don't require perfect balance, just spread.
@assert workers_with_work >= 2 "FAIL: Only $workers_with_work workers got work (need >= 2)"
println("  ✓ Work spread across $workers_with_work workers (load balancing active)")

kill_immune_pool!(pool)

# ==============================================================================
# 6. BAD INPUT PROCESSING DOES NOT STALL MAIN PATH
# ==============================================================================
println("\n[6] BAD INPUT DOES NOT STALL MAIN PATH")

pool = fresh_pool()
sleep(0.05)

# Pre-populate Hopfield with known signatures to ensure funky detection is triggered
# for alien input at mature node count
ImmuneSystem.reset_immune_state!()

# Submit a mix of good (immature gate) and funky (mature) inputs
futures_good  = ImmuneFuture[]
futures_funky = ImmuneFuture[]

t_start = time()

for i in 1:30
    # Good: immature gate
    fg = submit_immune_work!(pool, """{"pattern":"good_$i"}""", 500)
    push!(futures_good, fg)
end

for i in 1:20
    # Funky: mature, non-JSON novel input. Will trigger automata population.
    # Deliberately alien structure to force immune work.
    ff = submit_immune_work!(pool, "zzz_alien_funky_input_$(rand(UInt32))", 2000; is_critical=true)
    push!(futures_funky, ff)
end

t_submit_all = time() - t_start
println("  Submitted 50 mixed items in $(round(t_submit_all*1000, digits=2))ms")
@assert t_submit_all < 0.5 "FAIL: Submitting 50 items took $(round(t_submit_all*1000))ms (too slow)"
println("  ✓ All submissions returned immediately (bad inputs queued, not blocking)")

# Now collect results
good_results = [fetch_result(f) for f in futures_good]
@assert all(r -> r[1] == :immature, good_results) "FAIL: Good immature inputs should all be :immature"
println("  ✓ 30 good inputs resolved as :immature")

# Funky inputs: collect, ignoring ImmuneError (that's expected — input rejected)
n_rejected  = 0
n_processed = 0
for f in futures_funky
    try
        status, _ = fetch_result(f)
        n_processed += 1
        # Could be :coinflip_skip, :patched, :deleted (though delete throws ImmuneError)
    catch e
        if e isa ImmuneSystem.ImmuneError
            n_rejected += 1  # Expected: funky input rejected
        elseif e isa ImmuneWorkerDiedError
            @assert false "FAIL: Worker died during funky processing — $(e.cause)"
        else
            rethrow(e)
        end
    end
end

println("  Funky inputs: $n_processed processed, $n_rejected rejected (ImmuneError)")
@assert (n_processed + n_rejected) == 20 "FAIL: All 20 funky futures should have resolved"
println("  ✓ All 20 funky inputs resolved without stalling main path")

kill_immune_pool!(pool)

# ==============================================================================
# 7. FUTURE API — is_ready, fetch_result
# ==============================================================================
println("\n[7] FUTURE API")

pool = fresh_pool()
sleep(0.05)

# Submit something cheap (immature gate — returns instantly from immune_scan!)
f = submit_immune_work!(pool, """{"quick":"test"}""", 0)

# is_ready before resolution — might be false initially
# (we don't assert this because timing is not guaranteed)
ready_before = is_ready(f)

status, sig = fetch_result(f)
@assert status == :immature "FAIL: node_count=0 should be :immature, got $status"
println("  ✓ fetch_result returned :immature for node_count=0")

# After fetching, channel is empty
# (We can't re-fetch because take! would block — that's correct behavior)
println("  ✓ is_ready before resolution: $ready_before (timing-dependent, not asserted)")

# ImmuneFuture has correct fields
@assert f.input_text == """{"quick":"test"}""" "FAIL: future.input_text mismatch"
@assert f.submitted_at > 0.0 "FAIL: future.submitted_at should be > 0"
@assert f.request_id >= 0 "FAIL: future.request_id should be >= 0"
println("  ✓ ImmuneFuture fields (input_text, submitted_at, request_id) correct")

kill_immune_pool!(pool)

# ==============================================================================
# 8. DEAD POOL THROWS ImmunePoolDeadError
# ==============================================================================
println("\n[8] DEAD POOL DETECTION")

pool = fresh_pool()
sleep(0.02)
kill_immune_pool!(pool)

caught_dead = false
try
    submit_immune_work!(pool, "test input", 500)
catch e
    if e isa ImmunePoolDeadError
        caught_dead = true
    else
        rethrow(e)
    end
end
@assert caught_dead "FAIL: submit to dead pool should throw ImmunePoolDeadError"
println("  ✓ submit_immune_work! to dead pool throws ImmunePoolDeadError")

# ==============================================================================
# 9. EMPTY INPUT THROWS
# ==============================================================================
println("\n[9] EMPTY INPUT GUARD")

pool = fresh_pool()
sleep(0.02)

caught_empty = false
try
    submit_immune_work!(pool, "", 500)
catch e
    caught_empty = true
end
@assert caught_empty "FAIL: submit_immune_work! with empty input should throw"
println("  ✓ submit_immune_work! with empty input throws correctly")

caught_ws = false
try
    submit_immune_work!(pool, "   ", 500)
catch e
    caught_ws = true
end
@assert caught_ws "FAIL: submit_immune_work! with whitespace input should throw"
println("  ✓ submit_immune_work! with whitespace input throws correctly")

kill_immune_pool!(pool)

# ==============================================================================
# 10. SUBMIT_AND_WAIT — Blocking convenience wrapper
# ==============================================================================
println("\n[10] SUBMIT_AND_WAIT!")

pool = fresh_pool()
sleep(0.05)

# Immature gate
status, sig = submit_and_wait!(pool, """{"pattern":"sync_test"}""", 100)
@assert status == :immature "FAIL: submit_and_wait! should return :immature for node_count=100, got $status"
println("  ✓ submit_and_wait! returned :immature for node_count=100")

# Mature + JSON
status2, sig2 = submit_and_wait!(pool, """{"pattern":"sync_test2","action":"greet"}""", 1500)
@assert status2 == :nonfunky "FAIL: submit_and_wait! should return :nonfunky for valid JSON, got $status2"
println("  ✓ submit_and_wait! returned :nonfunky for valid JSON at node_count=1500")

kill_immune_pool!(pool)

# ==============================================================================
# 11. GET_POOL_STATUS — All fields present
# ==============================================================================
println("\n[11] GET_POOL_STATUS")

pool = fresh_pool()
sleep(0.05)

status = get_pool_status(pool)

@assert haskey(status, "pool_alive")        "FAIL: status missing pool_alive"
@assert haskey(status, "num_workers")       "FAIL: status missing num_workers"
@assert haskey(status, "alive_workers")     "FAIL: status missing alive_workers"
@assert haskey(status, "dead_workers")      "FAIL: status missing dead_workers"
@assert haskey(status, "waiting_list_size") "FAIL: status missing waiting_list_size"
@assert haskey(status, "waiting_list_max")  "FAIL: status missing waiting_list_max"
@assert haskey(status, "submitted_total")   "FAIL: status missing submitted_total"
@assert haskey(status, "dispatched_total")  "FAIL: status missing dispatched_total"
@assert haskey(status, "workers")           "FAIL: status missing workers"

@assert status["pool_alive"] == true "FAIL: pool_alive should be true"
@assert status["num_workers"] == NUM_IMMUNE_WORKERS "FAIL: num_workers should be $(NUM_IMMUNE_WORKERS)"
@assert status["alive_workers"] == NUM_IMMUNE_WORKERS "FAIL: all workers should be alive"
@assert status["dead_workers"] == 0 "FAIL: no workers should be dead"
@assert status["waiting_list_max"] == MAX_WAITING_LIST_SIZE "FAIL: waiting_list_max mismatch"
@assert length(status["workers"]) == NUM_IMMUNE_WORKERS "FAIL: should have $(NUM_IMMUNE_WORKERS) worker entries"

# Check each worker entry
for ws in status["workers"]
    @assert haskey(ws, "id")          "FAIL: worker status missing id"
    @assert haskey(ws, "alive")       "FAIL: worker status missing alive"
    @assert haskey(ws, "processed")   "FAIL: worker status missing processed"
    @assert haskey(ws, "errors")      "FAIL: worker status missing errors"
    @assert haskey(ws, "inbox_depth") "FAIL: worker status missing inbox_depth"
    @assert ws["alive"] == true "FAIL: worker $(ws["id"]) should be alive"
end

println("  ✓ get_pool_status returns all expected fields")
println("  ✓ All $(NUM_IMMUNE_WORKERS) worker entries present and alive")

kill_immune_pool!(pool)

# ==============================================================================
# 12. GET_WORKER_LOAD — Returns 8-element vector
# ==============================================================================
println("\n[12] GET_WORKER_LOAD")

pool = fresh_pool()
sleep(0.05)

loads = get_worker_load(pool)
@assert length(loads) == NUM_IMMUNE_WORKERS "FAIL: load vector should have $(NUM_IMMUNE_WORKERS) elements, got $(length(loads))"
@assert all(l -> l >= 0, loads) "FAIL: all loads should be >= 0 (idle workers)"
println("  ✓ get_worker_load returns $(NUM_IMMUNE_WORKERS)-element vector: $loads")

kill_immune_pool!(pool)

# ==============================================================================
# 13. CONCURRENT SUBMISSION — Thread-safe
# ==============================================================================
println("\n[13] CONCURRENT SUBMISSION — Thread safety")

pool = fresh_pool()
sleep(0.05)

n_concurrent = 200
concurrent_futures = Vector{ImmuneFuture}(undef, n_concurrent)
tasks = Task[]

for i in 1:n_concurrent
    t = @async begin
        try
            f = submit_immune_work!(pool, """{"concurrent":"$i","idx":$i}""", 500)
            concurrent_futures[i] = f
        catch e
            @error "Concurrent submission $i failed" exception=e
        end
    end
    push!(tasks, t)
end

# Wait for all submissions
for t in tasks
    wait(t)
end

println("  All $n_concurrent concurrent submissions completed")

# Wait for all futures
n_resolved = 0
for f in concurrent_futures
    if isassigned(concurrent_futures, 1)  # basic check
        try
            status, _ = fetch_result(f)
            n_resolved += 1
        catch e
            # Errors (ImmuneError, etc.) also count as resolved
            n_resolved += 1
        end
    end
end

@assert n_resolved == n_concurrent "FAIL: Expected $n_concurrent resolved futures, got $n_resolved"
println("  ✓ $n_resolved/$n_concurrent futures resolved without data corruption")

# Check counters are consistent
total_submitted = pool.submitted[]
@assert total_submitted == n_concurrent "FAIL: submitted counter=$total_submitted, expected $n_concurrent"
println("  ✓ Atomic submitted counter correct: $total_submitted")

kill_immune_pool!(pool)

# ==============================================================================
# 14. KILL POOL — Waiting list items get poisoned
# ==============================================================================
println("\n[14] KILL POOL — Pending futures receive ImmunePoolDeadError")

# Create pool but DON'T sleep (so dispatcher hasn't drained yet)
ImmuneSystem.reset_immune_state!()
pool = create_immune_pool(ImmuneSystem)
# Don't yield — submit immediately to keep items in waiting list

# Submit enough items to have some in waiting list when killed
pending_futures = ImmuneFuture[]
for i in 1:20
    f = submit_immune_work!(pool, """{"kill_test":$i}""", 500)
    push!(pending_futures, f)
end

# Kill immediately
kill_immune_pool!(pool)
@assert pool.alive[] == false "FAIL: pool should be dead after kill_immune_pool!"
println("  ✓ pool.alive[] = false after kill_immune_pool!")

# Any futures that were still in the waiting list (not dispatched yet) should
# receive ImmunePoolDeadError. Futures already dispatched will get normal results.
n_dead_errors = 0
n_normal = 0
for f in pending_futures
    try
        result = fetch_result(f)
        n_normal += 1
    catch e
        if e isa ImmunePoolDeadError
            n_dead_errors += 1
        elseif e isa ImmuneSystem.ImmuneError
            n_normal += 1  # Was processed before kill
        elseif e isa ImmuneWorkerDiedError
            n_dead_errors += 1  # Worker was killed
        else
            # Other errors should not happen
            @error "Unexpected error in kill test" exception=e
            rethrow(e)
        end
    end
end

println("  After kill: $n_normal processed normally, $n_dead_errors received dead/worker-died error")
@assert (n_normal + n_dead_errors) == 20 "FAIL: All 20 futures should have resolved one way or another"
println("  ✓ All 20 futures resolved after pool kill (no hanging futures)")

# ==============================================================================
# 15. OVERLOAD PROTECTION — Waiting list max
# ==============================================================================
println("\n[15] OVERLOAD PROTECTION")

# Create pool and fill waiting list beyond max
ImmuneSystem.reset_immune_state!()
pool = create_immune_pool(ImmuneSystem)
# Don't sleep — keep dispatcher from draining

# Manually stuff the waiting list to capacity
pool.waiting_list.size[] = MAX_WAITING_LIST_SIZE

caught_overload = false
try
    submit_immune_work!(pool, "overflow test", 500)
catch e
    if e isa ImmunePoolOverloadError
        caught_overload = true
    else
        rethrow(e)
    end
end
@assert caught_overload "FAIL: Should throw ImmunePoolOverloadError when waiting list full"
println("  ✓ ImmunePoolOverloadError thrown when waiting list at capacity ($MAX_WAITING_LIST_SIZE)")

# Reset for cleanup
pool.waiting_list.size[] = 0
kill_immune_pool!(pool)

# ==============================================================================
# 16. WORKER RESTART — restart_worker! on dead worker
# ==============================================================================
println("\n[16] WORKER RESTART")

pool = fresh_pool()
sleep(0.05)

# Manually kill worker 1
pool.workers[1].alive[] = false
close(pool.workers[1].inbox)
@assert pool.workers[1].alive[] == false "FAIL: Worker 1 should be dead"
println("  Worker 1 manually killed")

# Restart it
new_w = restart_worker!(pool, 1, ImmuneSystem)
sleep(0.05)  # let it start

@assert new_w.id == 1 "FAIL: Restarted worker should have id=1"
@assert new_w.alive[] == true "FAIL: Restarted worker should be alive"
@assert pool.workers[1] === new_w "FAIL: Pool should reference new worker"
@assert pool.balancer.workers[1] === new_w "FAIL: Balancer should reference new worker"
println("  ✓ Worker 1 restarted successfully and alive")

# Verify it can process work
f = submit_immune_work!(pool, """{"restart_test":"ok"}""", 500)
status, _ = fetch_result(f)
@assert status == :immature "FAIL: Restarted worker should handle work, got $status"
println("  ✓ Restarted worker 1 processed work correctly")

# Test invalid restart args
caught_bad_id = false
try
    restart_worker!(pool, 0, ImmuneSystem)
catch e
    caught_bad_id = true
end
@assert caught_bad_id "FAIL: restart_worker! with id=0 should throw"
println("  ✓ restart_worker! with invalid id throws correctly")

caught_alive = false
try
    restart_worker!(pool, 2, ImmuneSystem)  # Worker 2 is still alive
catch e
    caught_alive = true
end
@assert caught_alive "FAIL: restart_worker! on alive worker should throw"
println("  ✓ restart_worker! on alive worker throws correctly")

kill_immune_pool!(pool)

# ==============================================================================
# 17. CONSTANTS SANITY CHECK
# ==============================================================================
println("\n[17] CONSTANTS")

@assert NUM_IMMUNE_WORKERS == 8 "FAIL: NUM_IMMUNE_WORKERS must be 8, got $NUM_IMMUNE_WORKERS"
@assert MAX_WAITING_LIST_SIZE > 0 "FAIL: MAX_WAITING_LIST_SIZE must be positive"
@assert WORKER_CHANNEL_DEPTH > 0 "FAIL: WORKER_CHANNEL_DEPTH must be positive"
println("  ✓ NUM_IMMUNE_WORKERS = $NUM_IMMUNE_WORKERS")
println("  ✓ MAX_WAITING_LIST_SIZE = $MAX_WAITING_LIST_SIZE")
println("  ✓ WORKER_CHANNEL_DEPTH = $WORKER_CHANNEL_DEPTH")

# ==============================================================================
# 18. NO SILENT FAILURES — Error surface coverage
# ==============================================================================
println("\n[18] NO SILENT FAILURES — Error surface coverage")

pool = fresh_pool()
sleep(0.02)

error_tests = [
    ("submit to dead pool",  begin
        dead_pool = create_immune_pool(ImmuneSystem)
        kill_immune_pool!(dead_pool)
        () -> submit_immune_work!(dead_pool, "test", 500)
     end),
    ("submit empty input",   () -> submit_immune_work!(pool, "", 500)),
    ("submit whitespace",    () -> submit_immune_work!(pool, "  ", 500)),
    ("restart bad id 0",     () -> restart_worker!(pool, 0, ImmuneSystem)),
    ("restart bad id 9",     () -> restart_worker!(pool, 9, ImmuneSystem)),
]

for (name, fn) in error_tests
    caught = false
    try
        fn()
    catch e
        caught = true
    end
    @assert caught "FAIL: '$name' should throw but didn't"
    println("  ✓ $name → throws correctly")
end

kill_immune_pool!(pool)

# ==============================================================================
# 19. IMMUNE GATE INTEGRATION — simulate Main.jl immune_gate using pool
# ==============================================================================
println("\n[19] IMMUNE GATE INTEGRATION (simulated)")

ImmuneSystem.reset_immune_state!()
pool = create_immune_pool(ImmuneSystem)
sleep(0.05)

# Simulate what immune_gate does but using the thread pool
function pool_immune_gate(cmd_name::String, input_text::String, node_count::Int; is_critical::Bool=true)::Bool
    try
        status, sig = submit_and_wait!(pool, input_text, node_count; is_critical=is_critical)
        if status == :deleted
            println("[POOL_IMMUNE] ⛔ $cmd_name REJECTED (sig=0x$(string(sig, base=16)))")
            return false
        end
        if status != :immature
            println("[POOL_IMMUNE] 🛡 $cmd_name scan: $status (sig=0x$(string(sig, base=16)))")
        end
        return true
    catch e
        if e isa ImmuneSystem.ImmuneError
            println("[POOL_IMMUNE] ⛔ $cmd_name REJECTED: $(e.info)")
            return false
        elseif e isa ImmuneWorkerDiedError
            error("!!! FATAL: Immune worker died during gate check for $cmd_name! Restart pool! !!!")
        else
            @error "[POOL_IMMUNE] Unexpected error in immune gate for $cmd_name (non-fatal)" exception=e
            return true
        end
    end
end

# Below maturity — gate passes (always, immune sleeping)
result1 = pool_immune_gate("/grow", """{"pattern":"test"}""", 500)
@assert result1 == true "FAIL: gate should pass for immature specimen"
println("  ✓ immune_gate passes for immature specimen (node_count=500)")

# Mature + valid JSON — should pass
result2 = pool_immune_gate("/grow", """{"pattern":"valid_json_command","action":"greet^1"}""", 2000)
@assert result2 == true "FAIL: gate should pass for valid JSON at mature node count"
println("  ✓ immune_gate passes for valid JSON at node_count=2000")

kill_immune_pool!(pool)

# ==============================================================================
# 20. THROUGHPUT SMOKE TEST
# ==============================================================================
println("\n[20] THROUGHPUT SMOKE TEST")

ImmuneSystem.reset_immune_state!()
pool = create_immune_pool(ImmuneSystem)
sleep(0.05)

n_smoke = 500
smoke_futures = ImmuneFuture[]

t0 = time()
for i in 1:n_smoke
    f = submit_immune_work!(pool, """{"smoke_test":$i,"value":"x"}""", 500)
    push!(smoke_futures, f)
end
t_submit_smoke = time() - t0

t1 = time()
n_smoke_ok = 0
for f in smoke_futures
    try
        fetch_result(f)
        n_smoke_ok += 1
    catch
        n_smoke_ok += 1  # Any resolved result counts
    end
end
t_total_smoke = time() - t0
t_process_smoke = time() - t1

println("  $n_smoke items: submit=$(round(t_submit_smoke*1000, digits=1))ms, " *
        "total=$(round(t_total_smoke*1000, digits=1))ms, " *
        "process_wait=$(round(t_process_smoke*1000, digits=1))ms")

@assert n_smoke_ok == n_smoke "FAIL: Only $n_smoke_ok/$n_smoke futures resolved"
println("  ✓ All $n_smoke items processed")
println("  ✓ Submit phase: $(round(t_submit_smoke*1000, digits=1))ms (non-blocking)")

kill_immune_pool!(pool)

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("✅  ALL IMMUNE THREAD POOL TESTS PASSED (20 groups)")
println("="^60 * "\n")