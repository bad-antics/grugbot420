module PatternScanner

export cheap_scan, medium_scan, high_res_scan
export PatternScanError, PatternNotFoundError

# GRUG: Bring magic random bones for math (jitter).
using Random

# ==============================================================================
# 1. STRICT ERROR HANDLING (NO SILENT FAILURES)
# ==============================================================================

# GRUG: Grug no like quiet failures. If rock is bad or pattern missing, Grug scream loud!
# No return false, no return nothing. ONLY SCREAM!
abstract type AbstractScannerError <: Exception end

"""
Thrown when logical inputs to the scanner are invalid (e.g., empty arrays or mismatched lengths).
"""
struct PatternScanError <: AbstractScannerError
    msg::String
end

"""
Thrown when the target pattern cannot be resolved within the provided threshold limits.
Includes the highest confidence found before failing, for debug visibility.
"""
struct PatternNotFoundError <: AbstractScannerError
    msg::String
    highest_confidence::Float64
end

Base.showerror(io::IO, e::PatternScanError) = print(io, "PatternScanError: ", e.msg)
Base.showerror(io::IO, e::PatternNotFoundError) = print(io, "PatternNotFoundError: $(e.msg) (Highest Confidence: $(round(e.highest_confidence, digits=4)))")

# ==============================================================================
# 2. CORE LOGIC & JITTER
# ==============================================================================

# GRUG: Perfect bullseye is fake! Nature always shakes.
# Grug use bounded uniform shake so math tails don't reach infinity.
function slight_jitter(confidence::Float64)::Float64
    # Jitter scales slightly with how close to 1.0 (bullseye) we are
    jitter_magnitude = 0.005 + (0.01 * (1.0 - abs(confidence)))
    
    # GRUG FIX: randn() can draw infinitely long tails. 
    # Grug use rand() to keep noise strictly inside the box! [-1.0 to 1.0]
    jitter = (rand() * 2.0 - 1.0) * jitter_magnitude
    
    # Clamp between -1.0 and 1.0 so Grug math doesn't explode
    return clamp(confidence + jitter, -1.0, 1.0)
end

# GRUG: Grug look at window of rocks. 
# If rock look like pattern rock, Grug happy (similarity).
# If rock look different, Grug mad (dissimilarity).
# Confidence = Happy minus Mad. Then Grug shake it!
function evaluate_window(window::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}, tolerance::Real)::Float64
    if length(window) != length(pattern)
        throw(PatternScanError("Window size and pattern size do not match. Internal logic error."))
    end

    sim_count = 0
    dissim_count = 0
    total = length(pattern)

    @inbounds for i in 1:total
        diff = abs(window[i] - pattern[i])
        if diff <= tolerance
            sim_count += 1
        else
            dissim_count += 1
        end
    end

    similarity = sim_count / total
    dissimilarity = dissim_count / total

    # GRUG COHERENCE FIX: Large number small number coherence!
    # If Grug see ANY matching rocks (similarity > 0), Grug put a hard floor of 0.1.
    # Why? Grug want intrinsic matches to stay alive even if user throws a giant pile 
    # of garbage (dissimilarity) rocks around it.
    # If purely noise (similarity == 0), Grug let confidence fall completely negative.
    if similarity > 0
        raw_confidence = max(0.1, similarity - (dissimilarity * 0.1))
    else
        raw_confidence = -dissimilarity
    end
    
    return slight_jitter(raw_confidence)
end

# GRUG: Make sure rocks are real before Grug look at them.
# If pattern bigger than cave, Grug scream.
function _validate_inputs(target::AbstractVector, pattern::AbstractVector)
    if isempty(target) || isempty(pattern)
        throw(PatternScanError("Target or Pattern array cannot be empty."))
    end
    if length(pattern) > length(target)
        throw(PatternScanError("Pattern is larger than the target array."))
    end
end

# ==============================================================================
# 3. SCAN IMPLEMENTATIONS
# ==============================================================================

# GRUG: Fast scan. Grug skip over some rocks (stride) to run fast.
# Lazy but fast! If Grug find nothing, Grug no stay quiet—Grug throw error!
function cheap_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
                    tolerance::Real=0.1, threshold::Real=0.6)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    
    # GRUG FIX: Grug legs only so long. Skip some rocks based on length, 
    # but hard clamp the max stride at 8 so Grug doesn't accidentally jump entirely over a mountain.
    stride = clamp(pat_len ÷ 4, 1, 8)
    
    best_conf = -1.0
    best_idx = 0

    # Sliding window with stride
    for i in 1:stride:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance)
        
        if conf > best_conf
            best_conf = conf
            best_idx = i
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("Cheap scan failed to find pattern.", best_conf))
    end

    return (best_idx, best_conf)
end

# GRUG: Normal look. Grug check every single rock. Good balance.
function medium_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
                     tolerance::Real=0.1, threshold::Real=0.75)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    best_conf = -1.0
    best_idx = 0

    # Check every index
    for i in 1:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance)
        
        if conf > best_conf
            best_conf = conf
            best_idx = i
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("Medium scan failed to find pattern.", best_conf))
    end

    return (best_idx, best_conf)
end

# GRUG: High resolution! Grug squint real hard.
# First pass: Grug look for blurry maybe-spots.
# Second pass: Grug measure exact variance. If rocks too weird, Grug punish confidence!
function high_res_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
                       tolerance::Real=0.05, threshold::Real=0.90)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    candidates = Int[]
    
    # GRUG FIX: Pass 1 uses a mathematically looser threshold (threshold - 0.2)
    # so Grug can find blurry candidate zones before doing heavy variance math.
    looser_threshold = threshold - 0.2
    
    for i in 1:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance * 2.0) 
        if conf > looser_threshold
            push!(candidates, i)
        end
    end

    if isempty(candidates)
        throw(PatternNotFoundError("High-Res scan pass 1 found no candidate zones.", -1.0))
    end

    # Pass 2: Strict High-Res validation
    best_conf = -1.0
    best_idx = 0

    for idx in candidates
        window = view(target, idx:(idx + pat_len - 1))
        
        # Calculate strict confidence
        conf = evaluate_window(window, pattern, tolerance)
        
        # Penalty for high variance (High Res feature)
        variance = sum(abs2, window .- pattern) / pat_len
        
        # GRUG COHERENCE FIX: Just like the window evaluation, don't let 
        # a high variance penalty completely nuke an already positive tool match.
        if conf > 0
            penalized_conf = max(0.1, conf - (variance * 0.1))
        else
            penalized_conf = conf - (variance * 0.1)
        end
        
        final_conf = slight_jitter(penalized_conf)

        if final_conf > best_conf
            best_conf = final_conf
            best_idx = idx
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("High-Res scan pass 2 rejected all candidates.", best_conf))
    end

    return (best_idx, best_conf)
end

end # module

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: PERCEPTUAL SCANNER LAYER
#
# 1. STRICT NO-SILENT-FAILURE ARCHITECTURE:
# The module is completely deterministic in its error routing. It abandons traditional 
# silent returns (e.g., `nothing`, `-1`, or `false`) in favor of explicitly unwinding 
# the stack via `AbstractScannerError`. 
#
# 2. LARGE NUMBER / SMALL NUMBER COHERENCE:
# `evaluate_window` calculates discrete proportional similarity but safely dampens 
# localized dissimilarity. If any positive semantic signal exists (`similarity > 0`),
# a mathematical floor `max(0.1, ...)` acts as a circuit breaker so that excessive 
# user noise does not artificially negate intrinsic structural matches.
#
# 3. DYNAMIC EPHEMERAL JITTER (BULLSEYE RUN):
# `slight_jitter` injects a randomized, bounded uniform micro-variance into the final 
# confidence score. This mathematically models hardware/sensor variance ("running from 
# the bullseye") without allowing infinite Gaussian tails to destabilize output.
# ==============================================================================