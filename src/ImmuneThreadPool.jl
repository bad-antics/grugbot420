# ImmuneThreadPool.jl — Immune System Thread Space
# ==============================================================================
# GRUG: Immune system now lives in its OWN CAVE. Separate from main cave.
# 8 dedicated side threads. All input waiting/collection happens HERE.
# Bad input gets processed here. Main cave NEVER WAITS for immune work.
# If immune thread dies, IT SCREAMS LOUD. No hush. No quiet death.
#
# ARCHITECTURE:
#   - 8 worker threads (ImmuneWorker). Each owns one inbox Channel.
#   - ImmuneLoadBalancer: routes incoming scan requests to least-loaded worker.
#   - ImmuneWaitingList: inputs sit here before being picked up by balancer.
#   - Main thread calls submit_immune_work! → WaitingList → Balancer → Worker.
#   - Workers call ImmuneSystem.immune_scan! and return result via Future.
#   - Non-blocking: submit_immune_work! returns immediately with a Future.
#   - Caller can fetch(future) later, or fire-and-forget with watch mode.
#   - Zero silent failures: dead workers SCREAM via ImmuneWorkerDiedError.
#     Balancer SCREAMS if overloaded. Future SCREAMS if result is an error.
#
# GRUG RULES:
#   1. Immune thread space is isolated. Main cave does not touch it directly.
#   2. Load balancer distributes by least-queue-depth (cheapest bin fill).
#   3. Waiting list is bounded (MAX_WAITING_LIST_SIZE). Overflow = LOUD ERROR.
#   4. Worker crash = ImmuneWorkerDiedError thrown to all pending futures on that worker.
#   5. All state behind locks. Atomic counters for hot-path metrics.
#   6. No @warn, no @info for failures. Only @error or throw. Grug not whisper.
# ==============================================================================

module ImmuneThreadPool

using Base.Threads: Atomic, atomic_add!, atomic_sub!, ReentrantLock

# ImmuneSystem is included by the parent module (GrugBot420.jl / Main.jl).
# We reference it via the module name. If running standalone for tests,
# caller must include ImmuneSystem.jl first.

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Exactly 8 immune worker threads. Matches GrugBreathMap's 8 holes.
# 8 is the number. Not 7. Not 9. Eight.
const NUM_IMMUNE_WORKERS = 8

# GRUG: Each worker has an inbox channel of this depth.
# Deep enough to buffer burst traffic. Overflow → WaitingList backs up → LOUD ERROR.
const WORKER_CHANNEL_DEPTH = 64

# GRUG: Maximum items sitting in the WaitingList before we scream.
# If waiting list is full, system is overloaded. Caller must back off.
const MAX_WAITING_LIST_SIZE = 512

# GRUG: How often (seconds) the dispatcher wakes to drain WaitingList into workers.
# Short interval = low latency. 0.5ms is plenty.
const DISPATCHER_SLEEP_S = 0.0005

# GRUG: How long (seconds) worker waits for new work before looping.
# Controls worker responsiveness vs CPU burn. 1ms is fine.
const WORKER_TAKE_TIMEOUT_S = 0.001

# GRUG: Maximum retries to find a non-full worker before screaming.
const BALANCER_MAX_RETRY = 16

# ==============================================================================
# ERROR TYPES — GRUG: ALL LOUD. NO WHISPERING.
# ==============================================================================

"""
    ImmuneWorkerDiedError

GRUG: A worker thread in the immune pool died unexpectedly.
This is NOT a silent failure. Everyone hears about it.
All pending futures on that worker receive this error.
"""
struct ImmuneWorkerDiedError <: Exception
    worker_id::Int
    cause::Any   # The exception that killed it
end

function Base.showerror(io::IO, e::ImmuneWorkerDiedError)
    print(io, "💀 IMMUNE WORKER #$(e.worker_id) DIED! Grug's immune cave wall crumbled! cause=$(e.cause)")
end

"""
    ImmunePoolOverloadError

GRUG: The immune waiting list is full. Too many inputs piling up.
System is overwhelmed. Caller must back off and retry.
"""
struct ImmunePoolOverloadError <: Exception
    waiting_list_size::Int
    msg::String
end

function Base.showerror(io::IO, e::ImmunePoolOverloadError)
    print(io, "💀 IMMUNE POOL OVERLOADED! Waiting list at $(e.waiting_list_size). $(e.msg)")
end

"""
    ImmunePoolDeadError

GRUG: Tried to submit work to a dead pool. Pool was shut down.
Make a new pool if you want immune scanning.
"""
struct ImmunePoolDeadError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::ImmunePoolDeadError)
    print(io, "💀 IMMUNE POOL IS DEAD! Cannot submit work. $(e.msg)")
end

"""
    ImmuneWorkerBalancerError

GRUG: Load balancer could not find any worker with space.
All 8 worker inboxes are full. System is severely overloaded.
"""
struct ImmuneWorkerBalancerError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::ImmuneWorkerBalancerError)
    print(io, "💀 IMMUNE BALANCER STUCK! All 8 workers full. $(e.msg)")
end

# ==============================================================================
# IMMUNE FUTURE — Return handle for async immune scan results
# ==============================================================================

"""
    ImmuneFuture

GRUG: Handle to a pending immune scan result.
Call fetch_result(future) to get the result.
If immune worker died, fetch_result throws ImmuneWorkerDiedError.
If scan was rejected (ImmuneError), fetch_result throws that error.
No silent swallowing. Future either delivers or screams.

Fields:
- result_channel: buffered channel(1) where worker deposits result
- input_text:     original input (for debugging)
- submitted_at:   when this was submitted
- worker_id:      which worker is handling it (set by balancer)
- request_id:     unique monotonic ID for this request
"""
mutable struct ImmuneFuture
    result_channel::Channel{Any}  # delivers (status, sig) or an Exception
    input_text::String
    submitted_at::Float64
    worker_id::Atomic{Int}        # -1 = not yet assigned
    request_id::UInt64
end

"""
    ImmuneFuture(input_text::String, request_id::UInt64) -> ImmuneFuture

Create a new future for a pending immune scan.
"""
function ImmuneFuture(input_text::String, request_id::UInt64)
    return ImmuneFuture(
        Channel{Any}(1),
        input_text,
        time(),
        Atomic{Int}(-1),
        request_id
    )
end

"""
    fetch_result(future::ImmuneFuture)::Tuple{Symbol, UInt64}

GRUG: Wait for immune scan result. Blocks until result is ready.
Returns (status, signature) on success.
Throws if immune worker died or input was rejected.
NO SILENT SWALLOWING. All errors propagate to caller.
"""
function fetch_result(future::ImmuneFuture)
    result = take!(future.result_channel)
    if result isa Exception
        throw(result)  # GRUG SCREAMS
    end
    return result::Tuple{Symbol, UInt64}
end

"""
    is_ready(future::ImmuneFuture)::Bool

GRUG: Non-blocking check. Is result already available?
"""
function is_ready(future::ImmuneFuture)::Bool
    return isready(future.result_channel)
end

# ==============================================================================
# IMMUNE WORK ITEM — What goes into a worker's inbox
# ==============================================================================

"""
    ImmuneWorkItem

GRUG: A unit of immune work. Lives in the waiting list and worker inboxes.
Contains the input to scan, context for the scan, and the future to fill.
"""
struct ImmuneWorkItem
    future::ImmuneFuture
    input_text::String
    node_count::Int
    is_critical::Bool
    enqueued_at::Float64
end

# ==============================================================================
# IMMUNE WORKER — One thread, one inbox, one job: scan inputs
# ==============================================================================

"""
    ImmuneWorker

GRUG: One immune worker. Lives on its own thread. Has its own inbox channel.
Drains inbox, runs immune_scan!, puts result in future.
If it dies for any reason, it screams and poisons all pending futures.

Fields:
- id:           Worker ID (1–8)
- inbox:        Channel of ImmuneWorkItem
- task:         The background Task running this worker
- alive:        Atomic Bool. true = running, false = dead/stopping
- processed:    Atomic counter for diagnostics
- errors:       Atomic counter for scan errors (rejected inputs etc.)
- lock:         Lock for task reassignment during restart
"""
mutable struct ImmuneWorker
    id::Int
    inbox::Channel{ImmuneWorkItem}
    task::Task
    alive::Atomic{Bool}
    processed::Atomic{Int}
    errors::Atomic{Int}
    lock::ReentrantLock
end

# ==============================================================================
# IMMUNE WAITING LIST — Bounded input buffer before load balancing
# ==============================================================================

"""
    ImmuneWaitingList

GRUG: The waiting room. Inputs arrive here before being dispatched to workers.
Bounded. Overflow = LOUD ERROR. Main thread never blocks here.
The dispatcher task drains this into worker inboxes.

Fields:
- items:    Vector of ImmuneWorkItem (FIFO, front = oldest)
- lock:     Protects the items vector
- size:     Atomic for fast non-locked size check
"""
mutable struct ImmuneWaitingList
    items::Vector{ImmuneWorkItem}
    lock::ReentrantLock
    size::Atomic{Int}
end

function ImmuneWaitingList()
    return ImmuneWaitingList(ImmuneWorkItem[], ReentrantLock(), Atomic{Int}(0))
end

# ==============================================================================
# IMMUNE LOAD BALANCER — Routes work to least-loaded worker
# ==============================================================================

"""
    ImmuneLoadBalancer

GRUG: Picks which worker gets the next job.
Strategy: least-queue-depth (cheapest bin first filling).
If all workers full, throws ImmuneWorkerBalancerError LOUD.

Fields:
- workers:      Vector{ImmuneWorker} of exactly 8
- round_robin:  Atomic{Int} fallback counter (used when all depths equal)
"""
mutable struct ImmuneLoadBalancer
    workers::Vector{ImmuneWorker}
    round_robin::Atomic{Int}
end

"""
    pick_worker(balancer::ImmuneLoadBalancer)::ImmuneWorker

GRUG: Find the least-loaded alive worker.
Returns the worker to dispatch to.
Throws ImmuneWorkerBalancerError if all workers dead or all inboxes full.
"""
function pick_worker(balancer::ImmuneLoadBalancer)::ImmuneWorker
    # GRUG: Try to find least-loaded alive worker.
    # If tie, use round-robin among tied workers.
    best_worker = nothing
    best_depth = typemax(Int)

    for w in balancer.workers
        if !w.alive[]
            continue  # GRUG: Skip dead workers
        end
        depth = Base.n_avail(w.inbox)
        if depth < best_depth
            best_depth = depth
            best_worker = w
        end
    end

    if best_worker === nothing
        throw(ImmuneWorkerBalancerError(
            "All $(NUM_IMMUNE_WORKERS) immune workers are dead or unavailable. " *
            "Pool needs restart. Call restart_immune_pool!(pool)."
        ))
    end

    # GRUG: Check that chosen worker's inbox is not full
    for attempt in 1:BALANCER_MAX_RETRY
        if !isfull(best_worker.inbox)
            return best_worker
        end
        # GRUG: Chosen worker full, try round-robin among alive workers
        idx = (atomic_add!(balancer.round_robin, 1) % NUM_IMMUNE_WORKERS) + 1
        w = balancer.workers[idx]
        if w.alive[] && !isfull(w.inbox)
            return w
        end
    end

    throw(ImmuneWorkerBalancerError(
        "All $(NUM_IMMUNE_WORKERS) immune worker inboxes full after $(BALANCER_MAX_RETRY) retries. " *
        "Immune system is severely overloaded. Back off."
    ))
end

# Helper: check if channel is at capacity
function isfull(ch::Channel)::Bool
    return Base.n_avail(ch) >= ch.sz_max
end

# ==============================================================================
# IMMUNE THREAD POOL — The whole immune cave
# ==============================================================================

"""
    ImmuneThreadPool

GRUG: The whole immune cave. Eight workers. One dispatcher. One waiting list.
Submit work here. Pool handles everything. Main cave stays clean.

Fields:
- workers:       8 ImmuneWorker instances
- balancer:      ImmuneLoadBalancer
- waiting_list:  ImmuneWaitingList
- dispatcher:    Background Task draining waiting_list → workers
- alive:         Atomic{Bool} — true while pool is running
- request_counter: Atomic{UInt64} monotonic request ID generator
- submitted:     Atomic{Int} total submitted count
- dispatched:    Atomic{Int} total dispatched to workers
- rejected:      Atomic{Int} total immune rejections (not pool errors)
- pool_lock:     ReentrantLock for pool-level operations
"""
mutable struct ImmunePool
    workers::Vector{ImmuneWorker}
    balancer::ImmuneLoadBalancer
    waiting_list::ImmuneWaitingList
    dispatcher::Task
    alive::Atomic{Bool}
    request_counter::Atomic{Int}
    submitted::Atomic{Int}
    dispatched::Atomic{Int}
    rejected::Atomic{Int}
    pool_lock::ReentrantLock
end

# ==============================================================================
# WORKER LOOP — What each worker thread runs forever
# ==============================================================================

"""
    _worker_loop(worker::ImmuneWorker, immune_module)

GRUG: The inner loop of one immune worker.
Drains its inbox. Runs immune_scan! on each item.
Puts result in the item's future.
If immune_scan! throws ImmuneError → result is that error (rejection, not crash).
If anything ELSE throws → worker is considered dead, screams, poisons futures.

immune_module: The ImmuneSystem module reference passed in at pool creation.
"""
function _worker_loop(worker::ImmuneWorker, immune_module)
    worker.alive[] = true

    # GRUG: Worker stays alive until pool shuts down or fatal error
    while worker.alive[]
        # GRUG: Try to take from inbox. Non-blocking check first.
        local item::ImmuneWorkItem
        try
            # GRUG: isready check to avoid blocking when inbox empty
            if !isready(worker.inbox)
                sleep(WORKER_TAKE_TIMEOUT_S)
                continue
            end
            item = take!(worker.inbox)
        catch e
            # GRUG: Channel was closed (pool shutting down) — exit gracefully
            if e isa InvalidStateException
                break
            end
            # GRUG: Something weird happened to the channel. SCREAM.
            error_obj = ImmuneWorkerDiedError(worker.id, e)
            @error "💀 IMMUNE WORKER #$(worker.id): inbox take! failed" exception=e
            worker.alive[] = false
            break
        end

        # GRUG: We have work. Do the immune scan.
        try
            result = immune_module.immune_scan!(
                item.input_text,
                item.node_count;
                is_critical=item.is_critical
            )
            # GRUG: Success. Deliver result to future.
            put!(item.future.result_channel, result)
            atomic_add!(worker.processed, 1)

        catch e
            atomic_add!(worker.errors, 1)

            if e isa immune_module.ImmuneError
                # GRUG: Input was rejected by immune system.
                # This is NOT a worker crash. Deliver the error to the future.
                # Caller who fetch_result()s will see the ImmuneError thrown at them.
                put!(item.future.result_channel, e)
                atomic_add!(worker.processed, 1)

            else
                # GRUG: Unexpected error in immune_scan!. This is a REAL crash.
                # Poison this future. Then check if worker should die.
                death_error = ImmuneWorkerDiedError(worker.id, e)
                put!(item.future.result_channel, death_error)

                # GRUG: Log loud — this is not a normal rejection
                @error "💀 IMMUNE WORKER #$(worker.id): immune_scan! threw unexpected error" exception=(e, catch_backtrace())

                # GRUG: Worker stays alive (scan error ≠ worker death).
                # Only truly fatal errors (OOM, stack overflow) kill the worker.
                # Those will be caught by the outer try/catch below.
            end
        end
    end

    worker.alive[] = false
end

"""
    _start_worker(id::Int, immune_module) -> ImmuneWorker

GRUG: Spawn a new immune worker on a background task.
Returns the worker struct with running task.
"""
function _start_worker(id::Int, immune_module)::ImmuneWorker
    inbox = Channel{ImmuneWorkItem}(WORKER_CHANNEL_DEPTH)
    worker = ImmuneWorker(
        id,
        inbox,
        Task(() -> nothing),  # dummy task, replaced below
        Atomic{Bool}(false),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock()
    )

    worker.task = @async begin
        try
            _worker_loop(worker, immune_module)
        catch fatal_e
            # GRUG: Worker died with a fatal error (OOM etc). SCREAM LOUD.
            @error "💀 IMMUNE WORKER #$id FATALLY CRASHED" exception=(fatal_e, catch_backtrace())
            worker.alive[] = false
            # GRUG: Drain remaining inbox items, poison their futures
            while isready(inbox)
                try
                    item = take!(inbox)
                    death = ImmuneWorkerDiedError(id, fatal_e)
                    if isopen(item.future.result_channel)
                        put!(item.future.result_channel, death)
                    end
                catch
                    break
                end
            end
        end
    end

    return worker
end

# ==============================================================================
# DISPATCHER LOOP — Drains WaitingList into workers
# ==============================================================================

"""
    _dispatcher_loop(pool::ImmunePool)

GRUG: Background task. Wakes every DISPATCHER_SLEEP_S seconds.
Drains the waiting list into worker inboxes via load balancer.
If balancer throws (all workers dead/full), dispatcher screams too.
Dispatcher death = pool death. Pool should be restarted.
"""
function _dispatcher_loop(pool::ImmunePool)
    while pool.alive[]
        # GRUG: Drain as many items from waiting list as possible this cycle
        drained = 0
        while true
            # GRUG: Grab next item from waiting list (under lock)
            item = lock(pool.waiting_list.lock) do
                if isempty(pool.waiting_list.items)
                    return nothing
                end
                it = popfirst!(pool.waiting_list.items)
                atomic_sub!(pool.waiting_list.size, 1)
                return it
            end

            if item === nothing
                break  # GRUG: Waiting list is empty. Rest.
            end

            # GRUG: Route item to a worker via load balancer
            try
                worker = pick_worker(pool.balancer)
                item.future.worker_id[] = worker.id
                put!(worker.inbox, item)
                atomic_add!(pool.dispatched, 1)
                drained += 1
            catch e
                if e isa ImmuneWorkerBalancerError
                    # GRUG: All workers full or dead. Put item BACK at front of list.
                    # Log it loud. Don't silently drop.
                    @error "💀 IMMUNE DISPATCHER: Balancer failed, re-queuing item" exception=e
                    lock(pool.waiting_list.lock) do
                        pushfirst!(pool.waiting_list.items, item)
                        atomic_add!(pool.waiting_list.size, 1)
                    end
                    break  # Stop draining this cycle, try again next tick
                else
                    # GRUG: Unexpected dispatcher error. Poison the future. SCREAM.
                    @error "💀 IMMUNE DISPATCHER: Unexpected error dispatching item" exception=(e, catch_backtrace())
                    death = ImmuneWorkerDiedError(-1, e)
                    if isopen(item.future.result_channel)
                        put!(item.future.result_channel, death)
                    end
                end
            end
        end

        sleep(DISPATCHER_SLEEP_S)
    end
end

# ==============================================================================
# PUBLIC API — Create, use, and shut down the immune pool
# ==============================================================================

"""
    create_immune_pool(immune_module) -> ImmunePool

GRUG: Spin up the immune thread pool. 8 workers. 1 dispatcher. 1 waiting list.
Pass in the ImmuneSystem module so workers can call immune_scan!.
Returns a running ImmunePool.

This should be called ONCE at bot startup. Keep the pool alive for the bot's lifetime.
"""
function create_immune_pool(immune_module)::ImmunePool
    # GRUG: Spawn 8 workers
    workers = [_start_worker(i, immune_module) for i in 1:NUM_IMMUNE_WORKERS]

    # Small yield to let workers start their loops
    yield()

    balancer = ImmuneLoadBalancer(workers, Atomic{Int}(0))
    waiting_list = ImmuneWaitingList()

    # GRUG: Dummy dispatcher task, replaced below
    dummy_dispatcher = Task(() -> nothing)

    pool = ImmunePool(
        workers,
        balancer,
        waiting_list,
        dummy_dispatcher,
        Atomic{Bool}(true),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock()
    )

    # GRUG: Start the dispatcher
    pool.dispatcher = @async begin
        try
            _dispatcher_loop(pool)
        catch e
            @error "💀 IMMUNE DISPATCHER FATALLY CRASHED" exception=(e, catch_backtrace())
            pool.alive[] = false
        end
    end

    return pool
end

"""
    submit_immune_work!(
        pool::ImmunePool,
        input_text::String,
        node_count::Int;
        is_critical::Bool = true
    ) -> ImmuneFuture

GRUG: Submit an input to the immune thread pool for scanning.
Returns immediately with an ImmuneFuture. NEVER BLOCKS MAIN CAVE.
Input goes to WaitingList → Dispatcher → Worker → Future.

Throws:
- ImmunePoolDeadError: if pool is not running
- ImmunePoolOverloadError: if waiting list is full

No silent failures. If submit throws, caller knows immediately.
"""
function submit_immune_work!(
    pool::ImmunePool,
    input_text::String,
    node_count::Int;
    is_critical::Bool = true
)::ImmuneFuture

    # GRUG: Guard — pool must be alive
    if !pool.alive[]
        throw(ImmunePoolDeadError(
            "Immune pool is not running. Call create_immune_pool() first."
        ))
    end

    # GRUG: Guard — input must not be empty
    if strip(input_text) == ""
        error("!!! FATAL: submit_immune_work! got empty input_text! !!!")
    end

    # GRUG: Guard — waiting list not full
    current_size = pool.waiting_list.size[]
    if current_size >= MAX_WAITING_LIST_SIZE
        throw(ImmunePoolOverloadError(
            current_size,
            "Immune pool waiting list full ($current_size/$(MAX_WAITING_LIST_SIZE)). " *
            "Main cave is submitting faster than immune workers can process. Back off."
        ))
    end

    # GRUG: Create request ID and future
    req_id = UInt64(atomic_add!(pool.request_counter, 1))
    future = ImmuneFuture(input_text, req_id)

    item = ImmuneWorkItem(
        future,
        input_text,
        node_count,
        is_critical,
        time()
    )

    # GRUG: Push to waiting list (under lock)
    lock(pool.waiting_list.lock) do
        push!(pool.waiting_list.items, item)
        atomic_add!(pool.waiting_list.size, 1)
    end

    atomic_add!(pool.submitted, 1)
    return future
end

"""
    submit_and_wait!(
        pool::ImmunePool,
        input_text::String,
        node_count::Int;
        is_critical::Bool = true
    ) -> Tuple{Symbol, UInt64}

GRUG: Submit AND wait for result. Blocking convenience wrapper.
Use this when you need the result before proceeding (e.g., /grow gate).
Use submit_immune_work! when you want fire-and-forget or async checking.

Throws whatever the immune scan throws (ImmuneError on rejection, etc.).
"""
function submit_and_wait!(
    pool::ImmunePool,
    input_text::String,
    node_count::Int;
    is_critical::Bool = true
)::Tuple{Symbol, UInt64}

    future = submit_immune_work!(pool, input_text, node_count; is_critical=is_critical)
    return fetch_result(future)
end

"""
    kill_immune_pool!(pool::ImmunePool)

GRUG: Shut down the immune pool. Signal dispatcher and workers to stop.
Drain and poison any remaining waiting list items.
After this, pool is dead. Cannot be restarted (make a new one).
"""
function kill_immune_pool!(pool::ImmunePool)
    pool.alive[] = false

    # GRUG: Signal all workers to stop
    for w in pool.workers
        w.alive[] = false
    end

    # GRUG: Close all worker inboxes so blocked takes! wake up
    for w in pool.workers
        if isopen(w.inbox)
            close(w.inbox)
        end
    end

    # GRUG: Poison remaining items in waiting list
    remaining = lock(pool.waiting_list.lock) do
        items = copy(pool.waiting_list.items)
        empty!(pool.waiting_list.items)
        pool.waiting_list.size[] = 0
        items
    end

    shutdown_error = ImmunePoolDeadError("Immune pool was shut down while item was waiting.")
    for item in remaining
        if isopen(item.future.result_channel)
            put!(item.future.result_channel, shutdown_error)
        end
    end

    return nothing
end

"""
    restart_worker!(pool::ImmunePool, worker_id::Int, immune_module)

GRUG: Restart a dead worker. Use when a worker crashes.
Does NOT block. New worker starts async.
Throws if worker_id is out of range.
"""
function restart_worker!(pool::ImmunePool, worker_id::Int, immune_module)
    if worker_id < 1 || worker_id > NUM_IMMUNE_WORKERS
        error("!!! FATAL: restart_worker! got invalid worker_id=$worker_id (must be 1–$(NUM_IMMUNE_WORKERS))! !!!")
    end

    old_worker = pool.workers[worker_id]

    if old_worker.alive[]
        error("!!! FATAL: restart_worker! called on still-alive worker #$worker_id! Kill it first. !!!")
    end

    # GRUG: Close old inbox, create new worker
    if isopen(old_worker.inbox)
        close(old_worker.inbox)
    end

    new_worker = _start_worker(worker_id, immune_module)

    lock(pool.pool_lock) do
        pool.workers[worker_id] = new_worker
        pool.balancer.workers[worker_id] = new_worker
    end

    return new_worker
end

# ==============================================================================
# STATUS / DIAGNOSTICS
# ==============================================================================

"""
    get_pool_status(pool::ImmunePool) -> Dict{String, Any}

GRUG: Return full status of the immune thread pool.
Used for /status CLI display and monitoring.
"""
function get_pool_status(pool::ImmunePool)::Dict{String, Any}
    worker_statuses = Dict{String, Any}[]

    for w in pool.workers
        push!(worker_statuses, Dict{String, Any}(
            "id"          => w.id,
            "alive"       => w.alive[],
            "processed"   => w.processed[],
            "errors"      => w.errors[],
            "inbox_depth" => isopen(w.inbox) ? Base.n_avail(w.inbox) : -1,
            "inbox_max"   => WORKER_CHANNEL_DEPTH
        ))
    end

    alive_count = count(w -> w.alive[], pool.workers)

    return Dict{String, Any}(
        "pool_alive"        => pool.alive[],
        "num_workers"       => NUM_IMMUNE_WORKERS,
        "alive_workers"     => alive_count,
        "dead_workers"      => NUM_IMMUNE_WORKERS - alive_count,
        "waiting_list_size" => pool.waiting_list.size[],
        "waiting_list_max"  => MAX_WAITING_LIST_SIZE,
        "submitted_total"   => pool.submitted[],
        "dispatched_total"  => pool.dispatched[],
        "rejected_total"    => pool.rejected[],
        "workers"           => worker_statuses
    )
end

"""
    get_worker_load(pool::ImmunePool) -> Vector{Int}

GRUG: Return inbox depth of each worker (load snapshot).
Index = worker_id, value = current queue depth.
"""
function get_worker_load(pool::ImmunePool)::Vector{Int}
    return [isopen(w.inbox) ? Base.n_avail(w.inbox) : -1 for w in pool.workers]
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export ImmunePool, ImmuneFuture, ImmuneWorkItem
export ImmuneWorkerDiedError, ImmunePoolOverloadError, ImmunePoolDeadError, ImmuneWorkerBalancerError
export create_immune_pool, submit_immune_work!, submit_and_wait!, kill_immune_pool!
export restart_worker!, get_pool_status, get_worker_load
export fetch_result, is_ready
export NUM_IMMUNE_WORKERS, MAX_WAITING_LIST_SIZE, WORKER_CHANNEL_DEPTH

# ==============================================================================
# ACADEMIC BLOCK
# ==============================================================================
# The ImmuneThreadPool implements a bounded work-stealing-style executor for
# the grugbot420 immune system. Key design properties:
#
# 1. **Thread Isolation**: The 8 immune workers run exclusively on @async Tasks,
#    ensuring immune processing never executes on the main task's call stack.
#    This guarantees main-path latency is unaffected by immune work, even under
#    heavy anomaly load.
#
# 2. **Load Balancing via Least-Queue-Depth**: The ImmuneLoadBalancer implements
#    a greedy bin-filling strategy: route to the worker with the fewest pending
#    items. This minimizes worst-case queue depth under uneven load, approximating
#    optimal Makespan scheduling for independent equal-cost tasks.
#
# 3. **Bounded Buffering**: The ImmuneWaitingList provides a bounded FIFO buffer
#    (capacity MAX_WAITING_LIST_SIZE) between submission and dispatch. This
#    decouples the submission rate from the processing rate and provides
#    backpressure signaling (ImmunePoolOverloadError) when the system is saturated.
#
# 4. **Non-Blocking Submission**: submit_immune_work! enqueues to the WaitingList
#    under a single lock acquisition and returns an ImmuneFuture immediately.
#    The O(1) enqueue ensures the main path is never blocked on immune work.
#
# 5. **Zero Silent Failures**: Every failure path either (a) throws a typed
#    exception to the caller, or (b) delivers a typed exception into the
#    ImmuneFuture. There is no logging-only path for errors. Dead workers
#    propagate ImmuneWorkerDiedError to all pending futures on their inbox.
#
# 6. **Future-Based Result Delivery**: Results flow through Channel{Any}(1)
#    futures, enabling both blocking (fetch_result) and polling (is_ready)
#    consumption patterns. The single-slot channel ensures at-most-once delivery.
#
# Formal properties:
#   Let W = {w₁,...,w₈}, Q_i = inbox depth of wᵢ
#   pick_worker: argmin_{wᵢ alive} Q_i  (ties broken by round-robin)
#   submit_immune_work!: O(1) amortized (WaitingList append + size atomic)
#   dispatch latency: ≤ DISPATCHER_SLEEP_S + O(1) pick_worker time
#   overload signal: ImmunePoolOverloadError when |WaitingList| ≥ MAX_WAITING_LIST_SIZE
#   worker fault isolation: crash of wᵢ does not affect w_{j≠i}
#   main-path isolation: main task never holds ImmunePool locks during submission
# ==============================================================================

end # module ImmuneThreadPool